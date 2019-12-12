# Kill docker containers
docker kill postgres openldap pg4admin

# Kill the Vault dev server
kill $(ps -af | grep "vault server -dev" | grep -v grep | awk '{print $2}')
