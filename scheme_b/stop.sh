#!/system/bin/sh
# F50 Pro Scheme B: Stop Mihomo & Tailscale
# Author: shuangye

DIR="/data/local/tmp/scheme_b"
LOG="$DIR/service.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping Scheme B services..." >> "$LOG"

# Clean iptables DNS redirect
iptables -t nat -D PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null
iptables -t nat -D PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null

# Kill processes
pkill -f "$DIR/mihomo" 2>/dev/null
pkill -f "$DIR/tailscaled" 2>/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scheme B services stopped" >> "$LOG"
