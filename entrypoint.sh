#!/bin/bash

ARGS=$@

if [[ ! -z "${DEBUG}" ]];
then
  echo "Docker: $(dockerd --version)"
  echo "Kernel: $(/linux/linux --version)"
  echo "Rootfs: $(lsb_release -ds)"
  echo
  echo "Configuration: MEM=${MEMORY:-$MEM} DISK=$DISK"
fi

#/usr/local/bin/sshd -v &

#start sshd
#/etc/init.d/ssh start
mkdir -p ${HOME}/keys/ ${HOME}/.ssh/
ssh-keygen -f ${HOME}/keys/ssh_host_rsa_key -N '' -t rsa > /dev/null 2>&1
ssh-keygen -f ${HOME}/keys/ssh_host_dsa_key -N '' -t dsa > /dev/null 2>&1

echo ${SSH_PUB_KEY} >> ${HOME}/.ssh/authorized_keys

cat ${HOME}/keys/ssh_host_rsa_key.pub >>${HOME}/.ssh/authorized_keys
cat ${HOME}/keys/ssh_host_dsa_key.pub >>${HOME}/.ssh/authorized_keys

chmod 600 ${HOME}/.ssh/authorized_keys
chmod 700 ${HOME}/.ssh
chmod 600 ${HOME}/keys/*
chmod 644 ${HOME}/keys/config
cp ${HOME}/keys/ssh_host_rsa_key ${HOME}/.ssh/id_rsa
sed -i "s|\\\${HOME}|${HOME}|g" ${HOME}/keys/config

if [[ "root" == $(whoami) ]];
then
  mkdir /run/sshd
  chmod 0755 /run/sshd
fi

/usr/sbin/sshd -f ${HOME}/keys/config -D &


# Create the ext4 volume image for /var/lib/docker
if [ ! -f /persistent/var_lib_docker.img ]; then
    if [[ ! -z "${DEBUG}" ]];
    then
      echo "Formatting /persistent/var_lib_docker.img"
    fi
    dd if=/dev/zero of=/persistent/var_lib_docker.img bs=1 count=0 seek=${DISK} > /dev/null 2>&1
    mkfs.ext4 /persistent/var_lib_docker.img > /dev/null 2>&1
fi

# verify TMPDIR configuration
if [ $(stat --file-system --format=%T $TMPDIR) != tmpfs ]; then
    if [[ ! -z "${DEBUG}" ]]; then
      echo "For better performance, consider mounting a tmpfs on $TMPDIR like this: \`docker run --tmpfs $TMPDIR:rw,nosuid,nodev,exec,size=8g\`"
    fi
fi

#start the uml kernel with docker inside
echo "DIUID_DOCKERD_FLAGS=\"$DIUID_DOCKERD_FLAGS\"" > /tmp/env
echo "HOST_USER=\"$(whoami)\"" >> /tmp/env
echo "HOST_HOME=\"$HOME\"" >> /tmp/env
echo "SSH_PRIVATE_KEY=\"$(cat ${HOME}/.ssh/id_rsa)\"" >> /tmp/env

# Get docker group from DIUID_DOCKERD_FLAGS
DIUID_DOCKERD_GROUP='docker'
DIUID_DOCKERD_OPTS=`getopt -q -o G: --long group: -n 'getopt' -- $DIUID_DOCKERD_FLAGS`
eval set -- "$DIUID_DOCKERD_OPTS"
while true; do
  case "$1" in
	-G|--group ) DIUID_DOCKERD_GROUP="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done
echo "DIUID_DOCKERD_GROUP=\"$DIUID_DOCKERD_GROUP\"" >> /tmp/env

/sbin/start-stop-daemon --start --background --make-pidfile --pidfile /tmp/kernel.pid --exec /bin/bash -- -c "exec /kernel.sh > /tmp/kernel.log 2>&1"

if [[ ! -z "${DEBUG}" ]]; then
  echo -n "waiting for dockerd "
fi
while true; do
	if docker version 2>/dev/null >/dev/null; then
		echo ""
		break
	fi
	if ! /sbin/start-stop-daemon --status --pidfile /tmp/kernel.pid; then
		echo ""
		echo failed to start uml kernel:
		cat /tmp/kernel.log
		exit 1
	fi

  if [[ ! -z "${DEBUG}" ]]; then
	  echo -n "."
  fi
	sleep 0.5
done

if [[ ! -z "${DEBUG}" ]]; then
  echo "Executing \"$ARGS\""
fi
exec $ARGS
