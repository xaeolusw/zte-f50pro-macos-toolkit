#!/bin/bash
# ========================================================
# 中兴 F50 Pro (B25) 一键刷机与管理工具箱 for macOS
# 作者: shuangye
# 兼容: macOS (Apple Silicon M1/M2/M3/M4 & Intel Universal)
# ========================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/bin" ]; then
    BASE_DIR="$SCRIPT_DIR"
elif [ -d "$HOME/Downloads/中兴F50Pro_macOS一键工具包_shuangye/bin" ]; then
    BASE_DIR="$HOME/Downloads/中兴F50Pro_macOS一键工具包_shuangye"
elif [ -d "$HOME/Desktop/中兴F50Pro_macOS一键工具包_shuangye/bin" ]; then
    BASE_DIR="$HOME/Desktop/中兴F50Pro_macOS一键工具包_shuangye"
else
    echo "❌ 错误：找不到核心资源目录 (bin/)，请确保工具包位于 Downloads 或 Desktop 文件夹中。"
    read dummy
    exit 1
fi
cd "$BASE_DIR"

# 检查管理员权限
if [ "$EUID" -ne 0 ]; then
    echo "================================================================================"
    echo "  中兴 F50 Pro (B25) 一键工具箱 (macOS 原生版)"
    echo "  🔥 原创作者: shuangye  |  开源项目: 永久完全免费！"
    echo "  ⚠️ 严正防诈警告: 本工具完全开源免费，严禁任何形式的倒卖、转售或有偿代刷！"
    echo "     若您是在闲鱼、淘宝、拼多多等平台花钱购买的，您已被骗，请立即向平台举报退款！"
    echo "================================================================================"
    echo "提示：macOS 底层 USB 通信需要管理员权限以接管设备。"
    echo "请输入您的 Mac 开机密码并回车（输入时密码不显示属于正常现象）："
    echo "================================================================================"
    sudo "$0" "$@"
    exit $?
fi

chmod +x "$BASE_DIR/bin/spd_dump_mac" 2>/dev/null
chmod +x "$BASE_DIR/bin/adb" 2>/dev/null

# 优先使用自带的通用独立 adb
if [ -x "./bin/adb" ]; then
    ADB_BIN="./bin/adb"
elif [ -x "/opt/homebrew/bin/adb" ]; then
    ADB_BIN="/opt/homebrew/bin/adb"
elif [ -x "/usr/local/bin/adb" ]; then
    ADB_BIN="/usr/local/bin/adb"
else
    ADB_BIN="adb"
fi

# 自动等待并连接 ADB 的函数
wait_and_connect_adb() {
    echo ""
    echo "========================================================"
    echo "正在等待设备开机并启动 ADB 服务（大约需要 30 ~ 45 秒）..."
    echo "========================================================"
    for i in {1..35}; do
        printf "."
        sleep 2
        $ADB_BIN connect 192.168.0.1:5555 >/dev/null 2>&1
        DEVS=$($ADB_BIN devices 2>/dev/null | grep -E "\bdevice\b")
        if [ -n "$DEVS" ]; then
            echo ""
            echo ""
            echo "🎉 恭喜！成功检测并连接到 ADB 设备！"
            echo "--------------------------------------------------------"
            $ADB_BIN devices -l
            echo "--------------------------------------------------------"
            return 0
        fi
    done
    echo ""
    echo "⚠️ 暂未检测到设备上线，您可以稍后在主菜单选择 [3] 重新连接。"
    return 1
}

# 获取当前在线设备 ID
get_online_device() {
    $ADB_BIN connect 192.168.0.1:5555 >/dev/null 2>&1
    $ADB_BIN devices 2>/dev/null | grep -E "\bdevice\b" | head -n 1 | awk '{print $1}'
}

