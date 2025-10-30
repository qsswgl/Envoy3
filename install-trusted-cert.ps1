param(
    [string]$CertificatePath = "qsgl.net.cer",
    [string]$RemoteHost = "62.234.212.241",
    [string]$RemoteCertPath = "/root/envoy/certs/cert.pem",
    [string]$SshUser = "ubuntu",
    [string]$SshKey = "C:\Key\qsgl_key.pem"
)

Write-Host "=== 下载最新证书 ===" -ForegroundColor Cyan
if (-Not (Test-Path $CertificatePath)) {
    $remote = "{0}@{1}:{2}" -f $SshUser, $RemoteHost, $RemoteCertPath
    & scp -i $SshKey $remote $CertificatePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "证书下载失败，请检查 SSH 配置。"
        exit 1
    }
    Write-Host "证书已下载: $CertificatePath" -ForegroundColor Green
} else {
    Write-Host "本地已存在证书文件: $CertificatePath (如需更新请删除后重试)" -ForegroundColor Yellow
}

Write-Host "=== 导入到本地受信任根证书颁发机构 ===" -ForegroundColor Cyan
try {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $CertificatePath
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
    $store.Open("ReadWrite")
    $existing = $store.Certificates | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
    if ($existing) {
        Write-Host "已存在相同指纹的证书，无需重复导入。" -ForegroundColor Yellow
    } else {
        $store.Add($cert)
        Write-Host "证书导入成功 (指纹: $($cert.Thumbprint))" -ForegroundColor Green
    }
    $store.Close()
}
catch {
    Write-Error "导入证书失败: $_.Exception.Message"
    Write-Host "请使用管理员权限重新运行 PowerShell: Start-Process powershell -Verb runAs" -ForegroundColor Yellow
    exit 1
}

Write-Host "=== 完成 ===" -ForegroundColor Cyan
