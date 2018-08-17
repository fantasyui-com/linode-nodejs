#!/bin/bash
#
#<UDF name="ssuser" Label="Sudo user username?" example="administrator" default="administrator"/>
#<UDF name="sspassword" Label="Sudo user password?" example="6bba3c13c40f57b8ee387345ddd30838136bf065" />
#<UDF name="sspubkey" Label="SSH pubkey (installed for root and sudo user)?" example="execute cat ~/.ssh/id_rsa.pub" />

if [[ ! $SSUSER ]]; then read -p "Sudo user username?" SSUSER; fi
if [[ ! $SSPASSWORD ]]; then read -p "Sudo user password?" SSPASSWORD; fi
if [[ ! $SSPUBKEY ]]; then read -p "SSH pubkey (installed for root and sudo user)?" SSPUBKEY; fi

# set up sudo user
echo Creating nodejs user: $SSUSER...
useradd $SSUSER && echo $SSPASSWORD | passwd $SSUSER --stdin
usermod -aG wheel $SSUSER
echo ...done
# sudo user complete

# setup node user
echo Creating nodejs user: nodejs
sudo useradd -d /home/nodejs -m nodejs


# set up ssh pubkey
# for x in... loop doesn't work here, sadly
echo Setting up ssh pubkeys...
mkdir -p /root/.ssh
mkdir -p /home/$SSUSER/.ssh
echo "$SSPUBKEY" >> /root/.ssh/authorized_keys
echo "$SSPUBKEY" >> /home/$SSUSER/.ssh/authorized_keys
chmod -R 700 /root/.ssh
chmod -R 700 /home/${SSUSER}/.ssh
chown -R ${SSUSER}:${SSUSER} /home/${SSUSER}/.ssh
echo ...done

# disable password and root over ssh
echo Disabling passwords and root login over ssh...
sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
echo Restarting sshd...
systemctl restart sshd
echo ...done

#remove unneeded services
echo Removing unneeded services...
yum remove -y avahi chrony
echo ...done

# Initial needfuls
yum update -y
yum install -y epel-release
yum update -y

# Set up automatic  updates
echo Setting up automatic updates...
yum install -y yum-cron
sed -i -e "s/apply_updates = no/apply_updates = yes/" /etc/yum/yum-cron.conf
echo ...done
# auto-updates complete

#set up fail2ban
echo Setting up fail2ban...
yum install -y fail2ban
cd /etc/fail2ban
cp fail2ban.conf fail2ban.local
cp jail.conf jail.local
sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban
echo ...done

# set up firewalld
echo Setting up firewalld...
systemctl start firewalld
systemctl enable firewalld

# Use public zone
firewall-cmd --set-default-zone=public
firewall-cmd --zone=public --add-interface=eth0

firewall-cmd --zone=public --add-port=80/tcp --permanent; # Public Port 80, used in port masquerade
firewall-cmd --zone=public --add-port=443/tcp --permanent; # Public Port 443, used in port masquerade
firewall-cmd --zone=public --add-masquerade --permanent; # 80 -> 8080 masquerade
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent;
firewall-cmd --zone=public --add-forward-port=port=443:proto=tcp:toport=8443 --permanent;

firewall-cmd --reload
echo ...done
#
# Set up distro kernel and grub
yum install -y kernel grub2
sed -i -e "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=10/" /etc/default/grub
sed -i -e "s/crashkernel=auto rhgb console=ttyS0,19200n8/console=ttyS0,19200n8/" /etc/default/grub
mkdir /boot/grub
grub2-mkconfig -o /boot/grub/grub.cfg

# ensure ntp is installed and running
yum install -y ntp
systemctl enable ntpd
systemctl start ntpd

# install node
curl --silent --location https://rpm.nodesource.com/setup_10.x | bash -
yum -y install nodejs
setcap 'cap_net_bind_service=+ep' $(readlink -f $(which node))

      # do things as nodejs
      sudo su - nodejs

      npm i -g pm2

      # enter /home/nodejs
      cd ~

      mkdir server
      cd server
      echo "require('bonsoir');" > server.js
      npm init -y # this detects server.js and adds it into npm run
      npm i bonsoir
      
      # npm start

      # exit the su session
      exit


#
echo All finished! Rebooting...
(sleep 5; reboot) &
