# Envoy 证书测试脚本 - 本地验证
# 用于在部署后验证证书和服务器配置

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Envoy 代理服务器测试工具" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

$server = "62.234.212.241"
$domain = "www.qsgl.net"
$ports = @(443, 99, 5002)

# 测试 1: DNS 解析
Write-Host "[测试 1] DNS 解析检查" -ForegroundColor Yellow
Write-Host "解析域名: $domain" -ForegroundColor Gray
try {
    $dnsResult = Resolve-DnsName -Name $domain -ErrorAction Stop
    Write-Host "✓ DNS 解析成功: $($dnsResult.IPAddress -join ', ')" -ForegroundColor Green
} catch {
    Write-Host "✗ DNS 解析失败或未配置" -ForegroundColor Red
    Write-Host "  提示: 需要配置 $domain 指向 $server" -ForegroundColor Yellow
}
Write-Host ""

# 测试 2: 服务器连通性
Write-Host "[测试 2] 服务器连通性" -ForegroundColor Yellow
Write-Host "测试服务器: $server" -ForegroundColor Gray
$pingResult = Test-Connection -ComputerName $server -Count 2 -Quiet
if ($pingResult) {
    Write-Host "✓ 服务器可达" -ForegroundColor Green
} else {
    Write-Host "✗ 服务器无法访问" -ForegroundColor Red
    exit 1
}
Write-Host ""

# 测试 3: 端口开放检查
Write-Host "[测试 3] 端口开放检查" -ForegroundColor Yellow
foreach ($port in $ports) {
    Write-Host "测试端口: $port" -ForegroundColor Gray
    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $tcpClient.Connect($server, $port)
        $tcpClient.Close()
        Write-Host "✓ 端口 $port 开放" -ForegroundColor Green
    } catch {
        Write-Host "✗ 端口 $port 关闭或无法访问" -ForegroundColor Red
    }
}
Write-Host ""

# 测试 4: HTTPS 连接测试
Write-Host "[测试 4] HTTPS 连接测试" -ForegroundColor Yellow

# 忽略 SSL 证书验证（因为是自签名证书）
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
    $certCallback = @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback
        {
            public static void Ignore()
            {
                if(ServicePointManager.ServerCertificateValidationCallback ==null)
                {
                    ServicePointManager.ServerCertificateValidationCallback += 
                        delegate
                        (
                            Object obj, 
                            X509Certificate certificate, 
                            X509Chain chain, 
                            SslPolicyErrors errors
                        )
                        {
                            return true;
                        };
                }
            }
        }
"@
    Add-Type $certCallback
}
[ServerCertificateValidationCallback]::Ignore()
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

foreach ($port in $ports) {
    Write-Host "测试 https://${server}:${port}/" -ForegroundColor Gray
    try {
        $url = "https://${server}:${port}/"
        $headers = @{
            "Host" = $domain
        }
        $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "✓ 端口 $port - HTTP 状态: $($response.StatusCode)" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode) {
            Write-Host "✓ 端口 $port - HTTP 状态: $statusCode (服务器响应)" -ForegroundColor Green
        } else {
            Write-Host "✗ 端口 $port - 连接失败: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
Write-Host ""

# 测试 5: 证书信息（通过 SSH）
Write-Host "[测试 5] 证书 SAN 验证" -ForegroundColor Yellow
Write-Host "正在连接服务器检查证书..." -ForegroundColor Gray
try {
    $sshKey = "C:\Key\qsgl_key.pem"
    $certCheck = ssh -i $sshKey ubuntu@$server "echo | openssl s_client -connect localhost:443 -servername $domain 2>/dev/null | openssl x509 -text -noout | grep -A2 'Subject Alternative Name'" 2>$null
    
    if ($certCheck -match "DNS:.*qsgl.net") {
        Write-Host "✓ 证书包含 Subject Alternative Name (SAN)" -ForegroundColor Green
        Write-Host "  $certCheck" -ForegroundColor Gray
    } else {
        Write-Host "✗ 证书缺少 SAN 扩展" -ForegroundColor Red
    }
} catch {
    Write-Host "⚠ 无法通过 SSH 检查证书（需要 SSH 密钥）" -ForegroundColor Yellow
}
Write-Host ""

# 测试总结
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  测试总结" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步操作:" -ForegroundColor Yellow
Write-Host "1. 在浏览器中打开: https://$domain" -ForegroundColor White
Write-Host "2. 查看证书详情，确认包含 SAN 扩展" -ForegroundColor White
Write-Host "3. 点击 '高级' → '继续访问' (因为是自签名证书)" -ForegroundColor White
Write-Host ""
Write-Host "参考文档: BROWSER-TEST-GUIDE.md" -ForegroundColor Cyan
Write-Host ""

# 可选：在浏览器中打开
$openBrowser = Read-Host "是否在默认浏览器中打开 https://$domain? (Y/N)"
if ($openBrowser -eq 'Y' -or $openBrowser -eq 'y') {
    Start-Process "https://$domain"
    Write-Host "已在浏览器中打开，请按照提示继续访问" -ForegroundColor Green
}
