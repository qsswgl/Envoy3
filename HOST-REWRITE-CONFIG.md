# Host重写配置说明 (Host Rewrite)

## ✅ 配置完成

**问题**: 访问 `a.qsgl.net`, `test.qsgl.net` 等子域名时，后端返回404  
**原因**: 后端服务器只配置了 `www.qsgl.net` 站点，不识别其他子域名  
**解决**: 在Envoy中添加 `host_rewrite_literal: "www.qsgl.net"`，将所有请求的Host头改写为 `www.qsgl.net`

## 工作原理

### 请求流程

#### 修改前 ❌
```
客户端访问: https://a.qsgl.net
    ↓
Envoy代理: Host: a.qsgl.net (保持原样)
    ↓
后端服务器: 收到 Host: a.qsgl.net → 404 Not Found (没有配置这个站点)
```

#### 修改后 ✅
```
客户端访问: https://a.qsgl.net
    ↓
Envoy代理: Host: a.qsgl.net → 改写为 → Host: www.qsgl.net
    ↓
后端服务器: 收到 Host: www.qsgl.net → 200 OK (返回www.qsgl.net的内容)
```

## 配置详情

### 添加的配置
在每个路由的 `route` 部分添加了 `host_rewrite_literal`:

```yaml
routes:
  - match:
      prefix: "/"
    route:
      cluster: backend_cluster_443
      timeout: 300s
      host_rewrite_literal: "www.qsgl.net"  # ← 新增：重写Host头
```

### 更新的监听器
所有5个监听器都已添加Host重写：

1. ✅ `listener_https_443` (TCP 443) → `host_rewrite_literal: "www.qsgl.net"`
2. ✅ `listener_https_5002` (TCP 5002) → `host_rewrite_literal: "www.qsgl.net"`
3. ✅ `listener_https_99` (TCP 99) → `host_rewrite_literal: "www.qsgl.net"`
4. ✅ `listener_quic_443` (UDP 443, HTTP/3) → `host_rewrite_literal: "www.qsgl.net"`
5. ✅ `listener_quic_5002` (UDP 5002, HTTP/3) → `host_rewrite_literal: "www.qsgl.net"`

## 测试结果

### a.qsgl.net 测试 (修改前后对比)

#### 修改前 ❌
```bash
$ curl -I https://a.qsgl.net/
HTTP/1.1 404 Not Found
content-length: 315
server: envoy
```

#### 修改后 ✅
```bash
$ curl -I https://a.qsgl.net/
HTTP/1.1 200 OK
cache-control: no-cache
content-length: 29478    # ← 与www.qsgl.net相同
content-type: text/html
server: envoy
x-powered-by: ASP.NET
alt-svc: h3=":443"; ma=86400
```

### 验证所有子域名

```bash
# 所有子域名现在都返回www.qsgl.net的内容
curl -I https://a.qsgl.net/        # ✅ 200 OK
curl -I https://api.qsgl.net/      # ✅ 200 OK (需要DNS指向62.234.212.241)
curl -I https://test.qsgl.net/     # ✅ 200 OK (需要DNS指向62.234.212.241)
curl -I https://任意子域名.qsgl.net/  # ✅ 200 OK (需要DNS配置)
```

## 优势

### 1. 简化后端配置
- ✅ 后端只需配置一个站点 `www.qsgl.net`
- ✅ 无需为每个子域名单独配置IIS绑定
- ✅ 减少后端服务器的维护工作

### 2. 统一证书管理
- ✅ 前端使用泛域名证书 `*.qsgl.net`
- ✅ 后端只需配置 `www.qsgl.net` 证书
- ✅ 简化证书更新流程

### 3. 灵活的域名管理
- ✅ 可以随时添加新子域名（只需配置DNS）
- ✅ 无需修改后端服务器配置
- ✅ 所有子域名自动共享相同内容

### 4. 透明代理
- ✅ 客户端仍然看到自己访问的域名（浏览器地址栏）
- ✅ 证书域名匹配正确（泛域名覆盖）
- ✅ 后端收到统一的Host头

## 配置验证

### 验证Envoy配置
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241

# 查看Host重写配置
grep -B5 "host_rewrite_literal" /opt/envoy/config/envoy.yaml

# 应该看到5处配置：
# host_rewrite_literal: "www.qsgl.net"
```

### 验证实际效果
```bash
# 本地测试（绕过DNS）
curl -I -k -H "Host: a.qsgl.net" https://62.234.212.241/
# 应该返回 200 OK

# 公网测试
curl -I https://a.qsgl.net/
# 应该返回 200 OK
```

### 验证Host头重写
在后端服务器上查看IIS日志，应该看到所有请求的Host都是 `www.qsgl.net`：

```
# IIS日志路径示例
C:\inetpub\logs\LogFiles\W3SVC1\

# 日志示例（所有请求的cs-host都应该是www.qsgl.net）
2025-10-30 00:35:53 GET / - 200 www.qsgl.net
2025-10-30 00:35:54 GET / - 200 www.qsgl.net
```

## 与其他配置的兼容性

### 1. SNI (Server Name Indication)
后端连接的SNI仍然配置为 `www.qsgl.net`：

```yaml
clusters:
  - name: backend_cluster_443
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.qsgl.net  # ← SNI固定为www.qsgl.net
```

这确保了：
- ✅ Envoy与后端的TLS握手使用正确的SNI
- ✅ 后端证书验证通过
- ✅ TLS连接建立成功

### 2. CORS配置
如果后端配置了CORS，Host重写不会影响：
- 原始请求的Origin头保持不变
- 后端看到的Host头是 `www.qsgl.net`
- CORS验证正常工作

### 3. 日志记录
Envoy日志会记录原始Host和重写后的Host：
```
[2025-10-30 00:35:53.123] "GET / HTTP/2" 200
  authority: a.qsgl.net              ← 客户端请求的域名
  x-envoy-original-host: a.qsgl.net  ← 原始Host头（可能）
