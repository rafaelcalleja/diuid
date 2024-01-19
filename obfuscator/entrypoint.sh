#!/bin/bash

set -a

if [[ ! -z "${REPOSITORY}" ]]; then
  GPG_PASSPHRASE=$(curl -u "$USERNAME:$PASSWORD" -SsL -H "X-Gitea-OTP: $CODE" $REPOSITORY |jq -r .content|base64 -d)
fi

if [[ ! -z "${GPG_PRIVATE_KEY}" ]] && [[ -z "${GPG_PASSPHRASE}" ]]; then
  gpg --import <(echo ${GPG_PRIVATE_KEY} | base64 --decode) > /dev/null 2>&1
fi

if [[ ! -z "${GPG_PRIVATE_KEY}" ]] && [[ ! -z "${GPG_PASSPHRASE}" ]]; then
  echo ${GPG_PASSPHRASE}| gpg --batch --yes --passphrase-fd 0 --import <(echo ${GPG_PRIVATE_KEY} | base64 --decode) > /dev/null 2>&1
fi

exec docker-entrypoint.sh "$@"
