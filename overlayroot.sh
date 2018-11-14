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
: ${RELEASE:="bionic"} # [trusty|xenial|bionic]
: ${KERNEL:="generic"} # [generic|generic-hwe|signed-generic|signed-generic-hwe]
: ${PROFILE:="server"} # [minimal|standard|server|server-nvidia|desktop|desktop-nvidia]
: ${KEYBOARD:="JP"}    # [JP|US]

# User
: ${USER_NAME:="ubuntu"}
: ${USER_PASS:="ubuntu"}
: ${USER_FULL:="Ubuntu User"}
: ${USER_KEYS:=""}

# Storage
: ${ROOTFS:="/run/rootfs"}                                # Root File System Mount Point
: ${DESTDIR:="./release/${RELEASE}-${KERNEL}-${PROFILE}"} # Destination Directory

# Mirror
: ${MIRROR_UBUNTU:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu"}
: ${MIRROR_UBUNTU_PARTNER:="http://archive.canonical.com"}
: ${MIRROR_UBUNTU_JA:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu"}
: ${MIRROR_UBUNTU_JA_NONFREE:="http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free"}
: ${MIRROR_NVIDIA_CUDA:="http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64"}

# Proxy
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
    echo "RELEASE: trusty or xenial or bionic"
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
    echo "KERNEL: generic or generic-hwe or signed-generic or signed-generic-hwe"
    exit 1
    ;;
esac

# Profile
case "${PROFILE}" in
  'minimal' ) ;;
  'standard' ) ;;
  'server' ) ;;
  'server-nvidia' ) ;;
  'desktop' ) ;;
  'desktop-nvidia' ) ;;
  * )
    echo "PROFILE: minimal or standard or server or server-nvidia or desktop or desktop-nvidia"
    exit 1
    ;;
esac

################################################################################
# Cleanup
################################################################################

# Check Release Directory
if [ -d "${DESTDIR}" ]; then
  # Cleanup Release Directory
  find "${DESTDIR}" -type f | xargs rm -f
else
  # Create Release Directory
  mkdir -p "${DESTDIR}"
fi

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

# Debootstrap Use Variant
VARIANT="--variant=minbase"

# Debootstrap Components
COMPONENTS="--components=main,restricted,universe,multiverse"

# Debootstrap Include Packages
INCLUDE="--include=gnupg,tzdata,locales,console-setup"

# Check APT Proxy
if [ "x${APT_PROXY_HOST}" != "x" -a "x${APT_PROXY_PORT}" != "x" ]; then
  APT_PROXY="http://${APT_PROXY_HOST}:${APT_PROXY_PORT}"
  DEBOOTSTRAP_COMMAND="env http_proxy=\"${APT_PROXY}\" https_proxy=\"${APT_PROXY}\" debootstrap"
else
  DEBOOTSTRAP_COMMAND="debootstrap"
fi

# Install Base System
${DEBOOTSTRAP_COMMAND} "${VARIANT}" "${COMPONENTS}" "${INCLUDE}" "${RELEASE}" "${ROOTFS}" "${MIRROR_UBUNTU}"

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
if [ "${KEYBOARD}" = 'JP' ]; then
  # Japanese Keyboard
  sed -i -e 's@XKBMODEL="pc105"@XKBMODEL="jp106"@' "${ROOTFS}/etc/default/keyboard"
  sed -i -e 's@XKBLAYOUT="us"@XKBLAYOUT="jp"@'     "${ROOTFS}/etc/default/keyboard"
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
chroot "${ROOTFS}" adduser "${USER_NAME}" plugdev
chroot "${ROOTFS}" adduser "${USER_NAME}" sambashare
chroot "${ROOTFS}" adduser "${USER_NAME}" staff
chroot "${ROOTFS}" adduser "${USER_NAME}" sudo
chroot "${ROOTFS}" adduser "${USER_NAME}" users
chroot "${ROOTFS}" adduser "${USER_NAME}" video

# Trusty/Xenial Only
if [ "${RELEASE}" = 'trusty' -o "${RELEASE}" = 'xenial' ]; then
  chroot "${ROOTFS}" adduser "${USER_NAME}" netdev
fi

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

################################################################################
# Repository
################################################################################

# Official Repository
cat > "${ROOTFS}/etc/apt/sources.list" << __EOF__
# Official Repository
deb ${MIRROR_UBUNTU} ${RELEASE}           main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-updates   main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-backports main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-security  main restricted universe multiverse
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
# Kernel
################################################################################

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
chroot "${ROOTFS}" apt-get -y --no-install-recommends install "${KERNEL_PACKAGE}"

################################################################################
# Minimal
################################################################################

# Minimal Package
chroot "${ROOTFS}" apt-get -y install ubuntu-minimal

################################################################################
# Overlay
################################################################################

# Require Package
chroot "${ROOTFS}" apt-get -y install cloud-initramfs-dyn-netconf cloud-initramfs-rooturl overlayroot

