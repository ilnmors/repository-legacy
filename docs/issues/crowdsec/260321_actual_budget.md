# Actual Budget crowdsec false positive issue

## Status
- Finished

## Date
- 2026-03-21

## Version
- Actual Budget: 26.3.0

## Problem
- When users access and log in actual budget, all connections to homelab services are refused.
  - fw ban users' IP address.

## Reason
- Actual budget has local first policy.
- When the user log in actual budget, the client downloads all sql files from the server.
- LAPI decides that as an attack which sensitive file(sql) is downloaded concurrently.

## Timeline
- 2026-03-21: Release actual budget
- 2026-03-21: Find the false positive case, and add whitelist

## Solution
- Access to fw
  - Check the ban list with `sudo cscli alerts list`
  - Read the ban case with `sudo cscli alerts inspect $NUMBER`
- Add regex on whitelist
  - evt.Meta.target_fqdn == '{{ services['actualbudget']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_path contains '/data/migrations/'
- Delete false positive decision
  - Check false positive decision with `sudo cscli decision list`
  - Delete false positive decision with `sudo cscli decision delete --id $ID`
