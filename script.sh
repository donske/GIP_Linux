#!/bin/bash

# Update and upgrade packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y fish exa curl isc-dhcp-server bind9 bind9-doc ufw fail2ban clamav bmon apache2 squid3 iftop ntop vsftpd samba nfs-kernel-server

# Copy Fish shell configuration
mkdir -p /root/.config/fish
cp config.fish /root/.config/fish/config.fish

# Change the default shell for root user to Fish
chsh -s /usr/bin/fish root

# Install Starship prompt
curl -fsSL https://starship.rs/install.sh | bash

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

# Comment out the Example line in freshclam.conf
sed -i -e "s/^Example/#Example/" /etc/clamav/freshclam.conf

# Enable ClamAV and auditd services
systemctl enable clamav auditd

# Configure Apache web server for individual user webpages
sed -i 's/\/var\/www\/html/\/home/' /etc/apache2/sites-available/000-default.conf
sed -i 's/#ServerName www.example.com/ServerName GR5-Jarno-Alexi/' /etc/apache2/sites-available/000-default.conf
a2enmod userdir
systemctl restart apache2

# Enable and start Squid proxy server
systemctl enable squid
systemctl start squid

# Configure UFW (Uncomplicated Firewall)
ufw --force enable
ufw allow OpenSSH
ufw allow 'Apache Full'
ufw allow 'Samba'
ufw allow 'NFS'
systemctl enable --now ufw

# Configure FTP server (vsftpd)
sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
sed -i 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf

# Configure SMB/Samba server
# Edit /etc/samba/smb.conf as per your requirements

# Configure NFS server
# Edit /etc/exports as per your requirements

# Restart services
systemctl restart isc-dhcp-server bind9 apache2 clamav-freshclam squid vsftpd smbd nfs-kernel-server

echo "Script execution completed."
