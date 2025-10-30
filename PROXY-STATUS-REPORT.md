# Envoy 代理详细信息报告

**生成时间**: 2025年10月30日  
**服务器**: 62.234.212.241  
**域名**: *.qsgl.net, qsgl.net

---

## 1. 版本信息

- **Envoy版本**: v1.36.2 (contrib)
- **构建版本**: dc2d3098ae5641555f15c71d5bb5ce0060a8015c
- **SSL库**: BoringSSL
- **镜像**: envoyproxy/envoy:contrib-v1.36.2
- **构建类型**: RELEASE/Clean

---

## 2. 监听端口配置

### TCP监听端口
| 端口 | 协议 | 用途 | 状态 |
|------|------|------|------|
| 443 | HTTPS (HTTP/2, HTTP/1.1) | 主要Web流量 | ✅ 活跃 |
| 5002 | HTTPS (HTTP/2, HTTP/1.1) | 备用端口 | ✅ 活跃 |
| 99 | HTTPS (HTTP/2, HTTP/1.1) | 备用端口 | ✅ 活跃 |
| 9901 | HTTP | 管理接口 | ✅ 活跃 |

### UDP监听端口 (HTTP/3)
| 端口 | 协议 | 用途 | 状态 |
|------|------|------|------|
| 443 | QUIC/HTTP3 | HTTP/3主要流量 | ⚠️ 已配置，未使用 |
| 5002 | QUIC/HTTP3 | HTTP/3备用端口 | ⚠️ 已配置，未使用 |

---

## 3. HTTP协议使用统计

### 443端口统计 (listener_https_443)
```
HTTP/1.1 连接总数: 4
HTTP/2   连接总数: 2
HTTP/3   连接总数: 0
已完成请求总数:    33
  - 2xx 响应: 32
  - 4xx 响应: 1
```

### 5002端口统计 (listener_https_5002)
```
HTTP/1.1 连接总数: 1
HTTP/2   连接总数: 0
HTTP/3   连接总数: 0
已完成请求总数:    1
  - 4xx 响应: 1 (后端5002端口未配置)
```

### 99端口统计 (listener_https_99)
```
连接总数: 0
请求总数: 0
```

### QUIC监听器统计
```
listener_quic_443:
  HTTP/3 连接总数: 0
  已完成请求总数:  0

listener_quic_5002:
  HTTP/3 连接总数: 0
  已完成请求总数:  0
```

---

## 4. HTTP/3 工作状态分析

### ✅ HTTP/3 已正确配置
1. **UDP端口443已监听**: Envoy在UDP 443端口上监听QUIC连接
2. **UDP端口5002已监听**: Envoy在UDP 5002端口上监听QUIC连接
3. **QUIC模块已加载**: 使用envoy.quic.crypto_stream.server.quiche
4. **配置文件正确**: http3_protocol_options配置在所有QUIC监听器中

### ⚠️ HTTP/3 实际未被使用的原因

#### 1. **客户端不支持HTTP/3**
- 当前测试使用的curl客户端不支持HTTP/3
- 标准浏览器(Chrome, Firefox, Edge)默认支持HTTP/3
- 需要使用支持HTTP/3的客户端才能建立QUIC连接

#### 2. **Alt-Svc响应头缺失**
HTTP/3需要通过Alt-Svc响应头告知客户端:
```http
Alt-Svc: h3=":443"; ma=86400
```
当前配置未添加此响应头，导致客户端不知道服务器支持HTTP/3。

#### 3. **防火墙/网络问题**
- 需要确保云服务器安全组允许UDP 443入站
- 某些网络环境可能阻止UDP流量
- ISP可能限制QUIC协议

---

## 5. 启用HTTP/3的建议

### 方法1: 添加Alt-Svc响应头 (推荐)

在envoy.yaml的route配置中添加:

```yaml
routes:
  - match:
      prefix: "/"
    route:
      cluster: backend_cluster_443
      host_rewrite_literal: "www.qsgl.net"
    response_headers_to_add:
      - header:
          key: "alt-svc"
          value: 'h3=":443"; ma=86400'
        append: false
```

### 方法2: 检查云服务器安全组

确保腾讯云安全组规则包含:
```
协议: UDP
端口: 443
来源: 0.0.0.0/0
动作: 允许
```