while true; do
    clear
    echo "================================================================================"
    echo "      中兴 F50 Pro (B25) macOS 原生一键玩机工具箱"
    echo "      🔥 原创作者: shuangye  |  开源项目: 永久完全免费！"
    echo "      ⚠️ 严正防诈警告: 本工具完全开源免费，严禁任何形式的倒卖、转售或有偿代刷！"
    echo "         若您是在闲鱼、淘宝、拼多多等平台花钱购买的，您已被骗，请立即举报退款！"
    echo "================================================================================"
    echo " [1] 一键 Root + 开启无线 ADB (直接插电，推荐)"
    echo " [2] 一键部署 UFI-TOOLS 网页增强后台 (端口 2333)"
    echo " [3] 检查并连接设备 (有线 + 192.168.0.1 无线)"
    echo " [4] 进入设备 ADB Shell 命令行"
    echo " [5] [备用/救砖] 短接模式 一键 Root"
    echo " [6] 🌟 启动屏幕实时控制台 (Web 屏幕 + scrcpy)"
    echo " [7] 🛡️ 芯片底层全量备份 (BootROM 镜像，救砖必备)"
    echo " [8] 🚑 芯片底层一键救砖还原 (从备份文件快速恢复)"
    echo " [9] 📶 网络急救：强制切回外置实体 SIM 卡 (解决无服务)"
    echo " [10] 🛸 方案B：Mihomo 透明软路由 + Tailscale 穿透管理中心"
    echo " [0] 退出"
    echo "========================================================"
    read -p "请输入选项 [0-10]: " choice

    case "$choice" in
        1)
            echo ""
            echo ">>> 启动【直接插电】一键 Root..."
            echo "【第 1 步：预先获取 Mac 管理员权限】"
            echo "提示：macOS 底层 USB BootROM 通信需要管理员权限。"
            echo "请输入您的 Mac 开机密码并回车（输入时密码不显示属于正常现象）："
            echo "--------------------------------------------------------"
            sudo -v || { echo "❌ 密码错误或未授权"; sleep 2; continue; }
            echo "✅ 管理员权限已确认！"
            echo "--------------------------------------------------------"
            echo "【第 2 步：拔插设备】"
            echo "  1. 请【拔掉】插在电脑上的 F50 Pro 设备（确保断电）。"
            echo "  2. 拔掉后，按【回车键】开始等待接入..."
            read -p ">>> 请先拔下设备，然后按回车键继续..." dummy
            echo ""
            echo "========================================================"
            echo "正在等待设备插入 USB（请将 F50 Pro 重新插回 Mac USB 接口）..."
            echo "========================================================"
            sudo "$BASE_DIR/bin/spd_dump_mac" --wait 300 --kickto 2 exec path "$BASE_DIR/bin" w trustos "$BASE_DIR/bin/tos.bin" w_force init_boot "$BASE_DIR/bin/magisk.img" reset
            if [ $? -eq 0 ]; then
                wait_and_connect_adb
            fi
            echo ""
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        2)
            echo ""
            echo ">>> 启动【UFI-TOOLS 网页增强后台】一键部署..."
            echo "正在检测设备连接..."
            DEV_ID=$(get_online_device)
            if [ -z "$DEV_ID" ]; then
                echo "正在尝试等待设备响应..."
                for i in {1..15}; do
                    printf "."
                    sleep 2
                    DEV_ID=$(get_online_device)
                    [ -n "$DEV_ID" ] && break
                done
                echo ""
            fi

            if [ -z "$DEV_ID" ]; then
                echo "❌ 未检测到在线设备，请确保设备已开机并插入电脑。"
                echo "按回车键返回主菜单..."
                read dummy
                continue
            fi

            echo "✅ 已连接到设备: $DEV_ID"
            echo ">>> 正在安装 UFI-TOOLS 完整版到设备..."
            $ADB_BIN -s "$DEV_ID" install -r -d ./bin/UFI-TOOLS.apk
            if [ $? -ne 0 ]; then
                echo "❌ APK 安装失败，请检查设备存储空间。"
                echo "按回车键返回主菜单..."
                read dummy
                continue
            fi

            echo ">>> 正在配置后台常驻与必要系统权限..."
            $ADB_BIN -s "$DEV_ID" shell "
