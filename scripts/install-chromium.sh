#!/bin/bash
# 龙虾计划 - Chromium安装脚本（实时输出版）
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
echo "📥 开始安装Chromium（约需3-5分钟）..."
echo "   下载大小：约100MB"
echo "   会显示实时进度，请耐心等待..."
echo ""

# 创建安装脚本
cat > /tmp/install_chromium.py << 'PYTHON_SCRIPT'
import subprocess
import sys
import os

print("=" * 50)
print("开始下载并安装Chromium...")
print("=" * 50)
print()

# 使用Popen实时显示输出
process = subprocess.Popen(
    [sys.executable, "-m", "playwright", "install", "chromium"],
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True,
    bufsize=1
)

# 实时读取并显示输出
for line in process.stdout:
    print(line, end='')
    sys.stdout.flush()

# 等待进程结束
process.wait()

print()
print("=" * 50)
if process.returncode == 0:
    print("✅ Chromium安装成功！")
    print("=" * 50)
    sys.exit(0)
else:
    print(f"❌ 安装失败，退出码: {process.returncode}")
    print("=" * 50)
    sys.exit(1)
PYTHON_SCRIPT

# 复制到容器并执行
docker cp /tmp/install_chromium.py lobster-xhs-bot:/tmp/

# 执行安装（带超时5分钟）
echo "⏳ 正在安装（超时时间：5分钟）..."
echo ""

timeout 300 docker exec lobster-xhs-bot python3 /tmp/install_chromium.py

INSTALL_EXIT=$?

if [ $INSTALL_EXIT -eq 124 ]; then
    echo ""
    echo "❌ 安装超时（超过5分钟）"
    echo "可能原因：网络速度慢或下载被中断"
    echo "建议：检查网络后重试"
    exit 1
elif [ $INSTALL_EXIT -ne 0 ]; then
    echo ""
    echo "❌ 安装失败"
    exit 1
fi

echo ""
echo "🔍 验证安装结果..."
# 使用find查找chrome可执行文件
CHROME_PATH=$(docker exec lobster-xhs-bot bash -c "find /root/.cache/ms-playwright -name 'chrome' -type f 2>/dev/null | head -1")
if [ -n "$CHROME_PATH" ]; then
    echo "✅ Chromium验证成功！"
    echo "路径: $CHROME_PATH"
    docker exec lobster-xhs-bot ls -lh "$CHROME_PATH"
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
