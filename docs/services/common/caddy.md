# Caddy

## TLS re-encryption

This is not a perfect E2EE communication theorogically, however technically it is. The main caddy decrypt as an edge node of WAN side, and it becomes a client of side caddy with private certificate.

### .com public domain

WAN - \(Let's Encrypt certificate\) -> Caddy \(auth\) - \(ilnmors internal certificate\) -> Caddy \(app\) or https services - http -> app's local service

### .internal private domain
client - \(ilnmors internal certificate\) -> Caddy \(Infra\) - http -> local services

### DNS record

*.app.ilnmors.internal - CNAME -> app.ilnmors.internal

## X-Forwarded-Host

When caddy in app conducts TLS re-encryption, it is important to change their Host header as X-Forwarded-Host haeder for session maintainance.

## Example

```ini
# Auth server
test.ilnmors.com
{
    import crowdsec_log
    route {
        crowdsec
        reverse_proxy https://test.app.ilnmors.internal
    }
}
# App server
test.app.ilnmors.internal
{
     import internal_tls
     trusted_proxies {{ hostvars['fw']['network4']['auth']['server'] }} {{ hostvars['fw']['network6']['auth']['server'] }}
     route {
        reverse_proxy host.containers.internal:3000 {
            header_up Host {header.X-Forwarded-Host} {Host}
        }
     }
}
```
