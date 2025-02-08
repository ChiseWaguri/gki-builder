# GKI Version
export GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Makassar"
export KBUILD_BUILD_USER="eraselk"
export KBUILD_BUILD_HOST="QuartiX"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
export ANYKERNEL_REPO="https://github.com/ChiseWaguri/anykernel"
export ANYKERNEL_BRANCH="multi"

# Kernel
export KERNEL_REPO="https://github.com/hazepynut/gki_android12-5.10"
export KERNEL_BRANCH="master"
export KERNEL_DEFCONFIG="gki_defconfig"

# Releases repository
export GKI_RELEASES_REPO="https://github.com/hazepynut/quartix-releases"

# AOSP Clang
export USE_AOSP_CLANG="false"
export AOSP_CLANG_VERSION="r547379"

# Custom clang
export USE_CUSTOM_CLANG="true"
export CUSTOM_CLANG_SOURCE=$(curl -s https://api.github.com/repos/ZyCromerZ/Clang/releases/latest | grep "browser_download_url" | cut -d '"' -f4)
export CUSTOM_CLANG_BRANCH=""

# Zip name
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%y%m%d%H%M")
export ZIP_NAME="QuartiX-KVER-OPTIONE-$BUILD_DATE.zip"
