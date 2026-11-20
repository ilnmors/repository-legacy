sTags: #os, #firewall, #configuration, #network, #security 

## Suricata

Suricata is IPS(Intrusion Prevent System)/IDS(Intrusion Detection System) to supersede snort in 2010 from OISF for NSM(Network Security Monitoring). This program supports multi-thread and check the packet and even the programs (such as exe or shell script) in it based on rules. When the suricata find the packet matched with rule it has, it decides `pass; with alert`, `block` the packet.

### General setting in OPNsense

#### Enable Suricata

- Services:Intrusion Detection:Administration - Settings
    - \[\*\] Enabled
    - \[\*\] IPS mode
    - \[\*\] Promiscuous mode (Scan all traffic even L2 traffics)
    - Interfaces: Select ALL
    - Pattern matcher: Hyperscan (Intel's opensource regex matching library)

#### Rule set download and update

- Services:Intrusion Detection:Administration - Download

- Select the rule set below
    - ET open/botcc: List of bot net C&C server
    - ET open/compromised: List of known zombie PC
    - ET open/drop: List of certain malicious traffic
    - ET open/dshield: List of current activated malicious IP
    - ET open/emerging-attack_response: List of response after attack success
    - ET open/emerging-coinminer: List of coinminer malicious code
    - ET open/emerging-current_event: List of latest attack pattern
    - ET open/emerging-dns: List of malicious DNS query
    - ET open/emerging-exploit: List of attack towards software vulnerability
    - ET open/emerging-exploit_kit: List of automatic hacking tool
    - ET open/emerging-ja3: List of malicious programs'(tools, or browsers) finger print
    - ET open/emerging-malware: List of malware C&C server
    - ET open/emerging-mobile_malware: List of mobile malware C&C server
    - ET open/emerging-phishing: List of communication regard phishing
    - ET open/emerging-policy: List of non-standard or malicious TLS version or http traffics
    - ET open/emerging-scan: List of port scan or network scan traffic
    - ET open/emerging-shellcode: List of malicious attack shell script
    - ET open/emerging-sql: List of sql injection traffic
    - ET open/emerging-user_agent: List of malicious bot user-agent
    - ET open/emerging-web_client: List of attack towards web browser
    - ET open/emerging-web_server: List of attack towards web server
    - ET open/emerging-web_specific_apps: List of attack towards specific web application(like word press)
    - ET open/emerging-CS_c2: List of Cobalt Strike hacking tool
- `Enable selected`
- `Download & Update Rules`

> When you want to delete rule set, then select target rule and click `Disable selected` and `Download & Update Rules`

- Services:Intrusion Detection:Schedule
    - \[\*\] Enable update

#### Policy of rule set

Suricata rule set in OPNsense has basically `Alert` policy. Therefore, it is necessary to set rules as `Drop` manually. Except `ET open/emerging-ja3` and `ET open/emerging-policy`, it is good for security to drop all rule set. The reason why `ja3` and `policy` remain as `Alert` is they are not extremely dangerous, and they could drop normal packets frequently.

- Services:Intrusion Detection:Policy - Policies - \[+\]
    - Ruleset: All ruleset except `ja3` and `policy`
    - Action: Alert, Drop
    - New action: Drop
    - `Save`
- `Apply`

### Check the log

- Services:Intrusion Detection:Administration - Alerts

If suricata made the wrong action like block the normal packets or pass malicious packet, you can tune the ruleset. At the Alerts section, next to log there's Info column. When you click the pencil icon on info column, then you can change that rule's action in specific environment; source IP. It is a suppress.