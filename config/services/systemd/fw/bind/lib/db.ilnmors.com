$TTL    86400

@           IN SOA bind.ilnmors.internal. mail.ilnmors.internal. (
                2026021201 ; serial
                3600       ; refresh (1 hour)
                1800       ; retry (30 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
            )
            IN      NS      bind.ilnmors.internal.
@           IN      A       192.168.10.12
@           IN      AAAA    fd00:10::12
*           IN      A       192.168.10.12
*           IN      AAAA    fd00:10::12
