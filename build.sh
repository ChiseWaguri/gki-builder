#!/usr/bin/env bash
set -e

# Check chat id, telegram bot token, and GitHub token
ret=0
if [[ -z $chat_id ]]; then
    echo "error: please fill CHAT_ID secret!"
    let ret++
fi

if [[ -z $token ]]; then
    echo "error: please fill TOKEN secret!"
    let ret++
fi

if [[ -z $gh_token ]]; then
    echo "error: please fill GH_TOKEN secret!"
    let ret++
fi

[[ $ret -gt 0 ]] && exit $ret

mkdir -p android-kernel && cd android-kernel

# Variables
WORKDIR=$(pwd)
export WORKDIR=$WORKDIR
source $WORKDIR/../config.sh

# Import functions
source $WORKDIR/../functions.sh

# if use ksu
if [[ $USE_KSU == "yes" ]]; then
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE/KSU/g')
elif [[ $USE_KSU_NEXT == "yes" ]]; then
    # if use ksu next
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE/KSU_NEXT/g')
else
    # if not use ksu or ksu next
    ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/OPTIONE-//g')
fi

# Clone kernel source
git clone --depth=$KERNEL_DEPTH $KERNEL_REPO -b $KERNEL_BRANCH $WORKDIR/common
cd $WORKDIR/common
if [[ $KERNEL_REVERT_COMMIT == "yes" ]]; then
    git checkout $KERNEL_COMMIT_HASH
fi

# Extract kernel version
cd $WORKDIR/common
KERNEL_VERSION=$(make kernelversion)
ZIP_NAME=$(echo "$ZIP_NAME" | sed "s/KVER/$KERNEL_VERSION/g")
cd $WORKDIR

# Download Toolchains
mkdir $WORKDIR/clang
if [[ $USE_AOSP_CLANG == "true" ]]; then
    echo "Downloading https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$AOSP_CLANG_VERSION.tar.gz"
    wget -qO $WORKDIR/clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$AOSP_CLANG_VERSION.tar.gz
    tar -xf $WORKDIR/clang.tar.gz -C $WORKDIR/clang/
    rm -f $WORKDIR/clang.tar.gz
