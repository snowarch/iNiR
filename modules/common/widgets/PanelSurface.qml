pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import qs.modules.common
import qs.modules.common.functions

// PanelSurface — the shared "panel skin" (el molde de fondo único).
//
// En vez de que cada panel/componente dibuje su propio fondo, borde y esquinas a mano
// (que es lo que hace que todo se vea distinto), lo envuelven en esto y la pinta sale
// consistente. Editar ESTE archivo = cambiar la pinta de todos los que lo usen.
//
// Sabe poner la cara correcta según el estilo activo del shell — la misma lógica que
// antes estaba copiada y divergente en cada panel:
//   zzz    → placa con esquina cortada (chamfer) + hairline (look consola/poster)
//   angel  → tarjeta de vidrio
//   regalia→ tile sólido: jerarquía por masa/color, sin marcos ornamentales
//   inir   → capa plana con borde fino
//   aurora → sub-superficie translúcida
//   material/cards → rectángulo redondeado con el color de capa
//
// Uso:
//   PanelSurface { elevation: 1; /* tu contenido */ }
//   PanelSurface { island: true }            // pastilla (pill) que se redondea sola
//   PanelSurface { borderless: true }        // sin fondo (transparente)
Item {
    id: root

    default property alias content: contentHolder.data

    // Qué tan "elevado" se ve: 0 = fondo base, 1 = contenido (lo normal), 2+ = flotante.
    property int elevation: 1
    // Sin fondo (transparente) — para barras "borderless".
    property bool borderless: false
    // Pastilla: se redondea a la mitad de su alto (las "islas" de la barra).
    property bool island: false
    // Estilo tarjeta (config del usuario): esquinas más redondeadas + borde.
    property bool cardStyle: false
    // Force the body material to use the solid layer base for surfaces that
    // must remain legible regardless of a glass-oriented global style.
    // Shape, borders and dialect-specific chrome are still preserved.
    property bool opaqueSurface: false
    // Override manual de esquinas; -1 = automático según estilo.
    property real radiusOverride: -1
    // Some nested cards already have enough separation from fill/shape and do
    // not need a second outer contour.
    property bool outlined: true
    property bool editorialFocus: false
    property bool editorialGlassMaterial: false
    // Optional explicit stroke width for consumers that expose border tuning.
    // -1 preserves the dialect/default width.
    property real borderWidthOverride: -1
    // En zzz: true = placa con esquina cortada; false = transparente (cuando el
    // contorno del shell ya lo dibuja otra cosa, p.ej. la barra unificada).
    property bool zzzChamfer: true
    // En zzz: dibuja el marco técnico (marcas de registro en las esquinas), como la
    // card tech-frame. Off por defecto; prendelo en superficies grandes/poster.
    property bool techFrame: false
    property string frameLabel: ""
    property string frameIndex: ""

    // Backdrop de vidrio aurora (opt-in): wallpaper blureado DETRÁS del fill
    // translúcido del estilo, para que la transparencia lea como vidrio
    // esmerilado y no como agujero. El consumidor pasa su posición en
    // coordenadas de pantalla (los mismos números que usan los sidebars).
    property bool wallpaperBackdrop: false
    // Optional content-only mask. The surface/shadow stay untouched while child
    // content is clipped to the resolved visual radius. This is intentionally
    // opt-in because it renders the content subtree into an offscreen layer.
    property bool clipContent: false
    property real backdropScreenX: {
        const geometryDependency = root.x + root.y + root.width + root.height
        return root.mapToItem(null, 0, 0).x
    }
    property real backdropScreenY: {
        const geometryDependency = root.x + root.y + root.width + root.height
        return root.mapToItem(null, 0, 0).y
    }
    property real backdropScreenWidth: root.QsWindow?.window?.screen?.width
        ?? Quickshell.screens[0]?.width ?? 1920
    property real backdropScreenHeight: root.QsWindow?.window?.screen?.height
        ?? Quickshell.screens[0]?.height ?? 1080

    // Cara island Ricelin (opt-in por superficie, gateada por config del
    // consumidor): gradiente washi + hairline + sheen + glass, dibujada con
    // Appearance directo — modules/common no puede importar qs.modules.pill.
    property bool islandSkin: false
    // Optional explicit owner for nested surfaces. Empty preserves the global
    // worldview exactly; panel-local dialects such as Ricelin can opt in
    // without being restyled by an unrelated global flag.
    property string surfaceDialect: ""

    readonly property string _resolvedDialect: root.surfaceDialect.length > 0
        ? root.surfaceDialect : root.islandSkin ? "island" : Appearance.globalStyle
    readonly property bool _zzz: root._resolvedDialect === "zzz"
    readonly property bool _angel: root._resolvedDialect === "angel"
    readonly property bool _regalia: root._resolvedDialect === "regalia"
    readonly property bool _inir: root._resolvedDialect === "inir"
    readonly property bool _aurora: root._resolvedDialect === "aurora" || root._angel
    readonly property bool _cookie: root._resolvedDialect === "cookie"
    readonly property bool _editorial: root._resolvedDialect === "editorial"
    readonly property bool _island: root._resolvedDialect === "island"
    readonly property bool _material: root._resolvedDialect === "material"
    readonly property bool _editorialStackActive: root._editorial
        && Appearance.editorial.paperStack && !root.borderless
        && (root.editorialFocus || (root.outlined && root.elevation <= 1))
    readonly property bool _backdropActive: !root.borderless && Appearance.effectsEnabled
        && root.wallpaperBackdrop
        && (root._aurora || (root._editorial && Appearance.editorial.glassActive && !root.editorialFocus))

    // ── Color de fondo (misma elección que hacían los paneles a mano) ──
    // An explicit Material dialect is a real ownership boundary: consumers such
    // as onboarding must not become Aurora glass, Regalia mass or Cookie dough
    // merely because the shell style changes underneath them.
    readonly property color _materialFill: root.elevation <= 0 ? Appearance.m3colors.m3surface
        : root.elevation === 1 ? Appearance.m3colors.m3surfaceContainerLow
        : root.elevation === 2 ? Appearance.m3colors.m3surfaceContainer
        : root.elevation === 3 ? Appearance.m3colors.m3surfaceContainerHigh
        : Appearance.m3colors.m3surfaceContainerHighest
    readonly property color _solidFill: root._material ? root._materialFill
        : root.elevation <= 0 ? Appearance.colors.colLayer0Base
        : root.elevation === 1 ? Appearance.colors.colLayer1Base
        : root.elevation === 2 ? Appearance.colors.colLayer2Base
        : root.elevation === 3 ? Appearance.colors.colLayer3Base
        : Appearance.colors.colLayer4Base
    readonly property color _fill: root.borderless ? "transparent"
        : root._editorial && root.editorialFocus ? Appearance.editorial.ink
        : root._editorial && root.editorialGlassMaterial && Appearance.editorial.glassActive
            ? (root.elevation >= 2 ? Appearance.editorial.glassLayer2 : Appearance.editorial.glassPaper)
        : root._material ? root._materialFill
        : root.opaqueSurface ? root._solidFill
        : root._angel ? Appearance.angel.colGlassCard
        : root._regalia ? (root.elevation <= 0 ? Appearance.regalia.bg0
            : root.elevation === 1 ? Appearance.regalia.bg1
            : root.elevation === 2 ? Appearance.regalia.bg2
            : root.elevation === 3 ? Appearance.regalia.bg3 : Appearance.regalia.bg4)
        : root._inir ? (root.elevation <= 0 ? Appearance.inir.colLayer0 : Appearance.inir.colLayer1)
        : root._aurora ? Appearance.aurora.colSubSurface
        : (root.elevation <= 0 ? Appearance.colors.colLayer0
          : root.elevation === 1 ? Appearance.colors.colLayer1
          : root.elevation === 2 ? Appearance.colors.colLayer2
          : root.elevation === 3 ? Appearance.colors.colLayer3
          : Appearance.colors.colLayer4)

    // ── Esquinas ──
    readonly property real _radius: root.radiusOverride >= 0 ? root.radiusOverride
        : root._island ? (Config.options?.appearance?.island?.radius ?? 18)
        : root.island ? Math.min(width, height) / 2
        : root._angel ? Appearance.angel.roundingSmall
        : root._regalia ? Appearance.regalia.roundNormal
        : root._inir ? Appearance.inir.roundingNormal
        : root._editorial ? Appearance.editorial.radius
        : (root.cardStyle ? Appearance.rounding.normal : Appearance.rounding.small)

    // ── Borde ──
    readonly property real _borderWidth: (root.borderless || !root.outlined) ? 0
        : root.borderWidthOverride >= 0 ? root.borderWidthOverride
        : root.island ? 1
        : root._angel ? Appearance.angel.cardBorderWidth
        : root._regalia ? 0
        : root._editorial ? 1
        : root._inir ? 1
        : (root.cardStyle ? 1 : 0)
    readonly property color _borderColor: root._material ? Appearance.m3colors.m3outlineVariant
        : root._angel ? Appearance.angel.colCardBorder
        : root._regalia ? "transparent"
        : root._inir ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border

    // ── Backdrop de vidrio (aurora opt-in / island glass) debajo de la cara ──
    GlassBackground {
        anchors.fill: parent
        visible: root._backdropActive
        wallpaperBackdropEnabled: root._backdropActive
        forceBackdrop: root._editorial && Appearance.editorial.glassActive
        forceNeutralMaterial: root._editorial
        // Transparent dialects must still be readable if the configured
        // wallpaper disappears or has not decoded yet.
        fallbackColor: root._editorial ? Appearance.editorial.paper : root._solidFill
        overlayColor: root._editorial ? Appearance.editorial.paper : Appearance.colors.colLayer0Base
        blurStrength: root._editorial ? Appearance.editorial.glassBlur : 1
        saturationStrength: root._editorial ? 0.04 : 0.2
        auroraTransparency: root._editorial
            ? (root._editorialStackActive ? 1 : 1 - Appearance.editorial.glassOpacity)
            : Appearance.aurora.popupTransparentize
        radius: root._radius
        screenX: root.backdropScreenX
        screenY: root.backdropScreenY
        screenWidth: root.backdropScreenWidth
        screenHeight: root.backdropScreenHeight
    }

    // ── Cara ZZZ: placa con esquina cortada + hairline ──
    ZzzPlate {
        anchors.fill: parent
        visible: root._zzz && root.zzzChamfer && !root.borderless
        fillColor: root._fill
        strokeColor: Appearance.zzz.hairline
        strokeWidth: root.outlined ? Appearance.zzz.hairlineThick : 0
        chamfer: Appearance.zzz.cutCorner
    }

    // ── Cookie Shapes: one organic face; host geometry/input stay rectangular ──
    Loader {
        anchors.fill: parent
        active: root._cookie && !root.borderless && root.visible
        sourceComponent: CookieFace {
            role: "plate"
            color: root._fill
            radius: root._radius
        }
    }

    RicelinSurface {
        anchors.fill: parent
        visible: root._island && !root.borderless
        radius: root._radius
        glassEnabled: root.wallpaperBackdrop
        screen: root.QsWindow?.window?.screen ?? null
        shadow: false
    }

    // ── Regalia: fitted shell composition. The hard chassis contains a
    // recessed semantic field instead of recoloring the generic Material rectangle.
    RegaliaPlate {
        id: regaliaFace
        anchors.fill: parent
        visible: root._regalia && !root.borderless
        radius: root._radius
        fillColor: root._fill
        elevated: root.elevation >= 2
    }

    // ── Cara resto (y zzz transparente): rectángulo redondeado ──
    Rectangle {
        anchors.fill: parent
        visible: !(root._zzz && root.zzzChamfer && !root.borderless)
            && !root._island && !root._cookie && !root._regalia
        color: root._zzz || (root._editorial && root._backdropActive) ? "transparent" : root._fill
        radius: root._zzz ? Appearance.zzz.cardRadius : root._radius
        border.width: root._zzz ? 0 : root._borderWidth
        border.color: root._borderColor
        Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
        Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
    }

    // Marco técnico poster (marcas de registro en esquinas) — solo zzz, opt-in.
    // Las marcas L de esquina son vocabulario "console" (modo square); en
    // modo round (anime soft) son marcas cuadradas que chocan con la esquina
    // redondeada y se leen feas, así que se suprimen. kept in square.
    ZzzTechFrame {
        anchors.fill: parent
        visible: root._zzz && root.techFrame
        showCornerMarks: !Appearance.zzz.round
        showLabels: root.frameLabel.length > 0 || root.frameIndex.length > 0
        label: root.frameLabel
        index: root.frameIndex
    }

    EditorialPaperStack {
        anchors.fill: parent
        visible: root._editorialStackActive
        faceColor: root._backdropActive ? Appearance.editorial.paper : root._fill
        radius: root._radius
        materialOpacity: (root._backdropActive || root.editorialGlassMaterial && Appearance.editorial.glassActive)
            ? Appearance.editorial.glassOpacity : 1
        backingOpacity: (root._backdropActive || root.editorialGlassMaterial && Appearance.editorial.glassActive)
            ? Appearance.editorial.glassBackingOpacity : 1
    }

    // Contenido encima de la cara.
    Item {
        id: contentHolder
        anchors.fill: parent
        layer.enabled: root.clipContent && root.visible
        layer.effect: GE.OpacityMask {
            maskSource: Item {
                width: contentHolder.width
                height: contentHolder.height

                Rectangle {
                    anchors.fill: parent
                    visible: !root._zzz && !root._cookie
                    radius: root._radius
                    color: "white"
                }

                ZzzPlate {
                    anchors.fill: parent
                    visible: root._zzz
                    fillColor: "white"
                    strokeWidth: 0
                    radius: Appearance.zzz.round ? Appearance.zzz.panelRadius : 0
                }

                CookieFace {
                    anchors.fill: parent
                    visible: root._cookie
                    role: "plate"
                    color: "white"
                    radius: root._radius
                }
            }
        }
    }
}
