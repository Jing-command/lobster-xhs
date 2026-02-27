#!/bin/bash
# 龙虾计划 - Chromium安装脚本
# 带进度显示，解决二维码生成问题

set -e

echo "🦞 龙虾计划 - Chromium安装工具"
echo "================================"
echo ""

# 检查容器是否运行
echo "🔍 检查容器状态..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 错误：容器 lobster-xhs-bot 未运行"
    echo "请先执行: docker-compose up -d"
    exit 1
fi
echo "✅ 容器运行正常"
echo ""

# 检查当前Chromium状态
echo "🔍 检查当前Chromium安装状态..."
if docker exec lobster-xhs-bot ls /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome >/dev/null 2>&1; then
    echo "✅ Chromium已安装"
    docker exec lobster-xhs-bot ls -lh /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome
    echo ""
    echo "🎉 无需重新安装！"
    exit 0
else
    echo "⚠️ Chromium未安装，需要下载安装"
fi
echo ""

# 安装Chromium
echo "📥 开始安装Chromium（约需5-10分钟）..."
echo "   下载大小：约100MB"
echo ""

# 使用Python安装并显示进度
docker exec lobster-xhs-bot python3 << 'PYTHON_EOF'
import subprocess
import sys
import time
import threading

def show_spinner():
    """显示旋转进度条"""
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    i = 0
    while not stop_spinner:
        print(f"\r⏳ 正在下载... {spinner[i]} ", end='', flush=True)
        i = (i + 1) % len(spinner)
        time.sleep(0.1)
    print("\r✅ 下载完成！   ")

# 启动进度条
stop_spinner = False
spinner_thread = threading.Thread(target=show_spinner)
spinner_thread.start()

# 执行安装
try:
    result = subprocess.run(
        [sys.executable, "-m", "playwright", "install", "chromium"],
        capture_output=True,
        text=True,
        timeout=600  # 10分钟超时
    )
    stop_spinner = True
    spinner_thread.join()
    
    if result.returncode == 0:
        print("✅ Chromium安装成功！")
        if result.stdout:
            print("输出:", result.stdout[-500:] if len(result.stdout) > 500 else result.stdout)
    else:
        print("❌ 安装失败！")
        print("错误输出:", result.stderr)
        sys.exit(1)
except subprocess.TimeoutExpired:
    stop_spinner = True
    spinner_thread.join()
    print("❌ 安装超时（超过10分钟）")
    sys.exit(1)
except Exception as e:
    stop_spinner = True
    spinner_thread.join()
    print(f"❌ 发生错误: {e}")
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Chromium安装失败"
    exit 1
fi

echo ""
echo "🔍 验证安装结果..."
if docker exec lobster-xhs-bot ls /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome >/dev/null 2>&1; then
    echo "✅ Chromium验证成功！"
    docker exec lobster-xhs-bot ls -lh /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome
    echo ""
    echo "🎉 安装完成！"
    echo ""
    echo "下一步："
    echo "  1. 重启容器: docker-compose restart"
    echo "  2. 访问: http://你的服务器IP:8080/qr-image"
    echo "  3. 使用手机小红书APP扫码登录"
else
    echo "❌ 安装验证失败"
    echo "请检查日志: docker-compose logs"
    exit 1
fi
