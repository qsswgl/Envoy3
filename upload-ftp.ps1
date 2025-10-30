# FTP 上传测试页面到后端服务器
# 服务器: 61.163.200.245:31
# 账号: test
# 密码: lg_24mp76.

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  FTP 上传测试页面" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$ftpServer = "61.163.200.245"
$ftpPort = 31
$ftpUser = "test"
$ftpPassword = "lg_24mp76."

# 测试页面列表
$testPages = @(
    @{File="test-grpc-web.html"; Remote="/test-grpc-web.html"},
    @{File="test-grpc-web-verify.html"; Remote="/test-grpc-web-verify.html"},
    @{File="test-http3.html"; Remote="/test-http3.html"},
    @{File="edge-http3-guide.html"; Remote="/edge-http3-guide.html"}
)

Write-Host "FTP 服务器信息:" -ForegroundColor Yellow
Write-Host "  地址: $ftpServer`:$ftpPort" -ForegroundColor Gray
Write-Host "  用户: $ftpUser" -ForegroundColor Gray
Write-Host ""

# 上传函数
function Upload-FileToFTP {
    param(
        [string]$LocalFile,
        [string]$RemoteFile,
        [string]$Server,
        [int]$Port,
        [string]$Username,
        [string]$Password
    )
    
    $localPath = "K:\Envoy3\$LocalFile"
    
    if (-not (Test-Path $localPath)) {
        Write-Host "  ❌ 文件不存在: $LocalFile" -ForegroundColor Red
        return $false
    }
    
    try {
        # 构建 FTP URL
        $ftpUrl = "ftp://${Server}:${Port}${RemoteFile}"
        
        Write-Host "  上传: $LocalFile -> $ftpUrl" -ForegroundColor Cyan
        
        # 创建 FTP 请求
        $request = [System.Net.FtpWebRequest]::Create($ftpUrl)
        $request.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
        $request.Credentials = New-Object System.Net.NetworkCredential($Username, $Password)
        $request.UseBinary = $true
        $request.KeepAlive = $false
        
        # 读取文件内容
        $fileContent = [System.IO.File]::ReadAllBytes($localPath)
        $request.ContentLength = $fileContent.Length
        
        # 上传文件
        $requestStream = $request.GetRequestStream()
        $requestStream.Write($fileContent, 0, $fileContent.Length)
        $requestStream.Close()
        
        # 获取响应
        $response = $request.GetResponse()
        $statusDescription = $response.StatusDescription
        $response.Close()
        
        Write-Host "  ✅ $LocalFile 上传成功 ($statusDescription)" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "  ❌ 上传失败: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 上传所有文件
Write-Host "开始上传文件...`n" -ForegroundColor Yellow

$successCount = 0
$failCount = 0

foreach ($page in $testPages) {
    $result = Upload-FileToFTP -LocalFile $page.File -RemoteFile $page.Remote `
                                -Server $ftpServer -Port $ftpPort `
                                -Username $ftpUser -Password $ftpPassword
    if ($result) {
        $successCount++
    } else {
        $failCount++
    }
    Start-Sleep -Milliseconds 500
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  上传完成！" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "统计:" -ForegroundColor Yellow
Write-Host "  ✅ 成功: $successCount 个文件" -ForegroundColor Green
Write-Host "  ❌ 失败: $failCount 个文件" -ForegroundColor Red
Write-Host ""

if ($successCount -gt 0) {
    Write-Host "🌐 测试页面访问地址:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📱 gRPC-WEB 功能测试:" -ForegroundColor Cyan
    Write-Host "  https://www.qsgl.net/test-grpc-web.html" -ForegroundColor White
    Write-Host ""
    Write-Host "  📋 gRPC-WEB 验证页面 (含 curl 命令):" -ForegroundColor Cyan
    Write-Host "  https://www.qsgl.net/test-grpc-web-verify.html" -ForegroundColor White
    Write-Host ""
    Write-Host "  🚀 HTTP/3 检测页面:" -ForegroundColor Cyan
    Write-Host "  https://www.qsgl.net/test-http3.html" -ForegroundColor White
    Write-Host ""
    Write-Host "  📖 Edge HTTP/3 指南:" -ForegroundColor Cyan
    Write-Host "  https://www.qsgl.net/edge-http3-guide.html" -ForegroundColor White
    Write-Host ""
    Write-Host "✅ 现在可以通过域名访问测试页面了！" -ForegroundColor Green
    Write-Host "   测试 gRPC-WEB + CORS + HTTP/3 功能" -ForegroundColor Green
}
