# Crowdsec

## LAPI

### Detecting
Host logs \> CrowdSec Agent\(parser\) > CrowdSec LAPI

### Decision
CrowdSec LAPI \(Decision + Register\)

### Block
CrowdSec LAPI \> CrowdSec Bouncer \(Block\)

## CAPI
CrowdSec CAPI \> crowdsec LAPI \(local\) \> CrowdSec Bouncer \(Block\)

## Ansible Deployment

### Set LAPI (fw/roles/tasks/set_crowdsec_lapi.yaml)

- Deploy fw's config.yaml
- Deploy crowdsec certificates
- Register machines \(Agents\)
- Register bouncers \(Bouncers\)

### Set Bouncer (fw/roles/tasks/set_crowdsec_bouncer.yaml)

- Deploy crowdsec-firewall-bouncer.yaml
- Install suricata collection \(parser\) with cscli
- Set acquis.d for suricata
- set-only: bouncer can't get metrics from the chain and rules count result which it doesn't make. - It means, it is impossible to use prometheus metric with set-only true option.
- chain or rules matched count reasults are able to check on nftables. 
  - use sudo nft list chain inet filter global to check packet blocked. \(counter command is required\)

### Set Machines; agents (common/tasks/set_crowdsec_agent.yaml)

- Deploy config.yaml except fw \(disable LAPI, online_api_credentials\)
- Deploy local_api_credentials.yaml

### Set caddy host (auth/tasks/set_caddy.yaml)

- Set caddy CrowdSec module
- Set caddy log directory
- Install caddy collection \(parser\) with cscli
- Set acquis.d for caddy

### Set whitelist (/etc/crowdsec/parser/s02-enrich/whitelists.yaml)

- Set only local console IP address
- This can block local VM to the other subnet, but the communication between vms is possible because they are in the same subnet\(L2\) - packets don't pass the fw.
- Crowdsec bouncer only conducts blocks forward chain which pass Firewall, it is blocked by crowdsec bouncer based on lapi

## Test

### Decision test

> Set test decisions and check it

fw@fw:/etc/crowdsec/bouncers$ sudo cscli decisions add --ip 5.5.5.5 --duration 10m --reason "Test"
INFO[12-01-2026 01:50:40] Decision successfully added                  
fw@fw:/etc/crowdsec/bouncers$ sudo tail -f /var/log/crowdsec-firewall-bouncer.log

time="12-01-2026 01:50:22" level=info msg="backend type : nftables"
time="12-01-2026 01:50:22" level=info msg="nftables initiated"
time="12-01-2026 01:50:22" level=info msg="Using API key auth"
time="12-01-2026 01:50:22" level=info msg="Processing new and deleted decisions . . ."
time="12-01-2026 01:50:22" level=info msg="Serving metrics at 127.0.0.1:60601/metrics"
time="12-01-2026 01:50:22" level=info msg="1320 decisions deleted"
time="12-01-2026 01:50:22" level=info msg="15810 decisions added"
time="12-01-2026 01:50:42" level=info msg="1 decision added"

fw@fw:/etc/crowdsec/bouncers$ sudo nft list ruleset | grep -i 5.5.5.5
                             5.5.5.5 timeout 9m54s876ms expires 9m22s296ms,

### Parser test

> CrowdSec "crowdsecurity/suricata-evelogs" only parses "event_type: alert". You can test with cscli explain

