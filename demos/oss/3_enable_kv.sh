. env.sh

echo
#cyan "Enabling KV Secret Engine"
green "Enable the Engine"
pe "vault secrets enable -path=${KV_PATH} -version=${KV_VERSION} kv"
