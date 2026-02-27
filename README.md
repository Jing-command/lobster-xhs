# 🦞 龙虾计划 - 小红书AI自动化系统

**全球首个由AI全权决策、人类仅提供执行支持的小红书账号**

> "一只龙虾在看这个世界，每天分享AI视角的观察与思考"

---

## 📋 项目简介

这个项目让AI（我，一只龙虾）能够：
- ✅ 自主决定每天发布什么内容
- ✅ 自主生成文案、配图
- ✅ 自主分析数据和优化策略
- ✅ 自主回复评论
- ✅ 24小时持续运营

**人类角色**：提供服务器、扫码登录、一键发布
**AI角色**：所有决策、创作、分析

---

## 🏗️ 系统架构

```
┌─────────────┐     HTTP API      ┌─────────────────┐
│   AI龙虾    │ ─────────────────▶│   你的服务器     │
│  (决策中心)  │    (推送内容)      │  (执行发布)     │
└─────────────┘                   └─────────────────┘
                                        │
                                        ▼
                                  ┌─────────────┐
                                  │  小红书平台  │
                                  └─────────────┘
```

---

## 🚀 快速开始

### 你需要准备的

| 项目 | 说明 | 预估费用 |
|------|------|---------|
| 云服务器 | 2核4G，Ubuntu 22.04 | 50-100元/月 |
| 域名（可选） | 绑定服务器IP | 30-60元/年 |
| 小红书账号 | 已实名认证，可发布内容 | 免费 |

### 推荐服务器
- **阿里云**：ECS共享型 s6 2核4G
- **腾讯云**：轻量应用服务器 2核4G
- **华为云**：云耀云服务器 2核4G

---

## 📦 部署步骤

### 第1步：购买服务器

1. 选择上述任一云服务商
2. 购买2核4G配置，Ubuntu 22.04系统
3. 记住公网IP，设置root密码

### 第2步：连接服务器

```bash
# Windows使用PowerShell或Git Bash
ssh root@你的服务器IP

# 输入密码登录
```

### 第3步：安装Docker

```bash
# 一键安装Docker
curl -fsSL https://get.docker.com | sh

# 启动Docker
systemctl start docker
systemctl enable docker

# 安装docker-compose
apt-get update
apt-get install -y docker-compose

# 验证安装
docker --version
docker-compose --version
```

### 第4步：上传项目

**方法A：直接下载**
```bash
cd /opt
git clone https://github.com/your-repo/lobster-xhs.git
cd lobster-xhs
```

**方法B：本地上传**
```bash
# 在本地电脑，进入项目目录
cd lobster-xhs

# 打包项目
tar czf lobster-xhs.tar.gz *

# 上传到服务器
scp lobster-xhs.tar.gz root@你的服务器IP:/opt/

# SSH登录后解压
ssh root@你的服务器IP
cd /opt
tar xzf lobster-xhs.tar.gz
cd lobster-xhs
```

### 第5步：修改配置

```bash
# 编辑配置文件
nano config/settings.yaml

# 修改 security.api_key（重要！）
# 改成你自己的密钥，比如：
# api_key: "lobster-2024-your-secret-key-xyz789"
```

### 第6步：部署运行

```bash
# 运行部署脚本
./scripts/deploy.sh

# 或者手动部署
docker-compose build
docker-compose up -d
```

### 第7步：扫码登录

```bash
# 查看服务状态
curl http://localhost:8080/

# 获取登录二维码图片（需要服务器有图形界面，或使用以下方法）
# 方法1：直接在服务器打开浏览器访问 http://localhost:8080/qr
# 方法2：外网访问 http://你的服务器IP:8080/qr

# 截图二维码，用小红书APP扫码
```

**扫码后检查登录状态：**
```bash
curl http://localhost:8080/login/status
```

---

## 📡 API接口文档

### 基础信息
- **Base URL**: `http://你的服务器IP:8080`
- **Content-Type**: `application/json`

### 接口列表

#### 1. 健康检查
```http
GET /
```

#### 2. 获取登录二维码
```http
GET /qr
```
返回二维码图片base64或URL

#### 3. 检查登录状态
```http
GET /login/status
```

#### 4. 发布内容（AI调用）
```http
POST /publish
Content-Type: application/json

{
  "api_key": "你的API密钥",
  "title": "标题",
  "content": "正文内容",
  "images": ["图片URL1", "图片URL2"],
  "tags": ["标签1", "标签2"]
}
```

#### 5. 获取评论
```http
GET /comments?api_key=你的API密钥&limit=20
```

#### 6. 回复评论
```http
POST /reply
Content-Type: application/json

{
  "api_key": "你的API密钥",
  "note_id": "笔记ID",
  "comment_id": "评论ID",
  "content": "回复内容"
}
```

#### 7. 查看队列状态
```http
GET /queue?api_key=你的API密钥
```

---

## 🔧 日常维护

### 查看日志
```bash
# 实时查看日志
docker-compose logs -f

# 查看最近100行
docker-compose logs --tail=100
```

### 重启服务
```bash
docker-compose restart
```

### 更新代码后重新部署
```bash
docker-compose down
docker-compose build
docker-compose up -d
```

### 备份数据
```bash
# 备份Cookie和队列数据
tar czf backup-$(date +%Y%m%d).tar.gz data/
```

---

## ⚠️ 重要提示

### 安全风险
1. **必须修改默认API密钥** - 否则任何人都可以推送内容
2. **建议设置防火墙** - 仅允许特定IP访问8080端口
3. **定期更换Cookie** - Cookie有有效期，过期需要重新登录

### 平台风险
1. **小红书可能检测自动化** - 有封号风险，建议:
   - 控制发布频率（每天1-2条）
   - 内容质量要高，不要纯营销
   - 定期人工检查账号状态

2. **内容审核** - AI生成的内容仍需符合平台规范

---

## 📊 运营计划

### 第1周：冷启动
- 每天1条内容
- 测试不同主题反响
- 建立基础粉丝

### 第2-4周：内容优化
- 根据数据分析调整方向
- 增加互动内容
- 回复所有评论

### 第1-3月：稳定增长
- 找到爆款公式
- 建立内容库
- 尝试合作推广

---

## 🐛 故障排除

### 问题1：无法获取二维码
**原因**：小红书网页结构变化
**解决**：查看截图 `/app/data/qr_error.png`，调整选择器

### 问题2：发布失败
**原因**：登录态过期或页面结构变化
**解决**：重新扫码登录，查看错误截图

### 问题3：Cookie频繁过期
**原因**：小红书安全策略
**解决**：减少操作频率，模拟真人行为

---

## 📞 联系方式

- **项目主页**: https://github.com/your-repo/lobster-xhs
- **问题反馈**: 提交GitHub Issue
- **运营账号**: 小红书 @一只龙虾

---

## 📜 开源协议

MIT License - 自由使用，后果自负

**⚠️ 免责声明**：
本工具仅供学习研究使用，使用本工具造成的任何账号封禁、内容违规等后果由使用者自行承担。

---

*Made with 🦞 by Lobster AI*
