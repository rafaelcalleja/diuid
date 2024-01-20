#!/bin/bash

set -e
set -o pipefail

if [[ ! -z "${REPOSITORY}" ]]; then
  GPG_PASSPHRASE=$(curl -u "$USERNAME:$PASSWORD" -SsL -H "X-Gitea-OTP: $CODE" $REPOSITORY |jq -r .content|base64 -d)
   if [[ $? -ne 0 ]]; then
     unset GPG_PASSPHRASE
   fi
fi

if [[ ! -z "${GPG_PRIVATE_KEY}" ]] && [[ ! -z "${GPG_PASSPHRASE}" ]]; then
  export GPG_TTY=$(tty)
  gpg-connect-agent updatestartuptty /bye > /dev/null 2>&1

  echo ${GPG_PASSPHRASE}| gpg --batch --yes --passphrase-fd 0 --pinentry-mode loopback --import <(echo ${GPG_PRIVATE_KEY} | base64 --decode) > /dev/null 2>&1
  echo ${GPG_PASSPHRASE}| gpg --batch --pinentry-mode loopback --passphrase-fd 0 --sign --output /dev/null /dev/null > /dev/null 2>&1
fi

unset GPG_PASSPHRASE

exec docker-entrypoint.sh "$@"
