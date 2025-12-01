#!/bin/bash

# Check status of PAI Voice Server

SERVICE_NAME="pai-voice-server"
LOG_DIR="$HOME/.local/state/pai-voice-server"
ENV_FILE="$HOME/.env"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     PAI Voice Server Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check systemd service
echo -e "${BLUE}Service Status:${NC}"
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "  ${GREEN}✓ Service is running${NC}"

    # Get PID from systemd
    PID=$(systemctl --user show -p MainPID --value "$SERVICE_NAME" 2>/dev/null)
    if [ -n "$PID" ] && [ "$PID" != "0" ]; then
        echo -e "  ${GREEN}  PID: $PID${NC}"
    fi

    # Get uptime
    SINCE=$(systemctl --user show -p ActiveEnterTimestamp --value "$SERVICE_NAME" 2>/dev/null)
    if [ -n "$SINCE" ]; then
        echo "  Started: $SINCE"
    fi
else
    if systemctl --user is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "  ${YELLOW}⚠ Service is installed but not running${NC}"
        echo "  Start it with: ./start.sh"
    else
        echo -e "  ${RED}✗ Service is not installed${NC}"
        echo "  Install it with: ./install.sh"
    fi
fi

# Check if server is responding
echo
echo -e "${BLUE}Server Status:${NC}"
if curl -s -f -X GET http://localhost:8888/health > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓ Server is responding on port 8888${NC}"

    # Get health info
    HEALTH=$(curl -s http://localhost:8888/health 2>/dev/null)
    if [ -n "$HEALTH" ]; then
        echo "  Health Response:"
        echo "$HEALTH" | jq '.' 2>/dev/null || echo "  $HEALTH"
    fi
else
    echo -e "  ${RED}✗ Server is not responding${NC}"
fi

# Check port binding
echo
echo -e "${BLUE}Port Status:${NC}"
if ss -ltn | grep -q ':8888 ' 2>/dev/null; then
    echo -e "  ${GREEN}✓ Port 8888 is in use${NC}"
    PROCESS=$(ss -ltnp 2>/dev/null | grep ':8888 ')
    if [ -n "$PROCESS" ]; then
        echo "  $PROCESS"
    fi
elif lsof -i :8888 > /dev/null 2>&1; then
    # Fallback to lsof
    PROCESS=$(lsof -i :8888 | grep LISTEN | head -1)
    echo -e "  ${GREEN}✓ Port 8888 is in use${NC}"
    if [ -n "$PROCESS" ]; then
        echo "  $PROCESS" | awk '{print "  Process: " $1 " (PID: " $2 ")"}'
    fi
else
    echo -e "  ${YELLOW}⚠ Port 8888 is not in use${NC}"
fi

# Check ElevenLabs configuration
echo
echo -e "${BLUE}Voice Configuration:${NC}"
if [ -f "$ENV_FILE" ] && grep -q "ELEVENLABS_API_KEY=" "$ENV_FILE"; then
    API_KEY=$(grep "ELEVENLABS_API_KEY=" "$ENV_FILE" | cut -d'=' -f2)
    if [ "$API_KEY" != "your_api_key_here" ] && [ -n "$API_KEY" ]; then
        echo -e "  ${GREEN}✓ ElevenLabs API configured${NC}"
        if grep -q "ELEVENLABS_VOICE_ID=" "$ENV_FILE"; then
            VOICE_ID=$(grep "ELEVENLABS_VOICE_ID=" "$ENV_FILE" | cut -d'=' -f2)
            echo "  Voice ID: $VOICE_ID"
        fi
    else
        echo -e "  ${YELLOW}⚠ ElevenLabs not configured${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠ ElevenLabs not configured${NC}"
fi

# Check audio player
echo
echo -e "${BLUE}Audio System:${NC}"
if command -v mpg123 &> /dev/null; then
    echo -e "  ${GREEN}✓ mpg123 installed${NC}"
elif command -v ffplay &> /dev/null; then
    echo -e "  ${GREEN}✓ ffplay (ffmpeg) installed${NC}"
else
    echo -e "  ${YELLOW}⚠ No audio player found${NC}"
    echo "  Install: sudo apt-get install mpg123"
fi

# Check notification system
if command -v notify-send &> /dev/null; then
    echo -e "  ${GREEN}✓ notify-send installed${NC}"
else
    echo -e "  ${YELLOW}⚠ notify-send not found${NC}"
    echo "  Install: sudo apt-get install libnotify-bin"
fi

# Check recent logs
echo
echo -e "${BLUE}Recent Logs (last 5 lines):${NC}"
if [ -d "$LOG_DIR" ]; then
    echo "  Log directory: $LOG_DIR"
    if [ -f "$LOG_DIR/voice-server.log" ]; then
        tail -5 "$LOG_DIR/voice-server.log" 2>/dev/null | while IFS= read -r line; do
            echo "    $line"
        done
    fi
else
    echo -e "  ${YELLOW}⚠ Log directory not found${NC}"
fi

echo
echo -e "  View full logs: journalctl --user -u $SERVICE_NAME -n 50"

# Show commands
echo
echo -e "${BLUE}Available Commands:${NC}"
echo "  • Start:     ./start.sh    or  systemctl --user start $SERVICE_NAME"
echo "  • Stop:      ./stop.sh     or  systemctl --user stop $SERVICE_NAME"
echo "  • Restart:   ./restart.sh  or  systemctl --user restart $SERVICE_NAME"
echo "  • Logs:      journalctl --user -u $SERVICE_NAME -f"
echo "  • Test:      curl -X POST http://localhost:8888/notify -H 'Content-Type: application/json' -d '{\"message\":\"Test\"}'"
