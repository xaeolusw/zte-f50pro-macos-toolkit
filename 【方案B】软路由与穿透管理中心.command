#!/bin/bash
# ========================================================
# 中兴 F50 Pro 方案B：Mihomo 透明软路由 + Tailscale 内网穿透中心
# 作者: shuangye
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

ADB_BIN="$BASE_DIR/bin/adb"
SPD_BIN="$BASE_DIR/bin/spd_dump_mac"
chmod +x "$ADB_BIN" "$SPD_BIN" 2>/dev/null

ensure_adb_connected() {
    $ADB_BIN connect 192.168.0.1:5555 >/dev/null 2>&1
    local dev=$($ADB_BIN devices 2>/dev/null | grep -E "\bdevice\b" | head -n 1 | awk '{print $1}')
    if [ -z "$dev" ]; then
        echo "⚠️ 正在尝试重新连接 F50 Pro (192.168.0.1:5555)..."
        $ADB_BIN connect 192.168.0.1:5555 >/dev/null 2>&1
        sleep 1
        dev=$($ADB_BIN devices 2>/dev/null | grep -E "\bdevice\b" | head -n 1 | awk '{print $1}')
    fi
    echo "$dev"
}

check_root_ready() {
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then
        echo "offline"
        return 1
    fi
    local res=$($ADB_BIN -s "$dev" shell "su -c 'id' 2>/dev/null || /debug_ramdisk/su -c 'id' 2>/dev/null")
    if echo "$res" | grep -q "uid=0"; then
        echo "ready"
        return 0
    else
        echo "not_granted"
        return 2
    fi
}

flash_boot_patch() {
    echo "========================================================"
    echo "  🚀 一键刷入开机自启与Root补丁 (BootROM 芯片直刷)"
    echo "  作者: shuangye"
    echo "========================================================"
    echo "说明："
    echo "  此操作会将开机自启脚本与 UID 2000 永久 Root 授权补丁"
    echo "  刷入 F50 Pro 的 init_boot 分区。"
    echo "  刷入完成后，开机将自动启动 Mihomo 和 Tailscale，"
    echo "  且 ADB 将拥有免弹窗的永久 Root 权限！"
    echo "--------------------------------------------------------"
    echo "【第 1 步：预先获取 Mac 管理员权限】"
    echo "提示：macOS 底层 USB BootROM 通信需要管理员权限。"
    echo "请输入您的 Mac 开机密码并回车（输入时密码不显示属于正常现象）："
    echo "--------------------------------------------------------"
    sudo -v || { echo "❌ 密码错误或未授权，已取消。"; return 1; }

    echo ""
    echo "✅ 管理员权限已确认！"
    echo "--------------------------------------------------------"
    echo "【第 2 步：拔插设备】"
    echo "  1. 请【拔掉】插在电脑上的 F50 Pro 设备（断开电源）。"
    echo "  2. 拔掉后，按【回车键】开始等待接入..."
    read -p ">>> 请先拔下设备，然后按回车键继续..." dummy

    echo ""
    echo "========================================================"
    echo "正在等待设备插入 USB（请将 F50 Pro 重新插回 Mac USB 接口）..."
    echo "========================================================"

    # 调用 spd_dump_mac 写入 init_boot 补丁 (使用绝对路径)
    sudo "$SPD_BIN" --wait 300 --kickto 2 exec path "$BASE_DIR/bin" w_force init_boot "$BASE_DIR/bin/magisk.img" reset

    if [ $? -eq 0 ]; then
        echo ""
        echo "--------------------------------------------------------"
        echo "🎉 恭喜！开机自启与 Root 补丁已成功刷入！"
        echo "设备正在自动开机中，请等待约 20-30 秒让系统就绪..."
        echo "--------------------------------------------------------"
        for i in {25..1}; do
            echo -ne "倒计时: $i 秒...\r"
            sleep 1
        done
        echo ""
        echo "正在验证 ADB 连接与 Root 状态..."
        $ADB_BIN connect 192.168.0.1:5555 >/dev/null 2>&1
        local root_status=$(check_root_ready)
        if [ "$root_status" = "ready" ]; then
            echo "🎉 验证成功！系统已完全激活永久 Root 与开机自启环境！"
            echo ">>> 正在为您自动下发方案B全套组件与高可用看门狗..."
            deploy_scheme_b
        else
            echo "提示：设备已开机，若 Root 尚未就绪，请等待 10 秒后重新运行状态检查。"
        fi
    else
        echo ""
        echo "❌ 刷入过程中断或超时，请检查 USB 数据线连接后重试。"
    fi
}

