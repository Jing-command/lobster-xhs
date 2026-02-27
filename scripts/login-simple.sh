#!/bin/bash
# 龙虾计划 - 精简版登录流程
# 只保留有效的步骤：启动 → 访问 → 找图片 → 等待扫码 → 保存Cookie

echo "🦞 龙虾计划 - 精简登录流程"
echo "==========================="
echo ""

# 检查容器
echo "1️⃣ 检查容器..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器正常"
echo ""

# 精简版登录脚本
cat > /tmp/login_simple.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import os
import time
import json

async def login():
    start = time.time()
    browser = None
    
    try:
        # 1. 启动浏览器
        print("🚀 启动浏览器...")
        p = await async_playwright().start()
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )
        page = await browser.new_page(viewport={'width': 1280, 'height': 800})
        
        # 2. 访问小红书
        print("⏳ 访问小红书...")
        await page.goto("https://www.xiaohongshu.com", timeout=60000)
        print("✅ 页面加载完成")
        
        # 3. 等待页面渲染（二维码自动出现）
        print("⏳ 等待二维码...")
        await asyncio.sleep(5)
        
        # 4. 找二维码图片（174x174像素）
        print("📸 查找二维码...")
        qr_found = False
        
        images = await page.query_selector_all('img')
        print(f"   找到 {len(images)} 个图片")
        
        for i, img in enumerate(images):
            try:
                box = await img.bounding_box()
                # 小红书二维码是174x174
                if box and 150 <= box['width'] <= 200 and 150 <= box['height'] <= 200:
                    await img.screenshot(path="/app/data/qr_code.png")
                    print(f"✅ 找到二维码: {int(box['width'])}x{int(box['height'])}")
                    qr_found = True
                    break
            except:
                continue
        
        # 如果没找到，截图中心区域
        if not qr_found:
            await page.screenshot(
                path="/app/data/qr_code.png",
                clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
            )
            print("✅ 已截图中心区域")
        
        elapsed = time.time() - start
        print(f"⏱️  耗时: {elapsed:.1f}秒")
        print()
        print("=" * 50)
        print("📱 请立即用小红书APP扫码！")
        print("=" * 50)
        print()
        
        # 5. 等待扫码（最多3分钟）
        print("⏳ 等待扫码（3分钟）...")
        logged_in = False
        
        for i in range(0, 180, 5):
            # 检查是否登录
            try:
                # 检查用户元素
                if await page.query_selector('.user-name, .avatar, .user-info'):
                    print("✅ 登录成功！")
                    logged_in = True
                    break
                
                # 检查URL
                if '/user/profile' in page.url:
                    print("✅ 登录成功！")
                    logged_in = True
                    break
            except:
                pass
            
            if i % 30 == 0:
                print(f"   已等待 {i}秒...")
            
            await asyncio.sleep(5)
        
        # 6. 保存结果
        if logged_in:
            print()
            print("💾 保存Cookie...")
            cookies = await page.context.cookies()
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f)
            
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
            
            print(f"✅ 完成！总耗时: {time.time()-start:.1f}秒")
            await browser.close()
            return True
        else:
            print()
            print("⚠️ 超时未登录，请重试")
            await browser.close()
            return False
            
    except Exception as e:
        print(f"❌ 错误: {e}")
        if browser:
            await browser.close()
        return False

asyncio.run(login())
PYEOF

docker cp /tmp/login_simple.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动登录流程..."
echo "   预计40秒生成二维码，然后等待3分钟扫码"
echo ""

# 后台运行
docker exec -d lobster-xhs-bot python3 /tmp/login_simple.py

echo "✅ 已启动！等待生成二维码..."
sleep 40

# 复制到宿主机
docker cp lobster-xhs-bot:/app/data/qr_code.png /opt/lobster-xhs/data/ 2>/dev/null

echo ""
echo "📁 二维码文件:"
ls -lh /opt/lobster-xhs/data/qr_code.png 2>/dev/null || echo "   生成中，再等10秒..."

echo ""
echo "📱 请立即扫码！"
echo ""
echo "查看状态: docker exec lobster-xhs-bot cat /app/data/login_status.txt"
