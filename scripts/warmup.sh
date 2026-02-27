#!/bin/bash
# 龙虾计划 - 浏览器预热脚本
# Chromium第一次启动很慢，预热后二维码生成会快很多

echo "🦞 龙虾计划 - 浏览器预热"
echo "========================"
echo ""

# 检查容器
echo "1️⃣ 检查容器状态..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器运行正常"
echo ""

# 创建预热脚本
cat > /tmp/warmup.py << 'PYTHON_SCRIPT'
import asyncio
from playwright.async_api import async_playwright
import sys

async def warmup():
    print("=" * 50)
    print("开始预热浏览器...")
    print("=" * 50)
    print()
    
    try:
        async with async_playwright() as p:
            print("⏳ 启动 Chromium 浏览器...")
            print("   (第一次启动需要 30-60 秒，请耐心等待)")
            print()
            
            browser = await p.chromium.launch(headless=True)
            print("✅ 浏览器启动成功！")
            print()
            
            page = await browser.new_page()
            print("⏳ 访问小红书...")
            
            await page.goto("https://www.xiaohongshu.com", timeout=60000)
            print("✅ 小红书页面加载成功！")
            print()
            
            # 截图保存
            await page.screenshot(path="/app/data/warmup_screenshot.png")
            print("✅ 测试截图已保存到 /app/data/warmup_screenshot.png")
            print()
            
            await browser.close()
            print("✅ 浏览器已关闭")
            print()
            print("=" * 50)
            print("🎉 预热完成！浏览器已准备好")
            print("=" * 50)
            print()
            print("现在可以访问: http://你的服务器IP:8080/qr-image")
            return True
            
    except Exception as e:
        print()
        print("=" * 50)
        print(f"❌ 预热失败: {e}")
        print("=" * 50)
        return False

if __name__ == '__main__':
    success = asyncio.run(warmup())
    sys.exit(0 if success else 1)
PYTHON_SCRIPT

# 复制到容器
docker cp /tmp/warmup.py lobster-xhs-bot:/tmp/

echo "2️⃣ 开始预热浏览器..."
echo "   预计时间：30-60秒"
echo ""

# 执行预热
docker exec lobster-xhs-bot python3 /tmp/warmup.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 预热成功！"
    echo ""
    echo "现在可以测试二维码生成了："
    echo "  浏览器访问: http://你的服务器IP:8080/qr-image"
    echo "  或命令行: curl http://localhost:8080/qr-image -o qr.png"
    echo ""
    echo "📸 测试截图位置:"
    docker exec lobster-xhs-bot ls -lh /app/data/warmup_screenshot.png 2>/dev/null || echo "   截图未生成"
else
    echo ""
    echo "❌ 预热失败"
    echo "请检查日志: docker-compose logs"
    exit 1
fi
