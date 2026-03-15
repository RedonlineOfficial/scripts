#!/bin/bash

### update/upgrade
# update package lists
function updatePackageIndex() {
   echo "Updating package list"
   if ! apt update; then
      echo "ERR: Package list update failed"
      exit 1
   fi
   echo "Package list updated"
}
updatePackageIndex # run system update

# full system upgrade
echo "Peforming full system upgrade"
if ! apt full-upgrade -y; then
   echo "ERR: System could not be updated."
   exit 1
fi
echo "System successfully updated"

### package installation
corePackages=( "unattended-upgrades" "fail2ban" "ufw" "curl" "openssh" )
extraPackages=( "neovim" "git" )

updatePackageIndex

echo "Installing core packages"
for pkg in "${corePackages[@]}"; do
   apt install -y "$package"
done

echo "Installing extra packages"
for pkg in "${extraPackages[@]}"; do
   apt install -y "$package"
done

echo "All packages installed"


### automatic upgrades
echo "Setting up unattended upgrades"
EDITOR='sed -Ei "s|unattended-upgrades/enable_auto_updates=.+|unattended-upgrades/enable_auto_updates=\"yes\"|"' dpkg-reconfigure -f editor unattended-upgrades # this sets it non-interactively
echo "Unattended upgrades configured."

### configure timedatectl
timeZone="America/Phoenix"
echo "Configuring the time zone"
echo "Setting to $timeZone"
timedatectl set-timezone $timeZone
echo "Set timezone to $timeZone"

### account creation
adminUser="redonline"
adminGroup="sudo"

# check if user exists
echo "Checking if $adminUser exists"
if ! id $adminUser; then
   echo "User $adminUser does not exist"
   echo "Checking if there is a home directory for $adminUser"
   if [[ -d /home/$adminUser ]]; then
      echo "Home directory for $adminUser already exists."
      echo "Backing up and removing home directory"
      mv /home/$adminUser /home/$adminUser.bk
      echo "Moved existing home directory to /home/$adminUser.bk"
   else
      echo "No pre-existing home directory found."
   fi
   echo "Creating user account $adminUser"
   useradd -m $adminUser
   echo "Created account for $adminUser"
else
   echo "Account exists"
fi

# add user to sudo group
echo "Ensuring user is part of $adminGroup"
usermod -aG $adminGroup $adminUser

# set password
echo "Setting new account password"
passwd $adminUser
echo "Password set"

### lock root account
echo "Locking root account"
sed -i 's|/bin/bash|/sbin/nologin|' /etc/passwd
echo "Root account locked"

### security configuration
echo "Improving server security"
## firewall configuration
echo "Configuring the firewall (ufw)"
echo "Allowing the following ports: 22 (ssh), 80 (http), 443 (https)"
ufw allow ssh
ufw allow http
ufw allow https
echo "Enabling UFW"
ufw enable -f

## ssh hardening
echo "Configuring SSH"

echo "Creating /home/$adminUser/.ssh"
mkdir -p /home/$adminUser/.ssh

echo "Copying root's authorized keys to $adminUser"
cp /root/.ssh/authorized_keys /home/$adminUser/.ssh/

echo "Ensuring /etc/ssh/sshd_config.d exists"
mkdir -p /etc/ssh/sshd_config.d/

echo "Creating new config file /etc/ssh/sshd_config.d/security.conf"
mkdir -p /etc/ssh/sshd_config.d/
touch /etc/ssh/sshd_config.d/security.conf

cat >/etc/ssh/sshd_config.d/security.conf <<EOF
AuthenticationMethods publickey,password
Banner none
ClientAliveCountMax 2
ClientAliveInterval 300
DisableForwarding yes
LoginGraceTime 30
MaxSessions 3
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
PubkeyAuthentication yes
EOF

echo "ssh configured. Restarting daemon"
systemctl restart ssh

## fail2ban configuration
echo "Enabling Fail2Ban"
systemctl enable --now fail2ban

### clean up
echo "Cleaning up"
apt autoremove -y
apt autoclean

### Reboot
echo "Ubuntu server setup is complete"
while true; do
   read -p "Would you like to reboot now? (Y|n): " rebootAnswer
   rebootAnswer=${answer:-y}
   
   if [[ $answer == [Yy] ]]; then
      echo "The system will reboot now."
      break
   elif [[ $answer == [Nn] ]]; then
      echo "It is highly recommended that the system is rebooted. Exiting..."
      exit 0
   else
      echo "Invalid option. Please enter Y for Yes or N for No."
   fi
done

reboot
