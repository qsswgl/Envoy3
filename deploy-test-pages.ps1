# 部署测试页面到后端服务器
# 用法: .\deploy-test-pages.ps1

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  部署 gRPC-WEB 测试页面" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$proxyServer = "62.234.212.241"
$backendServer = "61.163.200.245"
$proxyKey = "C:\Key\qsgl_key.pem"

# 测试页面列表
$testPages = @(
    "test-grpc-web.html",
    "test-grpc-web-verify.html",
    "test-http3.html",
    "edge-http3-guide.html"
)

Write-Host "📦 准备上传的文件:" -ForegroundColor Yellow
foreach ($page in $testPages) {
    if (Test-Path "K:\Envoy3\$page") {
        Write-Host "  ✅ $page" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $page (不存在)" -ForegroundColor Red
    }
}

Write-Host "`n步骤 1: 上传文件到代理服务器..." -ForegroundColor Yellow

foreach ($page in $testPages) {
    if (Test-Path "K:\Envoy3\$page") {
        Write-Host "  上传 $page..."
        scp -i $proxyKey "K:\Envoy3\$page" "ubuntu@${proxyServer}:/tmp/$page"
    }
}

Write-Host "`n步骤 2: 从代理服务器传输到后端服务器..." -ForegroundColor Yellow

# 构建 SSH 命令
$sshCommand = @"
# 检查是否有到后端服务器的密钥
if [ ! -f ~/.ssh/backend_key ]; then
    echo '⚠️  警告: 没有找到后端服务器密钥'
    echo '请手动将文件从 /tmp/ 复制到后端服务器'
    ls -lh /tmp/*.html
    exit 1
fi

# 传输文件到后端 IIS 服务器
echo '传输文件到后端服务器...'
$(foreach ($page in $testPages) { "scp -i ~/.ssh/backend_key /tmp/$page root@${backendServer}:/var/www/html/$page && " })
echo '✅ 文件传输完成'

# 列出后端服务器的文件
echo ''
echo '后端服务器文件列表:'
ssh -i ~/.ssh/backend_key root@${backendServer} 'ls -lh /var/www/html/*.html | tail -10'

# 清理临时文件
rm -f /tmp/*.html
"@

Write-Host "执行远程命令..." -ForegroundColor Yellow
ssh -i $proxyKey "ubuntu@${proxyServer}" $sshCommand

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "🌐 测试页面访问地址:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  gRPC-WEB 功能测试:" -ForegroundColor Cyan
Write-Host "  https://www.qsgl.net/test-grpc-web.html" -ForegroundColor White
Write-Host ""
Write-Host "  gRPC-WEB 验证页面:" -ForegroundColor Cyan
Write-Host "  https://www.qsgl.net/test-grpc-web-verify.html" -ForegroundColor White
Write-Host ""
Write-Host "  HTTP/3 检测页面:" -ForegroundColor Cyan
Write-Host "  https://www.qsgl.net/test-http3.html" -ForegroundColor White
Write-Host ""
Write-Host "  Edge HTTP/3 指南:" -ForegroundColor Cyan
Write-Host "  https://www.qsgl.net/edge-http3-guide.html" -ForegroundColor White
Write-Host ""

Write-Host "✅ 现在可以通过域名访问测试页面了！" -ForegroundColor Green
