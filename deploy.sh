#!/bin/bash

set -eu

################################################################################
# Default Variables
################################################################################

# [YES|NO]
# shellcheck disable=SC2086
: ${SHUTDOWN:="NO"}

# [YES|NO]
# shellcheck disable=SC2086
: ${REBOOT:="NO"}

# Root File System Mount Point
# shellcheck disable=SC2086
: ${ROOTFS:="/rootfs"}

# [HDD|SSD|NVME]
# shellcheck disable=SC2086
: ${ROOT_DISK_TYPE:=""}

# List of /dev/disk/by-id/*
# shellcheck disable=SC2086
: ${ROOT_DISK_NAME:=""}

# Root Partition Size
# shellcheck disable=SC2086
: ${ROOT_PART_SIZE:="-1"}

# Swap Partition Size
# shellcheck disable=SC2086
: ${SWAP_PART_SIZE:="+16G"}

################################################################################
# Check Environment
################################################################################

# Root Disk Type
if [ "x${ROOT_DISK_TYPE}" != "xHDD" -a "x${ROOT_DISK_TYPE}" != "xSSD" -a "x${ROOT_DISK_TYPE}" != "xNVME" ]; then
  echo "ROOT_DISK_TYPE: HDD or SSD or NVME"
  exit 1
fi

# Root Disk Name
if [ ! -e "/dev/disk/by-id/${ROOT_DISK_NAME}" ]; then
  echo "ROOT_DISK_NAME: Please select by"
  find /dev/disk/by-id | sort
  exit 1
fi

# Deploy RootFs Url
DEPLOY_DISTRIBUTION=''
DEPLOY_RELEASE=''
DEPLOY_KERNEL=''
DEPLOY_PROFILE=''
DEPLOY_ROOTFS=''

# Default Result Code
RESULT=1

