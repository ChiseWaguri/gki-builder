# GKI Version
export GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="chise"
export KBUILD_BUILD_HOST="ubuntu24"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
export ANYKERNEL_REPO="https://github.com/ChiseWaguri/Anykernel3"
export ANYKERNEL_BRANCH="gki"

# Kernel
export KERNEL_REPO="https://github.com/ChiseWaguri/android_kernel_xiaomi_marble"
export KERNEL_BRANCH="next-susfs"
export DEFCONFIG="marble_defconfig"
export KERNEL_IMAGE="$workdir/out/arch/arm64/boot/Image"

# If you want to revert kernel repo to a specific commit hash/ or tag for some purposes
export KERNEL_DEPTH=1 # depth needed to revert to the commit hash, set it to 1 if you're not reverting kernel repo commit
export KERNEL_COMMIT_HASH="" # commit hash if u need to revert to some commit for testing purposes

# Melt KSU Manual Hook
export MELT_KSU_USE_MANUAL_HOOK=yes

# LTO
export LTO_CONFIG="default" 
# default, THIN, FULL, NONE

# Releases repository
export GKI_RELEASES_REPO="https://github.com/ChiseWaguri/releases"

# AOSP Clang
export USE_AOSP_CLANG="true"
export AOSP_CLANG_VERSION="r547379"

# Custom clang
export USE_CUSTOM_CLANG="false"
export CUSTOM_CLANG_SOURCE="" # git repo or tar file
export CUSTOM_CLANG_BRANCH="" # if from git

# Make flags
export MAKE_FLAGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 O=$workdir/out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"

# Zip name
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%m%d%y")
export KERNEL_NAME=Melt
export ZIP_NAME=$KERNEL_NAME-KVER-OPTIONE-$BUILD_DATE.zip
