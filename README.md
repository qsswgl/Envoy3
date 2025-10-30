# Envoy 容器代理部署文档

## 项目概述

本项目在腾讯云服务器上部署 Envoy 反向代理，实现 `*.qsgl.net` 泛域名到后端服务器 `https://61.163.200.245` 的代理转发。

### 主要特性

- ✅ 支持 HTTP/3 (QUIC) 和 HTTP/2
- ✅ 支持 gRPC-WEB 通讯
- ✅ 双端口代理：443 和 5002
- ✅ 容器自动重启策略
- ✅ 健康检查和自动诊断
- ✅ 服务监控和邮件告警（每5分钟检查）
- ✅ 使用 Docker Compose 管理部署

---

## 服务器信息

- **服务器 IP**: 62.234.212.241
- **SSH 密钥**: `K:\Key\qsgl_ssh\qsgl_key.pem`
- **后端服务器**: 61.163.200.245
- **代理端口**: 443, 5002
- **泛域名**: *.qsgl.net

---

## 部署前准备

### 1. SSH 连接服务器

#### Windows PowerShell
```powershell
ssh -i "K:\Key\qsgl_ssh\qsgl_key.pem" root@62.234.212.241
```

#### Linux/Mac
```bash
chmod 400 /path/to/qsgl_key.pem
ssh -i /path/to/qsgl_key.pem root@62.234.212.241
```

### 2. 安装必要软件

```bash
# 更新系统
apt update && apt upgrade -y

# 安装 Docker
curl -fsSL https://get.docker.com | sh
systemctl enable docker
systemctl start docker

# 安装 Docker Compose
apt install docker-compose -y

# 安装其他工具
apt install curl jq python3 python3-pip git -y

# 安装 Python 依赖（用于监控脚本）
pip3 install requests
```

---

## 部署步骤

### 1. 上传项目文件到服务器

```bash
# 在服务器上创建项目目录
mkdir -p /root/envoy
cd /root/envoy

# 从本地上传文件（在本地 PowerShell 中执行）
scp -i "K:\Key\qsgl_ssh\qsgl_key.pem" -r K:\Envoy3\* root@62.234.212.241:/root/envoy/
```

或者使用 Git：

```bash
# 如果项目在 Git 仓库中
cd /root/envoy
git clone <repository_url> .
```

### 2. 生成 SSL 证书

使用提供的脚本调用 API 生成证书：

```bash
cd /root/envoy

# 使用 Python 脚本生成证书
python3 generate-cert.py

# 或使用 Bash 脚本
chmod +x generate-cert.sh
./generate-cert.sh
```

**注意**: 
- 证书将保存在 `./certs/` 目录
- 请确保 API 端点 `https://tx.qsgl.net:5075/api/cert/v2/generate` 可访问
- 根据实际 API 文档调整脚本中的请求参数

如果 API 不可用，可以手动放置证书：

```bash
mkdir -p certs
# 将证书文件复制到 certs 目录
# cert.pem - 证书文件
# key.pem - 私钥文件
chmod 600 certs/key.pem
chmod 644 certs/cert.pem
```

### 3. 创建必要的目录

```bash
mkdir -p logs certs
```

### 4. 构建和启动容器

```bash
cd /root/envoy

# 构建镜像
docker-compose build

# 启动服务
docker-compose up -d

# 查看日志
docker-compose logs -f
```

### 5. 验证部署

```bash
# 检查容器状态
docker ps

# 检查端口监听
ss -tlnp | grep -E '443|5002|9901'

# 运行诊断脚本
chmod +x diagnose.sh
./diagnose.sh

# 检查 Envoy Admin API
curl http://localhost:9901/ready
curl http://localhost:9901/stats
```

---

## 监控和告警配置

### 1. 配置监控服务（使用 systemd）

```bash
# 复制服务文件
cp envoy-monitor.service /etc/systemd/system/

# 修改服务文件中的工作目录（如果需要）
nano /etc/systemd/system/envoy-monitor.service

# 重载 systemd
systemctl daemon-reload

# 启动监控服务
systemctl start envoy-monitor

# 设置开机自启
systemctl enable envoy-monitor

# 查看监控服务状态
systemctl status envoy-monitor

# 查看监控日志
journalctl -u envoy-monitor -f
```

### 2. 手动运行监控

```bash
# 前台运行（测试用）
python3 monitor.py

# 后台运行
nohup python3 monitor.py > /dev/null 2>&1 &
```

### 监控功能

