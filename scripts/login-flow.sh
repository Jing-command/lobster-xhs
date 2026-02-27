#!/bin/bash
# 龙虾计划 - 登录流程脚本（优化版）
# 优化二维码获取，快速可靠

echo "🦞 龙虾计划 - 小红书登录流程（优化版）"
echo "=========================================="
echo ""

# 检查容器
echo "1️⃣ 检查容器状态..."
if ! docker ps | grep -q "lobster-xhs-bot"; then
    echo "❌ 容器未运行"
    exit 1
fi
echo "✅ 容器运行正常"
echo ""

# 创建优化版登录脚本
cat > /tmp/login_flow_v2.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import os
import time
import sys

async def login_flow():
    print("=" * 60)
    print("小红书登录流程 - 优化版")
    print("=" * 60)
    print()
    
    browser = None
    start_time = time.time()
    
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
        await page.goto("https://www.xiaohongshu.com", timeout=60000)
        print("✅ 页面加载完成")
        
        # 3. 主动触发登录弹窗（优化点：多种方式尝试）
        print()
        print("⏳ 触发登录弹窗...")
        
        login_triggered = False
        
        # 方法1: 点击个人中心图标
        try:
            profile_selectors = [
                'a[href="/user/profile"]',
                '.user-icon',
                '[class*="profile"]',
                '.avatar',
                'button:has-text("我的")',
                'button:has-text("我")',
            ]
            for selector in profile_selectors:
                try:
                    elem = await page.wait_for_selector(selector, timeout=2000)
                    if elem:
                        await elem.click()
                        print(f"✅ 点击个人中心: {selector}")
                        login_triggered = True
                        await asyncio.sleep(2)
                        break
                except:
                    continue
        except:
            pass
        
        # 方法2: 点击登录按钮（如果页面有直接显示的）
        if not login_triggered:
            try:
                login_btn_selectors = [
                    'button:has-text("登录")',
                    'button:has-text("Login")',
                    '.login-btn',
                    '[class*="login-btn"]',
                    'a:has-text("登录")',
                ]
                for selector in login_btn_selectors:
                    try:
                        elem = await page.wait_for_selector(selector, timeout=2000)
                        if elem:
                            await elem.click()
                            print(f"✅ 点击登录按钮: {selector}")
                            login_triggered = True
                            await asyncio.sleep(2)
                            break
                    except:
                        continue
            except:
                pass
        
        # 方法3: 等待自动弹窗
        if not login_triggered:
            print("⏳ 等待自动弹窗...")
            await asyncio.sleep(5)
        
        # 4. 获取二维码（优化点：多种查找方式）
        print()
        print("📸 获取二维码...")
        
        qr_saved = False
        
        # 方法1: 找登录弹窗并截图
        try:
            modal_selectors = [
                '.login-modal',
                '.login-container',
                '[class*="login-modal"]',
                '[class*="login-container"]',
                'div[class*="modal"]:has(img)',
                'div[class*="login"]:has(img)',
            ]
            
            for selector in modal_selectors:
                try:
                    modal = await page.wait_for_selector(selector, timeout=3000)
                    if modal:
                        box = await modal.bounding_box()
                        if box and box['width'] > 200 and box['height'] > 200:
                            # 截图弹窗
                            await page.screenshot(
                                path="/app/data/qr_login.png",
                                clip={
                                    'x': max(0, box['x'] - 20),
                                    'y': max(0, box['y'] - 20),
                                    'width': min(box['width'] + 40, 800),
                                    'height': min(box['height'] + 40, 800)
                                }
                            )
                            print("✅ 已截图登录弹窗")
                            qr_saved = True
                            break
                except:
                    continue
        except:
            pass
        
        # 方法2: 找页面里的大图片（二维码通常是150-350像素）
        if not qr_saved:
            try:
                print("   尝试查找图片元素...")
                images = await page.query_selector_all('img')
                
                for img in images:
                    try:
                        box = await img.bounding_box()
                        # 二维码通常在150-350像素之间，正方形
                        if box and 150 <= box['width'] <= 400 and 150 <= box['height'] <= 400:
                            await img.screenshot(path="/app/data/qr_img.png")
                            print(f"✅ 已截图图片元素: {int(box['width'])}x{int(box['height'])}")
                            qr_saved = True
                            break
                    except:
                        continue
            except:
                pass
        
        # 方法3: 截图页面中心区域（保底方案）
        if not qr_saved:
            print("   截图中心区域...")
            await page.screenshot(
                path="/app/data/qr_center.png",
                clip={'x': 340, 'y': 150, 'width': 600, 'height': 600}
            )
            print("✅ 已截图中心区域")
            qr_saved = True
        
        # 5. 显示耗时
        elapsed = time.time() - start_time
        print()
        print(f"⏱️  二维码获取耗时: {elapsed:.1f} 秒")
        
        if not qr_saved:
            print("❌ 未能保存二维码")
            await browser.close()
            return False
        
        # 6. 等待扫码（最多3分钟）
        print()
        print("=" * 60)
        print("📱 请立即使用小红书APP扫码登录！")
        print("=" * 60)
        print()
        print("⏳ 等待扫码（最多3分钟）...")
        print()
        
        logged_in = False
        check_count = 0
        
        for i in range(0, 180, 5):  # 每5秒检查一次，共36次（3分钟）
            check_count += 1
            
            # 检查登录状态
            try:
                # 方法1: 检查用户元素
                user_elements = await page.query_selector_all('.user-name, .avatar, .user-info')
                if user_elements and len(user_elements) > 0:
                    print(f"✅ 检测到登录状态（用户元素）")
                    logged_in = True
                    break
                
                # 方法2: 检查URL变化
                current_url = page.url
                if '/user/profile' in current_url or '/home' in current_url:
                    print(f"✅ 检测到登录状态（URL变化）")
                    logged_in = True
                    break
                
                # 方法3: 检查登录按钮消失
                login_btns = await page.query_selector_all('button:has-text("登录")')
                if len(login_btns) == 0:
                    # 再确认一下是否有用户头像
                    avatars = await page.query_selector_all('.avatar, [class*="avatar"]')
                    if len(avatars) > 0:
                        print(f"✅ 检测到登录状态（登录按钮消失）")
                        logged_in = True
                        break
                    
            except Exception as e:
                pass
            
            # 显示进度（每6次即30秒显示一次）
            if check_count % 6 == 0:
                elapsed_wait = check_count * 5
                remaining = 180 - elapsed_wait
                print(f"   已等待 {elapsed_wait} 秒，还剩 {remaining} 秒...")
            
            await asyncio.sleep(5)
        
        # 7. 处理结果
        print()
        if logged_in:
            print("🎉 登录成功！")
            
            # 保存Cookie
            print()
            print("💾 保存Cookie...")
            cookies = await context.cookies()
            import json
            with open("/app/data/cookies.json", "w") as f:
                json.dump(cookies, f, indent=2)
            print("✅ Cookie已保存: /app/data/cookies.json")
            
            # 保存状态
            with open("/app/data/login_status.txt", "w") as f:
                f.write("logged_in=true\n")
                f.write(f"time={time.strftime('%Y-%m-%d %H:%M:%S')}\n")
            
            total_time = time.time() - start_time
            print()
            print("=" * 60)
            print(f"✅ 登录流程完成！总耗时: {total_time:.1f} 秒")
            print("=" * 60)
            
            await browser.close()
            return True
            
        else:
            print("⚠️  等待超时（3分钟），未检测到登录")
            print()
            print("可能原因：")
            print("  1. 未扫码")
            print("  2. 扫码后未确认登录")
            print("  3. 二维码过期")
            print()
            print("💡 请重新运行脚本")
            
            await browser.close()
            return False
            
    except Exception as e:
        print()
        print("=" * 60)
        print(f"❌ 错误: {e}")
        print("=" * 60)
        import traceback
        traceback.print_exc()
        if browser:
            await browser.close()
        return False

