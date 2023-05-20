#!/bin/bash

# Install bind9 package
apt-get install -y bind9

# Configure named.conf.local
named_conf_local_file="/etc/bind/named.conf.local"
named_conf_local_content=$(cat <<EOF
zone "GR5.server" {
    type master;
    file "/etc/bind/zones/db.GR5.server";
};

zone "0.22.172.in-addr.arpa" {
    type master;
    file "/etc/bind/zones/db.172.22";
};
EOF
)

# Write the zone configurations to named.conf.local
echo "$named_conf_local_content" > "$named_conf_local_file"

# Create zone files directory
zones_directory="/etc/bind/zones"
mkdir -p "$zones_directory"

# Create db.GR5.server zone file
db_example_file="$zones_directory/db.GR5.server"
db_example_content=$(cat <<EOF
\$TTL 86400
@   IN  SOA ns1.GR5.server. admin.GR5.server. (
            2023052001
            3600
            1800
            604800
            86400
)

@   IN  NS  ns1.GR5.server.
@   IN  NS  ns2.GR5.server.

ns1 IN  A   172.22.0.1
ns2 IN  A   172.22.0.2

www IN  A   172.22.0.10
EOF
)

# Write the content to db.GR5.server zone file
echo "$db_example_content" > "$db_example_file"

# Create db.172.22 reverse zone file
db_reverse_file="$zones_directory/db.172.22"
db_reverse_content=$(cat <<EOF
\$TTL 86400
@   IN  SOA ns1.GR5.server. admin.GR5.server. (
            2023052001
            3600
            1800
            604800
            86400
)

@   IN  NS  ns1.GR5.server.
@   IN  NS  ns2.GR5.server.

1   IN  PTR ns1.GR5.server.
2   IN  PTR ns2.GR5.server.
10  IN  PTR www.GR5.server.
EOF
)

# Write the content to db.172.22 reverse zone file
echo "$db_reverse_content" > "$db_reverse_file"

# Restart bind9 service
systemctl restart bind9
systemctl status bind9

echo "DNS server configuration completed."
