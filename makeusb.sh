#!/bin/sh
# vim: set noet :

set -eu

################################################################################
# Load Environment
################################################################################

if [ -n "$1" ] && [ -r "$1" ]; then
	# shellcheck source=/dev/null
	. "$1"
fi

################################################################################
# Default Variables
################################################################################

# USB Device ID
# shellcheck disable=SC2086
: ${USB_NAME:=""}

# Root File System Mount Point
# shellcheck disable=SC2086
: ${WORKDIR:='/run/liveusb'}

# Destination Directory
# shellcheck disable=SC2086
: ${DESTDIR:="$(cd "$(dirname "$0")"; pwd)/release"}

# Release Codename
# Value: [trusty|xenial|bionic]
# shellcheck disable=SC2086
: ${RELEASE:='bionic'}

# Kernel Package
# Value: [generic|generic-hwe|signed-generic|signed-generic-hwe]
# shellcheck disable=SC2086
: ${KERNEL:='generic'}

# Package Selection
# Value: [minimal|standard|server|server-nvidia|desktop|desktop-ubiquity|desktop-nvidia|desktop-nvidia-ubiquity]
# shellcheck disable=SC2086
: ${PROFILE:='server'}

################################################################################
# Require
################################################################################

# Install Require Packages
dpkg -l | awk '{print $2}' | grep -qs '^parted$'             || apt-get -y install parted
dpkg -l | awk '{print $2}' | grep -qs '^dosfstools$'         || apt-get -y install dosfstools
dpkg -l | awk '{print $2}' | grep -qs '^grub-pc-bin$'        || apt-get -y install grub-pc-bin
dpkg -l | awk '{print $2}' | grep -qs '^grub-efi-amd64-bin$' || apt-get -y install grub-efi-amd64-bin

################################################################################
# Initialize
################################################################################

# Check Variable
if [ "x${USB_NAME}" = "x" ]; then
  # Error...
  exit 1
fi

# Check Variable
if [ "x${WORKDIR}" = "x" ]; then
  # Error...
  exit 1
fi

# Destination Directory
DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

# Get Real Disk Path
USB_PATH="`realpath /dev/disk/by-id/${USB_NAME}`"

# Unmount Disk Drive
awk '{print $1}' /proc/mounts | grep -s "${USB_PATH}" | sort -r | xargs --no-run-if-empty umount

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

# Create Working Directory
if [ ! -d "${WORKDIR}" ]; then
  mkdir -p ${WORKDIR}
fi

################################################################################
# Partition
################################################################################

# MBR Partition Table
parted -s ${USB_PATH} 'mklabel msdos'
# EFI System Partition
parted -s ${USB_PATH} 'mkpart primary 1MiB 2GiB'
# USB Data Partition
parted -s ${USB_PATH} 'mkpart primary 2GiB -0'
# Set Hidden Flag
parted -s ${USB_PATH} 'set 1 hidden on'
# Set Boot Flag
parted -s ${USB_PATH} 'set 1 boot on'
# Set LBA Flag
parted -s ${USB_PATH} 'set 2 lba on'
# Wait
sleep 1

################################################################################
# Format
################################################################################

# Format Partition
mkfs.vfat -F 32 -n 'ESP' -v ${USB_PATH}1
mkfs.vfat -F 32 -n 'USB' -v ${USB_PATH}2

################################################################################
# Mount
################################################################################

# Mount Partition
mount -t vfat -o codepage=932,iocharset=utf8 ${USB_PATH}1 ${WORKDIR}

################################################################################
# Directory
################################################################################

# Require Directory
mkdir -p ${WORKDIR}/boot
mkdir -p ${WORKDIR}/casper
mkdir -p ${WORKDIR}/efi/boot

################################################################################
# Files
################################################################################

# Kernel
cp "${DESTDIR}/kernel.img" ${WORKDIR}/casper/vmlinuz

# Initramfs
cp "${DESTDIR}/initrd.img" ${WORKDIR}/casper/initrd.img

# Rootfs
cp "${DESTDIR}/rootfs.squashfs" ${WORKDIR}/casper/filesystem.squashfs

################################################################################
# Grub
################################################################################

# Get UUID
UUID="`blkid -s UUID -o value ${USB_PATH}1`"

# Grub Install
grub-install --target=i386-pc --recheck --boot-directory=${WORKDIR}/boot ${USB_PATH}
grub-install --target=x86_64-efi --recheck --boot-directory=${WORKDIR}/boot --efi-directory=${WORKDIR} --removable

# Grub Config
cat << __EOF__ > ${WORKDIR}/boot/grub/grub.cfg
set default=0
set timeout=0

if [ \${grub_platform} == "efi" ]; then
	insmod efi_gop
	insmod efi_uga
fi

insmod font
if loadfont \${prefix}/fonts/unicode.pf2 ; then
	insmod gfxterm
	set gfxmode=auto
	set gfxpayload=keep
	terminal_output gfxterm
fi

insmod gzio
insmod part_msdos
insmod fat

menuentry "Ubuntu" {
	search --fs-uuid --set --no-floppy ${UUID}
	linux /casper/vmlinuz video=efifb boot=casper toram noprompt nomodeset quiet splash
	initrd /casper/initrd.img
}
__EOF__

################################################################################
# Cleanup
################################################################################

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

# Cleanup Working Directory
rmdir ${WORKDIR}

# Disk Sync
sync;sync;sync
