#!/bin/bash
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
dpkg -l | awk '{print $2}' | grep -qs '^gdisk$'              || apt-get -y install gdisk
dpkg -l | awk '{print $2}' | grep -qs '^dosfstools$'         || apt-get -y install dosfstools
dpkg -l | awk '{print $2}' | grep -qs '^grub2-common$'       || apt-get -y install grub2-common
dpkg -l | awk '{print $2}' | grep -qs '^grub-pc-bin$'        || apt-get -y install grub-pc-bin
dpkg -l | awk '{print $2}' | grep -qs '^grub-efi-amd64-bin$' || apt-get -y install grub-efi-amd64-bin

################################################################################
# Check Environment
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

################################################################################
# Require Environment
################################################################################

# Destination Directory
DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

# Get Real Disk Path
USB_PATH="$(realpath /dev/disk/by-id/${USB_NAME})"

################################################################################
# Cleanup
################################################################################

# Unmount Disk Drive
awk '{print $1}' /proc/mounts | grep -s "${USB_PATH}" | sort -r | xargs --no-run-if-empty umount

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Initialize
################################################################################

# Create Working Directory
mkdir -p ${WORKDIR}

################################################################################
# Partition
################################################################################

# Clear Partition Table
sgdisk -Z "${USB_PATH}"

# Create GPT Partition Table
sgdisk -o "${USB_PATH}"

# Create BIOS Boot Partition
sgdisk -a 1 -n 1::2047 -c 1:"BIOS" -t 1:ef02 "${USB_PATH}"

# Create EFI System Partition
sgdisk      -n 2::+2G  -c 2:"ESP"  -t 2:ef00 "${USB_PATH}"

# Create USB Data Partition
sgdisk      -n 3::-1   -c 3:"USB"  -t 3:0700 "${USB_PATH}"

# Wait Probe
sleep 1

# Get Real Path
ESPPT="$(realpath "/dev/disk/by-id/${USB_PATH}-part2")"
USBPT="$(realpath "/dev/disk/by-id/${USB_PATH}-part3")"

# Get UUID
UUID="$(blkid -s UUID -o value "${ESPPT}")"

################################################################################
# Format
################################################################################

# Format Partition
mkfs.vfat -F 32 -n 'ESP' -v "${ESPPT}"
mkfs.vfat -F 32 -n 'USB' -v "${USBPT}"

################################################################################
# Mount
################################################################################

# Mount Partition
mount -t vfat -o codepage=932,iocharset=utf8 "${ESPPT}" "${WORKDIR}"

################################################################################
# Directory
################################################################################

# Require Directory
mkdir -p "${WORKDIR}/boot"
mkdir -p "${WORKDIR}/live"

################################################################################
# Files
################################################################################

# Kernel
cp "${DESTDIR}/kernel.img" "${WORKDIR}/live/kernel.img"

# Initramfs
cp "${DESTDIR}/initrd.img" "${WORKDIR}/live/initrd.img"

# Rootfs
cp "${DESTDIR}/rootfs.squashfs" "${WORKDIR}/live/rootfs.squashfs"

################################################################################
# Grub
################################################################################

# Grub Install
grub-install --target=i386-pc --recheck --boot-directory="${WORKDIR}/boot" "${USB_PATH}"
grub-install --target=x86_64-efi --recheck --boot-directory="${WORKDIR}/boot" --efi-directory="${WORKDIR}/boot" --removable

# Grub Config
cat > "${WORKDIR}/boot/grub/grub.cfg" << __EOF__
if [ x\$grub_platform = xpc ]; then
	insmod vbe
fi

if [ x\$grub_platform = xefi ]; then
	insmod efi_gop
	insmod efi_uga
fi

insmod gzio

insmod font

if loadfont \${prefix}/fonts/unicode.pf2; then
	insmod gfxterm
	set gfxmode=auto
	set gfxpayload=keep
	terminal_output gfxterm
fi

insmod part_gpt
insmod part_msdos

insmod fat

set default=0
set timeout=0

menuentry 'ubuntu' {
	search --no-floppy --fs-uuid --set=root ${UUID}
	linux /live/kernel.img root= ro quiet splash overlayroot=tmpfs ---
	initrd /live/initrd.img
}
__EOF__

################################################################################
# Cleanup
################################################################################

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

# Cleanup Working Directory
rmdir "${WORKDIR}"

# Disk Sync
sync;sync;sync
