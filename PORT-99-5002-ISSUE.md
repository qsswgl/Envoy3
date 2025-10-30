# 端口99和5002无法访问的问题分析与解决方案

## 🔍 问题诊断

### 测试结果
```
✅ https://www.qsgl.net:443/  → 200 OK (工作正常)
❌ https://www.qsgl.net:99/   → 404 Not Found
❌ https://www.qsgl.net:5002/ → 404 Not Found
```

### 后端服务器状态
```
✅ https://61.163.200.245:443/  → 200 OK (IIS, www.qsgl.net站点)
✅ https://61.163.200.245:99/   → 200 OK (Kestrel服务)
⚠️  https://61.163.200.245:5002/ → 405 Method Not Allowed (Kestrel, 只支持GET)
```

### Envoy配置
```yaml
端口99  → backend_cluster_443 (指向61.163.200.245:443)
端口5002 → backend_cluster_5002 (指向61.163.200.245:5002)
```

---

## 🎯 问题根源

### 问题1: 端口99配置错误

**当前配置**:
- Envoy监听: 0.0.0.0:99
- 路由到: backend_cluster_443 (61.163.200.245:443)
- Host重写: www.qsgl.net

**问题**:
- 后端61.163.200.245的**443端口**是IIS上的www.qsgl.net站点
- 但后端的**99端口**是独立的Kestrel服务
- Envoy把99端口的请求转发到了后端443端口，导致路由错误

**正确配置**: 应该创建backend_cluster_99，指向61.163.200.245:99

### 问题2: 端口5002的HEAD请求问题

**当前情况**:
- 后端5002端口的Kestrel服务只支持GET请求
- 当你用浏览器或curl -I (HEAD方法)测试时返回405
- 使用GET方法时可以正常访问

**SSE端点特性**:
- /sse/UsersID/1 是Server-Sent Events端点
- SSE需要保持长连接，不支持HEAD请求

---

## ✅ 解决方案

### 方案1: 修复端口99配置（推荐）

创建独立的backend_cluster_99集群，指向后端的99端口。

#### 修改步骤:

1. **添加backend_cluster_99集群**（在envoy.yaml末尾clusters部分添加）:

```yaml
  - name: backend_cluster_99
    connect_timeout: 30s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: backend_cluster_99
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: 61.163.200.245
                port_value: 99
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: www.qsgl.net
        common_tls_context:
          validation_context:
            trusted_ca:
              filename: "/etc/ssl/certs/ca-certificates.crt"
    health_checks:
    - timeout: 5s
      interval: 30s
      unhealthy_threshold: 3
      healthy_threshold: 2
      tcp_health_check: {}
```

2. **修改listener_https_99的路由配置**:

将:
```yaml
route:
  cluster: backend_cluster_443  # 错误
```

改为:
```yaml
route:
  cluster: backend_cluster_99   # 正确
```

3. **可选: 移除Host重写**（如果后端99端口不需要）:

如果后端99端口不需要特定的Host头，可以注释掉:
```yaml
# host_rewrite_literal: "www.qsgl.net"
```

### 方案2: 端口5002的SSE支持

SSE端点需要特殊配置以支持长连接和流式传输。

#### 修改listener_https_5002配置:

```yaml
route_config:
  name: local_route_5002
  virtual_hosts:
  - name: qsgl_backend_5002
    domains: ["*.qsgl.net", "qsgl.net"]
    routes:
    - match:
        prefix: "/sse/"  # SSE路径
      route:
        cluster: backend_cluster_5002
        timeout: 0s  # 禁用超时，支持长连接
        idle_timeout: 3600s  # 1小时空闲超时
        host_rewrite_literal: "www.qsgl.net"
    - match:
        prefix: "/"  # 其他路径
      route:
        cluster: backend_cluster_5002
        timeout: 300s
        host_rewrite_literal: "www.qsgl.net"
```

#### 添加streaming相关配置:

在http_connection_manager中添加:
```yaml
stream_idle_timeout: 3600s  # 流空闲超时
request_timeout: 0s  # 禁用请求超时（SSE需要）
```

---

## 🔧 快速修复脚本

我将为你生成修复后的配置文件。

---

## 📊 验证方法

### 修复后测试:

```bash
# 测试99端口
curl -I https://www.qsgl.net:99/
# 预期: HTTP/1.1 200 OK

# 测试5002端口（使用GET）
curl -k https://www.qsgl.net:5002/sse/UsersID/1
# 预期: SSE数据流

# 测试443端口（确保不受影响）
curl -I https://www.qsgl.net/
# 预期: HTTP/1.1 200 OK
```

---

## 🎓 技术说明

### 为什么99端口返回404？

```
用户请求: https://www.qsgl.net:99/
    ↓
Envoy接收: listener_https_99 (0.0.0.0:99)
    ↓
错误路由: backend_cluster_443 (61.163.200.245:443)
    ↓
后端IIS: 收到请求，但路径不匹配
    ↓
返回: 404 Not Found
```

**正确流程应该是**:
```
用户请求: https://www.qsgl.net:99/
    ↓
Envoy接收: listener_https_99 (0.0.0.0:99)
    ↓
正确路由: backend_cluster_99 (61.163.200.245:99)
    ↓
后端Kestrel: 正确处理请求
    ↓
返回: 200 OK
```

### 为什么5002端口特殊？

SSE (Server-Sent Events) 是HTML5标准，特点:
- 单向通信（服务器→客户端）
- 保持HTTP连接打开
- 持续推送数据
- Content-Type: text/event-stream

需要特殊的Envoy配置:
- timeout: 0s (禁用超时)
- 支持长连接
- 支持流式传输

---

## 📞 下一步

1. 我将修改envoy.yaml配置文件
2. 上传到服务器
3. 重启Envoy容器
4. 测试所有端口

准备好了吗？我现在开始修复配置。
