# Envoy 代理快速参考

## 服务器信息
- **服务器IP**: 62.234.212.241
- **SSH登录**: `ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241`
- **域名**: www.qsgl.net
- **后端**: 61.163.200.245

---

## 常用命令

### 容器管理
```bash
# 查看容器状态
sudo docker ps | grep envoy

# 查看容器日志
sudo docker logs envoy-proxy --tail 50

# 重启容器
cd /opt/envoy && sudo docker compose restart

# 停止容器
cd /opt/envoy && sudo docker compose down

# 启动容器
cd /opt/envoy && sudo docker compose up -d
```

### 监控服务
```bash
# 查看监控状态
sudo systemctl status envoy-monitor.service

# 重启监控
sudo systemctl restart envoy-monitor.service

# 查看监控日志
sudo journalctl -u envoy-monitor.service -n 50 -f

# 停止监控
sudo systemctl stop envoy-monitor.service
```

### 端口检查
```bash
# 查看监听端口
sudo ss -tulnp | grep -E ':(443|5002|9901)'

# 查看 Admin API
curl http://127.0.0.1:9901/ready
curl http://127.0.0.1:9901/stats
curl http://127.0.0.1:9901/clusters
```

### SSL/TLS 测试
```bash
# 测试 SSL 连接
openssl s_client -connect localhost:443 -servername www.qsgl.net

# 查看证书信息
openssl x509 -in /opt/shared-certs/qsgl.net.fullchain.crt -noout -text

# 验证证书和密钥匹配
openssl x509 -noout -modulus -in /opt/shared-certs/qsgl.net.fullchain.crt | openssl md5
openssl rsa -noout -modulus -in /opt/shared-certs/qsgl.net.key | openssl md5
```

### HTTP 测试
```bash
# 本地测试 (使用 -k 忽略自签名证书警告)
curl -k -I -H 'Host: www.qsgl.net' https://localhost:443/
curl -k -I -H 'Host: www.qsgl.net' https://localhost:5002/

# 公网测试 (证书替换后)
curl -I https://www.qsgl.net/
curl -I https://www.qsgl.net:5002/
```

---

## 文件位置

### Envoy 配置
```
/opt/envoy/
├── docker-compose.yml      # Docker Compose 配置
└── config/
    └── envoy.yaml          # Envoy 主配置文件
```

### 证书文件
```
/opt/shared-certs/
├── qsgl.net.fullchain.crt  # SSL 证书（含中间证书）
└── qsgl.net.key            # SSL 私钥
```

### 监控脚本
```
/root/envoy/
├── monitor.py              # 监控脚本
├── envoy.yaml              # 旧配置备份
└── logs/
    └── monitor.log         # 监控日志
```

### Systemd 服务
```
/etc/systemd/system/
└── envoy-monitor.service   # 监控服务配置
```

---

## 证书更新流程

### 方法1: Let's Encrypt (推荐)
```bash
# 1. 停止 Envoy (certbot 需要 80/443 端口)
cd /opt/envoy && sudo docker compose down

# 2. 申请证书
sudo certbot certonly --standalone \
  -d www.qsgl.net \
  --agree-tos \
  --email admin@qsgl.net

# 3. 复制证书
sudo cp /etc/letsencrypt/live/www.qsgl.net/fullchain.pem \
  /opt/shared-certs/qsgl.net.fullchain.crt
sudo cp /etc/letsencrypt/live/www.qsgl.net/privkey.pem \
  /opt/shared-certs/qsgl.net.key

# 4. 设置权限
sudo chmod 644 /opt/shared-certs/qsgl.net.fullchain.crt
sudo chmod 600 /opt/shared-certs/qsgl.net.key

# 5. 重启 Envoy
cd /opt/envoy && sudo docker compose up -d
```

### 方法2: API 生成
```bash
# 调用证书生成 API
curl -X POST https://tx.qsgl.net:5075/api/cert/v2/generate \
  -H "Content-Type: application/json" \
  -d '{"domain": "www.qsgl.net"}' \
  -o /tmp/cert_response.json

# 提取并保存证书和密钥
# (根据 API 响应格式调整)
```

---

## 故障排查

### 容器无法启动
```bash
# 查看详细错误
sudo docker logs envoy-proxy

# 常见问题:
# 1. 证书密钥不匹配 - 检查证书和密钥文件
# 2. 端口已被占用 - 检查端口占用情况
# 3. 配置文件错误 - 验证 envoy.yaml 语法
```

### 监控告警频繁
```bash
# 查看监控日志
sudo journalctl -u envoy-monitor.service -n 100

# 检查后端服务
curl -I https://61.163.200.245/

# 调整监控频率 (修改 monitor.py 中的 CHECK_INTERVAL)
```

### SSL 证书错误
```bash
# 验证证书有效期
openssl x509 -in /opt/shared-certs/qsgl.net.fullchain.crt -noout -dates

# 验证证书域名
openssl x509 -in /opt/shared-certs/qsgl.net.fullchain.crt -noout -text | grep DNS

# 检查证书链完整性
openssl verify -CAfile /opt/shared-certs/qsgl.net.fullchain.crt \
  /opt/shared-certs/qsgl.net.fullchain.crt
```

### 端口无法访问
```bash
# 检查防火墙
sudo ufw status
sudo iptables -L -n | grep -E '443|5002'

# 检查系统配置
sysctl net.ipv4.ip_unprivileged_port_start

# 应该显示: 80 (如果是 1024,需要执行:)
echo 'net.ipv4.ip_unprivileged_port_start=80' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 监控邮件配置

- **收件人**: qsoft@139.com
- **SMTP服务器**: smtp.139.com:465
- **授权码**: 574a283d502db51ea200
- **检查间隔**: 300秒 (5分钟)
- **告警冷却**: 1800秒 (30分钟)

---

## 性能调优

### Envoy 配置调整
编辑 `/opt/envoy/config/envoy.yaml`:

```yaml
# 调整超时时间
timeout: 30s

# 调整连接池大小
http2_protocol_options:
  max_concurrent_streams: 100

# 启用访问日志
access_log:
- name: envoy.access_loggers.file
  typed_config:
    path: /dev/stdout
```

### 系统参数优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# TCP 优化
sudo sysctl -w net.core.somaxconn=1024
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=2048
```

---

## 备份与恢复

### 配置备份
```bash
# 创建完整备份
sudo tar czf /tmp/envoy-backup-$(date +%Y%m%d).tgz \
  /opt/envoy/ \
  /opt/shared-certs/ \
  /root/envoy/ \
  /etc/systemd/system/envoy-monitor.service

# 下载到本地
scp -i "C:\Key\qsgl_key.pem" \
  ubuntu@62.234.212.241:/tmp/envoy-backup-*.tgz \
  K:\Envoy3\backups\
```

### 配置恢复
```bash
# 上传备份
scp -i "C:\Key\qsgl_key.pem" \
  K:\Envoy3\backups\envoy-backup-20251030.tgz \
  ubuntu@62.234.212.241:/tmp/

# 恢复配置
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241
cd /tmp
sudo tar xzf envoy-backup-20251030.tgz -C /
sudo systemctl daemon-reload
cd /opt/envoy && sudo docker compose up -d
sudo systemctl restart envoy-monitor.service
```

---

## 相关文档

- **完整迁移报告**: `TX-MIGRATION-REPORT.md`
- **部署文档**: `README.md`
- **需求文档**: `需求.txt`
- **本地配置**: `envoy.yaml`, `monitor.py`, `docker-compose.yml`

---

## 联系方式

- **监控邮箱**: qsoft@139.com
- **证书API**: https://tx.qsgl.net:5075/api/cert/v2/generate
- **Swagger文档**: https://tx.qsgl.net:5075/swagger/index.html

---

*更新时间: 2025年10月30日*
