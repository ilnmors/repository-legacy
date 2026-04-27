# Android application OIDC issue

## Status
- Processing

## Date
- 2026-04-20

## Version
- affine server: 0.26.3 (self-hosted)
- affine application: 0.26.3 (Android)
- IdP: Authelia:4.39.15

## Problem
- Affine android app cannot authenticate via OIDC
  - IdP authentication succeeds, but the app does not establish a session
  - The app remains on the "Sign In" screen

## Reason
- Affine uses callback deep link `affine://authentication`
- For self-hosted instances the deep link carries a 'server' parameter pointing to the correct origin, but android never read it.
- [Issue #12819: No SSO on Android](https://github.com/toeverything/AFFiNE/issues/12819)
- [PR #14809](https://github.com/toeverything/AFFiNE/pull/14809)

## Timeline
- 2025-06-14: Issue #12819
- 2026-04-08: PR #14809
- 2026-04-09: Canary branch merge
- 2026-04-15: Fork, cherry-pick

## Solution
- Wait for stable release which contains the merge above
- When the stable version releases, then verify after update
