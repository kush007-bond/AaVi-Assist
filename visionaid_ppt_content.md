# VisionAid: PPT Presentation Outline

This document contains a structured slide-by-slide outline that you can use to generate a PowerPoint (PPT) presentation for VisionAid. It covers all the core features, architecture, and value propositions of the app.

---

## Slide 1: Title Slide
**Title:** VisionAid
**Subtitle:** Real-Time AI-Powered Navigation Assistant for the Visually Impaired
**Speaker/Team:** [Your Team Name]
**Tagline:** Hear what you cannot see.

---

## Slide 2: Product Overview
**Title:** What is VisionAid?
**Content:**
* VisionAid is an AI-powered assistant designed to provide real-time scene descriptions and obstacle warnings for visually impaired users.
* It captures camera frames, analyzes them using a local AI model (LLaVA), and reads the scene descriptions aloud.
* Integrates seamlessly with an optional radar sensor for hardware-level proximity detection.
* **Core Goal:** Provide an instant safety net and contextual awareness of the surrounding environment.

---

## Slide 3: Core Value Proposition
**Title:** Why VisionAid?
**Content:**
* **Hear the Unseen:** AI describes the environment instantly using Text-to-Speech (TTS).
* **Radar Safety Net:** Hardware proximity alerts warn you of obstacles before the camera even processes them.
* **Always-On Context:** Users can ask follow-up questions at any time through a persistent chat interface.
* **Universal Access:** Built on Flutter to work everywhere (iOS, Android, and Web).

---

## Slide 4: Key Feature: Vision & Scene Analysis
**Title:** Intelligent Scene Description
**Content:**
* **Mode-Adaptive Camera Capture:** Automatically captures camera frames at specific intervals based on user environments.
    * *Indoor Mode:* Every 3.5 seconds for steady navigation.
    * *Outdoor Mode:* Every 1.5 seconds for fast-paced, dynamic environments.
* **AI Vision Integration:** Sends images to a local multimodal AI (Ollama + LLaVA) via a FastAPI backend to extract detailed scene context.
* **Real-time TTS:** Immediately reads out descriptions and identified obstacles.

---

## Slide 5: Key Feature: Radar & Proximity Alerts
**Title:** Hardware Radar Integration
**Content:**
* **Sensor Detection:** Automatically connects to supported BLE (Bluetooth) radar sensors on app launch.
* **Instant Distance Calculation:** Sends real-time distance and angle data to the backend.
* **Critical Warning System:** 
    * *< 80 cm:* Spoken "radar warning" immediately overrides other descriptions.
    * *< 30 cm:* "STOP — obstacle very close" immediate alert.
* **Surrounding Text Map:** Generates a spatial map (e.g., "WALL-LEFT | PATH-AHEAD | CHAIR-RIGHT").

---

## Slide 6: Key Feature: Interactive Chat
**Title:** Context-Aware Chat Bar
**Content:**
* **Persistent Bottom Chat:** Always accessible, even when camera analysis is actively running.
* **Follow-up Questions:** Users can ask the AI about the current scene (e.g., "Is the path ahead clear?").
* **Smart Memory:** Maintains context from the last scene description, processed by the Llama3 text model.
* **Audio Feedback:** Chat responses are also read aloud for a completely hands-free experience.

---

## Slide 7: App Interface & User Experience
**Title:** Designed for Accessibility
**Content:**
* **Minimalist UI:** High contrast, dark theme, large text, and no unnecessary animations.
* **Live Status Bar:** Displays current mode (Indoor/Outdoor), capture interval, and radar connectivity status.
* **Description Banner:** Shows a scrolling text history of the latest spoken descriptions.
* **Simple Controls:** Single Start/Stop toggle for camera analysis and a dedicated Settings screen for backend configurations.

---

## Slide 8: Technical Architecture
**Title:** How It Works Under the Hood
**Content:**
* **Frontend:** Built with Flutter for cross-platform compatibility. Handles camera captures, BLE radar scanning, TTS, and UI.
* **Backend:** Python FastAPI server handling high-throughput requests and WebSocket streaming.
* **Local AI Models:** 
    * *Vision:* Ollama running LLaVA for image-to-text scene analysis.
    * *Chat:* Ollama running Llama3 for processing conversational context.
* **Network:** Cloudflare Tunnel for secure, easy remote access to the local PC backend.

---

## Slide 9: Data Privacy & Offline Capabilities
**Title:** Privacy First
**Content:**
* **Fully Local Processing:** All AI inference happens locally on the host machine using Ollama.
* **No Cloud Dependency:** Images and private data never leave the user's secure network.
* **Zero Subscription Costs:** Uses powerful open-source models, avoiding costly API fees like OpenAI.

---

## Slide 10: Conclusion & Future Roadmap
**Title:** The Future of VisionAid
**Content:**
* Extend hardware support to more specialized IoT radar sensors.
* Optimize AI response times (lower latency) on mid-range hardware.
* Introduce deeper custom map integrations and route planning.
* **Final Thought:** Bridging the gap between the physical world and the visually impaired through accessible, local AI.
