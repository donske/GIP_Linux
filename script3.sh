#!/bin/bash

# Update and upgrade packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y exa
apt-get install -y curl
apt-get install -y isc-dhcp-server
apt-get install -y ufw
apt-get install -y fail2ban
apt-get install -y clamav
apt-get install -y bmon
apt-get install -y apache2
apt-get install -y squid3
apt-get install -y iftop
apt-get install -y ntop
apt-get install -y vsftpd
apt-get install -y samba
apt-get install -y nfs-kernel-server

# Create user groups
groupadd zaakvoerder
groupadd klantenrelaties
groupadd administratie
groupadd IT_medewerker

# Function to create user
create_user() {
    local username=$1
    local full_name=$2
    local group=$3

    # Generate login name and password
    local login_name="${full_name%% *}"
    local password="${login_name,,}123"

    # Create user and set password
    useradd -m -c "$full_name" -s /bin/bash -g "$group" -p "$(mkpasswd -m sha-512 "$password")" "$login_name"
    chown -R "$login_name":"$group" "/home/$login_name"
}

# Prompt for user creation
for i in 1 2; do
    read -r -p "Please enter the full name for user $i: " name
    create_user "user$i" "$name" "zaakvoerder"
done

# Create additional users
create_user "tinevdv" "Tine Van de Velde" "klantenrelaties"
create_user "jorisq" "Joris Quataert" "administratie"
create_user "kimdw" "Kim De Waele" "IT_medewerker"

# Continue with the rest of the script...

# Configure network interfaces
interfaces_file="/etc/network/interfaces"
interfaces_content=$(cat <<EOF
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback

auto ens33
iface ens33 inet dhcp

auto ens36
iface ens36 inet static
   address 172.22.0.1
   netmask 255.255.0.0
EOF
)

# Backup the original file
cp "$interfaces_file" "$interfaces_file.bak"

# Write the new content to the file
echo "$interfaces_content" > "$interfaces_file"

# Configure ISC DHCP Server
dhcp_server_file="/etc/default/isc-dhcp-server"
dhcp_server_content=$(cat <<EOF
INTERFACESv4="ens36"
EOF
)

# Backup the original file
cp "$dhcp_server_file" "$dhcp_server_file.bak"

# Write the new content to the file
echo "$dhcp_server_content" > "$dhcp_server_file"

# Configure DHCPD Server
dhcpd_server_file="/etc/dhcp/dhcpd.conf"
dhcpd_server_content=$(cat <<EOF
option domain-name "GR5-Jarno-Alexi";
option domain-name-servers 172.22.0.1;

default-lease-time 600;
ddns-update-style none;

authoritative;

subnet 172.22.0.0 netmask 255.255.0.0 {
     range 172.22.0.10 172.22.0.50;
     option routers 172.22.0.1;
     option subnet-mask 255.255.0.0;
     default-lease-time 720;
}
EOF
)

# Backup the original file
cp "$dhcpd_server_file" "$dhcpd_server_file.bak"

# Write the new content to the file
echo "$dhcpd_server_content" > "$dhcpd_server_file"

# Enable ClamAV just-in-time scanning
setsebool -P clamd_use_jit 1

# Solution to the "clamav-freshclam.conf" file not found error
touch /etc/clamav/freshclam.conf

# Comment out the Example line in freshclam.conf
sed -i -e "s/^Example/#Example/" /etc/clamav/freshclam.conf

# Enable ClamAV and auditd services
systemctl enable clamav
systemctl enable auditd

# Restart services and check status
systemctl restart isc-dhcp-server
systemctl status isc-dhcp-server

systemctl restart apache2
systemctl status apache2

systemctl restart clamav-freshclam
systemctl status clamav-freshclam

systemctl restart squid
systemctl status squid

systemctl restart vsftpd
systemctl status vsftpd

systemctl restart smbd
systemctl status smbd

systemctl restart nfs-kernel-server
systemctl status nfs-kernel-server

echo "Script execution completed."
