#!/bin/bash
# 龙虾计划 - 登录流程脚本
# 1. 生成二维码 → 2. 保持浏览器等待扫码 → 3. 保存Cookie

echo "🦞 龙虾计划 - 小红书登录流程"
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

# 创建登录流程脚本
cat > /tmp/login_flow.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import base64
import os
import time
import sys

async def login_flow():
    print("=" * 60)
    print("小红书登录流程")
    print("=" * 60)
    print()
    
    browser = None
    
    try:
        # 1. 启动浏览器
        print("🚀 启动浏览器...")
        p = await async_playwright().start()
        browser = await p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-setuid-sandbox']
        )
        context = await browser.new_context(viewport={'width': 1280, 'height': 800})
        page = await context.new_page()
        
        # 2. 访问小红书
        print("⏳ 访问小红书...")
        await page.goto("https://www.xiaohongshu.com", timeout=120000)
        print("✅ 页面加载完成")
        print()
        
        # 3. 等待登录弹窗
        print("⏳ 等待登录弹窗（5秒）...")
        await asyncio.sleep(5)
        
        # 4. 截图获取二维码
        print("📸 截取二维码...")
        
        # 先截图全页面
        await page.screenshot(path="/app/data/login_page.png", full_page=True)
        
        # 尝试找登录弹窗并截图
        qr_found = False
        try:
            modal = await page.wait_for_selector(
                '.login-modal, .login-container, [class*="login"][class*="modal"]',
                timeout=5000
            )
            if modal:
                box = await modal.bounding_box()
                if box:
                    await page.screenshot(
                        path="/app/data/qr_login.png",
                        clip={
                            'x': max(0, box['x'] - 20),
                            'y': max(0, box['y'] - 20),
                            'width': min(box['width'] + 40, 700),
                            'height': min(box['height'] + 40, 700)
                        }
                    )
                    print("✅ 已截图登录弹窗: /app/data/qr_login.png")
                    qr_found = True
        except Exception as e:
            print(f"   未找到弹窗: {e}")
        
        if not qr_found:
            # 截图中心区域
            await page.screenshot(
                path="/app/data/qr_center.png",
                clip={'x': 340, 'y': 150, 'width': 600, 'height': 500}
            )
            print("✅ 已截图中心区域: /app/data/qr_center.png")
        
        # 5. 等待用户扫码（最多3分钟）
        print()
        print("=" * 60)
        print("📱 请使用小红书APP扫码登录")
        print("=" * 60)
        print()
        print("⏳ 等待扫码（最多3分钟）...")
        print("   扫码后自动保存Cookie")
        print()
        
        logged_in = False
        max_wait = 180  # 3分钟
        check_interval = 5  # 每5秒检查一次
        
        for i in range(0, max_wait, check_interval):
            # 检查是否已登录
            try:
                # 检查是否有用户头像或用户名
                user_elements = await page.query_selector_all('.user-name, .avatar, .user-info, [class*="user-avatar"]')
                
                if user_elements and len(user_elements) > 0:
                    # 尝试获取用户名
                    try:
                        username_elem = await page.query_selector('.user-name, [class*="username"]')
                        if username_elem:
                            username = await username_elem.text_content()
                            print(f"✅ 检测到登录用户: {username}")
                    except:
                        pass
                    
                    logged_in = True
                    break
                
                # 检查URL变化（登录后通常会跳转）
                current_url = page.url
                if '/user/profile' in current_url or '/home' in current_url:
                    print("✅ 检测到登录状态（URL变化）")
                    logged_in = True
                    break
                    
            except Exception as e:
                pass
            
            # 显示进度
            remaining = max_wait - i
            if i % 30 == 0:  # 每30秒显示一次
                print(f"   已等待 {i} 秒，还剩 {remaining} 秒...")
            
            await asyncio.sleep(check_interval)
        
        # 6. 处理登录结果
        if logged_in:
            print()
            print("🎉 登录成功！")
            print()
            
            # 保存Cookie
            print("💾 保存Cookie...")
            cookies = await context.cookies()
            import json
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f, indent=2)
            print("✅ Cookie已保存到: /app/data/cookies.json")
            
            # 保存登录状态
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
                f.write(f"login_time={time.strftime('%Y-%m-%d %H:%M:%S')}\n")
            print("✅ 登录状态已记录")
            
            await browser.close()
            print()
            print("=" * 60)
            print("✅ 登录流程完成！")
            print("=" * 60)
            return True
            
        else:
            print()
            print("⚠️  等待超时（3分钟），未检测到登录")
            print("   可能原因：")
            print("   1. 未扫码")
            print("   2. 扫码后未确认登录")
            print("   3. 二维码已过期")
            print()
            print("💡 建议：重新运行脚本获取新二维码")
            
            await browser.close()
            return False
            
    except Exception as e:
        print()
        print("=" * 60)
        print(f"❌ 错误: {e}")
        print("=" * 60)
        if browser:
            await browser.close()
        return False

if __name__ == '__main__':
    success = asyncio.run(login_flow())
    sys.exit(0 if success else 1)
PYEOF

docker cp /tmp/login_flow.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动登录流程..."
echo ""
echo "⏳ 预计流程："
echo "   1. 启动浏览器（30-60秒）"
echo "   2. 获取二维码（5秒）"
echo "   3. 等待扫码（最多3分钟）"
echo "   4. 保存Cookie（5秒）"
echo ""
echo "📱 请在看到二维码后立即扫码并确认登录！"
echo ""

# 在后台运行登录流程
docker exec -d lobster-xhs-bot python3 /tmp/login_flow.py

echo "✅ 登录流程已在后台启动！"
echo ""
echo "⏳ 等待生成二维码（约30秒）..."
sleep 30

echo ""
echo "📁 检查生成的文件："
docker exec lobster-xhs-bot ls -lh /app/data/qr_*.png 2>/dev/null || echo "   二维码生成中，再等10秒..."

sleep 10

# 复制到宿主机
docker cp lobster-xhs-bot:/app/data/qr_login.png /opt/lobster-xhs/data/ 2>/dev/null
docker cp lobster-xhs-bot:/app/data/qr_center.png /opt/lobster-xhs/data/ 2>/dev/null
docker cp lobster-xhs-bot:/app/data/login_page.png /opt/lobster-xhs/data/ 2>/dev/null

echo ""
echo "📂 可用文件："
ls -lh /opt/lobster-xhs/data/qr_*.png 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

echo ""
echo "🔍 检查登录状态（每分钟自动检查）："
echo "   watch -n 10 'docker exec lobster-xhs-bot cat /app/data/login_status.txt 2>/dev/null || echo \"等待中...\"'"
echo ""
echo "📊 实时日志："
echo "   docker exec lobster-xhs-bot tail -f /tmp/login_flow.log 2>/dev/null || echo \"查看日志: docker logs lobster-xhs-bot\""
