#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ========================================================
# 中兴 F50 Pro 方案B: 订阅配置与自建节点智能合并引擎
# 作者: shuangye (https://github.com/shuangye)
# 本项目永久开源免费，严禁任何形式的商业倒卖与转售
# ========================================================

import sys
import os
import urllib.request
import yaml

def load_yaml(file_path):
    if not os.path.isfile(file_path):
        return {}
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except Exception as e:
        print(f"[!] 读取 YAML 失败 ({file_path}): {e}")
        return {}

def merge_subscription(sub_source, base_path, output_path):
    print(f"[*] 正在读取底模配置: {base_path}")
    base_cfg = load_yaml(base_path)

    # 检查是否存在同目录下的 custom.yaml
    custom_path = os.path.join(os.path.dirname(base_path), "custom.yaml")
    custom_cfg = {}
    if os.path.isfile(custom_path):
        print(f"[*] 检测到专属自定配置文件: {custom_path}")
        custom_cfg = load_yaml(custom_path)
    else:
        print("[-] 未找到 custom.yaml，将仅进行基础合并。")

    sub_cfg = {}
    # 如果 sub_source 为空或为 "self"/"local"，表示仅重新将 custom.yaml 应用到现有 base_cfg
    if sub_source in ("", "self", "local", "none"):
        print("[*] 正在基于现有配置重新融合 custom.yaml 自建节点与规则...")
        sub_cfg = dict(base_cfg)
    elif sub_source.startswith("http://") or sub_source.startswith("https://"):
        print(f"[*] 正在从订阅链接下载节点配置: {sub_source}")
        headers = {
            'User-Agent': 'ClashMeta/1.19.32'
        }
        req = urllib.request.Request(sub_source, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                sub_content = resp.read().decode('utf-8')
                sub_cfg = yaml.safe_load(sub_content) or {}
        except Exception as e:
            print(f"[!] 订阅下载/解析失败: {e}")
            return False
    elif os.path.isfile(sub_source):
        print(f"[*] 正在从本地文件读取机场配置: {sub_source}")
        sub_cfg = load_yaml(sub_source)
    else:
        print(f"[!] 错误: 无效的订阅源 {sub_source}")
        return False

    # 1. 基础配置复制（保留 F50 Pro 专用的 TUN、DNS、网卡接口、面板路径与密钥）
    merged = dict(base_cfg)

    # 提取机场订阅或现有配置的节点与策略
    sub_proxies = sub_cfg.get('proxies') or []
    sub_groups = sub_cfg.get('proxy-groups') or []
    sub_rules = sub_cfg.get('rules') or []
    sub_rule_providers = sub_cfg.get('rule-providers') or {}

    # 2. 合并自建 Proxies (自建节点置顶，按 name 去重)
    custom_proxies = custom_cfg.get('proxies') or []
    custom_proxy_names = {p['name'] for p in custom_proxies if isinstance(p, dict) and 'name' in p}

    filtered_sub_proxies = [
        p for p in sub_proxies
        if isinstance(p, dict) and p.get('name') not in custom_proxy_names
    ]
    final_proxies = custom_proxies + filtered_sub_proxies
    merged['proxies'] = final_proxies
    print(f"[+] 代理节点合并完成: {len(custom_proxies)} 个自建/链式节点 + {len(filtered_sub_proxies)} 个机场节点")

    # 3. 合并自建 Proxy-Groups
    custom_groups = custom_cfg.get('proxy-groups') or []
    custom_group_names = {g['name'] for g in custom_groups if isinstance(g, dict) and 'name' in g}

    filtered_sub_groups = [
        g for g in sub_groups
        if isinstance(g, dict) and g.get('name') not in custom_group_names
    ]
    final_groups = list(custom_groups) + list(filtered_sub_groups)

    # 4. 执行自建节点注入到机场策略组 (inject_into_groups)
    inject_list = custom_cfg.get('inject_into_groups') or []
    if inject_list:
        group_dict = {g['name']: g for g in final_groups if isinstance(g, dict) and 'name' in g}
        for item in inject_list:
            target_group_name = item.get('group_name')
            add_proxies = item.get('add_proxies') or []
            if target_group_name in group_dict:
                grp = group_dict[target_group_name]
                cur_proxies = grp.get('proxies') or []
                # 倒序将需要注入的节点插入到最前面，保持指定顺序且不重复
                for p_name in reversed(add_proxies):
                    if p_name in cur_proxies:
                        cur_proxies.remove(p_name)
                    cur_proxies.insert(0, p_name)
                grp['proxies'] = cur_proxies
                print(f"[+] 成功将自建项注入到机场策略组: [{target_group_name}] -> {add_proxies}")

    merged['proxy-groups'] = final_groups

    # 5. 合并 rule-providers
    if sub_rule_providers:
        merged['rule-providers'] = sub_rule_providers
    if 'rule-providers' in custom_cfg and custom_cfg['rule-providers']:
        if 'rule-providers' not in merged:
            merged['rule-providers'] = {}
        merged['rule-providers'].update(custom_cfg['rule-providers'])

    # 6. 合并 Rules (自建规则置顶)
    custom_rules = custom_cfg.get('rules') or []
    all_group_names = {g['name'] for g in final_groups if isinstance(g, dict) and 'name' in g}
    all_group_names.update(['DIRECT', 'REJECT', 'GLOBAL', 'PASS', 'COMPATIBLE'])
    all_proxy_names = {p['name'] for p in final_proxies if isinstance(p, dict) and 'name' in p}
    valid_targets = all_group_names | all_proxy_names

    sanitized_custom_rules = []
    for r in custom_rules:
        parts = [p.strip() for p in r.split(',')]
        if len(parts) >= 3:
            target = parts[2]
            # 如果目标是“🎯 绕过代理”但机场配置里没有这个组，自动回退到 DIRECT
            if target not in valid_targets:
                if target == "🎯 绕过代理":
                    parts[2] = "DIRECT"
                    sanitized_r = ",".join(parts)
                    sanitized_custom_rules.append(sanitized_r)
                    continue
                else:
                    print(f"[!] 警告: 规则目标 [{target}] 不存在，请检查 custom.yaml！")
        sanitized_custom_rules.append(r)

    # 去重合并规则：自建规则排在最前面
    seen_rules = set(sanitized_custom_rules)
    final_rules = list(sanitized_custom_rules)
    for r in sub_rules:
        parts = [p.strip() for p in r.split(',')]
        if len(parts) >= 3 and parts[2] in custom_group_names:
            # 过滤历史残留的自建策略规则（以 custom.yaml 中的声明为准）
            continue
        if r not in seen_rules:
            final_rules.append(r)
            seen_rules.add(r)

    merged['rules'] = final_rules
    print(f"[+] 分流规则合并完成: {len(sanitized_custom_rules)} 条专属置顶规则 + {len(final_rules) - len(sanitized_custom_rules)} 条通用规则")

    # 7. 写入最终输出文件
    with open(output_path, 'w', encoding='utf-8') as f:
        yaml.dump(merged, f, allow_unicode=True, sort_keys=False)

    print(f"[🎉] 配置智能合并成功！已写入: {output_path}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("用法: python3 merge_sub.py <sub_url_or_file_or_empty> <base_config> <output_config>")
        sys.exit(1)
    sub = sys.argv[1]
    base = sys.argv[2]
    out = sys.argv[3]
    success = merge_subscription(sub, base, out)
    sys.exit(0 if success else 1)
