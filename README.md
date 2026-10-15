# ZTE F50 Pro (MU3356) macOS Toolkit & 5G CPE Transparent Proxy + Tailscale

<p align="center">
  <b>English</b> | <a href="README_CN.md"><b>简体中文</b></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%20(Apple%20Silicon%20%26%20Intel)-brightgreen" alt="macOS">
  <img src="https://img.shields.io/badge/Device-ZTE%20F50%20Pro%20(MU3356)-blue" alt="ZTE F50 Pro">
  <img src="https://img.shields.io/badge/OS-Android%2015-orange" alt="Android 15">
  <img src="https://img.shields.io/badge/SoC-Unisoc%20T760-red" alt="Unisoc T760">
  <img src="https://img.shields.io/badge/Kernel-Mihomo%20v1.19-purple" alt="Mihomo">
  <img src="https://img.shields.io/badge/VPN-Tailscale%20v1.104-informational" alt="Tailscale">
  <img src="https://img.shields.io/badge/License-MIT%20with%20Anti--Scalping-green" alt="License">
  <img src="https://img.shields.io/badge/Author-shuangye-blueviolet" alt="Author">
</p>

A dedicated, driverless macOS toolkit engineered for the **ZTE F50 Pro 5G Mobile Wi-Fi (MU3356, Unisoc T760 SoC, Android 15)**. Provides one-click chip-level BootROM flashing, permanent Root privilege authorization, a high-performance **5G CPE Transparent Proxy (Mihomo)**, mesh VPN networking (**Tailscale**), and 100% brick rescue.

Completely eliminates the hurdles macOS users previously faced: absence of Windows SPD flash drivers, inability to touch/confirm root permission popups on a screenless MiFi device, Android 15 process group background kills, cold-boot 5G modem cellular IP timing mismatches that crashed TUN routing, and default jumbo frame MTU packet-drop throttling.

---

## 🌟 Key Highlights & Engineering Breakthroughs

1. **⚡ Native macOS Driverless BootROM Flashing**:
   - Built-in Universal 2 binary `spd_dump_mac`, natively supporting Apple Silicon (M1/M2/M3/M4) and Intel Macs.
   - Eliminates Windows SPD driver conflicts and driver signature requirements—plug via Type-C to communicate directly with the BootROM.
2. **🔑 Permanent Root with Zero-Prompt Elevation**:
   - Overcomes the headless dilemma where Magisk elevation dialogs cannot be physically tapped. Patches `init_boot` during early boot to inject SQLite permissions (UID 2000 shell permanently granted), allowing ADB commands instant root access without interactive prompts.
3. **🛡️ Android 15 SIGHUP-Immune High-Availability Watchdog**:
   - Overcomes Android 15's behavior of terminating background processes via `SIGHUP` when init process groups exit (using a `( trap '' HUP ... ) &` subshell daemon).
   - Standard integration with Magisk `service.d` late-start service directory (`/data/adb/service.d/mihomo_autostart.sh`).
4. **⏱️ 5G Modem Cold-Boot Cellular IP Timing Probe**:
   - On cold boot, kernel interface `sipa_eth8` appears at second 1, but baseband registration and cellular IP assignment take 15–25 seconds. The watchdog polls for the actual cellular `inet` IP before launching routing services, preventing `TUN route: network unreachable` errors.
   - Dual-health watchdog continuously polls every 15 seconds (verifying both `pidof mihomo` and `ip link show tun0`), automatically recovering in 1 second upon failure.
5. **🚀 Line-Rate 100 Mbps Cellular Throughput**:
   - Fixes carrier packet loss caused by default `mtu: 9000` jumbo frames on 5G modems.
   - Tuned to `MTU 1400` + user-space TCP stack `stack: mixed` (GVisor) + `TCPMSS --clamp-mss-to-pmtu`, achieving full 100 Mbps real-world download throughput.
