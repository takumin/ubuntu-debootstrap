#!/bin/sh

set -e

################################################################################
# Default Variables
################################################################################

# Generic
: ${RELEASE:="xenial"}  # [trusty|xenial|bionic]
: ${LIVE:="YES"}        # [TRUE|FALSE]
: ${KERNEL:="NORMAL"}   # [NORMAL|HWE]
: ${DESKTOP:="NO"}      # [YES|NO]
: ${NVIDIA:="NO"}       # [YES|NO]
: ${KEYBOARD:="US"}     # [JP|US]

# Disk
: ${ROOTFS:="/rootfs"}  # Root File System Mount Point
: ${ROOT_DISK_TYPE:=""} # [HDD|SSD|NVME]
: ${ROOT_DISK_NAME:=""} # List of /dev/disk/by-id/*

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

################################################################################
# Load Environment
################################################################################

if [ -n "$1" -a -r "$1" ]; then
  . "$1"
fi

################################################################################
# Check Environment
################################################################################

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
  # Check Root Disk Type
  if [ "x${ROOT_DISK_TYPE}" != "xHDD" -a "x${ROOT_DISK_TYPE}" != "xSSD" -a "x${ROOT_DISK_TYPE}" != "xNVME" ]; then
    echo "Unknown Environment ROOT_DISK_TYPE"
    exit 1
  fi

  # Check Root Disk Name
  if [ ! -e "/dev/disk/by-id/${ROOT_DISK_NAME}" ]; then
    echo "Unknown Environment ROOT_DISK_NAME"
    exit 1
  fi
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
# Require
################################################################################

# Check Linux Standard Base
if [ -f "/etc/lsb-release" ]; then
  . "/etc/lsb-release"
fi

# Check Ubuntu
if [ "x${DISTRIB_ID}" = "xUbuntu" ]; then
  # Check Default Live Ubuntu
  if [ `grep -qs "deb cdrom" /etc/apt/sources.list` ]; then
    # Set Password for Live User
    echo ubuntu:ubuntu | chpasswd

    # Official Repository
    echo "# Official Repository"                                                        >  "${ROOTFS}/etc/apt/sources.list"
    echo "deb ${MIRROR_UBUNTU} ${RELEASE}          main restricted universe multiverse" >> "${ROOTFS}/etc/apt/sources.list"
    echo "deb ${MIRROR_UBUNTU} ${RELEASE}-updates  main restricted universe multiverse" >> "${ROOTFS}/etc/apt/sources.list"
    echo "deb ${MIRROR_UBUNTU} ${RELEASE}-security main restricted universe multiverse" >> "${ROOTFS}/etc/apt/sources.list"

    # Update Repository
    apt-get -y update

    # Install SSH Server
    apt-get -y install ssh

    # Start SSH Service
    systemctl start ssh.service

    exit
  fi

  # Install Require Packages
  dpkg -l | awk '{print $2}' | grep -qs '^sed$'             || apt-get -y --no-install-recommends install sed
  dpkg -l | awk '{print $2}' | grep -qs '^mawk$'            || apt-get -y --no-install-recommends install mawk
  dpkg -l | awk '{print $2}' | grep -qs '^curl$'            || apt-get -y --no-install-recommends install curl
  dpkg -l | awk '{print $2}' | grep -qs '^wget$'            || apt-get -y --no-install-recommends install wget
  dpkg -l | awk '{print $2}' | grep -qs '^ca-certificates$' || apt-get -y --no-install-recommends install ca-certificates
  dpkg -l | awk '{print $2}' | grep -qs '^efibootmgr$'      || apt-get -y --no-install-recommends install efibootmgr
  dpkg -l | awk '{print $2}' | grep -qs '^hdparm$'          || apt-get -y --no-install-recommends install hdparm
  dpkg -l | awk '{print $2}' | grep -qs '^nvme-cli$'        || apt-get -y --no-install-recommends install nvme-cli
  dpkg -l | awk '{print $2}' | grep -qs '^gdisk$'           || apt-get -y --no-install-recommends install gdisk
  dpkg -l | awk '{print $2}' | grep -qs '^dosfstools$'      || apt-get -y --no-install-recommends install dosfstools
  dpkg -l | awk '{print $2}' | grep -qs '^xfsprogs$'        || apt-get -y --no-install-recommends install xfsprogs
  dpkg -l | awk '{print $2}' | grep -qs '^debootstrap$'     || apt-get -y --no-install-recommends install debootstrap
  dpkg -l | awk '{print $2}' | grep -qs '^squashfs-tools$'  || apt-get -y --no-install-recommends install squashfs-tools
