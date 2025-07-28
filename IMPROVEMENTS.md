# 改进建议

## 🔐 紧急修复

### 1. 更新凭据
```bash
# 生成强密码
openssl rand -base64 16

# 编辑 .env
AUTH_USERNAME=your_secure_username
AUTH_PASSWORD=<生成的密码>
SESSION_SECRET=$(openssl rand -base64 64)
```

### 2. 从 Git 移除二进制文件
```bash
git rm --cached web-terminal
git commit -m "Remove binary from repository"
git push
```

## 🚀 功能增强

### 1. 添加登录限制
```go
// 在 main.go 中添加
var loginAttempts = make(map[string]int)
var loginLock = sync.RWMutex{}

func rateLimitLogin(ip string) bool {
    loginLock.Lock()
    defer loginLock.Unlock()
    
    attempts := loginAttempts[ip]
    if attempts >= 5 {
        return false
    }
    loginAttempts[ip]++
    
    // 定时清理
    go func() {
        time.Sleep(15 * time.Minute)
        loginLock.Lock()
        delete(loginAttempts, ip)
        loginLock.Unlock()
    }()
    
    return true
}
```

### 2. 会话超时
```go
// 在认证中间件中添加
if session.Get("last_activity") != nil {
    lastActivity := session.Get("last_activity").(int64)
    if time.Now().Unix() - lastActivity > 1800 { // 30分钟
        session.Clear()
        session.Save()
        c.Redirect(302, "/login")
        c.Abort()
        return
    }
}
session.Set("last_activity", time.Now().Unix())
session.Save()
```

### 3. 审计日志
```go
func auditLog(username, action, ip string) {
    log.Printf("AUDIT: user=%s action=%s ip=%s time=%s",
        username, action, ip, time.Now().Format(time.RFC3339))
}
```

### 4. HTTPS 支持
```go
// 添加 TLS 配置
if config.Environment == "production" {
    r.RunTLS(addr, "cert.pem", "key.pem")
} else {
    r.Run(addr)
}
```

## 📦 部署建议

### 1. 使用 systemd 服务
```ini
[Unit]
Description=Web Terminal Service
After=network.target

[Service]
Type=simple
User=webterm
Group=webterm
WorkingDirectory=/opt/web-terminal
ExecStart=/opt/web-terminal/web-terminal
Restart=always
RestartSec=10
Environment="GIN_MODE=release"

[Install]
WantedBy=multi-user.target
```

### 2. Nginx 配置示例
```nginx
upstream web_terminal {
    server 127.0.0.1:3000;
}

server {
    listen 443 ssl http2;
    server_name terminal.example.com;
    
    ssl_certificate /etc/letsencrypt/live/terminal.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/terminal.example.com/privkey.pem;
    
    # 安全头
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    location / {
        proxy_pass http://web_terminal;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
}
```

### 3. Docker 容器化
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod download
RUN go build -o web-terminal main.go

FROM alpine:latest
RUN apk --no-cache add ca-certificates ttyd
WORKDIR /root/
COPY --from=builder /app/web-terminal .
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/.env.example ./.env
EXPOSE 3000
CMD ["./web-terminal"]
```

## 🔍 监控建议

### 1. 健康检查端点
```go
r.GET("/health", func(c *gin.Context) {
    c.JSON(200, gin.H{
        "status": "ok",
        "uptime": time.Since(startTime).Seconds(),
    })
})
```

### 2. Prometheus 指标
```go
import "github.com/prometheus/client_golang/prometheus"

var (
    loginAttempts = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "web_terminal_login_attempts_total",
            Help: "Total number of login attempts",
        },
        []string{"status"},
    )
)
```

## 📝 文档改进

1. 添加 API 文档
2. 创建用户手册
3. 添加故障排除指南
4. 创建安全最佳实践文档