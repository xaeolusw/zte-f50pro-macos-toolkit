#!/bin/bash

# ========================================================
# 中兴 F50 Pro 实时投屏与交互控制台
# 作者: shuangye
# ========================================================

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -x "./bin/adb" ]; then
    export ADB="./bin/adb"
elif [ -x "/opt/homebrew/bin/adb" ]; then
    export ADB="/opt/homebrew/bin/adb"
elif [ -x "/usr/local/bin/adb" ]; then
    export ADB="/usr/local/bin/adb"
else
    export ADB="adb"
fi

echo "========================================================"
echo "      中兴 F50 Pro 屏幕实时投屏与交互控制"
echo "      作者: shuangye"
echo "========================================================"
echo ""
echo "正在连接设备 192.168.0.1:5555 ..."
$ADB connect 192.168.0.1:5555 >/dev/null 2>&1

DEVS=$($ADB devices | grep -E "\bdevice\b" | head -n 1 | awk '{print $1}')
if [ -z "$DEVS" ]; then
    echo "❌ 未检测到在线设备，请确保已连接 F50 Pro 的 Wi-Fi 或插入电脑。"
    echo "按回车键退出..."
    read dummy
    exit 1
fi

echo "✅ 已连接到设备: $DEVS"
echo ""
echo "请选择投屏方式："
echo " [1] 🌟 网页交互控制台 (推荐，绝不黑屏，支持鼠标任意点击与按键)"
echo " [2] 原生窗口投屏 (scrcpy 窗口)"
echo " [0] 退出"
echo "--------------------------------------------------------"
read -p "请输入选项 [0-2]: " mode

case "$mode" in
    1)
        echo ">>> 正在启动网页交互控制台..."
        pkill -f "web_screen.py" 2>/dev/null
        python3 "$DIR/web_screen.py" &
        sleep 1
        open "http://127.0.0.1:8888"
        echo "✅ 已在浏览器中打开控制台: http://127.0.0.1:8888"
        echo "按回车键停止控制台服务..."
        read dummy
        pkill -f "web_screen.py" 2>/dev/null
        ;;
    2)
        SCRCPY_BIN="/opt/homebrew/bin/scrcpy"
        [ ! -x "$SCRCPY_BIN" ] && SCRCPY_BIN="$(which scrcpy 2>/dev/null)"
        if [ -z "$SCRCPY_BIN" ]; then
            brew install scrcpy
            SCRCPY_BIN="/opt/homebrew/bin/scrcpy"
        fi
        "$SCRCPY_BIN" -s "$DEVS" --display-id=0 --no-audio -m 800 --stay-awake --video-codec=h264
        ;;
    *)
        exit 0
        ;;
esac
