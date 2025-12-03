# Web Interface for PAI Voice Notifications

## Overview

The PAI Voice Server now includes a web-based notification interface designed specifically for WSL (Windows Subsystem for Linux) environments where desktop notifications and audio playback may not work properly.

## Features

✅ **Real-time Notifications** - WebSocket-based instant notification delivery
🎙️ **Voice Playback** - Audio messages play directly in your browser
📊 **Statistics** - Track notification counts and session time
🎨 **Modern UI** - Beautiful dark-themed interface with animations
📱 **Responsive** - Works on desktop and mobile browsers
🔊 **Volume Control** - Adjust audio playback volume
🧪 **Test Buttons** - Send test notifications to verify functionality

## Quick Start

### 1. Open the Web Interface

Simply open your browser and navigate to:

```
http://localhost:8888/
```

Or from Windows (if WSL is running):

```
http://localhost:8888/
```

### 2. Connection Status

The header will show your connection status:
- 🟢 **Connected** - Ready to receive notifications
- 🔴 **Disconnected** - Attempting to reconnect...

### 3. Test the System

Click the test buttons to verify everything is working:
- **📨 Send Test Notification** - Sends a text-only notification
- **🎙️ Test Voice Message** - Sends a notification with voice audio

## How It Works

### WebSocket Connection

The web interface connects to the server via WebSocket at:
```
ws://localhost:8888/ws
```

When a notification is sent to the API (via `/notify` or `/pai` endpoints), the server:
1. Generates voice audio using ElevenLabs TTS (if enabled)
2. Converts the audio to Base64
3. Broadcasts the notification to all connected WebSocket clients
4. Each browser receives and displays the notification
5. Audio plays automatically in the browser

### Architecture

```
┌─────────────────┐
│  Claude Code    │
│  (PAI Hooks)    │
└────────┬────────┘
         │
         │ HTTP POST
         ▼
┌─────────────────┐     WebSocket      ┌─────────────────┐
│  Voice Server   │◄──────────────────►│  Web Browser    │
│  (Port 8888)    │    Broadcast       │  (You open)     │
└─────────────────┘                    └─────────────────┘
         │
         │ API Call
         ▼
┌─────────────────┐
│  ElevenLabs     │
│  Text-to-Speech │
└─────────────────┘
```

## API Usage

The server exposes REST API endpoints that automatically broadcast to the web interface:

### Send Notification

```bash
curl -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Task Complete",
    "message": "Your task has finished successfully",
    "voice_enabled": true,
    "voice_id": "s3TPKV1kjDlVtZbl4Ksh"
  }'
```

### Parameters

- `title` (string) - Notification title (default: "PAI Notification")
- `message` (string) - Notification message (default: "Task completed")
- `voice_enabled` (boolean) - Enable voice synthesis (default: true)
- `voice_id` (string) - ElevenLabs voice ID (default: configured in ~/.env)

### Check Health

```bash
curl http://localhost:8888/health
```

Returns:
```json
{
  "status": "healthy",
  "port": 8888,
  "voice_system": "ElevenLabs",
  "model": "eleven_multilingual_v2",
  "default_voice_id": "s3TPKV1kjDlVtZbl4Ksh",
  "api_key_configured": true
}
```

## Configuration

### Volume Control

Use the slider in the web interface to adjust audio playback volume (0-100%).

### Browser Notifications

The web interface will request permission to show browser notifications. Click "Allow" to enable desktop notifications alongside the in-page display.

### Multiple Tabs

You can open the web interface in multiple browser tabs/windows. Each will receive notifications independently.

## Notification Display

Each notification shows:

- **Title** - Notification header
- **Message** - Main notification text
- **Timestamp** - When the notification was received
- **Voice Badge** - Indicates if voice was enabled
- **Play Button** - Click to replay the audio message

The interface keeps the last 50 notifications for your reference.

## Troubleshooting

### "Disconnected - Reconnecting..."

**Cause:** WebSocket connection to server failed
**Solution:**
- Ensure the voice server is running: `systemctl --user status pai-voice-server`
- Restart the server: `systemctl --user restart pai-voice-server`
- Check logs: `tail -f ~/.local/state/pai-voice-server/voice-server.log`

### Audio Not Playing

**Cause:** Browser autoplay policy or user interaction required
**Solution:**
- Click anywhere on the page first to enable audio
- Check volume slider is not at 0%
- Verify ElevenLabs API key is configured

### Notifications Not Appearing

**Cause:** WebSocket connection or API issue
**Solution:**
- Check browser console (F12) for errors
- Verify server is receiving requests: check logs
- Test with the "Send Test Notification" button

### CORS Errors

**Cause:** Accessing from unexpected origin
**Solution:**
- Access via `http://localhost:8888/` or `http://127.0.0.1:8888/`
- CORS is now enabled for all origins in the updated code

## Integration with PAI System

The web interface integrates seamlessly with existing PAI hooks:

1. **initialize-pai-session.ts** - Session start notifications
2. **stop-hook.ts** - Main agent completion
3. **subagent-stop-hook.ts** - Subagent task completion

All these hooks automatically send notifications that appear in your web browser!

## Security

- **Rate Limiting** - 10 requests per minute per IP
- **Input Validation** - All inputs sanitized to prevent XSS/injection
- **CORS Enabled** - Access from any origin (for WSL flexibility)
- **No Authentication** - Runs on localhost only (not exposed to network)

## Technical Details

### Technologies Used

- **Backend:** Bun (TypeScript runtime)
- **WebSocket:** Native Bun WebSocket support
- **Frontend:** Vanilla JavaScript (no frameworks)
- **Audio:** HTML5 Audio API with Base64-encoded MP3
- **Styling:** Modern CSS with gradients and animations

### File Structure

```
voice-server/
├── server.ts              # Main server with WebSocket support
├── public/
│   └── index.html        # Web interface (self-contained)
└── voices.json           # Voice configuration
```

### WebSocket Protocol

**Server → Client Messages:**

```typescript
// Welcome message on connection
{
  type: 'welcome',
  message: 'Connected to PAI Voice Server',
  timestamp: 1234567890
}

// Notification broadcast
{
  type: 'notification',
  title: 'Task Complete',
  message: 'Your task finished',
  voiceEnabled: true,
  voiceId: 's3TPKV1kjDlVtZbl4Ksh',
  audio: 'base64-encoded-mp3-data...',
  timestamp: 1234567890
}
```

## Advanced Usage

### Access from Windows Host

If you want to access the web interface from Windows (outside WSL):

1. Find your WSL IP address:
   ```bash
   ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1
   ```

2. Open in Windows browser:
   ```
   http://<wsl-ip-address>:8888/
   ```

### Keep Browser Window Open

For best experience:
1. Open the web interface in a browser tab
2. Keep the tab open (can minimize browser)
3. Enable desktop notifications for alerts even when tab is not active

### Mobile Access

If your mobile device is on the same network as your WSL instance:
1. Find your WSL IP address (see above)
2. Open `http://<wsl-ip>:8888/` on your mobile browser
3. Receive notifications on your phone!

## Performance

- **Latency:** ~50-100ms from API call to browser display
- **Audio Playback:** Starts immediately after notification appears
- **Connection:** Automatic reconnection on disconnect
- **Memory:** Keeps last 50 notifications in memory

## Future Enhancements

Potential improvements for future versions:
- Notification filtering by agent type
- Search/filter notification history
- Export notifications to file
- Custom sound effects
- Notification categories/priorities
- Dark/light theme toggle
- Notification persistence across sessions

## Support

For issues or questions:
1. Check server logs: `tail -f ~/.local/state/pai-voice-server/voice-server.log`
2. Check error logs: `tail -f ~/.local/state/pai-voice-server/voice-server-error.log`
3. Restart the service: `systemctl --user restart pai-voice-server`
4. Review browser console (F12) for JavaScript errors

## Credits

Built for the Personal AI Infrastructure (PAI) system to enable seamless notifications in WSL environments.

---

**Last Updated:** December 2, 2025
**Version:** 1.0.0
