# GKI Version
export GKI_VERSION="android12-5.10"

# Build variables
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="chise"
export KBUILD_BUILD_HOST="localhost"
export KBUILD_BUILD_TIMESTAMP=$(date)

# AnyKernel variables
export ANYKERNEL_REPO="https://github.com/ChiseWaguri/Anykernel3"
export ANYKERNEL_BRANCH="gki"

# Kernel
export KERNEL_REPO="https://github.com/pzqqt/android_kernel_xiaomi_marble"
export KERNEL_BRANCH="melt-rebase"
export KERNEL_DEPTH=1 # depth needed to revert to the commit hash, set it to 1 if you're not reverting kernel repo commit
export DEFCONFIG="marble_defconfig"
export KERNEL_IMAGE="$WORKDIR/out/arch/arm64/boot/Image"
# If you want to revert kernel repo to a specific commit hash/ or tag for some purposes
export KERNEL_REVERT_COMMIT=no # yes or no
export KERNEL_COMMIT_HASH=6cd5ee6f67f9374dca475929923d1e8c558832c8

# KSU Manual Hook
export KSU_USE_MANUAL_HOOK=yes

# SUSFS4KSU for KSU-Next
export SUSFS_REVERT_COMMIT=false
export SUSFS_COMMIT_HASH=1833d53211478a9e44f89eb50785018051e0bd8a

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
export MAKE_FLAGS="ARCH=arm64 LLVM=1 LLVM_IAS=1 O=$WORKDIR/out CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"

# Zip name
export BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%y%m%d%H%M")
export KERNEL_NAME=Melt
export ZIP_NAME=$KERNEL_NAME-KVER-OPTIONE-$BUILD_DATE.zip
