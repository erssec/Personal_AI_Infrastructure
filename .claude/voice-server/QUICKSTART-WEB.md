# Quick Start: Web Notifications for WSL

## 🚀 Get Started in 30 Seconds

### 1. Open Your Browser

Navigate to:
```
http://localhost:8888/
```

### 2. You're Done!

That's it! The web interface is now open and ready to receive notifications.

## 📊 What You'll See

- **Connection Status** - Shows if you're connected to the server
- **Statistics** - Total notifications, voice messages, session time
- **Test Buttons** - Try sending a test notification
- **Notification Feed** - Real-time display of all notifications
- **Volume Control** - Adjust audio playback volume

## 🧪 Test It

Click the **"Test Voice Message"** button to hear your first notification!

## 💡 How It Works

When your PAI agents complete tasks:
1. They send notifications to the voice server
2. The server broadcasts them via WebSocket
3. Your browser receives and displays them instantly
4. Voice messages play automatically

## 🎯 Key Features

- ⚡ **Real-time** - Instant notification delivery
- 🎙️ **Voice** - Audio plays in your browser
- 📱 **Responsive** - Works on any device
- 🔄 **Auto-reconnect** - Handles disconnections gracefully
- 📊 **Statistics** - Track your notifications
- 🎨 **Beautiful** - Modern dark UI with animations

## 🔧 Troubleshooting

### Not receiving notifications?

Check the service status:
```bash
systemctl --user status pai-voice-server
```

Restart if needed:
```bash
systemctl --user restart pai-voice-server
```

### Audio not playing?

- Click anywhere on the page first (browser autoplay policy)
- Check the volume slider
- Verify your ElevenLabs API key is configured in `~/.env`

## 📖 Full Documentation

For detailed information, see: [WEB-INTERFACE.md](./WEB-INTERFACE.md)

## 🎉 Enjoy!

You can now receive voice and text notifications right in your browser, perfect for WSL where desktop notifications don't always work!

Keep the browser tab open (you can minimize the window) and you'll get notified whenever your AI agents complete tasks.
