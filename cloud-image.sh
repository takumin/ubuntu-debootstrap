#!/bin/bash

set -e

################################################################################
# Load Environment
################################################################################

if [ -n "$1" -a -r "$1" ]; then
  . "$1"
fi

################################################################################
# Default Variables
################################################################################

# Generic
: ${MODE:="rootfs"}     # [rootfs|kernel|initrd]
: ${TYPE:="server"}     # [server|desktop]
: ${RELEASE:="bionic"}  # [trusty|xenial|bionic]
: ${KERNEL:="generic"}  # [generic|generic-hwe|signed-generic|signed-generic-hwe]

# Cloud
: ${DATASOURCES:="NoCloud"} # Cloud-Init Datasources

# Disk
: ${ROOTFS:="/run/rootfs"}  # Root File System Mount Point

# Mirror
: ${MIRROR_UBUNTU:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu"}
: ${MIRROR_UBUNTU_PARTNER:="http://archive.canonical.com"}
: ${MIRROR_UBUNTU_JA:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu"}
: ${MIRROR_UBUNTU_JA_NONFREE:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free"}
: ${MIRROR_NVIDIA_CUDA:="http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64"}

################################################################################
# Check Environment
################################################################################

# Mode
if [ "${MODE}" != 'rootfs' -a "${MODE}" != 'kernel' -a "${MODE}" != 'initrd' ]; then
  echo "MODE: rootfs or kernel or initrd"
  exit 1
fi

# Type
if [ "${TYPE}" != 'server' -a "${TYPE}" != 'desktop' ]; then
  echo "TYPE: server or desktop"
  exit 1
fi

# Release
if [ "${RELEASE}" != 'trusty' -a "${RELEASE}" != 'xenial' -a "${RELEASE}" != 'bionic' ]; then
  echo "RELEASE: trusty or xenial or bionic"
  exit 1
fi

# Kernel
if [ "${KERNEL}" != 'generic' -a "${KERNEL}" != 'generic-hwe' -a "${KERNEL}" != 'signed-generic' -a "${KERNEL}" != 'signed-generic-hwe' ]; then
  echo "KERNEL: generic or generic-hwe or signed-generic or signed-generic-hwe"
  exit 1
fi

################################################################################
# Cleanup
################################################################################

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Disk
################################################################################

# Mount Root File System Partition
mkdir -p "${ROOTFS}"
mount -t tmpfs -o mode=0755 tmpfs "${ROOTFS}"

################################################################################
# Debootstrap
################################################################################

# Flavour
FLAVOUR="--flavour=minimal"

# Debootstrap Include Packages
INCLUDE="--include=gnupg"

# Install Base System
cdebootstrap-static "${FLAVOUR}" "${INCLUDE}" "Ubuntu/${RELEASE}" "${ROOTFS}" "${MIRROR_UBUNTU}"

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
find "${ROOTFS}/dev"     -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/proc"    -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/run"     -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/sys"     -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/tmp"     -mindepth 1 | xargs --no-run-if-empty rm -fr
find "${ROOTFS}/var/tmp" -mindepth 1 | xargs --no-run-if-empty rm -fr

# Require Mount
mount -t devtmpfs                   devtmpfs "${ROOTFS}/dev"
mount -t devpts   -o gid=5,mode=620 devpts   "${ROOTFS}/dev/pts"
mount -t proc                       proc     "${ROOTFS}/proc"
mount -t tmpfs    -o mode=755       tmpfs    "${ROOTFS}/run"
mount -t sysfs                      sysfs    "${ROOTFS}/sys"
mount -t tmpfs                      tmpfs    "${ROOTFS}/tmp"
mount -t tmpfs                      tmpfs    "${ROOTFS}/var/tmp"
chmod 1777 "${ROOTFS}/dev/shm"

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

################################################################################
# Upgrade
################################################################################

# Update Repository
chroot "${ROOTFS}" apt-get -y update

# Upgrade System
chroot "${ROOTFS}" apt-get -y dist-upgrade

################################################################################
# Standard
################################################################################

# Minimal Package
chroot "${ROOTFS}" apt-get -y install ubuntu-minimal

# Standard Package
chroot "${ROOTFS}" apt-get -y install ubuntu-standard

################################################################################
# Cloud
################################################################################

# Require Package
chroot "${ROOTFS}" apt-get -y install cloud-init

# Clear Default Config
echo "" > "${ROOTFS}/etc/cloud/cloud.cfg"

# Select Datasources
sed -i -E "s/^(datasource_list:) .*/\\1 [ ${DATASOURCES}, None ]/" "${ROOTFS}/etc/cloud/cloud.cfg.d/90_dpkg.cfg"

################################################################################
# Kernel
################################################################################

# Check Environment Variable
if [ "${MODE}" = 'kernel' -o "${MODE}" = 'initrd' ]; then
  # Select Kernel
  case "${RELEASE}-${KERNEL}" in
    "trusty-generic"            ) KERNEL_PACKAGE="linux-image-generic" ;;
    "xenial-generic"            ) KERNEL_PACKAGE="linux-image-generic" ;;
    "bionic-generic"            ) KERNEL_PACKAGE="linux-image-generic" ;;
    "trusty-generic-hwe"        ) KERNEL_PACKAGE="linux-image-generic-lts-xenial" ;;
    "xenial-generic-hwe"        ) KERNEL_PACKAGE="linux-image-generic-hwe-16.04" ;;
    "bionic-generic-hwe"        ) KERNEL_PACKAGE="linux-image-generic" ;;
    "trusty-signed-generic"     ) KERNEL_PACKAGE="linux-signed-image-generic" ;;
    "xenial-signed-generic"     ) KERNEL_PACKAGE="linux-signed-image-generic" ;;
    "bionic-signed-generic"     ) KERNEL_PACKAGE="linux-signed-image-generic" ;;
    "trusty-signed-generic-hwe" ) KERNEL_PACKAGE="linux-signed-image-generic-lts-xenial" ;;
    "xenial-signed-generic-hwe" ) KERNEL_PACKAGE="linux-signed-image-generic-hwe-16.04" ;;
    "bionic-signed-generic-hwe" ) KERNEL_PACKAGE="linux-signed-image-generic" ;;
    * )
      echo "Unknown Release Codename & Kernel Type..."
      exit 1
      ;;
  esac

  # Install Kernel
  chroot "${ROOTFS}" apt-get -y install "${KERNEL_PACKAGE}"
