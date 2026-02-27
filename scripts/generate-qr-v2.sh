#!/bin/bash
# 龙虾计划 - 本地生成二维码脚本（终极版）
# 直接在服务器上生成二维码图片，避免API超时

echo "🦞 龙虾计划 - 本地生成二维码（终极版）"
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

# 创建二维码生成脚本
cat > /tmp/generate_qr_v2.py << 'PYEOF'
import asyncio
from playwright.async_api import async_playwright
import base64
import os
import time

async def generate_qr():
    print("=" * 60)
    print("开始生成小红书登录二维码")
    print("=" * 60)
    print()
    
    qr_path = "/app/data/qr_code_v2.png"
    
    if os.path.exists(qr_path):
        os.remove(qr_path)
    
    try:
        async with async_playwright() as p:
            print("⏳ 启动 Chromium 浏览器...")
            print("   （第一次启动较慢，请耐心等待 30-60 秒）")
            print()
            
            browser = await p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-setuid-sandbox']
            )
            print("✅ 浏览器启动成功！")
            print()
            
            page = await browser.new_page(
                viewport={'width': 1280, 'height': 800}
            )
            
            print("⏳ 访问小红书...")
            await page.goto("https://www.xiaohongshu.com", timeout=120000)
            print("✅ 页面加载完成")
            print()
            
            print("⏳ 等待页面渲染（5秒）...")
            await asyncio.sleep(5)
            
            await page.screenshot(path="/app/data/debug_page.png", full_page=True)
            print("📸 已保存页面截图")
            print()
            
            print("⏳ 点击个人中心触发登录弹窗...")
            profile_selectors = [
                '[href="/user/profile"]',
                '.user-icon',
                'button:has-text("登录")',
            ]
            
            clicked = False
            for selector in profile_selectors:
                try:
                    elem = await page.wait_for_selector(selector, timeout=3000)
                    if elem:
                        await elem.click()
                        print(f"✅ 点击: {selector}")
                        clicked = True
                        await asyncio.sleep(3)
                        break
                except:
                    continue
            
            if not clicked:
                print("⚠️ 未找到点击元素，等待自动弹窗...")
                await asyncio.sleep(5)
            
            await page.screenshot(path="/app/data/debug_after_click.png", full_page=True)
            print("📸 已保存点击后截图")
            print()
            
            print("⏳ 查找二维码...")
            qr_element = None
            
            # 方法1: 找登录弹窗
            try:
                modal = await page.wait_for_selector('.login-modal, .login-container', timeout=10000)
                if modal:
                    print("✅ 找到登录弹窗")
                    images = await modal.query_selector_all('img')
                    print(f"   弹窗内有 {len(images)} 个图片")
                    
                    for img in images:
                        box = await img.bounding_box()
                        if box and box['width'] > 100 and box['height'] > 100:
                            qr_element = img
                            print(f"   找到大图: {int(box['width'])}x{int(box['height'])}")
                            break
            except Exception as e:
                print(f"   方法1: {e}")
            
            # 方法2: 找页面里的大图片
            if not qr_element:
                try:
                    print("⏳ 方法2: 扫描所有图片...")
                    images = await page.query_selector_all('img')
                    print(f"   共 {len(images)} 个图片")
                    
                    for i, img in enumerate(images):
                        try:
                            box = await img.bounding_box()
                            # 二维码通常是 150-400 像素
                            if box and 150 <= box['width'] <= 400 and 150 <= box['height'] <= 400:
                                qr_element = img
                                print(f"   ✅ 候选 {i}: {int(box['width'])}x{int(box['height'])}")
                                await img.screenshot(path=f"/app/data/candidate_{i}.png")
                                break
                        except:
                            continue
                except Exception as e:
                    print(f"   方法2: {e}")
            
            # 如果找到了，截图
            if qr_element:
                print()
                print("⏳ 截取二维码...")
                await qr_element.screenshot(path=qr_path)
                
                if os.path.exists(qr_path):
                    file_size = os.path.getsize(qr_path)
                    print()
                    print("=" * 60)
                    print(f"🎉 二维码生成成功！")
                    print(f"   路径: {qr_path}")
                    print(f"   大小: {file_size} bytes")
                    print("=" * 60)
                    print()
                    print("📱 请使用小红书APP扫码")
                    await browser.close()
                    return True
            
            # 如果没找到，截图中心区域
            print()
            print("⚠️ 未找到明确二维码，截图中心区域...")
            await page.screenshot(path="/app/data/qr_center.png", clip={'x': 340, 'y': 100, 'width': 600, 'height': 600})
            print("📸 已保存: /app/data/qr_center.png")
            
            await browser.close()
            return True
            
    except Exception as e:
        print()
        print("=" * 60)
        print(f"❌ 失败: {e}")
        print("=" * 60)
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = asyncio.run(generate_qr())
    exit(0 if success else 1)
PYEOF

# 复制到容器
docker cp /tmp/generate_qr_v2.py lobster-xhs-bot:/tmp/

echo "2️⃣ 生成二维码（预计 60-120 秒）..."
echo ""

# 执行生成（带3分钟超时）
timeout 180 docker exec lobster-xhs-bot python3 /tmp/generate_qr_v2.py

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ 生成成功！"
    echo ""
    
    # 复制图片到宿主机
    docker cp lobster-xhs-bot:/app/data/debug_page.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/debug_after_click.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/qr_center.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/qr_code_v2.png /opt/lobster-xhs/data/ 2>/dev/null
    docker cp lobster-xhs-bot:/app/data/candidate_0.png /opt/lobster-xhs/data/ 2>/dev/null
    
    echo "📁 生成的文件："
    ls -lh /opt/lobster-xhs/data/*.png 2>/dev/null | awk '{print "   " $9 " (" $5 ")"}'
    echo ""
    echo "📱 请查看图片找到二维码"
    
elif [ $EXIT_CODE -eq 124 ]; then
    echo ""
    echo "❌ 超时（超过3分钟）"
    exit 1
else
    echo ""
    echo "❌ 失败（退出码: $EXIT_CODE）"
    exit 1
fi
