#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

echo "==================================="
echo "Web Terminal Startup Script"
echo "==================================="

# Check if .env file exists
if [ ! -f .env ]; then
    print_warning ".env file not found"
    if [ -f .env.example ]; then
        print_status "Creating .env from .env.example"
        cp .env.example .env
        print_warning "Please edit .env file with your configuration"
        exit 1
    else
        print_error ".env.example file not found"
        exit 1
    fi
else
    print_status ".env file found"
fi

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go first."
    exit 1
else
    print_status "Go is installed: $(go version)"
fi

# Check if ttyd is installed
if ! command -v ttyd &> /dev/null; then
    print_error "ttyd is not installed"
    echo "Install ttyd with one of the following:"
    echo "  Ubuntu/Debian: sudo apt-get install ttyd"
    echo "  macOS: brew install ttyd"
    echo "  Or visit: https://github.com/tsl0922/ttyd"
    exit 1
else
    print_status "ttyd is installed"
fi

# Check if dependencies are installed
if [ ! -d "vendor" ] && [ ! -f "go.sum" ]; then
    print_warning "Dependencies not found, installing..."
    go mod download
    if [ $? -eq 0 ]; then
        print_status "Dependencies installed"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
else
    print_status "Dependencies already installed"
fi

# Get ttyd port from TTYD_URL
TTYD_PORT=$(echo $TTYD_URL | grep -oE '[0-9]+$')
TTYD_PORT=${TTYD_PORT:-7681}

# Skip port check and find available port
print_status "查找可用端口..."
ORIGINAL_PORT=$TTYD_PORT

# Find available port starting from TTYD_PORT
for port in $(seq $TTYD_PORT 7690); do
    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        TTYD_PORT=$port
        print_status "找到可用端口: $TTYD_PORT"
        break
    else
        print_warning "端口 $port 已被占用"
    fi
done

# If no port found, use a higher range
if [ "$TTYD_PORT" -eq 7690 ] && lsof -Pi :$TTYD_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    TTYD_PORT=$((ORIGINAL_PORT + 100))
    print_warning "使用备用端口: $TTYD_PORT"
fi

# Old port check logic (skip it)
if false; then
    TTYD_PIDS=$(lsof -Pi :$TTYD_PORT -sTCP:LISTEN -t 2>/dev/null)
    TTYD_INFO=$(ps -p $TTYD_PIDS -o user=,comm= 2>/dev/null | head -1)
    print_warning "端口 $TTYD_PORT 已被占用"
    echo ""
    echo "进程信息: $TTYD_INFO (PID: $TTYD_PIDS)"
    
    # Check if it's a root process
    if [[ "$TTYD_INFO" == *"root"* ]]; then
        print_warning "这是一个系统进程，建议使用其他端口"
        echo ""
        echo "选项："
        echo "1) 使用备用端口 (推荐)"
        echo "2) 尝试停止进程 (需要 sudo)"
        echo "3) 退出"
        read -p "请选择 (1-3): " port_choice
        
        case $port_choice in
            1)
                # Find an available port
                for port in $(seq 7682 7690); do
                    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                        TTYD_PORT=$port
                        print_status "使用端口 $TTYD_PORT"
                        break
                    fi
                done
                ;;
            2)
                print_warning "需要 sudo 权限"
                exit 1
                ;;
            3)
                exit 0
                ;;
        esac
    else
        echo "选项："
        echo "1) 停止现有服务并继续"
        echo "2) 使用其他端口"
        echo "3) 退出"
        read -p "请选择 (1-3): " port_choice
        
        case $port_choice in
            1)
                for pid in $TTYD_PIDS; do
                    if kill -0 $pid 2>/dev/null; then
                        kill $pid 2>/dev/null && print_status "已停止进程 $pid" || print_error "无法停止进程 $pid"
                    fi
                done
                sleep 1
                ;;
            2)
                for port in $(seq 7682 7690); do
                    if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
                        TTYD_PORT=$port
                        print_status "使用端口 $TTYD_PORT"
                        break
                    fi
                done
                ;;
            3)
                exit 0
                ;;
            *)
                print_error "无效选择，退出"
                exit 1
                ;;
        esac
    fi
