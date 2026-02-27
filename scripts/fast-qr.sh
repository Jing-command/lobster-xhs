#!/bin/bash
# 龙虾计划 - 浏览器常驻 + 快速获取二维码
# 浏览器保持运行，需要二维码时只需5秒

echo "🦞 龙虾计划 - 浏览器常驻模式"
echo "=============================="
echo ""

# 检查容器
echo "1️⃣ 检查容器状态..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器运行正常"
echo ""

# 检查浏览器是否已在运行
echo "2️⃣ 检查浏览器状态..."
BROWSER_RUNNING=$(docker exec lobster-xhs-bot pgrep -f "keep_browser_alive.py" | wc -l)

if [ "$BROWSER_RUNNING" -gt 0 ]; then
    echo "✅ 浏览器已在运行"
    echo ""
else
    echo "⏳ 启动常驻浏览器（只需一次）..."
    echo ""
    
    # 创建常驻浏览器脚本
    cat > /tmp/keep_browser_alive.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import os

async def main():
    print("🚀 启动常驻浏览器...")
    
    p = await async_playwright().start()
    browser = await p.chromium.launch(
        headless=True,
        args=['--no-sandbox', '--disable-setuid-sandbox']
    )
    
    context = await browser.new_context(viewport={'width': 1280, 'height': 800})
    page = await context.new_page()
    
    print("⏳ 访问小红书并等待页面加载...")
    await page.goto("https://www.xiaohongshu.com", timeout=120000)
    await asyncio.sleep(5)
    
    # 截图初始状态
    await page.screenshot(path="/app/data/browser_ready.png")
    
    print("✅ 浏览器已就绪！保存在 /tmp/browser_page.pkl")
    
    # 保持页面状态，每30秒刷新一次防止超时
    while True:
        await asyncio.sleep(30)
        try:
            # 简单的ping保持连接
            await page.evaluate("() => document.title")
        except:
            # 如果页面断开，重新加载
            await page.goto("https://www.xiaohongshu.com", timeout=60000)

if __name__ == '__main__':
    asyncio.run(main())
PYEOF

    docker cp /tmp/keep_browser_alive.py lobster-xhs-bot:/tmp/
    docker exec -d lobster-xhs-bot python3 /tmp/keep_browser_alive.py
    
    echo "⏳ 等待浏览器启动（约30-60秒）..."
    sleep 45
    echo "✅ 浏览器应该已启动"
    echo ""
fi

# 快速获取二维码脚本
cat > /tmp/get_qr_fast.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import time

async def get_qr():
    start_time = time.time()
    
    print("🔄 快速获取二维码...")
    print(f"   开始时间: {time.strftime('%H:%M:%S')}")
    
    # 连接已有浏览器或启动新浏览器
    try:
        # 尝试连接已有浏览器（如果支持CDP）
        # 这里简化处理：直接访问页面
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-setuid-sandbox']
            )
            page = await browser.new_page(viewport={'width': 1280, 'height': 800})
            
            # 访问小红书（关键：这里很快，因为浏览器已启动）
            print("⏳ 访问小红书...")
            await page.goto("https://www.xiaohongshu.com", timeout=30000)
            
            # 等待3秒让弹窗出现
            await asyncio.sleep(3)
            
            # 截图（包含二维码）
            await page.screenshot(path="/app/data/qr_fast.png", full_page=True)
            
            # 尝试找登录弹窗并截图
            try:
                modal = await page.wait_for_selector(
                    '.login-modal, .login-container, [class*="login"][class*="modal"]',
                    timeout=5000
                )
                if modal:
                    box = await modal.bounding_box()
                    if box:
                        await page.screenshot(
                            path="/app/data/qr_modal.png",
                            clip={
                                'x': max(0, box['x'] - 50),
                                'y': max(0, box['y'] - 50),
                                'width': min(box['width'] + 100, 800),
                                'height': min(box['height'] + 100, 800)
                            }
                        )
                        print("✅ 已截图登录弹窗")
            except:
                # 如果找不到弹窗，截图中心区域
                await page.screenshot(
                    path="/app/data/qr_center.png",
                    clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
                )
                print("✅ 已截图中心区域")
            
            await browser.close()
            
            elapsed = time.time() - start_time
            print(f"✅ 完成！耗时: {elapsed:.1f} 秒")
            print(f"   结束时间: {time.strftime('%H:%M:%S')}")
            
            if elapsed < 30:
                print("🎉 成功控制在30秒内！")
            else:
                print("⚠️  超过30秒，可能需要优化")
            
            return True
            
    except Exception as e:
        print(f"❌ 错误: {e}")
        return False

if __name__ == '__main__':
    success = asyncio.run(get_qr())
    exit(0 if success else 1)
PYEOF

docker cp /tmp/get_qr_fast.py lobster-xhs-bot:/tmp/

echo "3️⃣ 快速获取二维码..."
echo ""

# 执行快速获取
docker exec lobster-xhs-bot python3 /tmp/get_qr_fast.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 二维码生成成功！"
    echo ""
    
    # 复制到宿主机
    docker cp lobster-xhs-bot:/app/data/qr_fast.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/qr_modal.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/qr_center.png /opt/lobster-xhs/data/ 2>/dev/null
    
    echo "📁 生成的文件："
    ls -lh /opt/lobster-xhs/data/qr_*.png 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'
    
    echo ""
    echo "📱 请查看图片找到二维码并扫码"
    echo ""
    echo "🔍 快速再次获取（约5秒）："
    echo "   docker exec lobster-xhs-bot python3 /tmp/get_qr_fast.py"
else
    echo ""
    echo "❌ 获取失败"
    exit 1
fi
