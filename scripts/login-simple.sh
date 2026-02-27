#!/bin/bash
# 龙虾计划 - 精简版登录流程（带时间统计和倒计时）

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

# 登录脚本
cat > /tmp/login_simple.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import os
import time
import json
import sys

async def countdown(seconds, message):
    """倒计时显示"""
    for i in range(seconds, 0, -1):
        print(f"\r   {message}: {i}秒", end='', flush=True)
        await asyncio.sleep(1)
    print(f"\r   {message}: 完成!    ")

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
        browser_time = time.time() - step_start
        print(f"   ✅ 启动耗时: {browser_time:.1f}秒")
        
        # 2. 访问小红书
        print()
        print("⏳ 访问小红书官网...")
        xhs_start = time.time()  # ⏱️ 记录进入小红书的时间
        await page.goto("https://www.xiaohongshu.com", timeout=60000)
        load_time = time.time() - xhs_start
        print(f"   ✅ 页面加载: {load_time:.1f}秒")
        
        # 3. 等待二维码出现（带倒计时）
        print()
        print("⏳ 等待二维码渲染...")
        await countdown(5, "等待")
        
        # 4. 查找并截图二维码
        print()
        print("📸 查找二维码...")
        find_start = time.time()
        qr_found = False
        
        images = await page.query_selector_all('img')
        print(f"   扫描到 {len(images)} 个图片")
        
        for i, img in enumerate(images):
            try:
                box = await img.bounding_box()
                if box and 150 <= box['width'] <= 200 and 150 <= box['height'] <= 200:
                    await img.screenshot(path="/app/data/qr_code.png")
                    print(f"   ✅ 找到二维码: {int(box['width'])}x{int(box['height'])}")
                    qr_found = True
                    break
            except:
                continue
        
        if not qr_found:
            await page.screenshot(
                path="/app/data/qr_code.png",
                clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
            )
            print("   ✅ 已截图中心区域")
        
        find_time = time.time() - find_start
        
        # ⏱️ 关键统计
        qr_total_time = time.time() - xhs_start
        total_elapsed = time.time() - total_start
        
        print()
        print("=" * 50)
        print("⏱️  时间统计")
        print("=" * 50)
        print(f"   启动浏览器:      {browser_time:.1f}秒")
        print(f"   页面加载:        {load_time:.1f}秒")
        print(f"   查找二维码:      {find_time:.1f}秒")
        print(f"   ─────────────────────")
        print(f"   ⭐ 官网→截图:    {qr_total_time:.1f}秒 ⭐")
        print(f"   总耗时:          {total_elapsed:.1f}秒")
        print("=" * 50)
        
        if qr_total_time <= 30:
            print("   🎉 达标！官网→截图 ≤ 30秒")
        else:
            print("   ⚠️  超时！官网→截图 > 30秒")
        print()
        
        # 5. 等待扫码（带倒计时）
        print("=" * 50)
        print("📱 请立即用小红书APP扫码！")
        print("=" * 50)
        print()
        print("⏳ 等待扫码，倒计时：")
        
        logged_in = False
        max_wait = 180  # 3分钟
        
        for remaining in range(max_wait, 0, -1):
            # 每秒检查一次登录状态
            if remaining % 5 == 0:  # 每5秒显示倒计时
                mins = remaining // 60
                secs = remaining % 60
                print(f"\r   剩余时间: {mins:02d}:{secs:02d}", end='', flush=True)
            
            # 检查是否登录
            try:
                if await page.query_selector('.user-name, .avatar, .user-info'):
                    print(f"\r   ✅ 登录成功！{' '*20}")
                    logged_in = True
                    break
                
                if '/user/profile' in page.url:
                    print(f"\r   ✅ 登录成功！{' '*20}")
                    logged_in = True
                    break
            except:
                pass
            
            await asyncio.sleep(1)
        
        if not logged_in:
            print(f"\r   ⚠️  超时未登录{' '*20}")
        
        # 6. 保存结果
        print()
        if logged_in:
            print("💾 保存Cookie...")
            cookies = await page.context.cookies()
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f)
            
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
                f.write(f"qr_time={qr_total_time:.1f}s\n")
                f.write(f"total_time={time.time()-total_start:.1f}s\n")
            
            await browser.close()
            print()
            print("🎉 登录流程完成！")
            return True
        else:
            await browser.close()
            print("💡 提示: 可以重新运行脚本获取新二维码")
            return False
            
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        if browser:
            await browser.close()
        return False

asyncio.run(login())
PYEOF

docker cp /tmp/login_simple.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动登录流程..."
echo "   预计40秒生成二维码，然后3分钟倒计时等待扫码"
echo ""

# 后台运行
docker exec -d lobster-xhs-bot python3 /tmp/login_simple.py

echo "✅ 已启动！等待生成二维码..."
echo ""

# 等待进度显示
for i in {10..50..10}; do
    sleep 10
    echo "   已等待 ${i}秒..."
done

# 复制到宿主机
docker cp lobster-xhs-bot:/app/data/qr_code.png /opt/lobster-xhs/data/ 2>/dev/null

echo ""
echo "📁 二维码文件:"
ls -lh /opt/lobster-xhs/data/qr_code.png 2>/dev/null || echo "   还在生成中..."

echo ""
echo "📱 请立即扫码！二维码1分钟后过期"
echo ""
echo "⏱️  目标: 进入官网→存储截图 ≤ 30秒"
echo ""
echo "查看实时进度:"
echo "   docker logs -f lobster-xhs-bot 2>&1 | grep -E '(时间统计|剩余时间|登录成功)'"
