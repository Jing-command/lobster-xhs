#!/bin/bash
# 龙虾计划 - 一键部署脚本
# Lobster XHS Automation Deployment Script

set -e

echo "🦞 龙虾计划部署脚本"
echo "===================="

# 检查Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "❌ 未检测到Docker，请先安装Docker"
    echo "安装指南: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose >/dev/null 2>&1; then
    echo "❌ 未检测到docker-compose，请先安装"
    exit 1
fi

echo "✅ Docker环境检查通过"

# 创建数据目录
echo "📁 创建数据目录..."
mkdir -p data
mkdir -p logs

# 检查API密钥是否已修改
echo ""
echo "🔐 检查API密钥配置..."

# 读取当前API密钥
if [ -f "config/settings.yaml" ]; then
    # 提取api_key值
    CURRENT_KEY=$(cat config/settings.yaml | grep "api_key:" | head -1 | sed 's/.*api_key:[ ]*//' | sed 's/"//g' | tr -d ' ')
    
    if [ "$CURRENT_KEY" = "change-this-to-your-secret-key" ] || [ -z "$CURRENT_KEY" ]; then
        echo ""
        echo "❌ 错误：你还没有修改API密钥！"
        echo ""
        echo "请执行以下步骤："
        echo "  1. nano config/settings.yaml"
        echo "  2. 找到 security.api_key"
        echo "  3. 将 \"change-this-to-your-secret-key\" 改为随机字符串"
        echo "  4. Ctrl+X → Y → Enter 保存"
        echo ""
        echo "示例密钥："
        echo "  api_key: \"mj30a6vatsAUHWJG3XAv8RIsGi7XvL6cZ2QPXYEo7qJe8JSx\""
        echo ""
        read -p "修改完成后按回车键继续，或按 Ctrl+C 退出..."
        
        # 再次检查
        CURRENT_KEY=$(cat config/settings.yaml | grep "api_key:" | head -1 | sed 's/.*api_key:[ ]*//' | sed 's/"//g' | tr -d ' ')
        if [ "$CURRENT_KEY" = "change-this-to-your-secret-key" ] || [ -z "$CURRENT_KEY" ]; then
            echo "❌ API密钥仍未修改，部署终止！"
            exit 1
        fi
    fi
    
    echo "✅ API密钥已配置"
else
    echo "❌ 配置文件不存在：config/settings.yaml"
    exit 1
fi

echo ""

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
