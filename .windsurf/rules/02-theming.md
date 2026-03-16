---
trigger: model_decision
description: Pull when working on colors, fonts, rounding, styles, aurora/inir/angel tokens, or any theme-aware UI behavior.
---

# iNiR Theming — Complete Token Reference (Verified from Appearance.qml, 881 lines)

## Style System

### Detection Flags (Appearance.qml L71-76)
```
globalStyle: string              ← Config.options?.appearance?.globalStyle ?? "material"
inirEverywhere: bool             ← globalStyle === "inir"
angelEverywhere: bool            ← globalStyle === "angel"
auroraEverywhere: bool           ← globalStyle === "aurora" || globalStyle === "angel"
```

Angel implies aurora. Cards has NO flag — uses material tokens with layout differences.

### Font Forcing (L339-341)
- inir: forces monospace (`_forceMono = true`)
- angel: forces Oxanium (`_useAngelFont = true`)
- Some themes force mono via `_themeMeta.fontStyle === "mono"`

## Color Tokens: `Appearance.colors.*` (L180-308)

### Layer System (backgrounds)
```
colLayer0, colLayer0Base, colLayer0Hover, colLayer0Active, colLayer0Border
colLayer1, colLayer1Base, colLayer1Hover, colLayer1Active
colLayer2, colLayer2Base, colLayer2Hover, colLayer2Active, colLayer2Disabled
colLayer3, colLayer3Base, colLayer3Hover, colLayer3Active
colLayer4, colLayer4Base, colLayer4Hover, colLayer4Active
```

### Text on layers
```
colOnLayer0, colOnLayer1, colOnLayer1Inactive, colOnLayer2, colOnLayer2Disabled, colOnLayer3, colOnLayer4
colSubtext
```

### Primary
```
colPrimary, colOnPrimary, colPrimaryHover, colPrimaryActive
colPrimaryContainer, colPrimaryContainerHover, colPrimaryContainerActive, colOnPrimaryContainer
```

### Secondary
```
colSecondary, colSecondaryHover, colSecondaryActive, colOnSecondary
colSecondaryContainer, colSecondaryContainerHover, colSecondaryContainerActive, colOnSecondaryContainer
```

### Tertiary
```
colTertiary, colTertiaryHover, colTertiaryActive
colTertiaryContainer, colTertiaryContainerHover, colTertiaryContainerActive
colOnTertiary, colOnTertiaryContainer
```

### Surface
```
colBackgroundSurfaceContainer
colSurfaceContainerLow, colSurfaceContainer, colSurfaceContainerHigh, colSurfaceContainerHighest
colSurfaceContainerHighestHover, colSurfaceContainerHighestActive
colOnSurface, colOnSurfaceVariant
```

### Utility
```
colTooltip, colOnTooltip, colScrim, colShadow
colOutline, colOutlineVariant
colError, colErrorHover, colErrorActive, colOnError
colErrorContainer, colErrorContainerHover, colErrorContainerActive, colOnErrorContainer
```

### WRONG names that DO NOT EXIST
`primary`, `surface`, `onSurface`, `background`, `onBackground` — these are NOT valid. Always use `col` prefix.

## Font Tokens: `Appearance.font.*` (L344-388)

### Families
```
font.family.main        ← "Roboto Flex" (angel: "Oxanium", inir: monospace)
font.family.numbers     ← "Rubik" (angel: "Oxanium")
font.family.title       ← "Gabarito" (angel: "Oxanium", inir: monospace)
font.family.iconMaterial ← "Material Symbols Rounded"
font.family.iconNerd    ← "JetBrains Mono NF"
font.family.monospace   ← "JetBrainsMono Nerd Font" (config overridable)
font.family.reading     ← "Readex Pro"
font.family.expressive  ← "Space Grotesk"
```

### Pixel Sizes (all × fontSizeScale, default 1.0)
```
font.pixelSize.smallest  = 10
font.pixelSize.smaller   = 12
font.pixelSize.smallie   = 13
font.pixelSize.small     = 15
font.pixelSize.normal    = 16
font.pixelSize.large     = 17
font.pixelSize.larger    = 19
font.pixelSize.huge      = 22
font.pixelSize.hugeass   = 23
font.pixelSize.title     = huge (alias)
```

## Rounding Tokens: `Appearance.rounding.*` (L310-325)

All scaled by `roundingScale` (default 1.0, theme-dependent):
```
rounding.unsharpen    = 2  × scale
rounding.unsharpenmore = 6  × scale
rounding.verysmall    = 8  × scale
rounding.small        = 12 × scale
rounding.normal       = 17 × scale
rounding.large        = 23 × scale
rounding.verylarge    = 30 × scale
rounding.full         = 9999 (constant)
rounding.screenRounding = large (alias)
rounding.windowRounding = 18 × scale
```

## Animation System (L88-506)

### Master switches
```
animationsEnabled: bool    ← false when GameMode or config reduceAnimations
effectsEnabled: bool       ← false when lowPower or GameMode disables effects
calcEffectiveDuration(ms)  ← returns 0 when animations disabled
```

### Presets: `Appearance.animation.*`
Each has `.duration`, `.type`, `.bezierCurve`, and `.numberAnimation` Component:
```
elementMove          500ms   expressiveDefaultSpatial    ← general spatial moves
elementMoveEnter     400ms   emphasizedDecel             ← panel open/enter
elementMoveExit      200ms   emphasizedAccel             ← panel close/exit
elementMoveFast      200ms   expressiveEffects           ← color + fast anims
elementResize        300ms   emphasized                  ← size changes
clickBounce          400ms   expressiveDefaultSpatial    ← button bounce
scroll               200ms   standardDecel               ← scroll position
menuDecel            350ms   OutExpo                     ← menu slide-in
```

