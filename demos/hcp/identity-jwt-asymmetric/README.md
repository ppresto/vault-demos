# Identity-jwt-asymmetric demo
This repo configures an existing vault instance, uses the Identity engine to create JWT tokens, validates the tokens, and rotates keys.

## Demo
This demo assumes a running HCP Vault instance, and your shells has the following variables set.
```
export VAULT_ADDR=
export VAULT_TOKEN=
export VAULT_NAMESPACE=admin
```

Manually cut/paste commands from the `hcp-demo.sh` script to slowly walk through each step.  Run it to do a dry test.
```
./hcp-demo.sh
```
* create dev namespace to work in
* enable userpass
* create ops-1 and app-1 users
* configure oidc
* create jwt tokens
* validate
* rotate


### References
* [Identity Backend](https://www.vaultproject.io/api/secret/identity/tokens)
* [Identity Token Claims](https://www.vaultproject.io/docs/secrets/identity#token-contents-and-templates)
* [Identity API](https://www.vaultproject.io/api/secret/identity)
* [JWT Claims](https://www.vaultproject.io/docs/auth/jwt#bound-claims)


### Thanks for the initial guidance and example code
<!-- https://raw.githubusercontent.com/all-contributors/all-contributors/master/README.md -->
<table>
  <tr>
    <td align="center"><a href="https://dahlke.io/"><img src="https://avatars.githubusercontent.com/u/2934337?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Neil Dahlke</b></sub></a><br /><a href="https://github.com/dahlke" title="Answering Questions">💬</a> <a href="https://github.com/dahlke" title="Documentation">📖</a><a href="https://github.com/dahlke" title="Code">💻</a></td>
  </tr>
</table>
