#!/bin/bash

# Stop the PAI Voice Server

SERVICE_NAME="pai-voice-server"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}▶ Stopping PAI Voice Server...${NC}"

# Check if service is running
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    # Stop the service
    systemctl --user stop "$SERVICE_NAME" 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Voice server stopped successfully${NC}"
    else
        echo -e "${RED}✗ Failed to stop voice server${NC}"
        echo "  Try: systemctl --user stop $SERVICE_NAME"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Voice server is not running${NC}"
fi

# Kill any remaining processes on port 8888
if ss -ltn | grep -q ':8888 ' 2>/dev/null; then
    echo -e "${YELLOW}▶ Cleaning up port 8888...${NC}"
    PID=$(ss -ltnp | grep ':8888 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$PID" ]; then
        kill -9 "$PID" 2>/dev/null && echo -e "${GREEN}✓ Port 8888 cleared${NC}"
    fi
elif lsof -i :8888 > /dev/null 2>&1; then
    # Fallback to lsof if ss doesn't work
    echo -e "${YELLOW}▶ Cleaning up port 8888...${NC}"
    lsof -ti :8888 | xargs kill -9 2>/dev/null && echo -e "${GREEN}✓ Port 8888 cleared${NC}"
fi
