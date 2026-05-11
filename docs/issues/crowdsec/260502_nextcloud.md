# Nextcloud crowdsec false positive issue

## Status
- Finished

## Date
- 2026-05-02

## Version
- Nextcloud: 33.0.3

## Problem
- When users download or modify some files, all connections to homelab services are refused.
  - fw ban users' IP address.

## Reason
- Nextcloud has a lot of workflows which can be caught from crowdsec

## Timeline
- 2026-05-02: Release nextcloud
- 2026-05-02: Find the false positive case, and add whitelist
- 2026-05-03: Install crowdsecurity/nextcloud-whitelist parser
- 2026-05-03: Make previous expressions annotation
- 2026-05-07: Find the false positive case, which is not on `crowdsecurity/nextcloud-whitelist`
- 2026-05-07: Set whitelist expression
- 2026-05-11: Find the false positive case, which is not on `crowdsec/nextcloud-whitelist`
- 2026-05-11: Set whitelist expression

## Solution
- Install crowdsecurity/nextcloud-whitelist on auth node
- Add expression on whitelist
  - evt.Meta.target_fqdn == '{{ services['nextcloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_status == '404' && evt.Meta.http_verb == 'GET' && evt.Meta.http_path startsWith '/index.php/core/preview?'
  - evt.Meta.target_fqdn == '{{ services['nextcloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_status in ['200', '304'] && evt.Meta.http_verb == 'GET' && evt.Meta.http_path contains 'chunks.mjs'

### Deprecated solution
- Access to fw
  - Check the ban list with `sudo cscli alerts list`
  - Read the ban case with `sudo cscli alerts inspect $NUMBER`
- Add expressions on whitelist
  - evt.Meta.target_fqdn == '{{ services['nextcloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_path contains '/apps/viewer/js/'
  - evt.Meta.target_fqdn == '{{ services['nextcloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_path contains '/dist/'
  - evt.Meta.target_fqdn == '{{ services['nextcloud']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_path contains '/remote.php/dav/files/'
- Delete false positive decision
  - Check false positive decision with `sudo cscli decision list`
  - Delete false positive decision with `sudo cscli decision delete --id $ID`
