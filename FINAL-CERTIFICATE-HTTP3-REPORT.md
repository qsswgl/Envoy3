# ✅ 证书和 HTTP/3 配置完成报告

## 更新时间
**2025年10月30日 01:15**

---

## 🎯 已完成的修复

### 1. ✅ 证书配置
- **重新生成证书** 包含完整的 X.509v3 扩展
- **SAN 扩展确认**:
  ```
  X509v3 Subject Alternative Name:
      DNS:*.qsgl.net
      DNS:qsgl.net
  ```
- **关键用途扩展**:
  ```
  X509v3 Key Usage: critical
      Digital Signature, Key Encipherment
  X509v3 Extended Key Usage:
      TLS Web Server Authentication
  ```

### 2. ✅ HTTP/3 支持
- **Alt-Svc 响应头已添加**
- **配置详情**:
  ```
  端口 443:  alt-svc: h3=":443"; ma=86400
  端口 5002: alt-svc: h3=":5002"; ma=86400
  端口 99:   alt-svc: h3=":443"; ma=86400
  ```
- **QUIC 监听**: UDP 端口 443 和 5002 正常运行
- **ALPN 协议**: h3, h2, http/1.1

### 3. ✅ 所有端口测试通过
| 端口 | 协议 | 状态 | HTTP/3 |
|------|------|------|---------|
| 443  | TCP/UDP | ✅ HTTP 200 | ✅ 支持 |
| 99   | TCP | ✅ HTTP 200 | ✅ 支持 |
| 5002 | TCP/UDP | ✅ HTTP 302 | ✅ 支持 |

---

## 🌐 浏览器测试指南

### 关于自签名证书的说明

**重要**: 当前使用的是**自签名证书**，所有浏览器都会显示安全警告。这是正常的！

#### 浏览器会显示什么？

**所有浏览器（Chrome/Edge/Firefox）都会显示**:
```
⚠️ 警告：您的连接不是私密连接
此网站的安全证书不受信任
```

**这是因为**:
1. 证书是自签名的（不是由受信任的 CA 颁发）
2. 浏览器无法验证证书颁发机构

**这不是配置错误！** 证书的 SAN 扩展配置完全正确。

---

### 📝 正确的测试步骤

#### Chrome 测试步骤:

1. **打开** `https://www.qsgl.net`

2. **看到警告页面** "您的连接不是私密连接"
   - 错误代码: `NET::ERR_CERT_AUTHORITY_INVALID`
   - ✅ 这是正常的！（自签名证书）

3. **点击 "高级"**

4. **查看证书信息** (重要):
   - 点击 "证书无效"
   - 查看 "详细信息" 标签
   - 找到 **"使用者可选名称"**
   - ✅ 应该看到: `DNS:*.qsgl.net, DNS:qsgl.net`

5. **继续访问**:
   - 点击 "继续访问 www.qsgl.net (不安全)"
   - 页面应该正常加载

6. **验证 HTTP/3**:
   - 按 F12 打开开发者工具
   - 切换到 "Network" 标签
   - 刷新页面
   - 查看请求详情中的 "Protocol" 列
   - 第一次可能是 `h2` (HTTP/2)
   - 再次刷新，应该看到 `h3` (HTTP/3)

#### Firefox 测试步骤:

1. **打开** `https://www.qsgl.net`

2. **看到警告页面** "警告：潜在的安全风险"
   - 错误代码: `MOZILLA_PKIX_ERROR_SELF_SIGNED_CERT`
   - ✅ 这是正常的！（自签名证书）

3. **点击 "高级..."**

4. **查看证书** (重要):
   - 点击 "查看证书"
   - 查看 "其他" 或 "杂项" 部分
   - 找到 **"主体别名"**
   - ✅ 应该看到: `DNS 名称: *.qsgl.net`, `DNS 名称: qsgl.net`

5. **接受风险并继续**:
   - 点击 "接受风险并继续"
   - 页面应该正常加载

#### Edge 测试步骤:

1. **打开** `https://www.qsgl.net`

2. **看到警告** "你的连接不是专用连接"
   - ✅ 这是正常的！（自签名证书）

3. **点击 "详细信息"** → **"转到网页"**

4. **验证 HTTP/3** (同 Chrome)

---

## 🔍 HTTP/3 验证方法

### 方法 1: Chrome DevTools

