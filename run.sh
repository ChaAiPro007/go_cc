#!/bin/bash

# 检查 ttyd 是否运行
if ! pgrep -f "ttyd" > /dev/null; then
    echo "Starting ttyd..."
    ttyd -p 7681 bash &
    sleep 2
fi

# 启动 gin 服务
echo "Starting web terminal on :3000..."
go run main.go