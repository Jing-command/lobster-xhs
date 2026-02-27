#!/bin/bash
# 龙虾计划 - 一键部署脚本
# Lobster XHS Deployment Script

set -e

echo "🦞 龙虾计划部署脚本"
echo "===================="

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo "❌ 未检测到Docker，请先安装Docker"
    echo "安装指南: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ 未检测到docker-compose，请先安装"
    exit 1
fi

echo "✅ Docker环境检查通过"

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p data
mkdir -p logs

# 修改API密钥（提示用户）
echo ""
echo "⚠️ 重要：请修改API密钥！"
echo "请编辑 config/settings.yaml，修改 security.api_key"
echo "当前使用的是默认密钥，存在安全风险"
echo ""
read -p "按回车键继续..."

# 构建镜像
echo "🔨 构建Docker镜像..."
docker-compose build

# 启动服务
echo "🚀 启动服务..."
docker-compose up -d

echo ""
echo "✅ 部署完成！"
echo ""
echo "访问地址:"
echo "  - 健康检查: http://你的服务器IP:8080/"
echo "  - 登录二维码: http://你的服务器IP:8080/qr"
echo "  - 登录状态: http://你的服务器IP:8080/login/status"
echo ""
echo "查看日志:"
echo "  docker-compose logs -f"
echo ""
echo "下一步:"
echo "  1. 访问 http://你的服务器IP:8080/qr 获取二维码"
echo "  2. 使用小红书APP扫码登录"
echo "  3. 检查登录状态 /login/status"
echo "  4. 开始发布内容！"
