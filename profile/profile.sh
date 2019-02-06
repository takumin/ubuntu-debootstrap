#!/bin/bash
# vim: set noet :

# Get Profile Directory
PROFILE_DIR="${BASH_SOURCE##*profile/}"

# Convert Array
PROFILE_ARRAY=(${PROFILE_DIR//\// })

# Set Variables
RELEASE="${PROFILE_ARRAY[0]}"
KERNEL="${PROFILE_ARRAY[1]}"
PROFILE="${PROFILE_ARRAY[2]%.sh}"
