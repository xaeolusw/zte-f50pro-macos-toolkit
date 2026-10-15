#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ========================================================
# 中兴 F50 Pro 方案B: 订阅配置合并工具
# 作者: shuangye (https://github.com/shuangye)
# 本项目永久开源免费，严禁任何形式的商业倒卖与转售
# ========================================================

import sys
import os
import urllib.request
import yaml

def merge_subscription(sub_source, base_path, output_path):
    print(f"[*] 正在读取模板配置: {base_path}")
    with open(base_path, 'r', encoding='utf-8') as f:
        base_cfg = yaml.safe_load(f) or {}

    sub_content = ""
    if sub_source.startswith("http://") or sub_source.startswith("https://"):
        print(f"[*] 正在从订阅链接下载节点配置...")
        headers = {'User-Agent': 'ClashMeta/1.19.32'}
        req = urllib.request.Request(sub_source, headers=headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            sub_content = resp.read().decode('utf-8')
    elif os.path.isfile(sub_source):
        print(f"[*] 正在从本地文件读取配置: {sub_source}")
        with open(sub_source, 'r', encoding='utf-8') as f:
            sub_content = f.read()
    else:
        print(f"[!] 错误: 无效的订阅源 {sub_source}")
        return False

    sub_cfg = yaml.safe_load(sub_content) or {}

    # 合并关键字段: 保留 F50 Pro 软路由专用 TUN / DNS / WebUI，合并订阅节点的 proxies / rules
    merged = dict(base_cfg)
    
    # 继承订阅的代理节点与策略组
    if 'proxies' in sub_cfg and sub_cfg['proxies']:
        merged['proxies'] = sub_cfg['proxies']
        print(f"[+] 成功提取到 {len(sub_cfg['proxies'])} 个代理节点")

    if 'proxy-groups' in sub_cfg and sub_cfg['proxy-groups']:
        merged['proxy-groups'] = sub_cfg['proxy-groups']
        print(f"[+] 成功提取到 {len(sub_cfg['proxy-groups'])} 个策略组")

    if 'rule-providers' in sub_cfg and sub_cfg['rule-providers']:
        merged['rule-providers'] = sub_cfg['rule-providers']

    if 'rules' in sub_cfg and sub_cfg['rules']:
        merged['rules'] = sub_cfg['rules']
        print(f"[+] 成功提取到分流规则")

    with open(output_path, 'w', encoding='utf-8') as f:
        yaml.dump(merged, f, allow_unicode=True, sort_keys=False)

    print(f"[+] 合并完成，已生成新配置文件: {output_path}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("用法: python3 merge_sub.py <sub_url_or_file> <base_config> <output_config>")
        sys.exit(1)
    sub = sys.argv[1]
    base = sys.argv[2]
    out = sys.argv[3]
    success = merge_subscription(sub, base, out)
    sys.exit(0 if success else 1)
