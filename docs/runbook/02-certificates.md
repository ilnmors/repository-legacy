# Certificates

Create and renew certificates are very important, and very barely executed. It is managed manually without ansible.

#### PKI CA signed offline

step-cli is installed by ansible playbook for console.

```bash
# Generate CA key password
openssl rand -base64 32 > /run/user/$UID/root_ca_password
openssl rand -base64 32 > /run/user/$UID/intermediate_ca_password
# Save the values in `secrets.yaml`

# Create CAs (Key and cert)
# Root CA
step certificate create \
"ilnmors.internal Root CA" /run/user/$UID/root_ca.crt /run/user/$UID/root_ca.key \
--password-file /run/user/$UID/root_ca_password \
--profile root-ca \
--not-after 87600h
# Save the key and crt files content in `secrets.yaml`

# Intermediate CA
step certificate create \
"ilnmors.internal Intermediate CA" /run/user/$UID/intermediate_ca.crt /run/user/$UID/intermediate_ca.key \
--password-file /run/user/$UID/intermediate_ca_password \
--profile intermediate-ca \
--ca /run/user/$UID/root_ca.crt \
--ca-key /run/user/$UID/root_ca.key \
--ca-password-file /run/user/$UID/root_ca_password \
--not-after 43800h
# Save the key and crt files content in `secrets.yaml`

# fw

step certificate create \
"crowdsec.ilnmors.internal" /run/user/$UID/crowdsec.crt /run/user/$UID/crowdsec.key \
--profile leaf \
--san crowdsec.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

step certificate create \
"blocky.ilnmors.internal" /run/user/$UID/blocky.crt /run/user/$UID/blocky.key \
--profile leaf \
--san blocky.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

# infra

step certificate create \
"postgresql.ilnmors.internal" /run/user/$UID/postgresql.crt /run/user/$UID/postgresql.key \
--profile leaf \
--san postgresql.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

step certificate create \
"ldap.ilnmors.internal" /run/user/$UID/ldap.crt /run/user/$UID/ldap.key \
--profile leaf \
--san ldap.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

step certificate create \
"prometheus.ilnmors.internal" /run/user/$UID/prometheus.crt /run/user/$UID/prometheus.key \
--profile leaf \
--san prometheus.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

step certificate create \
"loki.ilnmors.internal" /run/user/$UID/loki.crt /run/user/$UID/loki.key \
--profile leaf \
--san loki.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

# DSM

step certificate create \
"nas.ilnmors.internal" /run/user/$UID/nas.crt /run/user/$UID/nas.key \
--profile leaf \
--san nas.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password

## Recreate leaf certificates
## update secrets.yaml
step certificate create \
"crowdsec.ilnmors.internal" /run/user/$UID/crowdsec.crt /run/user/$UID/crowdsec.key \
--profile leaf \
--san crowdsec.ilnmors.internal \
--ca /run/user/$UID/intermediate_ca.crt \
--ca-key /run/user/$UID/intermediate_ca.key \
--ca-password-file /run/user/$UID/intermediate_ca_password \
--not-after 21900h \
--insecure --no-password -f 
# print
cat /run/user/$UID/crowdsec.key
cat /run/user/$UID/crowdsec.crt

# Verify
step certificate verify /run/user/$UID/test.crt --roots /run/user/$UID/root_ca.crt
# Inspect
step certificate inspect /run/user/$UID/test.crt
# validate date
sudo step certificate inspect --format json /run/user/$UID/test.crt | jq '.validity.end'
# margin date
echo "$(( ($(date -d 2028-07-17T03:50:10Z +%s) - $(date +%s)) / 60 / 60 / 24 ))"

# Delete temporary files
rm /run/user/$UID/root_ca*
rm /run/user/$UID/intermediate_ca*
rm /run/user/$UID/*.key
rm /run/user/$UID/*.crt
```

#### SSH CA

```bash
# Generate SSH CA
ssh-keygen -t ed25519 -f /run/user/$UID/id_local_ssh_ca -C "LOCAL_SSH_CA" -N ""
# Save the key and crt files content in `secrets.yaml`
echo @cert-authority *.ilnmors.internal "$(cat /run/user/$UID/id_local_ssh_ca.pub)" | sudo tee /etc/ssh/ssh_known_hosts >/dev/null && sudo chmod 644 /etc/ssh/ssh_known_hosts

# Signing HOST SSH crt by SSH CA key
ssh-keygen -s /run/user/$UID/id_local_ssh_ca \
-h \
-I "vmm" \
-n "vmm,vmm_init,vmm.ilnmors.internal,init.vmm.ilnmors.internal" \
/run/user/$UID/id_vmm_ssh_host.pub
# This process is automated by ansible

ssh-keygen -L -f /etc/ssh/ssh_host_ed25519_key-cert.pub

# Create SSH client key
ssh-keygen -t ed25519 -f /etc/secrets/$UID/id_console -C "il@ilnmors.internal" -N ""

# Signing SSH client crt by SSH CA key
ssh-keygen -s /run/user/$UID/id_local_ssh_ca \
-I "console" \
-n "vmm,fw,infra,auth,app" \
/etc/secrets/$UID/id_console.pub
# This process is automated by ansible
```