fi

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

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
  # Get Disk ID
  ROOT_DISK_PATH="`realpath /dev/disk/by-id/${ROOT_DISK_NAME}`"

  # Unmount Swap Partition
  swapoff -a

  # Unmount Disk Drive
  awk '{print $1}' /proc/mounts | grep -s "${ROOT_DISK_PATH}" | sort -r | xargs --no-run-if-empty umount
else
  # Delete Kernel/Initramfs/RootFs Image
  [ -f "./vmlinuz" ]       && rm "./vmlinuz"
  [ -f "./initrd.img" ]    && rm "./initrd.img"
  [ -f "./root.squashfs" ] && rm "./root.squashfs"
fi

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Disk
################################################################################

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
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
else
  # Mount Root File System Partition
  mkdir -p "${ROOTFS}"
  mount -t tmpfs -o mode=0755 tmpfs "${ROOTFS}"
fi

################################################################################
# Bootstrap
################################################################################

# Host Name
export HOSTNAME="${SITENAME}"

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
mount -t tmpfs    -o mode=755       tmpfs    "${ROOTFS}/run"
mount -t sysfs                      sysfs    "${ROOTFS}/sys"
mount -t tmpfs                      tmpfs    "${ROOTFS}/tmp"
mount -t tmpfs                      tmpfs    "${ROOTFS}/var/tmp"
chmod 1777 "${ROOTFS}/dev/shm"

# Check UEFI Platform
if [ -d "/sys/firmware/efi" ]; then
  mount --bind /sys/firmware/efi/efivars "${ROOTFS}/sys/firmware/efi/efivars"
fi

################################################################################
# FileSystem
################################################################################

# Symlink Mount Table
ln -s /proc/self/mounts "${ROOTFS}/etc/mtab"

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
  # Create Mount Point
  echo '# <file system> <dir>      <type> <options>         <dump> <pass>' >  "${ROOTFS}/etc/fstab"
  echo "${ROOTPT}       /          xfs    defaults          0      1"      >> "${ROOTFS}/etc/fstab"
  echo "${BOOTPT}       /boot/efi  vfat   defaults          0      2"      >> "${ROOTFS}/etc/fstab"
  echo "${SWAPPT}       none       swap   defaults          0      0"      >> "${ROOTFS}/etc/fstab"
  echo "tmpfs           /var/tmp   tmpfs  defaults          0      0"      >> "${ROOTFS}/etc/fstab"
  echo "tmpfs           /tmp       tmpfs  defaults          0      0"      >> "${ROOTFS}/etc/fstab"
