#!/data/data/com.termux/files/usr/bin/bash

TARGET_HOST="192.168.43.217"     #目标主机
TARGET_PORT="3257"     #目标端口
POLL_INTERVAL=3     #轮询间隔（秒）
SEEN_IDS_FILE="$(dirname "$0")/termux_notify_seen.txt"     #去重记录文件（当前目录）
#####
touch "$SEEN_IDS_FILE"
echo "Start monitoring notifications, forward via UDP to $TARGET_HOST:$TARGET_PORT"

while true; do
#获取当前所有通知
    notif_json=$(termux-notification-list 2>/dev/null)
#如果获取失败或为空,等待后继续
    [ -z "$notif_json" ] && sleep "$POLL_INTERVAL" && continue
    echo "$notif_json" | jq -c '.[]' 2>/dev/null | while read -r item; do
#提取字段
        key=$(echo "$item" | jq -r '.key // empty')
        title=$(echo "$item" | jq -r '.title // empty')
        content=$(echo "$item" | jq -r '.content // empty')
        [ -z "$key" ] && continue
        [ -z "$title" ] && [ -z "$content" ] && continue
#去重检查
        grep -qxF "$key" "$SEEN_IDS_FILE" 2>/dev/null && continue
#记录已处理的key
        echo "$key" >> "$SEEN_IDS_FILE"
        echo "$item" | nc -u "$TARGET_HOST" "$TARGET_PORT" &
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] UDP 转发: $key"
    done
    sleep "$POLL_INTERVAL"
done
