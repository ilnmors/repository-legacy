# Collabora office

## Prerequisite

- Nothing

## Configuration

- Admin page is disabled by Environment options
    - `admin_console.enable=false`

### Link to nextcloud

- https://nextcloud.ilnmors.com
    - login with admin account

- Profile: Apps: Nextcloud Office 
    - Check installation and enable

- Profile: Administration Settings: Nextcloud Office: Your own server
    - http://host.containers.internal:9980 (collabora container port)
    - Public FQDN is set automatically
    - save

- Files
    - Verify document opening (verified)
    - The basic font `Noto Sans KR` exists
        - Korean is presented very well
