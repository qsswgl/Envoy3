# 端口99 gRPC-WEB 修复报告

## 问题描述

测试页面 `https://a.qsgl.net/test-grpc-web.html` 显示：
- ✅ 端口 443: Envoy处理正常，gRPC-WEB工作
- ❌ 端口 99: Server显示N/A，请求被拒绝
- ✅ 端口 5002: Envoy处理正常，gRPC-WEB工作

## 问题根源

**端口99的请求完全绕过了Envoy代理**，直接连接到后端服务器。

### 分析过程

1. **测试发现**：端口99返回的响应头没有 `server: envoy`
   ```bash
   curl -I https://a.qsgl.net:99/
   # 返回: Server: N/A (实际是Kestrel/IIS)
   ```

2. **检查Docker端口映射**：
   ```bash
   docker ps | grep envoy
   # 发现：只有443和5002映射，没有99端口！
   ```

3. **原因确认**：
   - `docker-compose.yml` 缺少 `"99:99/tcp"` 端口映射
   - 请求直接到达 `62.234.212.241:99` 的后端服务
   - 完全绕过Envoy，所以没有CORS、没有gRPC-WEB过滤

## 修复方案

### 1. 添加Docker端口映射

**修改 `docker-compose.yml`**：
```yaml
ports:
  # HTTPS 端口 (TCP)
  - "443:443/tcp"
  - "99:99/tcp"        # ← 添加这一行
  - "5002:5002/tcp"
  # HTTP/3 端口 (UDP)
  - "443:443/udp"
  - "5002:5002/udp"
```

### 2. 修复其他配置问题

#### 问题A: Docker镜像构建失败
**原因**：服务器上没有Dockerfile
**解决**：改用预构建镜像
```yaml
# 从 build 改为 image
services:
  envoy:
    image: envoyproxy/envoy:contrib-v1.36.2  # 使用官方镜像
```

#### 问题B: 配置文件路径错误
**原因**：`envoy.yaml` 变成了目录
**解决**：使用正确的配置路径
```yaml
volumes:
  - ./config/envoy.yaml:/etc/envoy/envoy.yaml:ro  # 正确路径
```

#### 问题C: 证书路径错误
**原因**：证书在 `/opt/shared-certs/`，不在 `./certs/`
**解决**：修改证书挂载路径
```yaml
volumes:
  - /opt/shared-certs:/etc/envoy/certs:ro  # 使用绝对路径
```

## 修复步骤

### 执行的命令

```bash
# 1. 上传修改后的 docker-compose.yml
scp -i qsgl_key.pem docker-compose.yml ubuntu@62.234.212.241:/tmp/

# 2. 修改配置文件
ssh ubuntu@62.234.212.241 << 'EOF'
  # 移动配置文件
  sudo mv /tmp/docker-compose.yml /opt/envoy/

  # 移除build配置，添加image
  sudo sed -i '/build:/,/dockerfile: Dockerfile/d' docker-compose.yml
  sudo sed -i '/envoy:/a\    image: envoyproxy/envoy:contrib-v1.36.2' docker-compose.yml

  # 修复挂载路径
  sudo sed -i 's|./envoy.yaml|./config/envoy.yaml|g' docker-compose.yml
  sudo sed -i 's|./certs|/opt/shared-certs|g' docker-compose.yml

  # 修复envoy.yaml中的证书路径
  sudo sed -i 's|/opt/certs/|/etc/envoy/certs/|g' /opt/envoy/config/envoy.yaml
EOF

# 3. 重启容器
ssh ubuntu@62.234.212.241 "cd /opt/envoy && sudo docker compose down && sudo docker compose up -d"
```

### 验证结果

```bash
# 检查容器状态
docker ps | grep envoy
# ✅ 输出显示：0.0.0.0:99->99/tcp, :::99->99/tcp

# 测试Envoy处理
curl -I https://a.qsgl.net:99/
# ✅ 返回：server: envoy

# 测试CORS
curl -i -X OPTIONS https://a.qsgl.net:99/ \
  -H "Origin: https://a.qsgl.net" \
  -H "Access-Control-Request-Method: POST"
# ✅ 返回完整CORS头

# 测试gRPC-WEB
curl -I https://a.qsgl.net:99/ \
  -H "Content-Type: application/grpc-web+proto"
# ✅ 返回：content-type: application/grpc-web+proto
```

## 测试结果

### 所有端口功能正常

| 端口 | Envoy处理 | CORS | gRPC-WEB | HTTP/3 |
|------|-----------|------|----------|---------|
| 443  | ✅ | ✅ | ✅ | ✅ |
| 99   | ✅ | ✅ | ✅ | ❌ (仅TCP) |
| 5002 | ✅ | ✅ | ✅ | ✅ |

### 浏览器测试

访问 `https://a.qsgl.net/test-grpc-web.html`：
- ✅ 端口 443 - gRPC-WEB 请求测试：通过
- ✅ 端口 99 - gRPC-WEB 请求测试：通过
- ✅ 端口 5002 - gRPC-WEB 请求测试：通过

## 经验总训

### 1. Docker端口映射是第一步
配置再完美，如果容器没有暴露端口，外部无法访问。

### 2. 逐层排查
```
外部访问 → 云服务器安全组 → 防火墙 → Docker端口映射 → 容器内部 → Envoy监听 → 后端服务
```

### 3. 检查实际生效的配置
不要只看代码仓库的配置，要检查服务器上实际运行的配置。

### 4. 容器日志是最好的诊断工具
```bash
docker logs envoy-proxy --tail 50
```
可以快速定位：
- 证书路径错误
- 配置文件格式问题
- 监听端口冲突
- 权限问题

## 相关文件

- `docker-compose.yml` - Docker编排配置
- `envoy.yaml` - Envoy代理配置
- `test-grpc-web.html` - 浏览器测试页面
- `GRPC-WEB-TEST-REPORT.md` - 完整测试报告

## 时间线

- **12:06** - 用户报告端口99 gRPC-WEB失败
- **12:15** - 发现Docker缺少99端口映射
- **12:25** - 修复docker-compose.yml，遇到证书路径问题
- **12:27** - 解决所有配置问题，容器成功启动
- **12:28** - 验证完成，所有功能正常

## 配置差异对比

### 修复前
```yaml
services:
  envoy:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "443:443/tcp"
      # ❌ 缺少99端口
      - "5002:5002/tcp"
    volumes:
      - ./envoy.yaml:/etc/envoy/envoy.yaml:ro  # ❌ 路径错误
      - ./certs:/etc/envoy/certs:ro             # ❌ 证书位置错误
```

### 修复后
```yaml
services:
  envoy:
    image: envoyproxy/envoy:contrib-v1.36.2  # ✅ 使用官方镜像
    ports:
      - "443:443/tcp"
      - "99:99/tcp"                           # ✅ 添加99端口
      - "5002:5002/tcp"
    volumes:
      - ./config/envoy.yaml:/etc/envoy/envoy.yaml:ro  # ✅ 正确路径
      - /opt/shared-certs:/etc/envoy/certs:ro         # ✅ 正确证书位置
```

---

**修复完成时间**: 2025-10-30 12:28  
**测试状态**: ✅ 全部通过  
**文档版本**: v1.0
