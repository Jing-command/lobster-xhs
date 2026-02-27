#!/bin/bash
# 龙虾计划 - 本地生成二维码脚本
# 直接在服务器上生成二维码图片，避免API超时

echo "🦞 龙虾计划 - 本地生成二维码"
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

# 创建二维码生成脚本
cat > /tmp/generate_qr.py << 'PYTHON_SCRIPT'
import asyncio
from playwright.async_api import async_playwright
import base64
import os
import time

async def generate_qr():
    print("=" * 50)
    print("开始生成二维码...")
    print("=" * 50)
    print()
    
    qr_path = "/app/data/qr_code.png"
    
    # 如果已存在，先删除
    if os.path.exists(qr_path):
        os.remove(qr_path)
        print("🗑️  删除旧的二维码")
    
    try:
        async with async_playwright() as p:
            print("⏳ 启动浏览器...")
            browser = await p.chromium.launch(headless=True)
            print("✅ 浏览器启动成功")
            print()
            
            page = await browser.new_page()
            
            print("⏳ 访问小红书登录页面...")
            print("   (最多等待60秒)")
            await page.goto("https://www.xiaohongshu.com", timeout=60000)
            print("✅ 页面加载成功")
            print()
            
            # 点击登录按钮（如果需要）
            print("⏳ 查找登录按钮...")
            try:
                login_btn = await page.wait_for_selector('.login-btn, .login-entry, button:has-text(\"登录\")', timeout=5000)
                if login_btn:
                    await login_btn.click()
                    print("✅ 点击登录按钮")
                    await asyncio.sleep(2)
            except:
                print("ℹ️  无需点击登录按钮")
            
            print()
            print("⏳ 等待二维码出现...")
            print("   (最多等待60秒)")
            
            # 等待二维码元素
            await page.wait_for_selector('img.qr-code, .qrcode img, canvas, .login-qrcode img', timeout=60000)
            print("✅ 二维码已出现")
            print()
            
            # 获取二维码图片
            print("⏳ 截取二维码...")
            qr_element = await page.query_selector('img.qr-code, .qrcode img, .login-qrcode img')
            
            if qr_element:
                # 获取图片URL
                qr_src = await qr_element.get_attribute('src')
                
                if qr_src and qr_src.startswith('data:image'):
                    # Base64图片
                    base64_data = qr_src.split(',')[1]
                    img_data = base64.b64decode(base64_data)
                    with open(qr_path, "wb") as f:
                        f.write(img_data)
                    print("✅ 二维码已保存 (Base64)")
                else:
                    # 截图方式
                    await qr_element.screenshot(path=qr_path)
                    print("✅ 二维码已保存 (截图)")
                
                # 验证文件
                if os.path.exists(qr_path):
                    file_size = os.path.getsize(qr_path)
                    print()
                    print("=" * 50)
                    print(f"🎉 二维码生成成功！")
                    print(f"   路径: {qr_path}")
                    print(f"   大小: {file_size} bytes")
                    print("=" * 50)
                    print()
                    print("📱 请使用手机小红书APP扫码登录")
                    print()
                    await browser.close()
                    return True
            else:
                print("❌ 无法找到二维码元素")
                
            await browser.close()
            return False
            
    except Exception as e:
        print()
        print("=" * 50)
        print(f"❌ 生成失败: {e}")
        print("=" * 50)
        return False

if __name__ == '__main__':
    success = asyncio.run(generate_qr())
    exit(0 if success else 1)
PYTHON_SCRIPT

# 复制到容器
docker cp /tmp/generate_qr.py lobster-xhs-bot:/tmp/

echo "2️⃣ 生成二维码..."
echo "   预计时间：30-90秒"
echo ""

# 执行生成
docker exec lobster-xhs-bot python3 /tmp/generate_qr.py

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 二维码生成成功！"
    echo ""
    
    # 复制到宿主机
    echo "3️⃣ 复制二维码到宿主机..."
    docker cp lobster-xhs-bot:/app/data/qr_code.png /opt/lobster-xhs/data/qr_code.png
    
    if [ -f "/opt/lobster-xhs/data/qr_code.png" ]; then
        ls -lh /opt/lobster-xhs/data/qr_code.png
        echo ""
        echo "🎉 二维码文件位置:"
        echo "   容器内: /app/data/qr_code.png"
        echo "   宿主机: /opt/lobster-xhs/data/qr_code.png"
        echo ""
        echo "📱 请使用手机小红书APP扫码登录"
        echo ""
        echo "扫码后检查登录状态:"
        echo "   curl http://localhost:8080/login/status"
    else
        echo "❌ 复制失败"
        exit 1
    fi
else
    echo ""
    echo "❌ 二维码生成失败"
    echo "请检查日志: docker-compose logs"
    exit 1
fi
