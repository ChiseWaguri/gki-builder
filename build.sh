#!/usr/bin/env bash
set -ex

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

# Setup directory
homedir=$(pwd)
mkdir -p out
mkdir -p android-kernel && cd android-kernel

# Variables
workdir=$(pwd)
export workdir=$workdir
source ../config.sh

# Import functions
source ../functions.sh

# Clone source
git clone https://gitlab.com/simonpunk/susfs4ksu -b gki-android12-5.10
git clone https://github.com/ChiseWaguri/kernel-patches ./chise_patches
git clone https://github.com/WildPlusKernel/kernel_patches ./wild_patches
git clone --depth=$KERNEL_DEPTH $KERNEL_REPO -b $KERNEL_BRANCH common
cd $workdir/common
if [[ -z "$KERNEL_COMMIT_HASH" ]]; then
    git checkout $KERNEL_COMMIT_HASH
fi

# Extract kernel version
KERNEL_VERSION=$(make kernelversion)
cd $workdir

# Download Toolchains
mkdir clang
if [[ $USE_AOSP_CLANG == "true" ]]; then
    wget -qO clang.tar.gz https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-$AOSP_CLANG_VERSION.tar.gz
    tar -xf clang.tar.gz -C clang/
    rm -f clang.tar.gz
elif [[ $USE_CUSTOM_CLANG == "true" ]]; then
    if [[ $CUSTOM_CLANG_SOURCE =~ git ]]; then
        if [[ $CUSTOM_CLANG_SOURCE == *'.tar.'* ]]; then
            wget -qO clang.tar.gz $CUSTOM_CLANG_SOURCE
			tar -xf clang.tar.gz -C $workdir/clang/
            rm -f *.tar.*
        else
            rm -rf clang
            git clone $CUSTOM_CLANG_SOURCE -b $CUSTOM_CLANG_BRANCH $workdir/clang --depth=1
        fi
	elif [[ $CUSTOM_CLANG_SOURCE == *'.tar.'* ]]; then
            wget -qO clang.tar.gz $CUSTOM_CLANG_SOURCE
			tar -xf clang.tar.gz -C $workdir/clang/
            rm -f *.tar.*
    else
        echo "Clang source other than git or tar file is not supported."
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
if ! ls clang/bin | grep -q 'aarch64-linux-gnu'; then
    git clone --depth=1 https://android.googlesource.com/platform/prebuilts/gas/linux-x86 -b main gas
    export PATH="$workdir/clang/bin:$workdir/gas:$PATH"
else
    export PATH="$workdir/clang/bin:$PATH"
fi

# Extract clang version
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

# LTO Configuration
cd common
if [[ $LTO_CONFIG == "NONE" ]]; then
    sed -i 's/CONFIG_LTO=y/CONFIG_LTO=n/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_FULL=n/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_THIN=y/CONFIG_LTO_CLANG_THIN=n/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_THINLTO=y/CONFIG_THINLTO=n/' "arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_LTO_CLANG_NONE=y" >> "arch/arm64/configs/$DEFCONFIG"
    echo "CONFIG_LTO_NONE=y" >> "arch/arm64/configs/$DEFCONFIG"
    
elif [[ $LTO_CONFIG == "default" ]]; then
    echo "Using default LTO Config from '$DEFCONFIG'"
    
elif [[ $LTO_CONFIG == "THIN" ]]; then
    sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_FULL=y/CONFIG_LTO_CLANG_THIN=y/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_THIN=y/' "arch/arm64/configs/$DEFCONFIG"
    
elif [[ $LTO_CONFIG == "FULL" ]]; then
    sed -i 's/CONFIG_LTO=n/CONFIG_LTO=y/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_THIN=y/CONFIG_LTO_CLANG_FULL=y/' "arch/arm64/configs/$DEFCONFIG"
    sed -i 's/CONFIG_LTO_CLANG_NONE=y/CONFIG_LTO_CLANG_FULL=y/' "arch/arm64/configs/$DEFCONFIG"

fi

git config --global user.email "kontol@example.com"
git config --global user.name "Your Name"

# Apply patch
echo "Patching Hiding Stuff"
patch -p1 -F 3 < ../wild_patches/69_hide_stuff.patch || true

# Add additional tmpfs config setting
echo "CONFIG_TMPFS_XATTR=y" >> "arch/arm64/configs/$DEFCONFIG"

# Run sed commands for modifications
sed -i 's/check_defconfig//' "$workdir/common/build.config.gki"
sed -i 's/-dirty//' "$workdir/common/scripts/setlocalversion"
sed -i 's/echo "+"/# echo "+"/g' "$workdir/common/scripts/setlocalversion"
sed -i '$s|echo "\$res"|echo "\$res-$BUILD_DATE"|' "$workdir/common/scripts/setlocalversion"


text=$(
    cat <<EOF
*~~~ Compiling $KERNEL_NAME ~~~*
*GKI Version*: \`$GKI_VERSION\`
*Kernel Version*: \`$KERNEL_VERSION\`
EOF
)

send_msg "$text"



if [[ $build_type == "Multi" ]]; then
	echo "multi part 1"
	send_msg "$text"

	# Build GKI
	cd $workdir/common
	set +e
	(
		m mrproper
		m $DEFCONFIG
		[[ ! -z $DEFCONFIGS ]] && m ./scripts/kconfig/merge_config.sh $DEFCONFIGS
		scripts/config --file $workdir/out/.config --set-str LOCALVERSION "-$KERNEL_NAME"
		m
	) 2>&1 | tee $workdir/build.log
	set -e

	if ! [[ -f $KERNEL_IMAGE ]]; then
		send_msg "❌ Build failed!"
		upload_file "$workdir/build.log"
		exit 1
	else
		send_msg "NonKSU build success!"
		cp $KERNEL_IMAGE $homedir/out/NoKSU
		make $MAKE_FLAGS mrproper
		cd $workdir
	fi
fi

# KernelSU setup
if [[ $MELT_KSU_USE_MANUAL_HOOK == "yes" ]]; then
	echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$workdir/common/arch/arm64/configs/$DEFCONFIG"
fi

if [[ $USE_KSU_SUSFS == "yes" ]] || [[ $USE_KSU_OG != "yes" ]]; then
# Remove KernelSU in driver in kernel source if exist
	if [ -d "$workdir/common/drivers/staging/kernelsu" ]; then
		sed -i '/kernelsu/d' "$workdir/common/drivers/staging/Kconfig"
		sed -i '/kernelsu/d' "$workdir/common/drivers/staging/Makefile"
		rm -rf "$workdir/common/drivers/staging/kernelsu"
	fi
	if [ -d "$workdir/common/drivers/kernelsu" ]; then
		sed -i '/kernelsu/d' "$workdir/common/drivers/Kconfig"
		sed -i '/kernelsu/d' "$workdir/common/drivers/Makefile"
		rm -rf "$workdir/common/drivers/kernelsu"
	fi
	if [ -d "$workdir/common/KernelSU" ]; then
        rm -rf "$workdir/common/KernelSU"
    fi
fi

cd $workdir

if [[ $USE_KSU == yes ]]; then
	if [[ $USE_KSU_OG == "yes" ]] && [[ $USE_KSU_SUSFS == "yes" ]]; then
		curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
		cd $workdir/KernelSU

	elif [[ $USE_KSU_XX == "yes" ]]; then
		curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/magic/kernel/setup.sh" | bash -s magic
		cd $workdir/KernelSU

	elif [[ $USE_KSU_MKSU == "yes" ]]; then
		curl -LSs "https://raw.githubusercontent.com/5ec1cff/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
		cd $workdir/KernelSU

	elif [[ $USE_KSU_RKSU == "yes" ]]; then
		if [[ $USE_KSU_SUSFS == "yes" ]]; then
			curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s susfs-v1.5.5
		else
			curl -LSs "https://raw.githubusercontent.com/rsuntk/KernelSU/refs/heads/main/kernel/setup.sh" | bash -
		fi
		cd $workdir/KernelSU
		
	elif [[ $USE_KSU_NEXT == "yes" ]]; then
		if [[ $USE_KSU_SUSFS == "yes" ]]; then
			curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s next-susfs
		else
			curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s next
		fi
		cd $workdir/KernelSU-Next
		# patch -p1 < ../chise_patches/ksu-next_add-manager.patch || true
		# sed -i 's/return check_v2_signature(path, EXPECTED_NEXT_SIZE, EXPECTED_NEXT_HASH);/"return (check_v2_signature(path, EXPECTED_NEXT_SIZE, EXPECTED_NEXT_HASH) \
			# || check_v2_signature(path, 0x033b, c371061b19d8c7d7d6133c6a9bafe198fa944e50c1b31c9d8daa8d7f1fc2d2d6) \
			# || check_v2_signature(path, 0x384, 7e0c6d7278a3bb8e364e0fcba95afaf3666cf5ff3c245a3b63c8833bd0445cc4) \
			# || check_v2_signature(path, 0x396, f415f4ed9435427e1fdf7f1fccd4dbc07b3d6b8751e4dbcec6f19671f427870b));"/g'  kernel/apk_sign.c		
	
	fi
echo "CONFIG_KSU=y" >> "$workdir/common/arch/arm64/configs/$DEFCONFIG"
# KSU Version
[[ $USE_KSU_MKSU == "yes" ]] && KSU_VERSION="Magic KSU"
[[ $USE_KSU_XX == "yes" ]] && KSU_VERSION="xx's KSU Fork $(git describe --abbrev=0 --tags)"
[[ $USE_KSU_RKSU == "yes" ]] && KSU_VERSION="Rissu KSU Fork $(git describe --abbrev=0 --tags)"
[[ $USE_KSU_OG == "yes" ]] && KSU_VERSION="OG KSU $(git describe --abbrev=0 --tags)"
fi
cd $workdir

# SUSFS4KSU setup
if [[ $USE_KSU_SUSFS == "yes" ]] && [[ $USE_KSU != "yes" ]]; then
    echo "error: You can't use SuSFS without KSU enabled!"
    exit 1
elif [[ $USE_KSU == "yes" ]] && [[ $USE_KSU_SUSFS == "yes" ]]; then
	# Copy header files
	cd $workdir/common
    cp ../susfs4ksu/kernel_patches/include/linux/* ./include/linux/
	cp ../susfs4ksu/kernel_patches/fs/* ./fs/
	
	# Apply patch to kernel.
	patch -p1 < ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-$GKI_VERSION.patch || patch -p1 < ../chise_patches/inode.c_fix.patch || exit 1
	
    # KSU + SUSFS setup
    if [[ $USE_KSU_OG == "yes" ]] || [[ $USE_KSU_XX == "yes" ]] || [[ $USE_KSU_MKSU == "yes" ]]; then

        # Apply patch to KernelSU
        cd $workdir/KernelSU
        patch -p1 --forward < ../susfs4ksu/kernel_patches/10_enable_susfs_for_ksu.patch || patch -p1 < ../wild_patches/mksu_susfs.patch || exit 0

    # KSU-Next + SUSFS setup
    elif [[ $USE_KSU_NEXT == "yes" ]] || [[ $USE_KSU_RKSU == "yes" ]]; then
		: # No need cuz we use the susfs branch.
    fi
	
# Grab susfs version
SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' $workdir/common/include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
fi




text=$(
    cat <<EOF
*~~~ Compiling $KERNEL_NAME ~~~*
*KernelSU*: \`$([[ $USE_KSU == "yes" ]] && echo "yes")$([[ $USE_KSU_NEXT == "yes" ]] && echo "KernelSU-Next" || echo "-")\`$([[ $USE_KSU == "yes" ]] || [[ $USE_KSU_NEXT == "yes" ]] && echo "
*KSU Version*: \`$KSU_VERSION\`")
$([[ $USE_KSU == "yes" ]] || [[ $USE_KSU_NEXT == "yes" ]] && echo "*SUSFS*: \`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "true" || echo "false")\`$([[ $USE_KSU_SUSFS == "yes" ]] && echo "
*SUSFS Version*: \`$SUSFS_VERSION\`")")
*Compiler*: \`$COMPILER_STRING\`
EOF
)

send_msg "$text"

# Add + to kernel name for ksu version
if [ $USE_KSU == "yes" ]; then
    sed -i 's/Chise-$BUILD_DATE/Chise+-$BUILD_DATE/g' "$workdir/common/scripts/setlocalversion"
fi

# Build KSU
cd $workdir/common
set +e
(
	m mrproper
	m $DEFCONFIG
	[[ ! -z $DEFCONFIGS ]] && m ./scripts/kconfig/merge_config.sh $DEFCONFIGS
	scripts/config --file $workdir/out/.config --set-str LOCALVERSION "-$KERNEL_NAME-plus"
	m
) 2>&1 | tee $workdir/build.log
set -e

if ! [[ -f $KERNEL_IMAGE ]]; then
    send_msg "❌ Build KSU failed!"
    upload_file "$workdir/build.log"
    exit 1
else
	send_msg "KSU build success!"
	cp $KERNEL_IMAGE $homedir/out/KSU
fi

cd $homedir/out
if [[ $build_type == "Multi" ]]; then
	# Install bsdiff to patch Multi
	sudo add-apt-repository ppa:eugenesan/ppa
	sudo apt-get update -y
	sudo apt-get install bsdiff -y

	# Preparing artifact
	bsdiff NoKSU KSU ksu.p
	mkdir ./KernelSU
	mv ./NoKSU ./Image
	mv ./KSU ./KernelSU/Image
else
    mv ./KSU ./Image
fi

zip -r9 "$homedir/kernel.zip" *
send_msg "Success! Uploading Artifact..."
upload_file "$homedir/kernel.zip"

# end of build.sh
exit 0