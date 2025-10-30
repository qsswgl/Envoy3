# 泛域名代理配置说明

## ✅ 问题已解决

**问题**: `https://a.qsgl.net` 打开提示找不到页面，没有代理到后端  
**原因**: Envoy配置只允许 `www.qsgl.net`，不支持其他子域名  
**解决**: 已将配置改为泛域名 `*.qsgl.net` 和 `qsgl.net`

## 当前配置

### 支持的域名
Envoy现在支持所有子域名的代理：

- ✅ `www.qsgl.net`
- ✅ `a.qsgl.net`
- ✅ `test.qsgl.net`
- ✅ `api.qsgl.net`
- ✅ 任何 `*.qsgl.net` 子域名
- ✅ 裸域名 `qsgl.net`

### 配置详情
```yaml
# 所有5个监听器都已更新为泛域名
virtual_hosts:
  - name: qsgl_backend
    domains: ["*.qsgl.net", "qsgl.net"]  # 改为泛域名
```

更新的监听器：
1. ✅ `listener_https_443` (TCP 443端口)
2. ✅ `listener_https_5002` (TCP 5002端口)
3. ✅ `listener_https_99` (TCP 99端口)
4. ✅ `listener_quic_443` (UDP 443端口, HTTP/3)
5. ✅ `listener_quic_5002` (UDP 5002端口, HTTP/3)

## 测试结果

### a.qsgl.net 测试
```bash
$ curl -I https://a.qsgl.net/
HTTP/1.1 404 Not Found
content-length: 315
content-type: text/html; charset=us-ascii
server: envoy                    # ✅ 证明经过Envoy代理
date: Thu, 30 Oct 2025 00:32:16 GMT
x-envoy-upstream-service-time: 86
alt-svc: h3=":443"; ma=86400     # ✅ 支持HTTP/3
```

**说明**: 
- ✅ 代理正常工作（看到 `server: envoy`）
- ✅ 支持HTTP/3（看到 `alt-svc` 头）
- ⚠️ 返回404是因为**后端服务器**(61.163.200.245)上没有配置`a.qsgl.net`站点

### www.qsgl.net 测试
```bash
$ curl -I https://www.qsgl.net/
HTTP/2 200
cache-control: no-cache
content-length: 29478
content-type: text/html
server: envoy                    # ✅ 经过Envoy
alt-svc: h3=":443"; ma=86400    # ✅ 支持HTTP/3
```

## DNS配置要求

### 正确配置示例（指向Envoy服务器）
```
a.qsgl.net      A    62.234.212.241  ✅
www.qsgl.net    A    62.234.212.241  ✅
api.qsgl.net    A    62.234.212.241  ✅
```

### 错误配置示例（直连后端）
```
test.qsgl.net   A    61.163.200.245  ❌ 直连后端，绕过Envoy
```

**重要**: 要使用Envoy代理，所有子域名必须通过DNS解析到 `62.234.212.241`

## 后端服务器配置

### 当前后端响应
- ✅ `www.qsgl.net` → 200 OK (有配置的站点)
- ❌ `a.qsgl.net` → 404 Not Found (未配置)
- ❌ `test.qsgl.net` → 404 Not Found (未配置)

### 如何在后端添加新站点

#### 方法1: IIS绑定（如果后端是IIS）
1. 打开IIS管理器
2. 选择网站
3. 右键 → 编辑绑定
4. 添加新的主机名：`a.qsgl.net`
5. 保存并重启站点

#### 方法2: 使用通配符绑定
在IIS或Web服务器配置中使用：
```
*.qsgl.net  →  指向同一站点
```

这样所有子域名都会被同一站点处理。

#### 方法3: 应用程序内路由
在ASP.NET或其他框架中根据 `Host` 头判断：
```csharp
if (Request.Host == "a.qsgl.net") {
    // 处理 a.qsgl.net 的请求
}
```

## SSL证书覆盖

当前Let's Encrypt证书已支持所有子域名：

