#!/bin/bash
# 龙虾计划 - Chromium安装诊断工具
# 诊断安装失败的原因

echo "🦞 龙虾计划 - Chromium安装诊断"
echo "================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查容器状态
echo "1️⃣ 检查容器状态..."
if docker ps | grep -q "lobster-xhs-bot"; then
    echo -e "${GREEN}✅ 容器运行正常${NC}"
else
    echo -e "${RED}❌ 容器未运行${NC}"
    echo "请先执行: docker-compose up -d"
    exit 1
fi
echo ""

# 检查磁盘空间
echo "2️⃣ 检查磁盘空间..."
DISK_USAGE=$(docker exec lobster-xhs-bot df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✅ 磁盘空间充足 (${DISK_USAGE}%)${NC}"
else
    echo -e "${RED}❌ 磁盘空间不足 (${DISK_USAGE}%)${NC}"
    echo "需要至少200MB可用空间"
fi
docker exec lobster-xhs-bot df -h
echo ""

# 检查内存
echo "3️⃣ 检查内存..."
MEMORY_INFO=$(docker exec lobster-xhs-bot free -h | grep Mem)
echo "$MEMORY_INFO"
echo ""

# 检查网络连通性 - Playwright下载服务器
echo "4️⃣ 检查Playwright下载服务器..."
docker exec lobster-xhs-bot python3 << 'PYTHON_SCRIPT'
import urllib.request
import socket
import sys

print("测试DNS解析...")
try:
    ip = socket.gethostbyname('playwright.azureedge.net')
    print(f"✅ DNS解析成功: {ip}")
except Exception as e:
    print(f"❌ DNS解析失败: {e}")
    sys.exit(1)

print("\n测试HTTP连接...")
try:
    req = urllib.request.Request(
        'https://playwright.azureedge.net/',
        method='HEAD',
        headers={'User-Agent': 'Mozilla/5.0'}
    )
    response = urllib.request.urlopen(req, timeout=10)
    print(f"✅ HTTP连接成功: {response.status}")
except Exception as e:
    print(f"❌ HTTP连接失败: {e}")
    sys.exit(1)

print("\n测试Chromium下载URL...")
try:
    # 尝试获取Chromium版本信息
    url = 'https://raw.githubusercontent.com/microsoft/playwright/main/packages/playwright-core/browsers.json'
    response = urllib.request.urlopen(url, timeout=10)
    print(f"✅ 可以访问GitHub: {response.status}")
except Exception as e:
    print(f"⚠️ GitHub访问受限: {e}")

PYTHON_SCRIPT

if [ $? -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ 网络连接问题！${NC}"
    echo "可能原因："
    echo "  - 服务器无法访问外网"
    echo "  - DNS解析失败"
    echo "  - 防火墙阻止了连接"
    echo ""
    echo "解决方案："
    echo "  1. 检查服务器网络配置"
    echo "  2. 配置DNS（如8.8.8.8）"
    echo "  3. 使用代理服务器"
    exit 1
fi

echo ""
echo "5️⃣ 测试Chromium安装..."
docker exec lobster-xhs-bot timeout 120 python3 -c "
import subprocess
import sys

print('开始安装Chromium（最多2分钟）...')
result = subprocess.run(
    [sys.executable, '-m', 'playwright', 'install', 'chromium'],
    capture_output=True,
    text=True,
    timeout=120
)

print('STDOUT:', result.stdout[-1000:] if len(result.stdout) > 1000 else result.stdout)
print('STDERR:', result.stderr[-500:] if len(result.stderr) > 500 else result.stderr)
print('退出码:', result.returncode)

if result.returncode != 0:
    sys.exit(1)
" 2>&1

INSTALL_RESULT=$?
echo ""

# 验证安装
echo "6️⃣ 验证安装结果..."
if docker exec lobster-xhs-bot ls /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Chromium安装成功！${NC}"
    docker exec lobster-xhs-bot ls -lh /root/.cache/ms-playwright/chromium-*/chrome-linux/chrome
    echo ""
    echo "🎉 诊断完成！Chromium已就绪"
    echo ""
    echo "下一步："
    echo "  docker-compose restart"
    echo "  然后访问: http://你的服务器IP:8080/qr-image"
else
    if [ $INSTALL_RESULT -eq 124 ]; then
        echo -e "${YELLOW}⚠️ 安装超时（超过2分钟）${NC}"
        echo "可能原因：网络慢或被限制"
    else
        echo -e "${RED}❌ 安装失败${NC}"
    fi
    echo ""
    echo "建议解决方案："
    echo "  1. 检查服务器是否能访问外网"
    echo "  2. 配置镜像代理（如阿里云镜像）"
    echo "  3. 手动下载Chromium并复制到容器"
fi

echo ""
echo "诊断完成时间: $(date)"