elif [[ $USE_CUSTOM_CLANG == "true" ]]; then
    if [[ $CUSTOM_CLANG_SOURCE =~ git ]]; then
        if [[ $CUSTOM_CLANG_SOURCE == *'.tar.'* ]]; then
            wget -q $CUSTOM_CLANG_SOURCE
            tar -C $WORKDIR/clang/ -xf $WORKDIR/*.tar.*
            rm -f $WORKDIR/*.tar.*
        else
            rm -rf $WORKDIR/clang
            git clone $CUSTOM_CLANG_SOURCE -b $CUSTOM_CLANG_BRANCH $WORKDIR/clang --depth=1
        fi
    else
        echo "Clang source other than git is not supported."
        exit 1
    fi
elif [[ $USE_AOSP_CLANG == "true" ]] && [[ $USE_CUSTOM_CLANG == "true" ]]; then
    echo "You have to choose one, AOSP Clang or Custom Clang!"
    exit 1
else
    echo "stfu."
    exit 1
fi

# Clone binutils if they don't exist
if ! ls $WORKDIR/clang/bin | grep -q 'aarch64-linux-gnu'; then
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gas/linux-x86 -b main $WORKDIR/gas
    export PATH="$WORKDIR/clang/bin:$WORKDIR/gas:$PATH"
else
    export PATH="$WORKDIR/clang/bin:$PATH"
fi

# Extract clang version
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

# Melt remove ksu in staging
sed -i '/kernelsu/d' $WORKDIR/common/drivers/staging/Kconfig
sed -i '/kernelsu/d' $WORKDIR/common/drivers/staging/Makefile
rm -rf $WORKDIR/common/drivers/staging/kernelsu

# LTO Configuration

if [[ $LTO_CONFIG == "NONE" ]]; then
    sed -i 's/CONFIG_LTO=y/CONFIG_LTO=n/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_FULL=n/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_THIN=y/CONFIG_LTO_CLANG_THIN=n/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_THINLTO=y/CONFIG_THINLTO=n/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_LTO_CLANG_NONE=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_LTO_NONE=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    
elif [[ $LTO_CONFIG == "default" ]]; then
    echo "Using default LTO Config from '$DEFCONFIG'"
    
elif [[ $LTO_CONFIG == "THIN" ]]; then
    sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_THIN=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_THIN=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    
elif [[ $LTO_CONFIG == "FULL" ]]; then
    sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_THIN=y/CONFIG_LTO_CLANG_FULL=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_FULL=y/' "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"

fi


# KSU or KSU-Next setup
if [[ $USE_KSU_NEXT == "yes" ]]; then
    curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s next
    cd $WORKDIR/KernelSU-Next
    KSU_VERSION=$(git describe --abbrev=0 --tags)
    echo "CONFIG_KSU=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    cd $WORKDIR
elif [[ $USE_KSU == "yes" ]]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
    cd $WORKDIR/KernelSU
    KSU_VERSION=$(git describe --abbrev=0 --tags)
    echo "CONFIG_KSU=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    cd $WORKDIR
elif [[ $USE_KSU_NEXT == "yes" ]] && [[ $USE_KSU == "yes" ]]; then
    echo
    echo "Bruh"
    exit 1
fi
if [[ $KSU_USE_MANUAL_HOOK == "yes" ]]; then
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
fi

git config --global user.email "kontol@example.com"
git config --global user.name "Your Name"

# Kernel Patches
git clone --depth=1 "https://github.com/ChiseWaguri/kernel-patches" $WORKDIR/kernel-patches
KERNEL_PATCHES="$WORKDIR/kernel-patches"

# TheWildJames Patches
git clone https://github.com/TheWildJames/kernel_patches $WORKDIR/wild-patches
WILD_PATCHES="$WORKDIR/wild-patches"


# SUSFS4KSU setup
if [[ $USE_KSU_SUSFS == "yes" ]]; then
    git clone --depth=1 "https://gitlab.com/simonpunk/susfs4ksu" -b "gki-$GKI_VERSION" $WORKDIR/susfs4ksu
    SUSFS_PATCHES="$WORKDIR/susfs4ksu/kernel_patches"
    # Add SUSFS configuration settings
    echo "CONFIG_KSU_SUSFS=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    if [[ $KSU_USE_MANUAL_HOOK == "yes" ]]; then
        echo "CONFIG_KSU_SUSFS_SUS_SU=n" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    else
        echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"
    fi

    
    
    if [[ $USE_KSU_NEXT != "yes" ]] && [[ $USE_KSU != "yes" ]]; then
        echo "[ERROR] You can't use SUSFS without KSU enabled!"
        exit 1
       
    #KSU+SUSFS setup
    elif [[ $USE_KSU == "yes" ]]; then
        cd $WORKDIR/common
        ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/KSU/KSUxSUSFS/g')
    
        # Copy header files
        cp $SUSFS_PATCHES/include/linux/* ./include/linux/
        cp $SUSFS_PATCHES/fs/* ./fs/
    
        # Apply patch to KernelSU
        cd $WORKDIR/KernelSU
        cp $SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch .
        patch -p1 <10_enable_susfs_for_ksu.patch || exit 1
    
        # Apply patch to kernel
        cd $WORKDIR/common
        cp $SUSFS_PATCHES/50_add_susfs_in_gki-$GKI_VERSION.patch .
        patch -p1 <50_add_susfs_in_gki-$GKI_VERSION.patch || exit 1
    
        SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')

    
        #KSU Next+SUSFS setup
    elif [[ $USE_KSU_NEXT == "yes" ]]; then
        if [[ $SUSFS_REVERT_COMMIT == "yes" ]]; then
            cd $WORKDIR/susfs4ksu
            git checkout $SUSFS_COMMIT_HASH
        fi
    
        cd $WORKDIR/common
        ZIP_NAME=$(echo "$ZIP_NAME" | sed 's/KSU_NEXT/KSU_NEXTxSUSFS/g')
    
        # Copy header files
        cp $SUSFS_PATCHES/include/linux/* ./include/linux/
        cp $SUSFS_PATCHES/fs/* ./fs/
    
        # Apply patch to kernel
        cd $WORKDIR/common
        cp $SUSFS_PATCHES/50_add_susfs_in_gki-$GKI_VERSION.patch .
        echo "Patching GKI SUSFS"
        patch -p1 < 50_add_susfs_in_gki-$GKI_VERSION.patch || exit 1
        
        # Apply patch to KernelSU-Next
        cd $WORKDIR/KernelSU-Next
        echo "Patching KSU-Next"
        cp $KERNEL_PATCHES/Implement-SUSFS-v1.5.4-for-KernelSU-Next.patch .
        patch -p1 --forward < Implement-SUSFS-v1.5.4-for-KernelSU-Next.patch || true
    
        SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' $WORKDIR/common/include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
    fi
fi

# Apply patch
cd $WORKDIR/common
# Apply additional hiding patch
echo "Patching Hiding Stuff"
cp $WILD_PATCHES/69_hide_stuff.patch ./
patch -p1 -F 3 < 69_hide_stuff.patch || true

# Add additional tmpfs config setting
echo "CONFIG_TMPFS_XATTR=y" >> "$WORKDIR/common/arch/arm64/configs/$DEFCONFIG"

# Run sed commands for modifications
sed -i 's/check_defconfig//' "$WORKDIR/common/build.config.gki"
sed -i 's/-dirty//' "$WORKDIR/common/scripts/setlocalversion"
sed -i 's/echo "+"/# echo "+"/g' "$WORKDIR/common/scripts/setlocalversion"
sed -i '$s|echo "\$res"|echo "\$res-Chise+"|' "$WORKDIR/common/scripts/setlocalversion"

cd $WORKDIR

text=$(
    cat <<EOF
*~~~ Compiling $KERNEL_NAME ~~~*
*GKI Version*: \`$GKI_VERSION\`
*Kernel Version*: \`$KERNEL_VERSION\`
*Build Status*: \`$STATUS\`
*Date*: \`$KBUILD_BUILD_TIMESTAMP\`
*KernelSU*: \`$([[ $USE_KSU == "yes" ]] && echo "OG KernelSU")$([[ $USE_KSU_NEXT == "yes" ]] && echo "KernelSU-Next" || echo "-")\`$([[ $USE_KSU == "yes" ]] || [[ $USE_KSU_NEXT == "yes" ]] && echo "
*KSU Version*: \`$KSU_VERSION\`")
$([[ $USE_KSU == "yes" ]] || [[ $USE_KSU_NEXT == "yes" ]] && echo "*SUSFS*: \`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "true" || echo "false")\`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "
*SUSFS Version*: \`$SUSFS_VERSION\`")")
*Compiler*: \`$COMPILER_STRING\`
EOF
)

send_msg "$text"

# Build GKI
cd $WORKDIR/common
set +e
(
    make $MAKE_FLAGS mrproper
    make $MAKE_FLAGS $DEFCONFIG
    upload_file "$WORKDIR/common/.config" "config used"
    make $MAKE_FLAGS -j$(nproc --all)
) 2>&1 | tee $WORKDIR/build.log
set -e
cd $WORKDIR

if ! [[ -f $KERNEL_IMAGE ]]; then
    send_msg "❌ Build failed!"
    upload_file "$WORKDIR/build.log"
    exit 1
else
    # Clone AnyKernel
    git clone --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" $WORKDIR/anykernel

    # Zipping
    cd $WORKDIR/anykernel
    sed -i "s/NAMEDUMMY/$KERNEL_NAME/g" anykernel.sh
    sed -i "s/DUMMY1/$KERNEL_VERSION/g" anykernel.sh
    sed -i "s/DATE/$BUILD_DATE/g" anykernel.sh

    if [[ $USE_KSU != "yes" ]] && [[ $USE_KSU_NEXT != "yes" ]]; then
        sed -i "s/KSUDUMMY2 //g" anykernel.sh
    elif [[ $USE_KSU != "yes" ]] && [[ $USE_KSU_NEXT == "yes" ]]; then
        sed -i "s/KSU/KSU-Next/g" anykernel.sh
    fi

    if [[ $USE_KSU_SUSFS == "yes" ]]; then
        sed -i "s/DUMMY2/xSUSFS/g" anykernel.sh
    else
        sed -i "s/DUMMY2//g" anykernel.sh
    fi

    cp "$KERNEL_IMAGE" .
    zip -r9 "$WORKDIR/$ZIP_NAME" *
    cd "$WORKDIR"

    ## Release into GitHub
    if [[ $RELEASE_INTO_GH == "yes" ]]; then
        release_gh
    fi
    
    upload_file "$WORKDIR/$ZIP_NAME" "$ZIP_NAME"
    upload_file "$KERNEL_IMAGE" "Image"
    
    exit 0
fi
