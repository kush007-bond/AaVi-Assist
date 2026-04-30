# VisionAid — MVP PRD & Integration Plan
> Hackathon Edition · Backend: Python FastAPI + Ollama · Frontend: Flutter

---

## 1. Product Overview

VisionAid is a real-time AI-powered navigation assistant for visually impaired users. It captures camera frames at mode-adaptive rates, sends them to a local AI model via a FastAPI backend, receives scene descriptions and obstacle warnings, and reads them aloud to the user. An optional radar sensor provides additional proximity detection and surrounding mapping.

### Core Value Proposition
- **Hear what you cannot see** — AI describes the scene instantly
- **Radar safety net** — hardware proximity alerts before the camera can warn
- **Always-on chat bar** — user can ask follow-up questions any time
- **Works everywhere** — Flutter targets mobile (iOS/Android) + web

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Frontend                        │
│  ┌──────────┐  ┌────────────┐  ┌───────────┐  ┌─────────┐ │
│  │ Camera   │  │ Mode Ctrl  │  │ Radar API │  │  Chat   │ │
│  │ Service  │  │ Indoor 3.5s│  │ (sensor)  │  │  Bar    │ │
│  │         │  │ Outdoor1.5s│  │           │  │         │ │
│  └────┬─────┘  └─────┬──────┘  └─────┬─────┘  └────┬────┘ │
│       └──────────────┴──────────────┴──────────────┘       │
│                         HTTP / WS                           │
└───────────────────────────┬─────────────────────────────────┘
                            │  Cloudflare Tunnel
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Server (local PC)                  │
│  POST /analyse   POST /chat   WS /ws/analyse   GET /health  │
│                         │                                    │
│                    Ollama (local)                            │
│              LLaVA (vision) · Llama3 (chat)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Feature Breakdown (MVP Scope)

| # | Feature | Priority | Who builds |
|---|---------|----------|------------|
| F1 | Camera frame capture with interval modes | P0 | Flutter |
| F2 | Indoor (3.5s) / Outdoor (1.5s) mode toggle | P0 | Flutter |
| F3 | Frame → base64 → POST /analyse | P0 | Flutter + FastAPI |
| F4 | LLaVA scene description response | P0 | FastAPI + Ollama |
| F5 | TTS read-aloud of description | P0 | Flutter |
| F6 | Radar sensor detection on app launch | P1 | Flutter |
| F7 | Radar distance → /analyse payload | P1 | Flutter + FastAPI |
| F8 | Radar warning alert (< 80 cm) | P1 | FastAPI |
| F9 | Surrounding text map generation | P1 | FastAPI |
| F10 | Persistent bottom chat bar | P1 | Flutter |
| F11 | POST /chat with scene context | P1 | Flutter + FastAPI |
| F12 | Settings screen: backend URL + status | P1 | Flutter |
| F13 | Start/Stop toggle for analysis | P1 | Flutter |
| F14 | Health check on URL save | P1 | Flutter + FastAPI |

---

## 4. API Specification

### `GET /health`
Called when the app opens or user saves a new backend URL.

**Response:**
```json
{
  "status": "ok",
  "ollama_reachable": true,
  "vision_model": "llava",
  "text_model": "llama3",
  "timestamp": "2025-01-01T00:00:00Z"
}
```
Flutter shows a green dot if `ollama_reachable == true`.

---

### `POST /analyse`
Main vision endpoint. Called every `interval` seconds when running.

**Request:**
```json
{
  "image_base64": "<base64 string>",
  "mode": "indoor",
  "radar": [
    { "distance_cm": 45.0, "angle_deg": 0 }
  ]
}
```

**Response:**
```json
{
  "description": "You are standing in a hallway. There is a chair about two metres to your right and a door ahead.",
  "obstacles": ["chair — right", "door — ahead"],
  "warnings": [],
  "map_text": "WALL-LEFT | PATH-AHEAD | CHAIR-RIGHT",
  "radar_warning": null,
  "mode": "indoor",
  "processing_ms": 1240
}
```

`radar_warning` is non-null and spoken immediately when an object is within 80 cm.

---

### `POST /analyse/upload`
Multipart form alternative — easier with Flutter's `camera` package.

**Form fields:** `file` (image), `mode` (string), `radar_json` (optional JSON string)

---

### `POST /chat`
Bottom chat bar. Maintains conversation history client-side.

**Request:**
```json
{
  "messages": [
    { "role": "user", "content": "Is the path ahead clear?" }
  ],
  "context": "You are standing in a hallway. There is a chair about two metres to your right."
}
```

**Response:**
```json
{
  "reply": "Yes, the path ahead appears clear based on the last scene. The chair is to your right, so keep left.",
  "processing_ms": 890
}
```

---

### `WS /ws/analyse`
WebSocket for lower-latency continuous streaming (optional, advanced).

Client sends: `{ "image_base64": "...", "mode": "outdoor", "radar": [...] }`  
Server replies with same structure as `/analyse`.

---

## 5. Flutter Frontend Specification

### 5.1 Screen Map
```
App
├── SplashScreen          ← runs radar check, loads saved URL
├── HomeScreen
│   ├── CameraPreview     ← fills top 70% of screen
│   ├── StatusBar         ← mode label, interval, radar dot, start/stop
│   ├── DescriptionBanner ← last spoken description (scrolling text)
│   └── ChatBar           ← persistent bottom input + messages
└── SettingsScreen
    ├── Backend URL field
    ├── "Test Connection" button → GET /health
    ├── Status indicator (green/red dot + latency)
    └── Model info display
```

### 5.2 Camera Service (Dart pseudocode)

```dart
class CameraService {
  Timer? _timer;
  double get interval => _mode == 'indoor' ? 3.5 : 1.5;

  void start(String mode) {
    _mode = mode;
    _timer = Timer.periodic(
      Duration(milliseconds: (interval * 1000).toInt()),
      (_) => _captureAndSend(),
    );
  }

  void stop() => _timer?.cancel();

  Future<void> _captureAndSend() async {
    final image = await _controller.takePicture();
    final bytes  = await image.readAsBytes();
    final b64    = base64Encode(bytes);
    final radar  = await RadarService.getReadings();  // null if no sensor
    final result = await ApiService.analyse(b64, _mode, radar);
    TtsService.speak(result.radarWarning ?? result.description);
    setState(() => _lastResult = result);
  }
}
```

### 5.3 Radar Sensor Detection

On app launch (`initState` of SplashScreen):

```dart
Future<bool> detectRadarSensor() async {
  // Check for USB serial / Bluetooth / BLE sensor
  // For MVP: check if a known radar plugin/package reports a device
  try {
    final devices = await FlutterBlue.instance.connectedDevices;
    final radar = devices.firstWhereOrNull(
      (d) => d.name.toLowerCase().contains('radar') ||
             d.name.toLowerCase().contains('hc-sr04'),
    );
    return radar != null;
  } catch (_) {
    return false;  // no sensor, camera-only mode
  }
}
```

If radar is detected: show radar icon in status bar and include readings in each `/analyse` call.  
If not detected: silently continue with camera-only mode — no error shown.

### 5.4 Settings Screen — Key Behaviours

- URL is persisted in `SharedPreferences` key `backend_url`
- On "Test Connection" tap: call `GET /health`, show result inline
- Status dot: green = `ollama_reachable: true`, amber = server up but Ollama down, red = no connection
- Start/Stop button on HomeScreen sends a simple state toggle — no backend call needed
- Default URL: `http://localhost:8000` (for emulator); override for Cloudflare tunnel

### 5.5 Chat Bar

- Sits at the bottom, always visible (even during camera mode)
- Sends user message to `POST /chat` with full `messages` history array
- Includes `context` = last `description` from `/analyse` response
- Replies are also read aloud via TTS
- Messages scroll upward above the input field

---

## 6. Backend Setup Guide

### 6.1 Prerequisites
```bash
# Python 3.11+
pip install fastapi uvicorn httpx python-multipart pydantic

# Ollama
curl -fsSL https://ollama.ai/install.sh | sh
ollama pull llava      # ~4 GB — vision model
ollama pull llama3     # ~4 GB — chat model
```

### 6.2 Run the server
```bash
# Start Ollama (runs in background automatically after install)
ollama serve   # if not already running as a service

# Start FastAPI
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

### 6.3 Expose via Cloudflare Tunnel
```bash
# Install cloudflared
brew install cloudflared          # macOS
# or download binary from https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/

# Create tunnel (no account needed for quick tunnel)
cloudflared tunnel --url http://localhost:8000
```
Copy the generated `https://xxxx.trycloudflare.com` URL and paste it into the Flutter Settings screen.

### 6.4 Quick API test
```bash
# Health
curl https://xxxx.trycloudflare.com/health

# Analyse (provide a real base64 image)
curl -X POST https://xxxx.trycloudflare.com/analyse \
  -H "Content-Type: application/json" \
  -d '{"image_base64": "<b64>", "mode": "indoor"}'
```

---

## 7. Flutter Package Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  camera: ^0.10.5
  flutter_tts: ^3.8.5
  http: ^1.2.0
  shared_preferences: ^2.2.2
  flutter_blue_plus: ^1.29.0   # for radar BLE detection
  permission_handler: ^11.3.0
```

---

## 8. Data Flow (Step-by-Step)

```
1. App launches
   └─ SplashScreen.initState()
       ├─ Load saved backend URL from SharedPreferences
       ├─ GET /health → show connection status
       └─ RadarService.detectSensor() → set global hasRadar flag

2. User taps START (HomeScreen)
   └─ CameraService.start(mode)
       └─ Every interval seconds:
           ├─ camera.takePicture() → bytes → base64
           ├─ RadarService.getReadings() → [{distance_cm, angle_deg}] or null
           ├─ POST /analyse → AnalyseResponse
           └─ TtsService.speak(radarWarning ?? description)

3. User types in chat bar
   └─ Append to messages list
       └─ POST /chat {messages, context: lastDescription}
           └─ TtsService.speak(reply)

4. User taps STOP
   └─ CameraService.stop() → Timer cancelled

5. User opens Settings
   └─ Pastes new URL → taps "Test" → GET /health → show status dot
```

---

## 9. Error Handling

| Scenario | Backend response | Flutter action |
|----------|-----------------|----------------|
| Ollama not running | 503 + message | Show toast "AI model offline" |
| Bad image data | 400 | Skip frame silently, log |
| Timeout (>30s) | 504 / timeout | Skip frame, reduce interval by 0.5s |
| No network | — | TTS: "Connection lost, retrying" |
| Radar disconnected mid-session | — | Fall back to camera-only silently |

---

## 10. Radar Sensor Integration Details

### Supported Sensor Types (MVP)
- **BLE sensors** — detected via `flutter_blue_plus`
- **USB serial** — HC-SR04 via Arduino + serial bridge (advanced)
- **Web Bluetooth** — for web target

### Warning Thresholds
| Distance | Action |
|----------|--------|
| > 150 cm | No warning, include in map |
| 80–150 cm | "Obstacle nearby — proceed carefully" |
| < 80 cm | `radarWarning` — spoken immediately, overrides scene description |
| < 30 cm | "STOP — obstacle very close" |

### Text Map Format
The backend generates a simple one-line map string, e.g.:
```
WALL-LEFT | CLEAR-AHEAD | DOOR-RIGHT-FAR
```
This is shown in the DescriptionBanner and can be read aloud on demand.

---

## 11. Presentation Talking Points (for Judges)

1. **Multimodal AI on a budget** — LLaVA + Llama3 running fully locally via Ollama; no OpenAI costs
2. **Adaptive capture rate** — indoor/outdoor modes optimise for latency vs accuracy
3. **Hardware sensor fusion** — radar + camera gives two layers of obstacle detection
4. **Cross-platform** — one Flutter codebase for iOS, Android, and web
5. **Real-time TTS pipeline** — description → speech under 2 seconds on a mid-range laptop
6. **Privacy-first** — all processing local; no images leave the device network

---

## 12. File Structure

```
visionaid/
├── backend/
│   └── server.py               ← single-file FastAPI backend
├── flutter_app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart        ← /analyse, /chat, /health calls
│   │   │   ├── camera_service.dart     ← interval capture
│   │   │   ├── radar_service.dart      ← BLE sensor detection
│   │   │   └── tts_service.dart        ← flutter_tts wrapper
│   │   ├── models/
│   │   │   ├── analyse_response.dart
│   │   │   └── chat_message.dart
│   │   └── widgets/
│   │       ├── status_bar.dart
│   │       ├── description_banner.dart
│   │       └── chat_bar.dart
│   └── pubspec.yaml
└── VISIONAID_PRD_AND_PLAN.md   ← this file
```

---

## 13. Claude Code Instructions

When using Claude Code to build the Flutter app, pass these instructions:

```
Build a Flutter app called VisionAid with the following spec:

SCREENS:
1. SplashScreen — on init: load SharedPreferences key "backend_url" (default "http://localhost:8000"),
   call GET {backend_url}/health, set global connectionStatus and hasRadar flag,
   navigate to HomeScreen after 1.5s.

2. HomeScreen — top 70%: CameraPreview widget. Below it: StatusBar row showing mode label,
   interval, radar dot (green if hasRadar), and a Start/Stop FAB.
   Below that: DescriptionBanner (last analysis description, auto-scrolling).
   Bottom: ChatBar (always visible, TextField + Send button).
   On Start: call CameraService.start(mode). On Stop: CameraService.stop().

3. SettingsScreen — TextField for backend URL, "Test Connection" button that calls GET /health
   and shows status (green dot = ok, red = error). Displays vision_model and text_model from response.
   Save URL to SharedPreferences on confirm.

SERVICES:
- ApiService: http package. analyse(b64, mode, radar?) → POST /analyse. chat(messages, context?) → POST /chat.
- CameraService: Timer-based, interval = mode=="indoor" ? 3500ms : 1500ms. On tick: take picture,
  base64 encode, call ApiService.analyse, then TtsService.speak(result.radarWarning ?? result.description).
- TtsService: flutter_tts wrapper. speak(text) cancels previous then speaks.
- RadarService: use flutter_blue_plus to scan for connected BLE devices on launch.
  Return hasRadar bool. If has radar, getReadings() returns mock [{distance_cm: 120, angle_deg: 0}]
  for MVP (real sensor integration is hardware-specific).

MODELS:
- AnalyseResponse: description, obstacles (List<String>), warnings (List<String>),
  map_text, radar_warning (nullable), mode, processing_ms
- ChatMessage: role, content

UI STYLE: Minimal dark theme. Use black background, white text, green accents.
No unnecessary animations. Accessibility first — large text, high contrast.

IMPORTANT: No form widgets. Use StatefulWidget + setState. 
Persist backend URL in SharedPreferences.
```

---

## 14. Known MVP Limitations & Hackathon Trade-offs

- Radar readings are mocked in Flutter MVP — real BLE parsing depends on sensor hardware
- LLaVA response time varies (1–4s on GPU, 5–15s on CPU) — show a loading spinner
- No authentication on the FastAPI server — fine for local + tunnel demo
- WebSocket (`/ws/analyse`) is implemented but optional; use REST for demo stability
- Ollama must be running before the server starts

---

*Built for hackathon demo. Designed to be extended into a full product.*
