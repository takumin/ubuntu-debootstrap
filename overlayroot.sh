#!/bin/bash

set -eu

################################################################################
# Load Environment
################################################################################

if [ -n "$1" -a -r "$1" ]; then
  . "$1"
fi

if [ -n "$2" -a -r "$2" ]; then
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
: ${DESTDIR:="$(cd "$(dirname $0)"; pwd)/release"}

# Release Codename
# Value: [trusty|xenial|bionic]
# shellcheck disable=SC2086
: ${RELEASE:='bionic'}

# Kernel Package
# Value: [generic|generic-hwe|signed-generic|signed-generic-hwe]
# shellcheck disable=SC2086
: ${KERNEL:='generic'}

# Package Selection
# Value: [minimal|standard|server|server-nvidia|desktop|desktop-nvidia]
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

# Proxy - Apt Proxy
# shellcheck disable=SC2086
: ${APT_PROXY:=''}

# Proxy - FTP Proxy
# shellcheck disable=SC2086
: ${FTP_PROXY:=''}

# Proxy - HTTP Proxy
# shellcheck disable=SC2086
: ${HTTP_PROXY:=''}

# Proxy - HTTPS Proxy
# shellcheck disable=SC2086
: ${HTTPS_PROXY:=''}

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

# Destination Directory
DESTDIR="${DESTDIR}/${RELEASE}/${KERNEL}/${PROFILE}"

# Debootstrap Command
DEBOOTSTRAP_COMMAND="debootstrap"

# Debootstrap Variant
DEBOOTSTRAP_VARIANT="--variant=minbase"

# Debootstrap Components
DEBOOTSTRAP_COMPONENTS="--components=main,restricted,universe,multiverse"

# Debootstrap Include Packages
DEBOOTSTRAP_INCLUDES="--include=gnupg,tzdata,locales,console-setup"

# Check APT Proxy
if [ "x${APT_PROXY}" != "x" ]; then
  # Debootstrap Proxy Command
  declare -a DEBOOTSTRAP_PROXY=( "env" "http_proxy=${APT_PROXY}" "https_proxy=${APT_PROXY}" "${DEBOOTSTRAP_COMMAND}" )

  # Debootstrap Override Command
  DEBOOTSTRAP_COMMAND="${DEBOOTSTRAP_PROXY[*]}"
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
  * )
    echo "Unknown Release Codename & Kernel Type..."
    exit 1
    ;;
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
  * )
    echo "Unknown Release Codename & Kernel Type..."
    exit 1
    ;;
esac

# HWE Xorg Package
case "${RELEASE}-${KERNEL}" in
  # Trusty Part
  trusty-*-hwe )
    # Require Packages
    declare -a XORG_HWE_REQUIRE_PACKAGES=(
      'xserver-xorg-core-lts-xenial'
      'xserver-xorg-input-all-lts-xenial'
      'xserver-xorg-video-all-lts-xenial'
      'libegl1-mesa-lts-xenial'
      'libgbm1-lts-xenial'
      'libgl1-mesa-dri-lts-xenial'
      'libgl1-mesa-glx-lts-xenial'
      'libgles1-mesa-lts-xenial'
      'libgles2-mesa-lts-xenial'
      'libwayland-egl1-mesa-lts-xenial'
    )
    # HWE Xorg Package
    XORG_HWE_PACKAGE='xserver-xorg-lts-xenial'
    ;;
  # Xenial Part
  xenial-*-hwe )
    # Require Packages
    declare -a XORG_HWE_REQUIRE_PACKAGES=(
      'xserver-xorg-core-hwe-16.04'
      'xserver-xorg-input-all-hwe-16.04'
      'xserver-xorg-video-all-hwe-16.04'
      'xserver-xorg-legacy-hwe-16.04'
      'libgl1-mesa-dri'
    )
    # HWE Xorg Package
    XORG_HWE_PACKAGE='xserver-xorg-hwe-16.04'
    ;;
  # Bionic Part
  bionic-*-hwe )
    # Require Packages
    XORG_HWE_REQUIRE_PACKAGES=''
    # HWE Xorg Package
    XORG_HWE_PACKAGE=''
    ;;