fi

################################################################################
# Server
################################################################################

# Check Environment Variable
if [ "${MODE}" = 'rootfs' -a "${TYPE}" = 'server' ]; then
  # Server Package
  chroot "${ROOTFS}" apt-get -y install ubuntu-server language-pack-ja

  # Check Install Boot Loader
  if [ ! -e "${ROOTFS}/boot/grub/grub.cfg" ]; then
    # Purge EC2 Grub Boot Loader
    chroot "${ROOTFS}" apt-get -y purge grub-legacy-ec2

    # Cleanup Boot Directory
    rm -fr "${ROOTFS}/boot/grub"
  fi
fi

################################################################################
# Desktop
################################################################################

# Check Environment Variable
if [ "${MODE}" = 'rootfs' -a "${TYPE}" = 'desktop' ]; then
  # Server Package
  chroot "${ROOTFS}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja
fi

################################################################################
# Initramfs
################################################################################

# Check Environment Variable
if [ "${MODE}" = 'initrd' ]; then
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
fi

################################################################################
# Cleanup
################################################################################

# Out Of Packages
chroot "${ROOTFS}" apt-get -y autoremove --purge

# Package Archive
chroot "${ROOTFS}" apt-get -y clean

# Repository List
find "${ROOTFS}/var/lib/apt/lists" -type f | xargs rm
touch "${ROOTFS}/var/lib/apt/lists/lock"
chmod 0640 "${ROOTFS}/var/lib/apt/lists/lock"

# Log
find "${ROOTFS}/var/log" -type f | xargs rm
touch "${ROOTFS}/var/log/lastlog"
chmod 0644 "${ROOTFS}/var/log/lastlog"

################################################################################
# Release
################################################################################

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}/" | sort -r | xargs --no-run-if-empty umount

# Create Release Directory
[ ! -d "./release/${RELEASE}/${TYPE}/${KERNEL}" ] && mkdir -p "./release/${RELEASE}/${TYPE}/${KERNEL}"

# Packages List
chroot "${ROOTFS}" dpkg -l | sed -E '1,5d' | awk '{print $2}' > "./release/${RELEASE}/${TYPE}/${KERNEL}/${MODE}.manifest"

case "${MODE}" in
  "rootfs" )
    # Create SquashFS Image
    mksquashfs "${ROOTFS}" "./release/${RELEASE}/${TYPE}/${KERNEL}/${MODE}.squashfs" -comp xz
    ;;
  "kernel" )
    # Copy Kernel
    find "${ROOTFS}/boot" -type f -name "vmlinuz-*-generic" -exec cp {} "./release/${RELEASE}/${TYPE}/${KERNEL}/${MODE}.img" \;
    ;;
  "initrd" )
    # Copy Initrd
    find "${ROOTFS}/boot" -type f -name "initrd.img-*-generic" -exec cp {} "./release/${RELEASE}/${TYPE}/${KERNEL}/${MODE}.img" \;
    ;;
  * )
    echo "Unknown Generate Mode..."
    exit 1
    ;;
esac

################################################################################
# Permission
################################################################################

# Permission Files
find "./release" -type f | xargs chmod 0644

################################################################################
# Permission
################################################################################

# Owner/Group Files
if [ -n "${SUDO_UID}" -a -n "${SUDO_GID}" ]; then
  chown -R "${SUDO_UID}:${SUDO_GID}" "./release"
fi
