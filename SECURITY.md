# 🔒 安全配置指南

## ⚠️ 重要安全警告

默认配置中，ttyd 可能监听在所有网络接口上，这会导致严重的安全风险。任何人都可以通过 `http://your-server:7681-7690` 直接访问终端，绕过认证！

## 🛡️ 安全措施

### 1. 限制 ttyd 监听地址（已实施）

启动脚本已更新，ttyd 现在只监听本地地址：
```bash
ttyd -i 127.0.0.1 -p 7681 bash
```

这确保 ttyd 只能从本机访问，外部无法直接连接。

### 2. 防火墙配置

运行防火墙配置脚本：
```bash
sudo ./secure-firewall.sh
```

或手动配置：

#### UFW (Ubuntu/Debian)
```bash
# 拒绝外部访问 ttyd 端口
sudo ufw deny 7681:7690/tcp

# 只允许 Web 端口
sudo ufw allow 3000/tcp
```

#### iptables
```bash
# 只允许本地访问 ttyd
sudo iptables -A INPUT -p tcp -s 127.0.0.1 --dport 7681:7690 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 7681:7690 -j DROP
```

### 3. 使用 Nginx 反向代理 + SSL

创建 `/etc/nginx/sites-available/web-terminal`:
```nginx
server {
    listen 80;
    server_name terminal.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name terminal.yourdomain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    # 安全头
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 超时
        proxy_read_timeout 86400;
    }
}
```

### 4. 环境变量安全配置

更新 `.env` 文件：
```bash
# 使用强密码
AUTH_USERNAME=your_secure_username
AUTH_PASSWORD=$(openssl rand -base64 32)

# 生成安全的 session 密钥
SESSION_SECRET=$(openssl rand -base64 64)

# 生产环境启用安全 cookie
SECURE_COOKIE=true
ENV=production
```

### 5. 额外安全建议

#### a. 配置 fail2ban
```bash
# /etc/fail2ban/jail.local
[web-terminal]
enabled = true
port = 3000
filter = web-terminal
logpath = /var/log/web-terminal.log
maxretry = 5
bantime = 3600
```

#### b. 限制访问 IP
在 `.env` 添加：
```bash
ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8
```

#### c. 启用审计日志
记录所有终端操作：
```bash
# 在 ttyd 命令中添加
ttyd -i 127.0.0.1 -p 7681 --writable script -f /var/log/terminal-audit.log
```

#### d. 定期安全检查
```bash
# 检查开放端口
sudo netstat -tlnp | grep -E '(7681|7682|3000)'

# 检查 ttyd 监听地址
ps aux | grep ttyd | grep -v grep

# 应该只看到 127.0.0.1，不应该看到 0.0.0.0
```

## 🚨 紧急修复步骤

如果你的服务器已经暴露：

1. **立即停止服务**
   ```bash
   pkill ttyd
   pkill web-terminal
   ```

2. **检查是否被入侵**
   ```bash
   # 检查最近登录
   last -n 50
   
   # 检查异常进程
   ps aux | grep -v "^USER"
   
   # 检查网络连接
   netstat -tulnp
   ```

3. **更改所有密码**
   - 系统用户密码
   - Web 终端密码
   - 数据库密码

4. **应用安全配置**
   - 按照上述步骤配置
   - 重启服务

## 📋 安全检查清单

- [ ] ttyd 只监听 127.0.0.1
- [ ] 防火墙规则已配置
- [ ] 使用强密码
- [ ] Session 密钥已更新
- [ ] 生产环境配置已启用
- [ ] SSL/TLS 已配置（如果公网访问）
- [ ] 访问日志已启用
- [ ] 定期备份配置

## 🔍 测试安全性

```bash
# 从外部测试 ttyd 端口（应该失败）
curl http://your-server-ip:7681

# 测试 Web 端口（应该显示登录页）
curl http://your-server-ip:3000

# 使用 nmap 扫描
nmap -p 7681-7690,3000 your-server-ip
```

记住：安全是持续的过程，定期检查和更新你的配置！