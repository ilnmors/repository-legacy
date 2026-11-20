# repository-legacy

Read-only archive of the homelab before its current form. The live project is [ilnmors/repository](https://github.com/ilnmors/repository); its [history](https://github.com/ilnmors/repository/blob/main/docs/history.md) explains each generation.

| Generation | Period | Where to look |
| --- | --- | --- |
| 0 | 2025-04 – 2025-06 | `docs/archives/2025-06/`: the first design documents (commit `f4143b5`). |
| 1 | 2025-07 – 2025-12 | `docs/archives/2025-12/`: the hand-built runbooks (commit `4ddae07`). |
| 2 | 2026-01 – 2026-10 | The Ansible monorepo in the rest of the history, from `1.0.0 Release IaaS` (2026-03-15). |
| 3 | 2026-09 – 2026-10 | The roles-by-concern rewrite at the end of the history. |

## Generation 0 and 1 documents

These predate the Ansible code and are kept as plain files under `docs/archives/`.

**Generation 0: design (2025-06 snapshot)**, `docs/archives/2025-06/`

- `홈 서버 구축 계획.txt`: the first home server plan (Korean): goals and the step-by-step build plan.
- `on-premise.txt`: the project overview (Korean): motivation, goals, scope and the planned design.

Both are in Korean. English translations, line for line with the originals (commands and configuration unchanged), are in `docs/english-translation-ver/archives/2025-06/`: `home-server-plan.txt` and `on-premise.txt`.

**Generation 1: hand-built runbooks (2025-12 snapshot)**, `docs/archives/2025-12/`

| Folder | Contents |
| --- | --- |
| `01_plans/` | Hardware, VM plan and the project milestones. |
| `02_theory/` | Background notes: DNS, DHCP, PKI, TLS, SSO, e-mail. |
| `03_common/` | Shared Debian configuration, iptables, Podman, CrowdSec, Redis, btrfs. |
| `04_hypervisor/` | Debian with KVM/libvirt as the hypervisor. |
| `05_firewall/` | The OPNsense VM: interfaces, rules, Suricata, ACME, Kea. |
| `06_network/` | The net VM: DDNS, BIND, AdGuard Home, Kea. |
| `07_authorization/` | The auth VM: step-ca, Caddy, Authentik (replaced), LLDAP, Authelia. |
| `08_development/` | The dev VM: PostgreSQL, sidecar Caddy, code-server. |
| `09_application/` | The app VM preparation. |
| `console.md`, `scripts.md` | The console client and the secrets helper script. |

Notes on this archive:

- The first two commits were added when the archive was published. Their dates are the months the snapshots were taken (2025-06 and 2025-12); every later commit keeps its original date and message.
- Secret values that appeared in plain text (SSH host keys, WireGuard keys, application keys, database and backup passwords, a public address and a personal e-mail address) were replaced with `<redacted>` or documentation values throughout the history. The encrypted secrets files, generated tarball snapshots and empty data placeholders were removed.
- Nothing here is maintained. Configuration, versions and practices are outdated; use the live repository instead.
