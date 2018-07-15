#!/bin/sh

set -e

################################################################################
# Default Variables
################################################################################

# Configure
: ${KERNEL:="HWE"}
: ${DESKTOP:="YES"}
: ${NVIDIA:="YES"}
: ${KEYBOARD:="US"}

# Generic
: ${RELEASE:="xenial"}
: ${ROOTFS:="/rootfs"}

# Disk
: ${ROOT_DISK_TYPE:=""}
: ${ROOT_DISK_NAME:=""}

# Mirror
: ${MIRROR_UBUNTU:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu"}
: ${MIRROR_UBUNTU_PARTNER:="http://archive.canonical.com"}
: ${MIRROR_UBUNTU_JA:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu"}
: ${MIRROR_UBUNTU_JA_NONFREE:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free"}
: ${MIRROR_NVIDIA_CUDA:="http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64"}

# Proxy
: ${NO_PROXY:=""}
: ${APT_PROXY:=""}
: ${FTP_PROXY:=""}
: ${HTTP_PROXY:=""}
: ${HTTPS_PROXY:=""}

# DNS
: ${DNS_SERVER:="8.8.8.8 8.8.4.4"}
: ${DNS_SEARCH:=""}

# NTP
: ${NTP_SERVER:=""}
: ${NTP_POOL:=""}

# Address
: ${ADDRESS:="auto"}
: ${GATEWAY:=""}

# FQDN
: ${SITENAME:="ubuntu"}
: ${DOMAIN:=""}

# User
: ${USER_NAME:="ubuntu"}
: ${USER_PASS:="ubuntu"}
: ${USER_FULL:="Ubuntu User"}
: ${USER_KEYS:=""}

# NVIDIA
: ${NVIDIA_DRIVER_PACKAGE:="nvidia-396"}

################################################################################
# Check Environment
################################################################################

if [ "x${ROOT_DISK_TYPE}" != "xHDD" -a "x${ROOT_DISK_TYPE}" != "xSSD" -a "x${ROOT_DISK_TYPE}" != "xNVME" ]; then
  echo "Unknown Environment ROOT_DISK_TYPE..."
  exit 1
fi

if [ ! -e "/dev/disk/by-id/${ROOT_DISK_NAME}" ]; then
  echo "Unknown Environment ROOT_DISK_NAME..."
  exit 1
fi

################################################################################
# Proxy Environment
################################################################################

# Proxy Environment Variables
if [ "x${NO_PROXY}" != "x" ]; then
  export no_proxy="${NO_PROXY}"
  export NO_PROXY="${NO_PROXY}"
fi
if [ "x${FTP_PROXY}" != "x" ]; then
  export ftp_proxy="${FTP_PROXY}"
  export FTP_PROXY="${FTP_PROXY}"
fi
if [ "x${HTTP_PROXY}" != "x" ]; then
  export http_proxy="${HTTP_PROXY}"
  export HTTP_PROXY="${HTTP_PROXY}"
fi
if [ "x${HTTPS_PROXY}" != "x" ]; then
  export https_proxy="${HTTPS_PROXY}"
  export HTTPS_PROXY="${HTTPS_PROXY}"
fi

################################################################################
# Live Linux Image Require
################################################################################

# Check Arch Linux
if [ -f "/etc/arch-release" ]; then
  # Set Password for Root User
  echo root:root | chpasswd

  # Start SSH Service
  systemctl start sshd.service

  # Resolv Configuration
  echo '# DNS Server'     >  "/etc/resolv.conf"
  if [ "x${DOMAIN}" != "x" ]; then
    echo "domain ${DOMAIN}" >> "/etc/resolv.conf"
  fi
  if [ "x${DNS_SEARCH}" != "x" ]; then
    echo "search ${DNS_SEARCH}" >> "/etc/resolv.conf"
  fi
  if [ "x${DNS_SERVER}" != "x" ]; then
    for i in ${DNS_SERVER}; do
      echo "nameserver ${i}" >> "/etc/resolv.conf"
    done
  fi

  # Disable Beep
  set bell-style none
  echo 'set bell-style none' > ${HOME}/.inputrc
  echo 'set belloff=all' > ${HOME}/.vimrc

  # PacMan Mirror
  echo "Server = http://ftp.jaist.ac.jp/pub/Linux/ArchLinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist

  # Kill GnuPG Agent
  killall gpg-agent

  # PacMan Keyring Clear
  rm -fr /etc/pacman.d/gnupg/*

  # PacMan Keyring Initialize
  pacman-key --init

  # PacMan Keyring Refresh
  pacman-key --populate archlinux

  # PacMan Repository Update
  pacman -Syy --noconfirm

  # Debootstrap Package
  pacman -S --noconfirm debootstrap ubuntu-keyring
fi

################################################################################
# Cleanup
################################################################################

# Get Disk ID
ROOT_DISK_PATH="`realpath /dev/disk/by-id/${ROOT_DISK_NAME}`"

# Unmount Swap Partition
swapoff -a

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount

# Unmount Disk Drive
awk '{print $1}' /proc/mounts | grep -s "${ROOT_DISK_PATH}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Disk
################################################################################

# Check Disk Type
if [ "x${ROOT_DISK_TYPE}" = "xSSD" ]; then
  # Enter Key Message
  echo 'SSD Secure Erase'

  # Suspend-to-RAM (ACPI State S3)
  rtcwake -m mem -s 10

  # Wait
  sleep 10

  # Set Password
  hdparm --user-master u --security-set-pass P@ssW0rd "${ROOT_DISK_PATH}"

  # Secure Erase
  hdparm --user-master u --security-erase P@ssW0rd "${ROOT_DISK_PATH}"
fi

# Wait Probe
sleep 1

# Clear Partition Table
sgdisk -Z "${ROOT_DISK_PATH}"

# Create GPT Partition Table
sgdisk -o "${ROOT_DISK_PATH}"

# Create EFI Partition
sgdisk -n 1::+512M -c 1:"Efi"  -t 1:ef00 "${ROOT_DISK_PATH}"

# Create Swap Partition
sgdisk -n 2::+16G  -c 2:"Swap" -t 2:8200 "${ROOT_DISK_PATH}"

# Create Root Partition
sgdisk -n 3::-1    -c 3:"Root" -t 3:8300 "${ROOT_DISK_PATH}"

# Wait Probe
sleep 1

# Get Real Path
BOOTPT="`realpath /dev/disk/by-id/${ROOT_DISK_NAME}-part1`"
ROOTPT="`realpath /dev/disk/by-id/${ROOT_DISK_NAME}-part3`"
SWAPPT="`realpath /dev/disk/by-id/${ROOT_DISK_NAME}-part2`"

# Format EFI System Partition
mkfs.vfat -F 32 -n "EfiFs" "${BOOTPT}"

# Format Root File System Partition
mkfs.xfs -f -L "RootFs" "${ROOTPT}"

# Format Linux Swap Partition
mkswap -L "SwapFs" "${SWAPPT}"

# Mount Root File System Partition
mkdir -p "${ROOTFS}"
mount "${ROOTPT}" "${ROOTFS}"

# Mount EFI System Partition
mkdir -p "${ROOTFS}/boot/efi"
mount "${BOOTPT}" "${ROOTFS}/boot/efi"

# Mount Linux Swap Partition
swapon "${SWAPPT}"

################################################################################
# Bootstrap
################################################################################

# Install Base System
if [ "x${APT_PROXY_HOST}" != "x" -a "x${APT_PROXY_PORT}" != "x" ]; then
  env http_proxy="http://${APT_PROXY_HOST}:${APT_PROXY_PORT}" debootstrap "${RELEASE}" "${ROOTFS}" "${MIRROR_UBUNTU}"
else
  debootstrap "${RELEASE}" "${ROOTFS}" "${MIRROR_UBUNTU}"
fi

# Require Environment
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="/root"
export LC_ALL="C"
export LANGUAGE="C"
export LANG="C"
export DEBIAN_FRONTEND="noninteractive"
export DEBIAN_PRIORITY="critical"
export DEBCONF_NONINTERACTIVE_SEEN="true"

# Cleanup Files
find "${ROOTFS}/dev"       -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/proc"      -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/run"       -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/sys"       -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/tmp"       -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/var/tmp"   -mindepth 1 | xargs --no-run-if-empty rm -fr

# Require Mount
mount -t devtmpfs                   devtmpfs "${ROOTFS}/dev"
mount -t devpts   -o gid=5,mode=620 devpts   "${ROOTFS}/dev/pts"
mount -t proc                       proc     "${ROOTFS}/proc"
mount -t tmpfs                      tmpfs    "${ROOTFS}/run"
mount -t sysfs                      sysfs    "${ROOTFS}/sys"
mount -t tmpfs                      tmpfs    "${ROOTFS}/tmp"
mount -t tmpfs                      tmpfs    "${ROOTFS}/var/tmp"
mount --bind /sys/firmware/efi/efivars       "${ROOTFS}/sys/firmware/efi/efivars"
chmod 1777 "${ROOTFS}/dev/shm"

################################################################################
# FileSystem
################################################################################

# Symlink Mount Table
ln -s /proc/self/mounts "${ROOTFS}/etc/mtab"

# Create Mount Point
echo '# <file system> <dir>      <type> <options>         <dump> <pass>' >  "${ROOTFS}/etc/fstab"
echo "${ROOTPT}       /          xfs    defaults          0      1"      >> "${ROOTFS}/etc/fstab"
echo "${BOOTPT}       /boot/efi  vfat   defaults          0      2"      >> "${ROOTFS}/etc/fstab"
echo "${SWAPPT}       none       swap   defaults          0      0"      >> "${ROOTFS}/etc/fstab"
echo "tmpfs           /var/tmp   tmpfs  defaults          0      0"      >> "${ROOTFS}/etc/fstab"
echo "tmpfs           /tmp       tmpfs  defaults          0      0"      >> "${ROOTFS}/etc/fstab"

################################################################################
# Network
################################################################################

# Configure Hostname
echo "${SITENAME}" > "${ROOTFS}/etc/hostname"

# Resolve Hostname
if [ "x${DOMAIN}" != "x" ]; then
  echo "127.0.1.1	${SITENAME}.${DOMAIN} ${SITENAME}" >> "${ROOTFS}/etc/hosts"
else
  echo "127.0.1.1	${SITENAME}" >> "${ROOTFS}/etc/hosts"
fi

# Configure Resolve
rm "${ROOTFS}/etc/resolv.conf"
echo '# DNS Server'     >  "${ROOTFS}/etc/resolv.conf"
if [ "x${DOMAIN}" != "x" ]; then
  echo "domain ${DOMAIN}" >> "${ROOTFS}/etc/resolv.conf"
fi
if [ "x${DNS_SEARCH}" != "x" ]; then
  echo "search ${DNS_SEARCH}" >> "${ROOTFS}/etc/resolv.conf"
fi
if [ "x${DNS_SERVER}" != "x" ]; then
  for i in ${DNS_SERVER}; do
    echo "nameserver ${i}" >> "${ROOTFS}/etc/resolv.conf"
  done
fi

################################################################################
# Localize
################################################################################

# Timezone
echo 'Asia/Tokyo' > "${ROOTFS}/etc/timezone"
ln -fs /usr/share/zoneinfo/Asia/Tokyo "${ROOTFS}/etc/localtime"
chroot "${ROOTFS}" dpkg-reconfigure tzdata

# Locale
chroot "${ROOTFS}" locale-gen ja_JP.UTF-8
chroot "${ROOTFS}" update-locale LANG=ja_JP.UTF-8

# Keyboard
if [ "x${KEYBOARD}" = "JP" ]; then
  # Japanese Keyboard
  sed -i -e 's@XKBMODEL="pc105"@XKBMODEL="jp106"@'      "${ROOTFS}/etc/default/keyboard"
  sed -i -e 's@XKBLAYOUT="us"@XKBLAYOUT="jp"@'          "${ROOTFS}/etc/default/keyboard"
fi

# CapsLock to Ctrl
sed -i -e 's@XKBOPTIONS=""@XKBOPTIONS="ctrl:nocaps"@' "${ROOTFS}/etc/default/keyboard"

################################################################################
# Admin User
################################################################################

# Add Group
chroot "${ROOTFS}" addgroup --system admin
chroot "${ROOTFS}" addgroup --system lpadmin
chroot "${ROOTFS}" addgroup --system sambashare

# Add User
chroot "${ROOTFS}" adduser --disabled-password --gecos "${USER_FULL},,," "${USER_NAME}"
chroot "${ROOTFS}" adduser "${USER_NAME}" adm
chroot "${ROOTFS}" adduser "${USER_NAME}" admin
chroot "${ROOTFS}" adduser "${USER_NAME}" audio
chroot "${ROOTFS}" adduser "${USER_NAME}" cdrom
chroot "${ROOTFS}" adduser "${USER_NAME}" dialout
chroot "${ROOTFS}" adduser "${USER_NAME}" dip
chroot "${ROOTFS}" adduser "${USER_NAME}" lpadmin
chroot "${ROOTFS}" adduser "${USER_NAME}" netdev
chroot "${ROOTFS}" adduser "${USER_NAME}" plugdev
chroot "${ROOTFS}" adduser "${USER_NAME}" sambashare
chroot "${ROOTFS}" adduser "${USER_NAME}" staff
chroot "${ROOTFS}" adduser "${USER_NAME}" sudo
chroot "${ROOTFS}" adduser "${USER_NAME}" users
chroot "${ROOTFS}" adduser "${USER_NAME}" video

# Change Password
chroot ${ROOTFS} sh -c "echo ${USER_NAME}:${USER_PASS} | chpasswd"

# SSH Public Key
if [ "x${USER_KEYS}" != "x" ]; then
  mkdir -p "${ROOTFS}/home/${USER_NAME}/.ssh"
  chmod 0700 "${ROOTFS}/home/${USER_NAME}/.ssh"
  echo "${USER_KEYS}" > "${ROOTFS}/home/${USER_NAME}/.ssh/authorized_keys"
  chmod 0644 "${ROOTFS}/home/${USER_NAME}/.ssh/authorized_keys"
fi

# Proxy Configuration
if [ "x${NO_PROXY}" != "x" ]; then
  echo "export no_proxy=\"${NO_PROXY}\""       >> "${ROOTFS}/home/${USER_NAME}/.profile"
  echo "export NO_PROXY=\"${NO_PROXY}\""       >> "${ROOTFS}/home/${USER_NAME}/.profile"
fi
if [ "x${FTP_PROXY}" != "x" ]; then
  echo "export ftp_proxy=\"${FTP_PROXY}\""     >> "${ROOTFS}/home/${USER_NAME}/.profile"
  echo "export FTP_PROXY=\"${FTP_PROXY}\""     >> "${ROOTFS}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTP_PROXY}" != "x" ]; then
  echo "export http_proxy=\"${HTTP_PROXY}\""   >> "${ROOTFS}/home/${USER_NAME}/.profile"
  echo "export HTTP_PROXY=\"${HTTP_PROXY}\""   >> "${ROOTFS}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTPS_PROXY}" != "x" ]; then
  echo "export https_proxy=\"${HTTPS_PROXY}\"" >> "${ROOTFS}/home/${USER_NAME}/.profile"
  echo "export HTTPS_PROXY=\"${HTTPS_PROXY}\"" >> "${ROOTFS}/home/${USER_NAME}/.profile"
fi

# User Dir Permission
chroot "${ROOTFS}" chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"

# Sudo No Password
echo "${USER_NAME} ALL=(ALL) NOPASSWD: ALL" > "${ROOTFS}/etc/sudoers.d/${USER_NAME}"
chmod 0440 "${ROOTFS}/etc/sudoers.d/${USER_NAME}"

################################################################################
# Repository
################################################################################

# Official Repository
cat > "${ROOTFS}/etc/apt/sources.list" << __EOF__
# Official Repository
deb ${MIRROR_UBUNTU} ${RELEASE}          main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-updates  main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-security main restricted universe multiverse
__EOF__

# Partner Repository
cat > "${ROOTFS}/etc/apt/sources.list.d/ubuntu-partner.list" << __EOF__
# Partner Repository
deb ${MIRROR_UBUNTU_PARTNER} ${RELEASE} partner
__EOF__

# Japanese Team Repository
chroot "${ROOTFS}" apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 3B593C7BE6DB6A89FB7CBFFD058A05E90C4ECFEC
chroot "${ROOTFS}" apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 59676CBCF5DFD8C1CEFE375B68B5F60DCDC1D865
cat > "${ROOTFS}/etc/apt/sources.list.d/ubuntu-ja.list" << __EOF__
# Japanese Team Repository
deb ${MIRROR_UBUNTU_JA} ${RELEASE} main
deb ${MIRROR_UBUNTU_JA_NONFREE} ${RELEASE} multiverse
__EOF__

# Proxy Configuration
if [ "x${FTP_PROXY}" != "x" -o "x${HTTP_PROXY}" != "x" -o "x${HTTPS_PROXY}" != "x" -o \( "x${APT_PROXY_HOST}" != "x" -a "x${APT_PROXY_PORT}" != "x" \) ]; then
  echo "// Apt Proxy"                                                                              >  "${ROOTFS}/etc/apt/apt.conf"
  if [ "x${FTP_PROXY}" != "x" ]; then
    echo "Acquire::ftp::proxy \"${FTP_PROXY}\";"                                                   >> "${ROOTFS}/etc/apt/apt.conf"
  fi
  if [ "x${HTTP_PROXY}" != "x" ]; then
    echo "Acquire::http::proxy \"${HTTP_PROXY}\";"                                                 >> "${ROOTFS}/etc/apt/apt.conf"
  fi
  if [ "x${HTTPS_PROXY}" != "x" ]; then
    echo "Acquire::https::proxy \"${HTTPS_PROXY}\";"                                               >> "${ROOTFS}/etc/apt/apt.conf"
  fi
  if [ "x${APT_PROXY_HOST}" != "x" -a "x${APT_PROXY_PORT}" != "x" ]; then
    echo "Acquire::http::proxy::${APT_PROXY_HOST} \"http://${APT_PROXY_HOST}:${APT_PROXY_PORT}\";" >> "${ROOTFS}/etc/apt/apt.conf"
  fi
fi

################################################################################
# Upgrade
################################################################################

# Update Repository
chroot "${ROOTFS}" apt-get -y update

# Upgrade System
chroot "${ROOTFS}" apt-get -y dist-upgrade

################################################################################
# Kernel
################################################################################

# Install Kernel
if [ "x${KERNEL}" = "xHWE" ]; then
  # HWE Version
  chroot "${ROOTFS}" apt-get -y install linux-generic-hwe-16.04-edge
else
  # GA Version
  chroot "${ROOTFS}" apt-get -y install linux-generic
fi

################################################################################
# Require
################################################################################

# Standard
chroot "${ROOTFS}" apt-get -y install ubuntu-standard

# Build Tools
chroot "${ROOTFS}" apt-get -y install build-essential

################################################################################
# Disk
################################################################################

# Partition
chroot "${ROOTFS}" apt-get -y install gdisk

# File System
chroot "${ROOTFS}" apt-get -y install xfsprogs xfsdump acl attr

################################################################################
# Boot
################################################################################

if [ -d "/sys/firmware/efi" ]; then
  # EFI Boot Manager
  chroot "${ROOTFS}" apt-get -y install efibootmgr

  # Grub Boot Loader
  chroot "${ROOTFS}" apt-get -y install grub-efi

  # Remove UEFI Entry
  for i in `efibootmgr | grep -E 'Boot[0-9A-F]{4}' | sed -e 's/^Boot\([0-9A-Z]\{4\}\).*$/\1/;'`; do
    efibootmgr -b $i -B
  done

  # Generate UEFI Boot Entry
  chroot "${ROOTFS}" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Ubuntu --recheck
  chroot "${ROOTFS}" grub-mkconfig -o /boot/grub/grub.cfg
else
  # Grub Boot Loader
  chroot "${ROOTFS}" apt-get -y install grub-pc

  # Generate UEFI Boot Entry
  chroot "${ROOTFS}" grub-install --target=i386-pc --recheck "${ROOT_DISK_PATH}"
  chroot "${ROOTFS}" grub-mkconfig -o /boot/grub/grub.cfg
fi

################################################################################
# Network
################################################################################

# NetworkManager
chroot "${ROOTFS}" apt-get -y --no-install-recommends install network-manager

if [ "x${ADDRESS}" != "xauto" ]; then
  # Variables
  _DNS_SERVER="`echo ${DNS_SERVER} | sed -e 's/ /;/g'`"
  _DNS_SEARCH="`echo ${DNS_SEARCH} | sed -e 's/ /;/g'`"

  # Configure
  echo "[connection]"                   >  "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "id=Wired"                       >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "type=ethernet"                  >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo ""                               >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "[ipv4]"                         >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "method=manual"                  >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "address1=${ADDRESS},${GATEWAY}" >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "dns=${_DNS_SERVER};"            >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "dns-search=${_DNS_SEARCH};"     >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo ""                               >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "[ipv6]"                         >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "method=ignore"                  >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
  echo "addr-gen-mode=stable-privacy"   >> "${ROOTFS}/etc/NetworkManager/system-connections/Wired"

  # Change Owner
  chown root:root "${ROOTFS}/etc/NetworkManager/system-connections/Wired"

  # Change Permission
  chmod 0600 "${ROOTFS}/etc/NetworkManager/system-connections/Wired"
fi

################################################################################
# Ntp
################################################################################

# NTP Time Server
chroot "${ROOTFS}" apt-get -y install ntp

# Disable Default Server List
sed -i -e 's@^\(server.*\)@#\1@' "${ROOTFS}/etc/ntp.conf"
sed -i -e 's@^\(pool.*\)@#\1@' "${ROOTFS}/etc/ntp.conf"

# Configure NTP Server List
if [ "x${NTP_SERVER}" != "x" -o "x${NTP_POOL}" != "x" ]; then
  echo '' >> "${ROOTFS}/etc/ntp.conf"
  for i in ${NTP_SERVER}; do
    echo "server ${i} iburst" >> "${ROOTFS}/etc/ntp.conf"
  done
  for i in ${NTP_POOL}; do
    echo "pool ${i} iburst" >> "${ROOTFS}/etc/ntp.conf"
  done
fi

################################################################################
# OpenSSH
################################################################################

# OpenSSH
chroot "${ROOTFS}" apt-get -y install ssh

# Configure OpenSSH Server
echo ''          >> "${ROOTFS}/etc/ssh/sshd_config"
echo 'UseDNS=no' >> "${ROOTFS}/etc/ssh/sshd_config"

################################################################################
# Desktop
################################################################################

if [ "x${DESKTOP}" = "xYES" ]; then
  # HWE Kernel
  if [ "x${KERNEL}" = "xHWE" ]; then
    chroot "${ROOTFS}" apt-get -y install xserver-xorg-hwe-16.04
  fi

  # Desktop
  chroot "${ROOTFS}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja

  # Input Method
  chroot "${ROOTFS}" su -c "im-config -n fcitx" "${USER_NAME}"

  # User Directory
  chroot "${ROOTFS}" su -c "LANG=C xdg-user-dirs-update" "${USER_NAME}"
  rm "${ROOTFS}/home/${USER_NAME}/.config/user-dirs.locale"

  # NVIDIA Driver
  if [ "x${NVIDIA}" = "xYES" ]; then
    # NVIDIA Apt Public Key
    chroot "${ROOTFS}" apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys AE09FE4BBD223A84B2CCFCE3F60F4B3D7FA2AF80

    # NVIDIA CUDA Repository
    echo '# NVIDIA CUDA Repository'    >  "${ROOTFS}/etc/apt/sources.list.d/nvidia-cuda.list"
    echo "deb ${MIRROR_NVIDIA_CUDA} /" >> "${ROOTFS}/etc/apt/sources.list.d/nvidia-cuda.list"

    # Update Repository
    chroot "${ROOTFS}" apt-get -y update

    # Upgrade System
    chroot "${ROOTFS}" apt-get -y dist-upgrade

    # Install Driver
    chroot "${ROOTFS}" apt-get -y install ${NVIDIA_DRIVER_PACKAGE}

    # DRM Kernel Mode Setting
    echo "nvidia"         >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_modeset" >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_uvm"     >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_drm"     >> "${ROOTFS}/etc/initramfs-tools/modules"
    sed -i -e 's@^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$@GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 \1"@' "${ROOTFS}/etc/default/grub"
  fi
fi

################################################################################
# Cleanup
################################################################################

# Remove Original Resolve
rm "${ROOTFS}/etc/resolvconf/resolv.conf.d/original"

# Check Arch Linux
if [ -f "/etc/arch-release" ]; then
  # Remove ArchISO Kernel Module
  chroot "${ROOTFS}" update-initramfs -d -k "`uname -r`"
fi

# Update Initramfs
chroot "${ROOTFS}" update-initramfs -u

# Update Grub
chroot "${ROOTFS}" update-grub

# Cleanup Packages
chroot "${ROOTFS}" apt-get -y autoremove --purge
chroot "${ROOTFS}" apt-get -y clean

# Disk Sync
sync;sync;sync

# Check Disk Type
if [ "x${ROOT_DISK_TYPE}" = "xSSD" -o "x${ROOT_DISK_TYPE}" = "xNVME" ]; then
  # TRIM
  fstrim -v "${ROOTFS}"
fi

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount -fl

# Complete Message
echo 'Complete Setup!'
