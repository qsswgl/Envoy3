#!/bin/bash

###############################################################################
# Envoy 服务诊断脚本
# 功能：检查容器状态、网络连接、证书有效期等
###############################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 分隔线
print_separator() {
    echo "=============================================="
}

# 检查 Docker 服务
check_docker() {
    print_separator
    log_info "检查 Docker 服务状态..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker 服务未运行"
        return 1
    fi
    
    log_info "Docker 服务运行正常"
    docker --version
}

# 检查容器状态
check_container() {
    print_separator
    log_info "检查 Envoy 容器状态..."
    
    CONTAINER_NAME="envoy-proxy"
    
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_error "容器 ${CONTAINER_NAME} 不存在"
        return 1
    fi
    
    STATUS=$(docker inspect -f '{{.State.Status}}' ${CONTAINER_NAME})
    HEALTH=$(docker inspect -f '{{.State.Health.Status}}' ${CONTAINER_NAME} 2>/dev/null || echo "unknown")
    
    log_info "容器状态: $STATUS"
    log_info "健康状态: $HEALTH"
    
    if [ "$STATUS" != "running" ]; then
        log_error "容器未运行"
        log_info "查看容器日志:"
        docker logs --tail 50 ${CONTAINER_NAME}
        return 1
    fi
    
    if [ "$HEALTH" = "unhealthy" ]; then
        log_warn "容器健康检查失败"
    fi
}

# 检查端口监听
check_ports() {
    print_separator
    log_info "检查端口监听状态..."
    
    PORTS=(443 5002 9901)
    
    for port in "${PORTS[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
            log_info "端口 $port 正在监听 ✓"
        else
            log_warn "端口 $port 未监听"
        fi
    done
}

# 检查证书
check_certificate() {
    print_separator
    log_info "检查 SSL 证书..."
    
    CERT_FILE="./certs/cert.pem"
    
    if [ ! -f "$CERT_FILE" ]; then
        log_error "证书文件不存在: $CERT_FILE"
        return 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        log_warn "openssl 未安装，跳过证书检查"
        return 0
    fi
    
    log_info "证书信息:"
    openssl x509 -in "$CERT_FILE" -noout -subject -issuer
    
    log_info "证书有效期:"
    EXPIRY_DATE=$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)
    echo "  到期时间: $EXPIRY_DATE"
    
    # 检查证书是否即将过期（30天内）
    if openssl x509 -in "$CERT_FILE" -noout -checkend $((30*24*60*60)) > /dev/null; then
        log_info "证书有效（30天内不会过期）✓"
    else
        log_warn "证书将在30天内过期，请及时更新！"
    fi
}

# 检查后端连接
check_backend() {
    print_separator
    log_info "检查后端服务连接..."
    
    BACKEND_HOST="61.163.200.245"
    BACKEND_PORTS=(443 5002)
    
    for port in "${BACKEND_PORTS[@]}"; do
        if timeout 5 bash -c "cat < /dev/null > /dev/tcp/${BACKEND_HOST}/${port}" 2>/dev/null; then
            log_info "后端 ${BACKEND_HOST}:${port} 可达 ✓"
        else
            log_error "后端 ${BACKEND_HOST}:${port} 不可达"
        fi
    done
}

# 检查 Envoy Admin API
check_admin_api() {
    print_separator
    log_info "检查 Envoy Admin API..."
    
    if ! command -v curl &> /dev/null; then
        log_warn "curl 未安装，跳过 Admin API 检查"
        return 0
    fi
    
    # 健康检查
    if curl -sf http://localhost:9901/ready > /dev/null; then
        log_info "Envoy 就绪状态: 正常 ✓"
    else
        log_error "Envoy 就绪状态: 异常"
    fi
    
    # 统计信息
    log_info "Envoy 统计信息:"
    curl -s http://localhost:9901/stats | grep -E "http.ingress.*request|cluster.*upstream_cx" | head -10
}

# 检查容器日志
check_logs() {
    print_separator
    log_info "最近的容器日志（最后20行）:"
    docker logs --tail 20 envoy-proxy 2>&1
}

# 检查资源使用
check_resources() {
    print_separator
    log_info "容器资源使用情况:"
    docker stats --no-stream envoy-proxy
}

# 主函数
main() {
    echo ""
    log_info "开始 Envoy 服务诊断..."
    echo ""
    
    check_docker
    check_container
    check_ports
    check_certificate
    check_backend
    check_admin_api
    check_logs
    check_resources
    
    print_separator
    log_info "诊断完成"
    echo ""
}

main "$@"
