#!/bin/bash
#
# Compile script for Sashimi Kernel.
# Adapted from Sushi to Sashimi.
# Copyright (C) 2024 Akari.

SECONDS=0
CLANG_VERSION="clang-22.0.2"
TC_DIR="$HOME/tc/$CLANG_VERSION"
PATH=$HOME/tc/$CLANG_VERSION/bin:$PATH

export ARCH=arm64
export KBUILD_BUILD_USER=Sashimi
export KBUILD_BUILD_HOST=Kernel
export LLVM_DIR=$HOME/tc/$CLANG_VERSION/bin
export LLVM=1

AK3_DIR="$HOME/AnyKernel3"
VARIANTS=("bangkk")
DEFCONFIGS=("vendor/bangkk_defconfig")
ZIPNAME_PREFIX="Sushi-$(date '+%Y%m%d-%H%M')"
LOG_FILE="moe.log"
: > "$LOG_FILE"

if [[ $# -ne 2 || $1 != "-v" || ! " ${VARIANTS[@]} " =~ " $2 " ]]; then
    echo "Use: $0 -v {bangkk}" | tee -a "$LOG_FILE"
    exit 1
fi

VARIANT="$2"
DEFCONFIG="${DEFCONFIGS[0]}"

if ! [ -f "${LLVM_DIR}/clang" ]; then
    echo "Clang not found! Downloading LLVM 22.1.0 from GitHub Releases..." | tee -a "$LOG_FILE"
    mkdir -p "${TC_DIR}"

    if ! curl -fSL "https://github.com/Samw662/aosp-clang-toolchains/releases/download/clang-22/clang-r596125.tar.gz" \
         | tar -xJ -C "${TC_DIR}" --strip-components=1 >> "$LOG_FILE" 2>&1; then
        echo "Download failed! Aborting..." | tee -a "$LOG_FILE"
        exit 1
    fi
    echo "Clang setup completed successfully!" | tee -a "$LOG_FILE"
fi

echo -e "\nCompiler info:" | tee -a "$LOG_FILE"
"${LLVM_DIR}/clang" --version | head -n 1 | tee -a "$LOG_FILE"
"${LLVM_DIR}/ld.lld" --version | head -n 1 | tee -a "$LOG_FILE"

echo -e "\nCompiling for $DEFCONFIG with variant $VARIANT..." | tee -a "$LOG_FILE"

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG | tee -a "$LOG_FILE"

ARGS="
CC=clang
LD=${LLVM_DIR}/ld.lld
ARCH=arm64
AR=${LLVM_DIR}/llvm-ar
NM=${LLVM_DIR}/llvm-nm
AS=${LLVM_DIR}/llvm-as
OBJCOPY=${LLVM_DIR}/llvm-objcopy
OBJDUMP=${LLVM_DIR}/llvm-objdump
READELF=${LLVM_DIR}/llvm-readelf
OBJSIZE=${LLVM_DIR}/llvm-size
STRIP=${LLVM_DIR}/llvm-strip
LLVM_AR=${LLVM_DIR}/llvm-ar
LLVM_DIS=${LLVM_DIR}/llvm-dis
LLVM_NM=${LLVM_DIR}/llvm-nm
LLVM=1
KCFLAGS=-Wno-implicit-enum-enum-cast
"

make ${ARGS} O=out $DEFCONFIG moto.config | tee -a "$LOG_FILE"
make ${ARGS} O=out -j$(nproc) | tee -a "$LOG_FILE"

if [ ! -e "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Image binary not found. Compilation failed!" | tee -a "$LOG_FILE"
    exit 1
fi

echo -e "\nKernel compiled successfully for $DEFCONFIG! Zipping up...\n" | tee -a "$LOG_FILE"

if [ -d "$AK3_DIR" ]; then
    cp -r $AK3_DIR AnyKernel3
    git -C AnyKernel3 checkout bangkk &> /dev/null
else
    git clone -q https://github.com/MrEliteBall/AnyKernel3 -b bangkk
fi

cp out/.config AnyKernel3/config
cp out/arch/arm64/boot/Image AnyKernel3/Image
[ -f out/arch/arm64/boot/dtb.img ] && cp out/arch/arm64/boot/dtb.img AnyKernel3/dtb
[ -f out/arch/arm64/boot/dtbo.img ] && cp out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img

ZIPNAME="${ZIPNAME_PREFIX}-${VARIANT}.zip"

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder | tee -a "../$LOG_FILE"
cd ..

echo -e "\nCompleted compilation for $DEFCONFIG (variant $VARIANT) in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!" | tee -a "$LOG_FILE"
echo "Zip: $ZIPNAME" | tee -a "$LOG_FILE"

[ -f ./go-up ] || (wget https://raw.githubusercontent.com/GustavoMends/go-up/master/go-up && chmod +x go-up)
./go-up "$ZIPNAME"

rm -rf AnyKernel3