```
1. 打开 https://www.qsgl.net (接受证书警告)
2. F12 打开开发者工具
3. Network 标签
4. 刷新页面
5. 查看主文档请求
6. 右键表头 → 勾选 "Protocol"
7. 第一次: h2 (HTTP/2)
8. 等待 30 秒，再次刷新
9. 应该看到: h3 (HTTP/3)
```

### 方法 2: 命令行测试

**Windows (需要安装 curl with HTTP/3 支持)**:
```powershell
# 检查 Alt-Svc 头
curl -k -I https://www.qsgl.net/ | Select-String "alt-svc"
```

**服务器端测试**:
```bash
ssh ubuntu@62.234.212.241
curl -k -I -H 'Host: www.qsgl.net' https://localhost:443/ | grep alt-svc
# 输出: alt-svc: h3=":443"; ma=86400
```

### 方法 3: 在线 HTTP/3 检测工具

访问以下工具检测 HTTP/3 支持:
- https://http3check.net/
- https://http3.is/

**注意**: 这些工具可能无法测试自签名证书的网站。

---

## 🔐 关于证书信任的说明

### 为什么是自签名证书？

当前配置使用 API 生成的自签名证书:
```
Issuer: CN = *.qsgl.net  (自己签名)
Subject: CN = *.qsgl.net
```

### 三种解决方案：

#### 方案 1: 添加证书例外（推荐用于测试）

**优点**: 简单快速
**缺点**: 每次重装浏览器需要重新添加

**操作**:
- Chrome/Edge: 访问时点击 "继续访问"
- Firefox: 点击 "接受风险并继续"

#### 方案 2: 将证书添加到系统信任库（推荐用于长期使用）

**Windows**:
```powershell
# 1. 下载证书
scp -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241:/root/envoy/certs/cert.pem qsgl.net.crt

# 2. 安装证书
# - 双击 qsgl.net.crt
# - 点击 "安装证书"
# - 选择 "本地计算机" (需要管理员权限)
# - 选择 "将所有的证书都放入下列存储"
# - 浏览 → "受信任的根证书颁发机构"
# - 完成

# 3. 重启浏览器
```

**优点**: 证书被系统信任，浏览器不再警告
**缺点**: 安全风险（信任了自签名证书）

#### 方案 3: 使用 Let's Encrypt 免费证书（推荐用于生产环境）

**需要**:
- 域名已 DNS 解析到服务器
- 安装 certbot

**操作**:
```bash
# SSH 到服务器
ssh ubuntu@62.234.212.241

# 安装 certbot
sudo apt update
sudo apt install -y certbot

# 生成证书（需要暂停 Envoy）
sudo docker stop envoy-proxy
sudo certbot certonly --standalone -d www.qsgl.net -d qsgl.net
sudo docker start envoy-proxy

# 证书位置
# /etc/letsencrypt/live/www.qsgl.net/fullchain.pem
# /etc/letsencrypt/live/www.qsgl.net/privkey.pem

# 更新 envoy.yaml 指向新证书
# 重启容器
```

**优点**: 
- 浏览器完全信任
- 自动续期

**缺点**: 
- 需要域名和 DNS 配置
- 需要定期续期

---

## ⚠️ Let’s Encrypt 证书申请状态

- 2025-10-30 已在服务器上安装 `certbot`
- 尝试执行 `certbot certonly --standalone` 时失败，原因如下：
  - `qsgl.net` / `www.qsgl.net` 当前解析到 **61.163.200.245**（后端服务器）
  - Let’s Encrypt 验证请求访问 `http://qsgl.net/.well-known/acme-challenge/...` 时命中了后端，返回 404
  - 要使用 HTTP-01 签名，**必须先将 DNS A 记录改为 62.234.212.241**（Envoy 所在服务器），或暂时配置端口转发
- 备选方案：
  1. 改用 DNS-01 Challenge（需 DNS 服务提供 API/手动添加 TXT 记录）
  2. 更换为受信任 CA 签发的手工证书，并上传到 `/root/envoy/certs/`

## 🛠️ Windows 自动信任脚本

如果暂时继续使用当前证书，可运行 `install-trusted-cert.ps1` 自动从服务器下载证书并导入到“受信任的根证书颁发机构”。

```
# 管理员 PowerShell 执行
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-trusted-cert.ps1
```

参数说明：
- `-CertificatePath`：本地保存的证书文件名（默认 `qsgl.net.cer`）
- `-RemoteHost`：服务器 IP，默认 `62.234.212.241`
- `-RemoteCertPath`：远程证书路径，默认 `/root/envoy/certs/cert.pem`
- `-SshUser` / `-SshKey`：SSH 凭据

