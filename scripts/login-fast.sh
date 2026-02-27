#!/bin/bash
# 龙虾计划 - 极速版登录流程（目标30秒内）

echo "🦞 龙虾计划 - 极速登录流程（目标30秒）"
echo "=========================================="
echo ""

# 检查容器
echo "1️⃣ 检查容器..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器正常"
echo ""

# 极速版登录脚本
cat > /tmp/login_fast.py << 'PYEOF'
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
        browser_time = time.time() - step_start
        print(f"\r   ✅ 启动: {browser_time:.1f}秒")
        
        # 2. 访问小红书（优化：设置更短超时）
        print()
        print("⏳ 访问小红书...")
        xhs_start = time.time()
        await page.goto("https://www.xiaohongshu.com", timeout=30000)  # 减少到30秒
        load_time = time.time() - xhs_start
        print(f"   ✅ 加载: {load_time:.1f}秒")
        
        # 3. 快速查找二维码（优化：不固定等待，立即查找）
        print()
        print("📸 查找二维码...")
        find_start = time.time()
        qr_found = False
        
        # 最多尝试3秒查找
        for attempt in range(6):  # 6次尝试，每次0.5秒
            images = await page.query_selector_all('img')
            
            for img in images:
                try:
                    box = await img.bounding_box()
                    # 小红书二维码是174x174，允许误差
                    if box and 140 <= box['width'] <= 220 and 140 <= box['height'] <= 220:
                        await img.screenshot(path="/app/data/qr_code.png")
                        size = f"{int(box['width'])}x{int(box['height'])}"
                        print(f"   ✅ 找到: {size}")
                        qr_found = True
                        break
                except:
                    continue
            
            if qr_found:
                break
            
            # 没找到，等0.5秒再试
            await asyncio.sleep(0.5)
        
        # 如果没找到，立即截图中心区域
        if not qr_found:
            await page.screenshot(
                path="/app/data/qr_code.png",
                clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
            )
            print("   ✅ 中心区域截图")
        
        find_time = time.time() - find_start
        
        # ⏱️ 统计
        qr_total_time = time.time() - xhs_start
        total_elapsed = time.time() - total_start
        
        print()
        print("=" * 50)
        print("⏱️  时间统计")
        print("=" * 50)
        print(f"   启动浏览器: {browser_time:.1f}秒")
        print(f"   页面加载:   {load_time:.1f}秒")
        print(f"   查找截图:   {find_time:.1f}秒")
        print(f"   ─────────────────")
        print(f"   ⭐ 官网→截图: {qr_total_time:.1f}秒 ⭐")
        print(f"   总耗时:     {total_elapsed:.1f}秒")
        print("=" * 50)
        
        if qr_total_time <= 30:
            print("   🎉 达标！≤ 30秒")
        else:
            print(f"   ⚠️  超时 {qr_total_time-30:.1f}秒")
        print()
        
        # 4. 等待扫码（计时）
        print("=" * 50)
        print("📱 请立即扫码！二维码1分钟后过期")
        print("=" * 50)
        print()
        
        logged_in = False
        scan_start = time.time()
        
        while time.time() - scan_start < 180:  # 3分钟
            elapsed = time.time() - scan_start
            mins = int(elapsed) // 60
            secs = int(elapsed) % 60
            print(f"\r   已等待: {mins:02d}:{secs:02d}", end='', flush=True)
            
            # 检查登录
            try:
                if await page.query_selector('.user-name, .avatar'):
                    print(f"\r   ✅ 登录成功！")
                    logged_in = True
                    break
                
                if '/user/profile' in page.url:
                    print(f"\r   ✅ 登录成功！")
                    logged_in = True
                    break
            except:
                pass
            
            await asyncio.sleep(1)
        
        scan_time = time.time() - scan_start
        
        # 5. 保存结果
        print()
        if logged_in:
            print("💾 保存Cookie...")
            cookies = await page.context.cookies()
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f)
            
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
                f.write(f"qr_time={qr_total_time:.1f}s\n")
                f.write(f"scan_time={scan_time:.1f}s\n")
            
            await browser.close()
            print(f"\n🎉 完成！扫码用时: {scan_time:.1f}秒")
            return True
        else:
            print(f"\n⚠️ 超时 ({scan_time:.0f}秒)，请重试")
            await browser.close()
            return False
            
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        if browser:
            await browser.close()
        return False

asyncio.run(login())
PYEOF

docker cp /tmp/login_fast.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动极速登录流程..."
echo "   目标: 30秒内生成二维码"
echo ""

# 后台运行
docker exec -d lobster-xhs-bot python3 /tmp/login_fast.py

echo "✅ 已启动！"
echo ""

# 快速检查（每5秒）
for i in {5..35..5}; do
    sleep 5
    if docker exec lobster-xhs-bot test -f /app/data/qr_code.png 2>/dev/null; then
        echo "   ✅ ${i}秒: 二维码已生成！"
        break
    else
        echo "   ⏳ ${i}秒: 进行中..."
    fi
done

# 复制到宿主机
docker cp lobster-xhs-bot:/app/data/qr_code.png /opt/lobster-xhs/data/ 2>/dev/null

echo ""
echo "📁 二维码:"
ls -lh /opt/lobster-xhs/data/qr_code.png 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

echo ""
echo "📱 立即扫码！"
echo ""
echo "查看日志: docker logs -f lobster-xhs-bot"
