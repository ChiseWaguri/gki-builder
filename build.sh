#!/usr/bin/env bash
set -ex

ret=0
if [[ -z $CHAT_ID ]]; then
    echo "error: please fill CHAT_ID secret!"
    ((ret++))
fi

if [[ -z $TOKEN ]]; then
    echo "error: please fill TOKEN secret!"
    ((ret++))
fi

if [[ -z $GH_TOKEN ]]; then
    echo "error: please fill GH_TOKEN secret!"
    ((ret++))
fi

[[ $ret -gt 0 ]] && exit $ret

# Setup directory
builderdir=$(pwd)
mkdir -p android-kernel && cd android-kernel
workdir=$(pwd) # android-kernel

# Import configuration
source ../config.sh

# ------------------
# Functions
# ------------------

upload_file() {
    local file="$1"

    if ! [[ -f $file ]]; then
        echo "error: file $file doesn't exist"
        exit 1
    fi

    chmod 777 $file

    curl -s -F document=@"$file" "https://api.telegram.org/bot$TOKEN/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=markdown" \
        -o /dev/null
}

send_msg() {
    local msg="$1"
    curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="$msg" \
        -o /dev/null
}

config() {
    $workdir/common/scripts/config "$@"
}

install_ksu() {
    setup_ksu() {
        curl -LSs $1 | bash -s $2
    }

    if [[ $# -eq 0 ]]; then
        echo "Usage: installksu <repo-username/ksu-repo-name> [commit-or-tag]"
        echo ""
        echo "Examples:"
        echo "  installksu tiann/KernelSU        # Installs the latest tagged version"
        echo "  installksu tiann/KernelSU v1.0.3 # Installs a specific commit or tag"
        return 1
    elif [[ -z $2 ]]; then
        local ksu_tags=$(gh api repos/$1/tags --jq '.[0].name')
        local ksu_setup_url=https://raw.githubusercontent.com/$1/refs/tags/$ksu_tags/kernel/setup.sh
        setup_ksu $ksu_setup_url $ksu_tags
    else
        local ksu_setup_url=https://raw.githubusercontent.com/$1/refs/heads/$2/kernel/setup.sh
        setup_ksu $ksu_setup_url $2
    fi

    KSU_VERSION=$(gh api repos/$1/tags --jq '.[0].name')
}

# ---------------
# 	MAIN
# ---------------

# Kernel variant
if [[ $USE_KSU_OFC == "true" ]]; then # official ksu
    if [[ $USE_KSU_SUSFS == "true" ]]; then
        VARIANT="KSUxSUSFS"
    else
        VARIANT="KSU"
    fi
elif [[ $USE_KSU_NEXT == "true" ]]; then # ksun
    if [[ $USE_KSU_SUSFS == "true" ]]; then
        VARIANT="KSUNxSUSFS"
    else
        VARIANT="KSUN"
    fi
elif [[ $USE_KSU_RKSU == "true" ]]; then # rksu
    if [[ $USE_KSU_SUSFS == "true" ]]; then
        VARIANT="RKSUxSUSFS"
    else
        VARIANT="RKSU"
    fi
else
    # vanilla
    VARIANT="none"
fi

# Clone needed repositories
cd $workdir

# Clone the kernel source
git clone --depth=1 $KERNEL_REPO -b $KERNEL_BRANCH common
# Extract kernel version
cd $workdir/common
KERNEL_VERSION=$(make kernelversion)
# Clone kernel patches source
git clone --depth=1 https://github.com/ChiseWaguri/kernel-patches chise_patches
git clone --depth=1 https://github.com/WildPlusKernel/kernel_patches wildplus_patches

# Download Toolchains
cd $workdir
mkdir clang
if [[ $USE_AOSP_CLANG == $USE_CUSTOM_CLANG ]]; then
    echo "error: You have to choose one, AOSP Clang or Custom Clang!"
    exit 1
elif [[ $USE_AOSP_CLANG == "true" ]]; then
    wget -qO clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$AOSP_CLANG_VERSION.tar.gz
    tar -xf clang.tar.gz -C clang/
    rm -f clang.tar.gz
elif [[ $USE_CUSTOM_CLANG == "true" ]]; then
    if [[ $CUSTOM_CLANG_SOURCE == ./*'.tar.'* ]]; then
        wget -q $CUSTOM_CLANG_SOURCE
        tar -C clang/ -xf ./*.tar.*
        rm -f ./*.tar.*
    elif [[ $CUSTOM_CLANG_SOURCE =~ git ]]; then
        rm -rf clang
        git clone --depth=1 $CUSTOM_CLANG_SOURCE -b $CUSTOM_CLANG_BRANCH clang
    else
        echo "error: Clang source other than git nor tar is not supported."
        exit 1
    fi
else
    echo "stfu."
    exit 1
fi

# Clone binutils if they don't exist
if ! echo clang/bin/* | grep -q 'aarch64-linux-gnu'; then
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gas/linux-x86 -b main $workdir/binutils
    export PATH="$workdir/clang/bin:$workdir/binutils:$PATH"
else
    export PATH="$workdir/clang/bin:$PATH"
fi

# Extract clang version
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

# Apply LineageOS maphide patch (thanks to @backslashxx and @WildPlusKernel)
cd $workdir/common
if ! patch -p1 <$workdir/wildplus_patches/69_hide_stuff.patch; then
    echo "Patch rejected. Reverting patch..."
    mv fs/proc/task_mmu.c.orig fs/proc/task_mmu.c || true
    mv fs/proc/base.c.orig fs/proc/base.c || true
fi

# Apply extra tmpfs config
config --file arch/arm64/configs/$KERNEL_DEFCONFIG --enable CONFIG_TMPFS_XATTR
config --file arch/arm64/configs/$KERNEL_DEFCONFIG --enable CONFIG_TMPFS_POSIX_ACL

# Remove KernelSU in driver in kernel source if exist
if [ -d drivers/staging/kernelsu ]; then
    sed -i '/kernelsu/d' drivers/staging/Kconfig
    sed -i '/kernelsu/d' drivers/staging/Makefile
    rm -rf drivers/staging/kernelsu
fi

if [ -d drivers/kernelsu ]; then
    sed -i '/kernelsu/d' drivers/Kconfig
    sed -i '/kernelsu/d' drivers/Makefile
    rm -rf drivers/kernelsu
fi

if [ -d KernelSU ]; then
    rm -rf KernelSU
fi

# KernelSU setup
cd $workdir
if [[ $USE_KSU == true ]]; then
    [[ $USE_KSU_OFC == true ]] && install_ksu tiann/KernelSU
    [[ $USE_KSU_RKSU == true ]] && install_ksu rsuntk/KernelSU $([[ $USE_KSU_SUSFS == true ]] && echo "susfs-v1.5.5-new")
    [[ $USE_KSU_NEXT == true ]] && install_ksu rifsxd/KernelSU-Next $([[ $USE_KSU_SUSFS == true ]] && echo "next-susfs")
fi

# KernelSU manual hook (Need supported source on both kernel and KernelSU)
if [[ $KSU_USE_MANUAL_HOOK == "true" ]]; then
    config --file arch/arm64/configs/$KERNEL_DEFCONFIG --enable CONFIG_KSU_MANUAL_HOOK
fi

git config --global user.email "kontol@example.com"
git config --global user.name "Your Name"

# SUSFS for KSU setup
if [[ $USE_KSU_SUSFS == "true" ]] && [[ $USE_KSU != "true" ]]; then
    echo "error: You can't use SuSFS without KSU enabled!"
    exit 1
elif [[ $USE_KSU == "true" ]] && [[ $USE_KSU_SUSFS == "true" ]]; then
    git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu -b gki-$GKI_VERSION $workdir/susfs4ksu
    SUSFS_PATCHES="$workdir/susfs4ksu/kernel_patches"

    # Copy header files (Kernel Side)
    cd common
    cp $SUSFS_PATCHES/include/linux/* ./include/linux/
    cp $SUSFS_PATCHES/fs/* ./fs/
    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')

    # Apply patch to kernel (Kernel Side)
    patch -p1 <$SUSFS_PATCHES/50_add_susfs_in_gki-$GKI_VERSION.patch || patch -p1 <$workdir/chise_patches/inode.c_fix.patch || exit 1

    # Apply patch to KernelSU (KSU Side)
    if [[ $USE_KSU_OFC == "true" ]]; then
        cd ../KernelSU
        patch -p1 <$SUSFS_PATCHES/KernelSU/10_enable_susfs_for_ksu.patch || exit 1
    fi
fi

# Remove unnecessary code from scripts/setlocalversion
cd $workdir/common
if grep -q '-dirty' scripts/setlocalversion; then
    sed -i 's/-dirty//' scripts/setlocalversion
fi
if grep -q 'echo "+"' scripts/setlocalversion; then
    sed -i 's/echo "+"/# echo "+"/g' scripts/setlocalversion
fi
# sed -i '$s|echo "\$res"|echo "\$res-v3.6.1-Chise-$BUILD_DATE+"|' scripts/setlocalversion

text=$(
    cat <<EOF
*~~~ $KERNEL_NAME CI ~~~*
*GKI Version*: \`$GKI_VERSION\`
*Kernel Version*: \`$KERNEL_VERSION\`
*Build Status*: \`$STATUS\`
*Date*: \`$KBUILD_BUILD_TIMESTAMP\`
*KSU Variant*: \`$VARIANT\`$(echo "$VARIANT" | grep -qi 'KSU' && echo "
*KSU Version*: \`$KSU_VERSION\`")
*SUSFS*: \`$([[ $USE_KSU_SUSFS == "true" ]] && echo "$SUSFS_VERSION" || echo "none")\`
*Compiler*: \`$COMPILER_STRING\`
EOF
)

send_msg "$text"

# Define make args
MAKE_ARGS="
-j$(nproc --all)
ARCH=arm64
LLVM=1
LLVM_IAS=1
O=$workdir/out
CROSS_COMPILE=aarch64-linux-gnu-
CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
"
KERNEL_IMAGE=$workdir/out/arch/arm64/boot/Image

# Build GKI
cd $workdir/common
if [[ $BUILD_KERNEL == "true" ]]; then
    set +e
    (
        make $MAKE_ARGS $KERNEL_DEFCONFIG

        if [[ $BUILD_LKMS != "true" ]]; then
            sed -i 's/=m/=n/g' $workdir/out/.config
        fi

        if [[ -n $DEFCONFIGS ]]; then
            for CONFIG in $DEFCONFIGS; do
                echo "Merging $CONFIG..."
                make $MAKE_ARGS scripts/kconfig/merge_config.sh $CONFIG
            done
        fi

        make $MAKE_ARGS olddefconfig

        make $MAKE_ARGS -j$(nproc --all) \
            Image $([[ $STATUS == "STABLE" ]] || [[ $BUILD_BOOTIMG == "true" ]] && echo "Image.lz4 Image.gz")

    ) 2>&1 | tee $workdir/build.log
    set -e

elif [[ $GENERATE_DEFCONFIG == "true" ]]; then
    make $MAKE_ARGS $KERNEL_DEFCONFIG
    mv $workdir/out/.config $workdir/config
    send_msg "$(curl -s bashupload.com -T $workdir/config)"
    exit 0
fi

cd ..
if ! [[ -f $KERNEL_IMAGE ]]; then
    send_msg "❌ Build failed!"
    upload_file "build.log"
    upload_file "out/.config"
    exit 1
fi

# After-compiling stuff
cd $workdir
# Clone AnyKernel
git clone --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" anykernel

ZIP_NAME=$(
    echo "$ZIP_NAME" |
        sed "s/KVER/$KERNEL_VERSION/g" |
        if [[ $VARIANT == "none" ]]; then
            sed "s/VARIANT-//g"
        else
            sed "s/VARIANT/$VARIANT/g"
        fi
)

sed -i "s/kernel.string=.*/kernel.string=${KERNEL_NAME} ${KERNEL_VERSION} (${BUILD_DATE}) ${VARIANT}/g" $workdir/anykernel/anykernel.sh
if [[ $VARIANT == "none" ]]; then
    OLD=$(grep 'kernel.string' $workdir/anykernel/anykernel.sh | cut -f2 -d '=')
    NEW=$(
        echo "$OLD" |
            sed "s/none//g"
    )
    sed -i "s/kernel.string=.*/kernel.string=${NEW}/g" anykernel/anykernel.sh
fi

if [[ $STATUS == "STABLE" ]] || [[ $BUILD_BOOTIMG == "true" ]]; then
    # Clone tools
    AOSP_MIRROR=https://android.googlesource.com
    BRANCH=main-kernel-build-2024
    git clone $AOSP_MIRROR/kernel/prebuilts/build-tools -b $BRANCH --depth=1 build-tools
    git clone $AOSP_MIRROR/platform/system/tools/mkbootimg -b $BRANCH --depth=1 mkbootimg

    # Variables
    KERNEL_IMAGES=$(echo out/arch/arm64/boot/Image*)
    AVBTOOL=$workdir/build-tools/linux-x86/bin/avbtool
    MKBOOTIMG=$workdir/mkbootimg/mkbootimg.py
    UNPACK_BOOTIMG=$workdir/mkbootimg/unpack_bootimg.py
    BOOT_SIGN_KEY_PATH=$builderdir/key/verifiedboot.pem
    BOOTIMG_NAME="${ZIP_NAME%.zip}-boot-dummy.img"
    # Note: dummy is the Image format

    # Function
    generate_bootimg() {
        local kernel="$1"
        local output="$2"

        # Create boot image
        $MKBOOTIMG --header_version 4 \
            --kernel "$kernel" \
            --output "$output" \
            --ramdisk out/ramdisk \
            --os_version 12.0.0 \
            --os_patch_level $(date +"%Y-%m")

        sleep 1

        # Sign the boot image
        $AVBTOOL add_hash_footer \
            --partition_name boot \
            --partition_size $((64 * 1024 * 1024)) \
            --image "$output" \
            --algorithm SHA256_RSA2048 \
            --key $BOOT_SIGN_KEY_PATH
    }

    # Prepare boot image
    mkdir -p bootimg && cd bootimg
    cp $KERNEL_IMAGES .

    # Download and unpack GKI
    wget -qO gki.zip https://dl.google.com/android/gki/gki-certified-boot-android12-5.10-2023-01_r1.zip
    unzip -q gki.zip && rm gki.zip
    $UNPACK_BOOTIMG --boot_img=./boot-5.10.img
    rm ./boot-5.10.img

    # Generate and sign boot images
    for format in raw lz4 gz; do

        case $format in
        raw)
            kernel="./Image"
            output="${BOOTIMG_NAME/dummy/raw}"
            ;;
        lz4)
            kernel="./Image.lz4"
            output="${BOOTIMG_NAME/dummy/lz4}"
            ;;
        gz)
            kernel="./Image.gz"
            output="${BOOTIMG_NAME/dummy/gz}"
            ;;
        esac

        # Generate and sign
        generate_bootimg "$kernel" "$output"
        mv "$output" $workdir
    done
    cd $workdir
fi

# Zipping
cd anykernel
cp $KERNEL_IMAGE .
zip -r9 $workdir/$ZIP_NAME ./*
cd ..

if [[ $BUILD_LKMS == "true" ]]; then
    mkdir lkm && cd lkm
    # Find .ko files
    ko_files=$(find "$workdir/out" -type f -name "*.ko")
    # Check if any .ko files exist
    if [ -n "$ko_files" ]; then
        echo "Found .ko files, copying to current directory..."
        find "$workdir/out" -type f -name "*.ko" -exec cp {} . \;
        echo "Copy complete."
        zip -r9 $workdir/lkm-$KERNEL_VERSION-$BUILD_DATE.zip ./*
    else
        echo "No LKMs (.ko) files found."
    fi
    cd ..
fi

if [[ $STATUS == "STABLE" ]] || [[ $UPLOAD2GH == "true" ]]; then
    ## Upload into GitHub Release
    TAG="$BUILD_DATE"
    RELEASE_MESSAGE="${ZIP_NAME%.zip}"
    URL="$GKI_RELEASES_REPO/releases/$TAG"
    GITHUB_USERNAME=$(echo "$GKI_RELEASES_REPO" | awk -F'https://github.com/' '{print $2}' | awk -F'/' '{print $1}')
    REPO_NAME=$(echo "$GKI_RELEASES_REPO" | awk -F'https://github.com/' '{print $2}' | awk -F'/' '{print $2}')

    # Clone repository
    if ! git clone --depth=1 "https://${GITHUB_USERNAME}:${GH_TOKEN}@github.com/${GITHUB_USERNAME}/${REPO_NAME}.git" $workdir/rel; then
        echo "❌ Failed to clone GKI releases repository"
        exit 1
    fi

    # Create release
    cd $workdir/rel
    if ! gh release create "$TAG" -t "$RELEASE_MESSAGE"; then
        echo "❌ Failed to create release $TAG"
        exit 1
    fi

    sleep 2

    # Upload files to release
    for release_file in $workdir/*.zip $workdir/*.img; do
        if [[ -f $release_file ]]; then
            if ! gh release upload "$TAG" "$release_file"; then
                echo "❌ Failed to upload $release_file"
                exit 1
            fi
            sleep 2
        fi
    done

    cd ..
fi

if [[ $STATUS == "STABLE" ]] || [[ $UPLOAD2GH == "true" ]]; then
    send_msg "📦 [$RELEASE_MESSAGE]($URL)"
else
    cd $builderdir
    # upload to artifacts
    mv $workdir/*.zip ./
    mv $workdir/*.img ./ || true
    send_msg "✅ Build Succedded"
fi

exit 0
