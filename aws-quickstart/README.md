# Provision a Quick Start Vault Cluster in AWS

The goal of this guide is to allows users to easily provision a quick start Vault & Consul cluster in just a few commands.

## Reference Material

- [Terraform Getting Started](https://www.terraform.io/intro/getting-started/install.html)
- [Terraform Docs](https://www.terraform.io/docs/index.html)
- [Consul Getting Started](https://www.consul.io/intro/getting-started/install.html)
- [Consul Docs](https://www.consul.io/docs/index.html)
- [Vault Getting Started](https://www.vaultproject.io/intro/getting-started/install.html)
- [Vault Docs](https://www.vaultproject.io/docs/index.html)

## Estimated Time to Complete

5 minutes.

## Challenge

There are many different ways to provision and configure an easily accessible quick start Vault & Consul cluster, making it difficult to get started.

## Solution

Provision a quick start Vault & Consul cluster in a private network with a bastion host.

The AWS Quick Start Vault guide leverages the scripts in the [Guides Configuration Repo](https://github.com/hashicorp/guides-configuration) to do runtime configuration for Vault & Consul. Although using `curl bash` at runtime is _not_ best practices, this makes it quick and easy to standup a Vault & Consul cluster with no external dependencies like pre-built images. This guide will also forgo setting up TLS/encryption on Vault & Consul for the sake of simplicity.

## Prerequisites

- [Download Terraform](https://www.terraform.io/downloads.html)

## Steps

We will now provision the quick start Vault & Consul clusters.

### Step 1: Initialize

Initialize Terraform - download providers and modules.

#### CLI

[`terraform init` Command](https://www.terraform.io/docs/commands/init.html)

##### Request

```sh
$ terraform init
```

##### Response
```
```

### Step 2: Plan

Run a `terraform plan` to ensure Terraform will provision what you expect.

#### CLI

[`terraform plan` Command](https://www.terraform.io/docs/commands/plan.html)

##### Request

```sh
$ terraform plan
```

##### Response
```
```

### Step 3: Apply

Run a `terraform apply` to provision the HashiStack. One provisioned, view the `zREADME` instructions output from Terraform for next steps.

#### CLI

[`terraform apply` command](https://www.terraform.io/docs/commands/apply.html)

##### Request

```sh
$ terraform apply
```

### Step 4: Configure

** This is for development only!! **
Run `./vaultSetup_template.sh` from your build system.  This will scp/ssh to the bastion host to initialize, unseal, and setup vault your environment variables.  This will set your VAULT_TOKEN to the ROOT Token, and copy the adminVault.sh script to the bastion host to automate admin tasks like checking cluster health, and upgrading to v1.2.2.  FYI:  This script uses your Shamir Keys which were added to your ec2-user's ~/.bashrc by vaultSetup_template.sh for unsealing nodes that may have been restarted or shutdown during dev.

## Step 5: Administration

The vaultAdmin.sh script can be used to quickly assess your Vault Cluster health.  This can also upgrade your cluster to v1.2.2 if desired.  This script should be run from your bastion host or have direct access to your Vault Cluster.  This script depends on you running the configuration step previsously with "vaultSetup

```
$ sshbastion  # ssh alias created by vaultSetup_template.sh to get to your bastion host.

$ ./vaultAdmin.sh health

10.139.3.127 healthy (ver=1.2.2, sealed=false, HTTP_CODE=429)
10.139.1.33 healthy (ver=1.2.2, sealed=false, HTTP_CODE=200) - Leader
10.139.2.161 healthy (ver=1.2.2, sealed=false, HTTP_CODE=429)

$ ./vaultAdmin.sh upgrade  #Example output for a cluster already upgraded to v1.2.2 ...

Upgrading:  10.139.3.127 10.139.2.161 10.139.1.33
Leader URL: "http://10.139.1.33:8200"
10.139.3.127 healthy (ver=1.2.2, sealed=false, HTTP_CODE=429)
10.139.3.127 (ver:1.2.2, health status: 429) Skipping Upgrade
10.139.2.161 healthy (ver=1.2.2, sealed=false, HTTP_CODE=429)
10.139.2.161 (ver:1.2.2, health status: 429) Skipping Upgrade
10.139.1.33 healthy (ver=1.2.2, sealed=false, HTTP_CODE=200) - Leader
10.139.1.33 (Leader:true, ver:1.2.2, health status: 200) Skipping Upgrade
```

## Step 6: Labs

Walk through the vault basics in ./labs starting with 1. 

```
cd ./labs
./1_awsSecretsEngine.sh
```

## Next Steps

Now that you've provisioned, configured, and administered your Vault & Consul cluster, visit our [learn](https://learn.hashicorp.com/vault/?track=secrets-management#secrets-managemen) site.
