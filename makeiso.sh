#!/bin/bash
# vim: set noet :
# https://willhaley.com/blog/custom-debian-live-environment/

set -eu

################################################################################
# Load Environment
################################################################################

while getopts 'r:k:p:' OPTION; do
	case "${OPTION}" in
		r) RELEASE="${OPTARG}";;
		k) KERNEL="${OPTARG}";;
		p) PROFILE="${OPTARG}";;
	esac
done

################################################################################
# Default Variables
################################################################################

# Root File System Mount Point
# shellcheck disable=SC2086
: ${WORKDIR:='/tmp/liveiso'}

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
dpkg -l | awk '{print $2}' | grep -qs '^xorriso$'            || apt-get -y install xorriso
dpkg -l | awk '{print $2}' | grep -qs '^grub2-common$'       || apt-get -y install grub2-common
dpkg -l | awk '{print $2}' | grep -qs '^grub-pc-bin$'        || apt-get -y install grub-pc-bin
dpkg -l | awk '{print $2}' | grep -qs '^grub-efi-amd64-bin$' || apt-get -y install grub-efi-amd64-bin
dpkg -l | awk '{print $2}' | grep -qs '^mtools$'             || apt-get -y install mtools

################################################################################
# Check Environment
################################################################################

# Check Working Directory Variable
if [ "x${WORKDIR}" = "x" ]; then
  # Error...
  exit 1
fi

# Check Exists Destination Directory
if [ ! -d "${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}" ]; then
  # Error...
  exit 1
fi

################################################################################
# Require Environment
################################################################################

# Destination Directory
DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

################################################################################
# Cleanup
################################################################################

# Remove Old Image
rm -f "${DESTDIR}/live.iso"

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Initialize
################################################################################

# Mount Root File System Partition
mkdir -p "${WORKDIR}"
mount -t tmpfs -o 'mode=0755' tmpfs "${WORKDIR}"

################################################################################
# Directory
################################################################################

# Require Directory
mkdir -p "${WORKDIR}/img/live"
mkdir -p "${WORKDIR}/iso"

################################################################################
# Files
################################################################################

# Kernel
cp "${DESTDIR}/kernel.img" "${WORKDIR}/img/live/kernel.img"

# Initramfs
cp "${DESTDIR}/initrd.img" "${WORKDIR}/img/live/initrd.img"

# Rootfs
cp "${DESTDIR}/rootfs.squashfs" "${WORKDIR}/img/live/rootfs.squashfs"

################################################################################
# Bootloader
################################################################################

# Grub Config
cat > "${WORKDIR}/iso/grub.cfg" << '__EOF__'
if [ x$grub_platform = xpc ]; then
	insmod vbe
fi

if [ x$grub_platform = xefi ]; then
	insmod efi_gop
	insmod efi_uga
fi

set default=0
set timeout=0

menuentry 'ubuntu' {
	search --no-floppy --set=root --file /UBUNTU_LIVE
	probe -u $root --set=uuid
	linux /live/kernel.img liveroot-path=/live/rootfs.squashfs liveroot-uuid=$uuid overlayroot=tmpfs nouveau.modeset=0 nvidia-drm.modeset=1 cgroup_enable=memory swapaccount=1 quiet ---
	initrd /live/initrd.img
}
__EOF__

# Search Grub
touch "${WORKDIR}/img/UBUNTU_LIVE"

# UEFI Grub Image
grub-mkstandalone \
	--format=x86_64-efi \
	--output="${WORKDIR}/iso/bootx64.efi" \
	--locales="" \
	--fonts="" \
	"boot/grub/grub.cfg=${WORKDIR}/iso/grub.cfg"

# UEFI Disk Image
dd if=/dev/zero of="${WORKDIR}/iso/efiboot.img" bs=1M count=10
mkfs.vfat "${WORKDIR}/iso/efiboot.img"
mmd -i "${WORKDIR}/iso/efiboot.img" efi efi/boot
mcopy -i "${WORKDIR}/iso/efiboot.img" "${WORKDIR}/iso/bootx64.efi" ::efi/boot/

# BIOS Grub Image
grub-mkstandalone \
	--format=i386-pc \
	--output="${WORKDIR}/iso/core.img" \
	--install-modules="linux normal iso9660 biosdisk memdisk search tar test probe ls" \
	--modules="linux normal iso9660 biosdisk search test probe" \
	--locales="" \
	--fonts="" \
	"boot/grub/grub.cfg=${WORKDIR}/iso/grub.cfg"

# BIOS Disk Image
cat /usr/lib/grub/i386-pc/cdboot.img "${WORKDIR}/iso/core.img" > "${WORKDIR}/iso/bios.img"

################################################################################
# Generate
################################################################################

# ISO
xorriso \
	-as mkisofs \
	-iso-level 3 \
	-full-iso9660-filenames \
	-volid "UBUNTU_LIVE" \
	-eltorito-boot \
		boot/grub/bios.img \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		--eltorito-catalog boot/grub/boot.cat \
	--grub2-boot-info \
	--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
	-eltorito-alt-boot \
		-e EFI/efiboot.img \
		-no-emul-boot \
	-append_partition 2 0xef "${WORKDIR}/iso/efiboot.img" \
	-output "${DESTDIR}/live.iso" \
	-graft-points \
		"${WORKDIR}/img" \
		"/boot/grub/bios.img=${WORKDIR}/iso/bios.img" \
		"/EFI/efiboot.img=${WORKDIR}/iso/efiboot.img"

################################################################################
# Cleanup
################################################################################

# Owner/Group Files
if [ -n "${SUDO_UID}" ] && [ -n "${SUDO_GID}" ]; then
	chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi

# Unmount Working Directory
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

# Cleanup Working Directory
rmdir "${WORKDIR}"