### 方法3: 使用支持HTTP/3的客户端测试

**Chrome浏览器测试**:
1. 打开 chrome://flags/#enable-quic
2. 启用QUIC协议
3. 访问 https://www.qsgl.net/
4. 按F12打开开发者工具 → 网络标签
5. 查看协议列，应显示"h3"

**Firefox浏览器测试**:
1. 打开 about:config
2. 搜索 network.http.http3.enabled
3. 设置为true
4. 访问 https://www.qsgl.net/
5. 查看网络工具，协议应显示HTTP/3

---

## 6. 当前配置特点

### ✅ 已实现的功能
1. **多协议支持**: HTTP/1.1, HTTP/2, gRPC-Web
2. **泛域名支持**: *.qsgl.net, qsgl.net
3. **Host重写**: 所有子域名请求转发到后端时改写为 www.qsgl.net
4. **TLS/SSL**: Let's Encrypt通配符证书 (ECC P-256)
5. **后端负载均衡**: 支持多个后端服务器
6. **健康检查**: 后端服务健康检查
7. **HTTP/3基础配置**: UDP监听器已配置QUIC

### 🔧 需要优化的地方
1. **HTTP/3激活**: 添加Alt-Svc响应头
2. **安全组配置**: 确认UDP 443入站规则
3. **监控**: 添加QUIC/HTTP3特定指标监控

---

## 7. 实际使用情况

### 当前流量分布
- **HTTP/1.1**: 67% (4/6 连接)
- **HTTP/2**: 33% (2/6 连接)
- **HTTP/3**: 0% (0 连接)

### 成功率
- **443端口**: 97% 成功 (32/33 请求返回2xx)
- **5002端口**: 0% 成功 (后端未配置5002服务)

---

## 8. 后端连接配置

### 后端服务器
- **地址**: https://61.163.200.245:443
- **协议**: HTTPS (HTTP/2, HTTP/1.1)
- **SNI**: www.qsgl.net
- **Host重写**: 所有请求Host头改为 www.qsgl.net
- **TLS验证**: 已禁用证书验证 (trusted_ca未配置)

### 上游连接统计
```
backend_cluster_443:
  HTTP/3连接: 0
  协议错误:   0
  
backend_cluster_5002:
  HTTP/3连接: 0
  协议错误:   0
```

---

## 9. 域名和证书配置

### 支持的域名
- www.qsgl.net
- a.qsgl.net
- test.qsgl.net
- *.qsgl.net (所有子域名)
- qsgl.net (根域名)

### 证书信息
- **类型**: Let's Encrypt 通配符证书
- **域名**: *.qsgl.net
- **密钥类型**: ECC P-256
- **有效期至**: 2026-01-18
- **证书链**: 包含Let's Encrypt E7中间证书

---

## 10. 总结

### ✅ 当前状态: 生产就绪
- Envoy代理正常运行
- HTTP/1.1 和 HTTP/2 工作正常
- 所有域名正常解析和访问
- SSL证书有效
- Host重写功能正常

### ⚠️ HTTP/3状态: 已配置但未激活
- UDP端口正确监听
- QUIC模块正确加载
- 配置文件正确
- **缺少Alt-Svc响应头导致客户端不使用HTTP/3**

### 🎯 建议操作
1. 添加Alt-Svc响应头以启用HTTP/3自动协商
2. 验证云服务器安全组UDP 443入站规则
3. 使用Chrome/Firefox浏览器验证HTTP/3功能
4. 添加HTTP/3相关监控指标

---

## 附录: 验证命令

### 检查监听端口
```bash
# TCP端口
sudo netstat -tlnp | grep envoy

# UDP端口 (HTTP/3)
sudo netstat -ulnp | grep envoy
```

### 检查统计信息
```bash
# HTTP协议统计
curl -s http://localhost:9901/stats | grep downstream_cx_http

# 请求统计
curl -s http://localhost:9901/stats | grep downstream_rq_completed
```

### 测试访问
```bash
# HTTP/1.1
curl -I https://www.qsgl.net/

# HTTP/2
curl -I --http2 https://www.qsgl.net/

# HTTP/3 (需要支持的curl版本)
curl -I --http3 https://www.qsgl.net/
```
