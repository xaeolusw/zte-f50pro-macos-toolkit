#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import urllib.parse
import json
import os
import sys
import time

PORT = 8888
DEVICE = "192.168.0.1:5555"

def get_adb():
    for p in ["./bin/adb", "/opt/homebrew/bin/adb", "/usr/local/bin/adb", "adb"]:
        if os.path.exists(p) and os.access(p, os.X_OK):
            return p
    return "adb"

ADB = get_adb()

def run_adb(cmd):
    full_cmd = f"{ADB} -s {DEVICE} {cmd}"
    try:
        res = subprocess.run(full_cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
        return res.stdout.decode('utf-8', errors='ignore')
    except Exception as e:
        return str(e)

def get_screenshot():
    try:
        cmd = [ADB, "-s", DEVICE, "exec-out", "screencap", "-p"]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=4)
        if p.returncode == 0 and len(p.stdout) > 500:
            return p.stdout
    except Exception:
        pass
    return None

HTML_PAGE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>中兴 F50 Pro 实时屏幕控制台</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: #1a1a24; color: #e1e1e6; display: flex; flex-direction: column; align-items: center; padding: 20px; min-height: 100vh; }
        .header { text-align: center; margin-bottom: 16px; }
        .header h1 { font-size: 20px; color: #fff; display: flex; align-items: center; justify-content: center; gap: 8px; }
        .header p { font-size: 13px; color: #8f90a2; margin-top: 4px; }
        .container { display: flex; gap: 24px; max-width: 900px; width: 100%; justify-content: center; flex-wrap: wrap; }
        .screen-card { background: #262636; border-radius: 16px; padding: 16px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); display: flex; flex-direction: column; align-items: center; border: 1px solid #36364c; }
        .screen-wrapper { position: relative; width: 300px; height: 400px; border-radius: 8px; overflow: hidden; background: #000; box-shadow: 0 4px 12px rgba(0,0,0,0.5); cursor: crosshair; }
        #screen-img { width: 100%; height: 100%; object-fit: fill; display: block; image-rendering: pixelated; }
        .click-indicator { position: absolute; width: 24px; height: 24px; border-radius: 50%; background: rgba(0, 168, 255, 0.5); border: 2px solid #00a8ff; transform: translate(-50%, -50%); pointer-events: none; opacity: 0; transition: opacity 0.3s; }
        .controls-card { background: #262636; border-radius: 16px; padding: 20px; border: 1px solid #36364c; display: flex; flex-direction: column; gap: 16px; min-width: 300px; max-width: 360px; }
        .section-title { font-size: 13px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; color: #9a9ab0; margin-bottom: 8px; border-bottom: 1px solid #36364c; padding-bottom: 6px; }
        .btn-group { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
        .btn-group-3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
        .btn { background: #323248; color: #fff; border: 1px solid #42425e; padding: 10px 12px; border-radius: 8px; font-size: 13px; cursor: pointer; transition: all 0.2s; display: flex; align-items: center; justify-content: center; gap: 6px; }
        .btn:hover { background: #424262; border-color: #5c5c84; }
        .btn:active { transform: scale(0.97); }
        .btn-primary { background: #0070f3; border-color: #0070f3; font-weight: 600; }
        .btn-primary:hover { background: #1a82f7; }
        .btn-success { background: #10b981; border-color: #10b981; font-weight: 600; }
        .btn-success:hover { background: #22c55e; }
        .btn-danger { background: #ef4444; border-color: #ef4444; }
        .status-badge { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; color: #10b981; background: rgba(16, 185, 129, 0.1); padding: 4px 10px; border-radius: 20px; border: 1px solid rgba(16, 185, 129, 0.2); }
        .status-badge.offline { color: #ef4444; background: rgba(239, 68, 68, 0.1); border-color: rgba(239, 68, 68, 0.2); }
        .status-dot { width: 8px; height: 8px; border-radius: 50%; background: currentColor; }
        .log-box { font-family: monospace; font-size: 11px; background: #181822; padding: 8px 12px; border-radius: 6px; border: 1px solid #2b2b3a; color: #9e9eb4; height: 60px; overflow-y: auto; }
        .dpad { display: grid; grid-template-columns: repeat(3, 40px); grid-template-rows: repeat(3, 40px); gap: 4px; justify-content: center; margin: 4px 0; }
        .dpad .btn { padding: 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📱 中兴 F50 Pro 实时投屏与交互控制台</h1>
        <p>作者: shuangye | 本项目永久开源免费，严禁倒卖</p>
        <p style="font-size: 11px; color: #6e6e88; margin-top: 2px;">支持画面实时点击、Magisk 授权确认与按键导航</p>
    </div>

    <div class="container">
        <!-- 屏幕区域 -->
        <div class="screen-card">
            <div style="width: 100%; display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                <span class="status-badge" id="conn-badge"><span class="status-dot"></span> 实时已连接 (192.168.0.1)</span>
                <span style="font-size: 11px; color: #888;" id="fps-counter">刷新中...</span>
            </div>
            
            <div class="screen-wrapper" id="screen-wrapper" onclick="handleScreenClick(event)">
                <img id="screen-img" src="/screen.png" alt="Device Screen">
                <div class="click-indicator" id="indicator"></div>
            </div>

            <p style="font-size: 11px; color: #8f90a2; margin-top: 10px;">
                💡 <b>提示：可以直接用鼠标点击上方屏幕任意位置！</b>
            </p>
        </div>

        <!-- 操作面板 -->
        <div class="controls-card">
            <!-- 快捷修复按钮 -->
            <div>
                <div class="section-title">⚡️ 当前弹窗快捷操作</div>
                <div class="btn-group">
                    <button class="btn btn-primary" onclick="tapCoordinate(196, 191)">✅ 点击「确定」</button>
                    <button class="btn btn-danger" onclick="tapCoordinate(138, 191)">❌ 点击「取消」</button>
                </div>
            </div>

            <!-- Magisk 快捷操作 -->
            <div>
                <div class="section-title">🛡️ Magisk 超级用户操作</div>
                <div class="btn-group">
                    <button class="btn btn-success" onclick="openMagisk()">🏠 打开 Magisk 首页</button>
                    <button class="btn" onclick="tapCoordinate(225, 18)">⚙️ 点击右上角设置</button>
                </div>
                <div style="margin-top: 8px;">
                    <button class="btn" style="width: 100%;" onclick="grantRootPolicy()">🚀 一键解锁 ADB Root 权限</button>
                </div>
            </div>

            <!-- 方向键与确认 -->
            <div>
                <div class="section-title">🕹️ 虚拟导航键 (DPAD)</div>
                <div style="display: flex; justify-content: center;">
                    <div class="dpad">
                        <div></div>
                        <button class="btn" onclick="sendKey(19)">⬆️</button>
                        <div></div>
                        <button class="btn" onclick="sendKey(21)">⬅️</button>
                        <button class="btn btn-primary" onclick="sendKey(66)">OK</button>
                        <button class="btn" onclick="sendKey(22)">➡️</button>
                        <div></div>
                        <button class="btn" onclick="sendKey(20)">⬇️</button>
                        <div></div>
                    </div>
                </div>
            </div>

            <!-- 系统按键 -->
            <div>
                <div class="section-title">📱 系统按键</div>
                <div class="btn-group-3">
                    <button class="btn" onclick="sendKey(4)">🔙 返回</button>
                    <button class="btn" onclick="sendKey(3)">🏠 主页</button>
                    <button class="btn" onclick="sendKey(187)">📋 任务</button>
                </div>
                <div class="btn-group" style="margin-top: 8px;">
                    <button class="btn" onclick="sendKey(26)">💡 唤醒/息屏</button>
                    <button class="btn" onclick="sendKey(61)">⇥ TAB 键</button>
                </div>
            </div>

            <!-- 日志 -->
            <div class="log-box" id="log-box">就绪。正在保持实时画面推流...</div>
        </div>
    </div>

    <script>
        const img = document.getElementById('screen-img');
        const wrapper = document.getElementById('screen-wrapper');
        const indicator = document.getElementById('indicator');
        const logBox = document.getElementById('log-box');
        const fpsCounter = document.getElementById('fps-counter');

        let lastTime = Date.now();
        let frameCount = 0;

        function log(msg) {
            logBox.innerText = msg;
        }

        // 刷新屏幕帧
        function updateScreen() {
            const nextImg = new Image();
            nextImg.src = '/screen.png?t=' + Date.now();
            nextImg.onload = () => {
                img.src = nextImg.src;
                frameCount++;
                const now = Date.now();
                if (now - lastTime >= 2000) {
                    const fps = (frameCount / ((now - lastTime) / 1000)).toFixed(1);
                    fpsCounter.innerText = fps + ' FPS';
                    frameCount = 0;
                    lastTime = now;
                }
                setTimeout(updateScreen, 200);
            };
            nextImg.onerror = () => {
                setTimeout(updateScreen, 800);
            };
        }
        updateScreen();

        // 鼠标点击屏幕转换
        function handleScreenClick(e) {
            const rect = wrapper.getBoundingClientRect();
            const clickX = e.clientX - rect.left;
            const clickY = e.clientY - rect.top;

            // 显示点击指示点
            indicator.style.left = clickX + 'px';
            indicator.style.top = clickY + 'px';
            indicator.style.opacity = '1';
            setTimeout(() => { indicator.style.opacity = '0'; }, 300);

            // 映射到 240 x 320 实际坐标
            const realX = Math.round((clickX / rect.width) * 240);
            const realY = Math.round((clickY / rect.height) * 320);

            tapCoordinate(realX, realY);
        }

        function tapCoordinate(x, y) {
            log(`点击坐标: (${x}, ${y})...`);
            fetch(`/tap?x=${x}&y=${y}`)
                .then(r => r.json())
                .then(d => log(`点击完成: (${x}, ${y})`))
                .catch(e => log(`点击失败: ${e}`));
        }

        function sendKey(code) {
            log(`发送按键码: ${code}...`);
            fetch(`/key?code=${code}`)
                .then(r => r.json())
                .then(d => log(`按键已发送: ${code}`))
                .catch(e => log(`按键失败: ${e}`));
        }

        function openMagisk() {
            log('正在打开 Magisk...');
            fetch('/open_magisk')
                .then(r => r.json())
                .then(d => log('Magisk 已启动'))
                .catch(e => log(`打开失败: ${e}`));
        }

        function grantRootPolicy() {
            log('正在配置 Root 权限策略...');
            fetch('/grant_root')
                .then(r => r.json())
                .then(d => log(d.msg))
                .catch(e => log(`配置失败: ${e}`));
        }
    </script>
</body>
</html>
"""

class RequestHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass # 静默常规访问日志

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "/index.html":
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode("utf-8"))
        elif path == "/screen.png":
            data = get_screenshot()
            if data:
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_response(503)
                self.end_headers()
        elif path == "/tap":
            qs = urllib.parse.parse_qs(parsed.query)
            x = qs.get("x", ["0"])[0]
            y = qs.get("y", ["0"])[0]
            # 多重模拟点击：touchscreen, mouse, input motionevent
            run_adb(f"shell 'input touchscreen tap {x} {y} || input mouse tap {x} {y}'")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "x": x, "y": y}).encode())
        elif path == "/key":
            qs = urllib.parse.parse_qs(parsed.query)
            code = qs.get("code", ["0"])[0]
            run_adb(f"shell input keyevent {code}")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "code": code}).encode())
        elif path == "/open_magisk":
            run_adb("shell am start -n com.topjohnwu.magisk/.ui.MainActivity")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())
        elif path == "/grant_root":
            # 尝试通过 magiskd 触发授权
            res = run_adb("shell 'am broadcast -a com.topjohnwu.magisk.action.GRANT 2>/dev/null'")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok", "msg": "已触发授权广播"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), RequestHandler) as httpd:
        print(f"Server started at http://127.0.0.1:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