fi

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
wget -qO "${ROOTFS}/tmp/ubuntu-ja-archive-keyring.gpg" https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg
wget -qO "${ROOTFS}/tmp/ubuntu-jp-ppa-keyring.gpg" https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg
chroot "${ROOTFS}" apt-key add /tmp/ubuntu-ja-archive-keyring.gpg
chroot "${ROOTFS}" apt-key add /tmp/ubuntu-jp-ppa-keyring.gpg
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
  chroot "${ROOTFS}" apt-get -y install linux-generic-hwe-16.04
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

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
  # Check UEFI Platform
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
else
  # EFI Boot Manager
  chroot "${ROOTFS}" apt-get -y install efibootmgr

  # Grub Boot Loader
  chroot "${ROOTFS}" apt-get -y install grub-pc-bin grub-efi-ia32-bin grub-efi-amd64-bin

  # Kernel Frame Buffer
  chroot "${ROOTFS}" apt-get -y install v86d

  # LiveBoot Script
  echo '#!/bin/sh'                                                        >  "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo 'mountroot() {'                                                    >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  if [ -z ${NETBOOT} ]; then'                                     >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '    return 0;'                                                    >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  fi'                                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # environment'                                                  >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  local liveroot image lower upper work newroot opts'             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  liveroot="/run/liveroot"'                                       >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  image="${liveroot}/image"'                                      >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  lower="${liveroot}/lower"'                                      >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  upper="${liveroot}/upper"'                                      >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  work="${liveroot}/work"'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  newroot="${rootmnt}"'                                           >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  opts="lowerdir=${lower},upperdir=${upper},workdir=${work}"'     >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # network configuration'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  configure_networking'                                           >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # mount tmpfs'                                                  >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mkdir -p ${liveroot}'                                           >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mount -t tmpfs -o mode=0755 tmpfs ${liveroot}'                  >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  if [ ! $? -eq 0 ]; then'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '    panic "Unable to mount tmpfs..."'                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  fi'                                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # download squashfs image'                                      >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mkdir -p ${image}'                                              >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  chmod 0755 ${image}'                                            >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  wget ${NETBOOT} -O ${image}/root.squashfs'                      >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  if [ ! $? -eq 0 ]; then'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '    panic "Unable to download SquashFS image from ${NETBOOT}..."' >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  fi'                                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # mount squashfs'                                               >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  modprobe loop'                                                  >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  modprobe squashfs'                                              >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mkdir -p ${lower}'                                              >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  chmod 0755 ${lower}'                                            >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  losetup /dev/loop0 "${image}/root.squashfs"'                    >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mount -t squashfs -o ro /dev/loop0 "${lower}"'                  >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  if [ ! $? -eq 0 ]; then'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '    panic "Unable to mount SquashFS image..."'                    >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  fi'                                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo ''                                                                 >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  # mount overlay filesystem'                                     >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  modprobe overlay'                                               >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mkdir -p ${work}'                                               >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mkdir -p ${upper}'                                              >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  chmod 0755 ${work}'                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  chmod 0755 ${upper}'                                            >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  mount -t overlay -o ${opts} overlay ${newroot}/'                >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  if [ ! $? -eq 0 ]; then'                                        >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '    panic "Unable to mount Overlay filesystem..."'                >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '  fi'                                                             >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  echo '}'                                                                >> "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"

  # LiveBoot Hook
  echo '#!/bin/sh'                                   >  "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo ''                                            >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'set -e'                                      >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo ''                                            >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'if [ "$1" = prereqs ]; then'                 >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo '  exit 0'                                    >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'fi'                                          >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo ''                                            >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo '. /usr/share/initramfs-tools/hook-functions' >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo ''                                            >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'manual_add_modules loop'                     >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'manual_add_modules overlay'                  >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"
  echo 'manual_add_modules squashfs'                 >> "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"

  # Set Permission
  chmod 0755 "${ROOTFS}/usr/share/initramfs-tools/scripts/liveroot"
  chmod 0755 "${ROOTFS}/usr/share/initramfs-tools/hooks/liveroot"

  # Set Boot Type
  echo ''              >> "${ROOTFS}/etc/initramfs-tools/initramfs.conf"
  echo '# Boot Type'   >> "${ROOTFS}/etc/initramfs-tools/initramfs.conf"
  echo ''              >> "${ROOTFS}/etc/initramfs-tools/initramfs.conf"
  echo 'BOOT=liveroot' >> "${ROOTFS}/etc/initramfs-tools/initramfs.conf"

  # Check Desktop Environment
  if [ "x${DESKTOP}" != "xYES" ]; then
    # Auto Login
    mkdir -p "${ROOTFS}/etc/systemd/system/getty@tty1.service.d"
    echo "[Service]"                                                         >  "${ROOTFS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"
    echo "ExecStart="                                                        >> "${ROOTFS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"
    echo "ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux" >> "${ROOTFS}/etc/systemd/system/getty@tty1.service.d/autologin.conf"

    # Login Run Script
    echo "~/.startup.sh" >> "${ROOTFS}/root/.bash_login"

    # Startup Script
    echo '#!/bin/bash'                                                                           >  "${ROOTFS}/root/.startup.sh"
    echo ''                                                                                      >> "${ROOTFS}/root/.startup.sh"
    echo 'script_cmdline ()'                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '{'                                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '    local param'                                                                       >> "${ROOTFS}/root/.startup.sh"
    echo '    for param in $(< /proc/cmdline); do'                                               >> "${ROOTFS}/root/.startup.sh"
    echo '        case "${param}" in'                                                            >> "${ROOTFS}/root/.startup.sh"
    echo '            script=*) echo "${param#*=}" ; return 0 ;;'                                >> "${ROOTFS}/root/.startup.sh"
    echo '        esac'                                                                          >> "${ROOTFS}/root/.startup.sh"
    echo '    done'                                                                              >> "${ROOTFS}/root/.startup.sh"
    echo '}'                                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo ''                                                                                      >> "${ROOTFS}/root/.startup.sh"
    echo 'startup_script ()'                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '{'                                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '    local script rt'                                                                   >> "${ROOTFS}/root/.startup.sh"
    echo '    script="$(script_cmdline)"'                                                        >> "${ROOTFS}/root/.startup.sh"
    echo '    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then'                         >> "${ROOTFS}/root/.startup.sh"
    echo '        if [[ "${script}" =~ ^http:// || "${script}" =~ ^ftp:// ]]; then'              >> "${ROOTFS}/root/.startup.sh"
    echo '            wget "${script}" --retry-connrefused -q -O /tmp/startup_script >/dev/null' >> "${ROOTFS}/root/.startup.sh"
    echo '            rt=$?'                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '        else'                                                                          >> "${ROOTFS}/root/.startup.sh"
    echo '            cp "${script}" /tmp/startup_script'                                        >> "${ROOTFS}/root/.startup.sh"
    echo '            rt=$?'                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo '        fi'                                                                            >> "${ROOTFS}/root/.startup.sh"
    echo '        if [[ ${rt} -eq 0 ]]; then'                                                    >> "${ROOTFS}/root/.startup.sh"
    echo '            chmod +x /tmp/startup_script'                                              >> "${ROOTFS}/root/.startup.sh"
    echo '            /tmp/startup_script'                                                       >> "${ROOTFS}/root/.startup.sh"
    echo '        fi'                                                                            >> "${ROOTFS}/root/.startup.sh"
    echo '    fi'                                                                                >> "${ROOTFS}/root/.startup.sh"
    echo '}'                                                                                     >> "${ROOTFS}/root/.startup.sh"
    echo ''                                                                                      >> "${ROOTFS}/root/.startup.sh"
    echo 'if [[ $(tty) == "/dev/tty1" ]]; then'                                                  >> "${ROOTFS}/root/.startup.sh"
    echo '    startup_script'                                                                    >> "${ROOTFS}/root/.startup.sh"
    echo 'fi'                                                                                    >> "${ROOTFS}/root/.startup.sh"

    # Set Permission
    chmod 0755 "${ROOTFS}/root/.startup.sh"
  fi