fw@fw:~$ sudo cscli explain --file /tmp/suri_test.log --type suricata-evelogs --verbose
line: {"timestamp":"2026-01-11T14:43:52.153576+0000","flow_id":972844861874490,"in_iface":"wan","event_type":"alert","src_ip":"197.242.151.53","src_port":42976,"dest_ip":"203.0.113.10","dest_port":38694,"proto":"TCP","flow":{"pkts_toserver":1,"pkts_toclient":0,"bytes_toserver":60,"bytes_toclient":0,"start":"2026-01-11T14:42:51.554188+0000","end":"2026-01-11T14:42:51.554188+0000","age":0,"state":"new","reason":"timeout","alerted":false},"community_id":"1:Ovyuzq7R8yA3YfxM8jEExR5BZMI=","tcp":{"tcp_flags":"02","tcp_flags_ts":"02","tcp_flags_tc":"00","syn":true,"state":"syn_sent","ts_max_regions":1,"tc_max_regions":1}}
        ├ s00-raw
        |       ├ 🟢 crowdsecurity/non-syslog (first_parser)
        |       └ 🔴 crowdsecurity/syslog-logs
        ├ s01-parse
        |       ├ 🔴 crowdsecurity/apache2-logs
        |       ├ 🔴 crowdsecurity/nginx-logs
        |       ├ 🔴 crowdsecurity/sshd-logs
        |       ├ 🟢 crowdsecurity/suricata-evelogs (+9 ~2)
        |               ├ update evt.Stage : s01-parse -> s02-enrich
        |               ├ create evt.Parsed.dest_ip : 203.0.113.10
        |               ├ create evt.Parsed.dest_port : 38694
        |               ├ create evt.Parsed.proto : TCP
        |               ├ create evt.Parsed.time : 2026-01-11T14:43:52.153576
        |               ├ update evt.StrTime :  -> 2026-01-11T14:43:52.153576Z
        |               ├ create evt.Meta.log_type : suricata_alert
        |               ├ create evt.Meta.service : suricata
        |               ├ create evt.Meta.source_ip : 197.242.151.53
        |               ├ create evt.Meta.sub_log_type : suricata_alert_eve_json
        |               ├ create evt.Meta.suricata_flow_id : 972844861874490
        |       └ 🔴 crowdsecurity/suricata-fastlogs
        ├ s02-enrich
        |       ├ 🟢 crowdsecurity/dateparse-enrich (+2 ~1)
        |               ├ create evt.Enriched.MarshaledTime : 2026-01-11T14:43:52.153576Z
        |               ├ update evt.MarshaledTime :  -> 2026-01-11T14:43:52.153576Z
        |               ├ create evt.Meta.timestamp : 2026-01-11T14:43:52.153576Z
        |       ├ 🟢 crowdsecurity/geoip-enrich (+13)
        |               ├ create evt.Enriched.IsInEU : false
        |               ├ create evt.Enriched.IsoCode : ZA
        |               ├ create evt.Enriched.ASNumber : 37611
        |               ├ create evt.Enriched.Latitude : -28.998400
        |               ├ create evt.Enriched.Longitude : 23.988800
        |               ├ create evt.Enriched.SourceRange : 197.242.144.0/20
        |               ├ create evt.Enriched.ASNNumber : 37611
        |               ├ create evt.Enriched.ASNOrg : Afrihost
        |               ├ create evt.Meta.ASNNumber : 37611
        |               ├ create evt.Meta.IsInEU : false
        |               ├ create evt.Meta.SourceRange : 197.242.144.0/20
        |               ├ create evt.Meta.ASNOrg : Afrihost
        |               ├ create evt.Meta.IsoCode : ZA
        |       ├ 🔴 crowdsecurity/http-logs
        |       └ 🟢 crowdsecurity/whitelists (unchanged)
        ├-------- parser success 🟢
        ├ Scenarios

