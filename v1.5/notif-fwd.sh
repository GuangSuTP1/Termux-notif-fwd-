#!/data/data/com.termux/files/usr/bin/bash

WAIT=3     #轮询间隔秒Poll interval in seconds
TARGET_PORT="3257"     #目标端口.Target port, default
MODE=""                #运行模式:监听/发送 Run mode: listen / send
TARGET_HOST=""         #手动指定的接收端IP Manually specified receiver IP
SEEN_IDS_LIST=""     #去重记录(Deduplication record)
LOG_PATH=""     #日志保存路径(Log save path)

usage() {
    echo "用法 Usage: notif-fwd -l | -s [-p PORT] [-i IP] [-w WAIT] [-L FILE]"
    echo "  -l    监听模式 Listen mode: 广播本机IP，接收通知并弹窗 broadcast local IP, receive notifications and show popup"
    echo "  -s    发送模式 Send mode: 采集通知并转发到接收端 collect notifications and forward to receiver"
    echo "  -p    指定UDP端口 Specify UDP port (默认 default 3257)"
    echo "  -i    手动指定接收端IP Manually specify receiver IP (仅发送模式有效 only for -s)"
    echo "  -w    每轮循环的间隔(默认3秒) The interval of each loop cycle (default 3 seconds)"
    echo "  -L    保存日志 Save log"
    echo "  -h    显示此帮助 Show this help"
    exit 1
}

#支持 --help
[ "$1" = "--help" ] && usage

#参数解析 (Parse arguments)  使用 getopts 支持组合短选项
OPTERR=0   #禁止 getopts 自动报错
while getopts "lsp:i:w:L:h" opt; do
    case "$opt" in
        l) MODE="listen" ;;
        s) MODE="send" ;;
        p) TARGET_PORT="$OPTARG" ;;
        i) TARGET_HOST="$OPTARG" ;;
        w) WAIT="$OPTARG" ;;
        L) LOG_PATH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;   #任何不识别的选项或缺少参数都触发用法
    esac
done
shift $((OPTIND-1))

#有剩余非选项参数则报错
[ $# -ne 0 ] && usage

#未指定模式时显示用法(Show usage if no mode specified)
[ -z "$MODE" ] && usage

if [ -n "$LOG_PATH" ]; then
    mkdir -p "$LOG_PATH"     #确保目录存在
    LOG_PATH="$LOG_PATH/notif-fwd.log"     #拼接文件名
    touch "$LOG_PATH"     #创建日志文件
fi


#根据模式执行(Execute according to mode)
case "$MODE" in
    listen)
#####监听模式(Listen Mode)#####
        if [ -n "$LOG_PATH" ]; then
            exec > >(tee -a "$LOG_PATH") 2>&1
        fi
        HOST_IP=$(echo -n $(ifconfig 2>/dev/null | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}') | xxd -p)
        if [ -n "$LOG_PATH" ]; then
            echo "180ED473B1DC4062A3E586011EB76166 ${HOST_IP}" | tee >(sed "s/^/[$(date '+%Y-%m-%d %H:%M:%S')] /" >> "$LOG_PATH") | xxd -r -p | nc -ubw 0 255.255.255.255 $TARGET_PORT
        else
            echo "180ED473B1DC4062A3E586011EB76166 ${HOST_IP}" | xxd -r -p | nc -ubw 0 255.255.255.255 $TARGET_PORT
        fi
        echo "正在监听UDP端口 $TARGET_PORT (Listening on UDP port $TARGET_PORT)"
        ncat -ulkp "$TARGET_PORT" | while IFS= read -r line; do
            echo "[原始数据 RAW] $line"
            title=$(echo "$line" | jq -r '.title // empty' 2>/dev/null)
            content=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
            echo "[解析后 PARSED] title='$title', content='$content'"
            if [ -n "$title" ] || [ -n "$content" ]; then
                termux-notification -t "转发(Forward): ${title:-无标题(No Title)}" -c "内容(Content): ${content:-无内容(No Content)}"
                echo "[通知已发送 NOTIFICATION] Sent"
            else
                echo "[已忽略 IGNORED] 无标题或内容(No title/content)"
            fi
        done
        ;;

    send)
#####发送模式(Send Mode)#####

#确定接收端IP(Determine receiver IP)
        if [ -n "$LOG_PATH" ]; then
            exec > >(tee -a "$LOG_PATH") 2>&1
        fi

        if [ -n "$TARGET_HOST" ]; then
            echo "已手动指定接收端IP Manually specified receiver IP: $TARGET_HOST"
        else
#####自动获取接收端(Auto-Obtain Receiver IP)#####
            echo "正在自动获取接收端IP Auto-obtaining receiver IP, port: $TARGET_PORT"
            TARGET_HOST=$(
              timeout 15 nc -u -l -w 1 $TARGET_PORT | {
                read raw
                magic_bin=$(printf "%s" "$raw" | head -c 16)
                ip_part=$(printf "%s" "$raw" | tail -c +17)
                magic_hex=$(printf "%s" "$magic_bin" | xxd -p | tr -d '\n' | tr 'A-F' 'a-f')
                if [ "$magic_hex" = "180ed473b1dc4062a3e586011eb76166" ]; then
                  printf "%s" "$ip_part"
                fi
              }
            )
            if [ -n "$TARGET_HOST" ]; then
                echo "已获取到接收端IP Obtained receiver IP: $TARGET_HOST"
            else
                TARGET_HOST="255.255.255.255"
                echo "未获取到接收端IP,已自动设置为广播IP No receiver IP obtained, auto-set to broadcast IP (255.255.255.255)"
            fi
        fi

        echo "开始监控通知，通过UDP转发到 Start monitoring notifications, forward via UDP to $TARGET_HOST:$TARGET_PORT"

        while true; do
#获取当前所有通知(Get all current notifications)
            if [ -n "$LOG_PATH" ]; then
                notif_json=$(termux-notification-list 2>/dev/null | tee >(sed "s/^/[$(date '+%Y-%m-%d %H:%M:%S')] GET: /" >> "$LOG_PATH"))
            else
                notif_json=$(termux-notification-list 2>/dev/null)
            fi
#如果获取失败或为空,等待后继续(If failed or empty, wait and continue)
            [ -z "$notif_json" ] && sleep "$WAIT" && continue
            while read -r item; do
#提取字段(Extract fields)
                key=$(echo "$item" | jq -r '.key // empty')
                title=$(echo "$item" | jq -r '.title // empty')
                content=$(echo "$item" | jq -r '.content // empty')
                [ -z "$key" ] && continue
                [ -z "$title" ] && [ -z "$content" ] && continue
#去重检查(Deduplication check)
                echo "$SEEN_IDS_LIST" | grep -qxF "$key" && continue
#记录已处理的key(Record processed key)
                SEEN_IDS_LIST+="$key"$'\n'
#发送数据(Send data)
                echo "$item" | nc -bu "$TARGET_HOST" "$TARGET_PORT" &
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] UDP 转发(Forward): $key"
            done < <(echo "$notif_json" | jq -c '.[]' 2>/dev/null)
            sleep "$WAIT"
        done
        ;;
esac
