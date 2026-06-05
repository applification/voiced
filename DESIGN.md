---
name: Voiced
description: "A quiet, native-feeling dictation companion for fast capture and clean transcription."
colors:
  primary: "#88D0A0"
  ink: "#000808"
  ink-raised: "#081010"
  ink-soft: "#101818"
  panel: "#181C1C"
  panel-muted: "#384840"
  mint: "#88D0A0"
  mint-muted: "#80B890"
  mint-deep: "#385040"
  rim: "#E8ECE8"
  surface: "#F7FAF8"
  surface-muted: "#E7EFEA"
  text: "#101818"
  text-muted: "#385040"
typography:
  display:
    fontFamily: "Geist, Arial, Helvetica, sans-serif"
    fontSize: "5.5rem"
    fontWeight: 650
    lineHeight: 0.96
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Geist, Arial, Helvetica, sans-serif"
    fontSize: "3.25rem"
    fontWeight: 620
    lineHeight: 1.04
    letterSpacing: "-0.02em"
  title:
    fontFamily: "Geist, Arial, Helvetica, sans-serif"
    fontSize: "1.25rem"
    fontWeight: 620
    lineHeight: 1.2
    letterSpacing: "0px"
  body:
    fontFamily: "Geist, Arial, Helvetica, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.65
    letterSpacing: "0px"
  label:
    fontFamily: "Geist Mono, ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "0.8125rem"
    fontWeight: 520
    lineHeight: 1.3
    letterSpacing: "0px"
rounded:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "18px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "40px"
  xxl: "72px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
    typography: "{typography.label}"
  button-primary-hover:
    backgroundColor: "{colors.mint-muted}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
  button-secondary:
    backgroundColor: "{colors.ink-soft}"
    textColor: "{colors.rim}"
    rounded: "{rounded.pill}"
    padding: "12px 18px"
    typography: "{typography.label}"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "24px"
---

# Design System: Voiced

## 1. Overview

**Creative North Star: "The Quiet Recording Booth"**

Voiced should feel like a small, reliable audio instrument rather than a broad productivity platform. The app icon sets the tone: a deep, almost-black booth, a softened charcoal sound capsule, a mint waveform, and a pale rim that feels precise without being clinical. The website should make that object immediate in the first viewport and let the interface language grow from it.

The marketing surface can be more atmospheric than the mac app, but it should stay focused on capture, trust, and speed. Use darkness as acoustic quiet, mint as live signal, and pale surfaces as clean transcript output. The mac app should translate the same identity into native materials, restrained controls, and system typography where appropriate.

**Key Characteristics:**
- Quiet contrast: dark booth surfaces balanced by clean transcript surfaces.
- Signal color: mint is the product's voice and should stay rare enough to matter.
- Native precision: controls are compact, legible, and calm.
- Audio materiality: waveforms, recording states, transcript blocks, and keyboard hints are the natural visual assets.
- No generic SaaS gloss: avoid purple gradients, decorative dashboards, fake analytics, and oversized card grids.

## 2. Colors

The palette is extracted from `Config/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`: near-black acoustic space, fresh mint signal, softened charcoal structure, and pale rim highlights.

### Primary

- **Signal Mint** (`#88D0A0`): the live voice color. Use for the waveform, primary action, active recording state, selection, and key confirmation moments.
- **Muted Signal Mint** (`#80B890`): hover, pressed, and lower-emphasis mint states.
- **Deep Signal Green** (`#385040`): muted text on mint-tinted surfaces, inactive waveform bars, or subtle graph marks.

### Secondary

- **Booth Ink** (`#000808`): hero backgrounds, dark app previews, and the deepest surface in the system.
- **Raised Ink** (`#081010`): large dark panels that need separation from pure booth ink.
- **Soft Ink** (`#101818`): dark cards, navigation, and button backgrounds.

### Neutral

- **Charcoal Panel** (`#181C1C`): sound capsule surfaces, dark cards, and macOS popover-like panes.
- **Muted Charcoal** (`#384840`): dark-mode secondary text, inactive bars, subtle dividers, and icon strokes.
- **Pale Rim** (`#E8ECE8`): hairline outlines, focus rims, separators on dark surfaces, and small highlights.
- **Transcript Surface** (`#F7FAF8`): primary light background for website content sections.
- **Transcript Muted** (`#E7EFEA`): alternate light band, input fill, and low-emphasis panels.
- **Text Ink** (`#101818`): body text on light surfaces.
- **Muted Text Green** (`#385040`): secondary text on light surfaces, with contrast checked before use.

### Named Rules

**The Signal Rarity Rule.** Mint should usually occupy less than 10% of a screen. When everything is mint, nothing is recording.

**The Booth-To-Transcript Rule.** Dark surfaces represent listening and capture; pale surfaces represent output, clarity, and review.

## 3. Typography

**Display Font:** Geist, with Arial and Helvetica fallbacks.
**Body Font:** Geist, with Arial and Helvetica fallbacks.
**Label/Mono Font:** Geist Mono, with SF Mono and Menlo fallbacks.

**Character:** The type should feel contemporary, compact, and native to a macOS utility. Use weight, size, and spacing for hierarchy rather than decorative font pairing.

### Hierarchy

