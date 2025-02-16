# Kernel name
export KERNEL_NAME="QuartiX"

# GKI Version
export GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Makassar"
export KBUILD_BUILD_USER="eraselk"
export KBUILD_BUILD_HOST="$KERNEL_NAME"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
export ANYKERNEL_REPO="https://github.com/hazepynut/anykernel"
export ANYKERNEL_BRANCH="gki"

# Kernel
export KERNEL_REPO="https://github.com/hazepynut/kernel_new"
export KERNEL_BRANCH="android12-5.10"
export KERNEL_DEFCONFIG="gki_defconfig"

# Releases repository
export GKI_RELEASES_REPO="https://github.com/hazepynut/quartix-releases"

# AOSP Clang
export USE_AOSP_CLANG="true"
export AOSP_CLANG_VERSION="r547379"

# Custom clang
export USE_CUSTOM_CLANG="false"
export CUSTOM_CLANG_SOURCE="https://gitlab.com/rvproject27/RvClang"
export CUSTOM_CLANG_BRANCH="release/19.x"

# Zip name
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%y%m%d%H%M")
export ZIP_NAME="$KERNEL_NAME-KVER-VARIANT-$BUILD_DATE.zip"
# Note: KVER and VARIANT are dummy.
# it means they will be changed in the build.sh script.
