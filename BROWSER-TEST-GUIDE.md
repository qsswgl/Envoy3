# Chrome/Edge 浏览器测试指南

## 📋 测试前准备

### 确认事项
- ✅ 服务器：62.234.212.241
- ✅ Envoy 版本：1.36.2
- ✅ 证书包含 SAN：DNS:*.qsgl.net, DNS:qsgl.net
- ✅ 所有端口正常运行

## 🧪 测试步骤

### 测试 1：访问主站（端口 443）

1. **打开 Chrome 或 Edge 浏览器**

2. **输入地址：**
   ```
   https://www.qsgl.net
   ```

3. **首次访问会看到证书警告：**
   
   **Chrome 显示：**
   ```
   您的连接不是私密连接
   攻击者可能会试图从 www.qsgl.net 窃取您的信息...
   NET::ERR_CERT_AUTHORITY_INVALID
   ```
   
   **Edge 显示：**
   ```
   你的连接不是专用连接
   攻击者可能正尝试窃取你在 www.qsgl.net 中的信息...
   DLG_FLAGS_SEC_CERT_CN_INVALID
   ```

4. **查看证书详情：**
   - 点击 **"不安全"** 或 **"不是专用连接"**
   - 点击 **"证书无效"**
   - 在弹出窗口中，切换到 **"详细信息"** 标签
   - 找到 **"使用者可选名称"** 或 **"Subject Alternative Name"**
   
   **应该看到：**
   ```
   DNS 名称=*.qsgl.net
   DNS 名称=qsgl.net
   ```
   ✅ **这说明 SAN 配置正确！**

5. **继续访问：**
   - 点击 **"高级"** 或 **"详细信息"**
   - 点击 **"继续访问 www.qsgl.net（不安全）"** 或 **"转到 www.qsgl.net（不安全）"**

6. **验证成功：**
   - 页面应该正常加载
   - 地址栏显示 🔓 或 ⚠️ 图标（因为是自签名证书）
   - 页面内容正常显示

---

### 测试 2：访问备用端口（端口 99）

**输入地址：**
```
https://www.qsgl.net:99
```

重复上述步骤 3-6。

---

### 测试 3：访问 WebSocket/SSE 端口（端口 5002）

**输入地址：**
```
https://www.qsgl.net:5002
```

重复上述步骤 3-6。

---

## 🔍 证书验证详细步骤

### Chrome 中查看证书：

1. **访问** `https://www.qsgl.net`
2. 点击地址栏左侧的 **🔒** 或 **⚠️** 图标
3. 点击 **"连接是安全的"** 或 **"连接不安全"**
4. 点击 **"证书有效"** 或 **"证书（无效）"**
5. 在证书查看器中，点击 **"详细信息"**
6. 查找以下字段：

**应该看到的证书信息：**
```
字段                      值
-------------------------------------------
版本                     V3
序列号                   (随机数字)
签名算法                  sha256WithRSAEncryption
颁发者                    CN=*.qsgl.net
有效期开始                2025年10月28日
有效期结束                2028年10月29日
使用者                    CN=*.qsgl.net
公钥算法                  rsaEncryption (2048 位)

扩展 → 使用者可选名称:
  DNS 名称=*.qsgl.net     ✅ 关键字段
  DNS 名称=qsgl.net       ✅ 关键字段
```

---

### Edge 中查看证书：

1. **访问** `https://www.qsgl.net`
2. 点击地址栏左侧的 **🔒** 或 **⚠️** 图标
3. 点击 **"证书"**
4. 切换到 **"详细信息"** 标签
5. 在列表中找到 **"使用者备用名称"** 或 **"Subject Alternative Name"**
6. 双击该字段，应该看到：

```
DNS 名称=*.qsgl.net
DNS 名称=qsgl.net
```

---

## ✅ 成功标准

### 如果 SAN 配置正确，您会看到：

✅ **在证书详情中找到 "Subject Alternative Name" 字段**
✅ **SAN 包含 `DNS:*.qsgl.net` 和 `DNS:qsgl.net`**
✅ **点击"继续访问"后，页面正常加载**
✅ **没有 NET::ERR_CERT_COMMON_NAME_INVALID 错误**

### 如果 SAN 配置错误，您会看到：

❌ 证书详情中没有 "Subject Alternative Name" 字段
❌ 即使点击"继续访问"，仍然无法加载页面
❌ 错误信息：NET::ERR_CERT_COMMON_NAME_INVALID

