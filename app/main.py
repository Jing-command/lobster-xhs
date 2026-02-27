"""
小红书自动化发布系统 - 主入口
Lobster XHS Automation - Main Entry
"""

import asyncio
import json
import os
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Optional

import uvicorn
import yaml
from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.responses import JSONResponse, StreamingResponse, FileResponse
from pydantic import BaseModel
import base64

from .xhs_bot import XHSBot
from .content_queue import ContentQueue

# 加载配置
CONFIG_PATH = "/app/config/settings.yaml"
with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
    config = yaml.safe_load(f)

# 全局实例
bot: Optional[XHSBot] = None
queue: Optional[ContentQueue] = None


class PublishRequest(BaseModel):
    """发布请求"""
    title: str
    content: str
    images: list = []
    tags: list = []
    api_key: str


class ReplyRequest(BaseModel):
    """回复请求"""
    note_id: str
    comment_id: str
    content: str
    api_key: str


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    global bot, queue
    
    # 启动时初始化
    print("🦞 龙虾计划启动中...")
    queue = ContentQueue(config['system']['data_dir'])
    bot = XHSBot(config)
    
    # 检查登录状态
    is_logged_in = await bot.check_login()
    if not is_logged_in:
        print("⚠️ 未登录，请访问 /qr 获取二维码")
    else:
        print("✅ 已登录，系统就绪")
    
    yield
    
    # 关闭时清理
    print("🛑 系统关闭中...")
    if bot:
        await bot.close()


app = FastAPI(
    title="Lobster XHS Automation",
    description="小红书AI自动化发布系统",
    version="1.0.0",
    lifespan=lifespan
)


def verify_api_key(api_key: str) -> bool:
    """验证API密钥"""
    expected = config['security']['api_key']
    if expected == "change-this-to-your-secret-key":
        print("⚠️ 警告：正在使用默认API密钥，请修改 config/settings.yaml")
    return api_key == expected


@app.get("/")
async def root():
    """根路径 - 健康检查"""
    return {
        "status": "running",
        "name": "Lobster XHS Automation",
        "version": "1.0.0",
        "logged_in": bot.is_logged_in if bot else False
    }


@app.get("/qr")
async def get_qr_code():
    """
    获取登录二维码
    返回二维码图片URL或base64
    """
    if not bot:
        raise HTTPException(500, "系统未初始化")
    
    try:
        qr_data = await bot.get_login_qr()
        # 保存二维码图片到文件
        if qr_data.get("base64"):
            img_data = base64.b64decode(qr_data["base64"])
            qr_path = "/app/data/qr_code.png"
            with open(qr_path, "wb") as f:
                f.write(img_data)
        return {
            "success": True,
            "qr_url": qr_data.get("url"),
            "qr_base64": qr_data.get("base64"),
            "expire_seconds": 180,
            "message": "请使用小红书APP扫码登录，或访问 /qr-image 查看图片"
        }
    except Exception as e:
        raise HTTPException(500, f"获取二维码失败: {str(e)}")


@app.get("/qr-image")
async def get_qr_image():
    """
    获取登录二维码图片文件
    直接返回PNG图片，方便无图形界面服务器使用
    """
    qr_path = "/app/data/qr_code.png"
    
    # 如果文件不存在，尝试重新生成
    if not os.path.exists(qr_path):
        if not bot:
            raise HTTPException(500, "系统未初始化")
        try:
            qr_data = await bot.get_login_qr()
            if qr_data.get("base64"):
                img_data = base64.b64decode(qr_data["base64"])
                with open(qr_path, "wb") as f:
                    f.write(img_data)
        except Exception as e:
            raise HTTPException(500, f"生成二维码失败: {str(e)}")
    
    if os.path.exists(qr_path):
        return FileResponse(qr_path, media_type="image/png", filename="qr_code.png")
    else:
        raise HTTPException(404, "二维码图片不存在")


@app.get("/login/status")
async def login_status():
    """检查登录状态"""
    if not bot:
        return {"logged_in": False}
    
    is_logged_in = await bot.check_login()
    return {
        "logged_in": is_logged_in,
        "account_info": bot.account_info if is_logged_in else None
    }


@app.post("/publish")
async def publish_content(request: PublishRequest, background_tasks: BackgroundTasks):
    """
    发布内容到小红书
    支持图文、纯文字
    """
    if not verify_api_key(request.api_key):
        raise HTTPException(403, "API密钥无效")
    
    if not bot or not bot.is_logged_in:
        raise HTTPException(401, "未登录，请先扫码登录")
    
    # 添加到队列异步处理
    task_id = await queue.add_task({
        "type": "publish",
        "title": request.title,
        "content": request.content,
        "images": request.images,
        "tags": request.tags,
        "created_at": datetime.now().isoformat()
    })
    
    # 后台执行发布
    background_tasks.add_task(bot.publish_note, task_id, request.dict())
    
    return {
        "success": True,
        "task_id": task_id,
        "message": "内容已加入发布队列"
    }


@app.get("/comments")
async def get_comments(api_key: str, limit: int = 20):
    """获取最新评论"""
    if not verify_api_key(api_key):
        raise HTTPException(403, "API密钥无效")
    
    if not bot:
        raise HTTPException(500, "系统未初始化")
    
    comments = await bot.get_recent_comments(limit)
    return {
        "success": True,
        "comments": comments,
        "count": len(comments)
    }


@app.post("/reply")
async def reply_comment(request: ReplyRequest):
    """回复评论"""
    if not verify_api_key(request.api_key):
        raise HTTPException(403, "API密钥无效")
    
    if not bot or not bot.is_logged_in:
        raise HTTPException(401, "未登录")
    
    success = await bot.reply_comment(request.note_id, request.comment_id, request.content)
    return {
        "success": success,
        "message": "回复成功" if success else "回复失败"
    }


@app.get("/queue")
async def get_queue_status(api_key: str):
    """获取发布队列状态"""
    if not verify_api_key(api_key):
        raise HTTPException(403, "API密钥无效")
    
    if not queue:
        return {"tasks": [], "count": 0}
    
    tasks = await queue.get_all_tasks()
    return {
        "tasks": tasks,
        "pending": len([t for t in tasks if t["status"] == "pending"]),
        "completed": len([t for t in tasks if t["status"] == "completed"]),
        "failed": len([t for t in tasks if t["status"] == "failed"])
    }


@app.get("/logs")
async def get_logs(lines: int = 50):
    """获取最近日志"""
    log_file = "/app/data/system.log"
    if not os.path.exists(log_file):
        return {"logs": []}
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            all_lines = f.readlines()
            return {"logs": all_lines[-lines:]}
    except Exception as e:
        return {"error": str(e)}


if __name__ == "__main__":
    port = config['system']['port']
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        log_level=config['system']['log_level'].lower()
    )
