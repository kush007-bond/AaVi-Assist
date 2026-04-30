# VisionAid — Frontend Design Specification

> Theme: **Blue & White**  
> Platform: Flutter (iOS & Android)  
> Accessibility-first — large tap targets, high contrast, TTS on all critical actions

---

## Table of Contents

1. [Design Tokens](#1-design-tokens)
2. [Typography](#2-typography)
3. [Component Library](#3-component-library)
4. [Screen: Splash](#4-screen-splash)
5. [Screen: Home](#5-screen-home)
6. [Screen: Navigation Map](#6-screen-navigation-map)
7. [Screen: Room Map](#7-screen-room-map)
8. [Screen: Settings](#8-screen-settings)
9. [Overlay & State Patterns](#9-overlay--state-patterns)
10. [Theme Migration Checklist](#10-theme-migration-checklist)

---

## 1. Design Tokens

### Color Palette

| Token | Hex | Usage |
|---|---|---|
| `primary` | `#1565C0` | Buttons, active states, key accents |
| `primaryLight` | `#42A5F5` | Badges, highlights, sensor indicators |
| `primaryDark` | `#0D47A1` | App bar, pressed states |
| `surface` | `#FFFFFF` | Card backgrounds, panels |
| `background` | `#F0F4FF` | Screen background (light blue-white) |
| `onPrimary` | `#FFFFFF` | Text/icons on primary color |
| `onSurface` | `#0D1B3E` | Primary text on white |
| `onSurfaceMuted` | `#5C6E91` | Secondary text, placeholders |
| `divider` | `#C5D3E8` | Borders, separators |
| `cameraOverlay` | `#0A0A0A` | Camera preview background |
| `danger` | `#C62828` | Stop button, danger alerts |
| `dangerSurface` | `#FFEBEE` | Danger alert background |
| `caution` | `#E65100` | Caution alerts |
| `cautionSurface` | `#FFF3E0` | Caution alert background |
| `info` | `#0277BD` | Info alerts |
| `infoSurface` | `#E1F5FE` | Info alert background |
| `success` | `#2E7D32` | Completed states |
| `successSurface` | `#E8F5E9` | Completed state background |
| `liveRed` | `#D32F2F` | LIVE recording dot |
| `teal` | `#00695C` | Text detection badge |
| `tealSurface` | `#E0F2F1` | Text detection background |

### Elevation & Shadow

```
card shadow: 0px 2px 8px rgba(21, 101, 192, 0.12)
panel shadow: 0px 1px 4px rgba(0, 0, 0, 0.08)
app bar shadow: 0px 1px 3px rgba(13, 71, 161, 0.15)
```

---

## 2. Typography

| Style | Font Size | Weight | Color | Usage |
|---|---|---|---|---|
| `appTitle` | 20sp | Bold | `onPrimary` | App bar title |
| `screenTitle` | 18sp | SemiBold | `onSurface` | Section headings |
| `body` | 15sp | Regular | `onSurface` | Scene descriptions |
| `bodySmall` | 13sp | Regular | `onSurfaceMuted` | Secondary info, labels |
| `caption` | 11sp | Regular | `onSurfaceMuted` | Timestamps, badges |
| `badge` | 10sp | Bold | — | Status chips |
| `button` | 14sp | Bold | `onPrimary` | Button labels |
| `mono` | 12sp | Regular | `primaryLight` | Map debug text |

Font family: System default (SF Pro on iOS, Roboto on Android). Letter spacing `1.0` on `appTitle` only.

---

## 3. Component Library

### 3.1 Primary Button

```
Background : primary (#1565C0)
Text       : onPrimary (#FFFFFF), 14sp Bold
Padding    : 20px horizontal, 10px vertical
Min height : 44px (accessibility)
Border     : none
Radius     : 8px
Disabled   : background #C5D3E8, text #5C6E91
```

### 3.2 Outlined Button

```
Border     : 1.5px solid primary
Text       : primary (#1565C0)
Background : transparent
Radius     : 8px
Min height : 44px
```

### 3.3 Danger Button

```
Background : danger (#C62828)
Text       : white
Same sizing as Primary Button
```

### 3.4 Status Chip / Badge

```
Padding    : 6px H, 3px V
Radius     : 4px
Font       : 10–11sp Bold
Examples   : INDOOR, OUTDOOR, LIVE, HW, SIM
```

### 3.5 Warning Banner

```
Radius     : 6px
Padding    : 10px H, 8px V
Icon size  : 16px, left-aligned
Text       : 13sp Bold
Colors per level:
  - Danger  → dangerSurface bg, danger border, danger icon
  - Caution → cautionSurface bg, caution border, caution icon
  - Info    → infoSurface bg, info border, info icon
```

### 3.6 Icon Buttons (App Bar Actions)

```
Size         : 44×44px tap area
Icon size    : 22px
Active color : primaryLight (#42A5F5)
Inactive     : onSurfaceMuted (#5C6E91) at 60% opacity
```

### 3.7 Progress Bar

```
Height     : 5px
Radius     : 4px
Track      : divider (#C5D3E8)
Fill       : primary for normal, success for complete, caution for warning
```

### 3.8 Circular Progress Indicator

```
Color      : primary (#1565C0)
Stroke     : 2px (small), 3px (large)
```

---

## 4. Screen: Splash

### Purpose
App init screen. Checks server, loads sensors, then navigates to Home.

### Layout

```
┌─────────────────────────────┐
│                             │
│                             │
│     [Eye Icon 72px]         │  ← Icon: visibility, color: primary
│                             │
│        VisionAid            │  ← 32sp Bold, onSurface
│   AI Navigation Assistant   │  ← 15sp, onSurfaceMuted
│                             │
│   ┌──────────────────────┐  │
│   │ [Progress spinner]   │  │  ← 24px CircularProgressIndicator
│   └──────────────────────┘  │
│                             │
│    Starting up...           │  ← 13sp, onSurfaceMuted, centered
│    Checking server...       │     multiline, height 1.6
│    Detecting sensors...     │
│                             │
└─────────────────────────────┘
```

### State Colors
| State | Spinner Color | Status Text |
|---|---|---|
| Connecting | `onSurfaceMuted` (grey) | "Checking server..." |
| Connected + model ready | `success` (green) | "Server ready — vision model loaded" |
| Connected, no model | `caution` (orange) | "Vision model not loaded" |
| Failed | `danger` (red) | "Server not reachable. Configure URL in Settings" |

### Background
`background` (`#F0F4FF`) — full screen, no app bar.

---

## 5. Screen: Home

### Purpose
Main screen. Live camera preview with AI scene analysis, sensor monitor, voice control, mini room map overlay, and controls.

### App Bar

```
┌─────────────────────────────────────────────────────┐
│  ← [back hidden]  VisionAid  [LIVE badge]           │
│                          [⚡] [⊞ Room] [🗺 Nav] [⚙] │
└─────────────────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `primaryDark` (`#0D47A1`) |
| Title text | "VisionAid", 20sp Bold, white, letterSpacing 1.0 |
| LIVE badge | Outlined chip: `primaryLight` border + text, `primaryLight` bg at 15% opacity, 10sp Bold |
| ⚡ Real-time icon | Active: `primaryLight`, Inactive: white at 38% opacity |
| ⊞ Room Map icon | `primaryLight` always |
| 🗺 Nav Map icon | `primaryLight`, shown only when radar/LiDAR detected |
| ⚙ Settings icon | White at 80% opacity |

### Body Layout (top → bottom)

```
┌──────────────────────────────────┐
│                                  │
│        CAMERA PREVIEW            │  flex: 55 — full width
│   [Mini map ↙]      [Mic btn ↘] │
│   [LIVE dot ↗]                  │
│   [Analysing overlay — centered] │
│                                  │
├──────────────────────────────────┤
│  SENSOR BAR (if sensor active)   │  visible only when REALTIME enabled
├──────────────────────────────────┤
│  VOICE STRIP (if voice enabled)  │  visible only when voice is on
├──────────────────────────────────┤
│  STATUS BAR                      │  always visible
├──────────────────────────────────┤
│  DESCRIPTION BANNER              │  always visible
├──────────────────────────────────┤
│  ERROR BANNER (if error)         │  conditional
├──────────────────────────────────┤
│  CHAT BAR                        │  always visible (bottom)
└──────────────────────────────────┘
```

---

### 5.1 Camera Preview

**Background (no camera):**  
`#E8EDF5` (light blue-grey), centered text in `onSurfaceMuted`.

**Live preview:**  
Full-width `CameraPreview` widget.

**Overlays on camera:**

| Overlay | Position | Detail |
|---|---|---|
| Mini floor-plan widget | Bottom-left, 10px inset | 100×100px, white border 1.5px, radius 8px; label beneath in `#000000AA` chip |
| Mic button | Bottom-right, 10px inset | 56×56px circle — see §5.4 |
| LIVE recording dot | Top-right, 8px inset | Red dot `liveRed` + "LIVE" text, shown only in realtime+running |
| Analysing overlay | Centered, full cover | Semi-transparent `#000000AA`, spinner + "Analysing scene..." 14sp white |

---

### 5.2 Sensor Bar

Shown when `_sensorActive = true`.

```
┌──────────────────────────────────────────────────┐
│  [icon]  Message text              [XX cm] [HW▾] │
│  ████████████░░░░░░░░  ← distance fill bar 3px   │
└──────────────────────────────────────────────────┘
```

| State | Background | Text Color | Fill Color |
|---|---|---|---|
| Clear | `infoSurface` (#E1F5FE) | `info` (#0277BD) | `info` |
| Info | `#FFF9E6` | `#795500` | `caution` |
| Caution | `cautionSurface` | `caution` | `caution` |
| Danger | `dangerSurface` | `danger` | `danger` |

**HW/SIM badge:**  
- SIM: `caution` border + text, `cautionSurface` bg  
- HW: `success` border + text, `successSurface` bg

---

### 5.3 Voice Strip

Shown when `_voiceEnabled = true`.

```
┌──────────────────────────────────────────────────┐
│  [mic icon]  "Listening..." / partial text  [Speak▶] │
└──────────────────────────────────────────────────┘
```

| State | Background | Content |
|---|---|---|
| Listening | `danger` (#C62828) at 90% | Partial speech text in white, no Speak button |
| Processing | `caution` (#E65100) at 90% | Status/question text, no Speak button |
| Idle | `#EEF2FA` | Status text in `onSurface`, Speak button chip |

**Speak button chip:**  
Outlined, `primary` border, `primary` text, 12sp.

---

### 5.4 Mic Button

56×56px circle, bottom-right of camera preview.

| State | Background | Icon | Border |
|---|---|---|---|
| Idle / off | `#00000088` | `mic_off`, white 38% | white 24% |
| Voice on (idle) | `primary` at 85% | `mic`, white | white 24% |
| Listening | `liveRed` at 90% | `mic`, white | `liveRed` — pulses scale 1.0→1.25 |
| Processing | `caution` at 85% | `hourglass_empty`, black | white 24% |

---

### 5.5 Status Bar

```
┌──────────────────────────────────────────────────────────┐
│ [INDOOR▾]  LIVE / 3.5s   [sensors icon]  [radar icon]   │
│                                  [REALTIME]  [START/STOP]│
└──────────────────────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `surface` white |
| Mode chip | Outlined, `primary` border + text; tap to toggle INDOOR/OUTDOOR |
| Interval text | "LIVE" in `primary` bold / "3.5s" in `onSurfaceMuted` |
| Radar icon | `success` if connected, `divider` if not |
| LiDAR icon | `primaryLight` if connected, `divider` if not |
| REALTIME button | Outlined chip: active → `primaryLight` border+text + `#E3F2FD` bg; inactive → `divider` |
| START button | `primary` bg, white text; → `danger` bg + "STOP" when running |

---

### 5.6 Description Banner

Background: `surface` white. Padding 12px all sides.

**Empty state:**  
"Tap START to begin scene analysis." — 14sp, `onSurfaceMuted`.

**Loading state:**  
Spinner (14px, `primary`) + "Analysing scene..." 14sp `primary`.

**Result state (top to bottom):**

| Element | Background | Icon | Text Color |
|---|---|---|---|
| Depth/LiDAR warning | `infoSurface` | `radar`, `info` | `info` Bold 13sp |
| Radar warning | `dangerSurface` | `sensors`, `danger` | `danger` Bold 13sp |
| Approaching warning | `#EDE7F6` (light purple) | `directions_run`, `#6A1B9A` | `#6A1B9A` Bold 13sp |
| Scene description | — | — | `onSurface` 15sp, height 1.4 |
| Text detected badge | `tealSurface` | `text_fields`, `teal` | `teal` 13sp italic |
| Map text (monospace) | — | — | `primaryLight` 12sp mono |
| Obstacle chips | `#EEF2FA` | — | `onSurfaceMuted` 12sp |

---

### 5.7 Chat Bar

Sticky bottom bar for text queries to the AI.

```
┌────────────────────────────────────────────────┐
│  [text field: Ask anything...]    [Send ➤]     │
└────────────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `surface` white |
| Text field | Filled `#F0F4FF`, radius 24px, 13sp, hint in `onSurfaceMuted` |
| Border | `divider` when idle, `primary` when focused |
| Send button | Circle 40px, `primary` bg, white `send` icon |

---

## 6. Screen: Navigation Map

### Purpose
Polar radar view of obstacles + step-by-step navigation instructions.

### App Bar

```
┌─────────────────────────────────────────────────────┐
│  ←  Navigation Map   [radar icon] [lidar icon]      │
│                                  [⟳ auto] [↺ scan]  │
└─────────────────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `primaryDark` |
| Title | "Navigation Map" 18sp Bold, white |
| Sensor badges | Radar: `success` icon, LiDAR: `primaryLight` icon |
| Auto-scan toggle | Active: `primaryLight`, Inactive: `onSurfaceMuted` 60% |
| Refresh/Scan | White icon, disabled when scanning |

### Body Layout

```
┌──────────────────────────────────┐
│                                  │
│      RADAR MAP (CustomPaint)     │  flex: 60
│                                  │
│  [XXXms ↖]          [Scanning ↗]│
│  [Error banner ↙]                │
├──────────────────────────────────┤
│  [✓/⚠] Current instruction  [🔊]│  ← header row
├──────────────────────────────────┤
│  Scrollable steps list           │  flex: 40
├──────────────────────────────────┤
│  [← Prev]  [Scan Again]  [Next→] │  ← footer row
└──────────────────────────────────┘
```

### Radar Map Canvas

| Element | Color |
|---|---|
| Canvas background | `#EEF4FF` (very light blue) |
| Grid rings | `primary` at 10% opacity |
| Safe direction arc | `primary` at 25% fill |
| Obstacle dots | `danger` filled circles |
| Clear path vector | `primary` solid line |
| User position | `primaryDark` filled circle, 8px |
| Scan rings (animation) | `primary` fading outward |

**Empty state (no data yet):**  
Radar icon 60px `primary` at 30% + "Scanning environment..." 14sp `onSurfaceMuted`.

**Processing time badge:**  
`#00000066` bg, "XXXms" 10sp white 38%.

**Scanning overlay badge (when data exists):**  
Pulsing chip: `primary` at 20% bg, `primary` border + text, spinner.

---

### Navigation Instructions Panel

**Background:** `surface` white.

**Header row (instruction bar):**

| Element | Detail |
|---|---|
| Background | `#F0F4FF` |
| Status icon | `success` checkmark (path clear) / `caution` warning (obstacle) |
| Instruction text | 13sp Medium, `onSurface` |
| Speak current icon | `primary`, 20px |
| Speak full route | `primary`, 20px |

**Step list item:**

| State | Background | Border | Step Number | Text |
|---|---|---|---|---|
| Active | `primary` at 12% | `primary` at 50% | `primary` filled circle, white number | `onSurface` 13sp + volume icon |
| Inactive | transparent | `divider` | `#EEF2FA` circle, `onSurfaceMuted` number | `onSurfaceMuted` 13sp |

**Footer row:**

| Element | Detail |
|---|---|
| Background | `#F8FAFF` |
| Prev / Next | TextButton, `primary` when enabled, `divider` when disabled |
| Scan Again | Primary button, 44px height |

---

## 7. Screen: Room Map

### Purpose
Guides user through 4-direction room scan (Forward, Right, Back, Left) to build a floor plan.

### App Bar

```
┌──────────────────────────────────────────────┐
│  ←  Room Map   [sensor badges]        [🗑 Reset] │
└──────────────────────────────────────────────┘
```

Reset icon: `caution` (`#E65100`).

### Body Layout

```
┌──────────────────────────────────┐
│  COVERAGE PROGRESS BAR           │  ← always on top
├──────────────────────────────────┤
│                                  │
│      FLOOR PLAN (CustomPaint)    │  flex: 55
│   [pts count badge ↗]           │
│   [Scanning overlay]             │
│   [Error banner ↙]              │
│                                  │
├──────────────────────────────────┤
│  GUIDANCE PANEL                  │  flex: 45
└──────────────────────────────────┘
```

---

### Coverage Bar

```
┌──────────────────────────────────────────────────────┐
│  Coverage: 2/4 scans                           50%   │
│  ████████████░░░░░░░░░░ (5px progress bar)           │
└──────────────────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `#F8FAFF` |
| Label text | "Coverage: X/4 scans" 12sp `onSurfaceMuted` |
| Percentage | 12sp Bold; `caution` while in-progress, `success` when complete |
| Bar fill | `caution` in-progress, `success` complete |
| Bar track | `divider` |

---

### Floor Plan Canvas

| Element | Color |
|---|---|
| Background | `#EEF4FF` |
| Grid lines | `primary` at 8% |
| User center | `primaryDark` filled 10px dot |
| Obstacle points | `danger` dots, size proportional to distance confidence |
| Safe space | `primary` at 6% fill |
| Scan coverage arc | `primary` at 15% per scanned heading |
| Scanned heading lines | `primaryLight` |

**Empty state:**  
Grid icon 52px `primary` 25% + "No data yet. Tap Scan to start mapping." — 13sp `onSurfaceMuted`, centered.

**Points badge (top-right):**  
`#00000066` bg, "XX pts" 10sp white 38%.

---

### Guidance Panel

**Background:** `surface` white. Padding 16px all sides.

**Direction icons row (4 directions):**

```
   Fwd ↑       Right →       Back ↓       Left ←
  [circle]    [circle]     [circle]     [circle]
    Fwd         Right         Back         Left
```

| State | Circle Fill | Border | Icon | Label |
|---|---|---|---|---|
| Done | `successSurface` | `success` 1.5px | checkmark `success` | `success` 10sp |
| Next (pending) | `cautionSurface` | `caution` 1.5px | directional `caution` | `caution` 10sp |
| Waiting | `#F0F4FF` | `divider` 1.5px | directional `onSurfaceMuted` 40% | `onSurfaceMuted` 10sp |

Circle size: 36×36px.

**Guidance text box:**

```
┌──────────────────────────────────────────┐
│  [nav/check icon]  Guidance text     [🔊]│
└──────────────────────────────────────────┘
```

| Element | Detail |
|---|---|
| Background | `#F0F4FF` |
| Border | `primary` at 30%, 1px, radius 8px |
| Icon | `success` (done) / `caution` (next direction) |
| Text | `onSurface` 13sp, height 1.5 |
| Speak icon | `primary` |

**Scan button:**  
Full-width Primary button, 44px height. Label: "Scan Now" / "Scan Again" (complete) / spinner + "Scanning..." (busy).

---

## 8. Screen: Settings

### Purpose
Configure backend URL, test connection, view model status.

### App Bar

```
┌───────────────────────────────────────┐
│  ←  Settings                          │
└───────────────────────────────────────┘
```

Background: `primaryDark`.

### Body Layout

```
┌──────────────────────────────────────────────┐
│  Backend URL                                 │  ← label 13sp onSurfaceMuted
│  ┌────────────────────────────────────────┐  │
│  │ http://localhost:8000                  │  │  ← filled text field
│  └────────────────────────────────────────┘  │
│                                              │
│  [Test Connection]        [Save]             │  ← side-by-side buttons
│                                              │
│  ● Connected / Failed             XXXms      │  ← status row
│                                              │
│  Vision model:  moondream                    │  ← model rows
│  Chat model  :  qwen3.5:4b                   │
└──────────────────────────────────────────────┘
```

### Text Field

```
Fill        : #F0F4FF
Border idle : none (filled style)
Border focus: primary 2px
Text        : onSurface 15sp
Hint        : onSurfaceMuted
Radius      : 8px
Padding     : 12px H, 12px V
```

### Buttons (side by side)

| Button | Style | Detail |
|---|---|---|
| Test Connection | Outlined | `primary` border + text; spinner on loading |
| Save | Primary | `primary` bg, white text |

### Connection Status Row

| State | Dot color | Text color | Text |
|---|---|---|---|
| Connected + AI ready | `success` | `success` | "Connected" |
| Connected, no AI | `caution` | `caution` | "Server up — AI model offline" |
| Failed | `danger` | `danger` | "Connection failed" |
| Idle | — | — | hidden |

Latency badge: "XXXms" 12sp `onSurfaceMuted`.

### Model Rows

```
Vision model:  moondream     ← label onSurfaceMuted / value primaryLight
Chat model  :  qwen3.5:4b
```

---

## 9. Overlay & State Patterns

### 9.1 Analysing Overlay (Camera)

```
Full cover semi-transparent: #000000AA
Center column:
  CircularProgressIndicator — primary, strokeWidth 3
  "Analysing scene..." — 14sp white
```

### 9.2 Scanning Overlay (Map screens)

```
Full cover: #00000066
Centered pill container:
  Background  : primary at 20%
  Border      : primary at 50%
  Radius      : 12px
  Content     : spinner (primary) + "Scanning room..." (primary 13sp)
  Animation   : opacity pulse 0.4→1.0 on repeat
```

### 9.3 Error Banner

```
Background : dangerSurface (#FFEBEE)
Border     : danger left 3px accent
Padding    : 12px H, 8px V
Icon       : error_outline danger 16px
Text       : onSurface 12sp (up to 3 lines)
Close (✕)  : onSurfaceMuted 16px
```

### 9.4 Snackbar (Save confirmation)

```
Background : primary (#1565C0)
Text       : white, 14sp
Duration   : 2s
```

### 9.5 Empty State (generic)

```
Icon       : relevant icon, primary at 25% opacity, 52–60px
Text       : onSurfaceMuted 13–14sp, centered, max 2 lines
```

### 9.6 LIVE Badge (camera overlay)

```
Background : liveRed (#D32F2F) at 85%
Radius     : 4px
Dot        : 8px fiber_manual_record icon, white
Text       : "LIVE" 11sp Bold white
Position   : top-right 8px inset
```

---

## 10. Theme Migration Checklist

The following replaces the current **black/green** theme throughout the app. Update `main.dart` ThemeData first, then apply per-screen.

### `main.dart` ThemeData

```dart
ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: Color(0xFF1565C0),
    onPrimary: Colors.white,
    secondary: Color(0xFF42A5F5),
    surface: Colors.white,
    background: Color(0xFFF0F4FF),
    error: Color(0xFFC62828),
  ),
  scaffoldBackgroundColor: Color(0xFFF0F4FF),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF0D47A1),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF1565C0),
      foregroundColor: Colors.white,
      minimumSize: Size(80, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Color(0xFF1565C0),
      side: BorderSide(color: Color(0xFF1565C0), width: 1.5),
      minimumSize: Size(80, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  textTheme: TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF0D1B3E)),
    bodySmall: TextStyle(color: Color(0xFF5C6E91)),
  ),
)
```

### Color Swap Reference

| Old (black/green) | New (blue/white) |
|---|---|
| `Colors.black` (scaffold) | `Color(0xFFF0F4FF)` |
| `Colors.black` (app bar) | `Color(0xFF0D47A1)` |
| `Colors.grey[900]` (panels) | `Colors.white` |
| `Colors.grey[850]` | `Color(0xFFF0F4FF)` |
| `Colors.green` (primary) | `Color(0xFF1565C0)` |
| `Colors.green[700]` (buttons) | `Color(0xFF1565C0)` |
| `Colors.green` (active icons) | `Color(0xFF42A5F5)` |
| `Colors.white` (body text) | `Color(0xFF0D1B3E)` |
| `Colors.white54` (muted text) | `Color(0xFF5C6E91)` |
| `Colors.white12` (borders) | `Color(0xFFC5D3E8)` |
| `const Color(0xFF050F05)` (map bg) | `Color(0xFFEEF4FF)` |
| `Colors.lightBlueAccent` (LiDAR) | `Color(0xFF42A5F5)` |
| `Colors.cyan` (realtime btn) | `Color(0xFF1565C0)` |
| `Colors.amber` (caution) | `Color(0xFFE65100)` |
| `Colors.red[900]` (danger) | `Color(0xFFC62828)` |
| `Colors.teal[900]` (text badge) | `Color(0xFF00695C)` |

### Per-File Changes

| File | Key changes |
|---|---|
| `main.dart` | Full ThemeData swap (see above) |
| `splash_screen.dart` | Scaffold bg → background; icon → primary; text colors |
| `home_screen.dart` | AppBar bg → primaryDark; camera empty bg → #E8EDF5; overlays; sensor bar; voice strip |
| `status_bar.dart` | Container bg → white; all green → primary/primaryLight; cyan → primary |
| `description_banner.dart` | bg → white; warning badge colors per new palette; obstacle chips bg |
| `chat_bar.dart` | bg → white; field fill → #F0F4FF; send button → primary |
| `navigation_map_screen.dart` | AppBar bg; canvas bg; step list active colors; button colors |
| `room_map_screen.dart` | AppBar bg; coverage bar; direction icon states; guidance panel bg; canvas bg |
| `settings_screen.dart` | Scaffold bg; field fill; button styles; status colors |
| `radar_map_painter.dart` | Canvas bg; ring/arc/dot colors |
| `floor_plan_painter.dart` | Canvas bg; point/grid colors |

---

*Last updated: 2026-04-30*
