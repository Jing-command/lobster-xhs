#!/bin/bash
# 龙虾计划 - 快速二维码获取（浏览器常驻版）
# 先启动浏览器保持运行，然后快速获取二维码

echo "🦞 龙虾计划 - 快速二维码获取"
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

# 创建常驻浏览器脚本
cat > /tmp/keep_browser.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import os
import json

# 全局变量
browser = None
page = None
context = None

async def init_browser():
    """初始化并启动浏览器"""
    global browser, page, context
    
    print("🚀 启动常驻浏览器...")
    print("   （只需启动一次，后续快速获取二维码）")
    
    p = await async_playwright().start()
    browser = await p.chromium.launch(
        headless=True,
        args=['--no-sandbox', '--disable-setuid-sandbox']
    )
    
    context = await browser.new_context(
        viewport={'width': 1280, 'height': 800}
    )
    
    page = await context.new_page()
    
    # 访问小红书并等待登录弹窗
    print("⏳ 访问小红书...")
    await page.goto("https://www.xiaohongshu.com", timeout=120000)
    await asyncio.sleep(5)
    
    print("✅ 浏览器已就绪！")
    print("   现在可以快速获取二维码（5秒内）")
    
    return browser, page

async def get_qr():
    """获取二维码（快速版）"""
    global page
    
    if not page:
        print("❌ 浏览器未启动，请先调用 init_browser()")
        return False
    
    print("\n🔄 刷新页面获取新二维码...")
    
    # 刷新页面获取新二维码
    await page.reload()
    await asyncio.sleep(3)
    
    # 截图找二维码
    await page.screenshot(path="/app/data/qr_current.png", full_page=True)
    
    # 找登录弹窗
    try:
        modal = await page.wait_for_selector('.login-modal, .login-container', timeout=5000)
        if modal:
            # 截图弹窗区域
            box = await modal.bounding_box()
            if box:
                await page.screenshot(
                    path="/app/data/qr_modal.png",
                    clip={'x': box['x'], 'y': box['y'], 'width': box['width'], 'height': box['height']}
                )
                print("✅ 已截图登录弹窗")
                return True
    except:
        pass
    
    # 如果没找到弹窗，截图中心区域（二维码通常在中间）
    await page.screenshot(
        path="/app/data/qr_center.png",
        clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
    )
    print("✅ 已截图中心区域")
    return True

async def main():
    await init_browser()
    
    # 保持运行，每30秒生成一个新二维码
    counter = 0
    while True:
        counter += 1
        print(f"\n=== 生成第 {counter} 个二维码 ===")
        await get_qr()
        print("📸 二维码已保存到 /app/data/qr_modal.png 或 qr_center.png")
        print("⏳ 30秒后生成新的...")
        await asyncio.sleep(30)

if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 已停止")
PYEOF

# 复制到容器
docker cp /tmp/keep_browser.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动常驻浏览器（只需运行一次）..."
echo ""
echo "⚠️  这个脚本会："
echo "   1. 启动浏览器并保持运行"
echo "   2. 每30秒自动生成新二维码"
echo "   3. 二维码保存在 /app/data/ 目录"
echo ""
echo "📱 你可以随时下载最新的二维码扫码"
echo ""
echo "按 Ctrl+C 停止"
echo ""

# 在后台运行
docker exec -d lobster-xhs-bot python3 /tmp/keep_browser.py

echo "✅ 浏览器已在后台启动！"
echo ""
echo "等待10秒让浏览器初始化..."
sleep 10

echo ""
echo "📁 查看最新二维码："
docker exec lobster-xhs-bot ls -lh /app/data/qr_*.png 2>/dev/null || echo "   二维码生成中，请稍等..."

echo ""
echo "🔍 检查浏览器状态："
docker exec lobster-xhs-bot ps aux | grep python | grep -v grep || echo "   启动中..."

echo ""
echo "📥 下载二维码到本地："
echo "   scp root@8.215.81.16:/opt/lobster-xhs/data/qr_modal.png ~/Desktop/"
echo "   或"
echo "   scp root@8.215.81.16:/opt/lobster-xhs/data/qr_center.png ~/Desktop/"
echo ""
echo "⏰ 每30秒会自动更新二维码！"
