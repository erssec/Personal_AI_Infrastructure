#!/usr/bin/env bun
/**
 * PAIVoice - Personal AI Voice notification server using ElevenLabs TTS
 * Now with WebSocket support for browser-based notifications
 */

import { serve, type ServerWebSocket } from "bun";
import { spawn } from "child_process";
import { homedir } from "os";
import { join } from "path";
import { existsSync, readFileSync } from "fs";

// WebSocket connections
const wsClients = new Set<ServerWebSocket<unknown>>();

// Broadcast notification to all connected WebSocket clients
function broadcastNotification(data: any) {
  const message = JSON.stringify(data);
  for (const ws of wsClients) {
    try {
      ws.send(message);
    } catch (error) {
      console.error("Error sending to WebSocket client:", error);
      wsClients.delete(ws);
    }
  }
}

// Load .env from user home directory
const envPath = join(homedir(), '.env');
if (existsSync(envPath)) {
  const envContent = await Bun.file(envPath).text();
  envContent.split('\n').forEach(line => {
    const [key, value] = line.split('=');
    if (key && value && !key.startsWith('#')) {
      process.env[key.trim()] = value.trim();
    }
  });
}

const PORT = parseInt(process.env.PORT || "8888");
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;

if (!ELEVENLABS_API_KEY) {
  console.error('⚠️  ELEVENLABS_API_KEY not found in ~/.env');
  console.error('Add: ELEVENLABS_API_KEY=your_key_here');
}

// Default voice ID (Kai's voice)
const DEFAULT_VOICE_ID = process.env.ELEVENLABS_VOICE_ID || "s3TPKV1kjDlVtZbl4Ksh";

// Default model - eleven_multilingual_v2 is the current recommended model
// See: https://elevenlabs.io/docs/models#models-overview
const DEFAULT_MODEL = process.env.ELEVENLABS_MODEL || "eleven_multilingual_v2";

// Sanitize input for shell commands
function sanitizeForShell(input: string): string {
  return input.replace(/[^a-zA-Z0-9\s.,!?\-']/g, '').trim().substring(0, 500);
}

// Validate and sanitize user input
function validateInput(input: any): { valid: boolean; error?: string } {
  if (!input || typeof input !== 'string') {
    return { valid: false, error: 'Invalid input type' };
  }

  if (input.length > 500) {
    return { valid: false, error: 'Message too long (max 500 characters)' };
  }

  const dangerousPatterns = [
    /[;&|><`\$\(\)\{\}\[\]\\]/,
    /\.\.\//,
    /<script/i,
  ];

  for (const pattern of dangerousPatterns) {
    if (pattern.test(input)) {
      return { valid: false, error: 'Invalid characters in input' };
    }
  }

  return { valid: true };
}

// Generate speech using ElevenLabs API
async function generateSpeech(text: string, voiceId: string): Promise<ArrayBuffer> {
  if (!ELEVENLABS_API_KEY) {
    throw new Error('ElevenLabs API key not configured');
  }

  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
      'xi-api-key': ELEVENLABS_API_KEY,
    },
    body: JSON.stringify({
      text: text,
      model_id: DEFAULT_MODEL,
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.5,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    // Check for model-related errors
    if (errorText.includes('model') || response.status === 422) {
      throw new Error(`ElevenLabs API error: Invalid model "${DEFAULT_MODEL}". Update ELEVENLABS_MODEL in ~/.env. See https://elevenlabs.io/docs/models`);
    }
    throw new Error(`ElevenLabs API error: ${response.status} - ${errorText}`);
  }

  return await response.arrayBuffer();
}

// Play audio using mpg123 (Linux)
async function playAudio(audioBuffer: ArrayBuffer): Promise<void> {
  const tempFile = `/tmp/voice-${Date.now()}.mp3`;

  // Write audio to temp file
  await Bun.write(tempFile, audioBuffer);

  return new Promise((resolve, reject) => {
    // Try mpg123 first, fall back to ffplay if not available
    const audioPlayers = [
      { cmd: '/usr/bin/mpg123', args: ['-q', tempFile] },
      { cmd: 'mpg123', args: ['-q', tempFile] },
      { cmd: '/usr/bin/ffplay', args: ['-nodisp', '-autoexit', '-v', 'quiet', tempFile] },
      { cmd: 'ffplay', args: ['-nodisp', '-autoexit', '-v', 'quiet', tempFile] }
    ];

    let lastError: Error | null = null;

    const tryNextPlayer = (index: number) => {
      if (index >= audioPlayers.length) {
        // Clean up temp file
        spawn('/bin/rm', [tempFile]);
        reject(lastError || new Error('No audio player found. Install mpg123 or ffmpeg'));
        return;
      }

      const player = audioPlayers[index];
      const proc = spawn(player.cmd, player.args);

      proc.on('error', (error) => {
        lastError = error;
        tryNextPlayer(index + 1);
      });

      proc.on('exit', (code) => {
        // Clean up temp file
        spawn('/bin/rm', [tempFile]);

        if (code === 0) {
          resolve();
        } else {
          lastError = new Error(`${player.cmd} exited with code ${code}`);
          tryNextPlayer(index + 1);
        }
      });
    };

    tryNextPlayer(0);
  });
}

// Spawn a process safely
function spawnSafe(command: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args);

    proc.on('error', (error) => {
      console.error(`Error spawning ${command}:`, error);
      reject(error);
    });

    proc.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`${command} exited with code ${code}`));
      }
    });
  });
}

// Send Linux notification with voice and broadcast to web clients
async function sendNotification(
  title: string,
  message: string,
  voiceEnabled = true,
  voiceId: string | null = null
) {
  // Validate inputs
  const titleValidation = validateInput(title);
  const messageValidation = validateInput(message);

  if (!titleValidation.valid) {
    throw new Error(`Invalid title: ${titleValidation.error}`);
  }

  if (!messageValidation.valid) {
    throw new Error(`Invalid message: ${messageValidation.error}`);
  }

  // Sanitize inputs
  const safeTitle = sanitizeForShell(title);
  const safeMessage = sanitizeForShell(message);

  let audioBase64: string | null = null;

  // Generate and play voice using ElevenLabs
  if (voiceEnabled && ELEVENLABS_API_KEY) {
    try {
      const voice = voiceId || DEFAULT_VOICE_ID;
      console.log(`🎙️  Generating speech with ElevenLabs (voice: ${voice})`);

      const audioBuffer = await generateSpeech(safeMessage, voice);

      // Convert audio buffer to base64 for web clients
      audioBase64 = Buffer.from(audioBuffer).toString('base64');

      // Server-side audio playback disabled to prevent duplicate playback
      // (audio is played in the web client via autoplay)
      // Uncomment below if you want local server-side playback:
      // try {
      //   await playAudio(audioBuffer);
      // } catch (error) {
      //   console.log("Local audio playback not available (expected in WSL)");
      // }
    } catch (error) {
      console.error("Failed to generate/play speech:", error);
    }
  }

  // Broadcast to all WebSocket clients
  broadcastNotification({
    type: 'notification',
    title: safeTitle,
    message: safeMessage,
    voiceEnabled,
    voiceId: voiceId || DEFAULT_VOICE_ID,
    audio: audioBase64,
    timestamp: Date.now()
  });

  // Display Linux desktop notification using notify-send (will fail in WSL)
  try {
    // Try different notify-send locations
    const notifyCmds = ['/usr/bin/notify-send', 'notify-send'];

    for (const cmd of notifyCmds) {
      try {
        await spawnSafe(cmd, ['-u', 'normal', '-t', '5000', safeTitle, safeMessage]);
        break; // Success, no need to try other commands
      } catch (error) {
        // Try next command
        continue;
      }
    }
  } catch (error) {
    // Silently fail in WSL - web interface will handle notifications
  }
}

// Rate limiting
const requestCounts = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT = 10;
const RATE_WINDOW = 60000;

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const record = requestCounts.get(ip);

  if (!record || now > record.resetTime) {
    requestCounts.set(ip, { count: 1, resetTime: now + RATE_WINDOW });
    return true;
  }

  if (record.count >= RATE_LIMIT) {
    return false;
  }

  record.count++;
  return true;
}

