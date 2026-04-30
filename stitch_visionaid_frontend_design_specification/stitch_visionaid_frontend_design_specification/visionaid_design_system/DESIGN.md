---
name: VisionAid Design System
colors:
  surface: '#f9f9ff'
  surface-dim: '#d8dae2'
  surface-bright: '#f9f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f2f3fb'
  surface-container: '#ecedf6'
  surface-container-high: '#e7e8f0'
  surface-container-highest: '#e1e2ea'
  on-surface: '#191c21'
  on-surface-variant: '#424752'
  inverse-surface: '#2e3037'
  inverse-on-surface: '#eff0f9'
  outline: '#727783'
  outline-variant: '#c2c6d4'
  surface-tint: '#005db7'
  primary: '#004d99'
  on-primary: '#ffffff'
  primary-container: '#1565c0'
  on-primary-container: '#dae5ff'
  inverse-primary: '#a9c7ff'
  secondary: '#00629d'
  on-secondary: '#ffffff'
  secondary-container: '#4fafff'
  on-secondary-container: '#004069'
  tertiary: '#134aa4'
  on-tertiary: '#ffffff'
  tertiary-container: '#3563be'
  on-tertiary-container: '#dde5ff'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#d6e3ff'
  primary-fixed-dim: '#a9c7ff'
  on-primary-fixed: '#001b3d'
  on-primary-fixed-variant: '#00468c'
  secondary-fixed: '#cfe5ff'
  secondary-fixed-dim: '#99cbff'
  on-secondary-fixed: '#001d34'
  on-secondary-fixed-variant: '#004a78'
  tertiary-fixed: '#d9e2ff'
  tertiary-fixed-dim: '#b0c6ff'
  on-tertiary-fixed: '#001945'
  on-tertiary-fixed-variant: '#00429c'
  background: '#f9f9ff'
  on-background: '#191c21'
  surface-variant: '#e1e2ea'
typography:
  h1:
    fontFamily: Public Sans
    fontSize: 40px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.02em
  h2:
    fontFamily: Public Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: '1.2'
    letterSpacing: -0.01em
  h3:
    fontFamily: Public Sans
    fontSize: 24px
    fontWeight: '600'
    lineHeight: '1.3'
    letterSpacing: '0'
  body-lg:
    fontFamily: Lexend
    fontSize: 20px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0.01em
  body-md:
    fontFamily: Lexend
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.5'
    letterSpacing: 0.01em
  label-bold:
    fontFamily: Lexend
    fontSize: 16px
    fontWeight: '600'
    lineHeight: '1.2'
    letterSpacing: 0.05em
  caption:
    fontFamily: Lexend
    fontSize: 14px
    fontWeight: '500'
    lineHeight: '1.4'
    letterSpacing: 0.02em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  touch-target-min: 44px
  margin-mobile: 24px
  gutter: 16px
  stack-sm: 12px
  stack-md: 24px
  stack-lg: 40px
---

## Brand & Style

This design system is built on a foundation of absolute clarity and unwavering reliability. Designed for a navigation assistant, the brand personality is **guiding, dependable, and ultra-legible**. The visual direction follows a **Modern Institutional** style—blending the structured reliability of governmental accessibility standards with a clean, contemporary tech aesthetic. 

The emotional goal is to reduce cognitive load and anxiety for users navigating complex environments. This is achieved through high-contrast interfaces, generous whitespace, and a "function-over-form" philosophy that ensures every element serves a clear purpose.

## Colors

The palette is optimized for **WCAG 2.1 AAA compliance**. The core is a spectrum of blues that evoke trust and professional assistance. 

- **Primary (#1565C0):** Used for critical action buttons and active states to ensure maximum visibility.
- **Surface & Background:** A tinted off-white background (#F0F4FF) reduces screen glare while maintaining a crisp separation from pure white (#FFFFFF) surface cards.
- **High Contrast:** All text-to-background ratios must exceed 7:1 for body copy and 4.5:1 for large headings. Secondary and Light variants are used strictly for non-critical decorative elements or as backgrounds for high-contrast icons.

## Typography

Typography is the primary vehicle for navigation in this design system. We utilize **Public Sans** for headings due to its institutional clarity and **Lexend** for body text, as it was specifically designed to reduce visual stress and improve reading proficiency.

Key constraints:
- **No text smaller than 14px** is permitted under any circumstances.
- **Body text defaults to 18px** to ensure legibility while in motion.
- **Line heights** are generous (1.5x for body) to prevent "crowding" of characters.

## Layout & Spacing

This design system uses a **fluid grid with strict safe-area margins**. The layout rhythm is based on an 8px square grid, ensuring all components align predictably. 

- **Touch Targets:** A mandatory minimum tap target of **44x44px** is enforced for all interactive elements, with 48px being the preferred standard.
- **Padding:** Use large internal padding (min 16px) for cards and containers to ensure content never feels cramped.
- **Visual Hierarchy:** Vertical stacking follows a "Progressive Disclosure" model—primary navigation elements are always anchored at the bottom (thumb-zone) or top-center for immediate access.

## Elevation & Depth

This system prioritizes **Tonal Layers** over complex shadows to maintain high contrast for visually impaired users. 

- **Level 0 (Background):** #F0F4FF (Flat).
- **Level 1 (Surface/Cards):** #FFFFFF with a subtle 1px stroke (#D1D9E6) to define boundaries without relying on blur.
- **Level 2 (Active/Floating):** Used for "Start Navigation" or "SOS" buttons. These use high-contrast shadows—darker and more defined than standard UI shadows (e.g., 15% opacity PrimaryDark) to ensure they "pop" off the background.
- **Focus States:** A 3px high-contrast "PrimaryLight" ring must appear around any focused element for keyboard or screen-reader navigation.

## Shapes

The shape language is **Rounded (0.5rem)**. This choice balances a modern, friendly feel with enough structure to look "official" and serious. 

- **Buttons:** Use `rounded-lg` (1rem) to distinguish them clearly from layout cards.
- **Status Badges:** Use fully rounded (pill) shapes for immediate recognition.
- **Input Fields:** Use standard `rounded` (0.5rem) to maintain a blocky, stable appearance that suggests input security.

## Components

### Buttons
- **Primary:** Solid #1565C0 background with White text. Bold weight. Height: 56px for main actions.
- **Secondary/Outlined:** 2px stroke of #1565C0. Never use 1px strokes for interactive elements.
- **Icon Buttons:** Must include a 44px minimum circular hit area, even if the icon is smaller.

### Status Badges
- Used for "Route Clear," "Obstacle Detected," or "GPS Signal." 
- Badges must pair a high-contrast icon with text; color alone must not be the only indicator of status.

### Cards
- Surfaces for location info or directions. Use a 1px border (#D1D9E6) and no heavy drop shadows. Internal padding should be at least 20px.

### Inputs & Selectors
- Text fields must have persistent labels (no floating labels that disappear). 
- Active states use a 3px #1565C0 border to clearly indicate focus.

### Navigation Progress
- Large, bold directional arrows with high-contrast backgrounds. Avoid thin-line iconography; use "filled" icon sets for better weight and visibility.