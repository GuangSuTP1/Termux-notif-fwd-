notif-fwd - Cross-Device Notification Forwarding

A Termux-based notification forwarding script over local area network.

Forward notifications from Phone A to Phone B automatically. Pure LAN UDP communication, no cloud services required.

Quick Start

Receiver (Phone B)

```bash
./notif-fwd.sh -l
```

Sender (Phone A)

```bash
./notif-fwd.sh -s
```

Options

Option Description
-l Listen mode (receiver)
-s Send mode (sender)
-p PORT UDP port (default 3257)
-i IP Manually specify receiver IP
-w SEC Poll interval in seconds (default 3)
-L DIR Log directory

Dependencies

Command Purpose Package
jq Parse JSON notifications jq
termux-notification / termux-notification-list Send/read notifications termux-api
nc UDP data transmission netcat-openbsd
ncat Listen mode (supports -k) nmap
xxd Hex/binary conversion xxd or vim
ifconfig Get local IP net-tools
timeout Limit nc listening time coreutils (usually pre-installed)

One-step Installation

```bash
pkg update
pkg install jq termux-api netcat-openbsd nmap xxd net-tools
```

Note: nmap provides the ncat command, which is required for listen mode (or any alternative nc that supports -k). The nc from netcat-openbsd does NOT support -k.

License

MIT (Free for commercial use) https://github.com/GuangSuTP1/Termux-notif-fwd-/blob/main/LICENSE
