#!/bin/bash
# ========================================================
# 中兴 F50 Pro 芯片底层固件全量备份工具 (macOS 原生版)
# 作者: shuangye
# 作用: 通过紫光展锐 BootROM 底层协议，完整提取全部分区固件
#       包含基带 NVRAM、IMEI、射频校准、内核与系统引导，救砖必备！
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
    echo "  中兴 F50 Pro 芯片底层全量备份工具 (macOS 原生版)"
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
chmod +x "$BASE_DIR/bin/adb" 2>/dev/null

DATE_TAG=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backup/backup_${DATE_TAG}"
mkdir -p "$BACKUP_DIR"

clear
echo "========================================================"
echo "      中兴 F50 Pro 芯片底层全量备份 (macOS)"
echo "      作者: shuangye"
echo "========================================================"
echo "备份存放路径: $BACKUP_DIR"
echo ""
echo "重要说明："
echo "  此备份为【芯片硬件级全量镜像备份】。"
echo "  会完整导出您的基带参数、IMEI校准数据、ZTE特有卡槽配置、"
echo "  Boot引导、Kernel内核、Modem固件等所有核心关键分区。"
echo "  只要保存好这份备份，未来哪怕系统完全崩溃或变砖，"
echo "  随时可以用【一键救砖还原工具】100%满血复活！"
echo "--------------------------------------------------------"
echo "操作步骤："
echo "  1. 请【拔掉】插在电脑上的 F50 Pro 设备（断开电源）。"
echo "  2. 拔掉后，请按【回车键】开始监听设备接入..."
read -p ">>> 请拔下设备，然后按回车键继续..." dummy

echo ""
echo "========================================================"
echo "正在等待设备插入 USB（请将 F50 Pro 重新插入 Mac USB 口）..."
echo "========================================================"

# 执行展锐 BootROM 底层读取 (all_lite: 提取所有核心分区及活跃槽位)
./bin/spd_dump_mac --wait 300 --kickto 2 exec path "$BACKUP_DIR" r all_lite reset

if [ $? -eq 0 ]; then
    echo ""
    echo "--------------------------------------------------------"
    echo "🎉 恭喜！中兴 F50 Pro 底层固件全量备份完成！"
    echo "备份目录: $BACKUP_DIR"
    echo "备份文件列表："
    ls -lh "$BACKUP_DIR"
    echo "--------------------------------------------------------"
    echo "提示：请妥善保管该备份目录，后续救砖恢复全靠它！"
else
    echo ""
    echo "❌ 备份过程中断或超时，请检查 USB 数据线是否稳定，然后重试。"
fi

echo ""
echo "按回车键退出..."
read dummy
