---
trigger: model_decision
description: Pull when deciding visual behavior across material, cards, aurora, inir, and angel styles or when choosing the right design tokens and style dispatch.
---

# iNiR Design System (Verified from Appearance.qml)

## The 5 Visual Styles

### Material (default)
- Solid opaque surfaces, Material Design 3 colors from matugen
- No glass, no blur, no special borders
- Colors: `Appearance.colors.colLayer0..4`, `colOnLayer*`, `colPrimary`
- Shadows: standard gaussian via `StyledRectangularShadow`
- No config flag — default when no other style active

### Cards
- Material variant with elevated card containers and cornerStyle=3
- NOT a distinct visual engine — same `Appearance.colors.*` tokens
- Differences are layout flags: `dock.cardStyle`, `sidebar.cardStyle`, `bar.cornerStyle: 3`
- Does NOT appear in style ternaries — always falls through to material case
- `appearance.globalStyleCornerStyles.cards = 3` (fully rounded corners)

### Aurora (`Appearance.auroraEverywhere`)
- Glass/acrylic transparent surfaces over blurred wallpaper
- Tokens: `Appearance.aurora.colOverlay`, `.colSubSurface`, `.colPopupSurface`, `.colElevatedSurface`
- Transparency levels: panels 62%, cards 48%, popups 58%, tooltips 65% opaque
- Parent MUST set `screenX`/`screenY` on `GlassBackground` for correct blur alignment
- In aurora dark mode, outline colors are brightened for contrast

### Inir (`Appearance.inirEverywhere`)
- Terminal-inspired: solid dark opaque with accent borders
- Font forced to monospace (JetBrainsMono NF) via `_forceMono`
- Tokens: `Appearance.inir.colLayer0..3`, `.colBorder*`, `.colText*`
- Fixed rounding: 6/8/12 (NOT scaled by theme)
- `MaterialSymbol` auto-switches to Nerd Font glyphs
- Border system: `colBorder`, `colBorderHover`, `colBorderAccent`, `colBorderFocus`, `colBorderSubtle`, `colBorderMuted`

### Angel (`Appearance.angelEverywhere`)
- Neo-brutalism glass: aurora blur + escalonado shadows + partial borders + inset glow
- Font forced to "Oxanium" via `_useAngelFont`
- `angelEverywhere` implies `auroraEverywhere` (angel is superset)
- ALL parameters user-configurable via `Config.options?.appearance?.angel.*`
- `colorStrength` (default 1.0) multiplies ALL accent tint opacities

Angel subsystems:
- **Glass**: `colGlassPanel`, `colGlassCard`, `colGlassPopup` with per-surface transparency
- **Escalonado**: offset colored rectangles (2px default, 7px hover) instead of gaussian shadows
- **EscalonadoShadow**: glass-backed variant for settings cards
- **Partial borders**: asymmetric gradient borders with `borderCoverage` and per-state opacity
- **Surface borders**: `panelBorderWidth`/`cardBorderWidth` with separate opacities
- **Inset glow**: `insetGlowOpacity`, `insetGlowHeight`, `colInsetGlow`
- **Glow**: `glowOpacity` (0.80), `glowStrongOpacity` (0.65)
- **Accent bars**: `accentBarHeight`, `accentBarWidth` on hover/active

## Style Dispatch Pattern

Priority: angel > inir > aurora > material. Cards is NEVER in ternaries.

```qml
color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
     : Appearance.colors.colLayer1
```

For borders:
```qml
border.width: Appearance.inirEverywhere ? 1
            : Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : 0
```

## Shadow System

`StyledRectangularShadow` (52+ usages) dispatches:
- Material/Aurora/Cards: standard `RectangularShadow` with gaussian blur, uses `colors.colShadow`
- Angel: offset Rectangle colored `angel.colEscalonado`, animates offset on hover
- `EscalonadoShadow`: glass-backed variant for more prominent shadows

## Animation System

Master switches:
- `animationsEnabled`: false during GameMode or `performance.reduceAnimations`
- `effectsEnabled`: false during `performance.lowPower` or GameMode
- `calcEffectiveDuration(ms)`: returns 0 when disabled

8 presets with duration, easing curve, and reusable Component:
elementMove(500ms), elementMoveEnter(400ms), elementMoveExit(200ms), elementMoveFast(200ms), elementResize(300ms), clickBounce(400ms), scroll(200ms), menuDecel(350ms)

## GlassBackground Usage

Parent MUST provide screen-relative position:
```qml
GlassBackground {
    anchors.fill: parent
    radius: myRadius
    screenX: root.mapToGlobal(0, 0).x
    screenY: root.mapToGlobal(0, 0).y
    screenWidth: Quickshell.screens[0]?.width ?? 1920
    screenHeight: Quickshell.screens[0]?.height ?? 1080
    hovered: someHoverState
    fallbackColor: Appearance.colors.colLayer1
    inirColor: Appearance.inir.colLayer1
}
```
