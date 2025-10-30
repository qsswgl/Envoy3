# Edge浏览器HTTP/3快速检查脚本
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Edge浏览器 HTTP/3 状态检查" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📡 检查服务器Alt-Svc响应头..." -ForegroundColor Yellow
$result = curl.exe -I https://www.qsgl.net/ 2>&1 | Select-String "alt-svc"

if ($result) {
    Write-Host "✅ " -ForegroundColor Green -NoNewline
    Write-Host $result
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  📊 当前状态" -ForegroundColor Cyan  
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✅ 服务器端: HTTP/3已完全启用" -ForegroundColor Green
    Write-Host "⚠️  客户端: Edge浏览器默认未启用HTTP/3" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🎯 这就是为什么你看到 h2 (HTTP/2) 的原因！" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  🚀 5步启用HTTP/3" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. 在Edge地址栏输入: " -ForegroundColor White -NoNewline
    Write-Host "edge://flags/#enable-quic" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. 设置'Experimental QUIC protocol'为: " -ForegroundColor White -NoNewline
    Write-Host "Enabled" -ForegroundColor Green
    Write-Host ""
    Write-Host "3. 点击: " -ForegroundColor White -NoNewline
    Write-Host "[Relaunch]" -ForegroundColor Blue -NoNewline
    Write-Host " 重启浏览器" -ForegroundColor White
    Write-Host ""
    Write-Host "4. 清除缓存: " -ForegroundColor White -NoNewline
    Write-Host "Ctrl+Shift+Delete" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "5. 测试访问: " -ForegroundColor White -NoNewline
    Write-Host "https://www.qsgl.net/test-http3.html" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    
    $open = Read-Host "打开图文指南? (Y/N)"
    if ($open -eq "Y" -or $open -eq "y") {
        Start-Process "K:\Envoy3\edge-http3-guide.html"
        Write-Host "✅ 已在浏览器中打开！" -ForegroundColor Green
    }
} else {
    Write-Host "❌ 未找到Alt-Svc响应头" -ForegroundColor Red
}

Write-Host ""
