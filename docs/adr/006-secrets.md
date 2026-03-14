# ADR 006 - Secrets

## Date

- Feb/23/2026
    - First documentation

## Status

- Accepted

## Context

- Secret values must not uploaded anywhere as plain values.
- Manage secret values as Git without its real values.

## Considerations

### External KMS

- HashiCorp Vault or Infisical
    - Very powerful, but introduces significant compute/memory overhead.
    - Creates a "Secret Zero" problem for a single-node homelab environment because of dependency \(DB, or etc\).
    - It is hard to operate hardware separated key servers.

### Systemd-credential

- VM environment is hard to apply TPM for systemd-credential
    - It is hard to guarantee the idempotency of TPM in virtual environment.

### Ansible vault only

- Ansible vault is powerful options but they are not convenient.
    - It is necessary to encrypt separately outside of host_vars or group_vars' file.
    - It is hard to add or modify secret values in inventory file.

## Decisions

- All secret data which has yaml format is encrypted by sops with age-key in `secret.yaml`.
- age-key is encrypted by gpg and ansible vault with master key \(including upper, lower case, number, special letters) above 40 characters.
    - All secret data always decrypt by `edit_secret.sh` script or ansible tasks from secrets.yaml using age-key encrypted by ansible-vault.
    - decrypted secret data is always processed on ramfs, they are never saved on disk.
- Master key is never saved on disk, but only cold storage \(USB, M-DISC, operators' memory\)
- The secret data will be saved on each servers specific directory or podman secret.
    - OS:
        - path: /etc/secrets
          owner: root:root
          mode: 0711
        - path: /etc/secrets/\$UID
          owner: \$UID:root
          mode: 0500
    - Containers:
        - podman secret:
          path: /run/secret/\$SECRET_NAME
    - These data are never backed up by kopia, or uploaded to git.

## Consequences

- Secret values are not located as a plain text in everywhere except where they are needed.
- It is possible to manage encrypted secret data with Git.
