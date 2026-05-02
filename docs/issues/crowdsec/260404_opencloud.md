# OpenCloud crowdsec false positive issue

## Status
- Finished

## Date
- 2026-04-04

## Version
- OpenCloud: 4.0.4

## Problem
- When users download some files, all connections to homelab services are refused.
  - fw ban users' IP address.

## Reason
- OpenCloud uses chunks when clients uploads or download files to it.
- LAPI decides a ban when a lot of chunks file is uploaded or downloaded from external devices 

## Timeline
- 2026-04-04: Release OpenCloud
- 2026-04-04: Find the false positive case, and add whitelist

## Solution
- Access to fw
  - Check the ban list with `sudo cscli alerts list`
  - Read the ban case with `sudo cscli alerts inspect $NUMBER`
- Add expressions on whitelist
  - evt.Meta.target_fqdn == '{{ services['opencloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_path contains '/js/chunks/'
- Delete false positive decision
  - Check false positive decision with `sudo cscli decision list`
  - Delete false positive decision with `sudo cscli decision delete --id $ID`
