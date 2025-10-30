FROM envoyproxy/envoy:v1.31-latest

# 安装必要的工具
USER root
RUN apt-get update && \
    apt-get install -y curl ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 创建证书目录
RUN mkdir -p /etc/envoy/certs

# 复制 Envoy 配置文件
COPY envoy.yaml /etc/envoy/envoy.yaml

# 设置权限
RUN chmod 644 /etc/envoy/envoy.yaml

# 暴露端口
# 443, 5002 for HTTPS (TCP)
# 443, 5002 for HTTP/3 (UDP)
# 9901 for admin interface
EXPOSE 443/tcp 443/udp 5002/tcp 5002/udp 9901/tcp

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:9901/ready || exit 1

# 启动 Envoy
CMD ["/usr/local/bin/envoy", "-c", "/etc/envoy/envoy.yaml"]
