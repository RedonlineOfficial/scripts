#!/bin/sh

# --- SCRIPT INIT --- #

# Check for sudo
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges. Please run with sudo." >&2
  exit 1  # Exit with error code 1
fi

# --- Update System --- #
apt update # update package lists
apt full-upgrade -y # runs a full system upgrade
apt autoremove -y # cleans up unused packages


# --- Create non-root user --- #
adminUser="redonline" # specifies the admin's username
useradd -m $adminUser # creates the user, -m forces the creation of the user's home directory
groupadd sshUsers # creates sshUsers group, this will be used later
usermod -aG sudo $adminUser # adds the user to the sudo group, allowing the user to run sudo commands
usermod -aG sshUsers $adminUser # adds the user to sshUsers, will be used later
passwd $adminUser #sets the user's password interactively
chsh -s /bin/bash redonline # changes the default shell to bash
sed -i '1s|/bin/bash|/sbin/nologin|' /etc/passwd # deactivate root login

touch /home/${adminUser}/.sudo_as_admin_successful # disables sudo prompt

# --- ssh and firewall (ufw) --- #
mkdir -p /home/${adminUser}/.ssh # creates the .ssh config directory for the admin user
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICdS2GAZwoyZtSBicr/wNEpAK7EDLgnI+fc/6/tZTBk" >> /home/${adminUser}/.ssh/authorized_keys # copies my public key to the server

# The following creates a file in the ssh config directory.  All files in this directory
# are included in the main config.  
# The config changes are commented in the file.
cat >/etc/ssh/sshd_config.d/secure.conf <<EOF
PermitRootLogin no # disables root login

PubkeyAuthentication yes # enables public key authentication

PasswordAuthentication no # disables password authentication
PermitEmptyPasswords no # disallows empty password fields

AllowUsers redonline # restricts users that can login via ssh
#AllowGroups sshUsers # restricts groups that can login via ssh

LoginGraceTime 30 # sets how long the server waits for authentication
MaxAuthTries 3 # sets how many authentication attempts are allowed
ClientAliveInterval 300 # sets how long a user can be idle, in seconds (300 = 1 minute)
ClientAliveCountMax 1 # sets how many times the server will check for idle (ClientAliveCountMax * ClientAliveInterval = How long a user can idle)

AllowTCPForwarding no # disables tcp forwarding
X11Forwarding no # disables x11 forwarding
AllowAgentForwarding no # disables agent forwarding

Banner none # disables banner
DebianBanner none # disables debian's banner
EOF

systemctl restart ssh # restarts the ssh daemon loading the new configs

# Firewall
ufw allow OpenSSH
ufw enable

# --- Time and Date --- #
timedatectl set-timezone America/Phoenix

# --- Fail2Ban --- #
apt install fail2ban
systemctl enable --now fail2ban

# --- Automatic Updates --- #
apt install -y unattended-upgrades
dpkg-reconfigure --priority=low unattended-upgrades

