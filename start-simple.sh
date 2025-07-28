#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Find available port for ttyd
echo "查找可用端口..."
for port in $(seq 7681 7690); do
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        TTYD_PORT=$port
        print_status "使用端口: $TTYD_PORT"
        break
    fi
done

# Update TTYD_URL
export TTYD_URL="http://localhost:$TTYD_PORT"

# Select terminal mode
echo ""
echo "选择终端模式:"
echo "1) 普通 bash"
echo "2) tmux 会话"
read -p "选择 (1-2): " choice

case $choice in
    1)
        TTYD_CMD="bash"
        ;;
    2)
        # List tmux sessions
        echo ""
        echo "可用的 tmux 会话:"
        tmux list-sessions 2>/dev/null || echo "没有会话"
        echo ""
        read -p "输入会话名称 (或留空创建新会话): " session
        if [ -z "$session" ]; then
            session="webterm"
            tmux new-session -d -s $session 2>/dev/null
        fi
        TTYD_CMD="tmux attach-session -t $session"
        ;;
    *)
        TTYD_CMD="bash"
        ;;
esac

# Start ttyd - ONLY listen on localhost for security
print_status "启动 ttyd (仅本地访问)..."
ttyd -i 127.0.0.1 -p $TTYD_PORT $TTYD_CMD &
TTYD_PID=$!
sleep 2

if ! kill -0 $TTYD_PID 2>/dev/null; then
    print_error "ttyd 启动失败"
    exit 1
fi

print_status "ttyd 已启动 (PID: $TTYD_PID, Port: $TTYD_PORT)"

# Build and run web terminal
print_status "构建 Web 终端..."
go build -o web-terminal main.go || exit 1

print_status "启动 Web 终端..."
echo ""
echo "====================================="
print_status "访问地址: http://localhost:${SERVER_PORT:-3000}"
print_status "用户名: ${AUTH_USERNAME:-admin}"
echo "====================================="
echo ""
echo "按 Ctrl+C 停止服务"
echo ""

# Cleanup function
cleanup() {
    echo ""
    print_warning "停止服务..."
    kill $TTYD_PID 2>/dev/null
    exit 0
}

trap cleanup INT TERM

# Run web terminal
./web-terminal