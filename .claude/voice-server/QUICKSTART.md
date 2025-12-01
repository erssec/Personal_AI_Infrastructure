# PAI Voice Server - Quick Start Guide

Get voice notifications working in 5 minutes with ElevenLabs TTS on Ubuntu Linux.

## Prerequisites

- Ubuntu Linux 20.04+ (or other systemd-based distribution)
- [Bun](https://bun.sh) runtime
- Audio player: mpg123 or ffmpeg
- Desktop notifications: libnotify-bin
- ElevenLabs account (free tier available)

## Step 1: Install Dependencies

**Install Bun:**
```bash
curl -fsSL https://bun.sh/install | bash
```

**Install audio player (choose one):**
```bash
# Option 1: mpg123 (recommended, lightweight)
sudo apt-get install mpg123

# Option 2: ffmpeg (more features)
sudo apt-get install ffmpeg
```

**Install desktop notifications:**
```bash
sudo apt-get install libnotify-bin
```

## Step 2: Get Your ElevenLabs API Key

1. Go to [elevenlabs.io](https://elevenlabs.io) and create a free account
2. Navigate to your [Profile Settings](https://elevenlabs.io/app/settings/api-keys)
3. Click "Create API Key" or copy your existing key
4. Copy the API key (starts with something like `sk_...`)

**Free Tier:** 10,000 characters/month (perfect for notifications)

## Step 3: Configure Your Environment

Add your ElevenLabs API key to `~/.env`:

```bash
# Create or edit ~/.env
echo "ELEVENLABS_API_KEY=your_api_key_here" >> ~/.env
echo "ELEVENLABS_VOICE_ID=s3TPKV1kjDlVtZbl4Ksh" >> ~/.env
```

Replace `your_api_key_here` with your actual API key from Step 2.

**Important:** The `~/.env` file should be in your home directory, NOT in the PAI directory.

## Step 4: Install the Voice Server

```bash
cd ${PAI_DIR}/voice-server
./install.sh
```

This will:
- Check for required dependencies
- Create a systemd user service for auto-start
- Start the voice server on port 8888
- Verify the installation works

## Step 5: Test It!

Send a test notification:

```bash
curl -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Voice system is working perfectly!"}'
```

You should hear the message spoken aloud and see a desktop notification!

## What's Next?

### Choose Different Voices

Browse the [ElevenLabs Voice Library](https://elevenlabs.io/voice-library) to find voices you like:

1. Click on a voice to preview it
2. Click "Use" and copy the Voice ID
3. Update `ELEVENLABS_VOICE_ID` in your `~/.env`

### Agent Voice Configuration

The PAI system supports different voices for different agents:

| Agent | Default Voice ID | Purpose |
|-------|------------------|---------|
| Kai | s3TPKV1kjDlVtZbl4Ksh | Main assistant voice |
| Perplexity-Researcher | AXdMgz6evoL7OPd7eU12 | Research agent |
| Claude-Researcher | AXdMgz6evoL7OPd7eU12 | Research agent |
| Engineer | kmSVBPu7loj4ayNinwWM | Development agent |
| Designer | ZF6FPAbjXT4488VcRRnw | Design agent |
| Pentester | hmMWXCj9K7N5mCPcRkfC | Security agent |
| Architect | muZKMsIDGYtIkjjiUS82 | Architecture agent |
| Writer | gfRt6Z3Z8aTbpLfexQ7N | Content agent |

These voice IDs are configured in your hooks and agent files.

### Desktop Integration (Optional)

The voice server integrates with your Linux desktop:

**Auto-start on login** (enabled by default):
```bash
# Check if enabled
systemctl --user is-enabled pai-voice-server

# Disable/enable auto-start
systemctl --user disable pai-voice-server
systemctl --user enable pai-voice-server
```

**Desktop notifications** appear in your system notification area (varies by desktop environment: GNOME, KDE, i3, etc.)

## Troubleshooting

### "No voice output"

**Check 1:** Verify API key is set:
```bash
grep ELEVENLABS_API_KEY ~/.env
```

**Check 2:** Test the server:
```bash
curl http://localhost:8888/health
```

Expected output:
```json
{
  "status": "healthy",
  "port": 8888,
  "voice_system": "ElevenLabs",
  "default_voice_id": "s3TPKV1kjDlVtZbl4Ksh",
  "api_key_configured": true
}
```

**Check 3:** Look at server logs:
```bash
# Using journalctl (systemd logs)
journalctl --user -u pai-voice-server -n 50

# Or view log files directly
tail -f ~/.local/state/pai-voice-server/voice-server.log
```

### "Port 8888 already in use"

Check what's using the port and restart:
```bash
# Check port usage
ss -ltn | grep :8888

# Kill process if needed
lsof -ti:8888 | xargs kill -9

# Restart server
cd ${PAI_DIR}/voice-server && ./restart.sh
```

### "Invalid API key"

1. Verify your API key is correct in `~/.env`
2. Check that it doesn't have extra spaces or quotes
3. Make sure you copied the entire key from ElevenLabs

## Service Management

Once installed, the voice server runs automatically. You can control it with:

```bash
# Check status
./status.sh
# or: systemctl --user status pai-voice-server

# Stop server
./stop.sh
# or: systemctl --user stop pai-voice-server

# Start server
./start.sh
# or: systemctl --user start pai-voice-server

# Restart server
./restart.sh
# or: systemctl --user restart pai-voice-server

# View logs
journalctl --user -u pai-voice-server -f

# Uninstall (removes systemd service)
./uninstall.sh
```

## API Usage

### Send a Notification

```bash
curl -X POST http://localhost:8888/notify \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Your notification message here",
    "voice_id": "s3TPKV1kjDlVtZbl4Ksh",
    "title": "Optional Title"
  }'
```

### Parameters

- `message` (required): Text to speak
- `voice_id` (optional): ElevenLabs voice ID (uses default if not specified)
- `voice_enabled` (optional): Set to `false` to disable voice
- `title` (optional): Notification title (default: "PAI Notification")

## Security Notes

- Your API key is stored securely in `~/.env` (not in code)
- Server only accepts connections from localhost
- Rate limited to 10 requests/minute
- No sensitive data is logged

## What You've Accomplished

✅ Voice server running automatically on startup
✅ High-quality AI voices for notifications
✅ Secure API key storage
✅ Simple HTTP API for integration
✅ Different voices for different agents (optional)

## Learn More

- [Full Documentation](README.md) - Complete feature guide
- [Voice System Architecture](../documentation/voice-system.md) - How it works
- [ElevenLabs Docs](https://elevenlabs.io/docs) - Voice API reference

## Need Help?

1. Check the [README](README.md) for detailed troubleshooting
2. Review server logs: `journalctl --user -u pai-voice-server -n 50`
3. Test the health endpoint: `curl http://localhost:8888/health`
4. Check service status: `systemctl --user status pai-voice-server`

---

**🎉 Congratulations!** Your PAI voice system is now set up with professional AI voices!
