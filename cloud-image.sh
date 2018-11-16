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

# Destination Directory
: ${DESTDIR:="$(cd $(dirname $0); pwd)/release"}

# Generic
: ${RELEASE:="bionic"} # [trusty|xenial|bionic]
: ${KERNEL:="generic"} # [generic|generic-hwe|signed-generic|signed-generic-hwe]
: ${PROFILE:="server"} # [minimal|standard|server|desktop]

# Cloud-Init Datasources
: ${DATASOURCES:="NoCloud"}

# Repository Mirror URL
: ${MIRROR_UBUNTU:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu"}
: ${MIRROR_UBUNTU_PARTNER:="http://archive.canonical.com"}
: ${MIRROR_UBUNTU_JA:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu"}
: ${MIRROR_UBUNTU_JA_NONFREE:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free"}

# Forward Proxy URL
: ${NO_PROXY:=""}
: ${APT_PROXY:=""}
: ${FTP_PROXY:=""}
: ${HTTP_PROXY:=""}
: ${HTTPS_PROXY:=""}

################################################################################
# Check Environment
################################################################################

# Release
case "${RELEASE}" in
  'trusty' ) ;;
  'xenial' ) ;;
  'bionic' ) ;;
  * )
    echo 'RELEASE: trusty or xenial or bionic'
    exit 1
    ;;
esac

# Kernel
case "${KERNEL}" in
  'generic' ) ;;
  'generic-hwe' ) ;;
  'signed-generic' ) ;;
  'signed-generic-hwe' ) ;;
  * )
    echo 'KERNEL: generic or generic-hwe or signed-generic or signed-generic-hwe'
    exit 1
    ;;
esac

# Profile
case "${PROFILE}" in
  'minimal' ) ;;
  'standard' ) ;;
  'server' ) ;;
  'desktop' ) ;;
  * )
    echo 'PROFILE: minimal or standard or server or desktop'
    exit 1
    ;;
esac

################################################################################
# Normalize Environment
################################################################################

# Select Kernel
case "${RELEASE}-${KERNEL}" in
  'bionic-generic-hwe'        ) KERNEL='generic' ;;
  'bionic-signed-generic-hwe' ) KERNEL='signed-generic' ;;
  *                           ) ;;
esac

################################################################################
# Require Environment
################################################################################

# Root File System Mount Point
declare WORKDIR='/run/rootfs'

# Destination Directory
declare DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

# Debootstrap Command
declare DEBOOTSTRAP_COMMAND='debootstrap'

# Debootstrap Variant
declare DEBOOTSTRAP_VARIANT='--variant=minbase'

# Debootstrap Components
declare DEBOOTSTRAP_COMPONENTS='--components=main,restricted,universe,multiverse'

# Debootstrap Include Packages
declare DEBOOTSTRAP_INCLUDES='--include=gnupg'

# Check APT Proxy
if [ "x${APT_PROXY_HOST}" != "x" -a "x${APT_PROXY_PORT}" != "x" ]; then
  # Debootstrap Apt Proxy Environment
  declare APT_PROXY="http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"

  # Debootstrap Proxy Command
  declare -a DEBOOTSTRAP_PROXY=( "env" "http_proxy=${APT_PROXY}" "https_proxy=${APT_PROXY}" "${DEBOOTSTRAP_COMMAND}" )

  # Debootstrap Override Command
  DEBOOTSTRAP_COMMAND="${DEBOOTSTRAP_PROXY[*]}"
fi

