ARG IMAGE_BASE_NAME=debian
ARG IMAGE_BASE_VERSION=12.4
ARG KERNEL_VERSION=6.6
ARG GOLANG_VERSION=1.17.6
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=5:24.0.7-1~debian.12~bookworm
ARG SLIRP4NETNS_VERSION=1.2.2

FROM $IMAGE_BASE_NAME:$IMAGE_BASE_VERSION as kernel_build

RUN \
	apt-get update && \
	apt-get install git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc wget flex bison libelf-dev -y && \
	apt-get install -y --no-install-recommends libarchive-tools

ARG KERNEL_VERSION

RUN \
	wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz && \
	tar -xf linux-$KERNEL_VERSION.tar.xz && \
	rm linux-$KERNEL_VERSION.tar.xz

WORKDIR linux-$KERNEL_VERSION
COPY KERNEL.config .config
RUN make ARCH=um oldconfig && make ARCH=um prepare
RUN make ARCH=um -j `nproc`
RUN mkdir /out && cp -f linux /out/linux

RUN cp .config /KERNEL.config

# usage: docker build -t foo --target print_config . && docker run -it --rm foo > KERNEL.config
FROM $IMAGE_BASE_NAME:$IMAGE_BASE_VERSION AS print_config
COPY --from=kernel_build /KERNEL.config /KERNEL.CONFIG
RUN echo "CONFIG_IPV6=y" >> KERNEL.CONFIG && \
    echo "CONFIG_IPV6_SIT=y" >> KERNEL.CONFIG && \
    echo "CONFIG_IPV6_NDISC_NODETYPE=y" >> KERNEL.CONFIG && \
    echo "CONFIG_IPV6_MULTIPLE_TABLES=y" >> KERNEL.CONFIG && \
    echo "CONFIG_IPV6_SUBTREES=y" >> KERNEL.CONFIG && \
    echo "CONFIG_IPV6_MROUTE=y" >> KERNEL.CONFIG && \
    echo "CONFIG_NF_DEFRAG_IPV6=y" >> KERNEL.CONFIG

CMD ["cat", "/KERNEL.CONFIG"]

FROM golang:$GOLANG_VERSION AS diuid-docker-proxy
COPY diuid-docker-proxy /go/src/github.com/weber-software/diuid/diuid-docker-proxy
WORKDIR /go/src/github.com/weber-software/diuid/diuid-docker-proxy
RUN go build -o /diuid-docker-proxy

FROM $IMAGE_BASE_NAME:$IMAGE_BASE_VERSION

LABEL maintainer="weber@weber-software.com"

RUN \
	apt-get update && \
	apt-get install -y wget net-tools openssh-server psmisc rng-tools \
	apt-transport-https ca-certificates gnupg2 software-properties-common iptables iproute2

RUN \
	update-alternatives --set iptables /usr/sbin/iptables-legacy && \
	update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RUN \
	mkdir -p /root/.ssh && \
	ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N "" && \
	cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

#install docker
ARG DOCKER_CHANNEL
ARG DOCKER_VERSION
ARG IMAGE_BASE_NAME
RUN \
    install -m 0755 -d /etc/apt/keyrings && \
    wget -O - https://download.docker.com/linux/$IMAGE_BASE_NAME/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$IMAGE_BASE_NAME \
      $(. /etc/os-release && echo "$VERSION_CODENAME") $DOCKER_CHANNEL" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-cache madison docker-ce && \
    apt-get install -y docker-ce=$DOCKER_VERSION docker-ce-cli=$DOCKER_VERSION containerd.io docker-buildx-plugin docker-compose-plugin

#install diuid-docker-proxy
COPY --from=diuid-docker-proxy /diuid-docker-proxy /usr/bin
RUN echo GatewayPorts=yes >> /etc/ssh/sshd_config

#install slirp4netns (used by UML)
ARG SLIRP4NETNS_VERSION
RUN \
  wget -O /usr/bin/slirp4netns https://github.com/rootless-containers/slirp4netns/releases/download/v${SLIRP4NETNS_VERSION}/slirp4netns-x86_64 && \
  chmod +x /usr/bin/slirp4netns

#install kernel and scripts
COPY --from=kernel_build /out/linux /linux/linux

#VOLUME ["/image"]
#COPY --chown=1000:1000 image.raw /image/
#RUN chmod 777 /image/image.raw

RUN apt-get install -y uidmap

ADD kernel.sh kernel.sh
ADD entrypoint.sh entrypoint.sh
ADD init.sh init.sh

#specify the of memory that the uml kernel can use 
ENV MEM 2G
ENV TMPDIR /umlshm

RUN mkdir /umlshm; chown 1000:1000 /umlshm
RUN mkdir /persistent; chown 1000:1000 /persistent
RUN mkdir /var/lib/docker; chown 1000:1000 /var/lib/docker
RUN mkdir /etc/docker; chown 1000:1000 /etc/docker

RUN useradd -m -u 1000 user
RUN mkdir -p /home/user && chown 1000:1000 /home/user -R
RUN ln -s /home/user/.docker/run/docker.sock /var/run/docker.sock
#COPY reverse-ssh /usr/local/bin/sshd

#RUN chown 1000:1000 /image

USER 1000
ENV HOME /home/user
COPY --chown=user:user config ${HOME}/keys/
COPY --chown=root:root config /root/keys/

#it is recommended to override /umlshm with
#--tmpfs /umlshm:rw,nosuid,nodev,exec,size=8g,mode=1777,uid=1000,gid=1000
VOLUME /umlshm

#disk image for /var/lib/docker is created under this directory
VOLUME /persistent


ENV DISK 10G
ENV XDG_RUNTIME_DIR /home/user/.docker/run
ENV PATH /usr/bin:$PATH
ENV DOCKER_HOST unix:///home/user/.docker/run/docker.sock



ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "bash" ]

COPY --chown=user:user daemon.json /etc/docker/daemon.json
RUN dockerd-rootless-setuptool.sh install