6. **🌐 Zero-Configuration Web Dashboard**:
   - Embedded MetaCubeXD Web dashboard (Port 9090) with pre-configured backend endpoints and empty secrets for immediate access.
7. **🔒 Tailscale Mesh VPN & Subnet Routing**:
   - One-click background daemon with automated subnet routing announcement (`192.168.0.0/24`) and exit-node capabilities.
8. **🚑 100% Chip-Level Raw Backup & Factory Restore**:
   - One-click raw clone of all 6.2GB chip partitions (including critical baseband NVRAM, radio calibration data, `prodnv` IMEI partition, and `super` system partition) for 30-second BootROM brick recovery.

---

## 📁 Repository Structure

```text
中兴F50Pro_macOS一键工具包_shuangye/
├── 【5G CPE透明软路由】Mihomo与Tailscale穿透中心.command  # 🌟 Main 5G CPE Transparent Proxy Controller
├── F50Pro一键工具箱.command                               # 🌟 General Utility Toolkit (Root/UFI Web/Rescue)
├── 【一键全量备份固件】F50Pro.command                       # 🛡️ Full Chip Partition Backup Tool
├── 【一键底层救砖还原】F50Pro.command                       # 🚑 100% BootROM Brick Recovery Tool
├── README.md                                              # English Documentation
├── README_CN.md                                           # Chinese Documentation
├── LICENSE                                                # MIT License with Anti-Scalping Clause
├── 【重要技术全解】中兴F50Pro软路由与底层救砖交接文档.md                 # 📖 Technical Architecture & Handover Manual
├── bin/                                                   # Core Tools & Firmware Dependencies
│   ├── adb                                                # Universal macOS ADB
│   ├── spd_dump_mac                                       # Universal macOS Unisoc BootROM Flash Tool
│   ├── tos.bin                                            # TrustOS Patch (Root + Wireless ADB)
│   ├── magisk.img                                         # Magisk init_boot Patch (Zero-Prompt Elevation)
│   ├── UFI-TOOLS.apk                                      # Web Management Console (Port 2333)
│   └── ...                                                # Bootloaders & Signature Bypass Payloads
└── scheme_b/                                              # 5G CPE Soft Router Assets
    ├── mihomo                                             # ARM64 Mihomo (Clash.Meta) Core
    ├── tailscale / tailscaled                             # ARM64 Tailscale Mesh Networking Suite
    ├── config.yaml                                        # 5G-Optimized Transparent Proxy Config (MTU 1400)
    ├── autorun.sh                                         # Autostart Watchdog (5G IP Probe + Dual-Health Guard)
    ├── start.sh / stop.sh / status.sh                     # Service & Firewall Orchestration Scripts
    ├── merge_sub.py                                       # Smart Subscription Merger (Preserving 5G TUN Config)
    └── ui/                                                # MetaCubeXD Web Dashboard (Pre-Configured)
```

---

## 🚀 Quick Start Guide

### 1. Download
Download the pre-packaged archive `中兴F50Pro_macOS一键工具包_shuangye.zip` from the [Releases page](../../releases) and extract it.

### 2. Deploy 5G CPE Transparent Proxy + Tailscale (Recommended)
1. Double-click **`【5G CPE透明软路由】Mihomo与Tailscale穿透中心.command`**.
2. Press **`1`** (One-click autostart & root patch).
3. Enter your Mac administrator password when prompted, then connect the powered-off F50 Pro to your Mac USB port.
4. The tool automatically completes BootROM flashing and boots the device. Once online, the script **automatically deploys the soft router components and autostart watchdog**.
5. Return to the main menu and press **`5`** to paste your Clash subscription link (intelligently merged while preserving 5G CPE MTU/TUN optimizations).
6. Press **`3`** to launch the Web dashboard directly (`http://192.168.0.1:9090/ui`).

### 3. Everyday Use
- Simply connect the F50 Pro to any power bank or car charger. The transparent proxy comes online automatically within 20 seconds of cold boot—no PC required!
- All connected devices (phones, laptops, tablets, smart TVs) enjoy line-rate 100 Mbps transparent acceleration.

