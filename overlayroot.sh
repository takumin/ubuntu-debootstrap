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

if [ -n "$2" ] && [ -r "$2" ]; then
	# shellcheck source=/dev/null
	. "$2"
fi

################################################################################
# Default Variables
################################################################################

# Root File System Mount Point
# shellcheck disable=SC2086
: ${WORKDIR:='/run/rootfs'}

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

# Keyboard Type
# Value: [JP|US]
# shellcheck disable=SC2086
: ${KEYBOARD:='JP'}

# User - Name
# shellcheck disable=SC2086
: ${USER_NAME:='ubuntu'}

# User - Password
# shellcheck disable=SC2086
: ${USER_PASS:='ubuntu'}

# User - Full Name
# shellcheck disable=SC2086
: ${USER_FULL:='Ubuntu User'}

# User - SSH Public Key
# shellcheck disable=SC2086
: ${USER_KEYS:=''}

# Apt Repository - Official
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu'}

# Apt Repository URL - Canonical Partner
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_PARTNER:='http://archive.canonical.com'}

# Apt Repository URL - Japanese Team
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_JA:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu'}

# Apt Repository URL - Japanese Team
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_JA_NONFREE:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free'}

# Apt Repository URL - NVIDIA CUDA
# shellcheck disable=SC2016,SC2086
: ${MIRROR_NVIDIA_CUDA:='http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_MAJOR}${RELEASE_MINOR}/x86_64'}

# Proxy - No Proxy List
# shellcheck disable=SC2086
: ${NO_PROXY:=''}

# Proxy - FTP Proxy
# shellcheck disable=SC2086
: ${FTP_PROXY:=''}

# Proxy - HTTP Proxy
# shellcheck disable=SC2086
: ${HTTP_PROXY:=''}

# Proxy - HTTPS Proxy
# shellcheck disable=SC2086
: ${HTTPS_PROXY:=''}

# Proxy - Apt Proxy Host
# shellcheck disable=SC2086
: ${APT_PROXY_HOST:=''}

# Proxy - Apt Proxy Port
# shellcheck disable=SC2086
: ${APT_PROXY_PORT:=''}

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
# Normalization Environment
################################################################################

# Select Kernel Package
case "${RELEASE}-${KERNEL}" in
	"bionic-generic-hwe"        ) KERNEL="generic" ;;
	"bionic-signed-generic-hwe" ) KERNEL="signed-generic" ;;
	*                           ) ;;
esac

################################################################################
# Require Environment
################################################################################

# Get Release Version
case "${RELEASE}" in
	'trusty' )
		# shellcheck disable=SC2034
		RELEASE_MAJOR='14'
		# shellcheck disable=SC2034
		RELEASE_MINOR='04'
	;;
	'xenial' )
		# shellcheck disable=SC2034
		RELEASE_MAJOR='16'
		# shellcheck disable=SC2034
		RELEASE_MINOR='04'
	;;
	'bionic' )
		# shellcheck disable=SC2034
		RELEASE_MAJOR='18'
		# shellcheck disable=SC2034
		RELEASE_MINOR='04'
	;;
esac

# Download Files Directory
CACHEDIR="$(cd "$(dirname "$0")"; pwd)/.cache"

# Destination Directory
DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

# Debootstrap Command
DEBOOTSTRAP_COMMAND="debootstrap"

# Debootstrap Variant
DEBOOTSTRAP_VARIANT="--variant=minbase"

# Debootstrap Components
DEBOOTSTRAP_COMPONENTS="--components=main,restricted,universe,multiverse"

# Debootstrap Include Packages
DEBOOTSTRAP_INCLUDES="--include=tzdata,locales,console-setup,gnupg,eatmydata"

# Debootstrap Environment
declare -a DEBOOTSTRAP_ENVIRONMENT=()

# Check libeatmydata
if ldconfig -p | grep -qs 'libeatmydata.so'; then
	# Disable System Call fsync()
	DEBOOTSTRAP_ENVIRONMENT=("LD_PRELOAD=libeatmydata.so")
fi

