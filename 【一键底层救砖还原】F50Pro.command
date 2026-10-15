#!/bin/bash
# ========================================================
# 中兴 F50 Pro 芯片底层一键救砖与固件还原工具 (macOS 原生版)
# 作者: shuangye
# 作用: 当设备系统损坏、无限重启、无基带或无法开机时，
#       通过紫光展锐 BootROM 协议一键刷回备份分区，彻底救砖！
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
    echo "  中兴 F50 Pro 芯片底层一键救砖还原工具 (macOS 原生版)"
    echo "  🔥 原创作者: shuangye  |  开源项目: 永久完全免费！"
    echo "  ⚠️ 严正防诈警告: 本工具完全开源免费，严禁任何形式的倒卖、转售或有偿代刷！"
    echo "     若您是在闲鱼、淘宝、拼多多等平台花钱购买的，您已被骗，请立即向平台举报退款！"
    echo "================================================================================"
    echo "提示：macOS 底层 USB BootROM 通信需要管理员权限。"
    echo "请输入您的 Mac 开机密码并回车（输入时密码不显示属于正常现象）："
    echo "================================================================================"
    sudo "$0" "$@"
    exit $?
fi

chmod +x "$BASE_DIR/bin/spd_dump_mac" 2>/dev/null

clear
echo "========================================================"
echo "      中兴 F50 Pro 芯片底层一键救砖还原工具 (macOS)"
echo "      作者: shuangye"
echo "========================================================"
echo ""
echo "正在检测可用的固件备份..."

BACKUP_LIST=($(ls -d ./backup/backup_* 2>/dev/null))

if [ ${#BACKUP_LIST[@]} -eq 0 ]; then
    echo "❌ 未在 ./backup/ 目录下找到任何备份文件！"
    echo "请确保您之前运行过【一键全量备份固件】工具。"
    echo ""
    echo "按回车键退出..."
    read dummy
    exit 1
fi

echo "找到以下固件备份："
for i in "${!BACKUP_LIST[@]}"; do
    echo "  [$i] ${BACKUP_LIST[$i]}"
done
echo ""
read -p "请选择要还原的备份编号 [0-$((${#BACKUP_LIST[@]} - 1))]: " sel_idx

TARGET_BACKUP="${BACKUP_LIST[$sel_idx]}"
if [ -z "$TARGET_BACKUP" ] || [ ! -d "$TARGET_BACKUP" ]; then
    echo "❌ 选择无效！"
    exit 1
fi

echo ""
echo "已选择还原固件源: $TARGET_BACKUP"
echo "--------------------------------------------------------"
echo "操作步骤："
echo "  1. 请【拔掉】插在电脑上的 F50 Pro 设备（确保断电）。"
echo "  2. 拔掉后，按【回车键】开始等待连接..."
read -p ">>> 请拔下设备，然后按回车键继续..." dummy

echo ""
echo "========================================================"
echo "正在等待设备插入 USB（请将 F50 Pro 重新插入 Mac USB 口）..."
echo "========================================================"

# 执行硬件级恢复写回
./bin/spd_dump_mac --wait 300 --kickto 2 exec path "$TARGET_BACKUP" write_parts "$TARGET_BACKUP" reset

if [ $? -eq 0 ]; then
    echo ""
    echo "--------------------------------------------------------"
    echo "🎉 恭喜！中兴 F50 Pro 底层救砖写入完成！"
    echo "设备正在自动重启开机，请等待 30-45 秒恢复正常。"
    echo "--------------------------------------------------------"
else
    echo ""
    echo "⚠️ 普通插电还原未响应？"
    echo "如果设备已彻底变砖（指示灯完全不亮），请使用【短接模式】救砖："
    echo "1. 拆开外壳按住内部两个测试点短接"
    echo "2. 插入 USB 数据线并运行短接模式恢复命令"
fi

echo ""
echo "按回车键退出..."
read dummy