---

## 🚑 Full Firmware Backup & Brick Recovery

Before modifying your device, a full physical partition backup is strongly recommended:
1. Run **`【一键全量备份固件】F50Pro.command`**, reconnect the device once, and the tool will clone all hardware partitions to your local disk.
2. If your device ever soft-bricks (bootloop, stuck on ZTE logo), run **`【一键底层救砖还原】F50Pro.command`** and plug in the device to restore factory firmware within 30 seconds via BootROM!

> **⚠️ Privacy & Security Notice**: The generated `backup/` folder contains your device's unique physical IMEI, IMSI, and NVRAM RF calibration data. **Never upload this directory to any public repository or online drive.** The project `.gitignore` excludes this directory by default.

---

## 🛡️ Anti-Scalping & Non-Commercial Notice

> **⚠️ Notice to all users (especially those purchasing from e-commerce platforms):**
> 
> 1. **100% Free & Open Source**: This project is developed by `shuangye` as a non-profit open-source initiative. All source code, patches, and binaries are **permanently free for public use**.
> 2. **Prohibition of Paid Resale**: Any individual or merchant selling this toolkit, bundling it behind paid paywalls, or charging for "remote flashing services" on **Taobao, Xianyu, Pinduoduo, WeChat, Bilibili**, or any other platform is engaging in unauthorized infringement and fraud.
> 3. **Report Fraud**: If you paid money to obtain this tool, you have been defrauded. Please report the merchant to the respective platform immediately and request a full refund.
> 4. **Authentic Source**: Only obtain this tool from the official repository: [`https://github.com/Tai1win10c/zte-f50pro-macos-toolkit`](https://github.com/Tai1win10c/zte-f50pro-macos-toolkit). Repackaged third-party distributions may contain malicious trojans or adware.

---

## 👨‍💻 About the Author & Community

- **Author / Architecture**: **shuangye** ([@Tai1win10c](https://github.com/Tai1win10c))
- **Bilibili**: Video walkthroughs and firmware updates in preparation.
- **Support the Project ⭐️**: If this project helped you, please give it a **Star** on GitHub—it is the greatest encouragement to open-source creators!

---

## ⚖️ License, Acknowledgments & Technical Inspiration

- **Author / Lead**: **shuangye** ([@Tai1win10c](https://github.com/Tai1win10c))
- **License**: Released under the [MIT License with Anti-Commercial Scalping Rider](LICENSE). All redistributions must strictly preserve the original author attribution and upstream repository link, and may not be used for commercial gain.
- **Acknowledgments & Upstream Projects**:
  - **UFI-TOOLS Inspiration & Concept**: Special thanks to [kanoqwq/UFI-TOOLS](https://github.com/kanoqwq/UFI-TOOLS) (see [UFI-TOOLS Documentation](https://github.com/kanoqwq/UFI-TOOLS/blob/http-server-version/User_Doc.md#32-%E5%AE%89%E8%A3%85%E5%89%8D%E8%BF%9E%E6%8E%A5%E8%AE%BE%E5%A4%87)) for pioneering research on MiFi BootROM flashing, headless root authorization, and enhanced web utilities.
  - **Routing Proxy Core**: [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) for the exceptional Linux routing core.
  - **Web Dashboard**: [MetaCubeX/metacubexd](https://github.com/MetaCubeX/metacubexd) for the clean Web interface.
  - **Mesh Networking**: [Tailscale](https://tailscale.com) for secure zero-config virtual networking.
  - **BootROM Communication**: [spreadtrum_flash](https://github.com/handsomehack/spreadtrum_flash) for low-level Unisoc BootROM protocol foundations.

---

### Disclaimer
This toolkit is provided solely for networking research and personal optimization. Please comply with local telecommunications regulations. The author assumes no liability for hardware damage or service disruption resulting from improper operation.
