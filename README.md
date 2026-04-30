# AaVi — AI Navigation Assistant

AaVi is an AI-powered navigation assistant designed to help visually impaired users navigate indoor and outdoor environments. It uses real-time camera analysis, on-device sensors (radar/LiDAR), voice commands, and a local AI backend to describe surroundings, detect obstacles, and provide turn-by-turn navigation guidance.

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Backend Setup](#backend-setup)
- [Flutter App Setup](#flutter-app-setup)
- [API Reference](#api-reference)
- [Screens](#screens)
- [Tech Stack](#tech-stack)

---

## Features

- **Scene Analysis** — AI describes the environment in real time using a vision model
- **Obstacle Detection** — Detects and announces nearby obstacles via camera, radar, or LiDAR
- **Turn-by-Turn Navigation** — Generates step-by-step walking directions from a camera frame
- **Room Mapping** — Builds a 360° floor plan by scanning in 4 directions
- **Voice Control** — Hands-free commands: start, stop, indoor/outdoor mode, open map, ask questions
- **Text-to-Speech** — All AI responses are spoken aloud
- **Real-time Mode** — WebSocket-based continuous frame streaming for live analysis
- **Sensor Fusion** — Combines camera AI with optional hardware radar/LiDAR readings
- **Indoor / Outdoor Mode** — Separate AI prompts optimised for each environment

---

## Architecture

```
┌─────────────────────────────────────┐
│           Flutter App (Mobile)       │
│                                     │
│  Camera  →  ApiService  →  Screens  │
│  Voice   →  TtsService              │
│  Sensors →  SensorMonitor           │
└──────────────┬──────────────────────┘
               │ HTTP / WebSocket
               ▼
┌─────────────────────────────────────┐
│         FastAPI Backend             │
│                                     │
│  /analyse   →  Moondream (vision)   │
│  /navigate  →  Moondream + Qwen     │
│  /room-map  →  Moondream + Qwen     │
│  /chat      →  Qwen 3.5:4b          │
│  /ws/realtime → WebSocket stream    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│           Ollama (Local AI)          │
│  moondream  — vision/image model    │
│  qwen3.5:4b — chat/reasoning model  │
└─────────────────────────────────────┘
```

---

## Project Structure

```
AaVi-Assist/
├── backend/
│   ├── server.py            # FastAPI server — all AI endpoints
│   └── requirements.txt     # Python dependencies
│
└── flutter_app/
    ├── lib/
    │   ├── main.dart                    # App entry point, theme setup
    │   ├── app_theme.dart               # Material 3 design system (colors, typography)
    │   │
    │   ├── screens/
    │   │   ├── splash_screen.dart       # Startup: server check + sensor detection
    │   │   ├── home_screen.dart         # Camera view, voice control, AI descriptions
    │   │   ├── navigation_map_screen.dart  # Radar map + turn-by-turn directions
    │   │   ├── room_map_screen.dart     # 360° floor plan builder
    │   │   └── settings_screen.dart     # Backend URL, connection test
    │   │
    │   ├── services/
    │   │   ├── api_service.dart         # HTTP client for all backend endpoints
    │   │   ├── app_state.dart           # Global singleton state (ChangeNotifier)
    │   │   ├── camera_service.dart      # Camera init, capture, periodic analysis
    │   │   ├── tts_service.dart         # Text-to-speech output
    │   │   ├── voice_service.dart       # Speech recognition + command parsing
    │   │   ├── realtime_service.dart    # WebSocket streaming to /ws/realtime
    │   │   ├── sensor_monitor.dart      # Proximity alerts from radar/depth
    │   │   ├── radar_service.dart       # Hardware radar integration
    │   │   ├── depth_service.dart       # LiDAR / ToF depth sensor integration
    │   │   └── room_map_service.dart    # Floor plan accumulation + scan state
    │   │
    │   ├── models/
    │   │   ├── analyse_response.dart    # Scene analysis result model
    │   │   ├── navigation_data.dart     # Turn-by-turn directions + obstacles
    │   │   ├── room_map_data.dart       # Scanned points + room scan result
    │   │   └── chat_message.dart        # Chat message model
    │   │
    │   └── widgets/
    │       ├── bottom_nav_bar.dart      # Shared bottom navigation bar
    │       ├── floor_plan_painter.dart  # Canvas painter for room map
    │       ├── radar_map_painter.dart   # Canvas painter for radar/obstacle view
    │       ├── chat_bar.dart            # Text input for asking questions
    │       ├── description_banner.dart  # AI scene description display
    │       └── status_bar.dart          # Mode/sensor status indicators
    │
    ├── assests/
    │   └── logo.png                     # App logo
    └── pubspec.yaml                     # Dependencies
```

---

## Prerequisites

### Backend
- Python 3.10+
- [Ollama](https://ollama.com) installed and running locally

### Flutter App
- Flutter 3.x SDK ([install](https://docs.flutter.dev/get-started/install))
- Android Studio or Xcode (for device deployment)
- A physical Android or iOS device (camera required)

---

## Backend Setup

### 1. Install Ollama and pull the AI models

```bash
# Install Ollama from https://ollama.com, then:
ollama pull moondream      # ~1.7 GB — vision/image analysis
ollama pull qwen3.5:4b     # ~2.3 GB — chat and reasoning
```

### 2. Install Python dependencies

```bash
cd backend
pip install -r requirements.txt
```

### 3. Start the server

```bash
uvicorn server:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`.  
Interactive docs: `http://localhost:8000/docs`

> **Network access:** To connect from a physical phone on the same Wi-Fi, use your machine's local IP address (e.g. `http://192.168.1.x:8000`) instead of `localhost`.

---

## Flutter App Setup

### 1. Install dependencies

```bash
cd flutter_app
flutter pub get
```

### 2. Run on a device

```bash
flutter run
```

> A physical device is recommended — camera and microphone features do not work on emulators.

### 3. Configure the backend URL

On first launch, open **Settings** and enter your backend URL (e.g. `http://192.168.1.x:8000`), then tap **Test Connection** to verify, and **Save Settings**.

### Android permissions

The following permissions are declared in `AndroidManifest.xml` and requested at runtime:

| Permission | Purpose |
|---|---|
| `CAMERA` | Live camera feed for AI analysis |
| `RECORD_AUDIO` | Voice command recognition |
| `INTERNET` | Backend API communication |

---

## API Reference

All endpoints are served from the FastAPI backend at port `8000`.

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Server status, model availability, uptime |
| `POST` | `/analyse` | Analyse a base64 image — returns scene description, obstacles, text |
| `POST` | `/analyse/upload` | Same as `/analyse` but accepts multipart form upload |
| `POST` | `/chat` | Text chat with optional scene context |
| `POST` | `/navigate` | Generate turn-by-turn directions from a camera frame |
| `POST` | `/room-map` | Process one directional scan for room mapping |
| `WS` | `/ws/analyse` | WebSocket: continuous frame analysis stream |
| `WS` | `/ws/realtime` | WebSocket: full real-time pipeline (analyse + snapshot Q&A) |

### Example — `/analyse`

**Request**
```json
{
  "image_base64": "<base64-encoded JPEG>",
  "mode": "indoor",
  "radar": [{ "distance_cm": 120, "angle_deg": 0 }]
}
```

**Response**
```json
{
  "description": "You are in a hallway. The path ahead is clear for about 3 metres.",
  "obstacles": [{ "label": "chair", "distance_cm": 120, "angle_deg": 15, "severity": "caution" }],
  "is_path_clear": true,
  "text_detected": null,
  "processing_ms": 1840
}
```

---

## Screens

### Splash Screen
Checks backend connectivity, detects available sensors (radar/LiDAR), and navigates to Home.

### Home
The main screen. Shows a live camera feed with:
- **LIVE badge** when real-time AI streaming is active
- **Mini floor-plan** overlay (bottom-left) linking to Room Map
- **Mic FAB** (bottom-right) for voice commands
- **Sensor distance bar** showing nearest obstacle distance
- **Voice strip** with animated waveform while listening
- **Indoor / Outdoor toggle** and **START NAV** button
- **AI description banner** showing the latest scene analysis

### Navigation Map
Radar-style obstacle map with turn-by-turn instruction cards. Tap any step to hear it spoken. Use **Prev / Scan Again / Next** to move through the route.

### Room Map
Guides the user through 4 directional scans (Forward, Right, Back, Left) to build a 360° floor plan. Shows coverage progress and obstacle markers on the canvas.

### Settings
Configure the backend URL, test the connection, and view active AI model information.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart) |
| UI design system | Material 3 — Public Sans + Lexend fonts |
| AI backend | FastAPI + Python |
| Vision model | [Moondream](https://github.com/vikhyat/moondream) via Ollama |
| Chat/reasoning model | Qwen 3.5:4b via Ollama |
| Local AI runtime | [Ollama](https://ollama.com) |
| Real-time streaming | WebSocket (`web_socket_channel`) |
| Text-to-speech | `flutter_tts` |
| Speech recognition | `speech_to_text` |
| Camera | `camera` package |

---

## License

MIT — see [LICENSE](./LICENSE).