deploy_scheme_b() {
    echo "========================================================"
    echo "  📦 正在部署/同步 方案B 核心组件与自启看门狗"
    echo "  作者: shuangye"
    echo "========================================================"
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then echo "❌ 错误: 设备未在线 (192.168.0.1:5555)"; return 1; fi

    local root_status=$(check_root_ready)
    if [ "$root_status" != "ready" ]; then
        echo "⚠️ 提示: 检测到设备尚未激活免密 Root，请先选择 [1] 刷入补丁。"
        return 1
    fi

    echo ">>> 正在推送方案B核心组件 (Mihomo, Tailscale, MetaCubeXD WebUI, 全球规则库)..."
    $ADB_BIN -s "$dev" shell "mkdir -p /data/local/tmp/scheme_b"
    $ADB_BIN -s "$dev" push "$BASE_DIR/scheme_b/." /data/local/tmp/scheme_b/
    $ADB_BIN -s "$dev" shell "chmod -R 755 /data/local/tmp/scheme_b"

    echo ">>> 正在部署 Magisk 开机自启看门狗 (/data/adb/service.d/mihomo_autostart.sh)..."
    $ADB_BIN -s "$dev" shell "su -c 'mkdir -p /data/adb/service.d && cp -f /data/local/tmp/scheme_b/autorun.sh /data/adb/service.d/mihomo_autostart.sh && chmod 755 /data/adb/service.d/mihomo_autostart.sh /data/local/tmp/autorun.sh'"

    echo ">>> 正在启动方案B全部服务..."
    $ADB_BIN -s "$dev" shell "su -c 'cd /data/local/tmp/scheme_b && sh stop.sh >/dev/null 2>&1; sh start.sh'"
    sleep 2

    echo "--------------------------------------------------------"
    echo "🎉 恭喜！方案B全套组件与开机自启看门狗已全部部署就绪！"
    echo "Web 控制面板: http://192.168.0.1:9090/ui"
    echo "--------------------------------------------------------"
}

open_web_ui() {
    echo "正在打开 Mihomo Web 控制面板..."
    local url="http://192.168.0.1:9090/ui"
    open "$url"
    echo "已在浏览器中打开: $url"
}

tailscale_login() {
    echo "========================================================"
    echo "  🔑 Tailscale 账号绑定与互联配置"
    echo "========================================================"
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then
        echo "❌ 错误: 设备未在线，请检查 USB/Wi-Fi 连接。"
        return 1
    fi

    echo "正在确保 Tailscaled 后台守护进程运行中..."
    $ADB_BIN -s "$dev" shell "su -c 'pgrep -f /data/local/tmp/scheme_b/tailscaled >/dev/null || /data/local/tmp/scheme_b/tailscaled --state=/data/local/tmp/scheme_b/tailscale.state --socket=/data/local/tmp/scheme_b/tailscaled.sock --port=41641 > /data/local/tmp/scheme_b/tailscaled.log 2>&1 &'"
    sleep 2

    echo ">>> 正在获取 Tailscale 登录链接并宣告子网路由 (192.168.0.0/24)..."
    echo "--------------------------------------------------------"
    
    # 捕获 tailscale up 输出
    $ADB_BIN -s "$dev" shell "su -c '/data/local/tmp/scheme_b/tailscale --socket=/data/local/tmp/scheme_b/tailscaled.sock up --advertise-routes=192.168.0.0/24 --advertise-exit-node --accept-routes=false --reset'" 2>&1 | tee /tmp/tailscale_up.log
    
    local login_url=$(grep -Eo 'https://login\.tailscale\.com/a/[a-zA-Z0-9]+' /tmp/tailscale_up.log | head -n 1)
    if [ -n "$login_url" ]; then
        echo "--------------------------------------------------------"
        echo "🎉 成功获取到登录认证链接！"
        echo "链接: $login_url"
        echo "正在为您自动在浏览器中打开该页面..."
        open "$login_url"
    else
        echo "--------------------------------------------------------"
        echo "提示：如果已绑定或正在认证，可选择菜单 [5] 查看当前 Tailscale 状态。"
    fi
}