# Parse Boot Parameter
for param in $(< /proc/cmdline); do
  case "${param}" in
    distribution=*)
      if [ -n "${param#*=}" ]; then
        DEPLOY_DISTRIBUTION="${param#*=}"
        RESULT=0
      fi
      ;;
    release=*)
      if [ -n "${param#*=}" ]; then
        DEPLOY_RELEASE="${param#*=}"
        RESULT=0
      fi
      ;;
    kernel=*)
      if [ -n "${param#*=}" ]; then
        DEPLOY_KERNEL="${param#*=}"
        RESULT=0
      fi
      ;;
    profile=*)
      if [ -n "${param#*=}" ]; then
        DEPLOY_PROFILE="${param#*=}"
        RESULT=0
      fi
      ;;
    rootfs=*)
      if [[ "${param#*=}" =~ ^http:// || "${param#*=}" =~ ^https:// ]]; then
        DEPLOY_ROOTFS="${param#*=}"
        RESULT=0
      fi
      ;;
  esac
done

# Check Result Code
if [ "${RESULT}" -gt 0 ]; then
  echo 'Unknown Boot Parameter'
  echo "DEPLOY_DISTRIBUTION: ${DEPLOY_DISTRIBUTION}"
  echo "DEPLOY_RELEASE:      ${DEPLOY_RELEASE}"
  echo "DEPLOY_KERNEL:       ${DEPLOY_KERNEL}"
  echo "DEPLOY_PROFILE:      ${DEPLOY_PROFILE}"
  echo "DEPLOY_ROOTFS:       ${DEPLOY_ROOTFS}"
  cat /proc/cmdline
  exit 1
fi

################################################################################
# Require Packages
################################################################################

# Update Repository
apt-get -y update

# Install Packages
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

################################################################################
# Cleanup
################################################################################

# Get Disk ID
ROOT_DISK_PATH="$(realpath "/dev/disk/by-id/${ROOT_DISK_NAME}")"

# Unmount Swap Partition
swapoff -a

# Unmount Disk Drive
awk '{print $1}' /proc/mounts | grep -s "${ROOT_DISK_PATH}" | sort -r | xargs --no-run-if-empty umount

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Disk
################################################################################

# Check Disk Type
if [ "x${ROOT_DISK_TYPE}" = 'xSSD' ]; then
  # Check SSD Frozen
  if hdparm -I "${ROOT_DISK_PATH}" | grep 'frozen' | grep -qsv 'not' > /dev/null 2>&1; then
    # Suspend-to-RAM (ACPI State S3)
    rtcwake -m mem -s 10

    # Wait
    sleep 10
  fi

  # Set Password
  hdparm --user-master u --security-set-pass P@ssW0rd "${ROOT_DISK_PATH}"

  # Secure Erase
  hdparm --user-master u --security-erase P@ssW0rd "${ROOT_DISK_PATH}"
# Check Disk Type
elif [ "x${ROOT_DISK_TYPE}" = 'xNVME' ]; then
  # Suspend-to-RAM (ACPI State S3)
  rtcwake -m mem -s 10

  # Wait
  sleep 10

  # Secure Erase
  nvme format -s 1 "${ROOT_DISK_PATH}" || echo 'Not Secure Erase...'
fi

# Wait Probe
sleep 1

# Clear Partition Table
sgdisk -Z "${ROOT_DISK_PATH}"

# Create GPT Partition Table
sgdisk -o "${ROOT_DISK_PATH}"

# Create BIOS Partition
sgdisk -a 1 -n 1::2047                -c 1:"Bios" -t 1:ef02 "${ROOT_DISK_PATH}"

# Create EFI Partition
sgdisk      -n 2::+512M               -c 2:"Efi"  -t 2:ef00 "${ROOT_DISK_PATH}"

# Create Swap Partition
sgdisk      -n 3::"${SWAP_PART_SIZE}" -c 3:"Swap" -t 3:8200 "${ROOT_DISK_PATH}"

# Create Root Partition
sgdisk      -n 4::"${ROOT_PART_SIZE}" -c 4:"Root" -t 4:8300 "${ROOT_DISK_PATH}"

# Wait Probe
sleep 1

# Get Real Path
UEFIPT="$(realpath "/dev/disk/by-id/${ROOT_DISK_NAME}-part2")"
ROOTPT="$(realpath "/dev/disk/by-id/${ROOT_DISK_NAME}-part4")"
SWAPPT="$(realpath "/dev/disk/by-id/${ROOT_DISK_NAME}-part3")"

# Format EFI System Partition
mkfs.vfat -F 32 -n "EfiFs" "${UEFIPT}"

# Format Root File System Partition
mkfs.xfs -f -L "RootFs" "${ROOTPT}"

# Format Linux Swap Partition
mkswap -L "SwapFs" "${SWAPPT}"

# Mount Root File System Partition
mkdir -p "${ROOTFS}"
mount "${ROOTPT}" "${ROOTFS}"

# Mount EFI System Partition
mkdir -p "${ROOTFS}/boot/efi"
mount "${UEFIPT}" "${ROOTFS}/boot/efi"

# Mount Linux Swap Partition
swapon "${SWAPPT}"

################################################################################
# FileSystem
################################################################################

# Download Root FileSystem Archive
wget -O /tmp/rootfs.tar.xz "${DEPLOY_ROOTFS}"

# Extract Root FileSystem Archive
sudo tar -xvpJf /tmp/rootfs.tar.xz -C "${ROOTFS}" --numeric-owner

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
find "${ROOTFS}/dev"       -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${ROOTFS}/proc"      -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${ROOTFS}/run"       -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${ROOTFS}/sys"       -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${ROOTFS}/tmp"       -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${ROOTFS}/var/tmp"   -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr

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

# Resolve Configuration - resolvconf
if [ -f "/run/resolvconf/resolv.conf" ]; then
  # Create Resolv Configuration Directory
  mkdir -p "${ROOTFS}/run/resolvconf"

  # Copy Resolv Configuration
  cp /run/resolvconf/resolv.conf "${ROOTFS}/run/resolvconf/resolv.conf"
fi

# Resolve Configuration - systemd-resolved
if [ -f "/run/systemd/resolve/resolv.conf" ]; then
  # Create Resolv Configuration Directory
  mkdir -p "${ROOTFS}/run/systemd/resolve"

  # Copy Resolv Configuration
  cp /run/systemd/resolve/resolv.conf "${ROOTFS}/run/systemd/resolve/resolv.conf"
  cp /run/systemd/resolve/stub-resolv.conf "${ROOTFS}/run/systemd/resolve/stub-resolv.conf"
fi

# Create Mount Point
touch "${ROOTFS}/etc/fstab"
{
  echo '# <file system> <dir>      <type> <options>          <dump> <pass>'
  echo "${ROOTPT}       /          xfs    defaults           0      1"
  echo "${UEFIPT}       /boot/efi  vfat   defaults           0      2"
  echo "${SWAPPT}       none       swap   defaults           0      0"
  echo "tmpfs           /var/tmp   tmpfs  defaults,size=100% 0      0"
  echo "tmpfs           /tmp       tmpfs  defaults,size=100% 0      0"
} >> "${ROOTFS}/etc/fstab"

################################################################################
# Upgrade
################################################################################

# Update Repository
chroot "${ROOTFS}" apt-get -y update

# Upgrade System
chroot "${ROOTFS}" apt-get -y dist-upgrade

################################################################################
# Boot
################################################################################

# Check UEFI Platform
if [ -d "/sys/firmware/efi" ]; then
  # EFI Boot Manager
  chroot "${ROOTFS}" apt-get -y install efibootmgr

  # Grub Boot Loader
  chroot "${ROOTFS}" apt-get -y install grub-efi

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

# Check Profile
if [ "${DEPLOY_PROFILE}" = 'server' ]; then
  # Default Text Console
  sed -i -e 's@^GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"$@GRUB_CMDLINE_LINUX_DEFAULT="quiet"@' "${ROOTFS}/etc/default/grub"
fi

# Update Grub
chroot "${ROOTFS}" update-grub

################################################################################
# Addon
################################################################################

if [ "$(type deploy_addon)" = 'deploy_addon is a shell function' ]; then
  deploy_addon
fi

################################################################################
# Cleanup
################################################################################

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

# Complete Message
echo 'Complete Setup!'

# Check Reboot Flag
if [ "${REBOOT}" = "YES" ]; then
  # Reboot
  shutdown -r now
fi

# Check Shutdown Flag
if [ "${SHUTDOWN}" = "YES" ]; then
  # Shutdown
  shutdown -h now
fi
