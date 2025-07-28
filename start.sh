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

# Kill existing ttyd process
if pgrep -f "ttyd.*-p $TTYD_PORT" > /dev/null; then
    print_warning "Stopping existing ttyd process on port $TTYD_PORT"
    pkill -f "ttyd.*-p $TTYD_PORT"
    sleep 1
fi

# Kill existing web terminal process
if lsof -Pi :${SERVER_PORT:-3000} -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Port ${SERVER_PORT:-3000} is already in use, stopping existing process"
    kill $(lsof -Pi :${SERVER_PORT:-3000} -sTCP:LISTEN -t) 2>/dev/null
    sleep 1
fi

# Start ttyd in background
print_status "Starting ttyd on port $TTYD_PORT..."
ttyd -p $TTYD_PORT bash &
TTYD_PID=$!
sleep 2

# Check if ttyd started successfully
if ! kill -0 $TTYD_PID 2>/dev/null; then
    print_error "Failed to start ttyd"
    exit 1
else
    print_status "ttyd started successfully (PID: $TTYD_PID)"
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