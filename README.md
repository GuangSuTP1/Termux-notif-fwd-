notif-fwd - 跨设备通知转发
一个基于termux的局域网通知转发脚本

将手机A的通知自动转发到手机B，纯局域网UDP通信，无需云服务。

快速开始

接收端（B手机）

```bash
./notif-fwd.sh -l
```

发送端（A手机）

```bash
./notif-fwd.sh -s
```

参数

参数 说明
-l 接收模式
-s 发送模式
-p UDP端口（默认3257）
-i 手动指定接收端IP
-w 轮询间隔秒数（默认3）
-L 日志目录

依赖

# 依赖列表

| 命令 | 作用 | 安装包 |
|------|------|--------|
| `jq` | 解析 JSON 通知 | `jq` |
| `termux-notification` / `termux-notification-list` | 发送/读取通知 | `termux-api` |
| `nc` | UDP 收发数据 | `netcat-openbsd` |
| `ncat` | 监听模式（支持 `-k`） | `nmap` |
| `xxd` | 十六进制/二进制转换 | `xxd` 或 `vim` |
| `ifconfig` | 获取本机 IP | `net-tools` |
| `timeout` | 限制 nc 监听时间 | `coreutils`（通常自带） |

## 一键安装

```bash
pkg update
pkg install jq termux-api netcat-openbsd nmap xxd net-tools

注意：nmap 提供了 ncat 命令，监听模式必须用它（或找支持 -k 的 nc 替代）。netcat-openbsd 提供的 nc 不支持 -k。
```

## 许可证

MIT（免费商用）https://opensource.org/license/MIT
