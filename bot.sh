#!/bin/bash

if [[ -f ".env" ]]; then
    source .env
fi

export BOT_TOKEN="${BOT_TOKEN:-}"
export CHAT_ID="${CHAT_ID:-}"
export MESSAGE_THREAD_ID="${MESSAGE_THREAD_ID:-}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "Error: BOT_TOKEN or CHAT_ID not set."
    exit 1
fi

commit_id=$(git log --oneline -1 --pretty=format:'%h')
commit_text=$(git log --oneline -1 | cut -d ' ' -f 2-)

start_time=$(date +%s)

./sashimi.sh -v bangkk

if [[ $? -eq 0 ]]; then
    end_time=$(date +%s)
    elapsed_time=$((end_time - start_time))
    elapsed_minutes=$((elapsed_time / 60))
    elapsed_seconds=$((elapsed_time % 60))

    orig_zip=$(ls *.zip 2>/dev/null | head -n 1)
    if [[ -n "$orig_zip" ]]; then
        new_zip="sashimi-$(date +%Y%m%d-%H%M)-bangkk.zip"
        if [[ "$orig_zip" != "$new_zip" ]]; then
            mv "$orig_zip" "$new_zip"
        fi
        zip_file="$new_zip"

        caption="🍣 Sashimi Kernel (bangkk)
• Commit: ${commit_id}
• Message: ${commit_text}
• Duration: ${elapsed_minutes}m ${elapsed_seconds}s"

        curl -s -F chat_id="$CHAT_ID" \
            -F document=@"$zip_file" \
            ${MESSAGE_THREAD_ID:+-F message_thread_id="$MESSAGE_THREAD_ID"} \
            -F caption="$caption" \
            "https://api.telegram.org/bot$BOT_TOKEN/sendDocument"
    fi

    exit 0
else
    exit 1
fi
