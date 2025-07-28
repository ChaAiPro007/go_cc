#!/bin/bash

echo "停止现有服务..."
pkill web-terminal 2>/dev/null
pkill ttyd 2>/dev/null
sleep 1

echo "重新构建..."
go build -o web-terminal main.go || exit 1

echo "启动服务..."
./start-simple.sh