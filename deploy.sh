#!/bin/bash

# 安全部署脚本

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "====================================="
echo "Web Terminal 安全部署脚本"
echo "====================================="

# 1. 检查是否使用了安全版本
if [ -f main_secure.go ]; then
    print_status "检测到安全版本代码"
    
    # 备份原始文件
    if [ -f main.go ]; then
        cp main.go main.go.bak
        print_status "已备份原始 main.go"
    fi
    
    # 使用安全版本
    cp main_secure.go main.go
    print_status "已切换到安全版本"
else
    print_error "未找到 main_secure.go"
    exit 1
fi

# 2. 检查 .env 配置
if [ ! -f .env ]; then
    print_error "未找到 .env 文件"
    
    if [ -f .env.secure.example ]; then
        print_warning "请基于 .env.secure.example 创建 .env 文件"
        echo ""
        echo "执行以下命令："
        echo "  cp .env.secure.example .env"
        echo "  vim .env  # 编辑并设置强密码"
        echo ""
    fi
    exit 1
fi

# 3. 检查密码强度
if grep -q "admin123\|secret-key-change-this" .env; then
    print_error "检测到默认密码或密钥！"
    echo ""
    echo "请修改以下配置："
    grep -E "AUTH_PASSWORD|SESSION_SECRET" .env
    echo ""
    echo "生成强密码："
    echo "  openssl rand -base64 16  # 用于 AUTH_PASSWORD"
    echo "  openssl rand -base64 64  # 用于 SESSION_SECRET"
    exit 1
fi

# 4. 检查密码长度
AUTH_PASS_LEN=$(grep AUTH_PASSWORD .env | cut -d= -f2 | wc -c)
SESSION_SECRET_LEN=$(grep SESSION_SECRET .env | cut -d= -f2 | wc -c)

if [ $AUTH_PASS_LEN -lt 8 ]; then
    print_error "AUTH_PASSWORD 太短（至少8个字符）"
    exit 1
fi

if [ $SESSION_SECRET_LEN -lt 32 ]; then
    print_error "SESSION_SECRET 太短（至少32个字符）"
    exit 1
fi

print_status "密码和密钥检查通过"

# 5. 编译
print_status "编译安全版本..."
go build -o web-terminal main.go
if [ $? -ne 0 ]; then
    print_error "编译失败"
    exit 1
fi
print_status "编译成功"

# 6. 设置文件权限
chmod 700 web-terminal
chmod 600 .env
print_status "已设置安全文件权限"

# 7. 创建系统服务（可选）
if [ "$1" = "--install-service" ]; then
    print_status "创建 systemd 服务..."
    
    cat > /tmp/web-terminal.service << EOF
[Unit]
Description=Secure Web Terminal Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/web-terminal
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# 安全限制
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$(pwd)

[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/web-terminal.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable web-terminal
    print_status "服务已安装"
    echo ""
    echo "使用以下命令管理服务："
    echo "  sudo systemctl start web-terminal   # 启动"
    echo "  sudo systemctl stop web-terminal    # 停止"
    echo "  sudo systemctl status web-terminal  # 状态"
    echo "  sudo journalctl -u web-terminal -f  # 日志"
fi

echo ""
echo "====================================="
print_status "部署准备完成！"
echo ""
echo "安全建议："
echo "1. 确保防火墙已配置（运行 ./secure-firewall.sh）"
echo "2. 使用 Nginx 反向代理并启用 HTTPS"
echo "3. 定期更新密码"
echo "4. 监控登录日志"
echo ""
echo "启动服务："
echo "  ./start.sh"
echo "====================================="