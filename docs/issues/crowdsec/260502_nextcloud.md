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
- Nextcloud uses chunks for actions, and uploading and downloading
    - chunks on '/apps/viewer/js', '/dist/'
    - `crowdsecurity/http-crawl-non_statics`
- Nextcloud keeps checking directory which is uploading
    - upload directory '/remote.php/dav/files/'
    - `crowdsecurity/http-probing`

## Timeline
- 2026-05-02: Release nextcloud
- 2026-05-02: Find the false positive case, and add whitelist

## Solution
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
