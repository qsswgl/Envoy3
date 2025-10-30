# Envoy 自动部署 PowerShell 脚本
# 适用于 Windows 环境

param(
    [string]$Server = "62.234.212.241",
    [string]$SshKey = "K:\Key\qsgl_ssh\qsgl_key.pem",
    [string]$LocalDir = "K:\Envoy3",
    [string]$RemoteDir = "/root/envoy"
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Envoy 容器代理自动部署脚本" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 修复 SSH 密钥权限
Write-Host "[1/7] 修复 SSH 密钥权限..." -ForegroundColor Yellow
try {
    # 移除继承和现有权限
    $acl = Get-Acl $SshKey
    $acl.SetAccessRuleProtection($true, $false)
    
    # 只添加当前用户的读取权限
    $permission = "$env:USERNAME", "Read", "Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    
    Set-Acl $SshKey $acl
    Write-Host "  ✓ SSH 密钥权限已修复" -ForegroundColor Green
} catch {
    Write-Host "  ✗ 修复权限失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤 2: 测试 SSH 连接
Write-Host ""
Write-Host "[2/7] 测试 SSH 连接..." -ForegroundColor Yellow
$testCmd = "ssh -i `"$SshKey`" -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$Server echo 'Connection OK'"
try {
    $result = Invoke-Expression $testCmd 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ SSH 连接成功" -ForegroundColor Green
    } else {
        Write-Host "  ✗ SSH 连接失败" -ForegroundColor Red
        Write-Host "  错误: $result" -ForegroundColor Red
        Write-Host ""
        Write-Host "请检查:" -ForegroundColor Yellow
        Write-Host "  1. SSH 密钥路径是否正确" -ForegroundColor Yellow
        Write-Host "  2. 服务器 IP 是否可达" -ForegroundColor Yellow
        Write-Host "  3. 密钥是否已添加到服务器" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "  ✗ SSH 连接异常: $_" -ForegroundColor Red
    exit 1
}

# 步骤 3: 在服务器上创建目录
Write-Host ""
Write-Host "[3/7] 在服务器上创建目录..." -ForegroundColor Yellow
$mkdirCmd = "ssh -i `"$SshKey`" root@$Server `"mkdir -p $RemoteDir/certs $RemoteDir/logs`""
Invoke-Expression $mkdirCmd
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 目录创建成功" -ForegroundColor Green
} else {
    Write-Host "  ✗ 目录创建失败" -ForegroundColor Red
    exit 1
}

# 步骤 4: 上传配置文件
Write-Host ""
Write-Host "[4/7] 上传配置文件..." -ForegroundColor Yellow

$files = @(
    "envoy.yaml",
    "Dockerfile",
    "docker-compose.yml",
    "generate-cert.sh",
    "generate-cert.py",
    "diagnose.sh",
    "monitor.py",
    "deploy.sh",
    "envoy-monitor.service",
    "README.md"
)

$uploadSuccess = 0
$uploadFailed = 0

foreach ($file in $files) {
    $localFile = Join-Path $LocalDir $file
    if (Test-Path $localFile) {
        Write-Host "  上传: $file" -NoNewline
        $scpCmd = "scp -i `"$SshKey`" -o StrictHostKeyChecking=no `"$localFile`" root@${Server}:${RemoteDir}/"
        Invoke-Expression $scpCmd 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " ✓" -ForegroundColor Green
            $uploadSuccess++
        } else {
            Write-Host " ✗" -ForegroundColor Red
            $uploadFailed++
        }
    } else {
        Write-Host "  跳过: $file (文件不存在)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  上传统计: 成功 $uploadSuccess, 失败 $uploadFailed" -ForegroundColor Cyan

if ($uploadFailed -gt 0) {
    Write-Host "  警告: 部分文件上传失败" -ForegroundColor Yellow
}

# 步骤 5: 设置脚本执行权限
Write-Host ""
Write-Host "[5/7] 设置脚本执行权限..." -ForegroundColor Yellow
$chmodCmd = "ssh -i `"$SshKey`" root@$Server `"cd $RemoteDir && chmod +x *.sh *.py`""
Invoke-Expression $chmodCmd
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ 权限设置成功" -ForegroundColor Green
} else {
    Write-Host "  ✗ 权限设置失败" -ForegroundColor Red
}

# 步骤 6: 检查服务器环境
Write-Host ""
Write-Host "[6/7] 检查服务器环境..." -ForegroundColor Yellow
$checkCmd = "ssh -i `"$SshKey`" root@$Server `"which docker docker-compose python3`""
$result = Invoke-Expression $checkCmd 2>&1
Write-Host "  Docker 和依赖检查: $result" -ForegroundColor Cyan

# 步骤 7: 显示下一步操作
Write-Host ""
Write-Host "[7/7] 部署准备完成！" -ForegroundColor Green
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "文件已上传到服务器" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步操作:" -ForegroundColor Yellow
Write-Host ""
Write-Host "选项 1: 自动执行部署脚本 (推荐)" -ForegroundColor Cyan
Write-Host "  ssh -i `"$SshKey`" root@$Server `"cd $RemoteDir && ./deploy.sh`"" -ForegroundColor White
Write-Host ""
Write-Host "选项 2: 手动登录服务器" -ForegroundColor Cyan
Write-Host "  ssh -i `"$SshKey`" root@$Server" -ForegroundColor White
Write-Host "  cd $RemoteDir" -ForegroundColor White
Write-Host "  ./deploy.sh" -ForegroundColor White
Write-Host ""

# 询问是否继续自动部署
Write-Host "是否继续在服务器上执行自动部署? (y/n): " -ForegroundColor Yellow -NoNewline
$continue = Read-Host

if ($continue -eq 'y' -or $continue -eq 'Y') {
    Write-Host ""
    Write-Host "开始远程执行部署..." -ForegroundColor Cyan
    Write-Host ""
    
    $deployCmd = "ssh -i `"$SshKey`" root@$Server `"cd $RemoteDir && bash deploy.sh`""
    Invoke-Expression $deployCmd
    
    Write-Host ""
    Write-Host "部署执行完成！" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "请手动登录服务器执行部署" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完成！" -ForegroundColor Green