fi

# Check if web server port is in use
if lsof -Pi :${SERVER_PORT:-3000} -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Web 服务端口 ${SERVER_PORT:-3000} 已被占用"
    WEB_PID=$(lsof -Pi :${SERVER_PORT:-3000} -sTCP:LISTEN -t 2>/dev/null)
    # Only try to kill if it's our own web-terminal process
    if ps -p $WEB_PID -o comm= | grep -q "web-terminal\|main"; then
        kill $WEB_PID 2>/dev/null && print_status "已停止之前的 Web 服务进程" || print_error "无法停止进程 (可能需要 sudo 权限)"
        sleep 1
    else
        print_error "端口被其他程序占用，请检查或修改 SERVER_PORT 配置"
        exit 1
    fi
fi

# Interactive tmux session selection
select_terminal_command() {
    # Check if TTYD_COMMAND is already set via environment
    if [ ! -z "$TTYD_COMMAND" ] && [ "$TTYD_COMMAND" != "bash" ]; then
        print_status "Using predefined command: $TTYD_COMMAND"
        return
    fi

    # Check if tmux is installed
    if ! command -v tmux &> /dev/null; then
        print_warning "tmux not found, using bash"
        TTYD_COMMAND="bash"
        return
    fi

    # Get list of tmux sessions
    local sessions=$(tmux list-sessions 2>/dev/null | awk -F: '{print $1}')
    
    echo ""
    echo "==================================="
    echo "选择终端模式:"
    echo "==================================="
    
    if [ -z "$sessions" ]; then
        echo "1) 启动普通 bash shell"
        echo "2) 创建新的 tmux 会话"
        echo ""
        read -p "请输入选择 (1-2): " choice
        
        case $choice in
            1)
                TTYD_COMMAND="bash"
                print_status "已选择: 普通 bash shell"
                ;;
            2)
                read -p "输入 tmux 会话名称: " session_name
                session_name=${session_name:-webterm}
                tmux new-session -d -s "$session_name"
                TTYD_COMMAND="tmux attach-session -t $session_name"
                print_status "已创建并选择 tmux 会话: $session_name"
                ;;
            *)
                print_warning "无效的选择，使用 bash"
                TTYD_COMMAND="bash"
                ;;
        esac
    else
        # List existing sessions
        echo "可用的 tmux 会话:"
        echo ""
        local i=1
        declare -a session_array
        while IFS= read -r session; do
            # Get detailed session info
            local windows=$(tmux list-windows -t "$session" 2>/dev/null | wc -l)
            local attached=""
            if tmux list-sessions | grep "^$session:.*attached" > /dev/null 2>&1; then
                attached=" (已连接)"
            fi
            echo "$i) 会话: $session - $windows 个窗口$attached"
            session_array[$i]=$session
            ((i++))
        done <<< "$sessions"
        
        echo "$i) 启动普通 bash shell"
        local bash_option=$i
        ((i++))
        echo "$i) 创建新的 tmux 会话"
        local new_option=$i
        
        echo ""
        read -p "请输入选择 (1-$i): " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
            if [ "$choice" -eq "$bash_option" ]; then
                TTYD_COMMAND="bash"
                print_status "已选择: 普通 bash shell"
            elif [ "$choice" -eq "$new_option" ]; then
                read -p "输入新的 tmux 会话名称: " session_name
                session_name=${session_name:-webterm}
                tmux new-session -d -s "$session_name"
                TTYD_COMMAND="tmux attach-session -t $session_name"
                print_status "已创建并选择 tmux 会话: $session_name"
            else
                selected_session=${session_array[$choice]}
                # Ask if user wants to select a specific window
                local windows=$(tmux list-windows -t "$selected_session" 2>/dev/null | awk -F: '{print $1": "$2}')
                if [ $(echo "$windows" | wc -l) -gt 1 ]; then
                    echo ""
                    echo "'$selected_session' 会话中的窗口:"
                    echo "$windows"
                    read -p "输入窗口编号 (或按 Enter 使用当前窗口): " window_num
                    if [ ! -z "$window_num" ]; then
                        TTYD_COMMAND="tmux attach-session -t $selected_session:$window_num"
                        print_status "已选择: tmux 会话 '$selected_session' 窗口 $window_num"
                    else
                        TTYD_COMMAND="tmux attach-session -t $selected_session"
                        print_status "已选择: tmux 会话 '$selected_session'"
                    fi
                else
                    TTYD_COMMAND="tmux attach-session -t $selected_session"
                    print_status "已选择: tmux 会话 '$selected_session'"
                fi
            fi
        else
            print_warning "无效的选择，使用 bash"
            TTYD_COMMAND="bash"
        fi
    fi
    echo "==================================="
    echo ""
}

