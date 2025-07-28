#!/bin/bash

# 防火墙安全配置脚本

echo "配置防火墙规则以保护 ttyd 端口..."

# 检查是否有 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# UFW 防火墙配置（Ubuntu/Debian）
if command -v ufw &> /dev/null; then
    echo "配置 UFW 防火墙..."
    
    # 允许 SSH（避免锁定自己）
    ufw allow 22/tcp
    
    # 允许 Web 端口
    ufw allow 3000/tcp
    
    # 拒绝 ttyd 端口的外部访问（7681-7690）
    for port in $(seq 7681 7690); do
        ufw deny $port/tcp
    done
    
    # 启用防火墙
    ufw --force enable
    
    echo "UFW 防火墙规则已配置"
fi

# iptables 配置（通用 Linux）
if command -v iptables &> /dev/null; then
    echo "配置 iptables 规则..."
    
    # 允许本地访问 ttyd 端口
    iptables -A INPUT -p tcp -s 127.0.0.1 --dport 7681:7690 -j ACCEPT
    
    # 拒绝外部访问 ttyd 端口
    iptables -A INPUT -p tcp --dport 7681:7690 -j DROP
    
    # 保存规则
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save
    elif [ -f /etc/sysconfig/iptables ]; then
        service iptables save
    fi
    
    echo "iptables 规则已配置"
fi

echo ""
echo "防火墙配置完成！"
echo "- ttyd 端口 (7681-7690) 只能本地访问"
echo "- Web 端口 (3000) 可以外部访问"
echo ""
echo "建议额外的安全措施："
echo "1. 使用 Nginx/Apache 反向代理并启用 HTTPS"
echo "2. 配置 fail2ban 防止暴力破解"
echo "3. 定期更新密码和 session 密钥"