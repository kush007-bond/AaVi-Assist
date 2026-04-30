"""
VisionAid Backend Server
FastAPI + Ollama — Hackathon MVP
Vision model : moondream  (real image analysis, ~1.7 GB)
Chat model   : qwen3.5:4b (fast reasoning for Q&A)

Run: uvicorn server:app --host 0.0.0.0 --port 8000 --reload
"""

import asyncio
import base64
import io
import json
import re
import time
from datetime import datetime
from typing import Optional, List

from PIL import Image

import httpx
from fastapi import FastAPI, UploadFile, File, Form, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# ──────────────────────────────────────────────
# CONFIG
# ──────────────────────────────────────────────
OLLAMA_BASE_URL = "http://localhost:11434"
VISION_MODEL    = "moondream"      # real multimodal — ollama pull moondream
TEXT_MODEL      = "qwen3.5:4b"    # fast chat / reasoning

# ──────────────────────────────────────────────
# APP
# ──────────────────────────────────────────────
app = FastAPI(title="VisionAid API", version="1.1.0-mvp")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ──────────────────────────────────────────────
# PYDANTIC MODELS
# ──────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str
    ollama_reachable: bool
    vision_model: str
    text_model: str
    vision_model_loaded: bool
    timestamp: str

class RadarReading(BaseModel):
    distance_cm: float
    angle_deg: Optional[float] = 0

class DepthReading(BaseModel):
    """From device LiDAR / depth camera (ARKit / ARCore)."""
    distance_cm: float
    angle_deg: Optional[float] = 0
    source: Optional[str] = "lidar"  # "lidar" | "tof" | "stereo"

class AnalyseRequest(BaseModel):
    image_base64: str
    mode: str = "indoor"                          # "indoor" | "outdoor"
    radar: Optional[List[RadarReading]] = None    # BLE/USB radar readings
    depth: Optional[List[DepthReading]] = None    # device LiDAR / ToF readings
    history: Optional[List[dict]] = None
    # For approaching-object detection: pass the minimum distance from last scan
    prev_min_distance_cm: Optional[float] = None

class AnalyseResponse(BaseModel):
    description: str
    obstacles: List[str]
    warnings: List[str]
    map_text: str
    radar_warning: Optional[str] = None
    depth_warning: Optional[str] = None
    text_detected: Optional[str] = None          # any text/signs found in scene
    approaching_warning: Optional[str] = None    # object approaching from beyond sensor limit
    mode: str
    processing_ms: int

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    context: Optional[str] = None

class ChatResponse(BaseModel):
    reply: str
    processing_ms: int

# ── Room mapping models ──────────────────────

class RoomScanRequest(BaseModel):
    image_base64: str
    mode: str = "indoor"
    radar: Optional[List[RadarReading]] = None
    depth: Optional[List[DepthReading]] = None
    heading_deg: float = 0          # which direction user is currently facing (0=forward, 90=right, 180=back, 270=left)
    scan_index: int = 0             # 0-based sequential scan number

class MappedPoint(BaseModel):
    label: str
    distance_cm: float
    angle_deg: float                # relative to current facing direction
    severity: str = "info"

class RoomScanResponse(BaseModel):
    heading_deg: float
    scan_index: int
    obstacles: List[MappedPoint]    # obstacles found at this heading
    walking_instruction: str        # spoken guidance for the next step
    processing_ms: int

# ── Navigation map models ──────────────────────

class NavigateRequest(BaseModel):
    image_base64: str
    mode: str = "indoor"
    radar: Optional[List[RadarReading]] = None
    depth: Optional[List[DepthReading]] = None

class ObstaclePoint(BaseModel):
    label: str
    distance_cm: float
    angle_deg: float           # 0 = straight ahead, -90 = left, +90 = right
    severity: str = "info"    # "danger" (<80 cm) | "caution" (80-150) | "info" (>150)

class NavigateResponse(BaseModel):
    obstacles: List[ObstaclePoint]   # all detected obstacles with positions
    safe_angle_deg: float            # recommended direction (-90 to +90)
    instructions: List[str]          # ordered step-by-step route text
    spoken_instruction: str          # single TTS sentence for current step
    is_path_clear: bool
    processing_ms: int

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