# Check APT Proxy
if [ "x${APT_PROXY_HOST}" != "x" ] && [ "x${APT_PROXY_PORT}" != "x" ]; then
	# HTTP Proxy Environment
	DEBOOTSTRAP_ENVIRONMENT=("${DEBOOTSTRAP_ENVIRONMENT[*]}" "http_proxy=http://${APT_PROXY_HOST}:${APT_PROXY_PORT}")

	# HTTPS Proxy Environment
	DEBOOTSTRAP_ENVIRONMENT=("${DEBOOTSTRAP_ENVIRONMENT[*]}" "https_proxy=http://${APT_PROXY_HOST}:${APT_PROXY_PORT}")
fi

# Check Debootstrap Environment
if [ ${#DEBOOTSTRAP_ENVIRONMENT[*]} -gt 0 ]; then
	# Debootstrap Override Command
	DEBOOTSTRAP_COMMAND="env ${DEBOOTSTRAP_ENVIRONMENT[*]} ${DEBOOTSTRAP_COMMAND}"
fi

# Select Kernel Image Package
case "${RELEASE}-${KERNEL}" in
	"trusty-generic"            ) KERNEL_IMAGE_PACKAGE="linux-image-generic" ;;
	"xenial-generic"            ) KERNEL_IMAGE_PACKAGE="linux-image-generic" ;;
	"bionic-generic"            ) KERNEL_IMAGE_PACKAGE="linux-image-generic" ;;
	"trusty-generic-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-generic-lts-xenial" ;;
	"xenial-generic-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-generic-hwe-16.04" ;;
	"bionic-generic-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-generic" ;;
	"trusty-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"xenial-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"bionic-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"trusty-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic-lts-xenial" ;;
	"xenial-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic-hwe-16.04" ;;
	"bionic-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
esac

# Select Kernel Header Package
case "${RELEASE}-${KERNEL}" in
	"trusty-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"xenial-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"bionic-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"trusty-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic-lts-xenial" ;;
	"xenial-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic-hwe-16.04" ;;
	"bionic-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"trusty-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic" ;;
	"xenial-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic" ;;
	"bionic-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic" ;;
	"trusty-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic-lts-xenial" ;;
	"xenial-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic-hwe-16.04" ;;
	"bionic-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-signed-headers-generic" ;;
esac

# HWE Xorg Package
case "${RELEASE}-${KERNEL}-${PROFILE}" in
	# Trusty Server Part
	trusty-*-hwe-server-nvidia )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-core-lts-xenial'
			'libegl1-mesa-lts-xenial'
			'libgbm1-lts-xenial'
			'libgl1-mesa-dri-lts-xenial'
			'libgl1-mesa-glx-lts-xenial'
			'libgles1-mesa-lts-xenial'
			'libgles2-mesa-lts-xenial'
			'libwayland-egl1-mesa-lts-xenial'
		)
	;;

	# Trusty Desktop Part
	trusty-*-hwe-desktop* )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-lts-xenial'
		)
	;;

	# Xenial Server Part
	xenial-*-hwe-server-nvidia )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-core-hwe-16.04'
			'xserver-xorg-legacy-hwe-16.04'
		)
	;;

	# Xenial Desktop Part
	xenial-*-hwe-desktop* )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-hwe-16.04'
		)
	;;

	# Default
	* )
		declare -a XORG_HWE_PACKAGES=()
	;;
esac

# Ubuntu Japanese Team Repository Keyring URL
UBUNTU_JA_FREE_KEYRING_URL='https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg'
UBUNTU_JA_NONFREE_KEYRING_URL='https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg'

# NVIDIA CUDA Repository Keyring URL
NVIDIA_CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_MAJOR}${RELEASE_MINOR}/x86_64/7fa2af80.pub"

# Intel LAN Driver URL
INTEL_E1000E_URL='https://downloadmirror.intel.com/15817/eng/e1000e-3.4.2.1.tar.gz'
INTEL_IGB_URL='https://downloadmirror.intel.com/13663/eng/igb-5.3.5.22.tar.gz'
INTEL_IXGBE_URL='https://downloadmirror.intel.com/14687/eng/ixgbe-5.5.3.tar.gz'

# Intel LAN Driver Version
INTEL_E1000E_VERSION="$(basename "${INTEL_E1000E_URL}" | sed -e 's@^e1000e-@@; s@\.tar\.gz$@@;')"
INTEL_IGB_VERSION="$(basename "${INTEL_IGB_URL}" | sed -e 's@^igb-@@; s@\.tar\.gz$@@;')"
INTEL_IXGBE_VERSION="$(basename "${INTEL_IXGBE_URL}" | sed -e 's@^ixgbe-@@; s@\.tar\.gz$@@;')"

# Glib Schemas Directory
GLIB_SCHEMAS_DIR='/usr/share/glib-2.0/schemas'

# NVIDIA CUDA Install Option
case "${PROFILE}" in
	"server-nvidia"  ) NVIDIA_CUDA_INSTALL_OPTION='--no-install-recommends' ;;
	"desktop-nvidia" ) NVIDIA_CUDA_INSTALL_OPTION='' ;;
esac

################################################################################
# Cleanup
################################################################################

# Check Cache Directory
if [ ! -d "${CACHEDIR}" ]; then
	# Create Cache Directory
	mkdir -p "${CACHEDIR}"
fi

# Check Destination Directory
if [ -d "${DESTDIR}" ]; then
	# Cleanup Destination Directory
	find "${DESTDIR}" -type f -print0 | xargs -0 rm -f
else
	# Create Destination Directory
	mkdir -p "${DESTDIR}"
fi

# Unmount Root Partition
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}" | sort -r | xargs --no-run-if-empty umount

################################################################################
# Download
################################################################################

# Check Ubuntu Japanese Team Repository Keyring
if [ ! -f "${CACHEDIR}/ubuntu-ja-archive-keyring.gpg" ]; then
	# Download Ubuntu Japanese Team Repository Keyring
	wget -O "${CACHEDIR}/ubuntu-ja-archive-keyring.gpg" "${UBUNTU_JA_FREE_KEYRING_URL}"
fi

# Check Ubuntu Japanese Team Repository Keyring
if [ ! -f "${CACHEDIR}/ubuntu-jp-ppa-keyring.gpg" ]; then
	# Download Ubuntu Japanese Team Repository Keyring
	wget -O "${CACHEDIR}/ubuntu-jp-ppa-keyring.gpg" "${UBUNTU_JA_NONFREE_KEYRING_URL}"
fi

# Check NVIDIA CUDA Repository Keyring
if [ ! -f "${CACHEDIR}/nvidia-keyring.gpg" ]; then
	# Download NVIDIA CUDA Repository Keyring
	wget -O "${CACHEDIR}/nvidia-keyring.gpg" "${NVIDIA_CUDA_KEYRING_URL}"
fi

# Check Intel LAN Driver
if [ ! -f "${CACHEDIR}/e1000e-${INTEL_E1000E_VERSION}.tar.gz" ]; then
	# Download Intel LAN Driver
	wget -O "${CACHEDIR}/e1000e-${INTEL_E1000E_VERSION}.tar.gz" "${INTEL_E1000E_URL}"
fi

# Check Intel LAN Driver
if [ ! -f "${CACHEDIR}/igb-${INTEL_IGB_VERSION}.tar.gz" ]; then
	# Download Intel LAN Driver
	wget -O "${CACHEDIR}/igb-${INTEL_IGB_VERSION}.tar.gz" "${INTEL_IGB_URL}"
fi

# Check Intel LAN Driver
if [ ! -f "${CACHEDIR}/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" ]; then
	# Download Intel LAN Driver
	wget -O "${CACHEDIR}/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" "${INTEL_IXGBE_URL}"
fi

################################################################################
# Disk
################################################################################

# Mount Root File System Partition
mkdir -p "${WORKDIR}"
mount -t tmpfs -o mode=0755 tmpfs "${WORKDIR}"

################################################################################
# Debootstrap
################################################################################

# Set Default Hostname
declare -x HOSTNAME="localhost"

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
# Localize
################################################################################

# Timezone
echo 'Asia/Tokyo' > "${WORKDIR}/etc/timezone"
ln -fs /usr/share/zoneinfo/Asia/Tokyo "${WORKDIR}/etc/localtime"
chroot "${WORKDIR}" dpkg-reconfigure tzdata

# Locale
chroot "${WORKDIR}" locale-gen ja_JP.UTF-8
chroot "${WORKDIR}" update-locale LANG=ja_JP.UTF-8

# Keyboard Model
sed -i -e 's@^XKBMODEL=.*$@XKBMODEL="pc105"@' "${WORKDIR}/etc/default/keyboard"

# Keyboard Layout
if [ "${KEYBOARD}" = 'JP' ]; then
	sed -i -e 's@^XKBLAYOUT=.*$@XKBLAYOUT="jp"@'  "${WORKDIR}/etc/default/keyboard"
else
	sed -i -e 's@^XKBLAYOUT=.*$@XKBLAYOUT="us"@'  "${WORKDIR}/etc/default/keyboard"
fi

# CapsLock to Ctrl
sed -i -e 's@XKBOPTIONS=.*@XKBOPTIONS="ctrl:nocaps"@' "${WORKDIR}/etc/default/keyboard"

################################################################################
# TTY Autologin
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'minimal' ] || [ "${PROFILE}" = 'server' ] || [ "${PROFILE}" = 'server-nvidia' ]; then
	# Root Login
	mkdir -p "${WORKDIR}/etc/systemd/system/getty@tty1.service.d"
	cat > "${WORKDIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<- '__EOF__'
	[Service]
	Type=idle
	ExecStart=
	ExecStart=-/sbin/agetty --autologin root --noclear %I linux
	__EOF__

	# Login Run Script
	# shellcheck disable=SC2088
	echo '~/.startup.sh' >> "${WORKDIR}/root/.bash_login"

	# Startup Script
	cat > "${WORKDIR}/root/.startup.sh" <<- '__EOF__'
	#!/bin/bash

	script_cmdline ()
	{
		local param
		for param in $(< /proc/cmdline); do
			case "${param}" in
				script=*) echo "${param#*=}" ; return 0 ;;
			esac
		done
	}

	startup_script ()
	{
		local script rt
		script="$(script_cmdline)"
		if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
			if [[ "${script}" =~ ^http:// || "${script}" =~ ^ftp:// ]]; then
				wget "${script}" --retry-connrefused -q -O /tmp/startup_script >/dev/null
				rt=$?
			else
				cp "${script}" /tmp/startup_script
				rt=$?
			fi
			if [[ ${rt} -eq 0 ]]; then
				chmod +x /tmp/startup_script
				/tmp/startup_script
			fi
		fi
	}

	if [ "$(tty)" = '/dev/tty1' ]; then
		startup_script
	fi
	__EOF__

	# Execute Permission
	chmod 0755 "${WORKDIR}/root/.startup.sh"
fi

################################################################################
# Admin User
################################################################################

# Add Group
chroot "${WORKDIR}" addgroup --system admin
chroot "${WORKDIR}" addgroup --system lpadmin
chroot "${WORKDIR}" addgroup --system sambashare
chroot "${WORKDIR}" addgroup --system netdev

# Add User
chroot "${WORKDIR}" adduser --disabled-password --gecos "${USER_FULL},,," "${USER_NAME}"
chroot "${WORKDIR}" adduser "${USER_NAME}" adm
chroot "${WORKDIR}" adduser "${USER_NAME}" admin
chroot "${WORKDIR}" adduser "${USER_NAME}" audio
chroot "${WORKDIR}" adduser "${USER_NAME}" cdrom
chroot "${WORKDIR}" adduser "${USER_NAME}" dialout
chroot "${WORKDIR}" adduser "${USER_NAME}" dip
chroot "${WORKDIR}" adduser "${USER_NAME}" lpadmin
chroot "${WORKDIR}" adduser "${USER_NAME}" plugdev
chroot "${WORKDIR}" adduser "${USER_NAME}" sambashare
chroot "${WORKDIR}" adduser "${USER_NAME}" staff
chroot "${WORKDIR}" adduser "${USER_NAME}" sudo
chroot "${WORKDIR}" adduser "${USER_NAME}" users
chroot "${WORKDIR}" adduser "${USER_NAME}" video
chroot "${WORKDIR}" adduser "${USER_NAME}" netdev

# Change Password
chroot "${WORKDIR}" sh -c "echo ${USER_NAME}:${USER_PASS} | chpasswd"

# SSH Public Key
if [ "x${USER_KEYS}" != "x" ]; then
	mkdir -p "${WORKDIR}/home/${USER_NAME}/.ssh"
	chmod 0700 "${WORKDIR}/home/${USER_NAME}/.ssh"
	echo "${USER_KEYS}" > "${WORKDIR}/home/${USER_NAME}/.ssh/authorized_keys"
	chmod 0644 "${WORKDIR}/home/${USER_NAME}/.ssh/authorized_keys"
fi

# Proxy Configuration
if [ "x${NO_PROXY}" != "x" ]; then
	{
		echo "export no_proxy=\"${NO_PROXY}\""
		echo "export NO_PROXY=\"${NO_PROXY}\""
	} >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${FTP_PROXY}" != "x" ]; then
	{
		echo "export ftp_proxy=\"${FTP_PROXY}\""
		echo "export FTP_PROXY=\"${FTP_PROXY}\""
	} >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTP_PROXY}" != "x" ]; then
	{
		echo "export http_proxy=\"${HTTP_PROXY}\""
		echo "export HTTP_PROXY=\"${HTTP_PROXY}\""
	} >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTPS_PROXY}" != "x" ]; then
	{
		echo "export https_proxy=\"${HTTPS_PROXY}\""
		echo "export HTTPS_PROXY=\"${HTTPS_PROXY}\""
	} >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi

# User Dir Permission
chroot "${WORKDIR}" chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"

################################################################################
# Repository
################################################################################

# Official Repository
cat > "${WORKDIR}/etc/apt/sources.list" << __EOF__
# Official Repository
deb ${MIRROR_UBUNTU} ${RELEASE}           main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-updates   main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-backports main restricted universe multiverse
deb ${MIRROR_UBUNTU} ${RELEASE}-security  main restricted universe multiverse
__EOF__

# Partner Repository
cat > "${WORKDIR}/etc/apt/sources.list.d/ubuntu-partner.list" << __EOF__
# Partner Repository
deb ${MIRROR_UBUNTU_PARTNER} ${RELEASE} partner
__EOF__

# Japanese Team Repository
cp "${CACHEDIR}/ubuntu-ja-archive-keyring.gpg" "${WORKDIR}/tmp/ubuntu-ja-archive-keyring.gpg"
cp "${CACHEDIR}/ubuntu-jp-ppa-keyring.gpg" "${WORKDIR}/tmp/ubuntu-jp-ppa-keyring.gpg"
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
# Kernel
################################################################################

# Install Kernel
chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${KERNEL_IMAGE_PACKAGE}"

# Get Kernel Version
KERNEL_VERSION="$(chroot "${WORKDIR}" dpkg -l | awk '{print $2}' | grep -E 'linux-image-[0-9\.-]+-generic' | sed -E 's/linux-image-//')"

################################################################################
# Minimal
################################################################################

# Minimal Package
chroot "${WORKDIR}" apt-get -y install ubuntu-minimal

################################################################################
# Standard
################################################################################

# Check Environment Variable
if [ "${PROFILE}" != 'minimal' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-standard
fi

################################################################################
# Server
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ ^server.* ]]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-server language-pack-ja
fi

################################################################################
# Network
################################################################################

# Check Release Version
if [ "${RELEASE}" = 'xenial' ] || [ "${RELEASE}" = 'bionic' ]; then
	# NetPlan
	chroot "${WORKDIR}" apt-get -y install nplan
fi

################################################################################
# Netboot
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install cloud-initramfs-dyn-netconf cloud-initramfs-rooturl overlayroot

# Check Release Version
if [ "${RELEASE}" = 'trusty' ] || [ "${RELEASE}" = 'xenial' ]; then
	# Workaround initramfs dns
	cat > "${WORKDIR}/usr/share/initramfs-tools/hooks/libnss_dns" <<- '__EOF__'
	#!/bin/sh -e

	if [ "$1" = 'prereqs' ]; then
		exit 0
	fi

	. /usr/share/initramfs-tools/hook-functions

	for _LIBRARY in /lib/x86_64-linux-gnu/libnss_dns*; do
		if [ -e "${_LIBRARY}" ]; then
			copy_exec ${_LIBRARY} /lib
		fi
	done
	__EOF__

	# Execute Permission
	chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/hooks/libnss_dns"
fi

################################################################################
# SSH
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install ssh

# Remove Temporary SSH Host Keys
find "${WORKDIR}/etc/ssh" -type f -name '*_host_*' -exec rm {} \;

# Generate SSH Host Keys for System Boot
cat > "${WORKDIR}/etc/systemd/system/ssh-keygen.service" << __EOF__
[Unit]
Description=Generate SSH Host Keys During Boot
Before=ssh.service
After=local-fs.target
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_dsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_ecdsa_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key
ConditionPathExists=|!/etc/ssh/ssh_host_ed25519_key.pub
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key
ConditionPathExists=|!/etc/ssh/ssh_host_rsa_key.pub

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/dpkg-reconfigure --frontend noninteractive openssh-server

[Install]
WantedBy=multi-user.target
__EOF__

# Enabled Systemd Service
chroot "${WORKDIR}" systemctl enable ssh-keygen.service

################################################################################
# Xorg
################################################################################

# Check Xorg Package List
if [ ${#XORG_HWE_PACKAGES[*]} -gt 0 ]; then
	# Install HWE Version Xorg
	chroot "${WORKDIR}" apt-get -y install "${XORG_HWE_PACKAGES[@]}"
fi

################################################################################
# Desktop
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ ^desktop.* ]]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja

	# User Directory
	chroot "${WORKDIR}" su -c "LANG=C xdg-user-dirs-update" "${USER_NAME}"
	rm "${WORKDIR}/home/${USER_NAME}/.config/user-dirs.locale"

	# Check Release Version
	if [ "${RELEASE}" = 'bionic' ]; then
		# Workaround: Fix System Log Error Message
		chroot "${WORKDIR}" apt-get -y install gir1.2-clutter-1.0 gir1.2-clutter-gst-3.0 gir1.2-gtkclutter-1.0

		# Install Package
		chroot "${WORKDIR}" apt-get -y install fcitx fcitx-mozc

		# Default Input Method for Fcitx
		cat > "${WORKDIR}/${GLIB_SCHEMAS_DIR}/99_japanese-input-method.gschema.override" <<- __EOF__
		[org.gnome.settings-daemon.plugins.keyboard]
		active=false
		__EOF__

		# Compile Glib Schemas
		chroot "${WORKDIR}" glib-compile-schemas "${GLIB_SCHEMAS_DIR}"
	fi

	# Input Method
	chroot "${WORKDIR}" su -c "im-config -n fcitx" "${USER_NAME}"
fi

################################################################################
# Ubiquity
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ .*ubiquity.* ]]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubiquity
fi

################################################################################
# NVIDIA
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ .*nvidia.* ]]; then
	# NVIDIA Apt Public Key
	cp "${CACHEDIR}/nvidia-keyring.gpg" "${WORKDIR}/tmp/nvidia-keyring.gpg"
	chroot "${WORKDIR}" apt-key add /tmp/nvidia-keyring.gpg

	# NVIDIA CUDA Repository
	echo '# NVIDIA CUDA Repository'                      >  "${WORKDIR}/etc/apt/sources.list.d/nvidia-cuda.list"
	echo "deb $(eval echo -n "${MIRROR_NVIDIA_CUDA}") /" >> "${WORKDIR}/etc/apt/sources.list.d/nvidia-cuda.list"

	# Update Repository
	chroot "${WORKDIR}" apt-get -y update

	# Upgrade System
	chroot "${WORKDIR}" apt-get -y dist-upgrade

	# Install Driver
	chroot "${WORKDIR}" apt-get -y "${NVIDIA_CUDA_INSTALL_OPTION}" install cuda-drivers
fi

################################################################################
# Intel LAN Driver
################################################################################

intel_lan_driver_e1000e_dkms ()
{
	# Copy Archive
	cp "${CACHEDIR}/e1000e-${INTEL_E1000E_VERSION}.tar.gz" "${WORKDIR}/tmp/e1000e-${INTEL_E1000E_VERSION}.tar.gz"

	# Extract Archive
	tar -xf "${WORKDIR}/tmp/e1000e-${INTEL_E1000E_VERSION}.tar.gz" -C "${WORKDIR}/usr/src"

	# DKMS Configuration
	cat > "${WORKDIR}/usr/src/e1000e-${INTEL_E1000E_VERSION}/dkms.conf" <<- __EOF__
	PACKAGE_NAME="e1000e"
	PACKAGE_VERSION="${INTEL_E1000E_VERSION}"
	BUILT_MODULE_LOCATION="src"
	BUILT_MODULE_NAME[0]="e1000e"
	DEST_MODULE_LOCATION[0]="/kernel/drivers/net/e1000e/"
	MAKE[0]="BUILD_KERNEL=\${kernelver} make -C src"
	CLEAN[0]="BUILD_KERNEL=\${kernelver} make -C src clean"
	AUTOINSTALL="yes"
	REMAKE_INITRD="yes"
	__EOF__

	# DKMS Installation
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m e1000e -v "${INTEL_E1000E_VERSION}" add
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m e1000e -v "${INTEL_E1000E_VERSION}" build
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m e1000e -v "${INTEL_E1000E_VERSION}" install
}

intel_lan_driver_igb_dkms ()
{
	# Copy Archive
	cp "${CACHEDIR}/igb-${INTEL_IGB_VERSION}.tar.gz" "${WORKDIR}/tmp/igb-${INTEL_IGB_VERSION}.tar.gz"

	# Extract Archive
	tar -xf "${WORKDIR}/tmp/igb-${INTEL_IGB_VERSION}.tar.gz" -C "${WORKDIR}/usr/src"

	# DKMS Configuration
	cat > "${WORKDIR}/usr/src/igb-${INTEL_IGB_VERSION}/dkms.conf" <<- __EOF__
	PACKAGE_NAME="igb"
	PACKAGE_VERSION="${INTEL_IGB_VERSION}"
	BUILT_MODULE_LOCATION="src"
	BUILT_MODULE_NAME[0]="igb"
	DEST_MODULE_LOCATION[0]="/kernel/drivers/net/igb/"
	MAKE[0]="BUILD_KERNEL=\${kernelver} make -C src"
	CLEAN[0]="BUILD_KERNEL=\${kernelver} make -C src clean"
	AUTOINSTALL="yes"
	REMAKE_INITRD="yes"
	__EOF__

	# DKMS Installation
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m igb -v "${INTEL_IGB_VERSION}" add
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m igb -v "${INTEL_IGB_VERSION}" build
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m igb -v "${INTEL_IGB_VERSION}" install
}

intel_lan_driver_ixgbe_dkms ()
{
	# Copy Archive
	cp "${CACHEDIR}/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" "${WORKDIR}/tmp/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz"

	# Extract Archive
	tar -xf "${WORKDIR}/tmp/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" -C "${WORKDIR}/usr/src"

	# DKMS Configuration
	cat > "${WORKDIR}/usr/src/ixgbe-${INTEL_IXGBE_VERSION}/dkms.conf" <<- __EOF__
	PACKAGE_NAME="ixgbe"
	PACKAGE_VERSION="${INTEL_IXGBE_VERSION}"
	BUILT_MODULE_LOCATION="src"
	BUILT_MODULE_NAME[0]="ixgbe"
	DEST_MODULE_LOCATION[0]="/kernel/drivers/net/ixgbe/"
	MAKE[0]="BUILD_KERNEL=\${kernelver} make -C src"
	CLEAN[0]="BUILD_KERNEL=\${kernelver} make -C src clean"
	AUTOINSTALL="yes"
	REMAKE_INITRD="yes"
	__EOF__

	# DKMS Installation
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m ixgbe -v "${INTEL_IXGBE_VERSION}" add
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m ixgbe -v "${INTEL_IXGBE_VERSION}" build
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m ixgbe -v "${INTEL_IXGBE_VERSION}" install
}

