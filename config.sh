#!/usr/bin/env bash

# Kernel name
KERNEL_NAME="Melt"

# GKI Version
GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="chise"
export KBUILD_BUILD_HOST="ubuntu24"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
ANYKERNEL_REPO="https://github.com/hazepynut/anykernel"
ANYKERNEL_BRANCH="gki"

# Kernel
KERNEL_REPO="https://github.com/Pzqqt/android_kernel_xiaomi_marble"
KERNEL_BRANCH="melt-rebase"
KERNEL_DEFCONFIG="marble_defconfig"
# Defconfigs below would be merged in the compiling processes
DEFCONFIGS_EXAMPLE="
vendor/xiaomi.config
vendor/gold.config
"
DEFCONFIGS="
" # Leave this empty if you don't need to merge any configs

# Manual Hook
KSU_USE_MANUAL_HOOK=false

# Releases repository
GKI_RELEASES_REPO="https://github.com/hazepynut/quartix-releases"

# AOSP Clang
USE_AOSP_CLANG="false"
AOSP_CLANG_VERSION="r547379"

# Custom clang
USE_CUSTOM_CLANG="true"
CUSTOM_CLANG_SOURCE="https://gitlab.com/rvproject27/RvClang"
CUSTOM_CLANG_BRANCH="release/19.x"

# Zip name
BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%y%m%d%H%M")
ZIP_NAME="$KERNEL_NAME-KVER-VARIANT-$BUILD_DATE.zip"
# Note: KVER and VARIANT are placeholder and they will be changed in the build.sh script.