# Select Kernel Package
case "${RELEASE}-${KERNEL}" in
  'trusty-generic'            ) declare KERNEL_PACKAGE='linux-image-generic' ;;
  'xenial-generic'            ) declare KERNEL_PACKAGE='linux-image-generic' ;;
  'bionic-generic'            ) declare KERNEL_PACKAGE='linux-image-generic' ;;
  'trusty-generic-hwe'        ) declare KERNEL_PACKAGE='linux-image-generic-lts-xenial' ;;
  'xenial-generic-hwe'        ) declare KERNEL_PACKAGE='linux-image-generic-hwe-16.04' ;;
  'bionic-generic-hwe'        ) declare KERNEL_PACKAGE='linux-image-generic' ;;
  'trusty-signed-generic'     ) declare KERNEL_PACKAGE='linux-signed-image-generic' ;;
  'xenial-signed-generic'     ) declare KERNEL_PACKAGE='linux-signed-image-generic' ;;
  'bionic-signed-generic'     ) declare KERNEL_PACKAGE='linux-signed-image-generic' ;;
  'trusty-signed-generic-hwe' ) declare KERNEL_PACKAGE='linux-signed-image-generic-lts-xenial' ;;
  'xenial-signed-generic-hwe' ) declare KERNEL_PACKAGE='linux-signed-image-generic-hwe-16.04' ;;
  'bionic-signed-generic-hwe' ) declare KERNEL_PACKAGE='linux-signed-image-generic' ;;
  * )
    echo 'Unknown Release Codename & Kernel Type...'
    exit 1
    ;;
esac

# Glib Schemas Directory
declare GLIB_SCHEMAS_DIR='/usr/share/glib-2.0/schemas'

################################################################################
# Cleanup
################################################################################

# Check Release Directory
if [ -d "${DESTDIR}" ]; then
  # Cleanup Release Directory
  find "${DESTDIR}" -type f -print0 | xargs -0 rm -f
else
  # Create Release Directory
  mkdir -p "${DESTDIR}"
fi

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Disk
################################################################################

# Mount Root File System Partition
mkdir -p "${WORKDIR}"
mount -t tmpfs -o mode=0755 tmpfs "${WORKDIR}"

################################################################################
# Debootstrap
################################################################################

# Install Base System
${DEBOOTSTRAP_COMMAND} ${DEBOOTSTRAP_VARIANT} ${DEBOOTSTRAP_COMPONENTS} ${DEBOOTSTRAP_INCLUDES} "${RELEASE}" "${WORKDIR}" "${MIRROR_UBUNTU}"

# Require Environment
declare -x PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
declare -x HOME="/root"
declare -x LC_ALL="C"
declare -x LANGUAGE="C"
declare -x LANG="C"
declare -x DEBIAN_FRONTEND="noninteractive"
declare -x DEBIAN_PRIORITY="critical"
declare -x DEBCONF_NONINTERACTIVE_SEEN="true"

# Cleanup Files
find "${WORKDIR}/dev"     -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${WORKDIR}/proc"    -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${WORKDIR}/run"     -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${WORKDIR}/sys"     -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${WORKDIR}/tmp"     -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr
find "${WORKDIR}/var/tmp" -mindepth 1 -print0 | xargs -0 --no-run-if-empty rm -fr

# Require Mount
mount -t devtmpfs                   devtmpfs "${WORKDIR}/dev"
mount -t devpts   -o gid=5,mode=620 devpts   "${WORKDIR}/dev/pts"
mount -t proc                       proc     "${WORKDIR}/proc"
mount -t tmpfs    -o mode=755       tmpfs    "${WORKDIR}/run"
mount -t sysfs                      sysfs    "${WORKDIR}/sys"
mount -t tmpfs                      tmpfs    "${WORKDIR}/tmp"
mount -t tmpfs                      tmpfs    "${WORKDIR}/var/tmp"
chmod 1777 "${WORKDIR}/dev/shm"

################################################################################
# System
################################################################################

# Default Hostname
echo 'localhost' > "${WORKDIR}/etc/hostname"

################################################################################
# Repository
################################################################################

# Official Repository
cat > "${WORKDIR}/etc/apt/sources.list" << __EOF__
# Official Repository
deb ${MIRROR_UBUNTU} ${RELEASE}          main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-updates  main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-security main restricted universe multiverse
__EOF__

# Partner Repository
cat > "${WORKDIR}/etc/apt/sources.list.d/ubuntu-partner.list" << __EOF__
# Partner Repository
deb ${MIRROR_UBUNTU_PARTNER} ${RELEASE} partner
__EOF__

