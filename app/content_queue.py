"""
内容队列管理
Content Queue Management
"""

import json
import os
import asyncio
from datetime import datetime
from typing import Dict, Any, List, Optional
import aiofiles


class ContentQueue:
    """内容发布队列"""
    
    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self.queue_file = os.path.join(data_dir, 'queue.json')
        os.makedirs(data_dir, exist_ok=True)
        
        # 初始化队列文件
        if not os.path.exists(self.queue_file):
            self._save_queue([])
    
    def _load_queue(self) -> List[Dict[str, Any]]:
        """加载队列"""
        try:
            with open(self.queue_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except:
            return []
    
    def _save_queue(self, queue: List[Dict[str, Any]]):
        """保存队列"""
        with open(self.queue_file, 'w', encoding='utf-8') as f:
            json.dump(queue, f, ensure_ascii=False, indent=2)
    
    async def add_task(self, task: Dict[str, Any]) -> str:
        """添加任务到队列"""
        import uuid
        task_id = str(uuid.uuid4())[:8]
        
        task['id'] = task_id
        task['status'] = 'pending'
        task['created_at'] = datetime.now().isoformat()
        task['updated_at'] = datetime.now().isoformat()
        
        queue = self._load_queue()
        queue.append(task)
        self._save_queue(queue)
        
        return task_id
    
    async def update_task(self, task_id: str, updates: Dict[str, Any]):
        """更新任务状态"""
        queue = self._load_queue()
        
        for task in queue:
            if task['id'] == task_id:
                task.update(updates)
                task['updated_at'] = datetime.now().isoformat()
                break
        
        self._save_queue(queue)
    
    async def get_task(self, task_id: str) -> Optional[Dict[str, Any]]:
        """获取单个任务"""
        queue = self._load_queue()
        for task in queue:
            if task['id'] == task_id:
                return task
        return None
    
    async def get_all_tasks(self) -> List[Dict[str, Any]]:
        """获取所有任务"""
        return self._load_queue()
    
    async def get_pending_tasks(self) -> List[Dict[str, Any]]:
        """获取待处理任务"""
        queue = self._load_queue()
        return [t for t in queue if t['status'] == 'pending']
    
    async def clear_completed(self):
        """清理已完成任务"""
        queue = self._load_queue()
        queue = [t for t in queue if t['status'] != 'completed']
        self._save_queue(queue)