fi

################################################################################
# Network
################################################################################

# Install NetworkManager
chroot "${ROOTFS}" apt-get -y --no-install-recommends install network-manager

# Check Device IP Address
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

# Install NTP Server
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

# Install OpenSSH Server
chroot "${ROOTFS}" apt-get -y install ssh

# Configure OpenSSH Server
echo ''          >> "${ROOTFS}/etc/ssh/sshd_config"
echo 'UseDNS=no' >> "${ROOTFS}/etc/ssh/sshd_config"

################################################################################
# Cloud-Init
################################################################################

# Install Cloud-Init
#chroot "${ROOTFS}" apt-get -y install cloud-init

################################################################################
# Desktop
################################################################################

# Check Desktop Environment
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
    chroot "${ROOTFS}" sh -c 'wget -qO- https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub | apt-key add -'

    # NVIDIA CUDA Repository
    echo '# NVIDIA CUDA Repository'    >  "${ROOTFS}/etc/apt/sources.list.d/nvidia-cuda.list"
    echo "deb ${MIRROR_NVIDIA_CUDA} /" >> "${ROOTFS}/etc/apt/sources.list.d/nvidia-cuda.list"

    # Update Repository
    chroot "${ROOTFS}" apt-get -y update

    # Upgrade System
    chroot "${ROOTFS}" apt-get -y dist-upgrade

    # Install Driver
    chroot "${ROOTFS}" apt-get -y install cuda-drivers

    # Load Boot Time DRM Kernel Mode Setting
    echo "nvidia"         >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_modeset" >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_uvm"     >> "${ROOTFS}/etc/initramfs-tools/modules"
    echo "nvidia_drm"     >> "${ROOTFS}/etc/initramfs-tools/modules"

    # Check Live Image Environment
    if [ "x${LIVE}" != "xYES" ]; then
      # Enable Kernel Mode Setting
      sed -i -e 's@^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"$@GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 \1"@' "${ROOTFS}/etc/default/grub"
    fi
  fi
