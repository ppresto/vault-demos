## Mac Based
This was developed on a Mac with the following requirements installed:

- [Vault](https://www.vaultproject.io/downloads.html)
- [Docker](https://hub.docker.com/search/?type=edition&offering=community)
  - [Postgres image](https://hub.docker.com/_/postgres)
  - Custom OpenLDAP image - git clone https://github.com/grove-mountain/docker-ldap-server.git
- [jq](https://stedolan.github.io/jq/)

```

## Setup Postgres, LDAP, and Vault Server 
### First window
```
./0_launch_vault.sh
```

### Run Vault Configuration Demo.  By default the final test cases, audit log window, and browser features are commented out so you can quickly run through it.
```
./1_config_vault.sh
```

### Run Features Demo as HR App admin (Frank)
```
./2_run_demo.sh
```

Finish with:
```
./shutdown.sh
```
