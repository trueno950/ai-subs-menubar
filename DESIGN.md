---
name: AI Subs
description: A compact native macOS menu-bar instrument for AI plans and provider usage.
typography:
  title:
    fontFamily: "SF Pro (macOS system)"
    fontSize: "15pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (macOS system)"
    fontSize: "13pt"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro (macOS system)"
    fontSize: "11pt"
    fontWeight: 400
  metric:
    fontFamily: "SF Pro Rounded (macOS system)"
    fontSize: "17pt"
    fontWeight: 700
rounded:
  panel: "14pt"
  control: "7pt"
  icon: "8pt"
spacing:
  compact: "6pt"
  small: "8pt"
  medium: "12pt"
  large: "16pt"
components:
  menu-panel:
    rounded: "{rounded.panel}"
    width: "360pt"
    height: "480pt"
  provider-row:
    padding: "8pt 12pt"
  quota-meter:
    height: "4pt"
  menu-action:
    rounded: "{rounded.control}"
    padding: "6pt 8pt"
    height: "28pt"
---

# Design System: AI Subs

## 1. Overview

**Creative North Star: "The Precision Instrument"**

AI Subs is a personal macOS utility for checking subscription renewals, API spend, and coding-plan quota without leaving the current task. Its visual language should feel like a native menu-bar extra: compact, calm, and immediately legible. Keep one translucent HUD-like panel as the frame; inside it, prefer dense, table-like provider rows over a stack of repeated cards.

The palette and controls adapt to macOS appearance and accent settings. A number must always say what it measures: recurring plan cost, month-to-date API spend, or a provider's own quota cycle. Missing setup is a neutral state; warnings are reserved for real failures or actionable thresholds. This system rejects false alarms, repeated decorative cards, and color-only status.

**Key Characteristics:**
- Compact, technical information hierarchy with familiar macOS controls.
- Adaptive HUD vibrancy around flat, scan-friendly rows.
- Explicit labels and text/icon state cues; semantic colors reinforce rather than replace meaning.
- Distinct treatment for subscription totals, API spend, and plan quota.

## 2. Colors

AI Subs uses semantic macOS colors and materials rather than a fixed hex palette. The panel follows system appearance; `.primary`, `.secondary`, `.tertiary`, `Color.accentColor`, and semantic warning/error colors adapt to the user's settings. Keep the existing single pink SF Symbol accent restrained, and reserve orange/red for actionable warning and critical states.

### Primary
- **System Accent**: `Color.accentColor`. Use for a primary action or a small identity cue, never as decoration across every row.
- **Sparkle Accent**: system pink on the header SF Symbol. Keep this as a single restrained accent.

### Neutral
- **Primary Foreground**: `.primary` for provider names, labels, and key values.
- **Secondary Foreground**: `.secondary` for supporting context and dates.
- **Tertiary Foreground**: `.tertiary` only for optional hints or disabled states, not essential information.
- **HUD Material**: `NSVisualEffectView.Material.hudWindow` with `.behindWindow` blending; this is the adaptive translucent panel surface, not a card fill.
- **Tonal Row Surface**: the current `.quaternary` treatment is being reduced in favor of flat rows and subtle dividers.

### Named Rules
**The Semantic Color Rule.** Missing credentials are neutral. Orange means a recoverable error; red means a high-severity threshold. Always pair color with readable text or an icon.

**The Adaptive Palette Rule.** Do not replace system appearance/accent colors with fixed dark-mode hex values. Let macOS choose the light/dark surface and user accent.

## 3. Typography

**Display Font:** SF Pro (macOS system)
**Body Font:** SF Pro (macOS system)
**Label/Mono Font:** SF Pro Rounded with monospaced digits for currency and usage values.

**Character:** Native, compact system typography with a restrained weight contrast. Numeric values should align and scan quickly; labels should remain legible when the user increases text size.

### Hierarchy
- **Title** (semibold, 15pt): panel identity and short section labels.
- **Metric** (bold, 17pt, rounded, monospaced digits): subscription totals, API spend, and quota percentages.
- **Body** (regular/medium, 13pt): provider and plan names.
- **Caption** (regular, 11pt): renewal/reset dates and secondary setup guidance. Keep essential state out of caption-only text where it could be clipped.

### Named Rules
**The Scan-First Type Rule.** One glance should distinguish the number from its unit and period. Use monospaced digits for changing values and keep the label adjacent.

## 4. Elevation

Depth comes from one native `hudWindow` material blended behind the panel and the system window shadow. Inside the panel, use tonal layering sparingly; the approved direction is flat provider rows with subtle separators, not individually elevated cards. Do not stack blur surfaces or add heavy shadows to data rows.

### Shadow Vocabulary
- **Menu Panel Shadow** (`NSPanel.hasShadow = true`): system shadow separates the single menu panel from the desktop.
- **Provider Rows** (no row shadow): separate with spacing or a subtle divider, not elevation.

### Named Rules
**The One-Glass-Surface Rule.** Keep vibrancy on the outer panel. Rows and progress indicators stay legible, compact, and mostly flat.

## 5. Components

### Menu Panel
- **Shape:** Continuous rounded panel (14pt corner radius).
- **Background:** Native HUD material, behind-window blending, transparent window background.
- **Size:** Current standard frame is 360 × 480pt; preserve enough room for readable content and allow the content area to scroll.
- **Shadow:** Native panel shadow only.

### Provider Rows
- **Structure:** Provider icon and name, explicit connection/usage status, then the primary value aligned at the trailing edge.
- **Spacing:** Compact horizontal padding (12pt); separate rows with a small vertical rhythm or a fine divider.
- **States:** Not connected is neutral and offers a setup action. Actual request errors show warning icon plus text. Disabled state must not look like failure.
- **Quota:** GLM shows percent used, a progress indicator, remaining percentage, and reset timing. The meter is supportive; text remains authoritative.

### Plan Summary
- **Recurring plans:** Show a clearly labeled USD/month total; it includes subscriptions only.
- **API spend:** Show a distinct month-to-date sum from successfully connected monetary-spend providers.
- **Quota providers:** Show their plan-cycle quota separately; never add a percentage to a USD total.

### Quick Add
- **Presets:** ChatGPT Plus, Claude Pro, and GLM Coding Plan prefill the plan name and icon. The user confirms the actual price and renewal day; never infer billing details from a provider name.
- **Custom plans:** Keep an obvious path for any other service.

### Controls
- Prefer native SwiftUI buttons, fields, toggles, and pickers with their standard focus and disabled states.
- Keep setup actions visible when a provider is not connected; do not make the gear button the only route.
- Use semantic text styles where practical so larger accessibility text remains usable.

## 6. Do's and Don'ts

### Do:
- **Do** label values as `plans / month`, `API spend / MTD`, or `quota used / reset`.
- **Do** show a neutral “Not connected” state until a provider has credentials; reserve warnings for actual errors.
- **Do** pair every semantic color with a label or icon.
- **Do** use one glass panel, compact rows, system appearance, and native controls.
- **Do** make quota thresholds actionable and announce them once when crossed.
- **Do** keep preset price and renewal fields editable and user-confirmed.

### Don't:
- **Don't** show a warning-colored error for a provider that is merely not configured.
- **Don't** use oversized dashboards or repeated cards that make a menu-bar utility slow to scan.
- **Don't** communicate status by color alone.
- **Don't** combine recurring subscription cost, API spend, and plan-cycle quota into one ambiguous total.
- **Don't** hard-code a dark palette or use repeated blur/shadow layers.