// Start HTTP server with WebSocket support
const server = serve({
  port: PORT,
  async fetch(req, server) {
    const url = new URL(req.url);

    // WebSocket upgrade
    if (url.pathname === "/ws") {
      const upgraded = server.upgrade(req);
      if (!upgraded) {
        return new Response("WebSocket upgrade failed", { status: 500 });
      }
      return undefined;
    }

    // Serve static files
    if (url.pathname === "/" || url.pathname === "/index.html") {
      const htmlPath = join(__dirname, "public", "index.html");
      if (existsSync(htmlPath)) {
        const html = readFileSync(htmlPath, "utf-8");
        return new Response(html, {
          headers: { "Content-Type": "text/html" },
          status: 200
        });
      } else {
        // Return a simple HTML page if file doesn't exist yet
        return new Response(`
<!DOCTYPE html>
<html>
<head>
  <title>PAI Voice Server</title>
</head>
<body>
  <h1>PAI Voice Server</h1>
  <p>Web interface not yet installed. Please create public/index.html</p>
</body>
</html>
        `, {
          headers: { "Content-Type": "text/html" },
          status: 200
        });
      }
    }

    const clientIp = req.headers.get('x-forwarded-for') || 'localhost';

    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type"
    };

    if (req.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders, status: 204 });
    }

    if (!checkRateLimit(clientIp)) {
      return new Response(
        JSON.stringify({ status: "error", message: "Rate limit exceeded" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 429
        }
      );
    }

    if (url.pathname === "/notify" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "PAI Notification";
        const message = data.message || "Task completed";
        const voiceEnabled = data.voice_enabled !== false;
        const voiceId = data.voice_id || data.voice_name || null; // Support both voice_id and voice_name

        if (voiceId && typeof voiceId !== 'string') {
          throw new Error('Invalid voice_id');
        }

        console.log(`📨 Notification: "${title}" - "${message}" (voice: ${voiceEnabled}, voiceId: ${voiceId || DEFAULT_VOICE_ID})`);

        await sendNotification(title, message, voiceEnabled, voiceId);

        return new Response(
          JSON.stringify({ status: "success", message: "Notification sent" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("Notification error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: error.message?.includes('Invalid') ? 400 : 500
          }
        );
      }
    }

    if (url.pathname === "/pai" && req.method === "POST") {
      try {
        const data = await req.json();
        const title = data.title || "PAI Assistant";
        const message = data.message || "Task completed";

        console.log(`🤖 PAI notification: "${title}" - "${message}"`);

        await sendNotification(title, message, true, null);

        return new Response(
          JSON.stringify({ status: "success", message: "PAI notification sent" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200
          }
        );
      } catch (error: any) {
        console.error("PAI notification error:", error);
        return new Response(
          JSON.stringify({ status: "error", message: error.message || "Internal server error" }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: error.message?.includes('Invalid') ? 400 : 500
          }
        );
      }
    }

    if (url.pathname === "/health") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          port: PORT,
          voice_system: "ElevenLabs",
          model: DEFAULT_MODEL,
          default_voice_id: DEFAULT_VOICE_ID,
          api_key_configured: !!ELEVENLABS_API_KEY
        }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200
        }
      );
    }

    return new Response("PAIVoice Server - POST to /notify or /pai", {
      headers: corsHeaders,
      status: 200
    });
  },
  websocket: {
    open(ws) {
      wsClients.add(ws);
      console.log(`🔌 WebSocket client connected (${wsClients.size} total)`);

      // Send welcome message
      ws.send(JSON.stringify({
        type: 'welcome',
        message: 'Connected to PAI Voice Server',
        timestamp: Date.now()
      }));
    },
    message(ws, message) {
      console.log(`📨 WebSocket message:`, message);
    },
    close(ws) {
      wsClients.delete(ws);
      console.log(`🔌 WebSocket client disconnected (${wsClients.size} remaining)`);
    },
    error(ws, error) {
      console.error("WebSocket error:", error);
      wsClients.delete(ws);
    }
  }
});

console.log(`🚀 PAIVoice Server running on port ${PORT}`);
console.log(`🎙️  Using ElevenLabs TTS (model: ${DEFAULT_MODEL}, voice: ${DEFAULT_VOICE_ID})`);
console.log(`📡 POST to http://localhost:${PORT}/notify`);
console.log(`🌐 Web interface: http://localhost:${PORT}/`);
console.log(`🔌 WebSocket: ws://localhost:${PORT}/ws`);
console.log(`🔒 Security: CORS enabled, rate limiting active`);
console.log(`🔑 API Key: ${ELEVENLABS_API_KEY ? '✅ Configured' : '❌ Missing'}`);
