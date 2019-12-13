#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. env.sh

echo
cyan "Starting pg4admin with user: ppresto@hashicorp.com, pass: ${PGPASSWORD}"
sed -e "s/IP_ADDRESS/$PGHOST/" < pg4admin/servers.json.template  > pg4admin/servers.json

# pg4admin : https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html
docker run --rm --name pg4admin -p 80:80 \
  -v ${DIR}/pg4admin/servers.json:/pgadmin4/servers.json \
  -e 'PGADMIN_DEFAULT_EMAIL=ppresto@hashicorp.com' \
  -e PGADMIN_DEFAULT_PASSWORD=${PGPASSWORD} \
  -d dpage/pgadmin4