#### Caddy 
auth@auth:~/containers/authelia/config$ sudo cscli explain --file /var/log/caddy/access.log --type caddy
line: {"level":"info","ts":1771601235.7503738,"logger":"http.log.access.log1","msg":"handled request","request":{"remote_ip":"192.168.99.20","remote_port":"59900","client_ip":"192.168.99.20","proto":"HTTP/2.0","method":"GET","host":"authelia.ilnmors.com","uri":"/static/js/components.TimerIcon.CO1b_Yfm.js","headers":{"Accept-Encoding":["gzip, deflate, br, zstd"],"Referer":["https://authelia.ilnmors.com/settings"],"Te":["trailers"],"Accept":["*/*"],"Sec-Fetch-Dest":["script"],"Priority":["u=1"],"Sec-Fetch-Mode":["cors"],"Accept-Language":["en-US,en;q=0.9"],"Cookie":["REDACTED"],"Sec-Fetch-Site":["same-origin"],"User-Agent":["Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0"]},"tls":{"resumed":false,"version":772,"cipher_suite":4865,"proto":"h2","server_name":"authelia.ilnmors.com"}},"bytes_read":0,"user_id":"","duration":0.0077169,"size":10193,"status":200,"resp_headers":{"Via":["1.1 Caddy"],"Alt-Svc":["h3=\":443\"; ma=2592000"],"X-Content-Type-Options":["nosniff"],"Content-Security-Policy":["default-src 'none'"],"Date":["Fri, 20 Feb 2026 15:27:15 GMT"],"Etag":["7850315714d1e01e73f4879aa3cb7465b4e879dc"],"Cache-Control":["public, max-age=0, must-revalidate"],"Content-Length":["10193"],"X-Frame-Options":["DENY"],"Content-Type":["text/javascript; charset=utf-8"],"Referrer-Policy":["strict-origin-when-cross-origin"],"Permissions-Policy":["accelerometer=(), autoplay=(), camera=(), display-capture=(), geolocation=(), gyroscope=(), keyboard-map=(), magnetometer=(), microphone=(), midi=(), payment=(), picture-in-picture=(), screen-wake-lock=(), sync-xhr=(), xr-spatial-tracking=(), interest-cohort=()"],"X-Dns-Prefetch-Control":["off"]}}
        ├ s00-raw
        |       ├ 🟢 crowdsecurity/non-syslog (first_parser)
        |       └ 🔴 crowdsecurity/syslog-logs
        ├ s01-parse
        |       ├ 🔴 crowdsecurity/apache2-logs
        |       └ 🟢 crowdsecurity/caddy-logs (+19 ~2)
        ├ s02-enrich
        |       ├ 🟢 crowdsecurity/dateparse-enrich (+2 ~1)
        |       ├ 🟢 crowdsecurity/http-logs (+7)
        |       └ 🟢 crowdsecurity/whitelists (~2 [whitelisted])
        └-------- parser failure 🔴

## BAN logs case

### LAPI metrics

fw@fw:~$ sudo cscli metrics

Acquisition Metrics:
╭─────────────────────────────────────────────────┬────────────┬──────────────┬────────────────┬────────────────────────╮
│                     Source                      │ Lines read │ Lines parsed │ Lines unparsed │ Lines poured to bucket │
├─────────────────────────────────────────────────┼────────────┼──────────────┼────────────────┼────────────────────────┤
│ file:/var/log/suricata/eve.json                 │ 130.25k    │ -            │ 130.25k        │ -                      │
│ journalctl:journalctl-_SYSTEMD_UNIT=ssh.service │ 6          │ -            │ 6              │ -                      │
╰─────────────────────────────────────────────────┴────────────┴──────────────┴────────────────┴────────────────────────╯

Parser Metrics:
╭─────────────────────────────────┬─────────┬─────────┬──────────╮
│             Parsers             │  Hits   │ Parsed  │ Unparsed │
├─────────────────────────────────┼─────────┼─────────┼──────────┤
│ child-crowdsecurity/sshd-logs   │ 60      │ -       │ 60       │
│ child-crowdsecurity/syslog-logs │ 6       │ 6       │ -        │
│ crowdsecurity/non-syslog        │ 130.25k │ 130.25k │ -        │
│ crowdsecurity/sshd-logs         │ 6       │ -       │ 6        │
│ crowdsecurity/syslog-logs       │ 6       │ 6       │ -        │
╰─────────────────────────────────┴─────────┴─────────┴──────────╯

Local Api Metrics:
╭──────────────────────┬────────┬───────╮
│        Route         │ Method │ Hits  │
├──────────────────────┼────────┼───────┤
│ /v1/alerts           │ GET    │ 1     │
│ /v1/alerts           │ POST   │ 6     │
│ /v1/decisions/stream │ GET    │ 11337 │
│ /v1/heartbeat        │ GET    │ 8053  │
│ /v1/watchers/login   │ POST   │ 145   │
╰──────────────────────┴────────┴───────╯

