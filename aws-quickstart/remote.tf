terraform {
    backend "remote" {
        hostname = "app.terraform.io"
        organization = "Patrick"

        workspaces {
            name = "vault-learning-aws-quickstart"
        }
    }
}