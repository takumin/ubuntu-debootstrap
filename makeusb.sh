#!/bin/sh

set -e

: ${USB_PATH:=""}
: ${ESP_DIR:="/mnt/esp"}

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
if [ "x${ESP_DIR}" = "x" ]; then
  # Error...
  exit 1
fi

# Get Real Disk Path
USB_PATH="`realpath /dev/disk/by-id/${USB_NAME}`"

# Unmount Disk Drive
awk '{print $1}' /proc/mounts | grep -s "${USB_PATH}" | sort -r | xargs --no-run-if-empty umount

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${ESP_DIR}" | sort -r | xargs --no-run-if-empty umount

# Create Working Directory
if [ ! -d "${ESP_DIR}" ]; then
  mkdir -p ${ESP_DIR}
fi

################################################################################
# Partition
################################################################################

# MBR Partition Table
parted -s ${USB_PATH} 'mklabel msdos'
# EFI System Partition
parted -s ${USB_PATH} 'mkpart primary 1MiB 1GiB'
# USB Data Partition
parted -s ${USB_PATH} 'mkpart primary 1GiB -0'
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
mount -t vfat -o codepage=932,iocharset=utf8 ${USB_PATH}1 ${ESP_DIR}

################################################################################
# Directory
################################################################################

# Require Directory
mkdir -p ${ESP_DIR}/boot
mkdir -p ${ESP_DIR}/casper
mkdir -p ${ESP_DIR}/efi/boot

################################################################################
# Files
################################################################################

# Kernel
cp ./vmlinuz ${ESP_DIR}/casper/vmlinuz

# Initramfs
cp ./initrd.img ${ESP_DIR}/casper/initrd.img

# Rootfs
cp ./root.squashfs ${ESP_DIR}/casper/filesystem.squashfs

################################################################################
# Grub
################################################################################

# Get UUID
UUID="`blkid -s UUID -o value ${USB_PATH}1`"

# Grub Install
grub-install --target=i386-pc --recheck --boot-directory=${ESP_DIR}/boot ${USB_PATH}
grub-install --target=x86_64-efi --recheck --boot-directory=${ESP_DIR}/boot --efi-directory=${ESP_DIR} --removable

# Grub Config
cat << __EOF__ > ${ESP_DIR}/boot/grub/grub.cfg
set default=0
set timeout=0

if [ \${grub_platform} == "efi" ]; then
	insmod efi_gop
	insmod efi_uga
fi

insmod font
if loadfont \${prefix}/unicode.pf2 ; then
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
awk '{print $2}' /proc/mounts | grep -s "${ESP_DIR}" | sort -r | xargs --no-run-if-empty umount

# Cleanup Working Directory
rmdir ${ESP_DIR}

# Disk Sync
sync;sync;sync
