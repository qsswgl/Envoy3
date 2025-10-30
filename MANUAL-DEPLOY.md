# 手动部署指南

由于 SSH 密钥认证问题，请按照以下步骤手动完成部署：

## 步骤 1: 解决 SSH 密钥问题

当前密钥文件 `C:\Key\qsgl_id_rsa.txt` 无法被 OpenSSH 识别。

### 可能的解决方案：

#### 选项 A: 检查密钥是否需要密码
```powershell
# 尝试使用密码连接
ssh -i "C:\Key\qsgl_id_rsa.txt" root@62.234.212.241
```

#### 选项 B: 使用 PuTTY 格式
如果密钥是 PuTTY 格式(.ppk)，需要转换：
1. 使用 PuTTYgen 打开密钥
2. Conversions -> Export OpenSSH key
3. 保存为新文件

#### 选项 C: 转换密钥格式
```powershell
# 如果有原始 PEM 格式的密钥
ssh-keygen -p -f C:\Key\qsgl_id_rsa.txt -m pem -P "" -N ""
```

#### 选项 D: 使用密码登录
```powershell
ssh root@62.234.212.241
# 输入密码后再进行部署
```

#### 选项 E: 使用其他 SSH 客户端
- 尝试使用 MobaXterm、Xshell 或 PuTTY
- 这些工具可能对密钥格式更宽容

## 步骤 2: 手动上传文件

一旦 SSH 连接成功，使用以下命令上传文件：

### 方法 1: 使用 SCP
```powershell
# 设置变量
$KEY = "C:\Key\qsgl_id_rsa.txt"  # 或其他有效的密钥路径
$SERVER = "root@62.234.212.241"
$REMOTE = "/root/envoy"

# 创建远程目录
ssh -i $KEY $SERVER "mkdir -p $REMOTE/certs $REMOTE/logs"

# 上传所有文件
scp -i $KEY K:\Envoy3\envoy.yaml ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\Dockerfile ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\docker-compose.yml ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\*.sh ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\*.py ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\*.service ${SERVER}:${REMOTE}/
scp -i $KEY K:\Envoy3\*.md ${SERVER}:${REMOTE}/
```

### 方法 2: 使用 WinSCP
1. 打开 WinSCP
2. 连接到 62.234.212.241
3. 将 K:\Envoy3\ 下的所有文件拖拽到 /root/envoy/

### 方法 3: 先登录 SSH，然后使用 Git
```bash
# 在服务器上
cd /root
git clone <your-repo-url> envoy
# 或者如果文件在本地，可以使用 FTP/SFTP 工具
```

## 步骤 3: 在服务器上执行部署

SSH 登录到服务器后：

```bash
cd /root/envoy

# 设置执行权限
chmod +x *.sh *.py

# 查看文件
ls -la

# 执行自动部署脚本
./deploy.sh
```

## 步骤 4: 或者手动逐步部署

如果自动部署脚本遇到问题，按以下步骤手动部署：

```bash
cd /root/envoy

# 1. 安装依赖
apt update
apt install -y curl jq python3 python3-pip docker.io docker-compose
pip3 install requests

# 2. 启动 Docker
systemctl enable docker
systemctl start docker

# 3. 生成证书
python3 generate-cert.py
# 如果 API 不可用，需要手动放置证书到 certs/ 目录

# 4. 构建并启动容器
docker-compose build
docker-compose up -d

# 5. 查看容器状态
docker ps
docker-compose logs -f

# 6. 配置监控服务
cp envoy-monitor.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable envoy-monitor
systemctl start envoy-monitor

# 7. 运行诊断
./diagnose.sh
```

## 验证部署

```bash
# 检查容器状态
docker ps | grep envoy-proxy

# 检查端口
ss -tlnp | grep -E '443|5002|9901'

# 测试 Envoy Admin API
curl http://localhost:9901/ready

# 检查监控服务
systemctl status envoy-monitor

# 查看日志
tail -f logs/monitor.log
```

## 测试访问

从本地或其他机器测试：

```bash
# 测试 HTTPS 连接
curl -k https://62.234.212.241

# 测试端口 5002
curl -k https://62.234.212.241:5002

# 测试域名（需要先配置 DNS）
curl -k https://your-domain.qsgl.net
```

## 故障排除

### SSH 密钥问题
- 确认密钥文件格式（OpenSSH 或 PEM）
- 检查密钥权限（600）
- 确认密钥是否需要密码短语
- 尝试生成新的密钥对

### 证书生成失败
如果 API 无法访问，需要手动准备证书：
```bash
mkdir -p certs
# 将证书文件放入 certs/cert.pem
# 将私钥文件放入 certs/key.pem
chmod 600 certs/key.pem
chmod 644 certs/cert.pem
```

### Docker 问题
```bash
# 查看 Docker 版本
docker --version
docker-compose --version

# 如果版本太旧，手动安装最新版
curl -fsSL https://get.docker.com | sh
```

## 联系支持

如需帮助，请提供以下信息：
- SSH 连接错误信息
- 服务器系统版本：`cat /etc/os-release`
- Docker 版本：`docker --version`
- 错误日志：`docker-compose logs`

---

**提示**: 所有配置文件已准备好在 `K:\Envoy3\` 目录中，只需要解决 SSH 连接问题即可开始部署。
