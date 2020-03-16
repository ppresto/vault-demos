path "db-blog/creds/mother-hr-full-2m" {
    capabilities = [ "read" ]
    #mfa_methods  = ["my_okta"]
}

path "db-blog/creds/mother-hr-full-1h" {
    capabilities = [ "read" ]
    mfa_methods  = ["my_okta"]
}