################################################################################
# Standard
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'standard' -o "${PROFILE}" = 'server' -o "${PROFILE}" = 'server-nvidia' -o "${PROFILE}" = 'desktop' -o "${PROFILE}" = 'desktop-nvidia' ]; then
  # Install Package
  chroot "${ROOTFS}" apt-get -y install ubuntu-standard
fi

################################################################################
# Server
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'server' -o "${PROFILE}" = 'server-nvidia' ]; then
  # Install Package
  chroot "${ROOTFS}" apt-get -y install ubuntu-server language-pack-ja
fi

################################################################################
# Desktop
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'desktop' -o "${PROFILE}" = 'desktop-nvidia' ]; then
  # HWE Version Xorg
  if [ "${RELEASE}-${KERNEL}" = 'trusty-generic-hwe' -o "${RELEASE}-${KERNEL}" = 'trusty-signed-generic-hwe' ]; then
    chroot "${ROOTFS}" apt-get -y install xserver-xorg-lts-xenial \
                                          xserver-xorg-core-lts-xenial \
                                          xserver-xorg-input-all-lts-xenial \
                                          xserver-xorg-video-all-lts-xenial \
                                          libwayland-egl1-mesa-lts-xenial
  elif [ "${RELEASE}-${KERNEL}" = 'xenial-generic-hwe' -o "${RELEASE}-${KERNEL}" = 'xenial-signed-generic-hwe' ]; then
    chroot "${ROOTFS}" apt-get -y install xserver-xorg-hwe-16.04
  fi

  # Install Package
  chroot "${ROOTFS}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja

  # User Directory
  chroot "${ROOTFS}" su -c "LANG=C xdg-user-dirs-update" "${USER_NAME}"
  rm "${ROOTFS}/home/${USER_NAME}/.config/user-dirs.locale"

  # Check Release Version
  if [ "${RELEASE}" = 'bionic' ]; then
    # Workaround: System Log Error Message
    # https://askubuntu.com/questions/1044635/why-do-i-receive-an-error-message-while-trying-to-access-some-of-my-gnome-shell
    chroot "${ROOTFS}" apt-get -y install gir1.2-clutter-1.0 gir1.2-clutter-gst-3.0 gir1.2-gtkclutter-1.0

    # Install Package
    chroot "${ROOTFS}" apt-get -y install fcitx fcitx-mozc

    # Default Fcitx
    echo '[org.gnome.settings-daemon.plugins.keyboard]' >  "${ROOTFS}/usr/share/glib-2.0/schemas/99_gsettings-input-method.gschema.override"
    echo 'active=false'                                 >> "${ROOTFS}/usr/share/glib-2.0/schemas/99_gsettings-input-method.gschema.override"
    chroot "${ROOTFS}" glib-compile-schemas /usr/share/glib-2.0/schemas
  fi

  # Input Method
  chroot "${ROOTFS}" su -c "im-config -n fcitx" "${USER_NAME}"
fi

################################################################################
# NVIDIA
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'server-nvidia' -o "${PROFILE}" = 'desktop-nvidia' ]; then
  # NVIDIA Apt Public Key
  wget -qO "${ROOTFS}/tmp/nvidia-keyring.gpg" https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
  chroot "${ROOTFS}" apt-key add /tmp/nvidia-keyring.gpg

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
fi

################################################################################
# Initramfs
################################################################################

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

################################################################################
# Cleanup
################################################################################

# Out Of Packages
chroot "${ROOTFS}" apt-get -y autoremove --purge

# Package Archive
chroot "${ROOTFS}" apt-get -y clean

# Repository List
find "${ROOTFS}/var/lib/apt/lists" -type f | xargs rm -f
touch "${ROOTFS}/var/lib/apt/lists/lock"
chmod 0640 "${ROOTFS}/var/lib/apt/lists/lock"

################################################################################
# Archive
################################################################################

# Packages List
chroot "${ROOTFS}" dpkg -l | sed -E '1,5d' | awk '{print $2 "\t" $3}' > "${DESTDIR}/packages.manifest"

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${ROOTFS}/" | sort -r | xargs --no-run-if-empty umount

# Create SquashFS Image
mksquashfs "${ROOTFS}" "${DESTDIR}/rootfs.squashfs" -comp xz

# Create TarBall Image
tar -I pixz -p --acls --xattrs --one-file-system -cf "${DESTDIR}/rootfs.tar.xz" -C "${ROOTFS}" .

# Copy Kernel
find "${ROOTFS}/boot" -type f -name "vmlinuz-*-generic" -exec cp {} "${DESTDIR}/kernel.img" \;

# Copy Initrd
find "${ROOTFS}/boot" -type f -name "initrd.img-*-generic" -exec cp {} "${DESTDIR}/initrd.img" \;

# Permission Files
find "${DESTDIR}" -type f | xargs chmod 0644

# Owner/Group Files
if [ -n "${SUDO_UID}" -a -n "${SUDO_GID}" ]; then
  chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi
