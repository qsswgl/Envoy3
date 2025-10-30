#!/bin/bash

###############################################################################
# Envoy 快速部署脚本
# 服务器: 62.234.212.241
###############################################################################

set -e

echo "=================================="
echo "Envoy 容器代理自动部署脚本"
echo "=================================="
echo ""

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 用户运行此脚本"
    exit 1
fi

# 步骤 1: 安装必要软件
echo "[1/6] 安装必要软件..."
apt update
apt install -y curl jq python3 python3-pip git docker.io docker-compose

# 启动 Docker
systemctl enable docker
systemctl start docker

# 安装 Python 依赖
pip3 install requests

# 步骤 2: 创建项目目录
echo "[2/6] 创建项目目录..."
mkdir -p /root/envoy/{certs,logs}
cd /root/envoy

# 步骤 3: 下载/准备配置文件
echo "[3/6] 准备配置文件..."
echo "请确保已将所有配置文件上传到 /root/envoy/ 目录"
echo "需要的文件:"
echo "  - envoy.yaml"
echo "  - Dockerfile"
echo "  - docker-compose.yml"
echo "  - generate-cert.py"
echo "  - diagnose.sh"
echo "  - monitor.py"
echo "  - envoy-monitor.service"

# 步骤 4: 生成证书
echo "[4/6] 生成 SSL 证书..."
if [ -f "generate-cert.py" ]; then
    python3 generate-cert.py
    if [ $? -eq 0 ]; then
        echo "✓ 证书生成成功"
    else
        echo "✗ 证书生成失败，请手动放置证书到 certs/ 目录"
        echo "  需要文件: certs/cert.pem, certs/key.pem"
        read -p "按回车继续..."
    fi
else
    echo "警告: generate-cert.py 不存在"
    echo "请手动放置证书到 certs/ 目录"
    read -p "按回车继续..."
fi

# 步骤 5: 启动容器
echo "[5/6] 构建并启动 Envoy 容器..."
docker-compose build
docker-compose up -d

# 等待容器启动
sleep 5

# 检查容器状态
if docker ps | grep -q envoy-proxy; then
    echo "✓ Envoy 容器启动成功"
else
    echo "✗ Envoy 容器启动失败"
    docker-compose logs
    exit 1
fi

# 步骤 6: 配置监控服务
echo "[6/6] 配置监控服务..."
if [ -f "envoy-monitor.service" ]; then
    cp envoy-monitor.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable envoy-monitor
    systemctl start envoy-monitor
    echo "✓ 监控服务已启动"
else
    echo "警告: envoy-monitor.service 不存在，跳过监控配置"
fi

# 完成
echo ""
echo "=================================="
echo "部署完成！"
echo "=================================="
echo ""
echo "服务状态:"
docker ps | grep envoy-proxy

echo ""
echo "端口监听:"
ss -tlnp | grep -E '443|5002|9901'

echo ""
echo "下一步操作:"
echo "1. 运行诊断脚本: ./diagnose.sh"
echo "2. 查看日志: docker-compose logs -f"
echo "3. 检查监控: systemctl status envoy-monitor"
echo "4. 测试访问: curl -k https://62.234.212.241"
echo ""
