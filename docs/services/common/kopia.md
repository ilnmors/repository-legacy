# Kopia

Kopia is one of modern backup solution to support very strong deduplication.

## Repository

Kopia saves all information, even the users and policies on repository. Repository itself is complete. Repository is encrypted by master password.

## User and policy

When kopia is run as a kopia server, client can access to server with user and user password. The clients don't have to know master password. Kopia server decrypt the repository with the master password, and the client just access to the kopia server with their user account.

Repository <- Master password -> Kopia server <- User password -> Kopia client

