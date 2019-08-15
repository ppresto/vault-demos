# Provision a Vault Cluster in AWS

The goal of this guide is to provision a quick start Vault & Consul cluster in a private network with a bastion host.

This leverages the scripts in the [Guides Configuration Repo](https://github.com/hashicorp/guides-configuration) to do runtime configuration for Vault & Consul. Although using `curl bash` at runtime is _not_ best practices, this makes it quick and easy to standup a Vault & Consul cluster with no external dependencies like pre-built images.

## Reference Material

- [Terraform Getting Started](https://www.terraform.io/intro/getting-started/install.html)
- [Terraform Docs](https://www.terraform.io/docs/index.html)
- [Consul Getting Started](https://www.consul.io/intro/getting-started/install.html)
- [Consul Docs](https://www.consul.io/docs/index.html)
- [Vault Getting Started](https://www.vaultproject.io/intro/getting-started/install.html)
- [Vault Docs](https://www.vaultproject.io/docs/index.html)

## Estimated Time to Complete Env Build

5 minutes.

## Prerequisites

- [Download Terraform](https://www.terraform.io/downloads.html)

## Steps

We will now provision the quick start Vault & Consul clusters.

### Step 1: Initialize

Initialize Terraform - download providers and modules.

#### CLI

[`terraform init` Command](https://www.terraform.io/docs/commands/init.html)

```sh
$ cd ./aws-quickstart
$ terraform init
```

### Step 2: Plan

Run a `terraform plan` to ensure Terraform will provision what you expect.

#### CLI

[`terraform plan` Command](https://www.terraform.io/docs/commands/plan.html)

```sh
$ terraform plan
```

### Step 3: Apply

Run a `terraform apply` to provision the HashiStack. One provisioned, view the `zREADME` instructions output from Terraform for next steps.

#### CLI

[`terraform apply` command](https://www.terraform.io/docs/commands/apply.html)

```sh
$ terraform apply
```

### Step 4: Configure Vault

Run `0.vaultSetupScript_template.sh` to ssh to bastion host to initialize, unseal, and setup vault environment variables locally and on bastion host so you can interact with vault.

#### CLI

```sh
$ ./0.vaultSetupScript_template.sh
```

## Next Steps
Go to learn.hashicorp.com and walk through the examples.
* secrets engine - 1_awsSecretsEngine.sh
* github auth - 2_githubAuth.sh
* policies - 3_policy.sh, 4_policy_test.sh
* appRole Auth - 5_appRoleAuth_API.sh