if __name__ == '__main__':
    success = asyncio.run(login_flow())
    sys.exit(0 if success else 1)
PYEOF

docker cp /tmp/login_flow_v2.py lobster-xhs-bot:/tmp/

echo "2️⃣ 启动优化版登录流程..."
echo ""
echo "⏳ 流程：启动 → 获取二维码（约40秒） → 等待扫码（3分钟） → 保存Cookie"
echo ""

# 在后台运行
docker exec -d lobster-xhs-bot python3 /tmp/login_flow_v2.py > /tmp/login_flow.log 2>&1

echo "✅ 登录流程已启动（后台运行）"
echo ""
echo "⏳ 等待生成二维码（约40秒）..."
echo ""

# 等待并检查
for i in {30..50..10}; do
    sleep 10
    echo "   已等待 $((i+10)) 秒..."
    
    # 检查是否生成二维码
    if docker exec lobster-xhs-bot ls /app/data/qr_*.png > /dev/null 2>&1; then
        echo "   ✅ 检测到二维码文件！"
        break
    fi
done

# 复制到宿主机
docker cp lobster-xhs-bot:/app/data/qr_login.png /opt/lobster-xhs/data/ 2>/dev/null
docker cp lobster-xhs-bot:/app/data/qr_img.png /opt/lobster-xhs/data/ 2>/dev/null
docker cp lobster-xhs-bot:/app/data/qr_center.png /opt/lobster-xhs/data/ 2>/dev/null

echo ""
echo "📁 生成的二维码文件："
ls -lh /opt/lobster-xhs/data/qr_*.png 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'

echo ""
echo "📱 请立即扫码登录！"
echo ""
echo "🔍 查看实时进度："
echo "   docker exec lobster-xhs-bot tail -f /tmp/login_flow.log"
echo ""
echo "⏰ 扫码后等待约5-10秒，系统会自动检测登录状态"
