#!/bin/bash

# PAI Voice Server Installation Script
# This script installs the voice server as a Linux systemd user service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SERVICE_NAME="pai-voice-server"
SERVICE_FILE="${SERVICE_NAME}.service"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="${SYSTEMD_USER_DIR}/${SERVICE_FILE}"
LOG_DIR="$HOME/.local/state/pai-voice-server"
ENV_FILE="$HOME/.env"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}     PAI Voice Server Installation (Ubuntu Linux)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo

# Check for Bun
echo -e "${YELLOW}▶ Checking prerequisites...${NC}"
if ! command -v bun &> /dev/null; then
    echo -e "${RED}✗ Bun is not installed${NC}"
    echo "  Please install Bun first:"
    echo "  curl -fsSL https://bun.sh/install | bash"
    exit 1
fi
echo -e "${GREEN}✓ Bun is installed${NC}"

# Check for audio player (mpg123 or ffmpeg)
AUDIO_PLAYER_INSTALLED=false
if command -v mpg123 &> /dev/null; then
    echo -e "${GREEN}✓ mpg123 is installed${NC}"
    AUDIO_PLAYER_INSTALLED=true
elif command -v ffplay &> /dev/null; then
    echo -e "${GREEN}✓ ffplay (ffmpeg) is installed${NC}"
    AUDIO_PLAYER_INSTALLED=true
else
    echo -e "${YELLOW}⚠ No audio player found (mpg123 or ffmpeg)${NC}"
    echo "  Install one of these for audio playback:"
    echo "  sudo apt-get install mpg123"
    echo "  or"
    echo "  sudo apt-get install ffmpeg"
    read -p "Continue without audio player? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for notify-send (libnotify)
if command -v notify-send &> /dev/null; then
    echo -e "${GREEN}✓ notify-send is installed${NC}"
else
    echo -e "${YELLOW}⚠ notify-send not found${NC}"
    echo "  Install libnotify-bin for desktop notifications:"
    echo "  sudo apt-get install libnotify-bin"
    read -p "Continue without notifications? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for existing installation
if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠ Voice server is already installed and running${NC}"
    read -p "Do you want to reinstall? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}▶ Stopping existing service...${NC}"
        systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
        echo -e "${GREEN}✓ Existing service stopped${NC}"
    else
        echo "Installation cancelled"
        exit 0
    fi
fi

# Check for ElevenLabs configuration
echo -e "${YELLOW}▶ Checking ElevenLabs configuration...${NC}"
if [ -f "$ENV_FILE" ] && grep -q "ELEVENLABS_API_KEY=" "$ENV_FILE"; then
    API_KEY=$(grep "ELEVENLABS_API_KEY=" "$ENV_FILE" | cut -d'=' -f2)
    if [ "$API_KEY" != "your_api_key_here" ] && [ -n "$API_KEY" ]; then
        echo -e "${GREEN}✓ ElevenLabs API key configured${NC}"
        ELEVENLABS_CONFIGURED=true
    else
        echo -e "${YELLOW}⚠ ElevenLabs API key not configured${NC}"
        ELEVENLABS_CONFIGURED=false
    fi
else
    echo -e "${YELLOW}⚠ No ElevenLabs configuration found${NC}"
    ELEVENLABS_CONFIGURED=false
fi

if [ "$ELEVENLABS_CONFIGURED" = false ]; then
    echo
    echo "To enable AI voices, add your ElevenLabs API key to ~/.env:"
    echo "  echo 'ELEVENLABS_API_KEY=your_api_key_here' >> ~/.env"
    echo "  Get a free key at: https://elevenlabs.io"
    echo
fi

# Create systemd user directory if it doesn't exist
echo -e "${YELLOW}▶ Creating systemd user service...${NC}"
mkdir -p "$SYSTEMD_USER_DIR"
mkdir -p "$LOG_DIR"

# Copy service file and replace placeholders
sed "s|%h|$HOME|g" "$SCRIPT_DIR/$SERVICE_FILE" > "$SERVICE_PATH"

echo -e "${GREEN}✓ Systemd service file created${NC}"

# Reload systemd daemon
systemctl --user daemon-reload

# Enable the service to start at login
echo -e "${YELLOW}▶ Enabling voice server service...${NC}"
systemctl --user enable "$SERVICE_NAME"
echo -e "${GREEN}✓ Service enabled (will start at login)${NC}"

# Start the service
echo -e "${YELLOW}▶ Starting voice server service...${NC}"
systemctl --user start "$SERVICE_NAME" 2>&1 || {
    echo -e "${RED}✗ Failed to start service${NC}"
    echo "  Check status: systemctl --user status $SERVICE_NAME"
    echo "  Check logs: journalctl --user -u $SERVICE_NAME"
    exit 1
}

# Wait for server to start
sleep 3

# Test the server
echo -e "${YELLOW}▶ Testing voice server...${NC}"
if curl -s -f -X GET http://localhost:8888/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Voice server is running${NC}"

    # Send test notification
    echo -e "${YELLOW}▶ Sending test notification...${NC}"
    curl -s -X POST http://localhost:8888/notify \
        -H "Content-Type: application/json" \
        -d '{"message": "Voice server installed successfully"}' > /dev/null
    echo -e "${GREEN}✓ Test notification sent${NC}"
else
    echo -e "${RED}✗ Voice server is not responding${NC}"
    echo "  Check logs: journalctl --user -u $SERVICE_NAME -n 50"
    echo "  Try running manually: bun run $SCRIPT_DIR/server.ts"
    exit 1
fi

# Show summary
echo
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}     ✓ Installation Complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}Service Information:${NC}"
echo "  • Service: $SERVICE_NAME"
echo "  • Status: Running"
echo "  • Port: 8888"
echo "  • Logs: $LOG_DIR/"
echo "  • System logs: journalctl --user -u $SERVICE_NAME"

if [ "$ELEVENLABS_CONFIGURED" = true ]; then
    echo "  • Voice: ElevenLabs AI"
else
    echo "  • Voice: Not configured (audio only)"
fi

echo
echo -e "${BLUE}Management Commands:${NC}"
echo "  • Status:   ./status.sh  or  systemctl --user status $SERVICE_NAME"
echo "  • Stop:     ./stop.sh    or  systemctl --user stop $SERVICE_NAME"
echo "  • Start:    ./start.sh   or  systemctl --user start $SERVICE_NAME"
echo "  • Restart:  ./restart.sh or  systemctl --user restart $SERVICE_NAME"
echo "  • Logs:     journalctl --user -u $SERVICE_NAME -f"
echo "  • Uninstall: ./uninstall.sh"

echo
echo -e "${BLUE}Test the server:${NC}"
echo "  curl -X POST http://localhost:8888/notify \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"message\": \"Hello from PAI\"}'"

echo
echo -e "${GREEN}The voice server will now start automatically when you log in.${NC}"
echo