esac

# Intel LAN Driver Version
INTEL_IXGBE_URL='https://downloadmirror.intel.com/14687/eng/ixgbe-5.5.1.tar.gz'
INTEL_IXGBE_VERSION="$(basename "${INTEL_IXGBE_URL}" | sed -e 's@^ixgbe-@@; s@\.tar\.gz$@@;')"

# Glib Schemas Directory
GLIB_SCHEMAS_DIR='/usr/share/glib-2.0/schemas'

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
# Localize
################################################################################

# Timezone
echo 'Asia/Tokyo' > "${WORKDIR}/etc/timezone"
ln -fs /usr/share/zoneinfo/Asia/Tokyo "${WORKDIR}/etc/localtime"
chroot "${WORKDIR}" dpkg-reconfigure tzdata

# Locale
chroot "${WORKDIR}" locale-gen ja_JP.UTF-8
chroot "${WORKDIR}" update-locale LANG=ja_JP.UTF-8

# Keyboard
if [ "${KEYBOARD}" = 'JP' ]; then
  # Japanese Keyboard
  sed -i -e 's@XKBMODEL="pc105"@XKBMODEL="jp106"@' "${WORKDIR}/etc/default/keyboard"
  sed -i -e 's@XKBLAYOUT="us"@XKBLAYOUT="jp"@'     "${WORKDIR}/etc/default/keyboard"
fi

# CapsLock to Ctrl
sed -i -e 's@XKBOPTIONS=""@XKBOPTIONS="ctrl:nocaps"@' "${WORKDIR}/etc/default/keyboard"

################################################################################
# TTY Autologin
################################################################################

# Root Login
mkdir -p "${WORKDIR}/etc/systemd/system/getty@tty1.service.d"
cat > "${WORKDIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" << '__EOF__'
[Service]
Type=idle
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I linux
__EOF__

# Login Run Script
echo "\~/.startup.sh" >> "${WORKDIR}/root/.bash_login"

# Startup Script
cat > "${WORKDIR}/root/.startup.sh" << '__EOF__'
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

# Set Permission
chmod 0755 "${WORKDIR}/root/.startup.sh"

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
  echo "export no_proxy=\"${NO_PROXY}\""       >> "${WORKDIR}/home/${USER_NAME}/.profile"
  echo "export NO_PROXY=\"${NO_PROXY}\""       >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${FTP_PROXY}" != "x" ]; then
  echo "export ftp_proxy=\"${FTP_PROXY}\""     >> "${WORKDIR}/home/${USER_NAME}/.profile"
  echo "export FTP_PROXY=\"${FTP_PROXY}\""     >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTP_PROXY}" != "x" ]; then
  echo "export http_proxy=\"${HTTP_PROXY}\""   >> "${WORKDIR}/home/${USER_NAME}/.profile"
  echo "export HTTP_PROXY=\"${HTTP_PROXY}\""   >> "${WORKDIR}/home/${USER_NAME}/.profile"
fi
if [ "x${HTTPS_PROXY}" != "x" ]; then
  echo "export https_proxy=\"${HTTPS_PROXY}\"" >> "${WORKDIR}/home/${USER_NAME}/.profile"
  echo "export HTTPS_PROXY=\"${HTTPS_PROXY}\"" >> "${WORKDIR}/home/${USER_NAME}/.profile"
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
if [ "${PROFILE}" = 'server' -o "${PROFILE}" = 'server-nvidia' ]; then
  # Install Package
  chroot "${WORKDIR}" apt-get -y install ubuntu-server language-pack-ja
fi

