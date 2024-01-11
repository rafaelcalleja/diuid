#!/bin/bash

if [[ ! -z "${GPG_PRIVATE_KEY}" ]]; then
  gpg --import <(echo ${GPG_PRIVATE_KEY} | base64 --decode) > /dev/null 2>&1
fi

exec docker-entrypoint.sh "$@"
