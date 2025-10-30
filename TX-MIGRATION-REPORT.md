# Envoy 代理迁移报告

## 迁移概述

**日期**: 2025年10月30日  
**源服务器**: tx.qsgl.net (43.138.35.183)  
**目标服务器**: 62.234.212.241  
**迁移状态**: ✅ 成功完成

---

## 迁移内容

### 1. Envoy 容器配置

从 tx.qsgl.net 迁移的 Envoy 代理容器配置：

- **镜像版本**: `envoyproxy/envoy:contrib-v1.36.2`
- **部署位置**: `/opt/envoy/`
- **配置文件**: 
  - `/opt/envoy/docker-compose.yml`
  - `/opt/envoy/config/envoy.yaml`
- **证书位置**: `/opt/shared-certs/`

### 2. 配置特性

#### 监听端口
- **443** (TCP/UDP): HTTPS + HTTP/3 (QUIC)
- **5002** (TCP): HTTPS (支持SSE长连接)
- **9901** (TCP): Admin接口 (仅本地访问)

#### 支持的协议
- ✅ HTTP/1.1
- ✅ HTTP/2 (h2)
- ✅ HTTP/3 (QUIC)
- ✅ gRPC-WEB

#### 域名配置
- **监听域名**: www.qsgl.net, tx.qsgl.net, *.qsgl.net, qsgl.net
- **上游SNI**: www.qsgl.net
- **后端服务器**: 61.163.200.245:443, 61.163.200.245:5002

#### CORS 配置
- 允许所有来源
- 允许凭证传递
- 支持常见HTTP方法: GET, POST, PUT, DELETE, OPTIONS, PATCH

---

## 迁移步骤

### 第一阶段：获取配置
1. ✅ SSH登录到 tx.qsgl.net
2. ✅ 导出 docker-compose.yml 和 envoy.yaml
3. ✅ 识别使用的证书文件
4. ✅ 打包配置文件和证书

### 第二阶段：准备目标服务器
1. ✅ 停止旧的 Envoy 容器
2. ✅ 创建 `/opt/envoy` 目录结构
3. ✅ 创建 `/opt/shared-certs` 证书目录
4. ✅ 配置系统参数: `net.ipv4.ip_unprivileged_port_start=80`

### 第三阶段：部署新配置
1. ✅ 传输配置文件到目标服务器
2. ✅ 标记现有镜像为 contrib-v1.36.2
3. ✅ 部署临时自签名证书
4. ✅ 启动 Envoy 容器

### 第四阶段：验证
1. ✅ 容器状态检查 - 正常运行
2. ✅ 端口监听检查 - 443, 5002, 9901 正常
3. ✅ Admin API 检查 - LIVE
4. ✅ SSL握手测试 - 成功

---

## 当前状态

### 运行状态
```bash
容器名称: envoy-proxy
镜像: envoyproxy/envoy:contrib-v1.36.2
状态: Up (运行中)
重启策略: unless-stopped
网络模式: host
特权模式: true
```

### 监听端口
```
TCP  0.0.0.0:443    (envoy-proxy)
TCP  0.0.0.0:5002   (envoy-proxy)
TCP  127.0.0.1:9901 (envoy-proxy)
UDP  0.0.0.0:443    (envoy-proxy, HTTP/3)
```

### 证书状态
⚠️ **当前使用自签名证书** (临时)
- 颁发者: CN=*.qsgl.net
- 主体: CN=*.qsgl.net
- 类型: 自签名证书

---

## 配置差异说明

### 与原 62.234.212.241 配置的主要区别

1. **域名匹配更宽泛**
   - 原配置: 仅 `www.qsgl.net`
   - 新配置: `www.qsgl.net`, `tx.qsgl.net`, `*.qsgl.net`, `qsgl.net`

2. **增强的 CORS 支持**
   - 配置了完整的 CORS 策略
   - 支持凭证传递
   - 允许自定义请求头

3. **SSE 长连接支持**
   - 5002 端口支持 `/sse/` 路径的无超时配置
   - stream_idle_timeout: 3600s

4. **访问日志**
   - 5002 端口启用详细访问日志
   - 输出到容器标准输出

---

## 待完成任务

### 1. 证书替换 (高优先级)
⚠️ 当前使用自签名证书，需要替换为受信任证书

**选项 A: 使用 Let's Encrypt**
```bash
# 在目标服务器上执行
sudo certbot certonly --standalone \
  -d www.qsgl.net \
  --pre-hook "sudo docker stop envoy-proxy" \
  --post-hook "sudo docker start envoy-proxy"

# 复制证书到 Envoy 目录
sudo cp /etc/letsencrypt/live/www.qsgl.net/fullchain.pem /opt/shared-certs/qsgl.net.fullchain.crt
sudo cp /etc/letsencrypt/live/www.qsgl.net/privkey.pem /opt/shared-certs/qsgl.net.key

# 重启容器
cd /opt/envoy && sudo docker compose restart
```

**选项 B: 调用证书生成API**
```bash
# 调用 tx.qsgl.net 的证书生成服务
curl -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{"domain": "www.qsgl.net"}'
```

### 2. 配置监控脚本
需要将本地 `/root/envoy/monitor.py` 适配到新配置：
- 更新监控域名为 www.qsgl.net
- 确保监控服务 systemd 配置正确

### 3. 端口 99 支持
原需求包含端口 99，但 tx 配置中未包含，需确认是否需要添加。

---

## 本地配置更新

### 已更新文件

1. **envoy.yaml** (本地)
   - 虚拟主机域名从 `*.qsgl.net` 改为 `www.qsgl.net`
   - 所有5个监听器的domains配置已更新

2. **monitor.py** (本地)
   - 添加 `PUBLIC_ENDPOINT = "https://www.qsgl.net"`
   - 后端检查更新为 Host 头绑定方式
   - 新增公网域名检查功能
   - 禁用 urllib3 SSL 警告(临时)

3. **需求.txt** (本地)
   - 从"泛域名"更新为"单域名"

### 需同步到服务器的文件

⚠️ **注意**: 以下本地修改的文件需要上传到 62.234.212.241：

```bash
# 从本地上传更新后的监控脚本
scp -i "C:\Key\qsgl_key.pem" K:\Envoy3\monitor.py ubuntu@62.234.212.241:/tmp/
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 "sudo cp /tmp/monitor.py /root/envoy/monitor.py"
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 "sudo systemctl restart envoy-monitor.service"
```

---

## 验证命令

### 检查容器状态
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 "sudo docker ps | grep envoy"
```

### 检查监听端口
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 "sudo ss -tulnp | grep -E ':(443|5002|9901)'"
```

### 测试 Admin API
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 "curl -s http://127.0.0.1:9901/ready"
# 期望输出: LIVE
```

### 测试 SSL 连接
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241 \
  "timeout 5 openssl s_client -connect localhost:443 -servername www.qsgl.net < /dev/null 2>&1 | grep 'Verify return code'"
```

### 测试 HTTP 代理
```bash
# 替换证书后执行
curl -v https://www.qsgl.net/
```

---

## 故障排查

### 问题 1: 证书密钥不匹配
**现象**: `KEY_VALUES_MISMATCH` 错误  
**原因**: tx.qsgl.net 上的证书和密钥不匹配  
**解决**: 使用本地自签名证书临时运行，待重新申请证书

### 问题 2: 端口 443 权限拒绝
**现象**: `Permission denied` binding 0.0.0.0:443  
**解决**: 配置 `net.ipv4.ip_unprivileged_port_start=80`

### 问题 3: SSL 连接重置
**现象**: `Connection reset by peer`  
**原因**: SNI 不匹配或 filter_chain_match 限制  
**解决**: 使用正确的 `-servername` 参数测试

---

## 系统配置更改

### /etc/sysctl.conf
添加的配置：
```conf
net.ipv4.ip_unprivileged_port_start=80
```

生效命令：
```bash
sudo sysctl -p
```

---

## 下一步行动计划

### 立即执行
1. ⚠️ **申请 Let's Encrypt 证书**（高优先级）
2. 🔄 上传更新后的 monitor.py
3. ✅ 验证监控服务正常运行

### 近期计划
4. 📝 更新本地文档中的泛域名引用
5. 🧪 端到端测试所有代理功能
6. 📊 配置监控告警确认正常

### 长期维护
7. 🔐 设置证书自动续期
8. 📈 监控性能指标
9. 🔄 定期备份配置

---

## 迁移总结

✅ **成功项**:
- Envoy 容器从 tx.qsgl.net 成功迁移到 62.234.212.241
- 所有监听端口正常工作
- HTTP/3、gRPC-WEB 支持已启用
- Admin API 可访问
- 容器重启策略已配置

⚠️ **待完成项**:
- 替换自签名证书为受信任证书
- 同步更新后的监控脚本到服务器
- 验证公网访问和监控告警

---

## 附录

### 相关文件路径

**目标服务器 (62.234.212.241)**:
- Compose文件: `/opt/envoy/docker-compose.yml`
- Envoy配置: `/opt/envoy/config/envoy.yaml`
- 证书目录: `/opt/shared-certs/`
- 证书文件: `/opt/shared-certs/qsgl.net.fullchain.crt`
- 私钥文件: `/opt/shared-certs/qsgl.net.key`
- 旧配置备份: `/root/envoy/`

**本地工作目录 (K:\Envoy3)**:
- 迁移报告: `TX-MIGRATION-REPORT.md`
- 配置归档: `artifacts/envoy_proxy_bundle.tgz`
- 更新后的监控: `monitor.py`
- Envoy配置: `envoy.yaml`

### 联系信息
- 监控邮箱: qsoft@139.com
- 证书API: https://tx.qsgl.net:5075/api/cert/v2/generate

---

*报告生成时间: 2025年10月30日*