- **Display** (650, `clamp(3rem, 8vw, 5.5rem)`, 0.96): website hero statements and major campaign moments. Keep line length short and use `text-wrap: balance`.
- **Headline** (620, `clamp(2rem, 4vw, 3.25rem)`, 1.04): section leads, product claims, and feature clusters.
- **Title** (620, `1.25rem`, 1.2): component headings, settings group labels, and short cards.
- **Body** (400, `1rem`, 1.65): product explanation, docs-style support copy, and release notes. Cap prose at 65-75ch.
- **Label** (520, `0.8125rem`, 1.3): buttons, metadata, hotkeys, status text, and compact navigation. Do not force uppercase.

### Named Rules

**The Utility Type Rule.** Voiced is a tool, not an editorial magazine. Avoid serif display type, italic hero flourishes, and ornamental pull quotes unless the brand deliberately changes direction.

## 4. Elevation

Voiced is mostly flat and tonal. Depth comes from color steps, precise rims, and state changes rather than heavy shadow. The website may use a soft ambient shadow for app screenshots or floating recording controls, but cards and sections should not carry decorative drop shadows by default.

### Shadow Vocabulary

- **App Float** (`box-shadow: 0 14px 40px rgba(0, 8, 8, 0.22)`): use only for the main product screenshot, floating recorder, or a modal preview against a light background.
- **Control Lift** (`box-shadow: 0 6px 14px rgba(0, 8, 8, 0.16)`): use for hover or active state on controls that physically lift.
- **No Shadow** (`box-shadow: none`): default for cards, content bands, navigation, settings panes, and transcript blocks.

### Named Rules

**The Flat-At-Rest Rule.** Static UI sits in the plane. Motion, hover, modal focus, or active recording may lift.

## 5. Components

Components should feel compact, tactile, and instrument-like. Use familiar controls on macOS, then bring the icon's mint signal and dark booth vocabulary into moments that represent audio capture.

### Buttons

- **Shape:** pill for command buttons (`999px`), `8px` for compact icon buttons and segmented controls.
- **Primary:** Signal Mint background (`#88D0A0`) with Booth Ink text (`#000808`), `12px 18px` padding, label typography. Use for "Download Voiced", "Start recording", and "Save transcript".
- **Hover / Focus:** shift to Muted Signal Mint (`#80B890`); focus uses a 2px Pale Rim outline plus a 2px mint outer ring on dark surfaces.
- **Secondary / Ghost:** Soft Ink background with Pale Rim text on dark surfaces; transparent with a `1px` Pale Rim or Transcript Muted border on light surfaces.

### Chips

- **Style:** compact pills for hotkeys, model names, and status. Use Soft Ink with Pale Rim text on dark backgrounds; use Transcript Muted with Text Ink on light backgrounds.
- **State:** active recording chips may use Signal Mint with Booth Ink text. Inactive states should use Muted Charcoal or Deep Signal Green, not gray-blue.

### Cards / Containers

- **Corner Style:** `12px` default, `18px` only for major product preview containers. Avoid oversized rounded cards.
- **Background:** Transcript Surface for light cards, Charcoal Panel or Soft Ink for dark product previews.
- **Shadow Strategy:** no shadow at rest. Use thin borders, tonal shifts, and Pale Rim outlines.
- **Border:** `1px solid #E8ECE8` on light surfaces or `1px solid rgba(232, 236, 232, 0.18)` on dark surfaces.
- **Internal Padding:** `24px` for cards, `16px` for compact controls, `40px` for major website bands.

### Inputs / Fields

- **Style:** `8px` radius, Transcript Muted fill on light surfaces, Soft Ink fill on dark surfaces, `1px` tonal border.
- **Focus:** mint border or ring, never a generic blue browser outline.
- **Error / Disabled:** errors should use a distinct warm red introduced only when needed; disabled fields reduce contrast through opacity and text weight, not blur.

### Navigation

- **Style:** minimal and stable. Website nav should use Text Ink or Pale Rim depending on background, with mint reserved for the active or primary action.
- **Typography:** label role, sentence case, no tracked uppercase nav.
- **Mobile:** keep navigation compact; prioritize product name, primary action, and essential links.

### Signature Component: Waveform

The waveform is Voiced's signature visual. Bars use rounded caps, uneven heights, and Signal Mint as the active state. On dark booth surfaces, inactive bars use Deep Signal Green; on light transcript surfaces, inactive bars use Transcript Muted with a mint active sweep. Animation should be subtle and respect `prefers-reduced-motion`.

## 6. Do's and Don'ts

### Do:

- **Do** use the app icon as the first source of truth for color, proportion, and mood.
- **Do** make the website's first viewport show the product identity: icon, waveform, recorder, transcript, or real app screenshot.
- **Do** keep mint rare and meaningful: primary actions, active recording, selected text, and live signal.
- **Do** use pale transcript surfaces for reading, documentation, privacy, and support content.
- **Do** check contrast for Muted Text Green (`#385040`) on every tinted surface before shipping.
- **Do** prefer native macOS controls and spacing in the app, with brand color reserved for recording and confirmation.

### Don't:

- **Don't** use purple or blue gradients, neon glows, glassmorphism, or generic AI-product visual tropes.
- **Don't** build the website as repeated icon-heading-text card grids.
- **Don't** use decorative waveform art that does not correspond to recording, playback, state, or product identity.
- **Don't** over-round cards or sections beyond `18px`; the app icon is rounded because it is an icon, not because every UI panel should be.
- **Don't** put tiny uppercase tracked labels above every section heading.
- **Don't** use heavy shadows on ordinary cards. Use tonal layering and rims first.
- **Don't** make the brand feel like a meeting notes platform, analytics dashboard, or enterprise SaaS suite. Voiced is a focused dictation companion.