fi

################################################################################
# Cleanup
################################################################################

# Remove Original Resolve
rm "${ROOTFS}/etc/resolvconf/resolv.conf.d/original"

# Cleanup Packages
chroot "${ROOTFS}" apt-get -y autoremove --purge
chroot "${ROOTFS}" apt-get -y clean

# Get Linux Kernel Version
_CURRENT_LINUX_VERSION="`uname -r`"
_CHROOT_LINUX_VERSION="`chroot \"${ROOTFS}\" dpkg -l | awk '{print $2}' | grep -E 'linux-image-.*-generic' | sed -E 's/linux-image-//'`"

# Check Linux Kernel Version
if [ "${_CURRENT_LINUX_VERSION}" != "${_CHROOT_LINUX_VERSION}" ]; then
  # Remove Current Kernel Version Module
  chroot "${ROOTFS}" update-initramfs -d -k "`uname -r`"
fi

# Update Initramfs
chroot "${ROOTFS}" update-initramfs -u -k all

# Check Live Image Environment
if [ "x${LIVE}" != "xYES" ]; then
  # Update Grub
  chroot "${ROOTFS}" update-grub

  # Disk Sync
  sync;sync;sync

  # Check Disk Type
  if [ "x${ROOT_DISK_TYPE}" = "xSSD" -o "x${ROOT_DISK_TYPE}" = "xNVME" ]; then
    # TRIM
    fstrim -v "${ROOTFS}"
  fi

  # Unmount RootFs
  awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount
else
  # Disable Boot Cache
  chroot "${ROOTFS}" systemctl disable ureadahead.service

  # Clean Cache Repository
  find "${ROOTFS}/var/lib/apt/lists" -type f | xargs rm
  touch "${ROOTFS}/var/lib/apt/lists/lock"
  chmod 0640 "${ROOTFS}/var/lib/apt/lists/lock"

  # Clean Log
  find "${ROOTFS}/var/log" -type f | xargs rm
  touch "${ROOTFS}/var/log/lastlog"
  chmod 0644 "${ROOTFS}/var/log/lastlog"

  # Unmount RootFs
  awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}/" | sort -r | xargs --no-run-if-empty umount

  # Create SquashFS Image
  mksquashfs "${ROOTFS}" "root.squashfs"

  # Copy Kernel and Initramfs
  find "${ROOTFS}/boot" -type f -name "vmlinuz-*-generic" -exec cp {} "./vmlinuz" \;
  find "${ROOTFS}/boot" -type f -name "initrd.img-*-generic" -exec cp {} "./initrd.img" \;

  # Permission Files
  chmod 0644 "./vmlinuz"
  chmod 0644 "./initrd.img"
  chmod 0644 "./root.squashfs"

  # Owner/Group Files
  if [ -n "${SUDO_UID}" -a -n "${SUDO_GID}" ]; then
    chown "${SUDO_UID}:${SUDO_GID}" "./vmlinuz"
    chown "${SUDO_UID}:${SUDO_GID}" "./initrd.img"
    chown "${SUDO_UID}:${SUDO_GID}" "./root.squashfs"
  fi
fi

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount

# Delete Working Directory
rmdir "${ROOTFS}"

# Complete Message
echo 'Complete Setup!'

# Reboot
reboot
