#!/bin/bash

BASE_CONFIG="vendor/bangkk_gdx_defconfig"
FRAGMENT_CONFIG="vendor/bangkk_fts_defconfig"
OUTPUT_CONFIG="arch/arm64/configs/bangkk_merged_defconfig"

echo "Merging $BASE_CONFIG and $FRAGMENT_CONFIG..."
scripts/kconfig/merge_config.sh $BASE_CONFIG $FRAGMENT_CONFIG

echo "Generating new defconfig..."
make ARCH=arm64 savedefconfig

echo "Saving new defconfig as $OUTPUT_CONFIG..."
mv defconfig $OUTPUT_CONFIG

echo "Uploading $OUTPUT_CONFIG to temp.sh..."
UPLOAD_URL=$(curl -s -F "file=@$OUTPUT_CONFIG" https://temp.sh/upload)

if [[ $? -eq 0 ]]; then
    echo "Upload successful! File available at: $UPLOAD_URL"
else
    echo "Upload failed."
    exit 1
fi
