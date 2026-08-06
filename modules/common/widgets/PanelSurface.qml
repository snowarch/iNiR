pragma ComponentBehavior: Bound

import QtQuick
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
    // Override manual de esquinas; -1 = automático según estilo.
    property real radiusOverride: -1
    // Some nested cards already have enough separation from fill/shape and do
    // not need a second outer contour.
    property bool outlined: true
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
    property real backdropScreenX: 0
    property real backdropScreenY: 0
    property real backdropScreenWidth: 1920
    property real backdropScreenHeight: 1080

    // Cara island Ricelin (opt-in por superficie, gateada por config del
    // consumidor): gradiente washi + hairline + sheen + glass, dibujada con
    // Appearance directo — modules/common no puede importar qs.modules.pill.
    property bool islandSkin: false
    // Optional explicit owner for nested surfaces. Empty preserves the global
    // worldview exactly; panel-local dialects such as Ricelin can opt in
    // without being restyled by an unrelated global flag.
    property string surfaceDialect: ""

    readonly property string _resolvedDialect: root.surfaceDialect.length > 0
        ? root.surfaceDialect : Appearance.globalStyle
    readonly property bool _zzz: root._resolvedDialect === "zzz"
    readonly property bool _angel: root._resolvedDialect === "angel"
    readonly property bool _inir: root._resolvedDialect === "inir"
    readonly property bool _aurora: root._resolvedDialect === "aurora" || root._angel
    readonly property bool _cookie: root._resolvedDialect === "cookie"
    readonly property bool _island: root.surfaceDialect.length > 0
        ? root._resolvedDialect === "island"
        : root.islandSkin && !root._zzz
    readonly property real _islandOpacity: Config.options?.appearance?.island?.opacity ?? 1
    readonly property bool _backdropActive: !root.borderless && Appearance.effectsEnabled
        && ((root.wallpaperBackdrop && root._aurora)
            || (root._island && (Config.options?.appearance?.island?.glass ?? true)
                && root._islandOpacity < 0.999))

    // ── Color de fondo (misma elección que hacían los paneles a mano) ──
    readonly property color _fill: root.borderless ? "transparent"
        : root._angel ? Appearance.angel.colGlassCard
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
        : root._inir ? Appearance.inir.roundingNormal
        : (root.cardStyle ? Appearance.rounding.normal : Appearance.rounding.small)

    // ── Borde ──
    readonly property int _borderWidth: (root.borderless || !root.outlined) ? 0
        : root.island ? 1
        : root._angel ? Appearance.angel.cardBorderWidth
        : root._inir ? 1
        : (root.cardStyle ? 1 : 0)
    readonly property color _borderColor: root._angel ? Appearance.angel.colCardBorder
        : root._inir ? Appearance.inir.colBorder
        : Appearance.colors.colLayer0Border

    // ── Backdrop de vidrio (aurora opt-in / island glass) debajo de la cara ──
    GlassBackground {
        anchors.fill: parent
        visible: root._backdropActive
        wallpaperBackdropEnabled: root._backdropActive
        // Island glass fuera de aurora: GlassBackground gatea su blur a aurora,
        // forceBackdrop lo enciende igual. Blur fijo de la casa (island.glassBlur
        // fino queda para IslandPanel, que alinea offsets por superficie).
        forceBackdrop: root._backdropActive && root._island
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

    // ── Cara island (Ricelin): gradiente cardTop→cardBot + hairline + sheen ──
    Rectangle {
        id: islandFace
        anchors.fill: parent
        visible: root._island
        radius: root._radius
        border.width: root.outlined ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Appearance.colors.colLayer3, root._islandOpacity) }
            GradientStop { position: 1.0; color: Qt.alpha(Appearance.colors.colLayer1, root._islandOpacity) }
        }

        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.topMargin: 1
            anchors.leftMargin: islandFace.radius * 0.6
            anchors.rightMargin: islandFace.radius * 0.6
            height: 1
            visible: Config.options?.appearance?.island?.sheen ?? true
            color: Qt.alpha(Appearance.colors.colOnLayer0, 0.07)
        }
    }

    // ── Cara resto (y zzz transparente): rectángulo redondeado ──
    Rectangle {
        anchors.fill: parent
        visible: !(root._zzz && root.zzzChamfer && !root.borderless)
            && !root._island && !root._cookie
        color: root._zzz ? "transparent" : root._fill
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

    // Contenido encima de la cara.
    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