```
证书主题: CN = qsgl.net
SAN (主题备用名称):
  - DNS: *.qsgl.net  ✅ 覆盖所有子域名
  - DNS: qsgl.net    ✅ 覆盖裸域名
```

证书对以下域名均有效：
- ✅ www.qsgl.net
- ✅ a.qsgl.net
- ✅ api.qsgl.net
- ✅ test.qsgl.net
- ✅ 任何 *.qsgl.net
- ✅ qsgl.net

## 验证命令

### 测试任意子域名代理
```bash
# 测试a.qsgl.net
curl -I https://a.qsgl.net/

# 测试api.qsgl.net
curl -I https://api.qsgl.net/

# 查看是否经过Envoy（应该看到 server: envoy）
curl -I https://子域名.qsgl.net/ | grep -i server
```

### 本地测试（不依赖DNS）
```bash
# 直接测试Envoy服务器
curl -I -k -H "Host: a.qsgl.net" https://62.234.212.241/

# 应该返回
# HTTP/2 404
# server: envoy  ← 说明代理工作正常
```

### 检查Envoy配置
```bash
ssh -i "C:\Key\qsgl_key.pem" ubuntu@62.234.212.241

# 查看当前域名配置
grep -A2 "domains:" /opt/envoy/config/envoy.yaml

# 应该显示:
# domains: ["*.qsgl.net", "qsgl.net"]
```

## 故障排查

### 问题1: 子域名仍然显示"找不到页面"

**检查DNS**:
```bash
nslookup 子域名.qsgl.net
# 必须返回: 62.234.212.241
```

**解决**: 
- 如果DNS指向其他IP，需要在DNS服务商处修改A记录
- 或添加新的A记录指向62.234.212.241

### 问题2: 浏览器显示证书警告

**原因**: 泛域名证书 `*.qsgl.net` 覆盖所有子域名，不应有警告

**检查**:
```bash
openssl s_client -connect 子域名.qsgl.net:443 -servername 子域名.qsgl.net < /dev/null 2>/dev/null | openssl x509 -noout -text | grep DNS
```

应该显示: `DNS:*.qsgl.net, DNS:qsgl.net`

**解决**:
- 清除浏览器缓存
- 清除DNS缓存: `ipconfig /flushdns`

### 问题3: 后端返回404

**这不是Envoy的问题！** 404表示：
- ✅ Envoy代理工作正常
- ✅ 证书验证通过
- ✅ 请求到达后端服务器
- ❌ 后端服务器上该域名未配置站点

**解决**: 在后端服务器(61.163.200.245)上配置该域名的站点绑定

## 监控建议

### 监控所有子域名
建议在 `monitor.py` 中添加对主要子域名的监控：

```python
urls_to_check = [
    "https://www.qsgl.net",
    "https://a.qsgl.net",
    "https://api.qsgl.net",
]
```

### 日志分析
查看哪些子域名被访问：
```bash
sudo docker logs envoy-proxy | grep "path=\"/\"" | awk '{print $7}' | sort | uniq -c
```

## 性能考虑

泛域名配置不会影响性能：
- ✅ 域名匹配在内存中进行，速度极快
- ✅ 支持成千上万的子域名
- ✅ 不需要为每个子域名单独配置

## 总结

✅ **已完成**:
- Envoy配置已更新为泛域名 `*.qsgl.net`
- 所有5个监听器均支持泛域名
- `a.qsgl.net` 可以正常代理到后端
- Let's Encrypt证书覆盖所有子域名

⚠️ **注意**:
- DNS必须指向 `62.234.212.241` 才能使用代理
- 后端服务器需要配置对应域名的站点才能返回内容
- 返回404不是代理问题，是后端配置问题

📝 **后续步骤**:
1. 在后端服务器上配置需要的子域名站点
2. 或使用通配符绑定让所有子域名共享同一站点
3. 更新DNS记录，将需要代理的子域名指向62.234.212.241
