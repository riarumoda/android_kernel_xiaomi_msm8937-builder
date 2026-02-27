#!/bin/bash
##################################################
# Unofficial LineageOS Perf kernel Compile Script
# Based on the original compile script by vbajs
# Forked by Riaru Moda
##################################################

setup_environment() {
    echo "Setting up build environment..."
    # Imports
    local MAIN_DEFCONFIG_IMPORT="$1"
    local DEVICE_DEFCONFIG_IMPORT="$2"
    local KERNELSU_SELECTOR="$3"
    # Maintainer info
    export KBUILD_BUILD_USER=riaru-compile
    export KBUILD_BUILD_HOST=riaru.com
    export GIT_NAME="$KBUILD_BUILD_USER"
    export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"
    # GCC and Clang settings
    export CLANG_REPO_URI="https://git.codelinaro.org/clo/la/kernelplatform/prebuilts-master/clang/host/linux-x86.git"
    export GCC_64_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
    export GCC_32_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
    export CLANG_DIR=$PWD/clang
    export GCC64_DIR=$PWD/gcc64
    export GCC32_DIR=$PWD/gcc32
    export PATH="$CLANG_DIR/clang-r547379/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
    # Defconfig Settings
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/$MAIN_DEFCONFIG_IMPORT"
    export DEVICE_DEFCONFIG="arch/arm64/configs/vendor/xiaomi/$DEVICE_DEFCONFIG_IMPORT"
    export FEATURE_DEFCONFIG="arch/arm64/configs/vendor/feature/android-12.config arch/arm64/configs/vendor/feature/erofs.config arch/arm64/configs/vendor/feature/lineageos.config arch/arm64/configs/vendor/feature/lmkd.config arch/arm64/configs/vendor/feature/lto.config arch/arm64/configs/vendor/feature/wireguard.config"
    export CENTER_STAGE_DEFCONFIG="neon-perf_defconfig"
    # Defconfig common Settings
    if [[ "$MAIN_DEFCONFIG" == *"mi8937"* ]]; then
        export COMMON_DEFCONFIG="arch/arm64/configs/vendor/common.config arch/arm64/configs/vendor/debugfs.config arch/arm64/configs/vendor/msm-clk.config arch/arm64/configs/vendor/msm8937-legacy.config arch/arm64/configs/vendor/xiaomi/msm8937/common.config"
    else
        export COMMON_DEFCONFIG="arch/arm64/configs/vendor/common.config arch/arm64/configs/vendor/debugfs.config arch/arm64/configs/vendor/msm-clk.config"
    fi
    # KernelSU Settings
    if [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_BLXX" ]]; then
        export KSU_SETUP_URI="https://github.com/backslashxx/KernelSU/raw/refs/heads/master/kernel/setup.sh"
        export KSU_BRANCH="master"
        export KSU_GENERAL_PATCH="https://github.com/ximi-mojito-test/mojito_krenol/commit/ebc23ea38f787745590c96035cb83cd11eb6b0e7.patch"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=NONE" ]]; then
        export KSU_SETUP_URI=""
        export KSU_BRANCH=""
        export KSU_GENERAL_PATCH=""
    else
        echo "Invalid KernelSU selector. Use --ksu=KSU_BLXX, or --ksu=NONE."
        exit 1
    fi
    # KernelSU umount patch
    export KSU_UMOUNT_PATCH="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/64db0dfa2f8aa6c519dbf21eb65c9b89643cda3d.patch"
}

# Setup toolchain function
setup_toolchain() {
    echo "Setting up toolchain..."
    if [ ! -d "$PWD/clang" ]; then
        git clone $CLANG_REPO_URI --depth=1 clang &> /dev/null
    else
        echo "Local clang dir found, using it."
    fi
    if [ ! -d "$PWD/gcc64" ]; then
        git clone $GCC_64_REPO_URI --depth=1 gcc64 &> /dev/null
    else
        echo "Local gcc64 dir found, using it."
    fi
    if [ ! -d "$PWD/gcc32" ]; then
        git clone $GCC_32_REPO_URI --depth=1 gcc32 &> /dev/null
    else
        echo "Local gcc32 dir found, using it."
    fi
}

# Add patches function
add_patches() {
    # Apply general config patches
    echo "Tuning the rest of default configs..."
    sed -i 's/# CONFIG_PID_NS is not set/CONFIG_PID_NS=y/' $MAIN_DEFCONFIG
    sed -i 's/CONFIG_HZ_100=y/CONFIG_HZ_250=y/' $MAIN_DEFCONFIG
    echo "CONFIG_POSIX_MQUEUE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SYSVIPC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CGROUP_DEVICE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DEVTMPFS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_IPC_NS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DEVTMPFS_MOUNT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE_STATS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_FSCACHE_HISTOGRAM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    # Make image smaller by disabling kallsyms
    echo "CONFIG_KALLSYMS=n" >> $MAIN_DEFCONFIG
    echo "CONFIG_KALLSYMS_ALL=n" >> $MAIN_DEFCONFIG
    # Enable config mismatch
    # echo "CONFIG_DEBUG_SECTION_MISMATCH=y" >> $MAIN_DEFCONFIG
}

# Add KernelSU function
add_ksu() {
    if [ -n "$KSU_SETUP_URI" ]; then
        echo "Setting up KernelSU..."
        # Apply umount backport and kpatch fixes
        wget -qO- $KSU_UMOUNT_PATCH | patch -s -p1
        if [[ "$KSU_SETUP_URI" == *"backslashxx/KernelSU"* ]]; then
            # Apply manual hook
            # disable for now, we're gonna use hookless mode
            # wget -qO- $KSU_GENERAL_PATCH | patch -s -p1
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" >> $MAIN_DEFCONFIG
        fi
    else
        echo "No KernelSU to set up."
    fi
}


# Compile kernel function
compile_kernel() {
    # Merge all of the configs into one defconfig
    echo "Merging defconfigs..."
    mkdir -p out
    ARCH=arm64 ./scripts/kconfig/merge_config.sh -O out/ -m \
        $MAIN_DEFCONFIG \
        $COMMON_DEFCONFIG \
        $DEVICE_DEFCONFIG \
        $FEATURE_DEFCONFIG
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        olddefconfig
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        savedefconfig
    cp out/defconfig arch/arm64/configs/$CENTER_STAGE_DEFCONFIG
    rm -rf out
    mkdir -p out
    # Do a git cleanup before compiling
    echo "Cleaning up git before compiling..."
    git config user.email $GIT_EMAIL
    git config user.name $GIT_NAME
    git config set advice.addEmbeddedRepo true
    git add .
    git commit -m "cleanup: applied patches before build" &> /dev/null
    # Start compilation
    echo "Starting kernel compilation..."
    make -s O=out ARCH=arm64 $CENTER_STAGE_DEFCONFIG &> /dev/null
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        Image.gz dtbs Image.gz-dtb
}

# Main function
main() {
    # Check if all four arguments are valid
    echo "Validating input arguments..."
    if [ $# -ne 3 ]; then
        echo "Usage: $0 <MAIN_DEFCONFIG_IMPORT> <DEVICE_DEFCONFIG_IMPORT> <KERNELSU_SELECTOR>"
        echo "Example: $0 msm8937-perf_defconfig msm8937/mi8937.config --ksu=KSU_BLXX"
        exit 1
    fi
    if [ ! -f "arch/arm64/configs/vendor/$1" ]; then
        echo "Error: MAIN_DEFCONFIG_IMPORT '$1' does not exist."
        exit 1
    fi
    if [ ! -f "arch/arm64/configs/vendor/xiaomi/$2" ]; then
        echo "Error: DEVICE_DEFCONFIG_IMPORT '$2' does not exist."
        exit 1
    fi
    setup_environment "$1" "$2" "$3"
    setup_toolchain
    add_patches
    add_ksu
    compile_kernel
}

# Run the main function
main "$1" "$2" "$3"