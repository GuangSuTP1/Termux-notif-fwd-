#!/data/data/com.termux/files/usr/bin/bash

PORT=3257      #监听的UDP端口
######
echo "listening on UDP port $PORT"
#使用ncat持续接收UDP数据报
#每收到一行(以换行符分隔)就处理一次
ncat -u -l -p "$PORT" -k | while IFS= read -r line; do
#原始数据输出
    echo "[RAW] $line"
#提取title和content（分开赋值，避免read吃掉第二行）
    title=$(echo "$line" | jq -r '.title // empty' 2>/dev/null)
    content=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
    echo "[PARSED] title='$title', content='$content'"
#如果title或content非空,则弹出系统通知
    if [ -n "$title" ] || [ -n "$content" ]; then
        termux-notification -t "转发: ${title:-无标题}" -c "内容: ${content:-无内容}"
        echo "[NOTIFICATION] Sent"
    else
        echo "[IGNORED] No title/content"
    fi
done
