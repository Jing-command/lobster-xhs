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
echo "2️⃣ 测试网络连通性..."
docker exec lobster-xhs-bot python3 << 'PY_EOF'
import socket
import urllib.request
import sys

def test_dns():
    """测试DNS解析"""
    print("测试DNS解析...")
    hosts = [
        ('playwright.azureedge.net', 'Playwright服务器'),
        ('www.baidu.com', '百度'),
        ('www.google.com', 'Google'),
        ('8.8.8.8', 'Google DNS')
    ]
    
    for host, name in hosts:
        try:
            if host.replace('.', '').isdigit():
                print(f"  ✅ {name}: {host} (IP地址)")
            else:
                ip = socket.gethostbyname(host)
                print(f"  ✅ {name}: {host} -> {ip}")
        except Exception as e:
            print(f"  ❌ {name}: {host} -> {e}")

def test_http():
    """测试HTTP连接"""
    print("\n测试HTTP访问...")
    urls = [
        ('https://www.baidu.com', '百度'),
        ('https://playwright.azureedge.net', 'Playwright服务器'),
    ]
    
    for url, name in urls:
        try:
            req = urllib.request.Request(url, method='HEAD', 
                headers={'User-Agent': 'Mozilla/5.0'})
            response = urllib.request.urlopen(req, timeout=10)
            print(f"  ✅ {name}: HTTP {response.status}")
        except Exception as e:
            print(f"  ❌ {name}: {e}")

def test_chromium_download():
    """测试Chromium下载URL"""
    print("\n测试Chromium下载...")
    try:
        # Playwright浏览器信息URL
        url = 'https://raw.githubusercontent.com/microsoft/playwright/main/packages/playwright-core/browsers.json'
        req = urllib.request.Request(url, 
            headers={'User-Agent': 'Mozilla/5.0'})
        response = urllib.request.urlopen(req, timeout=10)
        data = response.read().decode('utf-8')
        if 'chromium' in data:
            print("  ✅ 可以访问Playwright浏览器配置")
        else:
            print("  ⚠️ 返回数据异常")
    except Exception as e:
        print(f"  ❌ 无法访问: {e}")
        print("  可能原因：GitHub被墙或网络受限")

if __name__ == '__main__':
    test_dns()
    test_http()
    test_chromium_download()
PY_EOF

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Python测试失败，容器内可能没有Python或网络完全不通"
    echo ""
    echo "尝试进入容器手动检查："
    echo "  docker exec -it lobster-xhs-bot bash"
    echo "  python3 -c \"print('test')\""
    exit 1
fi

echo ""
echo "3️⃣ 检查DNS配置..."
docker exec lobster-xhs-bot cat /etc/resolv.conf 2>/dev/null || echo "无法读取DNS配置"

echo ""
echo "======================="
echo "诊断完成！"
echo ""
echo "如果网络不通，解决方案："
echo "  1. 配置Docker DNS："
echo "     echo '{\"dns\": [\"8.8.8.8\", \"114.114.114.114\"]}' > /etc/docker/daemon.json"
echo "     systemctl restart docker"
echo ""
echo "  2. 重启容器："
echo "     cd /opt/lobster-xhs && docker-compose up -d"
echo ""
echo "  3. 如果服务器完全无法访问外网，需要配置代理或手动下载Chromium"
