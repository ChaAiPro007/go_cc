# ttyd 完全指南

ttyd 是一个简单的命令行工具，用于通过 Web 共享终端。它将你的终端转换为可以通过浏览器访问的 Web 应用。

## 目录

- [什么是 ttyd](#什么是-ttyd)
- [安装指南](#安装指南)
  - [Ubuntu/Debian](#ubuntudebian)
  - [CentOS/RHEL/Fedora](#centosrhelfedora)
  - [macOS](#macos)
  - [Windows](#windows)
  - [Docker](#docker)
  - [源码编译](#源码编译)
- [基本使用](#基本使用)
- [高级配置](#高级配置)
- [安全建议](#安全建议)
- [常见问题](#常见问题)

## 什么是 ttyd

ttyd 是一个基于 libwebsockets 的工具，它可以：
- 将任何命令行程序共享到 Web
- 支持多个客户端同时连接
- 提供类似 SSH 的终端体验
- 支持文件传输
- 跨平台运行

## 安装指南

### Ubuntu/Debian

#### 方法1：使用 APT（推荐）
```bash
# Ubuntu 20.04+ / Debian 11+
sudo apt update
sudo apt install ttyd

# 验证安装
ttyd --version
```

#### 方法2：使用预编译包
```bash
# 下载最新版本（以 1.7.4 为例）
wget https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64
chmod +x ttyd.x86_64
sudo mv ttyd.x86_64 /usr/local/bin/ttyd

# 验证安装
ttyd --version
```

#### 方法3：使用 Snap
```bash
sudo snap install ttyd --classic
```

### CentOS/RHEL/Fedora

#### 方法1：使用 YUM/DNF
```bash
# Fedora
sudo dnf install ttyd

# CentOS 8+ / RHEL 8+
sudo dnf install epel-release
sudo dnf install ttyd

# CentOS 7 / RHEL 7
sudo yum install epel-release
sudo yum install ttyd
```

#### 方法2：使用预编译包
```bash
# 下载最新版本
wget https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.x86_64
chmod +x ttyd.x86_64
sudo mv ttyd.x86_64 /usr/local/bin/ttyd

# 安装依赖
sudo yum install libwebsockets json-c zlib openssl
```

### macOS

#### 方法1：使用 Homebrew（推荐）
```bash
# 安装 Homebrew（如果未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装 ttyd
brew install ttyd

# 验证安装
ttyd --version
```

#### 方法2：使用 MacPorts
```bash
sudo port install ttyd
```

#### 方法3：下载预编译包
```bash
# Intel Mac
wget https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.darwin.x86_64
chmod +x ttyd.darwin.x86_64
sudo mv ttyd.darwin.x86_64 /usr/local/bin/ttyd

# Apple Silicon (M1/M2)
wget https://github.com/tsl0922/ttyd/releases/download/1.7.4/ttyd.darwin.arm64
chmod +x ttyd.darwin.arm64
sudo mv ttyd.darwin.arm64 /usr/local/bin/ttyd
```

### Windows

#### 方法1：使用 Scoop
```powershell
# 安装 Scoop（如果未安装）
irm get.scoop.sh | iex

# 安装 ttyd
scoop install ttyd
```

#### 方法2：使用 WSL
```bash
# 在 WSL 中按照 Ubuntu 的方法安装
sudo apt update
sudo apt install ttyd
```

#### 方法3：下载 Windows 二进制文件
1. 访问 https://github.com/tsl0922/ttyd/releases
2. 下载 `ttyd.win32.exe`
3. 重命名为 `ttyd.exe`
4. 添加到系统 PATH

### Docker

#### 使用官方镜像
```bash
# 基本运行
docker run -it --rm -p 7681:7681 tsl0922/ttyd

# 运行 bash
docker run -it --rm -p 7681:7681 tsl0922/ttyd bash

# 挂载本地目录
docker run -it --rm -p 7681:7681 -v $(pwd):/workspace tsl0922/ttyd bash
```

#### Dockerfile 示例
```dockerfile
FROM ubuntu:22.04
RUN apt-get update && \
    apt-get install -y ttyd && \
    apt-get clean
EXPOSE 7681
CMD ["ttyd", "bash"]
```

### 源码编译

适用于所有系统，需要时间较长：

```bash
# 安装依赖
# Ubuntu/Debian
sudo apt-get install build-essential cmake git
sudo apt-get install libjson-c-dev libwebsockets-dev

# CentOS/RHEL
sudo yum groupinstall "Development Tools"
sudo yum install cmake git json-c-devel libwebsockets-devel

# macOS
brew install cmake json-c libwebsockets

# 克隆源码
git clone https://github.com/tsl0922/ttyd.git
cd ttyd

# 编译
mkdir build && cd build
cmake ..
make

# 安装
sudo make install

# 验证
ttyd --version
```

## 基本使用

### 启动命令

```bash
# 基本启动（默认端口 7681）
ttyd bash

# 指定端口
ttyd -p 8080 bash

# 指定监听地址
ttyd -i 0.0.0.0 -p 8080 bash

# 运行特定命令
ttyd top
ttyd htop
ttyd vim /etc/hosts
ttyd python3
```

### 常用参数

```bash
# 端口和地址
-p, --port <port>          端口号（默认：7681）
-i, --interface <iface>    监听地址（默认：lo）

# 认证
-c, --credential USER:PASS  基本认证
-H, --auth-header <header>  认证头名称

# SSL/TLS
-S, --ssl                  启用 SSL
-C, --ssl-cert <cert>      SSL 证书文件
-K, --ssl-key <key>        SSL 密钥文件

# 功能选项
-r, --readonly             只读模式
-t, --client-option <opt>  客户端选项
-T, --terminal-type <type> 终端类型（默认：xterm-256color）
-O, --check-origin         检查请求来源

# 其他
-d, --debug <level>        调试级别
-v, --version              显示版本
-h, --help                 显示帮助
```

### 实际例子

```bash
# 1. 基本 Web 终端
ttyd -p 8080 bash

# 2. 带认证的终端
ttyd -p 8080 -c admin:secretpass bash

# 3. 只读模式（用于监控）
ttyd -p 8080 -r htop

# 4. SSL 加密
ttyd -p 8443 -S -C cert.pem -K key.pem bash

# 5. 允许所有 IP 访问
ttyd -i 0.0.0.0 -p 8080 bash

# 6. 自定义终端选项
ttyd -p 8080 -t fontSize=18 -t fontFamily="Monaco" bash

# 7. 运行 Docker
ttyd -p 8080 docker run -it ubuntu:latest bash

# 8. SSH 跳板
ttyd -p 8080 ssh user@remote-server
```

### tmux 会话映射

ttyd 可以映射现有的 tmux 会话，让你通过 Web 访问特定的 tmux 窗口：

#### 1. 创建 tmux 会话
```bash
# 创建新会话
tmux new-session -d -s webterm

# 在会话中运行命令
tmux send-keys -t webterm "htop" C-m

# 创建多个窗口
tmux new-window -t webterm -n logs
tmux send-keys -t webterm:logs "tail -f /var/log/syslog" C-m

tmux new-window -t webterm -n docker
tmux send-keys -t webterm:docker "docker ps -a" C-m
```

#### 2. 使用 ttyd 连接 tmux 会话
```bash
# 连接到默认会话
ttyd -p 8080 tmux attach

# 连接到特定会话
ttyd -p 8080 tmux attach-session -t webterm

# 连接到特定窗口
ttyd -p 8080 tmux attach-session -t webterm:logs

# 只读模式查看
ttyd -p 8080 -r tmux attach-session -t webterm

# 创建新会话（如果不存在）
ttyd -p 8080 tmux new-session -A -s webterm
```

#### 3. 高级 tmux 映射
```bash
# 映射特定面板
ttyd -p 8080 tmux attach-session -t webterm:0.1

# 使用脚本自动创建和连接
cat > /usr/local/bin/ttyd-tmux.sh << 'EOF'
#!/bin/bash
SESSION_NAME="${1:-webterm}"
WINDOW_NAME="${2:-main}"

# 检查会话是否存在
tmux has-session -t $SESSION_NAME 2>/dev/null
if [ $? != 0 ]; then
    # 创建新会话
    tmux new-session -d -s $SESSION_NAME -n $WINDOW_NAME
fi

# 连接到会话
tmux attach-session -t $SESSION_NAME:$WINDOW_NAME
EOF

chmod +x /usr/local/bin/ttyd-tmux.sh
ttyd -p 8080 /usr/local/bin/ttyd-tmux.sh myapp logs
```

#### 4. 持久化 tmux 会话服务
```bash
# 创建 systemd 服务维持 tmux 会话
cat > /etc/systemd/system/tmux-webterm.service << 'EOF'
[Unit]
Description=Tmux session for ttyd
After=network.target

[Service]
Type=forking
User=ttyd
ExecStart=/usr/bin/tmux new-session -d -s webterm
ExecStop=/usr/bin/tmux kill-session -t webterm
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 启动 tmux 会话服务
sudo systemctl enable tmux-webterm
sudo systemctl start tmux-webterm

# 然后用 ttyd 连接
ttyd -p 8080 tmux attach-session -t webterm
```

#### 5. 多用户 tmux 映射
```bash
# 为每个用户创建独立的 tmux 会话
ttyd -p 8081 -c user1:pass1 sh -c 'tmux new-session -A -s user1'
ttyd -p 8082 -c user2:pass2 sh -c 'tmux new-session -A -s user2'

# 或使用单个端口，根据认证用户选择会话
cat > /usr/local/bin/user-tmux.sh << 'EOF'
#!/bin/bash
USER=$(whoami)
tmux new-session -A -s $USER
EOF

chmod +x /usr/local/bin/user-tmux.sh
ttyd -p 8080 -c user1:pass1 /usr/local/bin/user-tmux.sh
```

#### 注意事项
1. tmux 会话必须在 ttyd 启动前创建
2. 使用 `-d` 参数让 tmux 在后台运行
3. 确保 ttyd 运行用户有权限访问 tmux 会话
4. 断开连接不会结束 tmux 会话，可以重新连接

## 高级配置

### 1. 系统服务配置

#### systemd (Ubuntu/Debian/CentOS 8+)

创建服务文件 `/etc/systemd/system/ttyd.service`：

```ini
[Unit]
Description=ttyd Web Terminal
After=network.target

[Service]
Type=simple
User=ttyd
Group=ttyd
WorkingDirectory=/home/ttyd
ExecStart=/usr/local/bin/ttyd -p 7681 -c admin:password123 bash
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动服务：
```bash
# 创建用户
sudo useradd -r -s /bin/bash -m ttyd

# 启动服务
sudo systemctl daemon-reload
sudo systemctl enable ttyd
sudo systemctl start ttyd
sudo systemctl status ttyd
```

#### init.d (旧系统)

创建脚本 `/etc/init.d/ttyd`：

```bash
#!/bin/sh
### BEGIN INIT INFO
# Provides:          ttyd
# Required-Start:    $network $local_fs
# Required-Stop:     $network $local_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: ttyd Web Terminal
### END INIT INFO

DAEMON=/usr/local/bin/ttyd
PIDFILE=/var/run/ttyd.pid
USER=ttyd
ARGS="-p 7681 -c admin:password123 bash"

case "$1" in
  start)
    echo "Starting ttyd..."
    start-stop-daemon --start --background --make-pidfile --pidfile $PIDFILE --chuid $USER --exec $DAEMON -- $ARGS
    ;;
  stop)
    echo "Stopping ttyd..."
    start-stop-daemon --stop --pidfile $PIDFILE
    rm -f $PIDFILE
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  *)
    echo "Usage: $0 {start|stop|restart}"
    exit 1
    ;;
esac
```

### 2. Nginx 反向代理

```nginx
server {
    listen 80;
    server_name terminal.example.com;
    
    # 强制 HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name terminal.example.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:7681;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket 超时设置
        proxy_read_timeout 86400;
    }
}
```

### 3. Apache 反向代理

```apache
<VirtualHost *:443>
    ServerName terminal.example.com
    
    SSLEngine on
    SSLCertificateFile /path/to/cert.pem
    SSLCertificateKeyFile /path/to/key.pem
    
    # 启用必要的模块
    # a2enmod proxy proxy_http proxy_wstunnel
    
    ProxyRequests Off
    ProxyPreserveHost On
    
    # WebSocket
    RewriteEngine On
    RewriteCond %{HTTP:Upgrade} =websocket [NC]
    RewriteRule /(.*)           ws://localhost:7681/$1 [P,L]
    
    # HTTP
    ProxyPass / http://localhost:7681/
    ProxyPassReverse / http://localhost:7681/
</VirtualHost>
```

### 4. 客户端选项配置

```bash
# 字体设置
ttyd -t fontSize=14 -t fontFamily="Cascadia Code" bash

# 主题设置
ttyd -t theme='{"background":"#1e1e1e","foreground":"#ffffff"}' bash

# 光标样式
ttyd -t cursorStyle=underline -t cursorBlink=true bash

# 所有可用选项
ttyd -t fontSize=16 \
     -t fontFamily="JetBrains Mono" \
     -t lineHeight=1.2 \
     -t letterSpacing=0 \
     -t cursorStyle=block \
     -t cursorBlink=false \
     -t bellStyle=none \
     -t scrollback=10000 \
     -t tabStopWidth=4 \
     -t screenReaderMode=false \
     bash
```

## 安全建议

### 1. 基本安全措施

```bash
# 永远不要在生产环境不加认证
ttyd -c username:strong_password bash

# 使用 SSL/TLS
ttyd -S -C cert.pem -K key.pem bash

# 限制监听地址
ttyd -i 127.0.0.1 bash  # 仅本地访问

# 只读模式
ttyd -r top  # 用户无法输入
```

### 2. 生成 SSL 证书

```bash
# 自签名证书（测试用）
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Let's Encrypt（生产用）
sudo apt-get install certbot
sudo certbot certonly --standalone -d terminal.example.com
```

### 3. 防火墙配置

```bash
# UFW (Ubuntu)
sudo ufw allow 7681/tcp
sudo ufw enable

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=7681/tcp
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p tcp --dport 7681 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

### 4. 安全检查清单

- ✅ 始终使用强密码认证
- ✅ 生产环境启用 SSL/TLS
- ✅ 限制访问 IP（防火墙或 -O 选项）
- ✅ 使用非特权用户运行
- ✅ 定期更新 ttyd 版本
- ✅ 监控访问日志
- ✅ 使用反向代理添加额外安全层

## 常见问题

### Q1: 连接被拒绝
```bash
# 检查服务是否运行
ps aux | grep ttyd
netstat -tlnp | grep 7681

# 检查防火墙
sudo ufw status
sudo iptables -L
```

### Q2: WebSocket 连接失败
```bash
# 确保没有代理干扰
unset http_proxy https_proxy

# 检查浏览器控制台错误
# F12 -> Console
```

### Q3: 中文显示乱码
```bash
# 设置正确的 locale
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# 在 ttyd 启动命令中设置
ttyd -T xterm-256color bash
```

### Q4: 性能优化
```bash
# 增加缓冲区
ttyd -t scrollback=50000 bash

# 减少延迟
ttyd -t rendererType=canvas bash
```

### Q5: 多用户隔离
```bash
# 为每个用户创建独立实例
ttyd -p 7681 -c user1:pass1 su - user1
ttyd -p 7682 -c user2:pass2 su - user2
```

### Q6: Docker 中使用
```bash
# 需要特权模式
docker run -it --rm --privileged -p 7681:7681 tsl0922/ttyd

# 或添加必要权限
docker run -it --rm \
  --cap-add=SYS_PTRACE \
  -p 7681:7681 \
  tsl0922/ttyd
```

## 故障排除步骤

1. **检查版本**
   ```bash
   ttyd --version
   ```

2. **测试基本功能**
   ```bash
   ttyd -p 8080 -d 7 echo "Hello World"
   ```

3. **查看调试日志**
   ```bash
   ttyd -d 7 -p 8080 bash
   ```

4. **检查依赖**
   ```bash
   ldd $(which ttyd)
   ```

5. **网络诊断**
   ```bash
   curl -v http://localhost:7681
   ```

## 相关资源

- 官方仓库：https://github.com/tsl0922/ttyd
- 问题反馈：https://github.com/tsl0922/ttyd/issues
- Wiki 文档：https://github.com/tsl0922/ttyd/wiki
- 在线演示：https://ttyd.fly.dev/

---

本指南覆盖了 ttyd 的完整使用流程，从安装到高级配置。根据你的具体需求选择合适的方案。