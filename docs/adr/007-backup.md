# ADR 007 - backup

## Date

- Feb/23/2026
    - First documentation

- Feb/27/2026
    - Status changed from Deferred to Accepted

- May/06/2026
    - Add backup checking rules
    
## Status

- Accepted

## Context

- All configuration file is managed by git \(IaC\)
- All data file should be backed up by kopia
- All backup should follow 3-2-1 backup cycle

## Considerations

### Backup Tool
- Restic / BorgBackup
    - Also excellent deduplicating backup tools.
    - However, Kopia provides a highly efficient native server mode (API) and cross-platform compatibility, making it easier to integrate with Synology DSM.

### Database Backup Method
- Physical Backup (Raw data folder backup / File system snapshots)
    - Backing up the `/var/lib/postgresql` directory directly while the DB is running can lead to severe data corruption and inconsistency.
    - Logical dumps (`pg_dump`) are much safer, database-agnostic, and easier to restore in a homelab environment.

### Silent failure problem

- May/06/2026, the fact that backups haven't run since commit '9f236b6fa5' because of '%h' in system service unit.
    - Operator couldn't realize backup doesn't run because the system service was failed silently.
    - Therefore, set the checking rule.


## Decisions

- All configuration files are managed by Git
    - Configuration files are based on text
    - It is necessary to version, history management.
    - Local git -> private Gitea -> github private project \(mirrored\) 
    - This fulfills 3-2-1 backup rules
- Data files are managed by Kopia and DSM
    - Local storage - kopia -> DSM's Kopia repository server - CloudSync -> Cloud server such as OneDrive or Google Drive
    - This fulfills 3-2-1 backup rules
- Data files which needs backup
    - DB data files: dump
        - DB data files are located on infra:/home/infra/containers/postgresql/backups/\{cluster,$service\}/
    - App data files: Photos, Media, etc ..
        - App data files are located on app:/home/app/data/
    - Backed up files: kopia
        - DSM:/kopia/{infra,app}/
- Kopia over DSM configuration is managed by runbook with equivalent CLI commands due to vendor limitation
- Restore will be processed manually
    - DB data files
        - From kopia server to console:$HOMELAB_PATH/data/volume/infra/postgresql/\{cluster,data\}
    - APP data files
        - From kopia server to APP vm after initiating before deploy services
- Automatic backup does not guarantee integrity of data system, so before reset the system conduct manual backup after making sure all services are shutdown.
- Check the repository once a week (Every monday)
    - Check the snapshot in repository with `kopia snapshot list --all`
    - Mount the snapshot respectively with `kopia mount $SNAPSHOT_ID $DESTINATION`
    - Copy random file from snapshot and check the values.
    - If there's some failure, check the backup service and conduct backup immediately.
    - Repeat the check flow.
    - When everything is done, umount the kopia mount with `ctrl+c`

## Consequences

- All files including configuration and data back ups will fulfill 3-2-1 \(3 Copies, 2 different media, 1 offsite\) back up rules
