# This is a minimal Alma kickstart designed to create a dockerized environment.
install
keyboard us
rootpw locked
timezone US/Pacific

text
skipx

firstboot --disabled

selinux --enforcing
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on --noipv6 --hostname=alma9.localdomain
reboot
bootloader --location=mbr --append="net.ifnames=0 biosdevname=0 no_timer_check"
lang en_US

# Disk setup
zerombr
clearpart --all --initlabel
autopart --nohome

# repo --name=BaseOS
url --url=https://dfw.mirror.rackspace.com/almalinux/9.0/BaseOS/x86_64/os/

# Package setup
%packages
@core
authconfig
sudo
-fprintd-pam
-intltool
-iwl*-firmware
-microcode_ctl
%end

%post

sed -i -e "s/.*PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config
sed -i -e "s/.*PasswordAuthentication.*/PasswordAuthentication yes/g" /etc/ssh/sshd_config

%end
