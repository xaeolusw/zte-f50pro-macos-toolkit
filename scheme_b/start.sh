#!/system/bin/sh
# ========================================================
# F50 Pro 5G CPE Transparent Proxy & Tailscale
# Author: shuangye (https://github.com/shuangye)
# Open-source Free Project - Prohibited for commercial sale
# ========================================================

DIR="/data/local/tmp/scheme_b"
LOG="$DIR/service.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting 5G CPE Soft Router & Tailscale services..." >> "$LOG"

# 1. 开启系统 IP 转发
sysctl -w net.ipv4.ip_forward=1 >> "$LOG" 2>&1
sysctl -w net.ipv6.conf.all.forwarding=1 >> "$LOG" 2>&1

# 2. 补全 main 路由表默认出口（让 Mihomo TUN 与出口网卡 sipa_eth8 完美联动）
ip route add default dev sipa_eth8 table main 2>/dev/null

# 3. 优化 TCPMSS 防卡顿与丢包
iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -I FORWARD 1 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -C POSTROUTING -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
    iptables -t mangle -I POSTROUTING 1 -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

# 4. 放行转发链中的 tun0 流量（解决 Wi-Fi 客户端无法转发的核心限速/断网问题）
iptables -C FORWARD -i tun0 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -i tun0 -j ACCEPT
iptables -C FORWARD -o tun0 -j ACCEPT 2>/dev/null || iptables -I FORWARD 1 -o tun0 -j ACCEPT

# 5. 放行 F50 Pro 本地防火墙端口 (WebUI 9090, 代理 7890-7892, DNS 1053, Tailscale 41641)
iptables -C INPUT -p tcp --dport 9090 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport 9090 -j ACCEPT
iptables -C INPUT -p tcp --dport 7890:7892 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport 7890:7892 -j ACCEPT
iptables -C INPUT -p tcp --dport 1053 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport 1053 -j ACCEPT
iptables -C INPUT -p udp --dport 1053 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p udp --dport 1053 -j ACCEPT
iptables -C INPUT -p udp --dport 41641 -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p udp --dport 41641 -j ACCEPT

# 6. 启动 Mihomo 软路由内核
if ! pgrep -f "$DIR/mihomo" > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Mihomo..." >> "$LOG"
    nohup $DIR/mihomo -d $DIR > $DIR/mihomo.log 2>&1 &
fi

# 7. 启动 Tailscaled 守护进程
if ! pgrep -f "$DIR/tailscaled" > /dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Tailscaled..." >> "$LOG"
    HOME=$DIR nohup $DIR/tailscaled --state=$DIR/tailscale.state --socket=$DIR/tailscaled.sock --port=41641 > $DIR/tailscaled.log 2>&1 &
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 5G CPE Soft Router & Tailscale services successfully started" >> "$LOG"
