# Outline crowdsec false positive issue

## Status
- Finished

## Date
- 2026-05-16

## Version
- Outline: 1.7.1

## Problem
- Reload the outline when session is terminated, it causes 401 errors
  - fw ban users' IP address.

## Reason
- When the session is terminated by some reasons, every request recieves 401 errors
    - `LePresidente/http-generic-401-bf`

## Timeline
- 2026-05-16: Release outline
- 2026-05-16: Find the false positive case, and add whitelist

## Solution
- Add expression on whitelist
  - evt.Meta.target_fqdn == '{{ services['outline']['domain']['public'] }}.{{ domain['public'] }}' && evt.Meta.http_status == '401' && evt.Meta.http_verb == 'POST' && evt.Meta.http_path startsWith '/api/'
