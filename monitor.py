#!/usr/bin/env python3
"""
Envoy 服务监控和告警脚本
功能：每 5 分钟检查服务状态，异常时发送邮件告警
收件人：qsoft@139.com
"""

import time
import smtplib
import subprocess
import requests
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime
import logging
from pathlib import Path

# 配置
SMTP_SERVER = "smtp.139.com"
SMTP_PORT = 465  # SSL 端口
SMTP_USER = "qsoft@139.com"
SMTP_PASSWORD = "574a283d502db51ea200"  # SMTP 授权码
ALERT_EMAIL = "qsoft@139.com"

CHECK_INTERVAL = 300  # 5 分钟 = 300 秒
CONTAINER_NAME = "envoy-proxy"
ADMIN_URL = "http://localhost:9901"
PUBLIC_ENDPOINT = "https://www.qsgl.net"
BACKEND_HOST = "61.163.200.245"
BACKEND_DOMAIN = "www.qsgl.net"
REQUEST_TIMEOUT = 10

# 日志配置
LOG_DIR = Path("./logs")
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / 'monitor.log'),
        logging.StreamHandler()
    ]
)

# 自签名证书阶段禁用 urllib3 警告，待替换为受信证书后可移除
requests.packages.urllib3.disable_warnings()  # type: ignore[attr-defined]

class EnvoyMonitor:
    def __init__(self):
        self.last_alert_time = {}
        self.alert_cooldown = 1800  # 30分钟内不重复发送相同告警
        
    def check_container_status(self):
        """检查容器状态"""
        try:
            result = subprocess.run(
                ['docker', 'inspect', '-f', '{{.State.Status}}', CONTAINER_NAME],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                return False, "容器不存在或无法访问"
            
            status = result.stdout.strip()
            if status != "running":
                return False, f"容器状态异常: {status}"
            
            # 检查健康状态
            health_result = subprocess.run(
                ['docker', 'inspect', '-f', '{{.State.Health.Status}}', CONTAINER_NAME],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if health_result.returncode == 0:
                health = health_result.stdout.strip()
                if health == "unhealthy":
                    return False, f"容器健康检查失败: {health}"
            
            return True, "容器运行正常"
            
        except Exception as e:
            return False, f"检查容器状态时出错: {str(e)}"
    
    def check_admin_api(self):
        """检查 Envoy Admin API"""
        try:
            response = requests.get(f"{ADMIN_URL}/ready", timeout=5)
            if response.status_code == 200:
                return True, "Admin API 响应正常"
            else:
                return False, f"Admin API 响应异常: {response.status_code}"
        except requests.exceptions.RequestException as e:
            return False, f"无法访问 Admin API: {str(e)}"
    
    def check_ports(self):
        """检查端口监听"""
        try:
            result = subprocess.run(
                ['docker', 'exec', CONTAINER_NAME, 'ss', '-tlnp'],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode != 0:
                return False, "无法检查端口状态"
            
            output = result.stdout
            required_ports = ['443', '5002', '9901']
            
            for port in required_ports:
                if f":{port}" not in output:
                    return False, f"端口 {port} 未监听"
            
            return True, "所有端口监听正常"
            
        except Exception as e:
            return False, f"检查端口时出错: {str(e)}"
    
    def check_backend_connectivity(self):
        """检查后端与域名绑定的 HTTPS 连接"""
        backend_ports = [443, 5002]
        statuses = []

        for port in backend_ports:
            url = f"https://{BACKEND_HOST}:{port}"
            try:
                response = requests.get(
                    url,
                    headers={"Host": BACKEND_DOMAIN},
                    timeout=REQUEST_TIMEOUT,
                    verify=False
                )

                status_code = response.status_code
                statuses.append(f"{port}->{status_code}")

                if status_code >= 500:
                    return False, f"后端返回状态异常 ({url} Host={BACKEND_DOMAIN} 状态 {status_code})"

            except requests.exceptions.RequestException as e:
                return False, f"访问后端失败 ({url} Host={BACKEND_DOMAIN}): {str(e)}"
            except Exception as e:
                return False, f"检查后端连接时出错: {str(e)}"

        return True, "后端响应正常: " + ", ".join(statuses)

    def check_public_endpoint(self):
        """检查公网域名 https://www.qsgl.net"""
        try:
            response = requests.get(
                PUBLIC_ENDPOINT,
                timeout=REQUEST_TIMEOUT,
                verify=False
            )

            status_code = response.status_code
            if status_code >= 500:
                return False, f"公网域名返回状态异常 ({PUBLIC_ENDPOINT} 状态 {status_code})"

            return True, f"公网域名响应 {status_code}"

        except requests.exceptions.RequestException as e:
            return False, f"无法访问公网域名 {PUBLIC_ENDPOINT}: {str(e)}"
        except Exception as e:
            return False, f"检查公网域名时出错: {str(e)}"
    
    def send_alert_email(self, subject, body):
        """发送告警邮件"""
        # 检查告警冷却时间
        alert_key = f"{subject}"
        current_time = time.time()
        
        if alert_key in self.last_alert_time:
            if current_time - self.last_alert_time[alert_key] < self.alert_cooldown:
                logging.info(f"告警 '{subject}' 在冷却期内，跳过发送")
                return
        
        try:
            msg = MIMEMultipart()
            msg['From'] = SMTP_USER
            msg['To'] = ALERT_EMAIL
            msg['Subject'] = f"[Envoy监控告警] {subject}"
            
            body_text = f"""
时间：{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
服务器：62.234.212.241
容器：{CONTAINER_NAME}

告警详情：
{body}

---
此邮件由 Envoy 监控系统自动发送
            """
            
            msg.attach(MIMEText(body_text, 'plain', 'utf-8'))
            
            # 使用 SSL 连接
            with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, timeout=30) as server:
                server.login(SMTP_USER, SMTP_PASSWORD)
                server.send_message(msg)
            
            logging.info(f"告警邮件已发送: {subject}")
            self.last_alert_time[alert_key] = current_time
            
        except Exception as e:
            logging.error(f"发送告警邮件失败: {e}")
    
    def run_checks(self):
        """执行所有检查"""
        logging.info("开始执行监控检查...")
        
        checks = [
            ("容器状态", self.check_container_status),
            ("Admin API", self.check_admin_api),
            ("端口监听", self.check_ports),
            ("后端连接", self.check_backend_connectivity),
            ("公网域名", self.check_public_endpoint),
        ]
        
        all_passed = True
        failed_checks = []
        
        for check_name, check_func in checks:
            try:
                passed, message = check_func()
                if passed:
                    logging.info(f"✓ {check_name}: {message}")
                else:
                    logging.warning(f"✗ {check_name}: {message}")
                    all_passed = False
                    failed_checks.append(f"{check_name}: {message}")
            except Exception as e:
                logging.error(f"✗ {check_name}: 检查时发生异常: {e}")
                all_passed = False
                failed_checks.append(f"{check_name}: 检查异常 - {str(e)}")
        
        # 如果有检查失败，发送告警
        if not all_passed:
            alert_body = "\n".join(failed_checks)
            self.send_alert_email("Envoy 服务异常", alert_body)
        else:
            logging.info("所有检查通过 ✓")
    
    def start(self):
        """启动监控"""
        logging.info("Envoy 监控服务启动")
        logging.info(f"检查间隔: {CHECK_INTERVAL} 秒")
        logging.info(f"告警邮箱: {ALERT_EMAIL}")
        
        while True:
            try:
                self.run_checks()
            except Exception as e:
                logging.error(f"监控检查发生未预期的错误: {e}")
            
            logging.info(f"等待 {CHECK_INTERVAL} 秒后进行下一次检查...")
            time.sleep(CHECK_INTERVAL)

def main():
    monitor = EnvoyMonitor()
    try:
        monitor.start()
    except KeyboardInterrupt:
        logging.info("监控服务已停止")
    except Exception as e:
        logging.error(f"监控服务异常退出: {e}")
        raise

if __name__ == "__main__":
    main()
