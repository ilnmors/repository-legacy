# WireGuard key get

```bash
wg genkey | tee /run/user/$UID/server_private.key | wg pubkey | tee /run/user/$UID/server_pub.key
wg genkey | tee /run/user/$UID/client_private.key | wg pubkey | tee /run/user/$UID/client_pub.key
wg genpsk | tee /run/user/$UID/preshared.key
# Save the key files content in `secrets.yaml`

# Client wireguard setting

[Interface]
PrivateKey = client_private.key
Address = 192.168.99.20/32, fd00:99::20/128
DNS = 192.168.10.2, fd00:10::2

[Peer]
PublicKey = server_pub.key
PresharedKey = preshared.key
AllowedIPs = 192.168.0.0/16, fd00::/8
Endpoint = vpn.ilnmors.com:11290
PersistentKeepalive = 25

```
