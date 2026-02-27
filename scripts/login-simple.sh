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
    total_start = time.time()
    browser = None
    
    try:
        # 1. 启动浏览器
        print("🚀 启动浏览器...")
        step_start = time.time()
        p = await async_playwright().start()
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )
        page = await browser.new_page(viewport={'width': 1280, 'height': 800})
        print(f"   启动耗时: {time.time()-step_start:.1f}秒")
        
        # 2. 访问小红书
        print()
        print("⏳ 访问小红书...")
        xhs_start = time.time()  # ⏱️ 记录进入小红书的时间
        await page.goto("https://www.xiaohongshu.com", timeout=60000)
        print(f"   页面加载: {time.time()-xhs_start:.1f}秒")
        
        # 3. 等待页面渲染（二维码自动出现）
        print("⏳ 等待二维码渲染...")
        wait_start = time.time()
        await asyncio.sleep(5)
        print(f"   等待耗时: {time.time()-wait_start:.1f}秒")
        
        # 4. 找二维码图片（174x174像素）
        print()
        print("📸 查找并截图二维码...")
        find_start = time.time()
        qr_found = False
        
        images = await page.query_selector_all('img')
        print(f"   扫描到 {len(images)} 个图片")
        
        for i, img in enumerate(images):
            try:
                box = await img.bounding_box()
                # 小红书二维码是174x174
                if box and 150 <= box['width'] <= 200 and 150 <= box['height'] <= 200:
                    await img.screenshot(path="/app/data/qr_code.png")
                    print(f"   ✅ 找到二维码: {int(box['width'])}x{int(box['height'])}")
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
            print("   ✅ 已截图中心区域")
        
        # ⏱️ 关键统计：从进入小红书到存储截图的时间
        qr_capture_time = time.time() - xhs_start
        total_elapsed = time.time() - total_start
        
        print()
        print("=" * 50)
        print("⏱️  时间统计")
        print("=" * 50)
        print(f"   启动浏览器: {time.time()-total_start-qr_capture_time:.1f}秒")
        print(f"   ⭐ 进入官网→存储截图: {qr_capture_time:.1f}秒 ⭐")
        print(f"   总耗时: {total_elapsed:.1f}秒")
        print("=" * 50)
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
        total_time = time.time() - total_start
        
        if logged_in:
            print()
            print("💾 保存Cookie...")
            cookies = await page.context.cookies()
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f)
            
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
            
            print()
            print("=" * 50)
            print(f"🎉 登录成功！")
            print(f"   获取二维码: {qr_capture_time:.1f}秒")
            print(f"   总耗时: {total_time:.1f}秒")
            print("=" * 50)
            await browser.close()
            return True
        else:
            print()
            print(f"⚠️  超时未登录（总耗时: {total_time:.1f}秒）")
            print("   请重试")
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
echo "📱 请立即扫码！二维码1分钟后过期"
echo ""
echo "⏱️  目标: 进入官网→存储截图 < 30秒"
echo ""
echo "查看状态: docker exec lobster-xhs-bot cat /app/data/login_status.txt"
