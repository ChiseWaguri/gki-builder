# GKI Version
export GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Makassar"
export KBUILD_BUILD_USER="eraselk"
export KBUILD_BUILD_HOST="gacorprjkt"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
export ANYKERNEL_REPO="https://github.com/Asteroidd21/Anykernel3"
export ANYKERNEL_BRANCH="gold"

# Kernel
export KERNEL_REPO="https://github.com/Asteroidd21/kernel_ximi_gold"
export KERNEL_BRANCH="master"
export DEFCONFIG="gold_defconfig"
export KERNEL_IMAGE="$WORKDIR/out/arch/arm64/boot/Image"

# Releases repository
export GKI_RELEASES_REPO="https://github.com/Asteroidd21/gki-releases"

# AOSP Clang
export USE_AOSP_CLANG="false"
export AOSP_CLANG_VERSION="r547379"

# Custom clang
export USE_CUSTOM_CLANG="true"
export CUSTOM_CLANG_SOURCE="https://github.com/Asteroidd21/gacorprjkt-clang/releases/download/20250105-1441/clang.tar.zst"
export CUSTOM_CLANG_BRANCH=""

# Make flags
export MAKE_FLAGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 O=$WORKDIR/out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"

# Zip name
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%y%m%d%H%M")
export ZIP_NAME="kerneltest-gold-KVER-OPTIONE-$BUILD_DATE.zip"
