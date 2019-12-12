. env.sh

echo
cyan "Starting Postgres Database"

docker image inspect ${POSTGRES_IMAGE} &> /dev/null
[[ $? -eq 0 ]] || docker pull ${POSTGRES_IMAGE}
docker rm postgres &> /dev/null
docker run \
  --name postgres \
  --rm \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=${PGPASSWORD}  \
  -v ${PWD}/sql:/docker-entrypoint-initdb.d \
  -d ${POSTGRES_IMAGE}

echo "Database is running on ${PGHOST}:5432"


# pg4admin : https://www.pgadmin.org/docs/pgadmin4/latest/container_deployment.html
# docker run --rm --name pg4admin -p 80:80 \
#     -e 'PGADMIN_DEFAULT_EMAIL=ppresto@hashicorp.com' \
#     -e 'PGADMIN_DEFAULT_PASSWORD=${PGPASSWORD}' \
#     -d dpage/pgadmin4

