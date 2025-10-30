#!/bin/bash
# HTTP/3验证脚本
# 用于验证Envoy HTTP/3配置是否正常工作

echo "=========================================="
echo "  HTTP/3 配置验证脚本"
echo "  服务器: 62.234.212.241"
echo "  域名: www.qsgl.net"
echo "=========================================="
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查计数
PASS=0
FAIL=0

# 测试函数
test_item() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "检查 $name... "
    
    result=$(eval "$command" 2>&1)
    
    if echo "$result" | grep -q "$expected"; then
        echo -e "${GREEN}✅ 通过${NC}"
        ((PASS++))
        return 0
    else
        echo -e "${RED}❌ 失败${NC}"
        echo "  预期: $expected"
        echo "  实际: $result"
        ((FAIL++))
        return 1
    fi
}

echo "=== 1. 服务状态检查 ==="
echo ""

# 检查容器运行状态
test_item "Envoy容器运行状态" \
    "docker ps | grep envoy-proxy" \
    "Up"

# 检查UDP端口监听
test_item "UDP 443端口监听" \
    "sudo netstat -ulnp | grep ':443.*envoy'" \
    "envoy"

test_item "UDP 5002端口监听" \
    "sudo netstat -ulnp | grep ':5002.*envoy'" \
    "envoy"

echo ""
echo "=== 2. HTTP/3配置检查 ==="
echo ""

# 检查QUIC监听器统计
test_item "QUIC监听器配置" \
    "curl -s http://localhost:9901/stats | grep 'ingress_quic_443'" \
    "ingress_quic_443"

# 检查http3_protocol_options配置
test_item "HTTP3协议选项配置" \
    "grep -c 'http3_protocol_options' /opt/envoy/config/envoy.yaml" \
    "5"

# 检查ALPN协议
test_item "ALPN h3协议配置" \
    "grep -A 3 'alpn_protocols' /opt/envoy/config/envoy.yaml | grep -c 'h3'" \
    "2"

echo ""
echo "=== 3. Alt-Svc响应头检查 ==="
echo ""

# 检查Alt-Svc配置
test_item "Alt-Svc配置存在" \
    "grep -c 'alt-svc' /opt/envoy/config/envoy.yaml" \
    "3"

# 测试本地Alt-Svc响应
test_item "本地Alt-Svc响应" \
    "curl -I -k https://localhost:443/ 2>&1 | grep -i 'alt-svc'" \
    "h3="

# 测试公网Alt-Svc响应
test_item "公网Alt-Svc响应" \
    "curl -I https://www.qsgl.net/ 2>&1 | grep -i 'alt-svc'" \
    'h3=":443"'

echo ""
echo "=== 4. 证书和TLS检查 ==="
echo ""

# 检查证书文件
test_item "证书文件存在" \
    "ls -la /opt/certs/qsgl.net.fullchain.crt" \
    "qsgl.net.fullchain.crt"

test_item "私钥文件存在" \
    "ls -la /opt/certs/qsgl.net.key" \
    "qsgl.net.key"

echo ""
echo "=== 5. 连接测试 ==="
echo ""

# 测试UDP连通性
test_item "UDP 443连通性" \
    "timeout 2 nc -v -u -z 127.0.0.1 443 2>&1" \
    "succeeded"

# 测试HTTPS访问
test_item "HTTPS访问正常" \
    "curl -I https://www.qsgl.net/ 2>&1 | head -1" \
    "200"

echo ""
echo "=== 6. 统计信息 ==="
echo ""

echo "HTTP协议连接统计:"
curl -s http://localhost:9901/stats | grep -E 'downstream_cx_http[123]_total' | grep 'ingress_https_443'

echo ""
echo "QUIC监听器统计:"
curl -s http://localhost:9901/stats | grep 'ingress_quic_443.downstream_cx_http3_total'

echo ""
echo "=========================================="
echo "  验证结果统计"
echo "=========================================="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✅ 所有检查通过！HTTP/3已完全启用。${NC}"
    echo ""
    echo "下一步:"
    echo "1. 在Chrome浏览器中启用HTTP/3 (chrome://flags/#enable-quic)"
    echo "2. 访问测试页面: https://www.qsgl.net/test-http3.html"
    echo "3. 在开发者工具中验证协议为 h3"
    exit 0
else
    echo -e "${RED}❌ 发现 $FAIL 个问题，请检查配置。${NC}"
    exit 1
fi
