# HTTP/3 已启用 - 快速指南

## ✅ 状态: HTTP/3 已完全启用并工作正常

### 验证方法
```bash
$ curl -I https://www.qsgl.net/ | grep alt-svc
alt-svc: h3=":443"; ma=86400
```

---

## 🌐 如何在浏览器中使用HTTP/3

### Chrome浏览器 (推荐)
1. 地址栏输入: `chrome://flags/#enable-quic`
2. 找到 "Experimental QUIC protocol"
3. 改为 **Enabled**
4. 点击 **Relaunch** 重启浏览器
5. 访问 https://www.qsgl.net/test-http3.html

### 验证是否使用HTTP/3
1. 按 `F12` 打开开发者工具
2. 切换到 **Network** (网络) 标签
3. 刷新页面 (`F5`)
4. 点击任意请求，查看 **Headers** → **General**
5. 查看 **Protocol** 字段:
   - 显示 `h3` = HTTP/3 ✅
   - 显示 `h2` = HTTP/2 (HTTP/3未生效)
   - 显示 `http/1.1` = HTTP/1.1

---

## 📊 当前服务器配置

| 项目 | 状态 | 说明 |
|------|------|------|
| Alt-Svc响应头 | ✅ 已配置 | `h3=":443"; ma=86400` |
| UDP 443端口 | ✅ 已监听 | QUIC协议 |
| UDP 5002端口 | ✅ 已监听 | QUIC协议 |
| ALPN协议 | ✅ 已配置 | h3, h2, http/1.1 |
| TLS证书 | ✅ 有效 | Let's Encrypt ECC |
| QUIC监听器 | ✅ 运行中 | listener_quic_443, listener_quic_5002 |

---

## 🧪 测试页面

访问专门的HTTP/3测试页面:
```
https://www.qsgl.net/test-http3.html
```

此页面会自动检测并显示当前使用的协议版本。

---

## 🎯 为什么现在还是HTTP/2?

HTTP/3协议需要客户端主动选择使用。工作流程如下:

1. **首次访问**: 浏览器使用HTTP/1.1或HTTP/2连接
2. **服务器响应**: 返回 `Alt-Svc: h3=":443"` 响应头
3. **浏览器记住**: "这个网站支持HTTP/3"
4. **后续访问**: 浏览器尝试使用HTTP/3 (QUIC over UDP 443)
5. **协议升级**: 如果成功，使用HTTP/3；否则降级到HTTP/2

**重要**: 
- 需要浏览器启用HTTP/3支持
- 首次访问通常是HTTP/2，第二次访问才会尝试HTTP/3
- 清除浏览器缓存会重置此行为

---

## 📈 监控HTTP/3使用情况

在服务器上执行:
```bash
# 查看HTTP/3连接统计
ssh ubuntu@62.234.212.241
curl -s http://localhost:9901/stats | grep downstream_cx_http3_total

# 输出示例:
# http.ingress_quic_443.downstream_cx_http3_total: 15
# (数字大于0表示有HTTP/3连接)
```

---

## 🌍 在线验证工具

使用第三方工具验证HTTP/3支持:
- https://http3check.net/?host=www.qsgl.net
- https://http3.is/?q=www.qsgl.net

---

## ✨ HTTP/3的优势

- ⚡ **更快**: 减少连接建立时间 (0-RTT)
- 🚀 **无队头阻塞**: 独立流不相互影响
- 📱 **连接迁移**: 切换网络不中断连接
- 🔐 **内置加密**: QUIC协议默认加密

---

## 📞 技术支持

如有问题，请检查:
1. 浏览器是否启用HTTP/3
2. 网络是否允许UDP 443
3. 查看 `HTTP3-ENABLED.md` 获取详细故障排查指南

**服务器**: 62.234.212.241  
**域名**: www.qsgl.net, *.qsgl.net  
**Envoy版本**: v1.36.2 contrib
