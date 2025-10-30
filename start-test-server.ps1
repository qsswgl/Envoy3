# 启动本地 HTTP 服务器以避免 CORS 问题
# 用法: .\start-test-server.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  启动 gRPC-WEB 测试服务器" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$port = 8080
$url = "http://localhost:$port/test-grpc-web.html"

Write-Host "正在启动 HTTP 服务器..." -ForegroundColor Yellow
Write-Host "端口: $port" -ForegroundColor Green
Write-Host "URL: $url" -ForegroundColor Green
Write-Host ""
Write-Host "按 Ctrl+C 停止服务器" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 启动 Python 内置的 HTTP 服务器
if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Host "使用 Python HTTP 服务器..." -ForegroundColor Green
    Start-Process -FilePath "python" -ArgumentList "-m", "http.server", $port -WorkingDirectory "K:\Envoy3"
    Start-Sleep -Seconds 2
    Start-Process msedge $url
    Write-Host "浏览器已打开: $url" -ForegroundColor Green
    Write-Host ""
    Write-Host "服务器正在运行，按任意键停止..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Stop-Process -Name python -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Python 未安装，使用 .NET HTTP 服务器..." -ForegroundColor Yellow
    
    # 使用 PowerShell 内置的 HTTP 服务器
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    
    Write-Host "服务器已启动，正在打开浏览器..." -ForegroundColor Green
    Start-Process msedge $url
    
    Write-Host "等待请求...按 Ctrl+C 停止" -ForegroundColor Yellow
    
    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            
            Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] $($request.HttpMethod) $($request.Url.AbsolutePath)" -ForegroundColor Cyan
            
            $filePath = Join-Path "K:\Envoy3" $request.Url.AbsolutePath.TrimStart('/')
            
            if (Test-Path $filePath) {
                $content = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentType = if ($filePath -match '\.html$') { "text/html; charset=utf-8" } else { "text/plain" }
                $response.ContentLength64 = $content.Length
                $response.OutputStream.Write($content, 0, $content.Length)
            } else {
                $response.StatusCode = 404
                $buffer = [System.Text.Encoding]::UTF8.GetBytes("File not found")
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            
            $response.Close()
        }
    } finally {
        $listener.Stop()
        Write-Host "服务器已停止" -ForegroundColor Red
    }
}
