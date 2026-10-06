# ldapcon2026-workshop

## Getting started

- Create the machines (tested with Debian 13)
- Setup inventory
  - use inventory-sample.yml as example
- Setup secrets
  - capass (plays create a self-signed CA for internal communication between servers)
  - truststorepw (used by jmeter to access java's default truststore cacerts)
  - rootpw (contains the password for jmeter service account)
- Stage artifacts
  - set path for letsencrypt cert in all.yml.
    - cert.pem
    - chain.pem
    - fullchain.pem
    - privkey.pem

## Run the play

```bash
ansible-playbook -i inventory.yml main.yml
```
