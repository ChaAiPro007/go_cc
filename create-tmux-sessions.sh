#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Creating example tmux sessions..."

# Development session
if ! tmux has-session -t dev 2>/dev/null; then
    echo -e "${GREEN}Creating 'dev' session...${NC}"
    tmux new-session -d -s dev -n editor
    tmux send-keys -t dev:editor "echo 'Ready for development'" C-m
    
    tmux new-window -t dev -n server
    tmux send-keys -t dev:server "echo 'Start your server here (e.g., npm run dev)'" C-m
    
    tmux new-window -t dev -n logs
    tmux send-keys -t dev:logs "echo 'Logs will appear here'" C-m
    
    tmux new-window -t dev -n git
    tmux send-keys -t dev:git "git status" C-m
else
    echo -e "${YELLOW}'dev' session already exists${NC}"
fi

# Monitoring session
if ! tmux has-session -t monitor 2>/dev/null; then
    echo -e "${GREEN}Creating 'monitor' session...${NC}"
    tmux new-session -d -s monitor -n system
    tmux send-keys -t monitor:system "htop" C-m
    
    tmux new-window -t monitor -n disk
    tmux send-keys -t monitor:disk "watch -n 5 df -h" C-m
    
    tmux new-window -t monitor -n network
    tmux send-keys -t monitor:network "sudo iftop 2>/dev/null || echo 'Install iftop for network monitoring'" C-m
else
    echo -e "${YELLOW}'monitor' session already exists${NC}"
fi

# Database session
if ! tmux has-session -t database 2>/dev/null; then
    echo -e "${GREEN}Creating 'database' session...${NC}"
    tmux new-session -d -s database -n mysql
    tmux send-keys -t database:mysql "echo 'mysql -u root -p'" C-m
    
    tmux new-window -t database -n redis
    tmux send-keys -t database:redis "redis-cli 2>/dev/null || echo 'Redis not installed'" C-m
    
    tmux new-window -t database -n mongo
    tmux send-keys -t database:mongo "mongosh 2>/dev/null || echo 'MongoDB not installed'" C-m
else
    echo -e "${YELLOW}'database' session already exists${NC}"
fi

# Docker session
if ! tmux has-session -t docker 2>/dev/null; then
    echo -e "${GREEN}Creating 'docker' session...${NC}"
    tmux new-session -d -s docker -n containers
    tmux send-keys -t docker:containers "watch docker ps -a" C-m
    
    tmux new-window -t docker -n logs
    tmux send-keys -t docker:logs "echo 'Use: docker logs -f <container_name>'" C-m
    
    tmux new-window -t docker -n compose
    tmux send-keys -t docker:compose "docker-compose ps 2>/dev/null || docker compose ps" C-m
else
    echo -e "${YELLOW}'docker' session already exists${NC}"
fi

echo ""
echo "Available tmux sessions:"
tmux list-sessions

echo ""
echo -e "${GREEN}Done! You can now run ./start.sh to select a session.${NC}"