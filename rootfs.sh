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

################################################################################
# Require Environment
################################################################################

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

# HWE Xorg Required Packages
case "${RELEASE}-${KERNEL}" in
	# Trusty Part
	trusty*hwe* )
		declare -a XORG_HWE_REQUIRE_PACKAGES=(
			'x11-xkb-utils'
			'xkb-data'
			'xserver-xorg-core-lts-xenial'
			'xserver-xorg-input-all-lts-xenial'
		)
		declare -a XORG_HWE_RECOMMEND_PACKAGES=(
			'libegl1-mesa-lts-xenial'
			'libgbm1-lts-xenial'
			'libgl1-mesa-dri-lts-xenial'
			'libgl1-mesa-glx-lts-xenial'
			'libgles1-mesa-lts-xenial'
			'libgles2-mesa-lts-xenial'
		)
		declare -a XORG_HWE_MAIN_PACKAGES=(
			'xserver-xorg-lts-xenial'
		)
	;;

	# Xenial Part
	xenial*hwe* )
		declare -a XORG_HWE_REQUIRE_PACKAGES=(
			'x11-xkb-utils'
			'xkb-data'
			'xserver-xorg-core-hwe-16.04'
			'xserver-xorg-input-all-hwe-16.04'
		)
		declare -a XORG_HWE_RECOMMEND_PACKAGES=(
			'libgl1-mesa-dri'
			'xserver-xorg-legacy-hwe-16.04'
		)
		declare -a XORG_HWE_MAIN_PACKAGES=(
			'xserver-xorg-hwe-16.04'
		)
	;;

	# Bionic Server Part
	bionic*hwe* )
		declare -a XORG_HWE_REQUIRE_PACKAGES=(
			'python3-apport'
			'x11-xkb-utils'
			'xkb-data'
			'xserver-xorg-core-hwe-18.04'
			'xserver-xorg-input-all-hwe-18.04'
		)
		declare -a XORG_HWE_RECOMMEND_PACKAGES=(
			'libgl1-mesa-dri'
			'xserver-xorg-legacy-hwe-18.04'
		)
		declare -a XORG_HWE_MAIN_PACKAGES=(
			'xserver-xorg-hwe-18.04'
		)
	;;

	# Default
	* )
		declare -a XORG_HWE_REQUIRE_PACKAGES=()
		declare -a XORG_HWE_RECOMMEND_PACKAGES=()
		declare -a XORG_HWE_MAIN_PACKAGES=()
	;;
esac

# HWE Xorg Desktop Packages
case "${RELEASE}-${KERNEL}-${PROFILE}" in
	trusty*hwe*desktop* ) XORG_HWE_RECOMMEND_PACKAGES=("${XORG_HWE_RECOMMEND_PACKAGES[@]}" 'xserver-xorg-video-all-lts-xenial') ;;
	xenial*hwe*desktop* ) XORG_HWE_RECOMMEND_PACKAGES=("${XORG_HWE_RECOMMEND_PACKAGES[@]}" 'xserver-xorg-video-all-hwe-16.04') ;;
	bionic*hwe*desktop* ) XORG_HWE_RECOMMEND_PACKAGES=("${XORG_HWE_RECOMMEND_PACKAGES[@]}" 'xserver-xorg-video-all-hwe-18.04') ;;
esac

# Ubuntu Japanese Team Repository Keyring URL
UBUNTU_JA_FREE_KEYRING_URL='https://www.ubuntulinux.jp/ubuntu-ja-archive-keyring.gpg'
UBUNTU_JA_NONFREE_KEYRING_URL='https://www.ubuntulinux.jp/ubuntu-jp-ppa-keyring.gpg'

# NVIDIA CUDA Repository Keyring URL
NVIDIA_CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_MAJOR}${RELEASE_MINOR}/x86_64/7fa2af80.pub"

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

################################################################################
# Disk
################################################################################

# Mount Root File System Partition
mkdir -p "${WORKDIR}"
mount -t tmpfs -o 'size=6g,mode=0755' tmpfs "${WORKDIR}"

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
# Minimal
################################################################################

# Minimal Package
chroot "${WORKDIR}" apt-get -y install ubuntu-minimal

# Check Release Version
if [ "${RELEASE}" = 'trusty' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install systemd
fi

################################################################################
# Standard
################################################################################

# Check Environment Variable
if [ "${PROFILE}" != 'minimal' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install ubuntu-standard language-pack-ja
fi

################################################################################
# Network
################################################################################

# Check Release Version
if [ "${RELEASE}" = 'trusty' ] || [ "${RELEASE}" = 'xenial' ]; then
	# Install Require Packages
	chroot "${WORKDIR}" apt-get -y install ethtool ifenslave
fi

# Check Release Version
if [ "${RELEASE}" = 'bionic' ]; then
	# Install Package
	chroot "${WORKDIR}" apt-get -y install nplan
fi

# Resolv Local Hostname
echo '127.0.1.1	localhost.localdomain localhost' >> "${WORKDIR}/etc/hosts"

################################################################################
# SSH
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install ssh

# Disable DNS Lookup
sed -i -e 's@^#?UseDNS.*$@UseDNS no@' "${WORKDIR}/etc/ssh/sshd_config"

# Remove Temporary SSH Host Keys
find "${WORKDIR}/etc/ssh" -type f -name '*_host_*' -exec rm {} \;

################################################################################
# Cloud
################################################################################

# Select Datasources
chroot "${WORKDIR}" sh -c "echo 'cloud-init cloud-init/datasources multiselect ${DATASOURCES}' | debconf-set-selections"

# Require Package
chroot "${WORKDIR}" apt-get -y install cloud-init

################################################################################
# Xorg
################################################################################

# Check Xorg Package List
if [ ${#XORG_HWE_REQUIRE_PACKAGES[*]} -gt 0 ] && [ ${#XORG_HWE_RECOMMEND_PACKAGES[*]} -gt 0 ]; then
	# Install HWE Version Xorg Base Packages
	chroot "${WORKDIR}" apt-get -y install "${XORG_HWE_REQUIRE_PACKAGES[@]}" "${XORG_HWE_RECOMMEND_PACKAGES[@]}"
fi

if [ ${#XORG_HWE_MAIN_PACKAGES[*]} -gt 0 ]; then
	# Install HWE Version Xorg Main Packages
	chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${XORG_HWE_MAIN_PACKAGES[@]}"
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
# mksquashfs "${WORKDIR}" "${DESTDIR}/rootfs.squashfs" -comp xz

# Create TarBall Image
# tar -p --acls --xattrs --one-file-system -cf - -C "${WORKDIR}" . | pv -s "$(du -sb ${WORKDIR} | awk '{print $1}')" | pixz > "${DESTDIR}/rootfs.tar.xz"

# Permission Files
find "${DESTDIR}" -type f -print0 | xargs -0 chmod 0644

# Owner/Group Files
if [ -n "${SUDO_UID}" ] && [ -n "${SUDO_GID}" ]; then
	chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi

# Infomation Files
ls -lah "${DESTDIR}/"
