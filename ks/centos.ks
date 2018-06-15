#version=DEVEL

# Post-installation scripts
%pre

iotty=`tty`
exec < $iotty > $iotty 2> $iotty

echo
echo -e "\e[1m\e[101m** Please note, by continuing the local disk WILL be wiped!! **\e[0m"
echo
echo -n "Enter the server hostname : "
read NAME
DOMAIN="ad.alexmartio.co.uk"
NAME="$NAME.$DOMAIN"
echo $NAME > /tmp/hostname.tmp
sleep 1
echo "network  --hostname=$NAME" >> /tmp/networkhost.txt
%end

# System authorization information
auth --enableshadow --passalgo=sha512
# Use network installation media
url --url 'http://repos.alexmartio.co.uk/centos/7/os/x86_64'

#epel repo
repo --name=epel --baseurl='http://repos.alexmartio.co.uk/pub/epel/7/x86_64/'
#updates repo
repo --name=updates --baseurl='http://repos.alexmartio.co.uk/centos/7/updates/x86_64/'

# Use text install
text
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=sda
# Keyboard layouts
keyboard --vckeymap=gb --xlayouts='gb'
# System language
lang en_GB.UTF-8

# Network information
network  --bootproto=dhcp --device=enp0s10f0 --onboot=off --ipv6=auto --no-activate
network  --bootproto=dhcp --device=eth0 --ipv6=auto --activate
%include /tmp/networkhost.txt

# Root password
rootpw --iscrypted ***REMOVED***
# System services
services --enabled="chronyd"
# System timezone
timezone Europe/London --isUtc
# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=sda
#autopart --type=lvm
# Partition clearing information
clearpart --all --initlabel



### Partitions
part	/boot	--recommended
#part	/boot	--fstype xfs --size=1024
part	swap	--recommended
part	pv.01	--size=1	--grow
#part	pv.01	--recommended

## Volume Group
volgroup vg_root pv.01

## Volumes
## CIS 1.1.2 - 1.1.13
logvol	/		--vgname vg_root	--name root	--fstype=xfs	--percent=20
logvol	/tmp		--vgname vg_root	--name tmp	--fstype=xfs	--percent=5	--fsoptions="nodev,nosuid,noexec"
logvol	/var		--vgname vg_root	--name var	--fstype=xfs	--percent=40
logvol	/var/tmp	--vgname vg_root	--name var_tmp	--fstype=xfs	--percent=5	--fsoptions="nodev,nosuid,noexec"
logvol	/var/log	--vgname vg_root	--name log	--fstype=xfs	--percent=20
logvol	/var/log/audit	--vgname vg_root	--name audit	--fstype=xfs	--percent=5
logvol	/home		--vgname vg_root	--name home	--fstype=xfs	--percent=5	--fsoptions="nodev"	--grow

# Reboot after installation
reboot

%packages
@^minimal
@core
adcli
chrony
dconf
kexec-tools
openscap
openscap-scanner
scap-security-guide
epel-release
bash-completion
deltarpm
krb5-workstation
vim-enhanced
mailx
mlocate
mutt
nano
policycoreutils-python
realmd
samba-common-tools
setroubleshoot-server
sssd
yum-cron

%end


# Post-installation scripts
%post

sed -i 's/#baseurl=http:\/\/mirror.centos.org/baseurl=http:\/\/repos.alexmartio.co.uk/' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/#baseurl=http:\/\/download.fedoraproject.org/baseurl=http:\/\/repos.alexmartio.co.uk/' /etc/yum.repos.d/epel.repo
sed -i 's/mirrorlist/#mirrorlist/' /etc/yum.repos.d/{CentOS-Base,epel}.repo

## Add Vim customisations
curl --create-dirs 'http://repos.alexmartio.co.uk/ks/vim/.vimrc' -o /tmp/vim/.vimrc
curl --create-dirs 'http://repos.alexmartio.co.uk/ks/vim/.vim/colors/Crystallite.vim' -o /tmp/vim/.vim/colors/Crystallite.vim
cp --recursive /tmp/vim/{.vimrc,.vim} /root
cp --recursive /tmp/vim/{.vimrc,.vim} /etc/skel
rm --force --recursive /tmp/vim
# Restore Contexts
restorecon -R /root
restorecon -R /etc/skel

# Configure SSSD - this has to be done on first boot, as systemd is not available in chroot
/bin/curl --silent "http://repos.alexmartio.co.uk/ks/sssd/firstboot.sh" -o /root/firstboot.sh
echo "@reboot root /bin/sleep 60; /bin/bash /root/firstboot.sh > /root/firstboot.log 2>&1" >> /etc/crontab

# Initialise AIDE database
aide --init
mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

%end # End Post


%addon org_fedora_oscap
    content-type = scap-security-guide
    profile = pci-dss
%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end

%anaconda
pwpolicy root --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy user --minlen=6 --minquality=50 --notstrict --nochanges --notempty
pwpolicy luks --minlen=6 --minquality=50 --notstrict --nochanges --notempty
%end