# Japanese Team Repository
wget -qO "${WORKDIR}/tmp/ubuntu-ja-archive-keyring.gpg" https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg
wget -qO "${WORKDIR}/tmp/ubuntu-jp-ppa-keyring.gpg" https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg
chroot "${WORKDIR}" apt-key add /tmp/ubuntu-ja-archive-keyring.gpg
chroot "${WORKDIR}" apt-key add /tmp/ubuntu-jp-ppa-keyring.gpg
cat > "${WORKDIR}/etc/apt/sources.list.d/ubuntu-ja.list" << __EOF__
# Japanese Team Repository
deb ${MIRROR_UBUNTU_JA} ${RELEASE} main
deb ${MIRROR_UBUNTU_JA_NONFREE} ${RELEASE} multiverse
__EOF__

################################################################################
# Upgrade
################################################################################

# Update Repository
chroot "${WORKDIR}" apt-get -y update

# Upgrade System
chroot "${WORKDIR}" apt-get -y dist-upgrade

################################################################################
# Minimal
################################################################################

# Minimal Package
chroot "${WORKDIR}" apt-get -y install ubuntu-minimal

################################################################################
# Standard
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'standard' -o "${PROFILE}" = 'server' -o "${PROFILE}" = 'desktop' ]; then
  # Install Package
  chroot "${WORKDIR}" apt-get -y install ubuntu-standard
fi

################################################################################
# Server
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'server' ]; then
  # Install Package
  chroot "${WORKDIR}" apt-get -y install ubuntu-server language-pack-ja
fi

################################################################################
# Desktop
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'desktop' ]; then
  # Check Release/Kernel Version
  case "${RELEASE}-${KERNEL}" in
    # Trusty Part
    trusty-*-hwe )
      # Require Packages
      chroot "${WORKDIR}" apt-get -y install \
        xserver-xorg-core-lts-xenial \
        xserver-xorg-input-all-lts-xenial \
        xserver-xorg-video-all-lts-xenial \
        libegl1-mesa-lts-xenial \
        libgbm1-lts-xenial \
        libgl1-mesa-dri-lts-xenial \
        libgl1-mesa-glx-lts-xenial \
        libgles1-mesa-lts-xenial \
        libgles2-mesa-lts-xenial \
        libwayland-egl1-mesa-lts-xenial

      # HWE Version Xorg Server
      chroot "${WORKDIR}" apt-get -y --no-install-recommends install xserver-xorg-lts-xenial
      ;;
    # Xenial Part
    xenial-*-hwe )
      # Require Packages
      chroot "${WORKDIR}" apt-get -y install \
        xserver-xorg-core-hwe-16.04 \
        xserver-xorg-input-all-hwe-16.04 \
        xserver-xorg-video-all-hwe-16.04 \
        xserver-xorg-legacy-hwe-16.04 \
        libgl1-mesa-dri

      # HWE Version Xorg Server
      chroot "${WORKDIR}" apt-get -y --no-install-recommends install xserver-xorg-hwe-16.04
      ;;
    # Bionic Part
    bionic-*-hwe )
      # None...
      ;;
  esac

  # Install Package
  chroot "${WORKDIR}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja

  # Check Release Version
  if [ "${RELEASE}" = 'bionic' ]; then
    # Workaround: Fix System Log Error Message
    chroot "${WORKDIR}" apt-get -y install gir1.2-clutter-1.0 gir1.2-clutter-gst-3.0 gir1.2-gtkclutter-1.0

    # Install Input Method Package
    chroot "${WORKDIR}" apt-get -y install fcitx fcitx-mozc

    # Default Input Method for Fcitx
    echo '[org.gnome.settings-daemon.plugins.keyboard]' >  "${WORKDIR}/${GLIB_SCHEMAS_DIR}/99_japanese-input-method.gschema.override"
    echo 'active=false'                                 >> "${WORKDIR}/${GLIB_SCHEMAS_DIR}/99_japanese-input-method.gschema.override"

    # Compile Glib Schemas
    chroot "${WORKDIR}" glib-compile-schemas "${GLIB_SCHEMAS_DIR}"
  fi
