#!/bin/bash
##################################################
# Unofficial LineageOS Perf kernel Compile Script
# Based on the original compile script by vbajs
# Forked by Riaru Moda
##################################################

setup_environment() {
    echo "Setting up build environment..."
    # Imports
    local DEVICE_IMPORT="$1"
    local KERNELSU_SELECTOR="$2"
    # Maintainer info
    export KBUILD_BUILD_USER=riaru-compile
    export KBUILD_BUILD_HOST=riaru.com
    export GIT_NAME="$KBUILD_BUILD_USER"
    export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"
    # GCC and Clang settings
    export CLANG_REPO_URI="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git"
    export GCC_64_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
    export GCC_32_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
    export CLANG_DIR=$PWD/clang
    export GCC64_DIR=$PWD/gcc64
    export GCC32_DIR=$PWD/gcc32
    export PATH="$CLANG_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
    # Defconfig Settings - v2
    if [[ "$DEVICE_IMPORT" == "mi89x7" ]]; then
        # Editable defconfig
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/msm8937-perf_defconfig"
        # Do not use for edit
        export ACTUAL_MAIN_DEFCONFIG="vendor/msm8937-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/msm8937-legacy.config vendor/common.config vendor/msm-clk.config"
        export DEVICE_DEFCONFIG="vendor/xiaomi/msm8937/common.config vendor/xiaomi/msm8937/mi8937.config"
        export FEATURE_DEFCONFIG="vendor/feature/android-12.config vendor/feature/erofs.config vendor/feature/kprobes.config vendor/feature/lmkd.config vendor/feature/lto.config"
    elif [[ "$DEVICE_IMPORT" == "mi89x7-a11" ]]; then
        # Editable defconfig
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/msm8937-perf_defconfig"
        # Do not use for edit
        export ACTUAL_MAIN_DEFCONFIG="vendor/msm8937-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/msm8937-legacy.config vendor/common.config vendor/msm-clk.config"
        export DEVICE_DEFCONFIG="vendor/xiaomi/msm8937/common.config vendor/xiaomi/msm8937/mi8937.config"
        export FEATURE_DEFCONFIG="vendor/feature/erofs.config vendor/feature/kprobes.config vendor/feature/lmkd.config vendor/feature/lto.config"
    else
        echo "Invalid MAIN_DEFCONFIG_IMPORT. Use a valid defconfig filename from arch/arm64/configs/vendor/ directory."
        exit 1
    fi
    # KernelSU Settings
    if [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_BLXX" ]]; then
        export KSU_SETUP_URI="https://github.com/backslashxx/KernelSU/raw/refs/heads/master/kernel/setup.sh"
        export KSU_BRANCH="master"
        export KSU_GENERAL_PATCH="https://github.com/zeta96/android_kernel_xiaomi_msm8937/commit/49f07744f13de12606b1d4ebc5eeac60b19c97e4.patch"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_NEXT" ]]; then
        export KSU_SETUP_URI="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh"
        export KSU_BRANCH="legacy"
        export KSU_GENERAL_PATCH="https://github.com/zeta96/android_kernel_xiaomi_msm8937/commit/49f07744f13de12606b1d4ebc5eeac60b19c97e4.patch"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=NONE" ]]; then
        export KSU_SETUP_URI=""
        export KSU_BRANCH=""
        export KSU_GENERAL_PATCH=""
    else
        echo "Invalid KernelSU selector. Use --ksu=KSU_BLXX, --ksu=KSU_NEXT, or --ksu=NONE."
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
    # Apply O3 flags into Kernel Makefile
    echo "Applying O3 to the Makefile..."
    sed -i 's/KBUILD_CFLAGS\s\++= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    sed -i 's/LDFLAGS\s\++= -O2/LDFLAGS += -O3/g' Makefile
    # Enable config mismatch
    # echo "CONFIG_DEBUG_SECTION_MISMATCH=y" >> $MAIN_DEFCONFIG
}

# Add KernelSU function
add_ksu() {
    if [ -n "$KSU_SETUP_URI" ]; then
        echo "Setting up KernelSU..."
        # Apply umount backport and kpatch fixes
        # disable for now, its already on the sources
        # wget -qO- $KSU_UMOUNT_PATCH | patch -s -p1
        if [[ "$KSU_SETUP_URI" == *"backslashxx/KernelSU"* ]]; then
            # Apply manual hook
            # disable for now, we're gonna use hookless mode
            # wget -qO- $KSU_GENERAL_PATCH | patch -s -p1
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" >> $MAIN_DEFCONFIG
        elif [[ "$KSU_SETUP_URI" == *"KernelSU-Next/KernelSU-Next"* ]]; then
            # Apply manual hook
            # disable for now, we're gonna use kprobes mode
            # wget -qO- $KSU_GENERAL_PATCH | patch -s -p1
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "KSU_KPROBES_HOOK=y" >> $MAIN_DEFCONFIG
        fi
    else
        echo "No KernelSU to set up."
    fi
}


# Compile kernel function
compile_kernel() {
    # Merge defconfig
    mkdir -p out
    make O=out ARCH=arm64 $ACTUAL_MAIN_DEFCONFIG
    echo "Appending fragments to .config..."
    for fragment in $COMMON_DEFCONFIG $DEVICE_DEFCONFIG $FEATURE_DEFCONFIG; do
        if [ -f "arch/arm64/configs/$fragment" ]; then
            echo "Merging $fragment..."
            cat "arch/arm64/configs/$fragment" >> out/.config
        else
            echo "Warning: Fragment arch/arm64/configs/$fragment not found!"
        fi
    done
    yes "" | make O=out ARCH=arm64 olddefconfig
    # Do a git cleanup before compiling
    echo "Cleaning up git before compiling..."
    git config user.email $GIT_EMAIL
    git config user.name $GIT_NAME
    git config set advice.addEmbeddedRepo true
    git add .
    git commit -m "cleanup: applied patches before build" &> /dev/null
    # Start compilation
    echo "Starting kernel compilation..."
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
        CLANG_TRIPLE=aarch64-linux-gnu- 
}

# Main function
main() {
    # Check if all four arguments are valid
    echo "Validating input arguments..."
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <DEVICE_IMPORT> <KERNELSU_SELECTOR>"
        echo "Example: $0 mi89x7 --ksu=KSU_BLXX"
        exit 1
    fi
    setup_environment "$1" "$2"
    setup_toolchain
    add_patches
    add_ksu
    compile_kernel
}

# Run the main function
main "$1" "$2"