import_subscription() {
    echo "========================================================"
    echo "  📥 导入/更新 Clash / Mihomo 订阅"
    echo "========================================================"
    echo "说明："
    echo "  您可以粘贴订阅链接（URL），或者拖入本地 .yaml 配置文件。"
    echo "  系统会自动保留 F50 Pro 的软路由透明代理 TUN/DNS 设置，"
    echo "  并将所有代理节点与分流规则一键下发到设备并热重载！"
    echo "--------------------------------------------------------"
    read -p "请输入订阅 URL 或拖入本地 yaml 文件: " sub_input

    # 去除首尾引号和空格
    sub_input=$(echo "$sub_input" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

    if [ -z "$sub_input" ]; then
        echo "❌ 输入为空，已取消。"
        return 1
    fi

    echo "正在合并配置并生成 F50 Pro 软路由配置..."
    python3 "$BASE_DIR/scheme_b/merge_sub.py" "$sub_input" "$BASE_DIR/scheme_b/config.yaml" "/tmp/merged_config.yaml"
    if [ $? -ne 0 ]; then
        echo "❌ 配置合并失败，请检查链接或文件格式。"
        return 1
    fi

    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then
        echo "❌ 错误: 设备未在线。"
        return 1
    fi

    echo "正在推送新配置到 F50 Pro 设备..."
    $ADB_BIN -s "$dev" push /tmp/merged_config.yaml /data/local/tmp/scheme_b/config.yaml
    $ADB_BIN -s "$dev" shell "chmod 755 /data/local/tmp/scheme_b/config.yaml"

    echo "正在热重载 Mihomo 内核..."
    local secret_val=$(grep "secret:" "$BASE_DIR/scheme_b/config.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"\r\n')
    local auth_header=""
    if [ -n "$secret_val" ]; then
        auth_header="-H \"Authorization: Bearer $secret_val\""
    fi
    curl -s -X PUT http://192.168.0.1:9090/configs \
        -H "Authorization: Bearer $secret_val" \
        -H "Content-Type: application/json" \
        -d '{"path": "/data/local/tmp/scheme_b/config.yaml", "payload": ""}' > /dev/null 2>&1
    
    echo "🎉 订阅更新完成！节点与规则已生效。"
}

view_status() {
    echo "========================================================"
    echo "  📊 F50 Pro 方案B 运行状态报告"
    echo "========================================================"
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then
        echo "❌ 错误: 设备未在线 (192.168.0.1:5555)。"
        return 1
    fi

    echo ">>> 设备连接: $dev (在线)"
    local root_status=$(check_root_ready)
    if [ "$root_status" = "ready" ]; then
        echo ">>> Root 权限: ✅ 正常 (UID 0)"
    else
        echo ">>> Root 权限: ⚠️ 未授权 (建议先执行 [1] 刷入补丁)"
    fi

    echo "--------------------------------------------------------"
    $ADB_BIN -s "$dev" shell "sh /data/local/tmp/scheme_b/status.sh 2>/dev/null"
    echo "--------------------------------------------------------"
    echo ">>> 5G 移动蜂窝状态:"
    $ADB_BIN -s "$dev" shell "ip addr show dev sipa_eth8 2>/dev/null | grep 'inet '" | while read -r line; do
        echo "    $line"
    done
    echo "========================================================"
}

start_services() {
    echo "正在启动方案B服务..."
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then echo "❌ 设备离线"; return 1; fi
    # 检查如果设备缺少组件则自动先下发
    local is_missing=$($ADB_BIN -s "$dev" shell "[ -f /data/local/tmp/scheme_b/mihomo ] || echo 'missing'")
    if [ "$is_missing" = "missing" ]; then
        echo "⚠️ 检测到设备尚未下发方案B组件，正在自动部署..."
        deploy_scheme_b
    else
        $ADB_BIN -s "$dev" shell "su -c 'sh /data/local/tmp/scheme_b/start.sh'"
        echo "🎉 启动指令已发送！"
        sleep 2
        view_status
    fi
}

stop_services() {
    echo "正在停止方案B服务..."
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then echo "❌ 设备离线"; return 1; fi
    $ADB_BIN -s "$dev" shell "su -c 'sh /data/local/tmp/scheme_b/stop.sh'"
    echo "🎉 方案B服务已停止，网络已恢复中兴官方原生直连状态！"
}

restart_services() {
    echo "正在重启方案B服务..."
    local dev=$(ensure_adb_connected)
    if [ -z "$dev" ]; then echo "❌ 设备离线"; return 1; fi
    $ADB_BIN -s "$dev" shell "su -c 'sh /data/local/tmp/scheme_b/stop.sh && sh /data/local/tmp/scheme_b/start.sh'"
    echo "🎉 重启完成！"
    sleep 2
    view_status
}

while true; do
    clear
    echo "================================================================================"
    echo "  🚀 中兴 F50 Pro 方案B：Mihomo 透明软路由 + Tailscale 穿透管理中心"
    echo "  🔥 原创作者: shuangye  |  开源项目: 永久完全免费！"
    echo "  ⚠️ 严正防诈警告: 本工具完全免费开源，严禁任何形式的倒卖、转售或有偿代刷！"
    echo "     若您是在闲鱼、淘宝、拼多多等平台花钱购买的，您已被骗，请立即向平台举报退款！"
    echo "================================================================================"
    echo " [1] ⚡ 一键刷入开机自启补丁 (BootROM 芯片直刷，只需拔插1次)"
    echo " [2] 📦 一键部署/同步 方案B 核心组件与自启看门狗 (新机/复用一键就绪)"
    echo " [3] 🌐 打开 Mihomo Web 控制面板 (http://192.168.0.1:9090/ui)"
    echo " [4] 🔑 Tailscale 账号绑定与内网互联 (显示登录链接/二维码)"
    echo " [5] 📥 导入/更新 Clash 订阅链接 (输入订阅URL自动同步节点)"
    echo " [6] 📊 查看运行状态 (Mihomo/Tailscale/5G网络/DNS重定向)"
    echo " [7] ▶️ 启动所有方案B服务 (Mihomo + Tailscale)"
    echo " [8] ⏹️ 停止所有方案B服务 (恢复原生路由器模式)"
    echo " [9] 🔄 重启所有方案B服务"
    echo " [0] 退出"
    echo "================================================================================"
    read -p "请输入选项 [0-9]: " choice

    case "$choice" in
        1) flash_boot_patch; read -p "按回车键继续..." dummy ;;
        2) deploy_scheme_b; read -p "按回车键继续..." dummy ;;
        3) open_web_ui; read -p "按回车键继续..." dummy ;;
        4) tailscale_login; read -p "按回车键继续..." dummy ;;
        5) import_subscription; read -p "按回车键继续..." dummy ;;
        6) view_status; read -p "按回车键继续..." dummy ;;
        7) start_services; read -p "按回车键继续..." dummy ;;
        8) stop_services; read -p "按回车键继续..." dummy ;;
        9) restart_services; read -p "按回车键继续..." dummy ;;
        0) echo "已退出。"; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 1 ;;
    esac
done
