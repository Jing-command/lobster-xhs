"""
小红书自动化操作核心
Xiaohongshu Automation Core
"""

import asyncio
import json
import os
import base64
import io
from typing import Optional, Dict, Any
from datetime import datetime

from playwright.async_api import async_playwright, Page, Browser, BrowserContext
import qrcode


class XHSBot:
    """小红书自动化机器人"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.browser: Optional[Browser] = None
        self.context: Optional[BrowserContext] = None
        self.page: Optional[Page] = None
        self.is_logged_in = False
        self.account_info = {}
        self.cookie_file = config['xiaohongshu']['cookie_file']
        
    async def init_browser(self):
        """初始化浏览器"""
        if self.browser:
            return
            
        self.playwright = await async_playwright().start()
        self.browser = await self.playwright.chromium.launch(
            headless=True,  # 无头模式
            args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--disable-gpu',
                '--window-size=1920,1080'
            ]
        )
        
        self.context = await self.browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        )
        
        # 加载Cookie（如果存在）
        if os.path.exists(self.cookie_file):
            with open(self.cookie_file, 'r') as f:
                cookies = json.load(f)
                await self.context.add_cookies(cookies)
                print(f"✅ 已加载 {len(cookies)} 个Cookie")
        
        self.page = await self.context.new_page()
        
    async def close(self):
        """关闭浏览器"""
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()
        if hasattr(self, 'playwright'):
            await self.playwright.stop()
    
    async def check_login(self) -> bool:
        """检查登录状态"""
        await self.init_browser()
        
        try:
            await self.page.goto("https://www.xiaohongshu.com", timeout=120000)
            await asyncio.sleep(3)
            
            # 检查是否有用户头像或用户名元素
            # 小红书登录后会有特定的DOM元素
            user_elements = await self.page.query_selector_all('.user-name, .avatar, .user-info')
            
            if user_elements:
                self.is_logged_in = True
                # 获取账号信息
                try:
                    avatar = await self.page.query_selector('.avatar img')
                    if avatar:
                        self.account_info['avatar'] = await avatar.get_attribute('src')
                    
                    username = await self.page.query_selector('.user-name')
                    if username:
                        self.account_info['username'] = await username.text_content()
                except:
                    pass
                
                # 保存Cookie
                await self._save_cookies()
                return True
            else:
                self.is_logged_in = False
                return False
                
        except Exception as e:
            print(f"检查登录状态出错: {e}")
            return False
    
    async def get_login_qr(self) -> Dict[str, str]:
        """获取登录二维码 - 优化版"""
        await self.init_browser()
        
        try:
            print("🌐 访问小红书...")
            await self.page.goto("https://www.xiaohongshu.com", timeout=120000)
            
            # 等待页面完全加载
            print("⏳ 等待页面加载...")
            await asyncio.sleep(5)
            
            # 先截图看看页面状态
            await self.page.screenshot(path='/app/data/page_loaded.png')
            print("📸 页面截图已保存")
            
            # 尝试多种方式找到二维码
            qr_selectors = [
                'img.qr-code',
                '.qrcode img',
                '.login-qrcode img',
                '[class*="qr"] img',
                '[class*="login"] img',
                'canvas',
            ]
            
            qr_element = None
            for selector in qr_selectors:
                try:
                    print(f"🔍 尝试: {selector}")
                    qr_element = await self.page.wait_for_selector(selector, timeout=8000)
                    if qr_element:
                        print(f"✅ 找到: {selector}")
                        break
                except:
                    continue
            
            # 如果没找到，尝试点击登录按钮
            if not qr_element:
                print("⏳ 点击登录按钮...")
                login_selectors = ['.login-btn', '.login-entry', '[class*="login"]']
                
                for selector in login_selectors:
                    try:
                        login_btn = await self.page.wait_for_selector(selector, timeout=5000)
                        if login_btn:
                            await login_btn.click()
                            print(f"✅ 点击: {selector}")
                            await asyncio.sleep(3)
                            break
                    except:
                        continue
                
                # 再次尝试找二维码
                for selector in qr_selectors:
                    try:
                        qr_element = await self.page.wait_for_selector(selector, timeout=15000)
                        if qr_element:
                            print(f"✅ 找到: {selector}")
                            break
                    except:
                        continue
            
            if qr_element:
                await asyncio.sleep(2)
                qr_src = await qr_element.get_attribute('src')
                
                if qr_src and qr_src.startswith('data:image'):
                    base64_data = qr_src.split(',')[1]
                    print("✅ 获取Base64二维码")
                    return {"url": qr_src, "base64": base64_data}
                else:
                    screenshot = await qr_element.screenshot()
                    base64_data = base64.b64encode(screenshot).decode()
                    print("✅ 截图二维码")
                    return {"url": None, "base64": base64_data}
            
            raise Exception("未找到二维码")
            
        except Exception as e:
            print(f"❌ 错误: {e}")
            if self.page:
                await self.page.screenshot(path='/app/data/qr_error.png')
            raise
    
    async def wait_for_login(self, timeout: int = 180) -> bool:
        """等待扫码登录完成"""
        start_time = asyncio.get_event_loop().time()
        
        while (asyncio.get_event_loop().time() - start_time) < timeout:
            is_logged_in = await self.check_login()
            if is_logged_in:
                return True
            await asyncio.sleep(3)
        
        return False
    
    async def _save_cookies(self):
        """保存Cookie到文件"""
        if not self.context:
            return
        
        cookies = await self.context.cookies()
        os.makedirs(os.path.dirname(self.cookie_file), exist_ok=True)
        
        with open(self.cookie_file, 'w') as f:
            json.dump(cookies, f, indent=2)
        
        print(f"💾 Cookie已保存到 {self.cookie_file}")
    
    async def publish_note(self, task_id: str, content: Dict[str, Any]) -> bool:
        """
        发布笔记
        注意：这是简化版本，实际需要根据小红书网页版DOM结构调整
        """
        if not self.is_logged_in:
            print("❌ 未登录，无法发布")
            return False
        
        try:
            # 打开发布页面
            await self.page.goto("https://creator.xiaohongshu.com/publish/publish")
            await asyncio.sleep(3)
            
            # 填写标题
            title_input = await self.page.query_selector('input[placeholder*="标题"], .title-input input')
            if title_input:
                await title_input.fill(content['title'])
            
            # 填写正文
            content_editor = await self.page.query_selector('.editor-content, [contenteditable="true"]')
            if content_editor:
                await content_editor.fill(content['content'])
            
            # 上传图片（如果有）
            if content.get('images'):
                # 实现图片上传逻辑
                pass
            
            # 添加标签
            if content.get('tags'):
                for tag in content['tags']:
                    # 添加标签逻辑
                    pass
            
            # 点击发布
            publish_btn = await self.page.query_selector('.publish-btn, button:has-text("发布")')
            if publish_btn:
                await publish_btn.click()
                await asyncio.sleep(5)
                
                # 检查是否发布成功
                success_indicator = await self.page.query_selector('.success, .publish-success')
                if success_indicator:
                    print(f"✅ 发布成功: {content['title']}")
                    return True
            
            return False
            
        except Exception as e:
            print(f"❌ 发布失败: {e}")
            # 保存错误截图
            if self.page:
                await self.page.screenshot(path=f'/app/data/error_{task_id}.png')
            return False
    
    async def get_recent_comments(self, limit: int = 20) -> list:
        """获取最近评论"""
        # 实现评论获取逻辑
        return []
    
    async def reply_comment(self, note_id: str, comment_id: str, content: str) -> bool:
        """回复评论"""
        # 实现回复逻辑
        return False