- ⏰ 每 5 分钟自动检查服务状态
- 📧 异常时发送邮件到 `qsoft@139.com`
- 🔍 检查项目：
  - 容器运行状态
  - 健康检查状态
  - Admin API 可用性
  - 端口监听状态
  - 后端服务连接

---

## 证书更新

### 自动更新证书

```bash
# 生成新证书
python3 generate-cert.py

# 重启容器使证书生效
docker-compose restart
```

### 定期自动更新（可选）

创建 cron 任务每月更新证书：

```bash
# 编辑 crontab
crontab -e

# 添加以下内容（每月1号凌晨2点更新）
0 2 1 * * cd /root/envoy && python3 generate-cert.py && docker-compose restart >> /root/envoy/logs/cert-renewal.log 2>&1
```

---

## 日常维护

### 查看日志

```bash
# 查看容器日志
docker-compose logs -f

# 查看最近的日志
docker-compose logs --tail=100

# 查看监控日志
tail -f logs/monitor.log

# 查看诊断日志
tail -f logs/cert-generation.log
```

### 重启服务

```bash
# 重启 Envoy 容器
docker-compose restart

# 完全重新部署
docker-compose down
docker-compose up -d
```

### 更新配置

```bash
# 修改 envoy.yaml 后
nano envoy.yaml

# 重启容器使配置生效
docker-compose restart
```

### 手动诊断

```bash
# 运行完整诊断
./diagnose.sh

# 检查容器健康状态
docker inspect envoy-proxy | jq '.[0].State.Health'

# 查看 Envoy 统计信息
curl http://localhost:9901/stats | grep -E "request|connection"

# 测试后端连接
curl -k https://61.163.200.245:443
```

---

## 故障排查

### 问题：容器无法启动

```bash
# 查看详细日志
docker-compose logs

# 检查配置文件语法
docker run --rm -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml envoyproxy/envoy:v1.31-latest \
  envoy --mode validate -c /etc/envoy/envoy.yaml
```

### 问题：证书错误

```bash
# 检查证书文件
ls -la certs/
openssl x509 -in certs/cert.pem -noout -text

# 验证证书和私钥匹配
openssl x509 -noout -modulus -in certs/cert.pem | openssl md5
openssl rsa -noout -modulus -in certs/key.pem | openssl md5
```

### 问题：端口冲突

```bash
# 检查端口占用
ss -tlnp | grep -E '443|5002'

# 停止占用端口的服务
systemctl stop <service-name>
```

### 问题：后端不可达

```bash
# 测试后端连接
telnet 61.163.200.245 443
curl -k -v https://61.163.200.245:443

# 检查防火墙规则
iptables -L -n
ufw status
```

### 问题：HTTP/3 不工作

```bash
# 确保 UDP 端口开放
ufw allow 443/udp
ufw allow 5002/udp

# 测试 QUIC 连接（需要支持 HTTP/3 的客户端）
curl --http3 https://your-domain.qsgl.net
```

---

## 安全建议

1. **定期更新**
   ```bash
   # 更新 Envoy 镜像
   docker-compose pull
   docker-compose up -d
   ```

2. **限制 Admin API 访问**
   - Admin API (9901) 仅监听 localhost
   - 不要将 9901 端口暴露到公网

3. **定期更新证书**
   - 监控证书到期时间
   - 提前 30 天更新证书

4. **日志管理**
   ```bash
   # 清理旧日志
   find logs/ -name "*.log" -mtime +30 -delete
   ```

5. **备份配置**
   ```bash
   # 定期备份配置文件
   tar -czf envoy-backup-$(date +%Y%m%d).tar.gz envoy.yaml docker-compose.yml certs/
   ```

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `envoy.yaml` | Envoy 主配置文件 |
| `Dockerfile` | 容器镜像构建文件 |
| `docker-compose.yml` | Docker Compose 配置 |
| `generate-cert.sh` | 证书生成脚本（Bash） |
| `generate-cert.py` | 证书生成脚本（Python） |
| `diagnose.sh` | 服务诊断脚本 |
| `monitor.py` | 监控和告警脚本 |
| `envoy-monitor.service` | systemd 服务配置 |
| `certs/` | 证书存放目录 |
| `logs/` | 日志存放目录 |

---

## 参考资源

- [Envoy 官方文档](https://www.envoyproxy.io/docs/envoy/latest/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [HTTP/3 配置指南](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/http/http3)
- [gRPC-Web 配置](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_filters/grpc_web_filter)

---

## 联系支持

如有问题，请联系：
- 📧 Email: qsoft@139.com
- 🔔 告警邮箱: qsoft@139.com

---

**最后更新**: 2025-10-29
