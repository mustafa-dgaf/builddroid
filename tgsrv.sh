#!/bin/bash
# Telegram bot script.
# Part of BuildDroid.
# https://github.com/wojtekojtek/builddroid

source config.ini || { echo "Error occurred while parsing config.ini"; exit 1; }
tg_user_id=$user_id
RED='\033[0;31m'
NC='\033[0m'
if [ -e pid1 ]; then
    echo $$ > pid3
else
    echo "Run builddroid first!"
    exit 1
fi
API_URL="https://api.telegram.org/bot$telegramtoken"
if [[ ! $telegramtoken =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Warning: Token format looks incorrect${NC}"
    kill -15 "$(cat pid2)" 2>/dev/null
    kill -15 "$(cat pid1)" 2>/dev/null
    exit_safe
fi
STARTED_TIME=$(date +%s)
TIMEOUT=30
BOT_INFO=$(curl -s -X GET "$API_URL/getMe")
BOT_USERNAME=$(echo "$BOT_INFO" | jq -r '.result.username // empty')
if [ -z "$BOT_USERNAME" ]; then
    # BOT_USERNAME="*"
    exit 1
else
    echo "Starting..."
fi

exit_safe() {
    echo -e "\nStopping..."
    exit 0
}

trap exit_safe SIGINT SIGTERM

send_message() {
    local chat_id=$1
    local text=$2
    local reply_to_message_id=$3
    local reply_param=""
    if [ -n "$reply_to_message_id" ]; then
        reply_param="\"reply_to_message_id\": $reply_to_message_id,"
    fi
    curl -s -X POST "$API_URL/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": $chat_id,
            $reply_param
            \"text\": \"$text\",
            \"parse_mode\": \"Markdown\"
        }" > /dev/null
}

log_command() {
    local command=$1
    local user_id=$2
    local username=$3
    local first_name=$4
    # echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] Command: /$command executed by User ID: $user_id, Username: $username, Name: $first_name${NC}"
    # echo "[$(date '+%Y-%m-%d %H:%M:%S')] /$command - User ID: $user_id, Username: $username, Name: $first_name" >> command_logs.txt
}

declare -A pending_confirmations
declare -A confirmation_timestamps
declare -A confirmation_types
declare -A confirmation_data
CONFIRMATION_EXPIRY=30

create_confirmation() {
    local user_id=$1
    local confirmation_type=$2
    local data=$3
    local current_time=$(date +%s)
    pending_confirmations[$user_id]=1
    confirmation_timestamps[$user_id]=$current_time
    confirmation_types[$user_id]=$confirmation_type
    confirmation_data[$user_id]=$data
    return 0
}

check_confirmation() {
    local user_id=$1
    local current_time=$(date +%s)
    if [ -z "${pending_confirmations[$user_id]}" ]; then
        return 1
    fi
    local timestamp=${confirmation_timestamps[$user_id]}
    if (( current_time - timestamp > CONFIRMATION_EXPIRY )); then
        clear_confirmation "$user_id"
        return 2
    fi
    return 0
}

clear_confirmation() {
    local user_id=$1
    
    unset pending_confirmations[$user_id]
    unset confirmation_timestamps[$user_id]
    unset confirmation_types[$user_id]
    unset confirmation_data[$user_id]
}

cleanup_expired_confirmations() {
    local current_time=$(date +%s)
    for user_id in "${!pending_confirmations[@]}"; do
        local timestamp=${confirmation_timestamps[$user_id]}
        if (( current_time - timestamp > CONFIRMATION_EXPIRY )); then
            clear_confirmation "$user_id"
        fi
    done
}

handle_start() {
    local chat_id=$1
    local message_id=$2
    local first_name=$3
    local user_id=$4
    local username=$5
    log_command "start" "$user_id" "$username" "$first_name"
    send_message "$chat_id" "Hello, $first_name! I'm a simple Telegram bot." "$message_id"
}

handle_accept() {
    local chat_id=$1
    local message_id=$2
    local first_name=$3
    local user_id=$4
    local username=$5
    log_command "accept" "$user_id" "$username" "$first_name"
    if check_confirmation "$user_id"; then
        local confirmation_type=${confirmation_types[$user_id]}
        local data=${confirmation_data[$user_id]}
        clear_confirmation "$user_id"
        case "$confirmation_type" in
            "kill")
                if [ -e pid1 ]; then
                    local pid=$(cat pid1)
                    if kill -15 "$pid" 2>/dev/null; then
                        send_message "$chat_id" "Successfully sent SIGTERM to process $pid (builddroid)" "$message_id"
                    else
                        send_message "$chat_id" "Failed to terminate process $pid (builddroid)" "$message_id"
                    fi
                fi
                if [ -e pid2 ]; then
                    local pid=$(cat pid2)
                    if kill -15 "$pid" 2>/dev/null; then
                        send_message "$chat_id" "Successfully sent SIGTERM to process $pid (status service)" "$message_id"
                    else
                        send_message "$chat_id" "Failed to terminate process $pid (status service)" "$message_id"
                    fi
                fi
                send_message "$chat_id" "Terminating... goodbye" "$message_id"
                exit_safe
                ;;
            *)
                send_message "$chat_id" "Unknown confirmation type. Operation canceled." "$message_id"
                ;;
        esac
    else
        local status=$?
        if [ $status -eq 1 ]; then
            send_message "$chat_id" "There is no pending action to accept." "$message_id"
        elif [ $status -eq 2 ]; then
            send_message "$chat_id" "Your previous confirmation request has expired. Please try again." "$message_id"
        fi
    fi
}

