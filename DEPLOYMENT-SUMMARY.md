# Envoy代理部署总结

## 服务器信息
- **IP地址**: 62.234.212.241
- **操作系统**: Ubuntu
- **SSH登录**: `ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241`

## 部署架构
```
客户端 
  ↓ (HTTPS/HTTP3)
www.qsgl.net (62.234.212.241)
  ↓ Envoy Proxy
后端服务器 (61.163.200.245:443, :5002)
```

## Envoy配置

### 容器信息
- **镜像**: envoyproxy/envoy:contrib-v1.36.2
- **网络模式**: host
- **重启策略**: unless-stopped
- **配置文件**: /opt/envoy/config/envoy.yaml

### 监听端口
| 端口 | 协议 | 用途 |
|------|------|------|
| 443 | TCP | HTTPS (HTTP/2, TLS) |
| 443 | UDP | HTTP/3 (QUIC) |
| 5002 | TCP | HTTPS备用端口 |
| 9901 | TCP | Admin管理接口 |

### 域名配置
- **主域名**: www.qsgl.net
- **后端服务器**: https://61.163.200.245:443 和 :5002
- **SNI**: www.qsgl.net (连接后端时使用)

## SSL证书

### 证书信息
- **类型**: Let's Encrypt (DV证书)
- **颁发者**: Let's Encrypt Authority (E7)
- **域名**: *.qsgl.net (泛域名证书，覆盖www.qsgl.net)
- **有效期**: 2025-10-20 至 2026-01-18
- **密钥类型**: ECDSA P-256 (ECC)
- **证书链**: 包含中间证书

### 证书文件位置
- **证书**: /opt/shared-certs/qsgl.net.fullchain.crt (2286字节)
- **私钥**: /opt/shared-certs/qsgl.net.key (365字节)
- **权限**: 644 (允许Envoy非root用户读取)

### 证书来源
从tx.qsgl.net证书管理系统获取的Let's Encrypt泛域名证书

## 协议支持
- ✅ **HTTP/3 (QUIC)**: 在UDP 443端口
- ✅ **HTTP/2**: TLS ALPN协商
- ✅ **HTTP/1.1**: 向后兼容
- ✅ **gRPC-WEB**: 启用过滤器
- ✅ **Alt-Svc头**: 通知客户端HTTP/3支持

## 监控服务

### 监控脚本
- **路径**: /root/envoy/monitor.py
- **检测频率**: 每5分钟
- **systemd服务**: envoy-monitor.service

### 监控项目
1. ✅ Docker容器状态
2. ✅ Envoy Admin API (localhost:9901)
3. ✅ 端口监听状态 (443, 5002, 9901)
4. ✅ 后端连接测试 (443, 5002)
5. ✅ 公网域名访问测试 (https://www.qsgl.net)

### 告警配置
- **邮件地址**: qsoft@139.com
- **SMTP服务器**: smtp.139.com:465 (SSL)
- **告警条件**: 任何检测项失败

## 系统配置

### 内核参数
```bash
# 允许非root用户绑定低端口
net.ipv4.ip_unprivileged_port_start=80
```

### Docker Compose
位置: /opt/envoy/docker-compose.yml
```yaml
version: '3.8'
services:
  envoy-proxy:
    image: envoyproxy/envoy:contrib-v1.36.2
    container_name: envoy-proxy
    network_mode: host
    privileged: true
    restart: unless-stopped
    volumes:
      - /opt/envoy/config/envoy.yaml:/etc/envoy/envoy.yaml:ro
      - /opt/shared-certs:/opt/certs:ro
```

## 常用命令

### 容器管理
```bash
# 查看容器状态
sudo docker ps | grep envoy

# 查看日志
sudo docker logs envoy-proxy -f

# 重启容器
cd /opt/envoy && sudo docker compose restart

# 停止容器
cd /opt/envoy && sudo docker compose down

# 启动容器
cd /opt/envoy && sudo docker compose up -d
```

### 配置验证
```bash
# 测试配置文件
sudo docker run --rm -v /opt/envoy/config/envoy.yaml:/etc/envoy/envoy.yaml envoyproxy/envoy:contrib-v1.36.2 --mode validate --config-path /etc/envoy/envoy.yaml

# 查看Admin API统计
curl http://localhost:9901/stats

# 查看证书信息
curl -s http://localhost:9901/certs | jq

# 查看监听器状态
curl http://localhost:9901/listeners
```

### 证书测试
```bash
# 本地测试证书
openssl s_client -connect localhost:443 -servername www.qsgl.net < /dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates

# 公网测试
curl -I https://www.qsgl.net/
```

### 监控服务
```bash
# 查看监控服务状态
sudo systemctl status envoy-monitor

# 手动运行监控脚本
python3 /root/envoy/monitor.py

# 查看监控日志
sudo journalctl -u envoy-monitor -f
```

## 故障排查

### 常见问题

#### 1. 证书加载失败
**症状**: 容器不断重启，日志显示 "Failed to load certificate"
**解决**:
```bash
# 检查证书格式（必须是PEM格式）
head -1 /opt/shared-certs/qsgl.net.fullchain.crt
# 应该显示: -----BEGIN CERTIFICATE-----

# 检查证书权限
ls -l /opt/shared-certs/
# 应该是 644

# 验证证书和密钥匹配
openssl x509 -noout -pubkey -in /opt/shared-certs/qsgl.net.fullchain.crt > /tmp/cert.pub
openssl ec -pubout -in /opt/shared-certs/qsgl.net.key > /tmp/key.pub 2>/dev/null
diff /tmp/cert.pub /tmp/key.pub
```

#### 2. 端口绑定失败
**症状**: 日志显示 "Permission denied" 或 "Address already in use"
**解决**:
```bash
# 检查端口占用
sudo netstat -tlnp | grep ':443'

# 检查内核参数
sysctl net.ipv4.ip_unprivileged_port_start

# 重新设置（如果需要）
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

#### 3. 后端连接失败
**症状**: 返回502 Bad Gateway
**解决**:
```bash
# 测试后端连接
curl -k https://61.163.200.245:443/ -H "Host: www.qsgl.net"

# 检查Envoy日志
sudo docker logs envoy-proxy | grep -i "upstream\|backend"

# 检查DNS解析
nslookup 61.163.200.245
```

#### 4. HTTP/3不工作
**症状**: 客户端无法使用HTTP/3
**解决**:
```bash
# 检查UDP端口
sudo netstat -ulnp | grep ':443'

# 测试QUIC连接
curl --http3 https://www.qsgl.net/ -I

# 检查防火墙
sudo ufw status
```

## 性能优化

### 当前配置
- **连接超时**: 30秒
- **请求超时**: 300秒
- **健康检查间隔**: 30秒
- **QUIC GRO**: 启用

### 可选优化
```yaml
# 在envoy.yaml中添加连接池配置
http2_protocol_options:
  max_concurrent_streams: 100
  initial_stream_window_size: 65536
  initial_connection_window_size: 1048576
```

## 安全建议

1. ✅ **定期更新证书**: Let's Encrypt证书有效期90天，建议60天时续订
2. ✅ **监控告警**: 已配置邮件告警
3. ⚠️ **限制Admin接口**: 当前绑定0.0.0.0:9901，建议改为127.0.0.1:9901
4. ⚠️ **启用访问日志**: 便于审计和故障排查
5. ⚠️ **配置速率限制**: 防止DDoS攻击

## 备份文件位置
- 配置备份: /opt/envoy/config/envoy.yaml.bak_wildcard
- 证书备份: /opt/shared-certs/*.bak

## 相关文档
- [Envoy官方文档](https://www.envoyproxy.io/docs/envoy/latest/)
- [HTTP/3配置指南](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/http3)
- [Let's Encrypt文档](https://letsencrypt.org/docs/)

## 更新日志

### 2025-10-30
- ✅ 从tx.qsgl.net迁移Envoy配置到62.234.212.241
- ✅ 将泛域名(*.qsgl.net)改为单域名(www.qsgl.net)
- ✅ 部署Let's Encrypt泛域名证书(*.qsgl.net)
- ✅ 修复ECC证书加载问题（清理PKCS#12元数据）
- ✅ 更新监控脚本，添加公网域名检测
- ✅ 所有服务正常运行，公网访问测试通过