Local Api Machines Metrics:
╭─────────┬───────────────┬────────┬──────╮
│ Machine │     Route     │ Method │ Hits │
├─────────┼───────────────┼────────┼──────┤
│ app     │ /v1/heartbeat │ GET    │ 1587 │
│ auth    │ /v1/alerts    │ GET    │ 1    │
│ auth    │ /v1/alerts    │ POST   │ 6    │
│ auth    │ /v1/heartbeat │ GET    │ 1605 │
│ fw      │ /v1/heartbeat │ GET    │ 1621 │
│ infra   │ /v1/heartbeat │ GET    │ 1620 │
│ vmm     │ /v1/heartbeat │ GET    │ 1620 │
╰─────────┴───────────────┴────────┴──────╯

Local Api Bouncers Metrics:
╭───────────────┬──────────────────────┬────────┬──────╮
│    Bouncer    │        Route         │ Method │ Hits │
├───────────────┼──────────────────────┼────────┼──────┤
│ caddy-bouncer │ /v1/decisions/stream │ GET    │ 1608 │
│ fw-bouncer    │ /v1/decisions/stream │ GET    │ 9729 │
╰───────────────┴──────────────────────┴────────┴──────╯

Local Api Decisions:
╭─────────────────┬────────┬────────┬───────╮
│     Reason      │ Origin │ Action │ Count │
├─────────────────┼────────┼────────┼───────┤
│ http:exploit    │ CAPI   │ ban    │ 17803 │
│ http:scan       │ CAPI   │ ban    │ 4583  │
│ ssh:bruteforce  │ CAPI   │ ban    │ 2509  │
│ http:bruteforce │ CAPI   │ ban    │ 1721  │
│ http:crawl      │ CAPI   │ ban    │ 87    │
│ http:dos        │ CAPI   │ ban    │ 15    │
╰─────────────────┴────────┴────────┴───────╯

Local Api Alerts:
╭───────────────────────────────────┬───────╮
│              Reason               │ Count │
├───────────────────────────────────┼───────┤
│ crowdsecurity/http-bad-user-agent │ 2     │
│ crowdsecurity/jira_cve-2021-26086 │ 4     │
╰───────────────────────────────────┴───────╯

### WAF parser alerts

auth@auth:~$ sudo cscli alerts list
╭────┬────────────────────┬───────────────────────────────────┬─────────┬────┬───────────┬─────────────────────────────────────────╮
│ ID │       value        │              reason               │ country │ as │ decisions │               created_at                │
├────┼────────────────────┼───────────────────────────────────┼─────────┼────┼───────────┼─────────────────────────────────────────┤
│ 25 │ Ip:206.168.34.127  │ crowdsecurity/http-bad-user-agent │         │    │ ban:1     │ 2026-03-07 02:26:58.074029091 +0000 UTC │
│ 23 │ Ip:162.142.125.212 │ crowdsecurity/http-bad-user-agent │         │    │ ban:1     │ 2026-03-07 00:19:08.421713824 +0000 UTC │
│ 12 │ Ip:159.65.144.72   │ crowdsecurity/jira_cve-2021-26086 │         │    │ ban:1     │ 2026-03-06 04:19:04.975124762 +0000 UTC │
│ 11 │ Ip:206.189.95.232  │ crowdsecurity/jira_cve-2021-26086 │         │    │ ban:1     │ 2026-03-06 04:19:01.215582087 +0000 UTC │
│ 10 │ Ip:68.183.9.16     │ crowdsecurity/jira_cve-2021-26086 │         │    │ ban:1     │ 2026-03-06 04:18:22.120468981 +0000 UTC │
│ 9  │ Ip:138.68.144.227  │ crowdsecurity/jira_cve-2021-26086 │         │    │ ban:1     │ 2026-03-06 04:18:18.35776077 +0000 UTC  │
╰────┴────────────────────┴───────────────────────────────────┴─────────┴────┴───────────┴─────────────────────────────────────────╯

## Log check and inspect

fw@fw:~$ sudo cscli alerts inspect 230 -d

- check the log and analyze and make expression
  - e.g. immich
    - evt.Meta.target_fqdn == 'immich.ilnmors.com' && evt.Meta.http_path contains '/api/assets/' && evt.Meta.http_path contains '/thumbnail'

