@echo off
REM Windows 批处理部署脚本

echo ============================================
echo Envoy 容器代理部署脚本 (Windows)
echo ============================================
echo.

REM 设置变量
set SERVER=62.234.212.241
set SSH_KEY=K:\Key\qsgl_ssh\qsgl_key.pem
set REMOTE_DIR=/root/envoy
set LOCAL_DIR=K:\Envoy3

echo [1/3] 修复 SSH 密钥权限...
icacls "%SSH_KEY%" /reset
icacls "%SSH_KEY%" /inheritance:r
icacls "%SSH_KEY%" /grant:r "%USERNAME%:(R)"

echo.
echo [2/3] 在服务器上创建目录...
ssh -i "%SSH_KEY%" -o StrictHostKeyChecking=no root@%SERVER% "mkdir -p %REMOTE_DIR%/certs %REMOTE_DIR%/logs"

if errorlevel 1 (
    echo 错误: 无法连接到服务器
    echo 请手动检查 SSH 密钥和网络连接
    pause
    exit /b 1
)

echo.
echo [3/3] 上传文件到服务器...
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\envoy.yaml" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\Dockerfile" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\docker-compose.yml" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\*.sh" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\*.py" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\*.service" root@%SERVER%:%REMOTE_DIR%/
scp -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_DIR%\*.md" root@%SERVER%:%REMOTE_DIR%/

echo.
echo ============================================
echo 文件上传完成！
echo ============================================
echo.
echo 下一步：手动 SSH 到服务器执行部署
echo.
echo 命令：
echo   ssh -i "%SSH_KEY%" root@%SERVER%
echo   cd /root/envoy
echo   chmod +x *.sh
echo   ./deploy.sh
echo.
pause
