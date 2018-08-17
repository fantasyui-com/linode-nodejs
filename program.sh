#!/bin/bash

if [[ ! $SSUSER ]]; then read -p "Sudo user username?" SSUSER; fi
if [[ ! $SSPASSWORD ]]; then read -p "Sudo user password?" SSPASSWORD; fi
if [[ ! $SSPUBKEY ]]; then read -p "SSH pubkey (installed for root and sudo user)?" SSPUBKEY; fi

# USERS
user_add_sudo "$SSUSER" "$SSPASSWORD" && user_add_pubkey "$SSUSER" $SSPUBKEY

# BASE NETSEC
ssh_disable_root
ssh_disable_password_authentication

# BASE UPDATE
system_update
system_autoupdate

# NETSEC
fail2ban_install
https_masquerade_firewall
setup_kernel_and_grub
ntp_install

# SOFTWARE
nodejs_install

tweaks

echo All finished! Rebooting...
(sleep 5; reboot) &