handle_cancel() {
    local chat_id=$1
    local message_id=$2
    local first_name=$3
    local user_id=$4
    local username=$5
    log_command "cancel" "$user_id" "$username" "$first_name"
    if check_confirmation "$user_id"; then
        local confirmation_type=${confirmation_types[$user_id]}
        clear_confirmation "$user_id"
        case "$confirmation_type" in
            "kill")
                send_message "$chat_id" "Kill operation has been canceled." "$message_id"
                ;;
            *)
                send_message "$chat_id" "Operation has been canceled." "$message_id"
                ;;
        esac
    else
        local status=$?
        if [ $status -eq 1 ]; then
            send_message "$chat_id" "There is no pending action to cancel." "$message_id"
        elif [ $status -eq 2 ]; then
            send_message "$chat_id" "Your previous confirmation request has already expired." "$message_id"
        fi
    fi
}

handle_status() {
    local chat_id=$1
    local message_id=$2
    local first_name=$3
    local user_id=$4
    local username=$5
    local file="status"
    log_command "status" "$user_id" "$username" "$first_name"
    if [ -e "$file" ]; then
        if [ ! -s "$file" ]; then
            send_message "$chat_id" "Status file is empty." "$message_id"
        else
            if [[ $(grep -o '[^[:space:]]' "$file" | wc -l) -eq 0 ]]; then
                send_message "$chat_id" "The file has nothing but spaces." "$message_id"
            else
                send_message "$chat_id" "$(cat "$file")" "$message_id"
            fi
        fi
    else
        send_message "$chat_id" "The file does not exist." "$message_id"
    fi
}

handle_kill() {
    local chat_id=$1
    local message_id=$2
    local first_name=$3
    local user_id=$4
    local username=$5
    log_command "kill" "$user_id" "$username" "$first_name"
    if [ -e "pid1" ] && [ -e "pid2" ] && kill -0 $(cat pid1) 2>/dev/null && kill -0 $(cat pid2) 2>/dev/null; then
        if [ "$user_id" == "$tg_user_id" ]; then
            create_confirmation "$user_id" "kill" ""
            send_message "$chat_id" "⚠️ \*Warning:\* You're about to kill the build task.\n\nAre you sure you still want to kill the build task?\n\nPlease confirm this action by sending:\n\n/accept - To proceed with killing the bot\n/cancel - To cancel this action\n\n\_This confirmation will expire in $CONFIRMATION_EXPIRY seconds.\_" "$message_id"
        else
            send_message "$chat_id" "You don't have access to this command." "$message_id"
        fi
    elif [ -e pid1 ] && kill -0 $(cat pid1) 2>/dev/null; then
        if [ "$user_id" == "$tg_user_id" ]; then
            create_confirmation "$user_id" "kill" ""
            send_message "$chat_id" "⚠️ \*Warning:\* You're about to kill the build task.\n\n\*Cannot find the status update service. Is it running?\*\n\nAre you sure you still want to kill the build task?\n\nPlease confirm this action by sending:\n\n/accept - To proceed with killing the bot\n/cancel - To cancel this action\n\n\_This confirmation will expire in $CONFIRMATION_EXPIRY seconds.\_" "$message_id"
        else
            send_message "$chat_id" "You don't have access to this command." "$message_id"
        fi
    elif [ -e pid2 ] && kill -0 $(cat pid2) 2>/dev/null; then
        if [ "$user_id" == "$tg_user_id" ]; then
            create_confirmation "$user_id" "kill" ""
            send_message "$chat_id" "⚠️ \*Warning:\* You're about to kill the build task.\n\n\*Cannot find the builddroid process. Is it running?\*\n\nAre you sure you still want to kill the build task?\n\nPlease confirm this action by sending:\n\n/accept - To proceed with killing the bot\n/cancel - To cancel this action\n\n\_This confirmation will expire in $CONFIRMATION_EXPIRY seconds.\_" "$message_id"
        else
            send_message "$chat_id" "You don't have access to this command." "$message_id"
        fi
    else
        if [ "$user_id" == "$tg_user_id" ]; then
            create_confirmation "$user_id" "kill" ""
            send_message "$chat_id" "⚠️ \*Warning:\* You're about to kill the build task.\n\n\*Cannot find the builddroid process and status service. Are you running this bot separately?\*\n\nAre you sure you still want to kill the build task?\n\nPlease confirm this action by sending:\n\n/accept - To proceed with killing the bot\n/cancel - To cancel this action\n\n\_This confirmation will expire in $CONFIRMATION_EXPIRY seconds.\_" "$message_id"
        else
            send_message "$chat_id" "You don't have access to this command." "$message_id"
        fi
    fi
}

