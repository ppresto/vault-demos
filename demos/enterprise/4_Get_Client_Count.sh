#!/bin/bash

# https://github.com/WhatsARanjit/vault-counter

. env.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

#docker run --rm -e VAULT_ADDR=http://${IP_ADDRESS}:8200 -e VAULT_TOKEN=${VAULT_TOKEN} whatsaranjit/vault_counter:0.0.4

docker run --rm -e VAULT_ADDR=http://${IP_ADDRESS}:8200 -e VAULT_TOKEN=${VAULT_TOKEN} whatsaranjit/vault_counter:latest