fi

################################################################################
# Cloud
################################################################################

# Select Datasources
chroot "${WORKDIR}" sh -c "echo 'cloud-init cloud-init/datasources multiselect ${DATASOURCES}' | debconf-set-selections"

# Require Package
chroot "${WORKDIR}" apt-get -y install cloud-init cloud-initramfs-copymods cloud-initramfs-dyn-netconf cloud-initramfs-rooturl overlayroot

################################################################################
# Cleanup
################################################################################

# Out Of Packages
chroot "${WORKDIR}" apt-get -y autoremove --purge

# Package Archive
chroot "${WORKDIR}" apt-get -y clean

# Repository List
find "${WORKDIR}/var/lib/apt/lists" -type f -print0 | xargs -0 rm -f
touch "${WORKDIR}/var/lib/apt/lists/lock"
chmod 0640 "${WORKDIR}/var/lib/apt/lists/lock"

################################################################################
# Infomation
################################################################################

# Packages List
chroot "${WORKDIR}" dpkg -l | sed -E '1,5d' | awk '{print $2 "\t" $3}' > "${DESTDIR}/packages.manifest"

################################################################################
# Archive
################################################################################

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}/" | sort -r | xargs --no-run-if-empty umount

# Create SquashFS Image
mksquashfs "${WORKDIR}" "${DESTDIR}/rootfs.squashfs" -e 'boot/grub' -comp xz

# Create TarBall Image
tar -I pixz -p --acls --xattrs --one-file-system -cf "${DESTDIR}/rootfs.tar.xz" -C "${WORKDIR}" --exclude './boot/grub' .

# Require Mount
mount -t devtmpfs                   devtmpfs "${WORKDIR}/dev"
mount -t devpts   -o gid=5,mode=620 devpts   "${WORKDIR}/dev/pts"
mount -t proc                       proc     "${WORKDIR}/proc"
mount -t tmpfs    -o mode=755       tmpfs    "${WORKDIR}/run"
mount -t sysfs                      sysfs    "${WORKDIR}/sys"
mount -t tmpfs                      tmpfs    "${WORKDIR}/tmp"
mount -t tmpfs                      tmpfs    "${WORKDIR}/var/tmp"
chmod 1777 "${WORKDIR}/dev/shm"

# Remove Resolv.conf
rm "${WORKDIR}/etc/resolv.conf"

# Copy Host Resolv.conf
cp /etc/resolv.conf "${WORKDIR}/etc/resolv.conf"

################################################################################
# Repository
################################################################################

# Update Repository
chroot "${WORKDIR}" apt-get -y update

################################################################################
# Kernel
################################################################################

# Install Kernel
chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${KERNEL_PACKAGE}"

# Copy Kernel
find "${WORKDIR}/boot" -type f -name "vmlinuz-*-generic" -exec cp {} "${DESTDIR}/kernel.img" \;

################################################################################
# Initramfs
################################################################################

# Get Linux Kernel Version
CURRENT_VERSION="$(uname -r)"
CHROOT_VERSION="$(chroot \"${WORKDIR}\" dpkg -l | awk '{print $2}' | grep -E 'linux-image-.*-generic' | sed -E 's/linux-image-//')"

# Check Linux Kernel Version
if [ "${CURRENT_VERSION}" != "${CHROOT_VERSION}" ]; then
  # Remove Current Kernel Version Module
  chroot "${WORKDIR}" update-initramfs -d -k "$(uname -r)"
fi

# Update Initramfs
chroot "${WORKDIR}" update-initramfs -u -k all

# Copy Initrd
find "${WORKDIR}/boot" -type f -name "initrd.img-*-generic" -exec cp {} "${DESTDIR}/initrd.img" \;

################################################################################
# Permission
################################################################################

# Permission Files
find "${DESTDIR}" -type f -print0 | xargs -0 chmod 0644

################################################################################
# Owner/Group
################################################################################

# Owner/Group Files
if [ -n "${SUDO_UID}" -a -n "${SUDO_GID}" ]; then
  chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi
