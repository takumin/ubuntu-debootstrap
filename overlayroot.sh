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
# Values: String
# shellcheck disable=SC2086
: ${WORKDIR:='/tmp/rootfs'}

# Destination Directory
# Values: String
# shellcheck disable=SC2086
: ${DESTDIR:="$(cd "$(dirname "$0")"; pwd)/release"}

# Release Codename
# Value:
#   - trusty
#   - xenial
#   - bionic
# shellcheck disable=SC2086
: ${RELEASE:='bionic'}

# Kernel Package
# Values:
#   - generic
#   - generic-hwe
#   - signed-generic
#   - signed-generic-hwe
#   - virtual
#   - virtual-hwe
# shellcheck disable=SC2086
: ${KERNEL:='generic'}

# Package Selection
# Values:
#   - minimal
#   - standard
#   - server
#   - server-nvidia
#   - desktop
#   - desktop-nvidia
#   - cloud-server
#   - cloud-server-nvidia
#   - cloud-desktop
#   - cloud-desktop-nvidia
# shellcheck disable=SC2086
: ${PROFILE:='server'}

# Cloud-Init Datasources
# Values:
#   - NoCloud
#   - None
# shellcheck disable=SC2086
: ${DATASOURCES:='NoCloud, None'}

# Keyboard Type
# Values:
#   - JP
#   - US
# shellcheck disable=SC2086
: ${KEYBOARD:='JP'}

# User - Name
# Values: String
# shellcheck disable=SC2086
: ${USER_NAME:='ubuntu'}

# User - Password
# Values: String
# shellcheck disable=SC2086
: ${USER_PASS:='ubuntu'}

# User - Full Name
# Values: String
# shellcheck disable=SC2086
: ${USER_FULL:='Ubuntu User'}

# User - SSH Public Key
# Values: String
# shellcheck disable=SC2086
: ${USER_KEYS:=''}

# Apt Repository - Official
# Values: String
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu'}

# Apt Repository URL - Canonical Partner
# Values: String
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_PARTNER:='http://archive.canonical.com'}

# Apt Repository URL - Japanese Team
# Values: String
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_JA:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu'}

# Apt Repository URL - Japanese Team
# Values: String
# shellcheck disable=SC2086
: ${MIRROR_UBUNTU_JA_NONFREE:='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free'}

# Apt Repository URL - NVIDIA CUDA
# Values: String
# shellcheck disable=SC2016,SC2086
: ${MIRROR_NVIDIA_CUDA:='http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_MAJOR}${RELEASE_MINOR}/x86_64'}

# Proxy - No Proxy List
# Values: String
# shellcheck disable=SC2086
: ${NO_PROXY:=''}

# Proxy - FTP Proxy
# Values: String
# shellcheck disable=SC2086
: ${FTP_PROXY:=''}

# Proxy - HTTP Proxy
# Values: String
# shellcheck disable=SC2086
: ${HTTP_PROXY:=''}

# Proxy - HTTPS Proxy
# Values: String
# shellcheck disable=SC2086
: ${HTTPS_PROXY:=''}

# Proxy - Apt Proxy Host
# Values: String
# shellcheck disable=SC2086
: ${APT_PROXY_HOST:=''}

# Proxy - Apt Proxy Port
# Values: String
# shellcheck disable=SC2086
: ${APT_PROXY_PORT:=''}

################################################################################
# Available Environment
################################################################################

# Release
declare -a AVAILABLE_RELEASE=(
	'trusty'
	'xenial'
	'bionic'
)

# Kernel
declare -a AVAILABLE_KERNEL=(
	'generic'
	'generic-hwe'
	'signed-generic'
	'signed-generic-hwe'
	'virtual'
	'virtual-hwe'
)

# Profile
declare -a AVAILABLE_PROFILE=(
	'minimal'
	'standard'
	'server'
	'server-nvidia'
	'desktop'
	'desktop-nvidia'
	'cloud-server'
	'cloud-server-nvidia'
	'cloud-desktop'
	'cloud-desktop-nvidia'
)

################################################################################
# Check Environment
################################################################################

# Array Util
containsElement () {
	local e match="$1"
	shift
	for e; do [[ "$e" == "$match" ]] && return 0; done
	return 1
}

# Release
containsElement "${RELEASE}" "${AVAILABLE_RELEASE[@]}"
RETVAL=$?
if [ "${RETVAL}" != 0 ]; then
	echo "RELEASE: ${AVAILABLE_RELEASE[*]}"
	exit 1
fi

# Kernel
containsElement "${KERNEL}" "${AVAILABLE_KERNEL[@]}"
RETVAL=$?
if [ "${RETVAL}" != 0 ]; then
	echo "KERNEL: ${AVAILABLE_KERNEL[*]}"
	exit 1
fi

# Profile
containsElement "${PROFILE}" "${AVAILABLE_PROFILE[@]}"
RETVAL=$?
if [ "${RETVAL}" != 0 ]; then
	echo "PROFILE: ${AVAILABLE_PROFILE[*]}"
	exit 1
fi

################################################################################
# Normalization Environment
################################################################################

# Select Kernel Package
case "${RELEASE}-${KERNEL}" in
	* ) ;;
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
DEBOOTSTRAP_INCLUDES="--include=gnupg,eatmydata"

# Debootstrap Environment
declare -a DEBOOTSTRAP_ENVIRONMENT=()

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
	"bionic-generic-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-generic-hwe-18.04" ;;
	"trusty-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"xenial-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"bionic-signed-generic"     ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic" ;;
	"trusty-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic-lts-xenial" ;;
	"xenial-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic-hwe-16.04" ;;
	"bionic-signed-generic-hwe" ) KERNEL_IMAGE_PACKAGE="linux-signed-image-generic-hwe-18.04" ;;
	"trusty-virtual"            ) KERNEL_IMAGE_PACKAGE="linux-image-virtual" ;;
	"xenial-virtual"            ) KERNEL_IMAGE_PACKAGE="linux-image-virtual" ;;
	"bionic-virtual"            ) KERNEL_IMAGE_PACKAGE="linux-image-virtual" ;;
	"trusty-virtual-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-virtual-lts-xenial" ;;
	"xenial-virtual-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-virtual-hwe-16.04" ;;
	"bionic-virtual-hwe"        ) KERNEL_IMAGE_PACKAGE="linux-image-virtual-hwe-18.04" ;;
esac

# Select Kernel Header Package
case "${RELEASE}-${KERNEL}" in
	"trusty-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"xenial-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"bionic-generic"            ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"trusty-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic-lts-xenial" ;;
	"xenial-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic-hwe-16.04" ;;
	"bionic-generic-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-generic-hwe-18.04" ;;
	"trusty-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"xenial-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"bionic-signed-generic"     ) KERNEL_HEADER_PACKAGE="linux-headers-generic" ;;
	"trusty-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-headers-generic-lts-xenial" ;;
	"xenial-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-headers-generic-hwe-16.04" ;;
	"bionic-signed-generic-hwe" ) KERNEL_HEADER_PACKAGE="linux-headers-generic-hwe-18.04" ;;
	"trusty-virtual"            ) KERNEL_HEADER_PACKAGE="linux-headers-virtual" ;;
	"xenial-virtual"            ) KERNEL_HEADER_PACKAGE="linux-headers-virtual" ;;
	"bionic-virtual"            ) KERNEL_HEADER_PACKAGE="linux-headers-virtual" ;;
	"trusty-virtual-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-virtual-lts-xenial" ;;
	"xenial-virtual-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-virtual-hwe-16.04" ;;
	"bionic-virtual-hwe"        ) KERNEL_HEADER_PACKAGE="linux-headers-virtual-hwe-18.04" ;;
esac

# HWE Xorg Package
case "${RELEASE}-${KERNEL}-${PROFILE}" in
	# Trusty Server Part
	trusty*hwe*server-nvidia )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-core-lts-xenial'
			'xserver-xorg-input-all-lts-xenial'
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
	trusty*hwe*desktop* )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-lts-xenial'
		)
	;;

	# Xenial Server Part
	xenial*hwe*server-nvidia )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-core-hwe-16.04'
			'xserver-xorg-input-all-hwe-16.04'
			'xserver-xorg-legacy-hwe-16.04'
		)
	;;

	# Xenial Desktop Part
	xenial*hwe*desktop* )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-hwe-16.04'
		)
	;;

	# Bionic Server Part
	bionic*hwe*server-nvidia )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-core-hwe-18.04'
			'xserver-xorg-input-all-hwe-18.04'
			'xserver-xorg-legacy-hwe-18.04'
		)
	;;

	# Bionic Desktop Part
	bionic*hwe*desktop* )
		declare -a XORG_HWE_PACKAGES=(
			'xserver-xorg-hwe-18.04'
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
INTEL_E1000E_URL='https://downloadmirror.intel.com/15817/eng/e1000e-3.6.0.tar.gz'
INTEL_IGB_URL='https://downloadmirror.intel.com/13663/eng/igb-5.3.5.42.tar.gz'
INTEL_IXGBE_URL='https://downloadmirror.intel.com/14687/eng/ixgbe-5.6.5.tar.gz'

# Intel LAN Driver Version
INTEL_E1000E_VERSION="$(basename "${INTEL_E1000E_URL}" | sed -e 's@^e1000e-@@; s@\.tar\.gz$@@;')"
INTEL_IGB_VERSION="$(basename "${INTEL_IGB_URL}" | sed -e 's@^igb-@@; s@\.tar\.gz$@@;')"
INTEL_IXGBE_VERSION="$(basename "${INTEL_IXGBE_URL}" | sed -e 's@^ixgbe-@@; s@\.tar\.gz$@@;')"

# NVIDIA CUDA Install Option
case "${RELEASE}-${KERNEL}-${PROFILE}" in
	*server*nvidia* ) NVIDIA_CUDA_INSTALL_OPTIONS='-y --no-install-recommends' ;;
	* )               NVIDIA_CUDA_INSTALL_OPTIONS='-y' ;;
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
mount -t tmpfs -o 'size=6g,mode=0755' tmpfs "${WORKDIR}"

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
# Workaround
################################################################################

# Apt Speed Up
echo 'force-unsafe-io' > "${WORKDIR}/etc/dpkg/dpkg.cfg.d/02apt-speedup"

# Check Release Version
if [ "${RELEASE}" = 'trusty' ]; then
	# Workaround policy-rc.d
	echo $'#!/bin/sh\nexit 101' > "${WORKDIR}/usr/sbin/policy-rc.d"
	chmod +x "${WORKDIR}/usr/sbin/policy-rc.d"

	# Workaround initctl
	chroot "${WORKDIR}" dpkg-divert --local --rename --add /sbin/initctl
	chroot "${WORKDIR}" ln -fs /bin/true /sbin/initctl

	# Workaround utmp
	chroot "${WORKDIR}" touch /var/run/utmp
fi

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

# Check APT Proxy
if [ "x${APT_PROXY_HOST}" != "x" ] && [ "x${APT_PROXY_PORT}" != "x" ]; then
	echo "Acquire::ftp::proxy \"http://${APT_PROXY_HOST}:${APT_PROXY_PORT}\";" >> "${WORKDIR}/etc/apt.conf"
	echo "Acquire::http::proxy \"http://${APT_PROXY_HOST}:${APT_PROXY_PORT}\";" >> "${WORKDIR}/etc/apt.conf"
	echo "Acquire::https::proxy \"http://${APT_PROXY_HOST}:${APT_PROXY_PORT}\";" >> "${WORKDIR}/etc/apt.conf"
fi

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

# Systemd Packages
chroot "${WORKDIR}" apt-get -y install systemd policykit-1

# Keep Proxy Environment Variables
cat > "${WORKDIR}/etc/sudoers.d/keep_proxy" << '__EOF__'
Defaults env_keep+="no_proxy"
Defaults env_keep+="NO_PROXY"
Defaults env_keep+="ftp_proxy"
Defaults env_keep+="FTP_PROXY"
Defaults env_keep+="http_proxy"
Defaults env_keep+="HTTP_PROXY"
Defaults env_keep+="https_proxy"
Defaults env_keep+="HTTPS_PROXY"
Defaults env_keep+="rsync_proxy"
Defaults env_keep+="RSYNC_PROXY"
__EOF__

# No Password
echo '%sudo ALL=(ALL) NOPASSWD: ALL' > "${WORKDIR}/etc/sudoers.d/no_passwd"

################################################################################
# Standard
################################################################################

# Check Environment Variable
if [ "${PROFILE}" != 'minimal' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-standard language-pack-ja
fi

################################################################################
# LiveBoot
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install cloud-initramfs-copymods cloud-initramfs-dyn-netconf cloud-initramfs-rooturl overlayroot

# Check Release Version
if [ "${RELEASE}" = 'trusty' ] || [ "${RELEASE}" = 'xenial' ]; then
	# Workaround initramfs dns
	cat > "${WORKDIR}/usr/share/initramfs-tools/hooks/libnss_dns" <<- '__EOF__'
	#!/bin/sh -e

	[ "$1" = 'prereqs' ] && { exit 0; }

	. /usr/share/initramfs-tools/hook-functions

	for libnss_dns in /lib/x86_64-linux-gnu/libnss_dns*; do
		if [ -e "${libnss_dns}" ]; then
			copy_exec "${libnss_dns}" /lib
			copy_exec "${libnss_dns}" /lib/x86_64-linux-gnu
		fi
	done
	__EOF__

	# Execute Permission
	chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/hooks/libnss_dns"
fi

# Include Kernel Modules
cat > "${WORKDIR}/usr/share/initramfs-tools/hooks/include_kernel_modules" <<- '__EOF__'
#!/bin/sh -e

[ "$1" = 'prereqs' ] && { exit 0; }

. /usr/share/initramfs-tools/hook-functions

# Bonding
manual_add_modules bonding
# Network Driver
copy_modules_dir kernel/drivers/net
# Mount Encoding
copy_modules_dir kernel/fs/nls
__EOF__

# Execute Permission
chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/hooks/include_kernel_modules"

# Generate Reset Network Interface for Initramfs
cat > "${WORKDIR}/usr/share/initramfs-tools/scripts/local-top/liveroot" << '__EOF__'
#!/bin/sh

[ "$1" = 'prereqs' ] && { exit 0; }

liveroot_mount_squashfs() {
	local readonly device="$1" fstype="$2" option="$3" image="$4" target="$5"

	mkdir -p "/run/liveroot"
	mount -t "${fstype}" -o "${option}" "${device}" "/run/liveroot"

	if [ -f "/run/liveroot${image}" ]; then
		mkdir -p "${target}"
		mount -t squashfs -o loop "/run/liveroot${image}" "${target}"
		return 0
	else
		umount "/run/liveroot"
		return 1
	fi
}

liveroot() {
	local readonly target="$1" image="${2#file://}"
	local device fstype

	udevadm trigger
	udevadm settle

	modprobe nls_utf8

	for device in $(blkid -o device); do
		fstype="$(blkid -p -s TYPE -o value "${device}")"

		case "${fstype}" in
			iso9660) liveroot_mount_squashfs "${device}" "${fstype}" "loop"              "${image}" "${target}" && break ;;
			vfat)    liveroot_mount_squashfs "${device}" "${fstype}" "ro,iocharset=utf8" "${image}" "${target}" && break ;;
			*)       continue ;;
		esac
	done
}

. /scripts/functions

case "${ROOT}" in
	file://*.squashfs) log_warning_msg "ROOT=\"${ROOT}\"" ;;
	file://*.squash)   log_warning_msg "ROOT=\"${ROOT}\"" ;;
	file://*.sfs)      log_warning_msg "ROOT=\"${ROOT}\"" ;;
	*)                 exit 0 ;;
esac

liveroot "${rootmnt}.live" "${ROOT}" || exit 1

{
	echo 'ROOTFSTYPE="liveroot"'
	echo "ROOTFLAGS=\"-o move\""
	echo "ROOT=\"${rootmnt}.live\""
} > /conf/param.conf
__EOF__

# Execute Permission
chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/scripts/local-top/liveroot"

# Generate Default Network Configuration
cat > "${WORKDIR}/usr/share/initramfs-tools/scripts/init-bottom/network-config" << '__EOF__'
#!/bin/sh

[ "$1" = 'prereqs' ] && { echo 'overlayroot'; exit 0; }

parse_cmdline() {
	local param
	for param in $(cat /proc/cmdline); do
		case "${param}" in
			ds=*) return 1 ;;
		esac
	done
	return 0
}

interfaces_config() {
	local intf
	echo 'auto lo'                >  "${rootmnt}/etc/network/interfaces.d/50-cloud-init.cfg"
	echo 'iface lo inet loopback' >> "${rootmnt}/etc/network/interfaces.d/50-cloud-init.cfg"
	for intf in /sys/class/net/*; do
		if [ "${intf##*/}" = 'lo' ]; then
			continue
		fi
		echo ""                            >> "${rootmnt}/etc/network/interfaces.d/50-cloud-init.cfg"
		echo "auto ${intf##*/}"            >> "${rootmnt}/etc/network/interfaces.d/50-cloud-init.cfg"
		echo "iface ${intf##*/} inet dhcp" >> "${rootmnt}/etc/network/interfaces.d/50-cloud-init.cfg"
	done
}

netplan_config() {
	local readonly cfgs="$(find ${rootmnt}/etc/netplan -type f -name '*.yaml' | wc -l)"
	if [ "${cfgs}" -gt 0 ]; then
		return 1
	fi
	echo "network:"     >  "${rootmnt}/etc/netplan/50-cloud-init.yaml"
	echo "  version: 2" >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
	echo "  ethernets:" >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
	local intf addr
	for intf in /sys/class/net/*; do
		if [ "${intf##*/}" = 'lo' ]; then
			continue
		fi
		addr="$(cat ${intf}/address)"
		echo "    ${intf##*/}:"            >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
		echo "      match:"                >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
		echo "        macaddress: ${addr}" >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
		echo "      set-name: ${intf##*/}" >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
		echo "      dhcp4: yes"            >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
		echo "      optional: true"        >> "${rootmnt}/etc/netplan/50-cloud-init.yaml"
	done
}

. /scripts/functions

case "${ROOTFSTYPE}" in
	liveroot) : ;;
	root_url) : ;;
	*)        exit 0 ;;
esac

parse_cmdline || exit 1
if [ -d "${rootmnt}/etc/netplan" ]; then
	netplan_config
elif [ -d "${rootmnt}/etc/network/interfaces.d" ]; then
	interfaces_config
fi
__EOF__

# Execute Permission
chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/scripts/init-bottom/network-config"

# Generate Reset Network Interface for Initramfs
cat > "${WORKDIR}/usr/share/initramfs-tools/scripts/init-bottom/reset-network-interfaces" << '__EOF__'
#!/bin/sh

[ "$1" = 'prereqs' ] && { exit 0; }

reset_network_interfaces() {
	local intf
	for intf in /sys/class/net/*; do
		ip addr flush dev "${intf##*/}"
		ip link set "${intf##*/}" down
	done
}

. /scripts/functions

reset_network_interfaces
__EOF__

# Execute Permission
chmod 0755 "${WORKDIR}/usr/share/initramfs-tools/scripts/init-bottom/reset-network-interfaces"

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
if [ "${PROFILE}" = 'minimal' ] || [ "${PROFILE}" = 'standard' ] || [[ "${PROFILE}" =~ ^.*server.*$ ]]; then
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

	script_cmdline() {
		local param
		for param in $(< /proc/cmdline); do
			case "${param}" in
				script=*) echo "${param#*=}" ; return 0 ;;
			esac
		done
	}

	startup_script() {
		local script rt
		script="$(script_cmdline)"
		if [ -n "${script}" ] && [ ! -x /tmp/startup_script ]; then
			if [[ "${script}" =~ ^https?:// ]]; then
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

# Check Environment Variable
if [[ ! "${PROFILE}" =~ ^.*cloud.*$ ]]; then
	# Add Group
	chroot "${WORKDIR}" addgroup --system admin
	chroot "${WORKDIR}" addgroup --system lpadmin
	chroot "${WORKDIR}" addgroup --system sambashare
	chroot "${WORKDIR}" addgroup --system netdev
	chroot "${WORKDIR}" addgroup --system lxd

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
	chroot "${WORKDIR}" adduser "${USER_NAME}" lxd

	# Change Password
	chroot "${WORKDIR}" sh -c "echo ${USER_NAME}:${USER_PASS} | chpasswd"

	# SSH Public Key
	if [ "x${USER_KEYS}" != "x" ]; then
		mkdir -p "${WORKDIR}/home/${USER_NAME}/.ssh"
		chmod 0700 "${WORKDIR}/home/${USER_NAME}/.ssh"
		echo "${USER_KEYS}" > "${WORKDIR}/home/${USER_NAME}/.ssh/authorized_keys"
		chmod 0644 "${WORKDIR}/home/${USER_NAME}/.ssh/authorized_keys"
	fi

	# User Dir Permission
	chroot "${WORKDIR}" chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"
fi

################################################################################
# Network
################################################################################

# Check Release Version
if [ "${RELEASE}" = 'trusty' ] || [ "${RELEASE}" = 'xenial' ]; then
	# Install Require Packages
	chroot "${WORKDIR}" apt-get -y install ethtool ifenslave

	if [[ ! "${PROFILE}" =~ ^.*cloud.*$ ]]; then
		# Install Package
		chroot "${WORKDIR}" apt-get -y --no-install-recommends install network-manager

		# Managed Interface
		# sed -i -e 's@source-directory.*@source /etc/network/interfaces.d/\*@' "${WORKDIR}/etc/network/interfaces"
		# sed -i -e 's/managed=.*/managed=true/;' "${WORKDIR}/etc/NetworkManager/NetworkManager.conf"
	fi
fi

# Check Release Version
if [ "${RELEASE}" = 'bionic' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install nplan
fi

# Default Hostname
echo 'localhost.localdomain' > "${WORKDIR}/etc/hostname"

# Resolv Local Hostname
sed -i -e 's@^\(127.0.0.1\s\+\)\(.*\)$@\1localhost.localdomain \2@' "${WORKDIR}/etc/hosts"
sed -i -e 's@^\(::1\s\+\)\(.*\)$@\1localhost.localdomain \2@' "${WORKDIR}/etc/hosts"

################################################################################
# SSH
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install ssh

# Disable DNS Lookup
sed -i -e 's@^#?UseDNS.*$@UseDNS no@' "${WORKDIR}/etc/ssh/sshd_config"

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
# Cloud
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ ^.*cloud.*$ ]]; then
	# Select Datasources
	chroot "${WORKDIR}" sh -c "echo 'cloud-init cloud-init/datasources multiselect ${DATASOURCES}' | debconf-set-selections"

	# Require Package
	chroot "${WORKDIR}" apt-get -y install cloud-init
fi

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
if [[ "${PROFILE}" =~ ^.*desktop.*$ ]]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-desktop ubuntu-defaults-ja

	# Check Release Version
	if [ "${RELEASE}" = 'bionic' ]; then
		# Workaround: Fix System Log Error Message
		chroot "${WORKDIR}" apt-get -y install gir1.2-clutter-1.0 gir1.2-clutter-gst-3.0 gir1.2-gtkclutter-1.0

		# Install Package
		chroot "${WORKDIR}" apt-get -y install fcitx fcitx-mozc

		# Default Input Method for Fcitx
		cat > "${WORKDIR}/usr/share/glib-2.0/schemas/99_japanese-input-method.gschema.override" <<- __EOF__
		[org.gnome.settings-daemon.plugins.keyboard]
		active=false
		__EOF__

		# Compile Glib Schemas
		chroot "${WORKDIR}" glib-compile-schemas "/usr/share/glib-2.0/schemas"
	fi

	# Check Environment Variable
	if [[ ! "${PROFILE}" =~ ^.*cloud.*$ ]]; then
		# User Directory
		chroot "${WORKDIR}" su -c "LANG=C xdg-user-dirs-update" "${USER_NAME}"
		rm "${WORKDIR}/home/${USER_NAME}/.config/user-dirs.locale"

		# Input Method
		chroot "${WORKDIR}" su -c "im-config -n fcitx" "${USER_NAME}"
	fi

	# Check Release & Profile
	if [ "${RELEASE}" = 'bionic' ] && [[ ! "${PROFILE}" =~ ^.*cloud.*$ ]]; then
		# Netplan Configuration
		{
			echo 'network:'
			echo '  version: 2'
			echo '  renderer: NetworkManager'
		} > "${WORKDIR}/etc/netplan/01-network-manager-all.yaml"
	fi
fi

################################################################################
# NVIDIA
################################################################################

# Check Environment Variable
if [[ "${PROFILE}" =~ ^.*nvidia.*$ ]]; then
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
	chroot "${WORKDIR}" apt-get ${NVIDIA_CUDA_INSTALL_OPTIONS} install cuda-drivers
fi

################################################################################
# Intel LAN Driver
################################################################################

intel_lan_driver_dkms ()
{
	if [ $# -ne 2 ]; then
		"intel_lan_driver_dkms driver_name driver_version"
		exit 1
	fi

	# Local Variables
	local readonly driver_name="$1"
	local readonly driver_version="$2"

	# Extract Archive
	tar -xf "${CACHEDIR}/${driver_name}-${driver_version}.tar.gz" -C "${WORKDIR}/usr/src"

	# DKMS Configuration
	cat > "${WORKDIR}/usr/src/${driver_name}-${driver_version}/dkms.conf" <<- __EOF__
	PACKAGE_NAME="${driver_name}"
	PACKAGE_VERSION="${driver_version}"
	BUILT_MODULE_LOCATION="src"
	BUILT_MODULE_NAME[0]="${driver_name}"
	DEST_MODULE_LOCATION[0]="/kernel/drivers/net/${driver_name}/"
	MAKE[0]="BUILD_KERNEL=\${kernelver} make -C src"
	CLEAN[0]="BUILD_KERNEL=\${kernelver} make -C src clean"
	AUTOINSTALL="yes"
	REMAKE_INITRD="yes"
	__EOF__

	# DKMS Installation
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m "${driver_name}" -v "${driver_version}" add
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m "${driver_name}" -v "${driver_version}" build
	chroot "${WORKDIR}" dkms -k "${KERNEL_VERSION}" -m "${driver_name}" -v "${driver_version}" install
}

# Check Profile&Kernel
if [[ "${KERNEL}" =~ ^generic.*$ ]] && [ "${PROFILE}" != 'minimal' ]; then
	# Kernel Header
	chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${KERNEL_HEADER_PACKAGE}"

	# Build Tools
	chroot "${WORKDIR}" apt-get -y install build-essential libelf-dev dkms

	# Check Release&Kernel Version
	case "${RELEASE}-${KERNEL}" in
		trusty*)
			intel_lan_driver_dkms 'e1000e' "${INTEL_E1000E_VERSION}"
			intel_lan_driver_dkms 'igb'    "${INTEL_IGB_VERSION}"
			intel_lan_driver_dkms 'ixgbe'  "${INTEL_IXGBE_VERSION}"
			;;
		xenial-generic)
			intel_lan_driver_dkms 'e1000e' "${INTEL_E1000E_VERSION}"
			intel_lan_driver_dkms 'igb'    "${INTEL_IGB_VERSION}"
			intel_lan_driver_dkms 'ixgbe'  "${INTEL_IXGBE_VERSION}"
			;;
		xenial-generic-hwe)
			intel_lan_driver_dkms 'e1000e' "${INTEL_E1000E_VERSION}"
			intel_lan_driver_dkms 'ixgbe'  "${INTEL_IXGBE_VERSION}"
			;;
		bionic*)
			intel_lan_driver_dkms 'e1000e' "${INTEL_E1000E_VERSION}"
			intel_lan_driver_dkms 'ixgbe'  "${INTEL_IXGBE_VERSION}"
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
# Workaround
################################################################################

# Remote Apt Speed Up
rm -f "${WORKDIR}/etc/dpkg/dpkg.cfg.d/02apt-speedup"

# Check Release Version
if [ "${RELEASE}" = 'trusty' ]; then
	# Workaround policy-rc.d
	rm -f "${WORKDIR}/usr/sbin/policy-rc.d"

	# Workaround initctl
	rm -f "${WORKDIR}/sbin/initctl"
	chroot "${WORKDIR}" dpkg-divert --rename --remove /sbin/initctl
fi

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

# Check APT Proxy
if [ "x${APT_PROXY_HOST}" != "x" ] && [ "x${APT_PROXY_PORT}" != "x" ]; then
	sed -i -e '/^Acquire::ftp::proxy.*/d' "${WORKDIR}/etc/apt.conf"
	sed -i -e '/^Acquire::http::proxy.*/d' "${WORKDIR}/etc/apt.conf"
	sed -i -e '/^Acquire::https::proxy.*/d' "${WORKDIR}/etc/apt.conf"
fi

# Persistent Machine ID
echo -n '' > "${WORKDIR}/etc/machine-id"
ln -fs "/etc/machine-id" "${WORKDIR}/var/lib/dbus/machine-id"

# Journal Log Directory
if [ -d "${WORKDIR}/var/log/journal" ]; then
	rmdir "${WORKDIR}/var/log/journal"
fi

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
tar -p --acls --xattrs --one-file-system -cf - -C "${WORKDIR}" . | pv -s "$(du -sb ${WORKDIR} | awk '{print $1}')" | pixz > "${DESTDIR}/rootfs.tar.xz"

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

# Infomation Files
ls -lah "${DESTDIR}/"