# Select terminal command
select_terminal_command

# Update TTYD_URL if port was changed
if [ "$TTYD_PORT" != "$(echo $TTYD_URL | grep -oE '[0-9]+$')" ]; then
    export TTYD_URL="http://localhost:$TTYD_PORT"
    print_status "更新 TTYD_URL 为: $TTYD_URL"
fi

# Start ttyd in background
print_status "正在端口 $TTYD_PORT 启动 ttyd..."
print_status "执行命令: ttyd -i 127.0.0.1 -p $TTYD_PORT $TTYD_COMMAND"

# Start ttyd and capture output - ONLY listen on localhost
ttyd -i 127.0.0.1 -p $TTYD_PORT $TTYD_COMMAND > /tmp/ttyd.log 2>&1 &
TTYD_PID=$!
sleep 2

# Check if ttyd started successfully
if ! kill -0 $TTYD_PID 2>/dev/null; then
    print_error "ttyd 启动失败"
    if [ -f /tmp/ttyd.log ]; then
        echo "错误信息:"
        tail -n 10 /tmp/ttyd.log
    fi
    # Try alternative port
    print_warning "尝试使用备用端口..."
    TTYD_PORT=$((TTYD_PORT + 1))
    export TTYD_URL="http://localhost:$TTYD_PORT"
    print_status "使用端口 $TTYD_PORT 重试..."
    ttyd -i 127.0.0.1 -p $TTYD_PORT $TTYD_COMMAND > /tmp/ttyd.log 2>&1 &
    TTYD_PID=$!
    sleep 2
    if ! kill -0 $TTYD_PID 2>/dev/null; then
        print_error "ttyd 启动失败，请检查端口是否被占用"
        exit 1
    fi
else
    print_status "ttyd 启动成功 (PID: $TTYD_PID)"
fi

# Function to cleanup on exit
cleanup() {
    echo ""
    print_warning "Shutting down services..."
    kill $TTYD_PID 2>/dev/null
    print_status "Services stopped"
    exit 0
}

# Set trap for cleanup
trap cleanup INT TERM

# Build the application
print_status "Building web terminal..."
go build -o web-terminal main.go
if [ $? -ne 0 ]; then
    print_error "Build failed"
    kill $TTYD_PID 2>/dev/null
    exit 1
fi
print_status "Build successful"

# Start the web terminal
echo ""
echo "==================================="
print_status "Starting Web Terminal on port ${SERVER_PORT:-3000}"
print_status "URL: http://localhost:${SERVER_PORT:-3000}"
print_status "Username: ${AUTH_USERNAME:-admin}"
echo "==================================="
echo ""
echo "Press Ctrl+C to stop all services"
echo ""

# Run the web terminal
./web-terminal