# Check Profile&Kernel
if [ "${PROFILE}" != 'minimal' ] && [ "${KERNEL}" = 'generic' ] || [ "${KERNEL}" = 'generic-hwe' ]; then
	# Kernel Header
	chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${KERNEL_HEADER_PACKAGE}"

	# Build Tools
	chroot "${WORKDIR}" apt-get -y install build-essential libelf-dev dkms

	# Check Release&Kernel Version
	case "${RELEASE}-${KERNEL}" in
		trusty*)
			intel_lan_driver_e1000e_dkms
			intel_lan_driver_igb_dkms
			intel_lan_driver_ixgbe_dkms
			;;
		xenial-generic)
			intel_lan_driver_e1000e_dkms
			intel_lan_driver_igb_dkms
			intel_lan_driver_ixgbe_dkms
			;;
		xenial-generic-hwe)
			intel_lan_driver_e1000e_dkms
			intel_lan_driver_ixgbe_dkms
			;;
		bionic*)
			intel_lan_driver_e1000e_dkms
			intel_lan_driver_ixgbe_dkms
			;;
	esac

	# Cleanup DKMS Initramfs Backup Image
	find "${WORKDIR}/boot" -type f -name '*.old-dkms' -exec rm -f {} \;
fi

################################################################################
# Initramfs
################################################################################

# Cleanup Initramfs
chroot "${WORKDIR}" update-initramfs -d -k all

# Create Initramfs
chroot "${WORKDIR}" update-initramfs -c -k "${KERNEL_VERSION}"

################################################################################
# Cleanup
################################################################################

# Kernel&Initramfs Old Symbolic Link
rm -f "${WORKDIR}/vmlinuz.old"
rm -f "${WORKDIR}/initrd.img.old"

# Out Of Packages
chroot "${WORKDIR}" apt-get -y autoremove --purge

# Package Archive
chroot "${WORKDIR}" apt-get -y clean

# Repository List
find "${WORKDIR}/var/lib/apt/lists" -type f -print0 | xargs -0 rm -f
touch "${WORKDIR}/var/lib/apt/lists/lock"
chmod 0640 "${WORKDIR}/var/lib/apt/lists/lock"

################################################################################
# Archive
################################################################################

# Packages List
chroot "${WORKDIR}" dpkg -l | sed -E '1,5d' | awk '{print $2 "\t" $3}' > "${DESTDIR}/packages.manifest"

# Unmount RootFs
awk '{print $2}' /proc/mounts | grep -s "${WORKDIR}/" | sort -r | xargs --no-run-if-empty umount

# Create SquashFS Image
mksquashfs "${WORKDIR}" "${DESTDIR}/rootfs.squashfs" -comp xz

# Create TarBall Image
tar -I pixz -p --acls --xattrs --one-file-system -cf "${DESTDIR}/rootfs.tar.xz" -C "${WORKDIR}" .

# Copy Kernel
find "${WORKDIR}/boot" -type f -name "vmlinuz-*-generic" -exec cp {} "${DESTDIR}/kernel.img" \;

# Copy Initrd
find "${WORKDIR}/boot" -type f -name "initrd.img-*-generic" -exec cp {} "${DESTDIR}/initrd.img" \;

# Permission Files
find "${DESTDIR}" -type f -print0 | xargs -0 chmod 0644

# Owner/Group Files
if [ -n "${SUDO_UID}" ] && [ -n "${SUDO_GID}" ]; then
	chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi
