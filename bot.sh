#!/bin/bash

if [[ -f ".env" ]]; then
    source .env
fi

export BOT_TOKEN="${BOT_TOKEN:-}"
export CHAT_ID="${CHAT_ID:-}"
export MY_ID="${MY_ID:-$CHAT_ID}"
export CHANNEL_ID="${CHANNEL_ID:-@SashimiKernelCI}"
export MESSAGE_THREAD_ID="${MESSAGE_THREAD_ID:-}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "Error: BOT_TOKEN or CHAT_ID not set."
    exit 1
fi

if [[ -f "build_count.txt" ]]; then
    build_count=$(cat build_count.txt)
else
    build_count=0
fi
build_count=$((build_count + 1))
echo $build_count > build_count.txt

commit_head=$(git log --oneline -1 --pretty=format:'%h - %an')
commit_id=$(git log --oneline -1 --pretty=format:'%h')
author_name=$(echo "$commit_head" | cut -d ' ' -f 3-)
commit_hash=$(echo "$commit_head" | cut -d ' ' -f 1)
commit_text=$(git log --oneline -1 | cut -d ' ' -f 2-)

kernel_version=$(make kernelversion 2>/dev/null || echo "5.4.x")
build_type="Release"
tag="bangkk_${commit_hash:0:7}_$(date +%Y%m%d)"

start_message=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
    -d chat_id="$MY_ID" \
    -d text="🍣 *Sashimi Kernel compilation started...*" \
    -d parse_mode="Markdown")

start_time=$(date +%s)

./sashimi.sh -v bangkk

if [[ $? -eq 0 ]]; then
    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    elapsed_minutes=$((elapsed_time / 60))
    elapsed_seconds=$((elapsed_time % 60))

    commit_link="[${commit_text}](https://github.com/MrEliteBall/android_kernel_motorola_bangkk/commit/${commit_hash})"

    build_info=$(cat <<EOF
🍣 *Sashimi Kernel | bangkk (#${build_count})*
*Status*: Success!
*Version*: ${kernel_version}
*Commit*: ${commit_link}
*Author*: \`${author_name}\`
*Duration*: ${elapsed_minutes}m ${elapsed_seconds}s

#bangkk #SashimiKernel
EOF
)

    zip_file=$(ls *.zip | head -n 1)
    if [[ -n "$zip_file" ]]; then
        caption=$(cat <<EOF
🍣 *Sashimi Kernel (bangkk)*
• *Commit*: \`${commit_id}\`
• *Message*: \`${commit_text}\`
• *Duration*: ${elapsed_minutes}m ${elapsed_seconds}s
EOF
)
        curl -s -F chat_id="$CHAT_ID" \
            -F document=@"$zip_file" \
            ${MESSAGE_THREAD_ID:+-F message_thread_id="$MESSAGE_THREAD_ID"} \
            -F caption="$caption" \
            -F parse_mode="Markdown" \
            "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
    fi

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHANNEL_ID" \
        -d text="$build_info" \
        -d parse_mode="Markdown"

    exit 0
else
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$MY_ID" \
        -d text="❌ *Compilation failed!*" \
        -d parse_mode="Markdown"
    exit 1
fi