---

## 🎯 预期结果

根据服务器验证，当前配置：

| 项目 | 状态 | 说明 |
|------|------|------|
| SAN 扩展 | ✅ 存在 | DNS:*.qsgl.net, DNS:qsgl.net |
| TLS 版本 | ✅ 1.3 | TLS_AES_256_GCM_SHA384 |
| HTTP 协议 | ✅ HTTP/2 | ALPN: h2 |
| 端口 443 | ✅ 正常 | HTTP 200 |
| 端口 99 | ✅ 正常 | HTTP 200 |
| 端口 5002 | ✅ 正常 | HTTP 302 |

**结论：** 证书配置完全符合 Chrome/Edge 要求，浏览器应该可以正常访问！

---

## 🛠️ 如果仍然有问题

### 1. 清除浏览器缓存

**Chrome:**
```
1. 按 Ctrl + Shift + Delete
2. 选择"时间范围" → "全部时间"
3. 勾选"Cookie 及其他网站数据"和"缓存的图片和文件"
4. 点击"清除数据"
5. 重启浏览器
```

**Edge:**
```
1. 按 Ctrl + Shift + Delete
2. 选择"时间范围" → "所有时间"
3. 勾选"Cookie 和其他站点数据"和"缓存的图像和文件"
4. 点击"立即清除"
5. 重启浏览器
```

### 2. 清除 DNS 缓存

**Windows:**
```powershell
ipconfig /flushdns
```

### 3. 强制刷新页面

访问网站后，按：
- **Windows**: `Ctrl + F5`
- **Mac**: `Cmd + Shift + R`

### 4. 使用隐私模式/无痕模式

**Chrome:**
- 按 `Ctrl + Shift + N`

**Edge:**
- 按 `Ctrl + Shift + P`

然后在隐私窗口中访问 `https://www.qsgl.net`

---

## 📸 截图参考

**正确的证书应该显示：**

```
证书查看器
├── 常规
│   ├── 颁发给: *.qsgl.net
│   ├── 颁发者: *.qsgl.net
│   └── 有效期: 2025-10-28 至 2028-10-29
│
└── 详细信息
    ├── 版本: V3
    ├── 序列号: (数字)
    ├── 签名算法: sha256WithRSAEncryption
    ├── 颁发者: CN=*.qsgl.net
    ├── 使用者: CN=*.qsgl.net
    └── 扩展
        └── 使用者可选名称: ⭐ 关键字段
            ├── DNS 名称=*.qsgl.net
            └── DNS 名称=qsgl.net
```

---

## 🚨 常见错误对比

### ❌ 旧证书（没有 SAN）
```
错误代码: NET::ERR_CERT_COMMON_NAME_INVALID
错误信息: "此服务器无法证实它就是 www.qsgl.net"
证书详情: 缺少 "Subject Alternative Name" 字段
```

### ✅ 新证书（有 SAN）
```
警告代码: NET::ERR_CERT_AUTHORITY_INVALID
警告信息: "您的连接不是私密连接"（仅因为是自签名）
证书详情: 包含 "Subject Alternative Name" = DNS:*.qsgl.net
解决方案: 点击"高级" → "继续访问"即可
```

---

## 📞 需要帮助？

如果测试遇到问题，请提供以下信息：

1. **浏览器和版本**
   - 例如：Chrome 120.0.6099.71

2. **错误代码**
   - 例如：NET::ERR_CERT_AUTHORITY_INVALID

3. **证书详情截图**
   - 特别是 "Subject Alternative Name" 字段

4. **访问的完整 URL**
   - 例如：https://www.qsgl.net:443/

---

## ✅ 测试清单

请逐一测试并勾选：

- [ ] Chrome 访问 https://www.qsgl.net - 证书包含 SAN
- [ ] Edge 访问 https://www.qsgl.net - 证书包含 SAN
- [ ] Chrome 访问 https://www.qsgl.net:99
- [ ] Edge 访问 https://www.qsgl.net:99
- [ ] Chrome 访问 https://www.qsgl.net:5002
- [ ] Edge 访问 https://www.qsgl.net:5002
- [ ] 查看证书详情 - 确认有 Subject Alternative Name
- [ ] 清除缓存后重新测试

---

**测试完成后，请告诉我测试结果！** 🎯
