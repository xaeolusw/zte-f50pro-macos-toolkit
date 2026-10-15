#!/system/bin/sh
# F50 Pro Scheme B: Status Check
# Author: shuangye

DIR="/data/local/tmp/scheme_b"

echo "=== Mihomo Status ==="
if pgrep -f "$DIR/mihomo" > /dev/null; then
    PID=$(pgrep -f "$DIR/mihomo" | head -n 1)
    echo "Status: RUNNING (PID: $PID)"
    echo "Web UI: http://192.168.0.1:9090/ui"
    echo "API Port: 9090 (Listening)"
else
    echo "Status: STOPPED"
fi

echo ""
echo "=== Tailscale Status ==="
if pgrep -f "$DIR/tailscaled" > /dev/null; then
    PID=$(pgrep -f "$DIR/tailscaled" | head -n 1)
    echo "Status: RUNNING (PID: $PID)"
    $DIR/tailscale --socket=$DIR/tailscaled.sock status 2>/dev/null || echo "Tailscaled is running. Run 'tailscale up' to log in."
else
    echo "Status: STOPPED"
fi

echo ""
echo "=== Network & DNS Status ==="
if iptables -t nat -L PREROUTING -n 2>/dev/null | grep -q "1053"; then
    echo "DNS Redirection (Port 53 -> 1053): ACTIVE"
else
    echo "DNS Redirection: OFF (Native Router DNS active)"
fi
