#!/bin/bash

# Uninstall PAI Voice Server

SERVICE_NAME="pai-voice-server"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="${SYSTEMD_USER_DIR}/${SERVICE_NAME}.service"
LOG_DIR="$HOME/.local/state/pai-voice-server"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     PAI Voice Server Uninstall${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Confirm uninstall
echo -e "${YELLOW}This will:${NC}"
echo "  • Stop the voice server"
echo "  • Disable the systemd service"
echo "  • Remove the systemd service file"
echo "  • Keep your server files and configuration"
echo
read -p "Are you sure you want to uninstall? (y/n): " -n 1 -r
echo
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled"
    exit 0
fi

# Stop the service if running
echo -e "${YELLOW}▶ Stopping voice server...${NC}"
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl --user stop "$SERVICE_NAME" 2>&1
    echo -e "${GREEN}✓ Voice server stopped${NC}"
else
    echo -e "${YELLOW}  Service was not running${NC}"
fi

# Disable the service
echo -e "${YELLOW}▶ Disabling service...${NC}"
if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl --user disable "$SERVICE_NAME" 2>&1
    echo -e "${GREEN}✓ Service disabled${NC}"
else
    echo -e "${YELLOW}  Service was not enabled${NC}"
fi

# Remove systemd service file
echo -e "${YELLOW}▶ Removing systemd service file...${NC}"
if [ -f "$SERVICE_PATH" ]; then
    rm "$SERVICE_PATH"
    systemctl --user daemon-reload
    echo -e "${GREEN}✓ Service file removed${NC}"
else
    echo -e "${YELLOW}  Service file not found${NC}"
fi

# Kill any remaining processes on port 8888
if ss -ltn | grep -q ':8888 ' 2>/dev/null; then
    echo -e "${YELLOW}▶ Cleaning up port 8888...${NC}"
    PID=$(ss -ltnp | grep ':8888 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$PID" ]; then
        kill -9 "$PID" 2>/dev/null
        echo -e "${GREEN}✓ Port 8888 cleared${NC}"
    fi
elif lsof -i :8888 > /dev/null 2>&1; then
    # Fallback to lsof
    echo -e "${YELLOW}▶ Cleaning up port 8888...${NC}"
    lsof -ti :8888 | xargs kill -9 2>/dev/null
    echo -e "${GREEN}✓ Port 8888 cleared${NC}"
fi

# Ask about logs
echo
read -p "Do you want to remove log files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "$LOG_DIR" ]; then
        rm -rf "$LOG_DIR"
        echo -e "${GREEN}✓ Log directory removed${NC}"
    else
        echo -e "${YELLOW}  Log directory not found${NC}"
    fi
fi

echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     ✓ Uninstall Complete${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}Notes:${NC}"
echo "  • Your server files are still in: $(dirname "${BASH_SOURCE[0]}")"
echo "  • Your ~/.env configuration is preserved"
echo "  • To reinstall, run: ./install.sh"
echo
echo "To completely remove all files:"
echo "  rm -rf $(dirname "${BASH_SOURCE[0]}")"