################################################################################
# Netboot
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install cloud-initramfs-dyn-netconf cloud-initramfs-rooturl

################################################################################
# Overlay
################################################################################

# Require Package
chroot "${WORKDIR}" apt-get -y install overlayroot

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
# Desktop
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'desktop' -o "${PROFILE}" = 'desktop-nvidia' ]; then
  # Check Kernel Version
  case "${KERNEL}" in
    *-hwe )
      # Check Package List
      if [ -n "${XORG_HWE_REQUIRE_PACKAGES[*]}" ]; then
        # Install Require Packages
        chroot "${WORKDIR}" apt-get -y install "${XORG_HWE_REQUIRE_PACKAGES[@]}"
      fi

      # Check Package List
      if [ -n "${XORG_HWE_PACKAGE}" ]; then
        # HWE Version Xorg Server
        chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${XORG_HWE_PACKAGE}"
      fi
      ;;
  esac

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
    echo '[org.gnome.settings-daemon.plugins.keyboard]' >  "${WORKDIR}/${GLIB_SCHEMAS_DIR}/99_japanese-input-method.gschema.override"
    echo 'active=false'                                 >> "${WORKDIR}/${GLIB_SCHEMAS_DIR}/99_japanese-input-method.gschema.override"

    # Compile Glib Schemas
    chroot "${WORKDIR}" glib-compile-schemas "${GLIB_SCHEMAS_DIR}"
  fi

  # Input Method
  chroot "${WORKDIR}" su -c "im-config -n fcitx" "${USER_NAME}"
fi

################################################################################
# NVIDIA
################################################################################

# Check Environment Variable
if [ "${PROFILE}" = 'server-nvidia' -o "${PROFILE}" = 'desktop-nvidia' ]; then
  # NVIDIA Apt Public Key
  wget -qO "${WORKDIR}/tmp/nvidia-keyring.gpg" https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/7fa2af80.pub
  chroot "${WORKDIR}" apt-key add /tmp/nvidia-keyring.gpg

  # NVIDIA CUDA Repository
  echo '# NVIDIA CUDA Repository'                      >  "${WORKDIR}/etc/apt/sources.list.d/nvidia-cuda.list"
  echo "deb $(eval echo -n "${MIRROR_NVIDIA_CUDA}") /" >> "${WORKDIR}/etc/apt/sources.list.d/nvidia-cuda.list"

  # Update Repository
  chroot "${WORKDIR}" apt-get -y update

  # Upgrade System
  chroot "${WORKDIR}" apt-get -y dist-upgrade

  # Install Driver
  chroot "${WORKDIR}" apt-get -y install cuda-drivers

  # Load Boot Time DRM Kernel Mode Setting
  {
    echo 'nvidia'
    echo 'nvidia_drm'
    echo 'nvidia_modeset'
    echo 'nvidia_uvm'
  } >> "${WORKDIR}/etc/initramfs-tools/modules"
fi

################################################################################
# Intel
################################################################################

# Build Tools
chroot "${WORKDIR}" apt-get -y install build-essential

# Kernel Header
chroot "${WORKDIR}" apt-get -y --no-install-recommends install "${KERNEL_HEADER_PACKAGE}"

# Download Archive
wget -qO "${WORKDIR}/tmp/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" "${INTEL_IXGBE_URL}"

# Extract Archive
tar -xf "${WORKDIR}/tmp/ixgbe-${INTEL_IXGBE_VERSION}.tar.gz" -C "${WORKDIR}/usr/src"

# Build Driver
chroot "${WORKDIR}" env BUILD_KERNEL="${KERNEL_VERSION}" make -j "$(nproc)" -C "/usr/src/ixgbe-${INTEL_IXGBE_VERSION}/src" install

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
if [ -n "${SUDO_UID}" -a -n "${SUDO_GID}" ]; then
  chown -R "${SUDO_UID}:${SUDO_GID}" "${DESTDIR}"
fi
