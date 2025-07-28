#!/bin/bash

echo "检查端口占用情况..."
echo ""

# Check ttyd port
echo "端口 7681 (ttyd 默认端口):"
if lsof -Pi :7681 -sTCP:LISTEN 2>/dev/null; then
    lsof -Pi :7681 -sTCP:LISTEN
else
    echo "  端口空闲"
fi

echo ""
echo "端口 3000 (Web 服务端口):"
if lsof -Pi :3000 -sTCP:LISTEN 2>/dev/null; then
    lsof -Pi :3000 -sTCP:LISTEN
else
    echo "  端口空闲"
fi

echo ""
echo "所有 ttyd 进程:"
if pgrep -af ttyd; then
    pgrep -af ttyd
else
    echo "  没有运行的 ttyd 进程"
fi

echo ""
echo "tmux 会话列表:"
tmux list-sessions 2>/dev/null || echo "  没有 tmux 会话"