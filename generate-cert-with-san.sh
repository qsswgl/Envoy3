#!/bin/bash
# 生成带 SAN (Subject Alternative Name) 的通配符证书
# 用于 Chrome/Edge 等现代浏览器

DOMAIN="*.qsgl.net"
DAYS=365
CERT_DIR="./certs"

mkdir -p "$CERT_DIR"

# 创建 OpenSSL 配置文件
cat > "$CERT_DIR/cert.conf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = CN
ST = Beijing
L = Beijing
O = QSGL
OU = IT
CN = *.qsgl.net

[v3_req]
subjectAltName = @alt_names
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = *.qsgl.net
DNS.2 = qsgl.net
DNS.3 = www.qsgl.net
EOF

echo "=== 生成带 SAN 的 SSL 证书 ==="

# 生成私钥
openssl genrsa -out "$CERT_DIR/key.pem" 2048

# 生成证书签名请求 (CSR)
openssl req -new -key "$CERT_DIR/key.pem" -out "$CERT_DIR/cert.csr" -config "$CERT_DIR/cert.conf"

# 生成自签名证书（带 SAN）
openssl x509 -req -days $DAYS \
    -in "$CERT_DIR/cert.csr" \
    -signkey "$CERT_DIR/key.pem" \
    -out "$CERT_DIR/cert.pem" \
    -extensions v3_req \
    -extfile "$CERT_DIR/cert.conf"

# 设置权限
chmod 644 "$CERT_DIR/cert.pem"
chmod 644 "$CERT_DIR/key.pem"

# 验证证书
echo ""
echo "=== 证书信息 ==="
openssl x509 -in "$CERT_DIR/cert.pem" -text -noout | grep -E "Subject:|Issuer:|DNS:"

echo ""
echo "=== 证书生成完成 ==="
echo "证书文件: $CERT_DIR/cert.pem"
echo "私钥文件: $CERT_DIR/key.pem"
echo ""
echo "Chrome/Edge 浏览器需要将此证书添加到系统信任列表"
