# HTTP/3故障排查脚本

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  HTTP/3 故障排查诊断" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 检查1: 验证Alt-Svc响应头
Write-Host "1️⃣  检查服务器Alt-Svc响应头" -ForegroundColor Yellow
$altSvc = curl.exe -I https://www.qsgl.net/ 2>&1 | Select-String "alt-svc"
if ($altSvc) {
    Write-Host "   ✅ " -ForegroundColor Green -NoNewline
    Write-Host $altSvc
} else {
    Write-Host "   ❌ 未找到Alt-Svc响应头" -ForegroundColor Red
    Write-Host "   → 可能原因: 访问到了后端而非Envoy代理" -ForegroundColor Yellow
}

Write-Host ""

# 检查2: 验证server响应头
Write-Host "2️⃣  检查代理服务器标识" -ForegroundColor Yellow
$server = curl.exe -I https://www.qsgl.net/ 2>&1 | Select-String "^server:"
if ($server -match "envoy") {
    Write-Host "   ✅ " -ForegroundColor Green -NoNewline
    Write-Host $server
    Write-Host "   → 正在通过Envoy代理访问" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  " -ForegroundColor Yellow -NoNewline
    Write-Host $server
    Write-Host "   → 可能直接访问到后端IIS，未经过Envoy" -ForegroundColor Yellow
}

Write-Host ""

# 检查3: DNS解析
Write-Host "3️⃣  检查DNS解析" -ForegroundColor Yellow
$dns = Resolve-DnsName www.qsgl.net -Type A 2>&1
$ip = $dns | Where-Object {$_.Type -eq "A"} | Select-Object -First 1 -ExpandProperty IPAddress
Write-Host "   域名: www.qsgl.net" -ForegroundColor White
Write-Host "   解析IP: $ip" -ForegroundColor White
if ($ip -eq "62.234.212.241") {
    Write-Host "   ✅ DNS解析正确（指向Envoy服务器）" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  DNS未指向Envoy服务器 (62.234.212.241)" -ForegroundColor Yellow
    Write-Host "   → 可能直接访问了后端服务器" -ForegroundColor Yellow
}

Write-Host ""

# 检查4: 网络环境
Write-Host "4️⃣  检查网络环境" -ForegroundColor Yellow
$netAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1
Write-Host "   网络接口: $($netAdapter.Name)" -ForegroundColor White
Write-Host "   接口类型: $($netAdapter.InterfaceDescription)" -ForegroundColor White

# 检查是否在企业网络
if ($netAdapter.InterfaceDescription -match "VPN|Virtual|VMware|Hyper-V") {
    Write-Host "   ⚠️  检测到虚拟/VPN网络，可能阻止UDP" -ForegroundColor Yellow
} else {
    Write-Host "   ✅ 物理网络连接" -ForegroundColor Green
}

Write-Host ""

# 检查5: 防火墙状态
Write-Host "5️⃣  检查Windows防火墙" -ForegroundColor Yellow
try {
    $fwProfiles = Get-NetFirewallProfile | Where-Object {$_.Enabled -eq $true}
    if ($fwProfiles) {
        Write-Host "   ⚠️  防火墙已启用: $($fwProfiles.Name -join ', ')" -ForegroundColor Yellow
        Write-Host "   → 可能阻止出站UDP 443" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ 防火墙未启用" -ForegroundColor Green
    }
} catch {
    Write-Host "   ℹ️  无法检查防火墙状态" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  诊断结果分析" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# 判断原因
if ($altSvc) {
    Write-Host "✅ 服务器配置正确，支持HTTP/3" -ForegroundColor Green
    Write-Host ""
    Write-Host "❓ HTTP/3未生效的可能原因:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "原因1: 网络阻止UDP 443端口" -ForegroundColor White
    Write-Host "   → 企业网络/公共WiFi常见问题" -ForegroundColor Gray
    Write-Host "   → 解决: 切换到家庭网络或手机热点测试" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "原因2: Edge浏览器QUIC未真正启用" -ForegroundColor White
    Write-Host "   → 需要完全重启Edge（关闭所有窗口）" -ForegroundColor Gray
    Write-Host "   → 解决: 任务管理器结束所有Edge进程后重开" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "原因3: 首次访问的正常现象" -ForegroundColor White
    Write-Host "   → 第一次访问必然是HTTP/2" -ForegroundColor Gray
    Write-Host "   → 解决: 多刷新几次页面（Ctrl+F5）" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "原因4: Alt-Svc缓存未生效" -ForegroundColor White
    Write-Host "   → 浏览器需要时间缓存服务器支持信息" -ForegroundColor Gray
    Write-Host "   → 解决: 等待30秒后再访问" -ForegroundColor Cyan
} else {
    Write-Host "❌ 未检测到Alt-Svc响应头" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能原因:" -ForegroundColor Yellow
    Write-Host "1. DNS解析到了后端服务器而非Envoy代理" -ForegroundColor White
    Write-Host "2. 本地hosts文件指向错误" -ForegroundColor White
    Write-Host "3. CDN或中间代理移除了Alt-Svc响应头" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  推荐操作" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "🔧 立即尝试:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 完全关闭Edge浏览器" -ForegroundColor White
Write-Host "   → 任务管理器 → 结束所有'Microsoft Edge'进程" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 重新打开Edge并访问" -ForegroundColor White
Write-Host "   → https://www.qsgl.net/" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 按Ctrl+F5强制刷新3-5次" -ForegroundColor White
Write-Host ""
Write-Host "4. 查看edge://net-internals/#quic" -ForegroundColor White
Write-Host "   → 查看是否有活跃的QUIC会话" -ForegroundColor Gray
Write-Host ""

Write-Host "📱 网络测试:" -ForegroundColor Yellow
Write-Host ""
Write-Host "如果上述方法无效，切换网络测试:" -ForegroundColor White
Write-Host "   → 手机热点（移动网络通常不阻止UDP）" -ForegroundColor Gray
Write-Host "   → 家庭网络（比企业网络限制少）" -ForegroundColor Gray
Write-Host ""

Write-Host "🌐 在线验证:" -ForegroundColor Yellow
Write-Host ""
Write-Host "访问在线HTTP/3检测工具:" -ForegroundColor White
Write-Host "   → https://http3check.net/?host=www.qsgl.net" -ForegroundColor Cyan
Write-Host "   → 如果在线工具显示支持，说明是本地网络问题" -ForegroundColor Gray
Write-Host ""
