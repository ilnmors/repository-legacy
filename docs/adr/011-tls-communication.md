# ADR 011 - TLS communication

## Date

- Mar/06/2026
    - First documentation
    
## Status

- Accepted

## Context

- To make administrational policy simple
- Set the principle of TLS communication boundry

## Considerations

### Apply mTLS

- implementing mTLS needs both client certificate and server certificate
- Managing a number of certificates makes a huge operational burden (expiry date, revocation, etc ..)

## Decisions

- Set TLS for all communication except 'lo' interface
- When it is possible to activate TLS, apply it even in 'lo' interface

## Consequences

- The policy is set simple
- The overhead is increased little
- Exclude the exceptions on operation (For the administrator)
