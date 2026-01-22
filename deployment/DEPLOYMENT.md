# SmartPen 部署文档

## 环境要求

### 生产环境
- **服务器**: Ubuntu 22.04 LTS / CentOS 8+
- **CPU**: 4 核心以上
- **内存**: 8GB 以上
- **存储**: 100GB 以上 SSD
- **GPU**: NVIDIA GPU (可选，用于 InkSight 加速)

### 软件依赖
- Docker 24.0+
- Docker Compose 2.20+
- Nginx 1.24+
- PostgreSQL 15+
- Redis 7+

## 快速部署

### 1. 克隆代码

```bash
git clone https://github.com/your-org/SmartPen.git
cd SmartPen
```

### 2. 配置环境变量

创建 `.env` 文件：

```bash
# 数据库配置
POSTGRES_USER=smartpen
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=smartpen

# Redis 配置
REDIS_PASSWORD=your_redis_password_here

# HuggingFace Token（用于下载 InkSight 模型）
HUGGINGFACE_TOKEN=your_huggingface_token_here

# 日志级别
LOG_LEVEL=INFO

# 域名配置
DOMAIN=api.smartpen.example.com
```

### 3. 启动服务

```bash
# 启动所有服务
docker-compose -f deployment/docker-compose.yml up -d

# 查看服务状态
docker-compose -f deployment/docker-compose.yml ps

# 查看日志
docker-compose -f deployment/docker-compose.yml logs -f backend
```

### 4. 初始化数据库

```bash
# 运行数据库迁移
docker-compose -f deployment/docker-compose.yml exec backend \
    alembic upgrade head

# 创建初始数据
docker-compose -f deployment/docker-compose.yml exec backend \
    python -m app.scripts.init_data
```

### 5. 验证部署

```bash
# 检查健康状态
curl https://api.smartpen.example.com/health

# 查看 API 文档
open https://api.smartpen.example.com/docs
```

## SSL 证书配置

### 使用 Let's Encrypt

```bash
# 安装 certbot
sudo apt-get install certbot

# 生成证书
sudo certbot certonly --standalone \
    -d api.smartpen.example.com

# 复制证书到项目目录
sudo cp /etc/letsencrypt/live/api.smartpen.example.com/fullchain.pem \
    deployment/ssl/fullchain.pem
sudo cp /etc/letsencrypt/live/api.smartpen.example.com/privkey.pem \
    deployment/ssl/privkey.pem

# 设置权限
sudo chmod 644 deployment/ssl/*.pem
```

## 监控配置

### 日志管理

```bash
# 查看实时日志
docker-compose -f deployment/docker-compose.yml logs -f

# 查看特定服务日志
docker-compose -f deployment/docker-compose.yml logs -f backend

# 导出日志
docker-compose -f deployment/docker-compose.yml logs > logs.txt
```

### 性能监控

使用 Prometheus + Grafana 监控：

```yaml
# docker-compose.monitoring.yml
services:
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3000:3000"
```

## 备份与恢复

### 数据库备份

```bash
# 备份
docker-compose -f deployment/docker-compose.yml exec postgres \
    pg_dump -U smartpen smartpen > backup_$(date +%Y%m%d).sql

# 恢复
docker-compose -f deployment/docker-compose.yml exec -T postgres \
    psql -U smartpen smartpen < backup_20240101.sql
```

### 模型缓存备份

```bash
# 备份模型缓存
docker run --rm -v smartpen_model_cache:/data -v $(pwd):/backup \
    alpine tar czf /backup/model_cache_$(date +%Y%m%d).tar.gz -C /data .
```

## 扩展部署

### 水平扩展

```yaml
# docker-compose.scale.yml
services:
  backend:
    deploy:
      replicas: 3
    environment:
      - WORKERS=4
```

### 负载均衡

更新 `nginx.conf`：

```nginx
upstream backend {
    least_conn;
    server backend1:8000;
    server backend2:8000;
    server backend3:8000;
}
```

## 故障排查

### 常见问题

1. **服务启动失败**
   ```bash
   # 查看详细日志
   docker-compose -f deployment/docker-compose.yml logs backend

   # 检查端口占用
   netstat -tunlp | grep 8000
   ```

2. **数据库连接失败**
   ```bash
   # 检查数据库状态
   docker-compose -f deployment/docker-compose.yml exec postgres \
       psql -U smartpen -c "SELECT 1"
   ```

3. **模型加载失败**
   ```bash
   # 检查模型缓存
   docker-compose -f deployment/docker-compose.yml exec backend \
       ls -lh /root/.cache/huggingface
   ```

## 安全建议

1. **定期更新依赖**
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

2. **启用防火墙**
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

3. **限制 API 访问**
   - 使用 API 密钥
   - 配置 IP 白名单
   - 启用速率限制

4. **定期备份**
   - 设置自动备份任务
   - 备份存储到异地