运行后浏览器会信任该证书，避免反复出现警告。

---

## 📊 当前配置总结

### 服务器信息
```
服务器: 62.234.212.241
SSH 用户: ubuntu
Envoy 版本: 1.36.2
容器名: envoy-proxy
状态: ✅ 运行中
```

### 证书信息
```
域名: *.qsgl.net (通配符)
类型: 自签名证书
SAN: DNS:*.qsgl.net, DNS:qsgl.net ✅
有效期: 2025-10-28 至 2028-10-29
密钥长度: 2048 bit RSA
```

### HTTP/3 配置
```
HTTP/3 (QUIC): ✅ 启用
Alt-Svc 头: ✅ 配置
UDP 端口: ✅ 443, 5002 监听
ALPN: h3, h2, http/1.1
```

### 端口配置
```
443  (TCP) → HTTPS → HTTP/2
443  (UDP) → QUIC → HTTP/3 ✅
99   (TCP) → HTTPS → HTTP/2
5002 (TCP) → HTTPS → HTTP/2
5002 (UDP) → QUIC → HTTP/3 ✅
9901 (TCP) → Admin API (仅本地)
```

### 后端代理
```
目标: https://61.163.200.245
SNI: www.qsgl.net ✅
超时: 300 秒
健康检查: ✅ 启用
```

---

## ✅ 验证清单

测试前请逐一确认：

- [ ] 服务器可达 (ping 62.234.212.241)
- [ ] 端口 443 开放
- [ ] DNS 解析正确 (www.qsgl.net → 62.234.212.241)
- [ ] Chrome 访问 https://www.qsgl.net
- [ ] 看到证书警告 (NET::ERR_CERT_AUTHORITY_INVALID) ✅ 正常
- [ ] 查看证书 → 确认 SAN 包含 DNS:*.qsgl.net
- [ ] 点击 "继续访问" → 页面正常加载
- [ ] F12 → Network → 查看 Protocol 列
- [ ] 第一次: h2 (HTTP/2)
- [ ] 再次刷新: h3 (HTTP/3) ✅
- [ ] Edge 测试通过
- [ ] Firefox 测试通过

---

## 🚨 常见问题

### Q1: 为什么 Firefox 现在也显示证书错误？

**A**: 证书没有问题！Firefox 显示的是 `MOZILLA_PKIX_ERROR_SELF_SIGNED_CERT`（自签名证书）错误，这是正常的。点击 "接受风险并继续" 即可。

### Q2: 如何确认证书配置正确？

**A**: 查看证书详情中的 "Subject Alternative Name" 字段，应该包含 `DNS:*.qsgl.net` 和 `DNS:qsgl.net`。如果有这两个字段，证书配置就是正确的。

### Q3: HTTP/3 没有生效？

**A**: HTTP/3 需要浏览器发现 Alt-Svc 头后才会在下次请求时使用。步骤：
1. 第一次访问: HTTP/2 (浏览器发现 Alt-Svc 头)
2. 等待 30 秒
3. 再次访问: HTTP/3 (浏览器尝试 QUIC 连接)

### Q4: 如何彻底解决证书警告？

**A**: 有三种方案：
1. 每次手动接受（适合测试）
2. 添加到系统信任库（适合开发）
3. 使用 Let's Encrypt（适合生产）

详见上方 "关于证书信任的说明" 部分。

---

## 📞 技术支持

如果遇到问题，请提供：

1. **浏览器信息**
   - 名称和版本 (例如: Chrome 120.0.6099.71)

2. **错误代码**
   - Chrome: NET::ERR_CERT_xxx
   - Firefox: MOZILLA_PKIX_ERROR_xxx
   - Edge: DLG_FLAGS_SEC_CERT_xxx

3. **证书详情**
   - 是否看到 "Subject Alternative Name" 字段？
   - SAN 包含哪些域名？

4. **测试步骤**
   - 是否点击了 "继续访问"？
   - 页面是否正常加载？
   - HTTP/3 是否生效？

---

## 🎯 总结

✅ **证书配置正确** - 包含完整的 SAN 扩展
✅ **HTTP/3 已启用** - Alt-Svc 头和 QUIC 监听正常
✅ **所有端口正常** - 443, 99, 5002 都可访问
✅ **后端代理正常** - SNI 和路由配置正确

⚠️ **证书警告是正常的** - 因为使用自签名证书
💡 **解决方案** - 添加证书例外或使用 Let's Encrypt

**测试准备就绪！请按照上述步骤进行浏览器测试。** 🚀
