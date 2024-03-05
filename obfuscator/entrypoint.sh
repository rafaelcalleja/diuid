#!/bin/bash

set -e
set -o pipefail

GNUPGHOME=${GNUPGHOME:-$HOME/.gnupg/}
GNUPG_EXTRA_SOCKET=${GNUPG_EXTRA_SOCKET:-${GNUPGHOME}/S.gpg-agent}
GNUPG_AGENT_TTL=${GNUPG_AGENT_TTL:-60}

if [[ -f "${GNUPGHOME}/gpg-agent.conf" ]]; then
  sed -i "s/60/${GNUPG_AGENT_TTL:-60}/g" ${GNUPGHOME}/gpg-agent.conf
fi

if [[ ! -z "${REPOSITORY}" ]]; then
  GPG_PASSPHRASE=$(curl -u "$USERNAME:$PASSWORD" -SsL -H "X-Gitea-OTP: $CODE" $REPOSITORY |jq -r .content|base64 -d)
   if [[ $? -ne 0 ]]; then
     unset GPG_PASSPHRASE
   fi
fi

if [[ ! -z "${GPG_PRIVATE_KEY}" ]]; then
  export GPG_TTY=$(tty)
  gpg-connect-agent updatestartuptty /bye > /dev/null 2>&1

  if [[ ! -z "${GNUPG_SOCKET_SERVER_PORT}" ]]; then
    (while true; do
      socat TCP-LISTEN:${GNUPG_SOCKET_SERVER_PORT},bind=${GNUPG_SOCKET_SERVER_HOST:-127.0.0.1} UNIX-CONNECT:${GNUPG_EXTRA_SOCKET};
    done) &
  fi

  if [[ ! -z "${GNUPG_SOCKET_CLIENT_PORT}" ]]; then
    gpgconf --kill gpg-agent
    (while true; do
      socat UNIX-LISTEN:${GNUPGHOME}/S.gpg-agent,unlink-close,unlink-early TCP4:${GNUPG_SOCKET_CLIENT_HOST:-localhost}:${GNUPG_SOCKET_CLIENT_PORT};
    done) &
  fi
fi

if [[ ! -z "${GPG_PRIVATE_KEY}" ]] && [[ ! -z "${GPG_PASSPHRASE}" ]]; then
  echo ${GPG_PASSPHRASE}| gpg --batch --yes --passphrase-fd 0 --pinentry-mode loopback --import <(echo ${GPG_PRIVATE_KEY} | base64 --decode) > /dev/null 2>&1
  echo ${GPG_PASSPHRASE}| gpg --batch --pinentry-mode loopback --passphrase-fd 0 --sign --output /dev/null /dev/null > /dev/null 2>&1

  bash -c "sleep ${GNUPG_AGENT_TTL}; gpgconf --kill gpg-agent" > /dev/null 2>&1 &
fi

unset GPG_PASSPHRASE

exec docker-entrypoint.sh "$@"
