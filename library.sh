#!/bin/bash
#
# Uses code from StackScript Bash Library

function system_update {
  # runs update
  yum update;
}

function system_autoupdate {
  # schedules automatic updates
  /sbin/chkconfig --level 345 yum on; /sbin/service yum start
}

function system_primary_ip {
  # returns the primary IP assigned to eth0
  echo $(ifconfig eth0 | awk -F: '/inet addr:/ {print $2}' | awk '{ print $1 }')
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
    adduser $USERNAME --disabled-password --gecos ""
    echo "$USERNAME:$USERPASS" | chpasswd
    usermod -aG sudo $USERNAME
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
    # Disables root SSH access.
  sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
  sed -i -e "s/#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
  touch /tmp/restart-ssh
}

function ssh_disable_password_authentication {
  sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
  sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
  touch /tmp/restart-ssh
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


###########################################################
# fail2ban
###########################################################

function fail2ban_install {
  yum install -y fail2ban
  cd /etc/fail2ban
  cp fail2ban.conf fail2ban.local
  cp jail.conf jail.local
  sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
  systemctl enable fail2ban
  systemctl start fail2ban
}

function https_masquerade_firewall {
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
}




function tweaks {
    # Installs the REAL vim, wget, less, and enables color root prompt and the "ll" list long alias

    yum -y install wget vim less
    yum remove -y avahi chrony
    sed -i -e 's/^#PS1=/PS1=/' /root/.bashrc # enable the colorful root bash prompt
    sed -i -e "s/^#alias ll='ls -l'/alias ll='ls -al'/" /root/.bashrc # enable ll list long alias <3
}

function randomString {
    if [ ! -n "$1" ];
        then LEN=20
        else LEN="$1"
    fi

    echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c $LEN) # generate a random string
}