# 📘 Clash / Mihomo (Clash.Meta) 终极配置与优化指南

> **适用内核**：Mihomo (原 Clash.Meta) 及各平台图形客户端（Clash Verge Rev、Clash Nyanpasu、Mihomo Party、软路由方案B等）  
> **核心原则**：低延迟、防封号、零泄漏、极速建连、稳定容灾  

---

## 目录
1. [基础核心参数 (General Settings)](#1-基础核心参数-general-settings)
2. [DNS 深度架构与防泄漏 (DNS Engine)](#2-dns-深度架构与防泄漏-dns-engine)
3. [TUN 虚拟网卡与透明软路由 (TUN Settings)](#3-tun-虚拟网卡与透明软路由-tun-settings)
4. [域名嗅探模块 (Sniffer)](#4-域名嗅探模块-sniffer)
5. [策略组类型与应用场景 (Proxy Groups)](#5-策略组类型与应用场景-proxy-groups)
6. [分流规则语法与优先级 (Rules & Flow Control)](#6-分流规则语法与优先级-rules--flow-control)
7. [开箱即用：两大黄金实践模板](#7-开箱即用两大黄金实践模板)
8. [排障速查备忘录](#8-排障速查备忘录)
9. [局域网软路由协同共存指南 (Mac 与随身WiFi双代理方案)](#9-局域网软路由协同共存指南-mac-与随身wifi双代理方案)

---

## 1. 基础核心参数 (General Settings)

### 1.1 端口与网络模式

```yaml
mixed-port: 7890          # 混合代理端口（同时支持 HTTP 与 SOCKS5）
allow-lan: false          # 是否允许局域网其他设备连接本机的代理端口
bind-address: '*'         # 监听绑定的网络接口，'*' 表示监听所有网卡
mode: rule                # 运行模式：rule (规则分流) / global (全局代理) / direct (全直连)
log-level: warning        # 日志等级：silent < error < warning < info < debug
ipv6: false               # 全局禁用 IPv6（强烈推荐设为 false，防止真实地址泄漏）
```

* **`mixed-port` 设置建议**：单端口同时支持 HTTP 和 SOCKS5，比传统分开写 `port: 7890` 和 `socks-port: 7891` 更加高效。
* **`allow-lan` 安全建议**：
  * **本机客户端**（Mac/Windows 电脑）：设为 `false`，防止同一局域网下未知设备蹭用你的代理流量。
  * **软路由/随身 WiFi**（如 F50 Pro）：必须设为 `true`，否则连入 WiFi 的手机电脑无法上网。
* **`ipv6` 为什么强烈建议设为 `false`？**
  * 国内运营商（移动/电信/联通）均分配了公网原生 IPv6；
  * 如果开启 IPv6，而您的很多代理节点不支持 IPv6，系统会“跳过代理”直接用国内真实 IPv6 直连境外目标；
  * **直接后果**：Claude、ChatGPT、Netflix 会瞬间捕获到您的国内地理位置，导致**账号秒被风控封禁**。

---

### 1.2 高性能加速与安全特性

```yaml
tcp-concurrent: true                   # 开启 TCP 并发握手（Happy Eyeballs 极速建连）
global-client-fingerprint: chrome      # 全局伪装客户端 TLS 指纹为 Chrome 原生
unified-delay: true                    # 剔除往返握手延迟偏差，测速更精准
find-process-mode: strict              # 进程级规则匹配模式（macOS/Windows 专用）
geodata-mode: true                     # 开启高效率 Geo 数据库模式
geodata-loader: memconservative        # 内存紧凑型加载（显著降低内存占用）
keep-alive-interval: 360               # TCP 长连接保活心跳间隔（秒）
```

* **`tcp-concurrent: true`（必须开启）**：
  * **原理**：基于 RFC 8305 规范，同时向目标的所有解析 IP 发起并发握手，选用最快响应的那条线路，其余握手静默取消。
  * **收益**：打开复杂网页（包含几十个 CSS/JS 静态资源的网站）时，首屏时间缩短 30%~50%，**网页秒开**！
* **`global-client-fingerprint: chrome`（防封防风控）**：
  * **原理**：Clash 原生使用的 Go 语言 TLS 握手特征与普通浏览器不同，易被 Cloudflare / 防火墙指纹识别拦截。
  * **收益**：强制伪装成真实 Google Chrome 浏览器的 TLS 握手特征，抗封锁和防封号能力大幅增强。
* **`find-process-mode: strict`**：
  * 专为 macOS / Windows 桌面客户端优化，确保规则中的 `PROCESS-NAME`（如 `Telegram`、`Discord`、`Safari`）能被准确抓取分流。

---

## 2. DNS 深度架构与防泄漏 (DNS Engine)

DNS 是透明软路由和翻墙体验中最核心的枢纽。配错 DNS 会导致**网页慢、打不开、DNS 污染和运营商审计泄漏**。

### 2.1 核心配置蓝图

```yaml
dns:
  enable: true
  listen: '0.0.0.0:1053'              # DNS 监听地址与端口
  ipv6: false                         # 彻底禁止解析 AAAA (IPv6) 记录
  enhanced-mode: fake-ip              # 增强模式：必须为 fake-ip
  fake-ip-range: 198.18.0.1/16        # 虚拟 IP 保留地址池
  use-hosts: true                     # 优先查询本地自定义 hosts
  use-system-hosts: true              # 优先查询操作系统 hosts

  # 1. 引导 DNS：仅用于首次解析 DoH 服务器自身的域名
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29

  # 2. 节点域名专用 DNS：解析机场中转服务器的域名
  proxy-server-nameserver:
    - 223.5.5.5
    - 119.29.29.29

  # 3. 国内主 DNS：解析境内日常域名
  nameserver:
    - 'https://223.5.5.5/dns-query'
    - 'https://doh.pub/dns-query'

  # 4. 海外备用加密 DNS：解析真实海外目标（彻底防污染）
  fallback:
    - 'https://1.1.1.1/dns-query'
    - 'https://dns.google/dns-query'
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

  # 5. 虚拟 IP 豁免白名单（必须返回真实公网 IP 的特殊服务）
  fake-ip-filter:
    - '*.lan'
    - '*.local'
    - '*.home.arpa'
    - 'captive.apple.com'
    - '+.pub.3gppnetwork.org'         # T-Mobile / Tello ePDG 通信网关
    - '+.3gppnetwork.org'
    - '+.t-mobile.com'
    - '+.tello.com'
    - 't-mobile.idemia.io'
    - 'stun.*.*'                      # STUN P2P / 游戏穿透
```

---

### 2.2 深度原理解析：核心痛点与避坑指南

#### ① 为什么必须坚持 `enhanced-mode: fake-ip` 而非 `redir-host`？
* **`redir-host` 的致命弊端**：
  * 请求外网时，必须等待海外 DNS 往返解析出真实 IP 才能建连，首次打开网页卡顿转圈 1~3 秒；
  * 明文向外请求 `claude.ai` 时，国内运营商基站可直接嗅探审计，且容易拿到 GFW 投毒的假 IP，**导致 Claude / OpenAI 账号被风控封号**；
  * Mihomo 官方已宣布废弃 `redir-host`。
* **`fake-ip` 的降维打击优势**：
  * **0 毫秒响应**：手机/电脑询问域名时，本地秒回虚假 IP（`198.18.x.x`）；
  * **零泄漏**：真实的域名解析由远程代理节点在海外加密完成，国内基站完全抓不到域名；
  * **极速并发**：无需等待任何 DNS 往返即可同步建立代理隧道。

#### ② 为什么 `proxy-server-nameserver` 必须填国内 DNS？
* **“鸡生蛋还是蛋生鸡”悖论**：
  * 节点未连接前，你没有代理；如果向海外 DNS 解析节点域名，会被国内防火墙阻断超时，导致**开机死锁、全网瘫痪**；
  * 现代机场全采用**国内 BGP / 专线中转机**。国内 DNS（223.5.5.5）能基于 Anycast 就近调度离你物理距离最近的专线入口机房，延迟最低。

#### ③ 什么时候必须把域名放进 `fake-ip-filter` 白名单？
遇到以下两类业务时，**必须返回真实公网 IP，严禁返回 198.18.x.x**：
1. **运营商 IMS / IPsec 语音隧道**：如 Tello、T-Mobile 的 **Wi-Fi Calling** (`*.pub.3gppnetwork.org`)。苹果/安卓基带安全模块只要检测到网关是虚假 IP，会直接拒接握手；
2. **P2P 联机与设备发现**：游戏 P2P、STUN 穿透（`stun.*.*`）、苹果连通性探测（`captive.apple.com`）。

---

## 3. TUN 虚拟网卡与透明软路由 (TUN Settings)

TUN 模式是实现“全局免设置、接上网线/WiFi就自动翻墙”的技术底座。

```yaml
tun:
  enable: true
  stack: mixed                    # 网络协议栈：mixed (推荐) / system / gvisor
  device: tun0                    # 虚拟网卡接口名称
  auto-route: true                # 自动将全局路由表默认网关接管进 TUN
  auto-detect-interface: false    # 随身 WiFi 上建议关掉，手动绑定 sipa_eth8 物理出口
  mtu: 1400                       # 关键调优：避免 5G 基带大包静默丢弃
  gso: true                       # 通用分段卸载加速（减轻 CPU 负荷）
  dns-hijack:                     # 强制劫持局域网所有设备的 DNS 流量
    - any:53
    - tcp://any:53
```

* **`stack: mixed`（性能与兼容性天花板）**：
  * TCP 采用用户态轻量化高并发栈（gVisor/lwIP），UDP 采用 Linux 原生系统栈；
  * 兼具高吞吐量与游戏 UDP 低延迟。
* **`mtu: 1400`（移动随身 WiFi 救命设置）**：
  * 很多随身 WiFi 刷了固件后默认 MTU 设为 9000（巨帧）；
  * 5G 移动蜂窝网络物理 MTU 只有 1500，巨帧数据包会被基站静默丢弃，造成死锁疯狂重传、测速慢到个位数；
  * 严格限定为 `1400` 并开启 `TCPMSS clamp-mss-to-pmtu`，即可**彻底跑满 100Mbps 蜂窝物理极限**。

---

## 4. 域名嗅探模块 (Sniffer)

解决客户端“不发域名、直接拿原始 IP 连海外服务器”导致规则失效的杀手锏。

```yaml
sniffer:
  enable: true
  parse-pure-ip: true             # 是否对纯 IP 请求进行反查解析
  sniff:
    HTTP:
      ports: [80, 8080-8880]
      override-destination: true  # 用嗅探到的真实域名覆盖目的 IP 进行重新分流
    TLS:
      ports: [443, 8443]
    QUIC:
      ports: [443, 8443]
  skip-domain:
    - 'Mijia Cloud'
    - '+.apple.com'
```

* **实战收益**：
  * Telegram、部分下载器、国际服游戏等 App，经常内置固定 IP 直连，传统规则抓不到域名；
  * 开启 `sniffer` 后，Mihomo 会在客户端进行 TLS 握手（Client Hello）的微秒瞬间，**强行嗅探提取出 SNI 真实域名**，并重新匹配到海外代理策略组，杜绝漏网。

---

## 5. 策略组类型与应用场景 (Proxy Groups)

选择合适的策略组类型与分流策略是保障**AI 账号不被封禁、推送不漏消息、下载不浪费流量、系统不卡死**的关键。

### 5.1 基础策略组类型对照 (Proxy Group Types)

| 策略组类型 (`type`) | 运行逻辑 | 最佳适用场景 | 是否适合 Claude/ChatGPT？ |
| :--- | :--- | :--- | :--- |
| **`select`** (手动选择) | 用户点哪个节点就永久固定走哪个，**绝对不跳** | **AI 问答、流媒体会员、对 IP 变动极其敏感的场景** | ✅ **强烈推荐（唯一安全模式）** |
| **`fallback`** (顺序故障转移) | 永远固定用第 1 个，第 1 个挂了才按顺序顺延换第 2 个 | 日常网页浏览、轻度外网办公 | ⚠️ 节点失效切换时有小概率 IP 突变 |
| **`url-test`** (自动延迟测速) | 每隔固定时间自动 Ping，谁延迟最低自动切到谁 | YouTube、测速、Github 下载、网页加速 | ❌ **绝对禁止**（IP 随延迟频繁变动必被封号） |
| **`load-balance`** (负载均衡) | 每次新请求在所有节点中随机轮询分发 | 多线程极速下载、爬虫、跑带宽测试 | ❌ **绝对禁止**（AI 账号秒封） |

---

### 5.2 核心专属业务策略组深度解析 (微软 / 苹果 / 谷歌FCM)

在主流机场订阅或高级分流规则中，通常会从通用代理池中单独剥离出 `Ⓜ️ 微软服务`、`🍎 苹果服务` 和 `📢 谷歌FCM` 三大专属策略组。它们的定位与调优逻辑如下：

#### ① 🍎 苹果服务 (Apple Services)
* **涵盖流量与服务**：
  * **应用分发与系统升级**：Mac App Store 软件下载、macOS/iOS 固件增量与完整镜像更新（体积往往高达数 GB 至数十 GB）。
  * **云同步生态**：iCloud 照片流、文件 Drive 同步、备忘录与钥匙串实时同步、iMessage、FaceTime。
  * **系统底层探测**：Wi-Fi 弹窗认证 (`captive.apple.com`)、公证书与应用签名在线校验 (`ocsp.apple.com`、`valid.apple.com`)。
* **为什么要独立分组（分流痛点）**：
  * **流量浪费与减速**：苹果在大陆已全面部署本地 CDN（云上贵州、腾讯云、白山云等）。如果误走代理节点，数 GB 的系统更新会极速榨干机场配额，且代理带宽往往远不如国内宽带直连。
  * **macOS 启动应用卡顿（彩虹轮）**：macOS 每次启动非系统 App 时，都会通过 OCSP 联网校验开发者签名。若该请求被转发给高延迟或故障的代理节点，会导致 Mac 打开应用时卡顿数秒甚至几十秒。
* **推荐设置策略**：
  * **绝大多数用户（国区 Apple ID）**：直接锁定为 **`🎯 绕过代理` (DIRECT)**。
  * **外区专属服务用户**：若使用外区 Apple ID 且订阅了 **Apple TV+**、**Apple News** 或美区 Apple Arcade，可将其指向 **`香港`** 或 **`美国`** 稳定节点（建议在规则层将 TV+/News 单独分流，其余保留直连）。

#### ② Ⓜ️ 微软服务 (Microsoft Services)
* **涵盖流量与服务**：
  * **办公与同步**：Office 365 网页与客户端、OneDrive 云盘同步、Microsoft Teams、SharePoint、Skype。
  * **系统与商店**：Windows Update、Microsoft Store、macOS 上的 Microsoft AutoUpdate (MAU)。
  * **AI 与前沿服务**：Microsoft Copilot、Bing 搜索与侧边栏 AI、Xbox Live 联机。
* **为什么要独立分组（分流痛点）**：
  * **矛盾的双重需求**：微软国内拥有世纪互联和本土 CDN，日常 Office 文档与 OneDrive 同步直连延迟低且不耗流量；但另一方面，**Copilot** 与部分海外版 Office 网页功能对国内 IP 实施了严格地域拦截。
* **推荐设置策略**：
  * **需要高频使用 Copilot / New Bing**：切换为 **`台湾`、`日本` 或 `美国` 稳定节点**（避免使用香港节点，部分微软 AI 服务对香港 IP 暂未全面开放）。
  * **日常仅用于 Office 文档办公与 OneDrive 同步**：推荐设置为 **`DIRECT`**，同步速度更快且杜绝浪费代理流量。

#### ③ 📢 谷歌FCM (Firebase Cloud Messaging)
* **涵盖流量与服务**：
  * Google 移动推送核心信道：`mtalk.google.com`、`alt*-mtalk.google.com` 以及专有长连接端口 `TCP 5228-5230`。
* **为什么要独立分组（分流痛点）**：
  * **跨平台通知枢纽**：不仅是 Android 系统底层的统一推送通道，许多跨平台应用（如 Telegram、Twitter/X、Gmail、部分银行 App）也高度依赖 FCM 在后台免保活接收消息通知。
  * **重连耗电与漏消息**：国内运营商对 `mtalk.google.com` 经常实施静默干扰或周期性丢包。若长连接不稳定，设备会陷入“断连 - 频繁重试 - 快速掉电”恶性循环，导致推送延迟数十分钟甚至彻底漏消息。
* **推荐设置策略**：
  * **局域网有 Android 手机或重度依赖海外 Push 消息**：必须指向 **`低延迟、极高在线率的节点`**（或由健康检查良好的 `fallback / select` 组接管），确保单一长连接全天候稳定在线。
  * **纯 Mac + iPhone 苹果全家桶用户**：iOS/macOS 设备的消息推送均由苹果自家的 APNs（走苹果服务通道）接管，极少产生 FCM 流量，设置为 **`DIRECT`** 或跟随默认代理组均可。


---

## 6. 分流规则语法与优先级 (Rules & Flow Control)

Mihomo 的规则执行遵循 **“从上到下，首条命中即终止 (First-Match)”** 的铁律。

### 6.1 常用规则语法对照

```yaml
rules:
  # 1. 域名完全匹配
  - DOMAIN,api.openai.com,🧲 海外AI

  # 2. 域名泛后缀匹配（最常用）
  - DOMAIN-SUFFIX,claude.ai,🧲 海外AI
  - DOMAIN-SUFFIX,anthropic.com,🧲 海外AI

  # 3. 关键字模糊匹配
  - DOMAIN-KEYWORD,google,🚀 节点选择

  # 4. 目标端口匹配
  - DST-PORT,500,DIRECT          # Tello Wi-Fi Calling IKEv2 直连
  - DST-PORT,4500,DIRECT

  # 5. 进程名称匹配（桌面客户端）
  - PROCESS-NAME,Telegram,📲 电报信息
  - PROCESS-NAME,Safari,DIRECT

  # 6. IP 段匹配
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve

  # 7. GeoIP / GeoSite 大数据库匹配（高效）
  - GEOSITE,cn,🎯 全球直连
  - GEOIP,CN,🎯 全球直连

  # 8. 兜底规则（未命中任何前面规则的流量）
  - MATCH,🐟 漏网之鱼
```

### 6.2 黄金规则顺序结构

1. **第 1 层：系统与特殊免代理业务**（本地私有 IP、Apple 局域网服务、Wi-Fi Calling 端口 `500/4500`）；
2. **第 2 层：高敏感业务锁定**（Claude、ChatGPT、Telegram、Netflix 专属锁定组）；
3. **第 3 层：国内大白名单**（`GEOSITE,cn` 与 `GEOIP,CN` 走直连）；
4. **第 4 层：兜底组**（`MATCH` 走海外代理策略）。

---

## 7. 开箱即用：两大黄金实践模板

### 7.1 模板 A：macOS 客户端 (Clash Verge Rev) 最佳性能配置

```yaml
mixed-port: 7890
allow-lan: false
mode: rule
log-level: warning
external-controller: '127.0.0.1:9097' # 👈 改为 9097 避开软路由/随身WiFi 9090 端口冲突
unified-delay: true
tcp-concurrent: true
global-client-fingerprint: chrome
find-process-mode: strict
ipv6: false
geodata-mode: true
geodata-loader: memconservative

cfw-bypass:
  - localhost
  - '127.*'
  - '10.*'
  - '192.168.*'
  - '<local>'

dns:
  enable: true
  listen: '0.0.0.0:7874'
  ipv6: false
  default-nameserver: [223.5.5.5, 119.29.29.29]
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  use-hosts: true
  use-system-hosts: true
  nameserver:
    - 'https://223.5.5.5/dns-query'
    - 'https://doh.pub/dns-query'
  fallback:
    - 'https://1.1.1.1/dns-query'
    - 'https://dns.google/dns-query'
  fallback-filter:
    geoip: true
    geoip-code: CN
  fake-ip-filter:
    - '*.lan'
    - '*.local'
    - 'captive.apple.com'
    - '+.pub.3gppnetwork.org'
    - '+.t-mobile.com'
    - '+.tello.com'
    - 't-mobile.idemia.io'
  proxy-server-nameserver:
    - 223.5.5.5
    - 119.29.29.29

sniffer:
  enable: true
  parse-pure-ip: true
  sniff:
    HTTP: { ports: [80, 8080-8880], override-destination: true }
    TLS: { ports: [443, 8443] }

rules:
  # 局域网与网关管理后台强制第一行直连 (防 TUN 拦截)
  - 'IP-CIDR,192.168.0.1/32,DIRECT,no-resolve'
  - 'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve'
  - 'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve'
  - 'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve'
  # ... 其他分流规则 ...
```

---

### 7.2 模板 B：随身 WiFi 软路由 (ZTE F50 Pro) 高可用配置

```yaml
port: 7890
socks-port: 7891
mixed-port: 7892
allow-lan: true
bind-address: '*'
mode: rule
log-level: info
ipv6: false
interface-name: sipa_eth8
external-controller: 0.0.0.0:9090
external-ui: /data/local/tmp/scheme_b/ui
secret: F50pro@2026!

tun:
  enable: true
  stack: mixed
  device: tun0
  auto-route: true
  auto-detect-interface: false
  mtu: 1400
  gso: true
  dns-hijack:
    - any:53
    - tcp://any:53

dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - '*.lan'
    - '+.zte.com.cn'
    - '+.pub.3gppnetwork.org'
    - '+.t-mobile.com'
    - '+.tello.com'
    - 't-mobile.idemia.io'
  default-nameserver: [223.5.5.5, 119.29.29.29]
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
    - https://dns.alidns.com/dns-query
  fallback:
    - 119.29.29.29
    - 223.5.5.5
  fallback-filter:
    geoip: true
    geoip-code: CN
  proxy-server-nameserver: [223.5.5.5, 119.29.29.29]
```

---

## 8. 排障速查备忘录

| 故障现象 | 最可能原因 | 对应检查方案 |
| :--- | :--- | :--- |
| **能登 QQ 微信，打不开任何网页** | DNS 死锁或 TUN DNS 劫持失效 | 检查 `nameserver` 是否可用，检查端口 53 劫持是否生效 |
| **国外连不上，节点测速全红** | `proxy-server-nameserver` 死锁或被墙 | 改用 `223.5.5.5`，严禁填 `127.0.0.1` 或海外被阻断 DNS |
| **Claude / ChatGPT 频繁封号** | 策略组选了自动测速或跳了国内/香港 IP | 策略组换成 `select` 并固定锁定在美国/日本优质节点，彻底关闭 IPv6 |
| **Tello Wi-Fi Calling 拉不起** | ePDG 域名被 Fake-IP 虚拟化 | 将 `+.pub.3gppnetwork.org` 加入 `fake-ip-filter`，放行端口 `500/4500` |
| **5G 随身 WiFi 网速极慢（个位数）** | TUN 默认 MTU 9000 发生巨帧丢包 | 将 TUN 的 `mtu` 严格限定为 `1400`，开启 TCPMSS 钳制 |
| **Mac 连随身 WiFi 进不去 9090/ui 后台** | Mac 本地端口冲突 (9090) 或 TUN/系统代理劫持局域网 | 本地控制端口改 9097，在 rules 最顶端置顶 192.168.0.1/32 直连，macOS 绕过添加 192.168.* |
| **链式代理 (dialer-proxy) 测速全红/报错** | 落地误填了国内中转域名，境外 VPS 回连被机房防火墙丢包 | 落地节点的 `server` 必须是真实的境外公网 IP 或 DDNS，严禁填机场国内中转域名 |
| **更新订阅报错 HTTP 400 (proxy group not found)** | 分流规则引用了不存在的策略组名称 | 检查 `proxy-groups` 确保被引用的组存在，或升级使用自动校验合并脚本 |
| **拉取机场订阅后自建节点丢失** | 客户端/脚本采取了暴力全量替换逻辑 | 采用 `custom.yaml` 独立解耦架构，通过智能合并脚本自动保留自建项并置顶 |


---

## 9. 局域网软路由协同共存指南 (Mac 与随身WiFi双代理方案)

在将随身 WiFi（如 ZTE F50 Pro）或家用 OpenWrt 部署为方案 B 透明软路由时，Mac 用户常遇到一个典型问题：
> **“Mac 连接随身 WiFi 后，打不开 `192.168.0.1:9090/ui` 软路由控制面板，只有彻底退出 Mac 本地的 Clash 才能打开，为什么？”**

### 9.1 冲突根因剖析

出现该问题的根本原因主要有三个层面：

1. **REST API 控制端口冲突 (`9090` 撞车)**：
   * 随身 WiFi 方案 B（Mihomo）默认监听 `192.168.0.1:9090`。
   * Mac 本地 Clash Verge / Clash for Windows 默认配置中的 `external-controller` 同样监听在 `127.0.0.1:9090`。
   * 当浏览器运行 MetaCubeXD / Yacd 前端时，页面向后端请求数据，请求容易被本地客户端接管或路由回环。
2. **“双重代理套娃”与 TUN 虚拟网卡劫持**：
   * 随身 WiFi 本身已经是透明软路由，全网设备已自动分流。
   * 如果 Mac 本地开启了 **TUN 模式** 或 **系统代理**，发往 `192.168.0.1` 的 TCP 连接会在 Mac 本机操作系统层面被先抓进 Mac 的虚拟网卡。若 Mac 分流规则中未置顶放行或走了 Fake-IP，该请求就无法正确触达物理局域网网关。
3. **系统代理绕过名单缺失 (macOS Proxy Bypass)**：
   * macOS 系统代理默认的忽略列表仅有 `*.local, 169.254/16`，并不包含 `192.168.0.0/16`。浏览器（Safari/Chrome）会把 `192.168.0.1` 当作普通外网 HTTP 请求转发给 `127.0.0.1:7890`。
4. **CIDR 语法格式错误**：
   * 常见配置笔误：写作 `192.168.0.1/24`（错误！单 IP 前缀必须为 `/32`，子网网段应为 `192.168.0.0/24`）。格式错误会导致内核解析规则跳过或抛弃。

---

### 9.2 两种共存姿势对比

| 方案 | 操作方式 | 适用场景 | 优点 | 缺点 |
| :--- | :--- | :--- | :--- | :--- |
| **姿势 1：无感直连 (最推荐 🌟)** | 连接随身 WiFi 时，Mac 本地**完全关闭任何代理软件** | 在外出差、随身携带 F50 Pro 移动办公 | **极致性能**：零套娃延迟；省电降耗；9090 管理面板秒开；全设备（包括 iPhone/iPad）自动无感透明翻墙。 | 离开随身 WiFi 接入普通宽带时，需手动点开 Mac 本地代理。 |
| **姿势 2：双开兼容 (极客模式)** | Mac 本地代理 24 小时常开，通过精细化配置放行局域网 | Mac 需要长期依赖本地专属规则（如指定进程分流、公司内网转发） | 无需手动开关 Mac 代理，跨网络切换平滑。 | 需要在 Mac 本地 Clash 中配置置顶放行规则并改换端口。 |

---

### 9.3 姿势 2 落地实施三步法

如果您需要 Mac 代理常开且能秒进 `192.168.0.1:9090/ui`，请按以下三步配置 Mac 本地 Clash：

#### 第一步：修改 Mac 本地 Clash 控制端口为 `9097`
在 Mac 本地订阅配置文件（`profiles/xxxx.yaml`）顶部，修改：
```yaml
external-controller: '127.0.0.1:9097'  # 避免占用 9090
```

#### 第二步：在 `rules:` 最上方第一行置顶直连网段
必须带上 `no-resolve` 参数，防止触发 DNS 反向查询：
```yaml
rules:
  # 随身 WiFi 与局域网网关最高优先级直连放行
  - 'IP-CIDR,192.168.0.1/32,DIRECT,no-resolve'
  - 'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve'
  - 'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve'
  - 'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve'
  # ... 后续其它规则 ...
```

#### 第三步：补全 macOS 系统代理忽略列表
打开 macOS 终端执行以下命令，将局域网网段加入系统的忽略代理列表：
```bash
networksetup -setproxybypassdomains "Wi-Fi" "192.168.0.0/16" "192.168.*" "10.0.0.0/8" "172.16.0.0/12" "127.0.0.1" "localhost" "*.local" "169.254/16"
networksetup -setproxybypassdomains "F50 Pro" "192.168.0.0/16" "192.168.*" "10.0.0.0/8" "172.16.0.0/12" "127.0.0.1" "localhost" "*.local" "169.254/16"
```
完成以上三步后，在 Clash Verge Rev 中点击**重新加载配置**，即可实现在 Mac 代理与 TUN 常开的情况下，随时直连访问随身 WiFi 软路由后台！
