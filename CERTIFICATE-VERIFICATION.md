# 证书验证说明

## 🎉 Let's Encrypt证书已成功部署！

### 证书详情
- **域名**: *.qsgl.net (泛域名证书，覆盖www.qsgl.net)
- **颁发机构**: Let's Encrypt Authority X7 (E7)
- **证书类型**: Domain Validation (DV)
- **加密算法**: ECDSA P-256 (ECC)
- **有效期**: 2025-10-20 至 2026-01-18 (90天有效期)
- **序列号**: 05:ce:e4:6d:08:27:68:08:2c:6e:c3:7a:2e:fa:ca:d4:21:4c

### 浏览器验证步骤

#### 方法1: Chrome浏览器
1. 打开 https://www.qsgl.net
2. 点击地址栏左侧的🔒锁图标
3. 点击"证书"或"Connection is secure" → "Certificate is valid"
4. 查看证书详情:
   - **颁发给**: qsgl.net
   - **颁发者**: Let's Encrypt Authority X7 (E7)
   - **主题备用名称**: *.qsgl.net, qsgl.net

#### 方法2: Firefox浏览器
1. 打开 https://www.qsgl.net
2. 点击地址栏左侧的🔒锁图标
3. 点击"连接安全" → "更多信息"
4. 点击"查看证书"按钮
5. 验证"颁发者"为Let's Encrypt

#### 方法3: Edge浏览器
1. 打开 https://www.qsgl.net
2. 点击地址栏左侧的🔒锁图标
3. 点击"连接是安全的" → "证书"
4. 查看证书详情

#### 方法4: 命令行验证
```bash
# PowerShell (Windows)
curl.exe -v https://www.qsgl.net/ 2>&1 | Select-String "issuer"

# 输出应包含: issuer: C=US; O=Let's Encrypt; CN=E7
```

```bash
# Linux/Mac
openssl s_client -connect www.qsgl.net:443 -servername www.qsgl.net < /dev/null 2>/dev/null | openssl x509 -noout -text | grep -E "(Issuer|Subject|Not)"

# 输出应显示:
# Issuer: C = US, O = Let's Encrypt, CN = E7
# Subject: CN = qsgl.net
# Not Before: Oct 20 05:38:51 2025 GMT
# Not After : Jan 18 05:38:50 2026 GMT
```

### 在线证书检测工具

1. **SSL Labs测试**: https://www.ssllabs.com/ssltest/analyze.html?d=www.qsgl.net
   - 评估SSL配置质量
   - 检测协议支持情况
   - 验证证书链完整性

2. **DigiCert工具**: https://www.digicert.com/help/
   - 快速证书验证

3. **WhatsMyDNS**: https://www.whatsmydns.net/#A/www.qsgl.net
   - 检查DNS解析是否正确

### 证书特性

#### ✅ 优点
- **免费**: Let's Encrypt完全免费
- **自动化**: 可通过ACME协议自动续订
- **浏览器信任**: 所有主流浏览器都信任Let's Encrypt
- **泛域名支持**: *.qsgl.net覆盖所有子域名
- **现代加密**: ECC算法，性能优于传统RSA

#### ⚠️ 注意事项
- **有效期短**: 90天，需定期续订（建议60天时更新）
- **DV级别**: 只验证域名所有权，不验证企业身份
- **速率限制**: 每周最多申请50次相同域名证书

### HTTP/3 (QUIC) 验证

检查是否支持HTTP/3:

```bash
# 使用curl (需要HTTP/3支持版本)
curl --http3 https://www.qsgl.net/ -I

# 查看Alt-Svc响应头
curl -I https://www.qsgl.net/ | grep -i alt-svc
# 输出: alt-svc: h3=":443"; ma=86400
```

浏览器支持检测:
- Chrome 87+: 默认启用QUIC
- Edge 87+: 默认启用QUIC
- Firefox 88+: 需要在about:config中启用network.http.http3.enabled

### 证书续订

#### 方法1: 使用tx.qsgl.net证书API
证书管理系统已配置www.qsgl.net的自动续订（renewDaysBefore: 30天）

#### 方法2: 手动通过API申请
```bash
# 需要从tx.qsgl.net服务器调用
curl -X POST https://tx.qsgl.net:5075/api/request-cert \
  -H "Content-Type: application/json" \
  -d '{
    "domain": "qsgl.net",
    "provider": "DNSPOD",
    "certType": "ECDSA256",
    "exportFormat": "PEM",
    "isWildcard": true
  }' -k
```

#### 方法3: 手动使用certbot（需要DNS指向正确服务器）
```bash
# 在62.234.212.241上
sudo certbot certonly --webroot -w /var/www/html -d www.qsgl.net
```

### 故障排查

#### 浏览器仍显示不安全或自签名证书
**可能原因**:
1. **浏览器缓存**: 清除浏览器缓存和SSL状态
   - Chrome: 设置 → 隐私和安全 → 清除浏览数据 → 缓存的图片和文件
   - 在chrome://net-internals/#sockets点击"Flush socket pools"

2. **DNS缓存**: 刷新本地DNS缓存
   ```cmd
   # Windows
   ipconfig /flushdns
   
   # Mac
   sudo dscacheutil -flushcache
   
   # Linux
   sudo systemd-resolve --flush-caches
   ```

3. **中间人代理**: 检查是否使用公司代理或防火墙
   - 检查证书颁发者是否为Let's Encrypt
   - 如果显示公司名称，说明有SSL解密代理

4. **证书链问题**: Envoy未加载中间证书
   ```bash
   # 验证证书链完整性
   openssl s_client -connect www.qsgl.net:443 -servername www.qsgl.net < /dev/null 2>/dev/null | grep -c "BEGIN CERTIFICATE"
   # 应该输出2（服务器证书+中间证书）
   ```

#### 证书链验证
```bash
# 下载完整证书链
openssl s_client -connect www.qsgl.net:443 -servername www.qsgl.net -showcerts < /dev/null 2>/dev/null > /tmp/cert_chain.pem

# 验证链完整性
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt /tmp/cert_chain.pem
# 输出: /tmp/cert_chain.pem: OK
```

### 测试结果预期

✅ **正常状态**:
- 浏览器地址栏显示🔒锁图标（绿色或灰色）
- 点击锁图标显示"连接是安全的"
- 证书颁发者为"Let's Encrypt"
- 证书有效期显示为2026-01-18
- 没有安全警告或错误提示

❌ **异常状态**:
- 显示"不安全"或红色警告
- 证书颁发者显示为"*.qsgl.net"（自签名）
- 浏览器提示"NET::ERR_CERT_AUTHORITY_INVALID"
- 提示证书过期

### 当前部署状态

根据测试结果:
- ✅ Envoy容器正常运行
- ✅ Let's Encrypt证书已加载
- ✅ 服务器端证书验证通过
- ✅ 公网HTTPS访问返回200 OK
- ✅ Alt-Svc头正确返回(支持HTTP/3)

**建议**: 现在可以用浏览器访问 https://www.qsgl.net 验证证书显示！