```

## 特殊场景处理

### 场景1: 需要区分子域名
如果后端应用需要知道客户端访问的实际子域名：

**方案1**: 添加自定义请求头
```yaml
request_headers_to_add:
  - header:
      key: "X-Original-Host"
      value: "%REQ(:AUTHORITY)%"
    append: false
```

后端应用可以读取 `X-Original-Host` 头获取原始域名。

**方案2**: 使用路径前缀
根据子域名路由到不同路径：
```yaml
# a.qsgl.net → /site-a/
# b.qsgl.net → /site-b/
```

### 场景2: 某些子域名需要特殊处理
可以添加多个虚拟主机配置：

```yaml
virtual_hosts:
  # 特殊域名：不重写Host
  - name: api_backend
    domains: ["api.qsgl.net"]
    routes:
      - match:
          prefix: "/"
        route:
          cluster: api_cluster
          # 不添加 host_rewrite_literal

  # 通用域名：重写为www.qsgl.net
  - name: qsgl_backend
    domains: ["*.qsgl.net", "qsgl.net"]
    routes:
      - match:
          prefix: "/"
        route:
          cluster: backend_cluster_443
          host_rewrite_literal: "www.qsgl.net"
```

### 场景3: 基于子域名的内容分发
如果需要根据子域名返回不同内容，但仍想使用统一的后端站点：

**后端应用处理** (推荐):
```csharp
// ASP.NET示例
string originalHost = Request.Headers["X-Original-Host"];
if (originalHost == "a.qsgl.net") {
    // 返回A站点内容
} else if (originalHost == "b.qsgl.net") {
    // 返回B站点内容
}
```

## 监控和诊断

### 检查Host重写是否生效
```bash
# 在Envoy服务器上抓包
sudo tcpdump -i any -A 'host 61.163.200.245 and port 443' | grep -i "host:"

# 应该看到所有请求的Host都是 www.qsgl.net
```

### Envoy Admin API
```bash
# 查看集群统计
curl http://localhost:9901/stats | grep backend_cluster_443

# 查看路由配置
curl http://localhost:9901/config_dump | jq '.configs[2]'
```

### 问题诊断

#### 问题: 仍然返回404
**检查点**:
1. Envoy配置是否包含 `host_rewrite_literal`
2. 后端 `www.qsgl.net` 站点是否正常
3. 后端证书是否匹配SNI

**验证**:
```bash
# 直接测试后端
curl -I -k -H "Host: www.qsgl.net" https://61.163.200.245/
# 应该返回 200
```

#### 问题: 证书错误
**原因**: 后端SNI与证书不匹配

**解决**: 确保cluster配置中的SNI正确：
```yaml
sni: www.qsgl.net  # 必须与后端证书域名匹配
```

## 最佳实践

### 1. 添加X-Original-Host头
建议添加自定义头传递原始域名：

```yaml
routes:
  - match:
      prefix: "/"
    route:
      cluster: backend_cluster_443
      timeout: 300s
      host_rewrite_literal: "www.qsgl.net"
    request_headers_to_add:
      - header:
          key: "X-Original-Host"
          value: "%REQ(:AUTHORITY)%"
        append: false
```

### 2. 记录访问日志
在Envoy中启用访问日志：

```yaml
access_log:
  - name: envoy.access_loggers.file
    typed_config:
      "@type": type.googleapis.com/envoy.extensions.access_loggers.file.v3.FileAccessLog
      path: /var/log/envoy/access.log
      format: "[%START_TIME%] %REQ(:AUTHORITY)% → %REQ(HOST)% %RESPONSE_CODE%\n"
```

### 3. 监控重写效果
在监控脚本中验证Host重写：

```python
# monitor.py
def check_host_rewrite():
    """验证Host重写是否正常工作"""
    # 访问子域名应该返回200
    response = requests.get("https://a.qsgl.net/", verify=False)
    assert response.status_code == 200
    assert "server" in response.headers
    assert response.headers["server"] == "envoy"
```

## 总结

### ✅ 已实现功能
- 所有 `*.qsgl.net` 子域名访问时，Host头自动重写为 `www.qsgl.net`
- 后端只需配置一个站点即可服务所有子域名
- 保持客户端证书验证正常（泛域名证书）
- 保持后端TLS连接正常（SNI: www.qsgl.net）

### 📊 配置对比

| 项目 | 修改前 | 修改后 |
|------|--------|--------|
| **前端域名** | *.qsgl.net | *.qsgl.net |
| **前端证书** | *.qsgl.net泛域名 | *.qsgl.net泛域名 |
| **发送到后端的Host** | 保持原样(a.qsgl.net) | 重写为www.qsgl.net |
| **后端站点配置** | 需要每个子域名 | 只需www.qsgl.net |
| **后端响应** | 404 Not Found | 200 OK |

### 🎯 使用场景
此配置适合以下场景：
- ✅ 多个子域名共享相同内容
- ✅ 简化后端站点管理
- ✅ 动态添加子域名而不修改后端
- ✅ 统一的证书和站点配置

不适合的场景：
- ❌ 每个子域名需要不同内容和独立站点
- ❌ 后端需要识别实际访问的子域名进行路由
- ❌ 子域名需要不同的后端服务器

### 📝 下次更新证书时
Let's Encrypt证书续订时，只需确保：
1. 前端：使用泛域名证书 `*.qsgl.net`
2. 后端：配置 `www.qsgl.net` 证书（或泛域名）
3. SNI配置：保持 `sni: www.qsgl.net`
