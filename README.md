# Ubuntu Cloud Image

User Custimization for direnv.

```sh
#!/bin/sh

export KEYBOARD='JP'

export USER_NAME='ubuntu'
export USER_PASS='ubuntu'
export USER_FULL='Ubuntu User'
export USER_KEYS=''

export MIRROR_UBUNTU='http://ftp.jaist.ac.jp/pub/Linux/ubuntu'
export MIRROR_UBUNTU_PARTNER='http://archive.canonical.com'
export MIRROR_UBUNTU_JA='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu'
export MIRROR_UBUNTU_JA_NONFREE='http://ftp.jaist.ac.jp/pub/Linux/ubuntu-jp-archive/ubuntu-ja-non-free'
export MIRROR_NVIDIA_CUDA='http://developer.download.nvidia.com/compute/cuda/repos/ubuntu${RELEASE_MAJOR}${RELEASE_MINOR}/x86_64'

export NO_PROXY=''
export APT_PROXY=''
export FTP_PROXY=''
export HTTP_PROXY=''
export HTTPS_PROXY=''
```

Creating Ubuntu Cloud Image

```sh
$ sudo -E ./overlayroot.sh ./profile/[select profile].sh
```
