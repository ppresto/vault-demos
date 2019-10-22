# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.auth_ldap_576a63e3.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.auth_ldap_576a63e3.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.auth_ldap_576a63e3.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.auth_ldap_576a63e3.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.auth_ldap_576a63e3.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.auth_ldap_576a63e3.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.auth_ldap_576a63e3.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.auth_ldap_576a63e3.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.auth_ldap_576a63e3.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.auth_ldap_576a63e3.name}}"
{
  capabilities = ["list", "read", "delete"]
}

# Allow full access to the current version of the kv-blog
path "kv-blog/data/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}


# Allow deletion of any kv-blog version
path "kv-blog/delete/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/delete/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}"
{
  capabilities = ["update"]
}

# Allow un-deletion of any kv-blog version
path "kv-blog/undelete/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/undelete/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}"
{
  capabilities = ["update"]
}

# Allow destroy of any kv-blog version
path "kv-blog/destroy/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}/*"
{
  capabilities = ["update"]
}

path "kv-blog/destroy/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}"
{
  capabilities = ["update"]
}
# Allow list and view of metadata and to delete all versions and metadata for a key
path "kv-blog/metadata/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}/*"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/{{identity.entity.aliases.auth_ldap_af9c1d3a.name}}"
{
  capabilities = ["list", "read", "delete"]
}

path "kv-blog/metadata/"
{
  capabilities = ["list"]
}
