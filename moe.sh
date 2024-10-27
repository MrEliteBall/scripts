#!/bin/bash
#
# Compile script for MoeKernel
# Copyright (C) 2024 Shoiya A.

SECONDS=0
CLANG_VERSION="clang-17.0.0"
TC_DIR="$HOME/tc/$CLANG_VERSION"
PATH=$HOME/tc/$CLANG_VERSION/bin:$PATH
export ARCH=arm64
export KBUILD_BUILD_USER=Moe
export KBUILD_BUILD_HOST=Nyan
export LLVM_DIR=$HOME/tc/$CLANG_VERSION/bin
export LLVM=1

AK3_DIR="$HOME/AnyKernel3"
VARIANTS=("fts" "gdx")
DEFCONFIGS=("vendor/bangkk_fts_defconfig" "vendor/bangkk_gdx_defconfig")
ZIPNAME_PREFIX="MoeKernel-$(date '+%Y%m%d-%H%M')"

if [[ $# -ne 2 || $1 != "--variant" || ! " ${VARIANTS[@]} " =~ " $2 " ]]; then
    echo "Uso: $0 --variant {fts|gdx}"
    exit 1
fi

# Determina a variante e o defconfig correspondente
VARIANT="$2"
if [[ "$VARIANT" == "fts" ]]; then
    DEFCONFIG="${DEFCONFIGS[0]}"
elif [[ "$VARIANT" == "gdx" ]]; then
    DEFCONFIG="${DEFCONFIGS[1]}"
fi

if ! [ -d "${TC_DIR}" ]; then
    echo "Clang not found! Cloning to ${TC_DIR}..."
    if ! git clone --depth=1 https://gitlab.com/moehacker/clang-r487747.git ${TC_DIR}; then
        echo "Cloning failed! Aborting..."
        exit 1
    fi
fi

echo -e "\nCompiling for $DEFCONFIG with variant $VARIANT..."

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

ARGS='
CC=clang
LD='${LLVM_DIR}/ld.lld'
ARCH=arm64
AR='${LLVM_DIR}/llvm-ar'
NM='${LLVM_DIR}/llvm-nm'
AS='${LLVM_DIR}/llvm-as'
OBJCOPY='${LLVM_DIR}/llvm-objcopy'
OBJDUMP='${LLVM_DIR}/llvm-objdump'
READELF='${LLVM_DIR}/llvm-readelf'
OBJSIZE='${LLVM_DIR}/llvm-size'
STRIP='${LLVM_DIR}/llvm-strip'
LLVM_AR='${LLVM_DIR}/llvm-ar'
LLVM_DIS='${LLVM_DIR}/llvm-dis'
LLVM_NM='${LLVM_DIR}/llvm-nm'
LLVM=1
'

make ${ARGS} O=out -j$(nproc)

if [ ! -e "out/arch/arm64/boot/Image" ]; then
    echo "ERROR: Image binary not found. Compilation failed!"
    exit 1
fi

echo -e "\nKernel compiled successfully for $DEFCONFIG! Zipping up...\n"

if [ -d "$AK3_DIR" ]; then
    cp -r $AK3_DIR AnyKernel3
    git -C AnyKernel3 checkout bangkk &> /dev/null
else
    git clone -q https://github.com/MoeKernel/AnyKernel3 -b inline
fi

cp out/.config AnyKernel3/config
cp out/arch/arm64/boot/Image AnyKernel3/Image
cp out/arch/arm64/boot/dtb.img AnyKernel3/dtb
cp out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img

ZIPNAME="${ZIPNAME_PREFIX}-${VARIANT}.zip"
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
cd ..

echo -e "\nCompleted compilation for $DEFCONFIG (variant $VARIANT) in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
echo "Zip: $ZIPNAME"
rm -rf AnyKernel3

echo -e "\nAll compilations finished!"