async def _check_model_loaded(model: str) -> bool:
    """Return True if Ollama has the model available."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as c:
            r = await c.get(f"{OLLAMA_BASE_URL}/api/tags")
            names = [m["name"] for m in r.json().get("models", [])]
            return any(model in n for n in names)
    except Exception:
        return False


def _normalise_to_png_b64(image_b64: str) -> str:
    """
    Decode base64 image, convert to RGB PNG, re-encode as base64.
    moondream in Ollama handles PNG reliably; JPEG sometimes crashes the runner.
    Also caps size to 512×512 to avoid OOM on the model runner.
    """
    raw = base64.b64decode(image_b64)
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    img.thumbnail((512, 512), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


async def ollama_vision(image_b64: str, prompt: str, timeout: float = 90.0) -> str:
    """
    Call moondream with the real image (normalised to PNG ≤ 512×512).
    """
    png_b64 = _normalise_to_png_b64(image_b64)
    payload = {
        "model": VISION_MODEL,
        "prompt": prompt,
        "images": [png_b64],
        "stream": False,
    }
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(f"{OLLAMA_BASE_URL}/api/generate", json=payload)
        resp.raise_for_status()
        return resp.json().get("response", "").strip()


async def ollama_chat(messages: list, timeout: float = 60.0) -> str:
    """Call qwen3.5:4b for chat — no image."""
    payload = {
        "model": TEXT_MODEL,
        "messages": messages,
        "stream": False,
        "think": False,
    }
    async with httpx.AsyncClient(timeout=timeout) as client:
        resp = await client.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload)
        resp.raise_for_status()
        return resp.json().get("message", {}).get("content", "").strip()


async def structured_scene(raw_description: str, mode: str,
                            proximity_note: str, timeout: float = 30.0) -> dict:
    """
    Step 2: take moondream's free-text description and ask qwen3.5 to
    turn it into the structured JSON we need.  This decouples vision from
    reasoning so each model does what it's good at.
    """
    mode_note = (
        "indoors — focus on furniture, walls, steps, narrow passages"
        if mode == "indoor"
        else "outdoors — focus on curbs, vehicles, people, poles, uneven ground"
    )
    prompt = (
        f"You are processing a scene description for a visually impaired person who is {mode_note}.\n"
        f"{proximity_note}"
        f"Raw scene description from vision sensor:\n\"{raw_description}\"\n\n"
        "Convert this into a JSON object with EXACTLY these keys "
        "(no markdown fences, no extra text):\n"
        "{\n"
        '  "description": "<2-3 warm, clear spoken sentences the user will hear>",\n'
        '  "obstacles": ["<item — position>"],\n'
        '  "warnings": ["<urgent warning for anything within 1 m or dangerous>"],\n'
        '  "map_text": "<one-line layout e.g. WALL-LEFT | PATH-CLEAR | TABLE-RIGHT>",\n'
        '  "text_detected": "<exact text/words visible in the scene, or null if none>"\n'
        "}\n"
        "Use [] for obstacles/warnings if path is clear. "
        "Set text_detected to null if no readable text, signs, or labels are visible. "
        "Return ONLY the JSON object."
    )
    messages = [{"role": "user", "content": prompt}]
    payload = {
        "model": TEXT_MODEL,
        "messages": messages,
        "stream": False,
        "think": False,
    }
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload)
            resp.raise_for_status()
            raw = resp.json().get("message", {}).get("content", "").strip()
            return _parse_json(raw)
    except Exception:
        # fallback — use raw description directly
        return {
            "description": raw_description,
            "obstacles": [],
            "warnings": [],
            "map_text": "Scene map unavailable.",
        }


def _parse_json(raw: str) -> dict:
    """Robustly extract the JSON object from a model response."""
    # strip <think> blocks
    cleaned = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL).strip()
    # strip markdown fences
    cleaned = re.sub(r"^```[a-z]*\n?", "", cleaned).rstrip("`").strip()
    # find first {...}
    m = re.search(r"\{.*\}", cleaned, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(0))
        except Exception:
            pass
    # last resort
    return {
        "description": cleaned or "Could not analyse scene.",
        "obstacles": [],
        "warnings": [],
        "map_text": "—",
    }


def _proximity_warning(
    radar: Optional[List[RadarReading]],
    depth: Optional[List[DepthReading]],
) -> tuple[Optional[str], Optional[str], str]:
    """
    Returns (radar_warning, depth_warning, proximity_note_for_prompt).
    Merges hardware sensor readings into urgency tiers.
    """
    radar_warn = None
    depth_warn = None
    notes = []

    # ── radar
    if radar:
        closest_r = min(radar, key=lambda r: r.distance_cm)
        d = closest_r.distance_cm
        angle_str = f" at {closest_r.angle_deg:.0f}°" if closest_r.angle_deg else ""
        if d < 30:
            radar_warn = f"STOP — obstacle {d:.0f} cm ahead{angle_str}. Do not move."
        elif d < 80:
            radar_warn = f"CAUTION: obstacle {d:.0f} cm ahead{angle_str}. Slow down."
        elif d < 150:
            notes.append(f"Radar: object {d:.0f} cm ahead{angle_str} — proceed carefully.")

    # ── device LiDAR / depth camera
    if depth:
        closest_d = min(depth, key=lambda x: x.distance_cm)
        d = closest_d.distance_cm
        src = closest_d.source or "depth sensor"
        angle_str = f" at {closest_d.angle_deg:.0f}°" if closest_d.angle_deg else ""
        if d < 30:
            depth_warn = f"STOP — {src} detects object {d:.0f} cm ahead{angle_str}."
        elif d < 80:
            depth_warn = f"CAUTION ({src}): object {d:.0f} cm ahead{angle_str}."
        elif d < 150:
            notes.append(f"{src.title()}: object {d:.0f} cm ahead{angle_str}.")

    prompt_note = ("\n".join(notes) + "\n") if notes else ""
    return radar_warn, depth_warn, prompt_note


# ──────────────────────────────────────────────
# ROUTES
# ──────────────────────────────────────────────

@app.get("/")
async def root():
    return {"message": "VisionAid API is running. Hit /health for status."}


@app.get("/health", response_model=HealthResponse)
async def health_check():
    try:
        async with httpx.AsyncClient(timeout=5.0) as c:
            r = await c.get(f"{OLLAMA_BASE_URL}/api/tags")
            ollama_ok = r.status_code == 200
            names = [m["name"] for m in r.json().get("models", [])] if ollama_ok else []
    except Exception:
        ollama_ok = False
        names = []

    vision_loaded = any(VISION_MODEL in n for n in names)

    return HealthResponse(
        status="ok" if (ollama_ok and vision_loaded) else "degraded",
        ollama_reachable=ollama_ok,
        vision_model=VISION_MODEL,
        text_model=TEXT_MODEL,
        vision_model_loaded=vision_loaded,
        timestamp=datetime.utcnow().isoformat() + "Z",
    )


@app.post("/analyse", response_model=AnalyseResponse)
async def analyse_frame(request: AnalyseRequest):
    """
    Two-step pipeline:
      1. moondream  → free-text scene description from the real image
      2. qwen3.5:4b → structured JSON (obstacles, warnings, map)
    """
    t0 = time.time()

    try:
        base64.b64decode(request.image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data.")

    # ── sensor warnings (hardware layer — independent of AI)
    radar_warn, depth_warn, proximity_note = _proximity_warning(
        request.radar, request.depth
    )

    # ── Approaching-object warning (compare current vs previous sensor distances) ──
    approaching_warn: Optional[str] = None
    current_sensor_readings = (request.radar or []) + [
        RadarReading(distance_cm=d.distance_cm, angle_deg=d.angle_deg)
        for d in (request.depth or [])
    ]
    if current_sensor_readings and request.prev_min_distance_cm is not None:
        current_min = min(r.distance_cm for r in current_sensor_readings)
        delta = request.prev_min_distance_cm - current_min
        if delta > 40:  # moved 40+ cm closer since last scan → actively approaching
            closest = min(current_sensor_readings, key=lambda r: r.distance_cm)
            angle_str = ""
            if closest.angle_deg and abs(closest.angle_deg) > 10:
                angle_str = " on your right" if closest.angle_deg > 0 else " on your left"
            approaching_warn = (
                f"WARNING — object approaching{angle_str}! "
                f"Now {current_min:.0f} cm away, was {request.prev_min_distance_cm:.0f} cm. "
                "Stop and listen."
            )

    # ── Step 1: moondream sees the real image
    vision_prompt = (
        "Describe what you see in this image clearly and concisely. "
        "List any objects, people, furniture, obstacles, steps, doors, "
        "or hazards you can identify and their positions (left, right, ahead, close, far). "
        "Also mention any visible text, signs, labels, numbers, or writing you can read."
    )
    try:
        raw_vision = await ollama_vision(request.image_base64, vision_prompt)
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="Ollama is not reachable.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision error: {e}")

    # ── Step 2: qwen3.5 structures the description
    parsed = await structured_scene(raw_vision, request.mode, proximity_note)

    elapsed_ms = int((time.time() - t0) * 1000)

    return AnalyseResponse(
        description=parsed.get("description", raw_vision),
        obstacles=parsed.get("obstacles", []),
        warnings=parsed.get("warnings", []),
        map_text=parsed.get("map_text", ""),
        radar_warning=radar_warn,
        depth_warning=depth_warn,
        text_detected=parsed.get("text_detected") or None,
        approaching_warning=approaching_warn,
        mode=request.mode,
        processing_ms=elapsed_ms,
    )


@app.post("/analyse/upload", response_model=AnalyseResponse)
async def analyse_frame_upload(
    file: UploadFile = File(...),
    mode: str = Form("indoor"),
    radar_json: Optional[str] = Form(None),
    depth_json: Optional[str] = Form(None),
):
    img_bytes = await file.read()
    image_b64 = base64.b64encode(img_bytes).decode()

    radar = None
    if radar_json:
        try:
            radar = [RadarReading(**r) for r in json.loads(radar_json)]
        except Exception:
            pass

    depth = None
    if depth_json:
        try:
            depth = [DepthReading(**d) for d in json.loads(depth_json)]
        except Exception:
            pass

    req = AnalyseRequest(image_base64=image_b64, mode=mode, radar=radar, depth=depth)
    return await analyse_frame(req)


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    t0 = time.time()

    system_prompt = (
        "You are a concise, calm navigation assistant for a visually impaired user. "
        "Speak as if describing things aloud. Always prioritise safety. "
        "Keep replies under 3 sentences."
    )
    if request.context:
        system_prompt += f"\n\nLast known scene: {request.context}"

    messages = [{"role": "system", "content": system_prompt}]
    for m in request.messages:
        messages.append({"role": m.role, "content": m.content})

    try:
        reply = await ollama_chat(messages)
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="Ollama not reachable.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat error: {e}")

    return ChatResponse(reply=reply, processing_ms=int((time.time() - t0) * 1000))


@app.post("/navigate", response_model=NavigateResponse)
async def navigate(request: NavigateRequest):
    """
    Navigation map endpoint.
    Returns positioned obstacle list + safe-path direction + spoken instructions.

    Pipeline:
      1. moondream  → free-text description of what is in the image
      2. qwen3.5:4b → structured obstacle map + route instructions (JSON)
      Sensor readings (radar/depth) are merged in as high-confidence obstacles.
    """
    t0 = time.time()

    try:
        base64.b64decode(request.image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data.")

    # ── Build sensor obstacle list (high confidence, exact distances) ──
    sensor_obstacles: list[dict] = []
    for r in (request.radar or []):
        d = r.distance_cm
        sev = "danger" if d < 80 else ("caution" if d < 150 else "info")
        sensor_obstacles.append({
            "label": "radar obstacle",
            "distance_cm": d,
            "angle_deg": r.angle_deg or 0.0,
            "severity": sev,
        })
    for dep in (request.depth or []):
        d = dep.distance_cm
        sev = "danger" if d < 80 else ("caution" if d < 150 else "info")
        sensor_obstacles.append({
            "label": f"{dep.source or 'depth'} obstacle",
            "distance_cm": d,
            "angle_deg": dep.angle_deg or 0.0,
            "severity": sev,
        })

    # ── Step 1: moondream describes the visual scene ──
    vision_prompt = (
        "Describe every object you can see in this image. "
        "For each object state: its name, rough distance (very close / close / medium / far), "
        "and position (far left, left, centre, right, far right). "
        "Focus on anything that could be a navigation obstacle."
    )
    try:
        raw_vision = await ollama_vision(request.image_base64, vision_prompt)
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="Ollama not reachable.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision error: {e}")

    # ── Step 2: qwen3.5 builds navigation JSON ──
    sensor_json = json.dumps(sensor_obstacles, indent=2) if sensor_obstacles else "none"
    mode_hint = (
        "indoor environment (furniture, walls, doors, steps)"
        if request.mode == "indoor"
        else "outdoor environment (curbs, vehicles, people, poles)"
    )

    nav_prompt = (
        f"You are a navigation AI helping a visually impaired person in a {mode_hint}.\n\n"
        f"Sensor readings (radar/LiDAR — high confidence):\n{sensor_json}\n\n"
        f"Visual scene from camera:\n\"{raw_vision}\"\n\n"
        "Produce a navigation plan as JSON (no markdown, no extra text):\n"
        "{\n"
        '  "obstacles": [\n'
        '    {"label": "<name>", "distance_cm": <number>, "angle_deg": <-90 to 90>, "severity": "<danger|caution|info>"}\n'
        "  ],\n"
        '  "safe_angle_deg": <number between -90 and 90, 0=straight, negative=left, positive=right>,\n'
        '  "instructions": ["<step 1>", "<step 2>", "<step 3>"],\n'
        '  "spoken_instruction": "<one calm sentence telling the user exactly what to do right now>",\n'
        '  "is_path_clear": <true|false>\n'
        "}\n\n"
        "Rules:\n"
        "- Sensor readings override visual guesses for distance/position.\n"
        "- safe_angle_deg points toward the clearest path (avoid all danger/caution obstacles).\n"
        "- Instructions must be 2-4 steps, each under 10 words.\n"
        "- spoken_instruction is a single calm sentence under 20 words.\n"
        "Return ONLY the JSON object."
    )
    messages = [{"role": "user", "content": nav_prompt}]
    payload = {"model": TEXT_MODEL, "messages": messages, "stream": False, "think": False}
    try:
        async with httpx.AsyncClient(timeout=45.0) as c:
            resp = await c.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload)
            resp.raise_for_status()
            raw_nav = resp.json().get("message", {}).get("content", "").strip()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Navigation reasoning error: {e}")

    parsed = _parse_json(raw_nav)

    # ── Merge sensor obstacles that AI might have missed ──
    ai_obstacles: list[dict] = parsed.get("obstacles", [])
    # De-dup: only add sensor entries whose angle isn't already close to an AI entry
    ai_angles = {o.get("angle_deg", 0) for o in ai_obstacles}
    for so in sensor_obstacles:
        if not any(abs(so["angle_deg"] - a) < 15 for a in ai_angles):
            ai_obstacles.append(so)

    # ── Validate / clamp fields ──
    safe_angle = float(parsed.get("safe_angle_deg", 0))
    safe_angle = max(-90.0, min(90.0, safe_angle))

    instructions = parsed.get("instructions", ["Proceed carefully."])
    if not isinstance(instructions, list):
        instructions = [str(instructions)]

    spoken = parsed.get(
        "spoken_instruction",
        "Path appears clear, proceed slowly and carefully.",
    )
    is_clear = bool(parsed.get("is_path_clear", True))

    # Override if any danger obstacle exists
    if any(o.get("severity") == "danger" for o in ai_obstacles):
        is_clear = False
        if "stop" not in spoken.lower():
            spoken = "Stop — obstacle detected very close ahead. Please do not move."

    obstacle_models = []
    for o in ai_obstacles:
        try:
            obstacle_models.append(ObstaclePoint(
                label=str(o.get("label", "obstacle")),
                distance_cm=float(o.get("distance_cm", 150)),
                angle_deg=float(o.get("angle_deg", 0)),
                severity=str(o.get("severity", "info")),
            ))
        except Exception:
            pass

    return NavigateResponse(
        obstacles=obstacle_models,
        safe_angle_deg=safe_angle,
        instructions=instructions,
        spoken_instruction=spoken,
        is_path_clear=is_clear,
        processing_ms=int((time.time() - t0) * 1000),
    )


@app.post("/room-map", response_model=RoomScanResponse)
async def room_map_scan(request: RoomScanRequest):
    """
    Room mapping endpoint — called once per scan as the user rotates/moves.
    Returns positioned obstacle list for the current heading and spoken guidance
    for where to scan next.

    The Flutter client accumulates scan results and builds a floor-plan map.
    Heading conventions: 0=forward, 90=right, 180=behind, 270=left.
    """
    t0 = time.time()

    try:
        base64.b64decode(request.image_base64, validate=True)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 image data.")

    # ── Build sensor obstacle list ──
    sensor_obstacles: list[dict] = []
    for r in (request.radar or []):
        d = r.distance_cm
        sev = "danger" if d < 80 else ("caution" if d < 150 else "info")
        sensor_obstacles.append({
            "label": "radar obstacle",
            "distance_cm": d,
            "angle_deg": r.angle_deg or 0.0,
            "severity": sev,
        })
    for dep in (request.depth or []):
        d = dep.distance_cm
        sev = "danger" if d < 80 else ("caution" if d < 150 else "info")
        sensor_obstacles.append({
            "label": f"{dep.source or 'depth'} obstacle",
            "distance_cm": d,
            "angle_deg": dep.angle_deg or 0.0,
            "severity": sev,
        })

    # ── Direction context for this heading ──
    heading = request.heading_deg % 360
    if heading < 45 or heading >= 315:
        dir_label = "forward"
    elif heading < 135:
        dir_label = "to your right"
    elif heading < 225:
        dir_label = "behind you"
    else:
        dir_label = "to your left"

    mode_hint = (
        "indoor room (map walls, furniture, doors, steps)"
        if request.mode == "indoor"
        else "outdoor space (map curbs, vehicles, poles, fences)"
    )

    # ── Step 1: moondream sees the scene at this heading ──
    vision_prompt = (
        f"The user is facing {dir_label} in a {request.mode} environment. "
        "Describe every object you can see. For each object state: its name, "
        "approximate distance (give a number in cm if possible), and position "
        "(far left, left, centre, right, far right). "
        "Focus on walls, large furniture, and permanent structures for room mapping."
    )
    try:
        raw_vision = await ollama_vision(request.image_base64, vision_prompt)
    except httpx.ConnectError:
        raise HTTPException(status_code=503, detail="Ollama not reachable.")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Vision error: {e}")

    # ── Step 2: qwen3.5 extracts obstacles + next-step guidance ──
    sensor_json = json.dumps(sensor_obstacles, indent=2) if sensor_obstacles else "none"
    next_scan_index = request.scan_index + 1
    next_heading = (request.heading_deg + 90) % 360
    next_dir = {0: "forward", 90: "right", 180: "behind you", 270: "left"}.get(
        int(next_heading) % 360, f"{next_heading:.0f}°"
    )
    scans_remaining = max(0, 4 - (request.scan_index + 1))

    map_prompt = (
        f"You are mapping a {mode_hint} for a visually impaired user.\n"
        f"User is currently facing {dir_label} (heading {request.heading_deg:.0f}°). "
        f"This is scan #{request.scan_index + 1}.\n\n"
        f"Sensor readings (high confidence):\n{sensor_json}\n\n"
        f"Visual scene:\n\"{raw_vision}\"\n\n"
        "Produce mapping JSON (no markdown, no extra text):\n"
        "{\n"
        '  "obstacles": [\n'
        '    {"label": "<name>", "distance_cm": <number>, "angle_deg": <-90 to 90>, "severity": "<danger|caution|info>"}\n'
        "  ],\n"
        f'  "walking_instruction": "<calm one sentence: describe what was found at {dir_label} and tell user to turn {next_dir} for next scan>"\n'
        "}\n\n"
        "Rules:\n"
        "- Sensor readings override visual estimates for distances.\n"
        "- distance_cm must be a positive number (estimate from scene if sensor not available).\n"
        "- angle_deg: 0=directly ahead in current facing direction, -90=far left, +90=far right.\n"
        f"- walking_instruction: mention what you found, then say 'Now turn to face {next_dir} and tap Scan Again'.\n"
        "Return ONLY the JSON object."
    )
    messages = [{"role": "user", "content": map_prompt}]
    payload = {"model": TEXT_MODEL, "messages": messages, "stream": False, "think": False}
    try:
        async with httpx.AsyncClient(timeout=45.0) as c:
            resp = await c.post(f"{OLLAMA_BASE_URL}/api/chat", json=payload)
            resp.raise_for_status()
            raw_map = resp.json().get("message", {}).get("content", "").strip()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Mapping reasoning error: {e}")

    parsed = _parse_json(raw_map)

    # ── Merge sensor obstacles ──
    ai_obstacles: list[dict] = parsed.get("obstacles", [])
    ai_angles = {o.get("angle_deg", 0) for o in ai_obstacles}
    for so in sensor_obstacles:
        if not any(abs(so["angle_deg"] - a) < 15 for a in ai_angles):
            ai_obstacles.append(so)

    obstacle_models: list[MappedPoint] = []
    for o in ai_obstacles:
        try:
            obstacle_models.append(MappedPoint(
                label=str(o.get("label", "obstacle")),
                distance_cm=float(o.get("distance_cm", 200)),
                angle_deg=float(o.get("angle_deg", 0)),
                severity=str(o.get("severity", "info")),
            ))
        except Exception:
            pass

    default_instruction = (
        f"Scan {request.scan_index + 1} complete. "
        f"Turn to face {next_dir} and tap Scan Again."
        if scans_remaining > 0 else
        "All directions scanned. Room map is complete."
    )
    spoken = parsed.get("walking_instruction", default_instruction)

    return RoomScanResponse(
        heading_deg=request.heading_deg,
        scan_index=request.scan_index,
        obstacles=obstacle_models,
        walking_instruction=spoken,
        processing_ms=int((time.time() - t0) * 1000),
    )


@app.websocket("/ws/analyse")
async def websocket_analyse(ws: WebSocket):
    await ws.accept()
    try:
        while True:
            data = await ws.receive_text()
            try:
                req = AnalyseRequest(**json.loads(data))
                result = await analyse_frame(req)
                await ws.send_text(result.model_dump_json())
            except Exception as e:
                await ws.send_text(json.dumps({"error": str(e)}))
    except WebSocketDisconnect:
        pass


@app.websocket("/ws/realtime")
async def websocket_realtime(ws: WebSocket):
    """
    Real-time streaming WebSocket — three message types:

    sensor_ping  → instant proximity check, no AI (< 5 ms)
    analyse      → full AI pipeline; skipped if AI is already busy
    snapshot     → immediate photo + spoken question answer (priority, cancels pending analyse)

    Client sends JSON:
      {"type": "sensor_ping", "radar": [...], "depth": [...], "prev_min_distance_cm": null}
      {"type": "analyse",     "image_base64": "...", "mode": "indoor", "radar": [...], "depth": [...], "prev_min_distance_cm": null}
      {"type": "snapshot",    "image_base64": "...", "mode": "indoor", "question": "What is ahead?"}

    Server responds with:
      {"type": "sensor_result",   "radar_warning": ..., "depth_warning": ..., "approaching_warning": ...}
      {"type": "analyse_result",  ...full AnalyseResponse fields...}
      {"type": "snapshot_result", "question": ..., "answer": ...}
      {"type": "skipped"}
      {"type": "error", "message": ...}
    """
    await ws.accept()
    pending_task: Optional[asyncio.Task] = None   # only 1 AI task at a time

    async def _send(payload: dict):
        try:
            await ws.send_text(json.dumps(payload))
        except Exception:
            pass

    try:
        while True:
            raw = await ws.receive_text()
            msg: dict = json.loads(raw)
            msg_type = msg.get("type", "analyse")

            # ── Fast path: sensor-only ping (no AI) ──────────────────────
            if msg_type == "sensor_ping":
                radar_raw = msg.get("radar") or []
                depth_raw = msg.get("depth") or []
                prev_min  = msg.get("prev_min_distance_cm")

                radar_objs = [RadarReading(**r) for r in radar_raw] or None
                depth_objs = [DepthReading(**d) for d in depth_raw] or None

                r_warn, d_warn, _ = _proximity_warning(radar_objs, depth_objs)

                # Approaching detection
                approach_warn: Optional[str] = None
                all_sensors = (radar_objs or []) + [
                    RadarReading(distance_cm=d.distance_cm, angle_deg=d.angle_deg)
                    for d in (depth_objs or [])
                ]
                if all_sensors and prev_min is not None:
                    cur_min = min(s.distance_cm for s in all_sensors)
                    if float(prev_min) - cur_min > 40:
                        closest = min(all_sensors, key=lambda s: s.distance_cm)
                        ang = closest.angle_deg or 0
                        side = " on your right" if ang > 10 else (" on your left" if ang < -10 else "")
                        approach_warn = (
                            f"WARNING — object approaching{side}! "
                            f"Now {cur_min:.0f} cm away. Stop and listen."
                        )

                await _send({
                    "type": "sensor_result",
                    "radar_warning": r_warn,
                    "depth_warning": d_warn,
                    "approaching_warning": approach_warn,
                })

            # ── Snapshot: priority voice query (cancels pending analyse) ──
            elif msg_type == "snapshot":
                if pending_task and not pending_task.done():
                    pending_task.cancel()
                    try:
                        await pending_task
                    except asyncio.CancelledError:
                        pass

                image_b64 = msg.get("image_base64", "")
                mode      = msg.get("mode", "indoor")
                question  = msg.get("question", "What do you see?")

                async def _do_snapshot():
                    try:
                        raw_vision = await ollama_vision(
                            image_b64,
                            f"Describe every detail you can see, then answer this question: {question}",
                        )
                        answer_prompt = (
                            f"A visually impaired person asked: \"{question}\"\n"
                            f"Camera scene: \"{raw_vision}\"\n\n"
                            "Give a direct, calm answer in 1-2 sentences. "
                            "Mention distances and directions where helpful."
                        )
                        answer = await ollama_chat(
                            [{"role": "user", "content": answer_prompt}],
                            timeout=30.0,
                        )
                        await _send({
                            "type": "snapshot_result",
                            "question": question,
                            "answer": answer,
                        })
                    except asyncio.CancelledError:
                        pass
                    except Exception as e:
                        await _send({"type": "error", "message": f"Snapshot error: {e}"})

                pending_task = asyncio.create_task(_do_snapshot())

            # ── Full AI analysis frame ────────────────────────────────────
            elif msg_type == "analyse":
                if pending_task and not pending_task.done():
                    # AI is still busy — skip this frame so we don't pile up
                    await _send({"type": "skipped"})
                    continue

                async def _do_analyse(m: dict = msg):
                    try:
                        req = AnalyseRequest(
                            image_base64=m.get("image_base64", ""),
                            mode=m.get("mode", "indoor"),
                            radar=[RadarReading(**r) for r in (m.get("radar") or [])] or None,
                            depth=[DepthReading(**d) for d in (m.get("depth") or [])] or None,
                            prev_min_distance_cm=m.get("prev_min_distance_cm"),
                        )
                        result = await analyse_frame(req)
                        payload = result.model_dump()
                        payload["type"] = "analyse_result"
                        await _send(payload)
                    except asyncio.CancelledError:
                        pass
                    except Exception as e:
                        await _send({"type": "error", "message": f"Analyse error: {e}"})

                pending_task = asyncio.create_task(_do_analyse())

    except WebSocketDisconnect:
        if pending_task and not pending_task.done():
            pending_task.cancel()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
