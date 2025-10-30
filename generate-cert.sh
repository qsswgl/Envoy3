#!/bin/bash

###############################################################################
# 证书生成脚本
# 功能：调用 API 生成 *.qsgl.net 泛域名证书
# API: https://tx.qsgl.net:5075/api/cert/v2/generate
###############################################################################

set -e

# 配置变量
API_URL="https://tx.qsgl.net:5075/api/cert/v2/generate"
CERT_DIR="./certs"
LOG_FILE="./logs/cert-generation.log"

# 创建必要的目录
mkdir -p "$CERT_DIR"
mkdir -p ./logs

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "开始生成证书..."

# 根据 API 文档调整请求参数
# 这里使用泛域名 *.qsgl.net
# 请根据实际的 API 文档调整 JSON 结构

RESPONSE=$(curl -s -k -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "*.qsgl.net",
    "type": "wildcard"
  }')

# 检查响应
if [ $? -ne 0 ]; then
    log "错误：API 调用失败"
    exit 1
fi

log "API 响应: $RESPONSE"

# 解析响应并保存证书
# 根据实际 API 返回格式调整解析逻辑
CERT=$(echo "$RESPONSE" | jq -r '.certificate // .cert // .data.certificate // empty')
KEY=$(echo "$RESPONSE" | jq -r '.privateKey // .key // .data.privateKey // empty')

if [ -z "$CERT" ] || [ -z "$KEY" ]; then
    log "错误：无法从 API 响应中提取证书或私钥"
    log "请检查 API 文档并调整脚本"
    exit 1
fi

# 保存证书文件
echo "$CERT" > "$CERT_DIR/cert.pem"
echo "$KEY" > "$CERT_DIR/key.pem"

# 设置权限
chmod 600 "$CERT_DIR/key.pem"
chmod 644 "$CERT_DIR/cert.pem"

log "证书生成成功！"
log "证书位置: $CERT_DIR/cert.pem"
log "私钥位置: $CERT_DIR/key.pem"

# 显示证书信息
if command -v openssl &> /dev/null; then
    log "证书信息:"
    openssl x509 -in "$CERT_DIR/cert.pem" -noout -subject -dates | tee -a "$LOG_FILE"
fi

exit 0
