#!/bin/sh

# --- SCRIPT INIT --- #

# Check for sudo
echo "Checking for escalated privledges..."
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script requires root privileges. Please run with sudo." >&2
  exit 1  # Exit with error code 1
fi
echo "Esclated privledges confirmed, continuing"
echo ""
echo "============================================================================"
echo ""

# --- Update System --- #
echo "Running system update"
apt update # update package lists
apt full-upgrade -y # runs a full system upgrade
echo "System update complete."
echo ""
echo "============================================================================"
echo ""

# --- Create non-root user --- #
adminUser="redonline" # specifies the admin's username
echo "Creating non-root admin user "$adminUser"."
useradd -m $adminUser # creates the user, -m forces the creation of the user's home directory
usermod -aG sudo $adminUser # adds the user to the sudo group, allowing the user to run sudo commands
usermod -aG sshUsers $adminUser # adds the user to sshUsers, will be used later
echo ""
echo "Please create a password for this user."
passwd $adminUser #sets the user's password interactively
echo ""
chsh -s /bin/bash redonline # changes the default shell to bash
echo "Disabling root account"
sed -i '1s|/bin/bash|/sbin/nologin|' /etc/passwd # deactivate root login

touch /home/${adminUser}/.sudo_as_admin_successful # disables sudo prompt

echo "Moving ssh keys to new user"
mkdir -p /home/${adminUser}/.ssh
cat /root/.ssh/authorized_keys > /home/${adminUser}/.ssh/authorized_keys

echo ""
echo "============================================================================"
echo ""


# --- ssh and firewall (ufw) --- #
echo "Setting up ssh configuration"
#mkdir -p /home/${adminUser}/.ssh # creates the .ssh config directory for the admin user
#echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICdS2GAZwoyZtSBicr/wNEpAK7EDLgnI+fc/6/tZTBk" >> /home/${adminUser}/.ssh/authorized_keys # copies my public key to the server
#
# The following creates a file in the ssh config directory.  All files in this directory
# are included in the main config.  
# The config changes are commented in the file.
cat >/etc/ssh/sshd_config.d/secure.conf <<EOF
PermitRootLogin no # disables root login

PubkeyAuthentication yes # enables public key authentication

PasswordAuthentication no # disables password authentication
PermitEmptyPasswords no # disallows empty password fields

AllowUsers redonline # restricts users that can login via ssh

LoginGraceTime 30 # sets how long the server waits for authentication
MaxAuthTries 3 # sets how many authentication attempts are allowed
ClientAliveInterval 300 # sets how long a user can be idle, in seconds (300 = 1 minute)
ClientAliveCountMax 1 # sets how many times the server will check for idle (ClientAliveCountMax * ClientAliveInterval = How long a user can idle)

AllowTCPForwarding no # disables tcp forwarding
X11Forwarding no # disables x11 forwarding
AllowAgentForwarding no # disables agent forwarding
EOF

echo "Restart ssh..."
systemctl restart ssh # restarts the ssh daemon loading the new configs
echo "ssh service restarted."
echo ""
echo "============================================================================"
echo ""

# Firewall
echo "Setting up firewall."
ufw allow OpenSSH # sets ufw to allow OpenSSH ports
ufw --force enable # enables the firewall
echo "Firewall enabled."
echo ""
echo "============================================================================"
echo ""

# --- Time and Date --- #
echo "Setting the correct timezone"
timedatectl set-timezone America/Phoenix # sets server's time zone
timedatectl
echo ""
echo "============================================================================"
echo ""

# --- Fail2Ban --- #
echo "Installing Fail2Ban"
# Using fail2ban to mitigate spam.  also using the default settings, should be fine
apt install fail2ban -y # installs fail2ban
echo ""
echo "Fail2Ban installed, configuring..."
systemctl enable --now fail2ban # enables fail2ban
echo "Fail2Ban configured."
echo ""
echo "============================================================================"
echo ""

# --- Automatic Updates --- #
echo "Installing unattended-upgrades for automatic system updates"
apt install unattended-upgrades -y # installs the package
echo ""
echo "Fail2Ban installed, configuring..."

# there is an annoying interactive pop-up that asks if you would like to enable automatic updates
# it takes the default, or prompts if blank.  the config ships with that option blank, thus the prompt.
# the following command edits the config to yes so that the question is skipped.
EDITOR='sed -Ei "s|unattended-upgrades/enable_auto_updates=.+|unattended-upgrades/enable_auto_updates=\"yes\"|"' dpkg-reconfigure -f editor unattended-upgrades
echo "Unattended Upgrades configured."
echo ""
echo "============================================================================"
echo ""

# --- Installing other useful packages --- #
echo "Installing other utilities..."
apt install -y \
	git \
	curl \
	neovim \
	htop \
echo "Install complete. Cleaning up..."

# --- Clean up --- #
apt autoremove -y
apt autoclean

echo "Clean up complete."

# --- Done --- #
echo "This system is now setup for production."
echo "Before any other changes are made, it is highly recommended"
echo "that the system is rebooted. This will NOT be done automatically and"
echo "is entirely up to the user."

