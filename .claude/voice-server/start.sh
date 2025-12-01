#!/bin/bash

# Start the PAI Voice Server

SERVICE_NAME="pai-voice-server"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}▶ Starting PAI Voice Server...${NC}"

# Check if service exists
if ! systemctl --user list-unit-files | grep -q "$SERVICE_NAME.service" 2>/dev/null; then
    echo -e "${RED}✗ Service not installed${NC}"
    echo "  Run ./install.sh first to install the service"
    exit 1
fi

# Check if already running
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Voice server is already running${NC}"
    echo "  To restart, use: ./restart.sh"
    exit 0
fi

# Start the service
systemctl --user start "$SERVICE_NAME" 2>&1

if [ $? -eq 0 ]; then
    # Wait for server to start
    sleep 2

    # Test if server is responding
    if curl -s -f -X GET http://localhost:8888/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Voice server started successfully${NC}"
        echo "  Port: 8888"
        echo "  Test: curl -X POST http://localhost:8888/notify -H 'Content-Type: application/json' -d '{\"message\":\"Test\"}'"
        echo "  Logs: journalctl --user -u $SERVICE_NAME -f"
    else
        echo -e "${YELLOW}⚠ Server started but not responding yet${NC}"
        echo "  Check logs: journalctl --user -u $SERVICE_NAME -n 50"
    fi
else
    echo -e "${RED}✗ Failed to start voice server${NC}"
    echo "  Check status: systemctl --user status $SERVICE_NAME"
    echo "  Try running manually: bun run $SCRIPT_DIR/server.ts"
    exit 1
fi
