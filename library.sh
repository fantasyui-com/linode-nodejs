#!/bin/bash
#
# Uses some code from StackScript Bash Library

###########################################################
# utils
###########################################################

function system_primary_ip {
  # returns the primary IP assigned to eth0
  echo $(ifconfig eth0 | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }')
}

function randomString {
    if [ ! -n "$1" ];
        then LEN=20
        else LEN="$1"
    fi
    echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c $LEN) # generate a random string
}

###########################################################
# functions
###########################################################


function system_update {
  # runs update
  yum update;
}

function system_autoupdate {
  # schedules automatic updates
  
  yum -y install yum-cron
  sed -i -e "s/update_cmd = default/update_cmd = security/" /etc/yum/yum-cron.conf
  sed -i -e "s/apply_updates = no/apply_updates = yes/" /etc/yum/yum-cron.conf
  
  systemctl enable yum-cron
  systemctl start yum-cron
  systemctl status yum-cron
}

function user_add_sudo {
  # Installs sudo if needed and creates a user in the sudo group.
  #
  # $1 - Required - username
  # $2 - Required - password
  USERNAME="$1"
  USERPASS="$2"

  if [ ! -n "$USERNAME" ] || [ ! -n "$USERPASS" ]; then
      echo "No new username and/or password entered"
      return 1;
  fi

  yum -y install sudo
  adduser $USERNAME 
  echo "$USERNAME:$USERPASS" | chpasswd
  usermod -aG wheel $USERNAME
  # passwd -l $USERNAME # lock user (disable login) from now on use `su - username`
}

function user_add_pubkey {
    # Adds the users public key to authorized_keys for the specified user. Make sure you wrap your input variables in double quotes, or the key may not load properly.
    #
    #
    # $1 - Required - username
    # $2 - Required - public key
    USERNAME="$1"
    USERPUBKEY="$2"
    
    if [ ! -n "$USERNAME" ] || [ ! -n "$USERPUBKEY" ]; then
        echo "Must provide a username and the location of a pubkey"
        return 1;
    fi
    
    if [ "$USERNAME" == "root" ]; then
        mkdir /root/.ssh
        echo "$USERPUBKEY" >> /root/.ssh/authorized_keys
        return 1;
    fi
    
    mkdir -p /home/$USERNAME/.ssh
    echo "$USERPUBKEY" >> /home/$USERNAME/.ssh/authorized_keys
    chown -R "$USERNAME":"$USERNAME" /home/$USERNAME/.ssh
}

function ssh_disable_root {
  # Disables root SSH access, root user will not be able to login. Login as normal user and then sudo -s to gain root powers
  sed -i -e "s/^#*PermitRootLogin.*$/PermitRootLogin no/" /etc/ssh/sshd_config;
  systemctl restart sshd
}

function ssh_disable_password_authentication {
  # Disables use of passwords from now on ensure that /home/******/.ssh/authorized_keys contains your ~/.ssh/id_rsa.pub
  sed -i -e "s/^#*PasswordAuthentication.*$/PasswordAuthentication no/" /etc/ssh/sshd_config
  systemctl restart sshd
}



###########################################################
# nodejs
###########################################################

function nodejs_install {
  # This uses the EPEL (Extra Packages for Enterprise Linux) repository that is available for CentOS.
  # To gain access to the EPEL repo, we install a package available in our current repos called epel-release.
  yum -y install epel-release
  yum update -y
  yum -y install nodejs
  yum -y install npm
  npm install -g http-server
  npm install -g pm2
  setcap 'cap_net_bind_service=+ep' $(readlink -f $(which node))
}



function https_masquerade_firewall {
  systemctl start firewalld
  systemctl enable firewalld

  # Use public zone
  firewall-cmd --set-default-zone=public
  firewall-cmd --zone=public --add-interface=eth0

  firewall-cmd --zone=public --add-port=80/tcp --permanent; # Public Port 80, used in port masquerade
  firewall-cmd --zone=public --add-port=81/tcp --permanent; # for developers and stats...
  firewall-cmd --zone=public --add-port=82/tcp --permanent; # for developers and stats...

  firewall-cmd --zone=public --add-port=443/tcp --permanent; # Public Port 443, used in port masquerade
  firewall-cmd --zone=public --add-masquerade --permanent; # 80 -> 8080 masquerade

  firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent;
  firewall-cmd --zone=public --add-forward-port=port=81:proto=tcp:toport=8081 --permanent;
  firewall-cmd --zone=public --add-forward-port=port=82:proto=tcp:toport=8082 --permanent;

  firewall-cmd --zone=public --add-forward-port=port=443:proto=tcp:toport=8443 --permanent;

  firewall-cmd --reload
}

function setup_kernel_and_grub {
  #
  # Set up distro kernel and grub
  yum install -y kernel grub2
  sed -i -e "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=10/" /etc/default/grub
  sed -i -e "s/crashkernel=auto rhgb console=ttyS0,19200n8/console=ttyS0,19200n8/" /etc/default/grub
  mkdir /boot/grub
  grub2-mkconfig -o /boot/grub/grub.cfg
}

function ntp_install {
  # ensure ntp is installed and running
  yum install -y ntp
  systemctl enable ntpd
  systemctl start ntpd
  systemctl status ntpd
}

function tweaks {
    # Installs the REAL vim, wget, less, and enables color root prompt and the "ll" list long alias
    yum -y install wget vim less
    yum remove -y avahi chrony
    sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt
    sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3
}
