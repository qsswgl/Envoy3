#!/usr/bin/env python3
"""
证书生成脚本 (Python 版本)
功能：调用 API 生成 *.qsgl.net 泛域名证书
API: https://tx.qsgl.net:5075/api/cert/v2/generate
"""

import requests
import json
import os
import logging
from datetime import datetime
from pathlib import Path

# 配置
API_URL = "https://tx.qsgl.net:5075/api/cert/v2/generate"
CERT_DIR = Path("./certs")
LOG_DIR = Path("./logs")

# 创建目录
CERT_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / 'cert-generation.log'),
        logging.StreamHandler()
    ]
)

def generate_certificate(domain="*.qsgl.net"):
    """调用 API 生成证书"""
    logging.info(f"开始为域名 {domain} 生成证书...")
    
    # 根据实际 API 文档调整请求参数
    payload = {
        "domain": domain,
        "type": "wildcard"
    }
    
    try:
        # 发送请求（禁用 SSL 验证，如需要可根据实际情况调整）
        response = requests.post(
            API_URL,
            json=payload,
            headers={"Content-Type": "application/json"},
            verify=False,  # 如果使用自签名证书
            timeout=30
        )
        
        response.raise_for_status()
        data = response.json()
        
        logging.info(f"API 响应状态: {response.status_code}")
        logging.debug(f"API 响应内容: {json.dumps(data, indent=2)}")
        
        # 解析证书数据（根据实际 API 返回格式调整）
        cert = (
            data.get('pemCert') or 
            data.get('certificate') or 
            data.get('cert') or 
            data.get('data', {}).get('certificate')
        )
        
        key = (
            data.get('pemKey') or 
            data.get('privateKey') or 
            data.get('key') or 
            data.get('data', {}).get('privateKey')
        )
        
        if not cert or not key:
            logging.error("无法从 API 响应中提取证书或私钥")
            logging.error(f"响应内容: {json.dumps(data, indent=2)}")
            return False
        
        # 保存证书文件
        cert_path = CERT_DIR / "cert.pem"
        key_path = CERT_DIR / "key.pem"
        
        cert_path.write_text(cert)
        key_path.write_text(key)
        
        # 设置权限（仅 Unix 系统）
        if os.name != 'nt':
            os.chmod(key_path, 0o600)
            os.chmod(cert_path, 0o644)
        
        logging.info("证书生成成功！")
        logging.info(f"证书位置: {cert_path}")
        logging.info(f"私钥位置: {key_path}")
        
        return True
        
    except requests.exceptions.RequestException as e:
        logging.error(f"API 请求失败: {e}")
        return False
    except json.JSONDecodeError as e:
        logging.error(f"JSON 解析失败: {e}")
        return False
    except Exception as e:
        logging.error(f"未知错误: {e}")
        return False

if __name__ == "__main__":
    # 禁用 SSL 警告（如果使用 verify=False）
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
    
    success = generate_certificate()
    exit(0 if success else 1)
