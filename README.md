# Web Terminal with Authentication

基于 Gin 框架的 Web 终端认证代理，为 ttyd 提供登录保护。采用环境变量配置，符合12-Factor应用最佳实践。

## 功能特性

- 🔐 用户登录认证
- 🍪 Session 管理
- 🔄 反向代理到 ttyd
- 🎨 简洁的登录界面
- ⚙️ 环境变量配置
- 🚀 一键启动脚本
- 🔧 生产环境就绪

## 快速开始

### 1. 安装 ttyd

```bash
# Ubuntu/Debian
sudo apt-get install ttyd

# macOS
brew install ttyd

# 或从源码编译
git clone https://github.com/tsl0922/ttyd.git
cd ttyd && mkdir build && cd build
cmake ..
make && sudo make install
```

### 2. 配置项目

```bash
# 克隆项目
cd /home/YanYun/go/gin-terminal

# 首次运行会自动从 .env.example 创建 .env 文件
# 编辑 .env 文件设置你的配置
vim .env
```

### 3. 启动服务

```bash
# (可选) 创建示例 tmux 会话
./create-tmux-sessions.sh

# 使用启动脚本（推荐）- 会交互式让你选择终端模式
./start.sh

# 或手动运行（不选择 tmux）
./run.sh
```

## 配置说明

所有配置通过环境变量或 `.env` 文件设置：

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| AUTH_USERNAME | admin | 登录用户名 |
| AUTH_PASSWORD | admin123 | 登录密码 |
| SERVER_PORT | 3000 | Web 服务端口 |
| TTYD_URL | http://localhost:7681 | ttyd 服务地址 |
| TTYD_COMMAND | bash | ttyd 启动命令（支持 tmux） |
| SESSION_SECRET | your-super-secret-key | Session 加密密钥 |
| SESSION_NAME | terminal_session | Session 名称 |
| SECURE_COOKIE | false | 是否启用安全 Cookie (HTTPS) |
| HTTP_ONLY | true | Cookie 仅限 HTTP 访问 |
| ENV | development | 运行环境 (development/production) |

## 使用说明

### 基本使用

1. 访问 http://localhost:3000
2. 使用配置的用户名密码登录
3. 登录成功后将自动跳转到 Web 终端

### 使用 tmux 会话

启动脚本会自动检测并列出所有 tmux 会话，让你选择要映射的终端：

```bash
./start.sh

# 输出示例：
===================================
Select Terminal Mode:
===================================
Available tmux sessions:

1) myapp: 2 windows (created Mon Nov 18 10:30:00 2024)
2) webterm: 1 windows (created Mon Nov 18 09:15:00 2024)
3) Start regular bash shell
4) Create new tmux session

Enter your choice (1-4): 
```

选择 tmux 会话后，如果该会话有多个窗口，还可以选择特定窗口：
```
Windows in session 'myapp':
0: bash
1: logs
Enter window number (or press Enter for current): 
```

#### 手动指定命令

也可以通过环境变量跳过交互式选择：

```bash
# 直接连接到指定会话
export TTYD_COMMAND="tmux attach-session -t myapp"
./start.sh

# 连接到特定窗口
export TTYD_COMMAND="tmux attach-session -t webterm:logs"
./start.sh
```

#### 预创建 tmux 会话

提前创建有意义的 tmux 会话：
```bash
# 创建开发环境会话
tmux new-session -d -s dev
tmux send-keys -t dev "cd /project && npm run dev" C-m
tmux new-window -t dev -n logs
tmux send-keys -t dev:logs "tail -f /var/log/app.log" C-m
tmux new-window -t dev -n db
tmux send-keys -t dev:db "mysql -u root -p" C-m

# 创建监控会话
tmux new-session -d -s monitor
tmux send-keys -t monitor "htop" C-m
tmux split-window -t monitor -h
tmux send-keys -t monitor "watch df -h" C-m
```

## 项目结构

```
gin-terminal/
├── main.go                    # 主程序
├── templates/
│   └── login.html            # 登录页面模板
├── .env                      # 环境配置文件（不提交到版本控制）
├── .env.example              # 环境配置示例
├── .gitignore               # Git 忽略文件
├── start.sh                 # 生产环境启动脚本（支持交互式选择）
├── run.sh                   # 快速启动脚本
├── create-tmux-sessions.sh  # 创建示例 tmux 会话
├── go.mod                   # Go 模块配置
├── go.sum                   # 依赖版本锁定
├── README.md                # 项目说明
└── TTYD_GUIDE.md           # ttyd 详细使用指南
```

## 安全建议

生产环境部署时：

1. **修改默认凭据**
   ```bash
   AUTH_USERNAME=your_secure_username
   AUTH_PASSWORD=your_very_secure_password
   ```

2. **生成强 Session 密钥**
   ```bash
   openssl rand -base64 32
   ```

3. **启用 HTTPS**
   ```bash
   SECURE_COOKIE=true
   ```

4. **设置生产环境**
   ```bash
   ENV=production
   ```

5. **限制访问**
   - 使用防火墙限制访问 IP
   - 配置反向代理（如 Nginx）
   - 启用访问日志监控

## 开发说明

### 安装依赖
```bash
go mod download
```

### 构建二进制
```bash
go build -o web-terminal main.go
```

### 运行测试
```bash
go test ./...
```

## 故障排除

### ttyd 未安装
```bash
# 检查 ttyd 是否安装
which ttyd

# 如果未安装，请参考安装步骤
```

### 端口被占用
```bash
# 查看端口占用
lsof -i :3000
lsof -i :7681

# 修改 .env 中的端口配置
```

### 依赖问题
```bash
# 清理并重新安装依赖
go clean -modcache
go mod download
```

## License

MIT