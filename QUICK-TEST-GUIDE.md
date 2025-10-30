# 🎯 快速测试参考卡

## 当前状态
✅ **证书**: 包含 SAN (DNS:*.qsgl.net, DNS:qsgl.net)
✅ **HTTP/3**: 已启用 (Alt-Svc: h3=":443"; ma=86400)
✅ **端口**: 443, 99, 5002 全部正常
⚠️ **证书类型**: 自签名 (浏览器会警告)

---

## 🌐 浏览器测试 3 步骤

### Chrome/Edge:
```
1. 访问 https://www.qsgl.net
2. 点击 "高级" → "继续访问"
3. ✅ 页面正常加载
```

### Firefox:
```
1. 访问 https://www.qsgl.net
2. 点击 "接受风险并继续"
3. ✅ 页面正常加载
```

---

## ⚠️ 重要说明

### 证书警告是正常的！

**所有浏览器都会显示警告**:
- Chrome: `NET::ERR_CERT_AUTHORITY_INVALID`
- Edge: `DLG_FLAGS_INVALID_CA`
- Firefox: `MOZILLA_PKIX_ERROR_SELF_SIGNED_CERT`

**原因**: 使用自签名证书
**解决**: 点击"继续访问"或"接受风险"

### 证书配置是正确的！

查看证书详情应该看到:
```
Subject Alternative Name:
  DNS: *.qsgl.net ✅
  DNS: qsgl.net   ✅
```

如果看到这两个 DNS 条目，说明 SAN 配置完全正确！

---

## 🧪 HTTP/3 测试

### 验证 Alt-Svc 头
```powershell
# 服务器端验证
ssh ubuntu@62.234.212.241
curl -k -I -H 'Host: www.qsgl.net' https://localhost:443/ | grep alt-svc

# 应该看到: alt-svc: h3=":443"; ma=86400 ✅
```

### 浏览器中验证
```
1. 打开 https://www.qsgl.net
2. F12 → Network 标签
3. 右键表头 → 勾选 "Protocol"
4. 刷新页面
5. 第一次: h2 (HTTP/2)
6. 等待 30 秒，再次刷新
7. 应该看到: h3 (HTTP/3) ✅
```

---

## 📊 端口测试

| 端口 | URL | 预期结果 |
|------|-----|----------|
| 443 | https://www.qsgl.net:443/ | HTTP 200 ✅ |
| 99 | https://www.qsgl.net:99/ | HTTP 200 ✅ |
| 5002 | https://www.qsgl.net:5002/ | HTTP 302 ✅ |

---

## 🔧 服务器快速检查

```bash
# SSH 连接
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241

# 检查容器
sudo docker ps | grep envoy
# 状态应该是: Up X minutes ✅

# 检查证书 SAN
echo | openssl s_client -connect localhost:443 -servername www.qsgl.net 2>/dev/null | \
openssl x509 -text -noout | grep -A2 "Subject Alternative Name"
# 应该看到: DNS:*.qsgl.net, DNS:qsgl.net ✅

# 检查 HTTP/3 支持
curl -k -I -H 'Host: www.qsgl.net' https://localhost:443/ | grep alt-svc
# 应该看到: alt-svc: h3=":443"; ma=86400 ✅

# 检查管理 API
curl -s http://localhost:9901/ready
# 应该返回: LIVE ✅
```

---

## 🎯 测试清单

- [ ] 访问 https://www.qsgl.net (会看到证书警告 - 正常✅)
- [ ] 查看证书详情 (确认有 SAN: DNS:*.qsgl.net ✅)
- [ ] 点击"继续访问" (页面应该正常加载 ✅)
- [ ] F12 查看 Protocol (第一次 h2，再次刷新可能看到 h3 ✅)
- [ ] 测试端口 99: https://www.qsgl.net:99/
- [ ] 测试端口 5002: https://www.qsgl.net:5002/

---

## 📚 完整文档

详细说明请查看:
- **FINAL-CERTIFICATE-HTTP3-REPORT.md** - 完整配置报告
- **BROWSER-TEST-GUIDE.md** - 浏览器测试指南
- **CERTIFICATE-UPDATE-REPORT.md** - 证书更新历史

---

## 🚨 故障排除

### 证书还是报错？
1. 清除浏览器缓存 (Ctrl+Shift+Delete)
2. 重启浏览器
3. 使用隐私模式测试
4. 查看证书详情确认 SAN

### HTTP/3 不生效？
1. 确认看到 Alt-Svc 头
2. 等待 30 秒后再次访问
3. 检查 UDP 443 端口开放
4. 某些网络可能阻止 UDP

### 页面无法访问？
```bash
# 检查服务器
ping 62.234.212.241

# 检查端口
Test-Connection -TcpPort 443 62.234.212.241

# 检查 DNS
nslookup www.qsgl.net
```

---

**现在可以开始测试了！** 🚀

记住：**证书警告是正常的**，点击"继续访问"即可。
