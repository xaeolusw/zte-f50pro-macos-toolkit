#!/system/bin/sh

# ========================================================
# 中兴 F50 Pro 方案B: 开机自启看门狗守护脚本
# 作者: shuangye (https://github.com/shuangye)
# 本项目永久开源免费，严禁任何形式的商业倒卖与转售
# ========================================================

(
    trap '' HUP
    export PATH=/sbin:/system/bin:/system/xbin:/product/bin:/vendor/bin:$PATH
    LOG="/data/local/tmp/autostart.log"

    # 确保 root 环境与 su 命令全局可用
    if [ ! -f /product/bin/su ] && [ -x /debug_ramdisk/su ]; then
        mkdir -p /data/local/tmp/pbin 2>/dev/null
        mount -t tmpfs tmpfs /data/local/tmp/pbin 2>/dev/null
        cp -a /product/bin/* /data/local/tmp/pbin/ 2>/dev/null
        ln -sf /debug_ramdisk/su /data/local/tmp/pbin/su 2>/dev/null
        ln -sf /debug_ramdisk/magisk /data/local/tmp/pbin/magisk 2>/dev/null
        chmod -R 755 /data/local/tmp/pbin 2>/dev/null
        mount --bind /data/local/tmp/pbin /product/bin 2>/dev/null
    fi

    echo "[$(date)] 看门狗已启动，等待 5G 基带注册与 IP 获取..." > "$LOG"

    # 等待 sipa_eth8 真正获取到蜂窝 IP 地址（最多等待 60 秒）
    i=0
    while ! ip addr show dev sipa_eth8 2>/dev/null | grep -q "inet "; do
        sleep 2
        i=$((i + 1))
        if [ $i -ge 30 ]; then
            echo "[$(date)] 警告：等待 60 秒后 sipa_eth8 仍未获取到 IP，强制继续启动" >> "$LOG"
            break
        fi
    done

    echo "[$(date)] 5G 网络与 IP 已就绪，正在启动软路由及穿透服务..." >> "$LOG"
    sleep 2

    # 首次启动
    cd /data/local/tmp/scheme_b
    sh start.sh >> "$LOG" 2>&1
    echo "[$(date)] start.sh 首次执行完毕" >> "$LOG"

    # 常驻高可用看门狗：每 15 秒检查一次，若进程挂掉或 tun0 虚拟网卡未成功创建，则重新恢复
    while true; do
        sleep 15
        if ! pidof mihomo >/dev/null 2>&1 || ! ip link show tun0 >/dev/null 2>&1; then
            echo "[$(date)] 检测到 mihomo 异常或 tun0 缺失，正在重新拉起..." >> "$LOG"
            cd /data/local/tmp/scheme_b
            sh stop.sh >> "$LOG" 2>&1
            sleep 1
            sh start.sh >> "$LOG" 2>&1
        fi
    done
) &