Usage: `Behavior on x { animation: Appearance.animation.elementMove.numberAnimation }`

## Aurora Style: `Appearance.aurora.*` (L508-556)

Transparent glass surfaces over blurred wallpaper.

### Transparency levels
```
overlayTransparentize     = 0.38   (panels: 62% opaque)
subSurfaceTransparentize  = 0.52   (cards: 48% opaque)
popupTransparentize       = 0.42   (popups: 58% opaque)
tooltipTransparentize     = 0.35   (tooltips: 65% opaque)
```

### Colors
```
colOverlay, colOverlayHover
colSubSurface, colSubSurfaceHover, colSubSurfaceActive
colElevatedSurface, colElevatedSurfaceHover
colPopupSurface, colPopupSurfaceHover, colPopupSurfaceActive
colTooltipSurface, colTooltipBorder
colDialogSurface
colPopupBorder, colTextSecondary
```

## iNiR Style: `Appearance.inir.*` (L558-682)

Terminal-inspired: solid dark opaque with accent borders, monospace font.

### Layers
```
colLayer0..3, colOnLayer0..3
colLayer1Hover, colLayer2Hover, colLayer3Hover
colLayer1Active, colLayer2Active, colLayer3Active
```

### Borders
```
borderScale                          ← from theme meta
colBorder, colBorderHover, colBorderAccent, colBorderFocus, colBorderSubtle, colBorderMuted
```

### Text
```
colText, colTextSecondary, colTextMuted, colTextDisabled, colLabel, colLabelSecondary
```

### Primary/Accent
```
colPrimary, colPrimaryHover, colPrimaryActive, colOnPrimary
colPrimaryContainer, colPrimaryContainerHover, colPrimaryContainerActive, colOnPrimaryContainer
colSecondary, colSecondaryContainer, colOnSecondaryContainer, colTertiary, colAccent
```

### Semantic
```
colSuccess, colOnSuccess, colSuccessContainer
colError, colOnError, colErrorContainer
colWarning (=tertiary), colInfo (=secondary)
```

### Component aliases
```
colSurface, colSurfaceHover, colPopupSurface, colOverlay
colTooltip, colTooltipBorder, colDialog, colDialogBorder
colInput, colInputBorder, colInputBorderFocus, colInputPlaceholder
colScrollbar, colScrollbarThumb, colScrollbarThumbHover
colSelection, colSelectionHover, colOnSelection
```

### Rounding (FIXED, not scaled)
```
roundingSmall  = 6
roundingNormal = 8
roundingLarge  = 12
```

## Angel Style: `Appearance.angel.*` (L691-830)

Neo-brutalism glass: aurora blur + escalonado shadows + partial borders + inset glow. ALL configurable via `Config.options?.appearance?.angel.*`.

### Blur
```
blurIntensity (0.25), blurSaturation (0.15), overlayOpacity (0.35), noiseOpacity (0.15), vignetteStrength (0.4)
```

### Glass transparency
```
panelTransparentize (0.35), cardTransparentize (0.50), popupTransparentize (0.35), tooltipTransparentize (0.25)
```

### Glass colors
```
colGlassPanel, colGlassCard, colGlassCardHover, colGlassCardActive
colGlassPopup, colGlassPopupHover, colGlassPopupActive
colGlassTooltip, colGlassDialog, colGlassElevated, colGlassElevatedHover
```

### Escalonado (offset shadow rectangles)
```
escalonadoOffsetX/Y (2px), escalonadoHoverOffsetX/Y (7px)
escalonadoOpacity (0.40), escalonadoBorderOpacity (0.60), escalonadoHoverOpacity (0.60)
colEscalonado, colEscalonadoBorder, colEscalonadoHover
colorStrength (1.0) — global multiplier for accent tint opacities
```

### EscalonadoShadow (glass-backed variant)
```
shadowOffsetX/Y (4px), shadowHoverOffsetX/Y (10px)
shadowGlass (true), shadowGlassBlur (0.15), shadowGlassOverlay (0.50)
colShadow, colShadowBorder, colShadowHover
```

### Partial borders
```
borderWidth (1.5), borderCoverage (0.0), accentBarHeight/Width (0)
borderOpacity (0.0), borderHoverOpacity (0.0), borderActiveOpacity (0.0)
colBorder, colBorderHover, colBorderActive, colBorderSubtle, colAccentBar
```

### Surface borders
```
panelBorderWidth (0), cardBorderWidth (1)
panelBorderOpacity (0.0), cardBorderOpacity (0.30)
colPanelBorder, colCardBorder
```

### Inset glow
```
insetGlowOpacity (0.0), insetGlowHeight (0), colInsetGlow
```

### Glow
```
glowOpacity (0.80), glowStrongOpacity (0.65), colGlow, colGlowStrong
```

### Text
```
colText, colTextSecondary, colTextMuted, colTextDim
colPrimary, colPrimaryHover, colOnPrimary, colSecondary, colTertiary
```

### Rounding (configurable)
```
roundingSmall  = Config…angel.rounding.small  ?? 10
roundingNormal = Config…angel.rounding.normal ?? 15
roundingLarge  = Config…angel.rounding.large  ?? 25
```
