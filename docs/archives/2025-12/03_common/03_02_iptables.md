Tags: #common, #configuration, #network, #security 

## iptables

iptables is the firewall program to manage netfilter which is in the linux kernel. Basically, the iptables' settings are temporary(when you reboot the computer they disappear). So, you can use netfilter-persistent program to make settings permanent. iptables has 3 modes(tables), which are filter, nat, and mangle. And each table has their chain like input, forward or prerouting, etc. iptables' setting is temporary, when the machine reboot, all rules will be reset. After set the rules use `netfilter-persistent save` to make the rules permanently.

### tables

#### filter

filter is the basic and most important table in iptables. Its role is to simply judge, to ACCEPT or DROP the packets. When you use the iptables command without table option (-t), the filter table is default option. There are chians of filter table below.

- INPUT: check the packets in
- OUTPUT: check the packets out
- FORWARD: check the packets which are passing through

#### nat

nat is the table changing packets' address and port without changing contents of packets. There are chians of nat table below.

- PREROUTING: change the destination address or port right after packets arrived
- POSTROUTING: change the source address or port before packets depart
- OUTPUT: change the destination address or port of packets which produced by itself (This doesn't change the source IP; DNAT)

#### mangle

mangle is a special table to mark on the packets. It works on the every chain and it works on special purpose like asymmetric routing.

### grammar

#### Commands

- -A \[--append\]: create the new rules
- -C \[--check\]: check the packets
- -D \[--delete\]: delete the rules
- -F \[--flush\]: delete all rules from the chain
- -I \[--insert\]: Insert the new rules
- -L \[--list\]: print the rules
- -N \[--new\]: create the new chain
- -P \[--policy\]: change the default policy
- -R \[--replace\]: change the rules as a new rule
- -X \[--delete-chain\]: delete chain
- -Z \[--zero\]: reset the packet and byte counter value of all chain

#### match

- -s \[--source\]: designate source ip address or networks
- -d \[--destination\]: designate destination ip address or networks
- -p \[--protocol\]: match protocol(tcp/udp/icmp.. etc.)
    - --dport: designate specific protocol number (When the protocol is already defined - tcp or udp)
    - --syn: match syn packets. when starting new TCP connection, apply the rule.
- -i \[--in-interface\]: input interface
- -o \[--out-interface\]: output interface
- --comment: comment(max 256byte)
- -f \[--fragment\]
- -t \[--table\]: designate table set(default: filter)
- -j \[--jump\]: designate targets
- -m \[--match\]: match with specific module
    - conntrack --ctstate: current linked connection

#### target

- ACCEPT: allow packets
- DROP: deny packets without response (Hide server existence)
- REJECT: deny packets with response (Show server existance)
- LOG: log the packets on syslog
- RETURN: stop current rules, and return to the previous chain

#### Command

```bash
iptables -L -v -n # Print all rules in filter table
iptables -L -v -n -t nat # Print all rules in nat table
```

## netfilter-persistent

### Save the rules

```bash
sudo netfilter-persistent save
```

- File:
    - /etc/iptables/rules.v4
    - /etc/iptables/rules.v6

### Reload the rules (manual)

```bash
# Edit the file
# Test
sudo bash -c 'iptables-restore --test < /etc/iptables/rules.v4'
# If there were no message, it would have no error
sudo netfilter-persistent start
# or
sudo netfilter-persistent reload
```

### Rule files

- File: /etc/iptables/rules.v4
#### Hypervisor (vmm)

```ini
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "allow established connection" -j ACCEPT
-A INPUT -i lo -m comment --comment "allow local connection" -j ACCEPT
-A INPUT -p icmp -m comment --comment "allow ICMP connection" -j ACCEPT
-A INPUT -s 192.168.1.11/32 -p tcp -m tcp --dport 22 -m comment --comment "allow emergemcy LAN console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.2/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.3/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.4/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 22 -m comment --comment "allow code-server ssh connection" -j ACCEPT
COMMIT
```

#### net

```ini
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "allow established connection" -j ACCEPT
-A INPUT -i lo -m comment --comment "allow local connection" -j ACCEPT
-A INPUT -p icmp -m comment --comment "allow ICMP connection" -j ACCEPT
-A INPUT -s 10.10.10.2/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.3/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.4/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 22 -m comment --comment "allow OPNsense ssh connection for ACME update" -j ACCEPT
-A INPUT -s 192.168.10.10/32 -p tcp -m tcp --dport 22 -m comment --comment "allow hypervisor ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 22 -m comment --comment "allow code-server ssh connection" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2053 -m conntrack --ctorigdstport 53 -m comment --comment "allow tcp DNS connection which is only prerouted from 53" -j ACCEPT
-A INPUT -p udp -m udp --dport 2053 -m conntrack --ctorigdstport 53 -m comment --comment "allow udp DNS connection which is only prerouted from 53" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2443 -m conntrack --ctorigdstport 443 -m comment --comment "allow tcp DoH(https) connection which is only prerouted from 443" -j ACCEPT
-A INPUT -p udp -m udp --dport 2443 -m conntrack --ctorigdstport 443 -m comment --comment "allow udp DoH(https) connection which is only prerouted from 443" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 2253 -m comment --comment "allow opnsense tcp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p udp -m udp --dport 2253 -m comment --comment "allow opnsense udp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.12/32 -p tcp -m tcp --dport 2253 -m comment --comment "allow auth tcp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.12/32 -p udp -m udp --dport 2253 -m comment --comment "allow auth udp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 2253 -m comment --comment "allow dev tcp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p udp -m udp --dport 2253 -m comment --comment "allow dev udp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.14/32 -p tcp -m tcp --dport 2253 -m comment --comment "allow app tcp nsupdate connection" -j ACCEPT
-A INPUT -s 192.168.10.14/32 -p udp -m udp --dport 2253 -m comment --comment "allow app udp nsupdate connection" -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 53 -m comment --comment "allow and preroute tcp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A PREROUTING -p udp -m udp --dport 53 -m comment --comment "allow and preroute udp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A PREROUTING -p tcp -m tcp --dport 443 -m comment --comment "allow and preroute tcp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
-A PREROUTING -p udp -m udp --dport 443 -m comment --comment "allow and preroute udp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 53 -m comment --comment "NAT local tcp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A OUTPUT -d 127.0.0.1/32 -p udp -m udp --dport 53 -m comment --comment "NAT local udp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A OUTPUT -d 192.168.10.11/32 -p tcp -m tcp --dport 53 -m comment --comment "NAT local tcp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A OUTPUT -d 192.168.10.11/32 -p udp -m udp --dport 53 -m comment --comment "NAT local udp DNS connection 53 to 2053" -j REDIRECT --to-ports 2053
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p udp -m udp --dport 443 -m comment --comment "NAT local udp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 192.168.10.11/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 192.168.10.11/32 -p udp -m udp --dport 443 -m comment --comment "NAT local udp DoH(https) connection 443 to 2443" -j REDIRECT --to-ports 2443
COMMIT
```

#### auth

```ini
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [204:15800]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "allow established connection" -j ACCEPT
-A INPUT -i lo -m comment --comment "allow local connection" -j ACCEPT
-A INPUT -p icmp -m comment --comment "allow ICMP connection" -j ACCEPT
-A INPUT -s 10.10.10.2/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.3/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.4/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 22 -m comment --comment "allow OPNsense ssh connection for ACME update" -j ACCEPT
-A INPUT -s 192.168.10.10/32 -p tcp -m tcp --dport 22 -m comment --comment "allow hypervisor ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 22 -m comment --comment "allow code-server ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 9000 -m comment --comment "allow opnsense step-ca connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 9000 -m comment --comment "allow dev step-ca connection" -j ACCEPT
-A INPUT -s 192.168.10.14/32 -p tcp -m tcp --dport 9000 -m comment --comment "allow app step-ca connetcion" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2080 -m conntrack --ctorigdstport 80 -m comment --comment "allow tcp http connection which is only from 80" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2443 -m conntrack --ctorigdstport 443 -m comment --comment "allow tcp https connection which is only from 443" -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 80 -m comment --comment "allow and preroute tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A PREROUTING -p tcp -m tcp --dport 443 -m comment --comment "allow and preroute tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 192.168.10.12/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 192.168.10.12/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 636 -m comment --comment "NAT local tcp ldaps connection 636 to 6360" -j REDIRECT --to-ports 6360
-A OUTPUT -d 192.168.10.12/32 -p tcp -m tcp --dport 636 -m comment --comment "NAT local tcp ldaps connection 636 to 6360" -j REDIRECT --to-ports 6360
COMMIT
```

#### dev

```ini
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "allow established connection" -j ACCEPT
-A INPUT -i lo -m comment --comment "allow local connection" -j ACCEPT
-A INPUT -p icmp -m comment --comment "allow ICMP connection" -j ACCEPT
-A INPUT -s 10.10.10.2/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.3/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.4/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 22 -m comment --comment "allow OPNsense ssh connection for ACME update" -j ACCEPT
-A INPUT -s 192.168.10.10/32 -p tcp -m tcp --dport 22 -m comment --comment "allow hypervisor ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.12/32 -p tcp -m tcp --dport 5432 -m comment --comment "allow auth postgresql connection" -j ACCEPT
-A INPUT -s 192.168.10.14/32 -p tcp -m tcp --dport 5432 -m comment --comment "allow app postgresql connection" -j ACCEPT
-A INPUT -s 192.168.10.12/32 -p tcp -m tcp --dport 2080 -m conntrack --ctorigdstport 80 -m comment --comment "allow tcp http connection which is only from 80 and main caddy" -j ACCEPT
-A INPUT -s 192.168.10.12/32 -p tcp -m tcp --dport 2443 -m conntrack --ctorigdstport 443 -m comment --comment "allow tcp https connection which is only from 443 and main caddy" -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 80 -m comment --comment "allow and preroute tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A PREROUTING -p tcp -m tcp --dport 443 -m comment --comment "allow and preroute tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 192.168.10.13/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 192.168.10.13/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
COMMIT
```

#### app

```ini
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -m comment --comment "allow established connection" -j ACCEPT
-A INPUT -i lo -m comment --comment "allow local connection" -j ACCEPT
-A INPUT -p icmp -m comment --comment "allow ICMP connection" -j ACCEPT
-A INPUT -s 10.10.10.2/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.3/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 10.10.10.4/32 -p tcp -m tcp --dport 22 -m comment --comment "allow vpn console ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.1/32 -p tcp -m tcp --dport 22 -m comment --comment "allow OPNsense ssh connection for ACME update" -j ACCEPT
-A INPUT -s 192.168.10.10/32 -p tcp -m tcp --dport 22 -m comment --comment "allow hypervisor ssh connection" -j ACCEPT
-A INPUT -s 192.168.10.13/32 -p tcp -m tcp --dport 22 -m comment --comment "allow code-server ssh connection" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2080 -m conntrack --ctorigdstport 80 -m comment --comment "allow tcp http connection which is only from 80" -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2443 -m conntrack --ctorigdstport 443 -m comment --comment "allow tcp https connection which is only from 443" -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -p tcp -m tcp --dport 80 -m comment --comment "allow and preroute tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A PREROUTING -p tcp -m tcp --dport 443 -m comment --comment "allow and preroute tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 192.168.10.14/32 -p tcp -m tcp --dport 80 -m comment --comment "NAT local tcp http connection 80 to 2080" -j REDIRECT --to-ports 2080
-A OUTPUT -d 127.0.0.1/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
-A OUTPUT -d 192.168.10.14/32 -p tcp -m tcp --dport 443 -m comment --comment "NAT local tcp https connection 443 to 2443" -j REDIRECT --to-ports 2443
COMMIT
```