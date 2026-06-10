# MembershipSystem - 部署文档

> 会员管理系统部署与运维指南

---

## 📋 目录

- [环境要求](#环境要求)
- [Docker 部署](#docker-部署)
- [传统部署](#传统部署)
- [Nginx 配置](#nginx-配置)
- [CI/CD 配置](#cicd-配置)
- [监控与日志](#监控与日志)
- [备份与恢复](#备份与恢复)
- [常见问题](#常见问题)

---

## 环境要求

### 最低配置

| 环境 | 要求 | 说明 |
|------|------|------|
| **CPU** | 2 核 | 支持 x86_64 / ARM64 |
| **内存** | 4 GB | JVM + MySQL + 系统开销 |
| **磁盘** | 20 GB | 操作系统 + 应用 + 数据库 |
| **操作系统** | Linux (CentOS 7+ / Ubuntu 20.04+) | 推荐 Linux 服务器 |
| **JDK** | 17+ | Java 运行环境 |
| **MySQL** | 8.0+ | 数据库 |
| **Nginx** | 1.20+ | 反向代理（可选） |
| **Docker** | 24.0+ | 容器化部署（可选） |

### 推荐配置

| 环境 | 配置 |
|------|------|
| **CPU** | 4 核 |
| **内存** | 8 GB |
| **磁盘** | 50 GB SSD |
| **网络** | 100 Mbps |
| **备份** | 每天自动备份，保留 30 天 |
| **监控** | Prometheus + Grafana（可选） |

### 软件版本对应

| 软件 | 推荐版本 | 最低版本 |
|------|---------|---------|
| Java | JDK 17 LTS | JDK 17 |
| Spring Boot | 3.4.5 | 3.2+ |
| MySQL | 8.0 | 8.0 |
| Maven | 3.9+ | 3.6+ |
| Nginx | 1.24+ | 1.20+ |
| Docker | 24.0+ | 20.10+ |
| Docker Compose | 2.20+ | 2.0+ |

---

## Docker 部署

### 项目结构

```
membership-deploy/
├── docker-compose.yml
├── Dockerfile
├── .env                    # 环境变量配置
├── nginx/
│   └── default.conf        # Nginx 配置
├── mysql/
│   └── init.sql            # 数据库初始化脚本
└── logs/                   # 日志目录（自动创建）
```

### 1. Dockerfile

```dockerfile
# 构建阶段
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src ./src
RUN mvn clean package -DskipTests -B

# 运行阶段
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# 设置时区
RUN apk add --no-cache tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && apk del tzdata

# 创建非 root 用户
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

COPY --from=builder /app/target/*.jar app.jar

RUN mkdir -p /app/logs && chown -R appuser:appgroup /app

USER appuser

# JVM 优化参数
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar --spring.profiles.active=${SPRING_PROFILES_ACTIVE:-prod}"]
```

### 2. Docker Compose

```yaml
version: '3.8'

services:
  mysql:
    image: mysql:8.0
    container_name: membership-mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      MYSQL_DATABASE: membership_system
      MYSQL_USER: ${MYSQL_USER}
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
      - ./mysql/init.sql:/docker-entrypoint-initdb.d/init.sql
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --max_connections=200
      - --innodb_buffer_pool_size=1G
      - --slow_query_log=1
      - --long_query_time=2
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: membership-app
    restart: always
    depends_on:
      mysql:
        condition: service_healthy
    environment:
      SPRING_PROFILES_ACTIVE: prod
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/membership_system?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
      SPRING_DATASOURCE_USERNAME: ${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: ${MYSQL_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRATION: ${JWT_EXPIRATION:-86400000}
    ports:
      - "8080:8080"
    volumes:
      - app-logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  nginx:
    image: nginx:1.24-alpine
    container_name: membership-nginx
    restart: always
    depends_on:
      - app
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - nginx-logs:/var/log/nginx

volumes:
  mysql-data:
  app-logs:
  nginx-logs:
```

### 3. 环境变量文件 (.env)

```bash
# 数据库配置
MYSQL_ROOT_PASSWORD=root_password_change_me
MYSQL_USER=membership
MYSQL_PASSWORD=membership_password_change_me

# JWT 配置
JWT_SECRET=your_jwt_secret_key_at_least_256_bits_long_change_me
JWT_EXPIRATION=86400000

# Spring Profile
SPRING_PROFILES_ACTIVE=prod

# JVM 配置
JAVA_OPTS=-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200
```

### 4. 部署运行

```bash
# 1. 创建部署目录
mkdir -p membership-deploy && cd membership-deploy

# 2. 复制项目构建产物
# 确保项目根目录有 Dockerfile、docker-compose.yml、.env 和 nginx/ 目录

# 3. 修改环境变量
vim .env
# 务必修改所有密码和密钥！

# 4. 构建并启动
docker compose build --no-cache
docker compose up -d

# 5. 检查运行状态
docker compose ps
docker compose logs -f app

# 6. 查看应用日志
docker compose logs --tail=100 app

# 7. 停止服务
docker compose down

# 8. 停止并删除数据卷
docker compose down -v
```

### 5. 健康检查

```bash
# 检查应用状态
curl http://localhost:8080/actuator/health

# 检查 API 可用性
curl http://localhost:8080/api/auth/admin/login -X POST \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'

# 检查 MySQL 连接
docker compose exec mysql mysqladmin ping -h localhost -u root -p
```

---

## 传统部署

### 1. 编译构建

```bash
# 克隆项目
git clone https://github.com/yourusername/MembershipSystemJava.git
cd MembershipSystemJava

# 编译（跳过测试）
mvn clean package -DskipTests

# 编译（运行测试）
mvn clean package

# 查看构建产物
ls -la target/*.jar
```

### 2. 配置文件

```yaml
# application-prod.yml
server:
  port: 8080

spring:
  datasource:
    url: jdbc:mysql://localhost:3306/membership_system?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
    username: membership
    password: your_password
    hikari:
      maximum-pool-size: 20
      minimum-idle: 5
      idle-timeout: 300000
      connection-timeout: 20000
      max-lifetime: 1200000

jwt:
  secret: your_jwt_secret_key_at_least_256_bits
  expiration: 86400000

logging:
  level:
    com.membership: INFO
    com.membership.mapper: INFO
  file:
    name: /var/log/membership/app.log
    max-size: 100MB
    max-history: 30
  pattern:
    console: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
    file: "%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n"
```

### 3. 启动脚本

```bash
#!/bin/bash
# start.sh - 生产环境启动脚本

APP_NAME="membership-system"
APP_JAR="/opt/membership/$APP_NAME.jar"
APP_LOG="/var/log/membership"
JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$APP_LOG/heapdump.hprof"
SPRING_PROFILE="prod"

# 创建日志目录
mkdir -p $APP_LOG

# 启动应用
nohup java $JAVA_OPTS \
  -jar $APP_JAR \
  --spring.profiles.active=$SPRING_PROFILE \
  > $APP_LOG/startup.log 2>&1 &

# 保存 PID
echo $! > /var/run/$APP_NAME.pid
echo "$APP_NAME started with PID $(cat /var/run/$APP_NAME.pid)"
```

```bash
#!/bin/bash
# stop.sh - 停止脚本

APP_NAME="membership-system"
PID_FILE="/var/run/$APP_NAME.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p $PID > /dev/null 2>&1; then
        echo "Stopping $APP_NAME (PID: $PID)..."
        kill $PID
        sleep 5
        if ps -p $PID > /dev/null 2>&1; then
            echo "Force stopping $APP_NAME..."
            kill -9 $PID
        fi
        echo "$APP_NAME stopped."
    else
        echo "Process $PID not found."
    fi
    rm -f "$PID_FILE"
else
    echo "PID file not found."
fi
```

```bash
#!/bin/bash
# deploy.sh - 全量部署脚本

set -e

APP_NAME="membership-system"
APP_DIR="/opt/membership"
BACKUP_DIR="/opt/backups"
JAR_NAME="$APP_NAME.jar"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "===== Starting deployment: $TIMESTAMP ====="

# 1. 停止现有应用
echo "1. Stopping application..."
$APP_DIR/stop.sh || true

# 2. 备份当前版本
echo "2. Backing up current version..."
if [ -f "$APP_DIR/$JAR_NAME" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$APP_DIR/$JAR_NAME" "$BACKUP_DIR/${JAR_NAME%.jar}_$TIMESTAMP.jar"
    echo "   Backup created: $BACKUP_DIR/${JAR_NAME%.jar}_$TIMESTAMP.jar"
fi

# 3. 部署新版本
echo "3. Deploying new version..."
cp ./target/$JAR_NAME $APP_DIR/$JAR_NAME

# 4. 备份配置文件
cp $APP_DIR/application-prod.yml "$BACKUP_DIR/application-prod_$TIMESTAMP.yml"

# 5. 启动应用
echo "4. Starting application..."
$APP_DIR/start.sh

# 6. 检查健康状态
echo "5. Checking health..."
sleep 15
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/actuator/health)
if [ "$HEALTH" = "200" ]; then
    echo "✅ Deployment successful! Health check: $HEALTH"
else
    echo "❌ Health check failed: $HEALTH"
    exit 1
fi

echo "===== Deployment completed: $TIMESTAMP ====="
```

### 4. systemd 服务配置

```ini
# /etc/systemd/system/membership.service
[Unit]
Description=Membership System Application
After=network.target mysql.service
Wants=mysql.service

[Service]
Type=simple
User=membership
Group=membership
WorkingDirectory=/opt/membership
Environment="SPRING_PROFILES_ACTIVE=prod"
ExecStart=/usr/bin/java \
  -Xms512m -Xmx1024m \
  -XX:+UseG1GC -XX:MaxGCPauseMillis=200 \
  -XX:+HeapDumpOnOutOfMemoryError \
  -XX:HeapDumpPath=/var/log/membership/heapdump.hprof \
  -jar /opt/membership/membership-system.jar
ExecStop=/bin/kill -15 $MAINPID
SuccessExitStatus=143
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# 启用服务
sudo systemctl daemon-reload
sudo systemctl enable membership
sudo systemctl start membership

# 查看状态
sudo systemctl status membership

# 查看日志
sudo journalctl -u membership -f

# 停止服务
sudo systemctl stop membership
```

---

## Nginx 配置

### 1. HTTP + HTTPS 配置

```nginx
# /etc/nginx/conf.d/membership.conf

upstream membership_backend {
    server 127.0.0.1:8080 max_fails=3 fail_timeout=30s;
    # 如果有多个实例
    # server 127.0.0.1:8081 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# HTTP -> HTTPS 重定向
server {
    listen 80;
    server_name api.example.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS 配置
server {
    listen 443 ssl http2;
    server_name api.example.com;

    # SSL 证书配置
    ssl_certificate     /etc/nginx/ssl/api.example.com.pem;
    ssl_certificate_key /etc/nginx/ssl/api.example.com.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 10m;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # 日志配置
    access_log /var/log/nginx/membership-access.log main;
    error_log  /var/log/nginx/membership-error.log warn;

    # 请求大小限制
    client_max_body_size 10m;

    # API 代理
    location /api/ {
        proxy_pass http://membership_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;

        # CORS 配置
        add_header Access-Control-Allow-Origin "*" always;
        add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS" always;
        add_header Access-Control-Allow-Headers "Authorization, Content-Type, X-Requested-With" always;
        add_header Access-Control-Max-Age 3600 always;

        # OPTIONS 预检请求直接返回
        if ($request_method = 'OPTIONS') {
            return 204;
        }
    }

    # Swagger UI
    location /swagger-ui.html {
        proxy_pass http://membership_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /v3/api-docs {
        proxy_pass http://membership_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 静态资源缓存
    location /static/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 健康检查
    location /actuator/health {
        proxy_pass http://membership_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        access_log off;
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

### 2. Nginx 日志格式

```nginx
# /etc/nginx/nginx.conf
http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';
}
```

### 3. Nginx 性能优化

```nginx
# /etc/nginx/nginx.conf 中优化参数
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 10240;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    server_tokens off;

    # 压缩配置
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 1000;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

---

## CI/CD 配置

### 1. GitHub Actions

```yaml
# .github/workflows/deploy.yml

name: Deploy Membership System

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Run tests
        run: mvn clean test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: target/surefire-reports/

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Build with Maven
        run: mvn clean package -DskipTests

      - name: Build Docker image
        run: |
          docker build -t membership-system:latest .
          docker tag membership-system:latest ${{ secrets.DOCKER_REGISTRY }}/membership-system:${{ github.sha }}

      - name: Push Docker image
        run: |
          docker login -u ${{ secrets.DOCKER_USERNAME }} -p ${{ secrets.DOCKER_PASSWORD }}
          docker push ${{ secrets.DOCKER_REGISTRY }}/membership-system:${{ github.sha }}
          docker tag ${{ secrets.DOCKER_REGISTRY }}/membership-system:${{ github.sha }} ${{ secrets.DOCKER_REGISTRY }}/membership-system:latest
          docker push ${{ secrets.DOCKER_REGISTRY }}/membership-system:latest

      - name: Deploy to production
        run: |
          ssh ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }} "
            cd /opt/membership &&
            docker compose pull app &&
            docker compose up -d app
          "
```

### 2. Docker Compose (CI/CD 版)

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    image: ${DOCKER_REGISTRY}/membership-system:latest
    container_name: membership-app
    restart: always
    environment:
      SPRING_PROFILES_ACTIVE: prod
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/membership_system?useUnicode=true&characterEncoding=utf8mb4&serverTimezone=Asia/Shanghai
      SPRING_DATASOURCE_USERNAME: ${DB_USERNAME}
      SPRING_DATASOURCE_PASSWORD: ${DB_PASSWORD}
      JWT_SECRET: ${JWT_SECRET}
      JWT_EXPIRATION: 86400000
    ports:
      - "8080:8080"
    volumes:
      - app-logs:/app/logs
    healthcheck:
      test: curl -f http://localhost:8080/actuator/health || exit 1
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  app-logs:
```

### 3. Jenkins Pipeline

```groovy
// Jenkinsfile
pipeline {
    agent any

    tools {
        maven 'Maven-3.9'
        jdk 'JDK-17'
    }

    environment {
        DOCKER_REGISTRY = 'your-registry.example.com'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/membership-system:${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                sh 'mvn clean test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker') {
            steps {
                sh 'docker build -t ${DOCKER_IMAGE} .'
            }
        }

        stage('Push Docker') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-hub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh 'docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}'
                    sh 'docker push ${DOCKER_IMAGE}'
                }
            }
        }

        stage('Deploy') {
            steps {
                sshagent(['deploy-key']) {
                    sh """
                        ssh deploy@prod-server "
                            cd /opt/membership &&
                            docker compose pull app &&
                            docker compose up -d app
                        "
                    """
                }
            }
        }
    }

    post {
        failure {
            emailext(
                subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: "Check console output at ${env.BUILD_URL}",
                to: 'team@example.com'
            )
        }
    }
}
```

---

## 监控与日志

### 1. Spring Boot Actuator 配置

```yaml
# application-prod.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when-authorized
      probes:
        enabled: true
  metrics:
    tags:
      application: ${spring.application.name}
```

### 2. Prometheus 配置

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'membership-app'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['localhost:8080']
        labels:
          application: 'membership-system'
          env: 'production'

  - job_name: 'mysql'
    static_configs:
      - targets: ['localhost:9104']  # mysqld_exporter
```

### 3. Grafana 仪表盘（JSON 片段）

```json
{
  "title": "Membership System Dashboard",
  "panels": [
    {
      "title": "JVM Memory Usage",
      "type": "graph",
      "targets": [
        {
          "expr": "jvm_memory_used_bytes{area='heap'}"
        }
      ]
    },
    {
      "title": "API Request Rate",
      "type": "graph",
      "targets": [
        {
          "expr": "rate(http_server_requests_seconds_count[5m])"
        }
      ]
    },
    {
      "title": "API Response Time (P99)",
      "type": "graph",
      "targets": [
        {
          "expr": "histogram_quantile(0.99, rate(http_server_requests_seconds_bucket[5m]))"
        }
      ]
    },
    {
      "title": "Database Connections",
      "type": "gauge",
      "targets": [
        {
          "expr": "hikaricp_connections_active"
        }
      ]
    }
  ]
}
```

### 4. 日志采集（Filebeat）

```yaml
# filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/membership/*.log
    multiline:
      pattern: '^\d{4}-\d{2}-\d{2}'
      negate: true
      match: after
    fields:
      service: membership-system
      env: production

output.elasticsearch:
  hosts: ["localhost:9200"]
  index: "membership-logs-%{+yyyy.MM.dd}"

setup.kibana:
  host: "localhost:5601"
```

---

## 备份与恢复

### 1. 数据库备份脚本

```bash
#!/bin/bash
# backup_db.sh - 数据库备份脚本

BACKUP_DIR="/data/backups/mysql"
DB_NAME="membership_system"
DB_USER="root"
DB_PASS="your_password"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 执行备份
echo "Starting backup: $TIMESTAMP"
mysqldump -u "$DB_USER" -p"$DB_PASS" \
  --single-transaction \
  --routines \
  --triggers \
  --events \
  --databases "$DB_NAME" \
  | gzip > "$BACKUP_DIR/${DB_NAME}_$TIMESTAMP.sql.gz"

# 检查备份是否成功
if [ $? -eq 0 ]; then
    echo "✅ Backup successful: ${DB_NAME}_$TIMESTAMP.sql.gz"
    ls -lh "$BACKUP_DIR/${DB_NAME}_$TIMESTAMP.sql.gz"
else
    echo "❌ Backup failed!"
    exit 1
fi

# 清理过期备份
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "Cleaned up backups older than $RETENTION_DAYS days"
```

### 2. crontab 定时备份

```bash
# 每天凌晨 3 点执行备份
0 3 * * * /opt/scripts/backup_db.sh >> /var/log/cron/backup.log 2>&1

# 每周日执行完整备份
0 3 * * 0 /opt/scripts/backup_db.sh full >> /var/log/cron/backup.log 2>&1
```

### 3. 恢复数据库

```bash
#!/bin/bash
# restore_db.sh - 数据库恢复脚本

BACKUP_FILE=$1
DB_NAME="membership_system"
DB_USER="root"
DB_PASS="your_password"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    echo "Example: $0 /data/backups/mysql/membership_system_20260609_030000.sql.gz"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "Starting restore from: $BACKUP_FILE"
echo "WARNING: This will OVERWRITE the current database!"
read -p "Are you sure? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Restore cancelled."
    exit 0
fi

# 解压并恢复
gunzip < "$BACKUP_FILE" | mysql -u "$DB_USER" -p"$DB_PASS"

if [ $? -eq 0 ]; then
    echo "✅ Restore successful!"
else
    echo "❌ Restore failed!"
    exit 1
fi
```

---

## 常见问题

### 1. 应用无法启动

**问题**：Spring Boot 应用启动失败

**检查步骤**：
```bash
# 1. 检查日志
tail -100 /var/log/membership/app.log

# 2. 检查 MySQL 连接
mysql -h localhost -u membership -p -e "SELECT 1"

# 3. 检查端口冲突
netstat -tlnp | grep 8080

# 4. 检查 JVM 参数
java -version
```

**常见原因**：
- MySQL 连接失败（检查密码、地址）
- 端口被占用（检查 8080 端口）
- JWT Secret 未配置
- 数据库表结构不匹配

### 2. 数据库连接池溢出

**问题**：`HikariPool-1 - Connection is not available, request timed out`

**解决方案**：
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 20       # 适当增加
      minimum-idle: 5
      connection-timeout: 30000   # 增加超时时间
      max-lifetime: 1200000       # 确保小于 MySQL wait_timeout
      idle-timeout: 300000
```

### 3. JWT Token 失效

**问题**：所有请求返回 401 Unauthorized

**检查**：
```bash
# 1. 检查 JWT Secret 配置
grep jwt.secret application-prod.yml

# 2. 检查 Token 是否过期
# 使用 jwt.io 在线解码 Token
```

### 4. 磁盘空间不足

**监控**：
```bash
# 查看磁盘使用
df -h

# 查看日志大小
du -sh /var/log/membership/

# 清理旧日志
find /var/log/membership/ -name "*.log.*" -mtime +7 -delete

# 清理 Docker 日志
docker system prune -f
```

---

**文档版本**：v1.0  
**作者**：黄志鹏  
**日期**：2026-06-09
