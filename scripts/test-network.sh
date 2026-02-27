#!/bin/bash
# 龙虾计划 - 网络连通性测试
# 测试容器是否能访问外网

echo "🦞 龙虾计划 - 网络诊断"
echo "======================="
echo ""

# 检查容器
echo "1️⃣ 检查容器状态..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器运行正常"
echo ""

# 使用Python进行网络测试
echo "2️⃣ 测试网络连通性（等待结果，最多30秒）..."
echo ""

# 创建临时Python脚本
cat > /tmp/network_test.py << 'PYTHON_CODE'
import socket
import urllib.request
import sys
import time

def test_dns():
    print("=" * 40)
    print("测试DNS解析...")
    print("=" * 40)
    hosts = [
        ('playwright.azureedge.net', 'Playwright服务器'),
        ('www.baidu.com', '百度'),
        ('www.google.com', 'Google'),
    ]
    
    for host, name in hosts:
        try:
            ip = socket.gethostbyname(host)
            print(f"✅ {name}: {host}")
            print(f"   IP: {ip}")
        except Exception as e:
            print(f"❌ {name}: {host}")
            print(f"   错误: {e}")
    print()

def test_http():
    print("=" * 40)
    print("测试HTTP连接...")
    print("=" * 40)
    urls = [
        ('https://www.baidu.com', '百度'),
        ('https://playwright.azureedge.net', 'Playwright服务器'),
    ]
    
    for url, name in urls:
        try:
            req = urllib.request.Request(url, method='HEAD', 
                headers={'User-Agent': 'Mozilla/5.0'})
            response = urllib.request.urlopen(req, timeout=15)
            print(f"✅ {name}: HTTP {response.status}")
        except Exception as e:
            print(f"❌ {name}: {str(e)[:100]}")
    print()

def test_chromium():
    print("=" * 40)
    print("测试Chromium下载地址...")
    print("=" * 40)
    try:
        url = 'https://raw.githubusercontent.com/microsoft/playwright/main/packages/playwright-core/browsers.json'
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        response = urllib.request.urlopen(req, timeout=15)
        print(f"✅ 可以访问Playwright配置: HTTP {response.status}")
    except Exception as e:
        print(f"❌ 无法访问Playwright配置")
        print(f"   错误: {str(e)[:100]}")
    print()

if __name__ == '__main__':
    test_dns()
    test_http()
    test_chromium()
    print("=" * 40)
    print("网络测试完成")
    print("=" * 40)
PYTHON_CODE

# 复制脚本到容器并执行
docker cp /tmp/network_test.py lobster-xhs-bot:/tmp/
docker exec lobster-xhs-bot python3 /tmp/network_test.py

TEST_RESULT=$?

if [ $TEST_RESULT -ne 0 ]; then
    echo ""
    echo "❌ Python测试执行失败"
    echo ""
    echo "尝试进入容器手动检查："
    echo "  docker exec -it lobster-xhs-bot bash"
    echo "  python3 -c \"import socket; print(socket.gethostbyname('baidu.com'))\""
    exit 1
fi

echo ""
echo "3️⃣ 检查DNS配置..."
echo "容器内的DNS配置："
docker exec lobster-xhs-bot cat /etc/resolv.conf 2>/dev/null || echo "无法读取DNS配置"

echo ""
echo "======================="
echo "诊断完成！"
echo ""
echo "如果网络不通，解决方案："
echo ""
echo "方案1: 配置Docker DNS（推荐）"
echo "  sudo bash -c 'echo \"{\\\"dns\\\": [\\\"8.8.8.8\\\", \\\"114.114.114.114\\\"]}\" > /etc/docker/daemon.json'"
echo "  sudo systemctl restart docker"
echo "  cd /opt/lobster-xhs && docker-compose up -d"
echo ""
echo "方案2: 如果服务器无法访问外网"
echo "  需要手动下载Chromium并导入容器"