declare -A rate_limit_timestamps

check_rate_limit() {
    local user_id=$1
    local username=$2
    local current_time=$(date +%s)
    local max_requests=5
    local time_window=120
    if [ "$user_id" == "$tg_user_id" ]; then
        return 0
    fi
    if [ -z "${rate_limit_timestamps[$user_id]}" ]; then
        rate_limit_timestamps[$user_id]="$current_time"
        return 0
    fi
    local timestamps=(${rate_limit_timestamps[$user_id]})
    local new_timestamps=()
    for ts in "${timestamps[@]}"; do
        if (( current_time - ts < time_window )); then
            new_timestamps+=("$ts")
        fi
    done
    new_timestamps+=("$current_time")
    rate_limit_timestamps[$user_id]="${new_timestamps[*]}"
    if (( ${#new_timestamps[@]} > max_requests )); then
        return 1
    else
        return 0
    fi
}

process_update() {
    local update="$1"
    local message_id=$(echo "$update" | jq -r '.message.message_id // empty')
    local chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
    local text=$(echo "$update" | jq -r '.message.text // empty')
    local date=$(echo "$update" | jq -r '.message.date // empty')
    local user_id=$(echo "$update" | jq -r '.message.from.id // "unknown"')
    local username=$(echo "$update" | jq -r '.message.from.username // "unknown"')
    local first_name=$(echo "$update" | jq -r '.message.from.first_name // "unknown"')
    if [ -z "$message_id" ] || [ -z "$chat_id" ] || [ -z "$text" ] || [ -z "$date" ]; then
        return
    fi
    if [ "$date" -lt "$STARTED_TIME" ]; then
        return
    fi
    if [[ "$text" == "/"* ]]; then
        local full_command=$(echo "$text" | cut -d' ' -f1)
        local command=$(echo "$full_command" | cut -d'@' -f1 | sed 's/\///')
        local target=$(echo "$full_command" | grep -o '@.*' | sed 's/@//')
        if [ -z "$target" ] || [ "$target" == "$BOT_USERNAME" ] || [ "$BOT_USERNAME" == "*" ]; then
            if check_rate_limit "$user_id" "$username"; then
                if type "handle_$command" &>/dev/null; then
                    "handle_$command" "$chat_id" "$message_id" "$first_name" "$user_id" "$username"
                fi
            else
                send_message "$chat_id" "⚠️ Whoa, too fast. Rate limit exceeded." "$message_id"
            fi
        fi
    fi
}

OFFSET=0
LAST_CLEANUP_TIME=$(date +%s)
CLEANUP_INTERVAL=60
while true; do
    UPDATES=$(curl -s -X GET "$API_URL/getUpdates?offset=$OFFSET&timeout=$TIMEOUT")
    CURRENT_TIME=$(date +%s)
    if (( CURRENT_TIME - LAST_CLEANUP_TIME > CLEANUP_INTERVAL )); then
        cleanup_expired_confirmations
        LAST_CLEANUP_TIME=$CURRENT_TIME
    fi
    ERROR_CODE=$(echo "$UPDATES" | jq -r '.error_code // empty')
    if [ -n "$ERROR_CODE" ]; then
        sleep 5
        continue
    fi
    UPDATES_COUNT=$(echo "$UPDATES" | jq '.result | length')
    if [ "$UPDATES_COUNT" -gt 0 ]; then
        for i in $(seq 0 $(($UPDATES_COUNT - 1))); do
            UPDATE=$(echo "$UPDATES" | jq -c ".result[$i]")
            UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
            process_update "$UPDATE"
            OFFSET=$((UPDATE_ID + 1))
        done
    fi
done