pm grant com.minikano.f50_sms android.permission.READ_EXTERNAL_STORAGE 2>/dev/null
pm grant com.minikano.f50_sms android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null
pm grant com.minikano.f50_sms android.permission.POST_NOTIFICATIONS 2>/dev/null
pm grant com.minikano.f50_sms android.permission.READ_SMS 2>/dev/null
appops set com.minikano.f50_sms android:get_usage_stats allow 2>/dev/null
appops set com.minikano.f50_sms GET_USAGE_STATS allow 2>/dev/null
appops set com.minikano.f50_sms PACKAGE_USAGE_STATS allow 2>/dev/null
dumpsys deviceidle whitelist +com.minikano.f50_sms 2>/dev/null
svc power stayon true 2>/dev/null
"
            echo ">>> 正在启动 UFI-TOOLS Web 服务..."
            $ADB_BIN -s "$DEV_ID" shell "am start -n com.minikano.f50_sms/.MainActivity" >/dev/null 2>&1
            sleep 2
            $ADB_BIN -s "$DEV_ID" shell "am broadcast -a com.minikano.f50_sms.UI_STATUS_CHANGED --ez status true" >/dev/null 2>&1

            echo ""
            echo "--------------------------------------------------------"
            echo "🎉 部署完成！"
            echo "UFI-TOOLS 网页后台已在随身 WiFi 上运行。"
            echo "访问地址: http://192.168.0.1:2333"
            echo "默认登录口令: admin"
            echo "--------------------------------------------------------"
            echo "正在为您打开浏览器管理页面..."
            open "http://192.168.0.1:2333" 2>/dev/null
            echo ""
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        3)
            echo ""
            echo ">>> 正在检查并连接设备..."
            $ADB_BIN connect 192.168.0.1:5555
            echo ""
            echo "当前 ADB 在线设备列表："
            $ADB_BIN devices -l
            echo ""
            echo "USB 物理总线硬件状态："
            ioreg -p IOUSB -w0 -l | grep -E "USB Product Name" | grep -v "Apple"
            echo "--------------------------------------------------------"
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        4)
            echo ""
            echo ">>> 正在打开设备命令行 (ADB Shell)..."
            DEV_ID=$(get_online_device)
            if [ -n "$DEV_ID" ]; then
                echo "已连接到设备: $DEV_ID"
                echo "提示：输入 exit 回车可退出控制台"
                echo "--------------------------------------------------------"
                $ADB_BIN -s "$DEV_ID" shell
            else
                echo "❌ 未检测到可用设备，请先确认设备已开机并插入电脑。"
            fi
            echo ""
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        5)
            echo ""
            echo ">>> 启动【短接模式】一键 Root..."
            echo "操作说明："
            echo "  1. 关机状态下按住内部短接测试点。"
            echo "  2. 插入 USB 数据线至 Mac，跑进度条后松开短接点。"
            echo "--------------------------------------------------------"
            ./bin/spd_dump_mac --wait 300 exec_addr 0x65012f48 fdl ./bin/fdl1-dl.bin 0x65000800 fdl ./bin/fdl2-dl.bin 0xb4fffe00 exec path ./bin w trustos ./bin/tos.bin w_force init_boot ./bin/magisk.img reset
            if [ $? -eq 0 ]; then
                wait_and_connect_adb
            fi
            echo ""
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        6)
            echo ""
            echo ">>> 启动【屏幕实时投屏与交互控制】..."
            DEV_ID=$(get_online_device)
            if [ -z "$DEV_ID" ]; then
                echo "❌ 未检测到在线设备，请先确认设备已连接 Wi-Fi 或插入电脑。"
                echo "按回车键返回主菜单..."
                read dummy
                continue
            fi
            SCRCPY_BIN="/opt/homebrew/bin/scrcpy"
            if [ ! -x "$SCRCPY_BIN" ]; then
                SCRCPY_BIN="$(which scrcpy 2>/dev/null)"
            fi
            if [ -z "$SCRCPY_BIN" ] || [ ! -x "$SCRCPY_BIN" ]; then
                echo "⚠️ 检测到系统中未安装 scrcpy，正在自动安装..."
                brew install scrcpy
                SCRCPY_BIN="/opt/homebrew/bin/scrcpy"
            fi
            echo "✅ 已连接到设备: $DEV_ID"
            echo ">>> 正在启动投屏窗口..."
            echo "💡 提示: 鼠标左键点击，右键返回，中键回到桌面，关闭窗口即可退出。"
            echo "--------------------------------------------------------"
            "$SCRCPY_BIN" -s "$DEV_ID" --window-title="中兴 F50 Pro 屏幕控制 (shuangye)" --no-audio -m 800 --stay-awake --video-codec=h264
            echo ""
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        7)
            ./【一键全量备份固件】F50Pro.command
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        8)
            ./【一键底层救砖还原】F50Pro.command
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        9)
            echo ""
            echo ">>> 正在执行【网络急救：强制切回外置实体 SIM 卡】..."
            DEV_ID=$(get_online_device)
            if [ -n "$DEV_ID" ]; then
                $ADB_BIN -s "$DEV_ID" shell "settings put system zte_webserver_sim_slot_id 4; settings put system zte_webserver_sim_slot_id_finished 1; settings put global data_roaming 1; svc data enable" 2>/dev/null
            fi
            curl -s -X POST -H "Referer: http://192.168.0.1/index.html" -d "isTest=false&goformId=SET_SIM_SLOT&sim_slot=11" "http://192.168.0.1/goform/goform_set_cmd_process" >/dev/null 2>&1
            sleep 2
            curl -s -X POST -H "Referer: http://192.168.0.1/index.html" -d "isTest=false&goformId=CONNECT_NETWORK" "http://192.168.0.1/goform/goform_set_cmd_process" >/dev/null 2>&1
            echo "✅ 指令已下发，正在检测网络恢复状态..."
            sleep 3
            NET_STATUS=$(curl -s "http://192.168.0.1/goform/goform_get_cmd_process?isTest=false&cmd=network_type,network_provider,ppp_status,signalbar,wan_ipaddr")
            echo "当前网络状态: $NET_STATUS"
            echo "--------------------------------------------------------"
            echo "按回车键返回主菜单..."
            read dummy
            ;;
        10)
            ./【方案B】软路由与穿透管理中心.command
            ;;
        0)
            echo "已退出。"
            exit 0
            ;;
        *)
            echo "无效选项，请重新输入。"
            sleep 1
            ;;
    esac
done
