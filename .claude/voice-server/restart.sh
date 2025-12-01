#!/bin/bash

# Restart the PAI Voice Server

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICE_NAME="pai-voice-server"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}▶ Restarting PAI Voice Server...${NC}"

# Use systemctl restart if service is installed
if systemctl --user list-unit-files | grep -q "$SERVICE_NAME.service" 2>/dev/null; then
    systemctl --user restart "$SERVICE_NAME"

    if [ $? -eq 0 ]; then
        sleep 2
        if curl -s -f -X GET http://localhost:8888/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Voice server restarted successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Server restarted but not responding yet${NC}"
            echo "  Check logs: journalctl --user -u $SERVICE_NAME -n 20"
        fi
    else
        echo -e "${RED}✗ Failed to restart service${NC}"
        exit 1
    fi
else
    # Fallback to manual stop/start
    "$SCRIPT_DIR/stop.sh"
    sleep 2
    "$SCRIPT_DIR/start.sh"
fi
