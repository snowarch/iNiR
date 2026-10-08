import qs.modules.common
import QtQuick
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    property string text: ""
    property color color: Appearance.colors.colOnSurface
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignVCenter

    // Opt-in gradient down the glyph's own colour (the iRiS tile pack uses it so a
    // glyph keeps its identity hue). Off, the glyph is one flat colour as always.
    property bool glyphGradient: false
    readonly property bool gradientActive: root.glyphGradient && !root.useJp && !root.useNerd && root.text.length > 0
    property alias font: iconText.font
    property alias style: iconText.style
    property alias styleColor: iconText.styleColor
    property bool animateChange: false  // Compatibility with StyledText
    property bool forceNerd: false  // Force Nerd Font rendering (text is already a glyph)
    property bool animateFill: false
    property int textRenderType: Text.NativeRendering
    
    // Use Nerd Font only when explicitly requested.
    readonly property bool useNerd: forceNerd
    readonly property string nerdGlyph: forceNerd ? text : ""
    readonly property bool hasNerdGlyph: useNerd && nerdGlyph !== ""

    // "jp:<char>" renders the raw character in the Japanese UI font instead of
    // a Material Symbols name — lets registry icons be kanji/katakana.
    readonly property bool useJp: text.startsWith("jp:")
    readonly property string jpGlyph: useJp ? text.slice(3) : ""
    
    // Nerd fonts need slightly larger size to match Material Symbols visually
    readonly property real effectiveFontSize: (useNerd && hasNerdGlyph) ? iconSize * 1.1 : iconSize
    readonly property real effectiveSize: (useNerd && hasNerdGlyph) ? iconSize * 1.1 : iconSize
    
    // Use iconSize for consistent sizing regardless of font metrics
    implicitWidth: effectiveSize
    implicitHeight: effectiveSize
    
    readonly property real clampedFill: Math.max(0, Math.min(1, fill))
    readonly property real effectiveFill: animateFill && !Appearance.regaliaEverywhere
        ? (clampedFill < 0.01 ? 0 : (clampedFill > 0.99 ? 1 : clampedFill))
        : Math.round(clampedFill)
    // Material Symbols variable font axis range is 20..48; keeping it in-range avoids distorted fill at small icon sizes.
    readonly property real effectiveOpsz: 24
    
    Text {
        id: iconText
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        text: root.useJp ? root.jpGlyph
            : (root.useNerd && root.hasNerdGlyph) ? root.nerdGlyph : root.text
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        renderType: root.textRenderType
        font {
            hintingPreference: (root.useNerd && root.hasNerdGlyph) ? Font.PreferFullHinting : Font.PreferNoHinting
            family: root.useJp ? "Zen Kaku Gothic New"
                : (root.useNerd && root.hasNerdGlyph)
                ? (Appearance?.font.family.monospace ?? "JetBrainsMono Nerd Font")
                : (Appearance?.font.family.iconMaterial ?? "Material Symbols Rounded")
            pixelSize: root.useJp ? root.iconSize * 0.92 : root.effectiveFontSize
            weight: root.useJp ? Font.Medium : Font.Normal
            variableAxes: (root.useJp || (root.useNerd && root.hasNerdGlyph)) ? ({}) : ({
                "FILL": root.effectiveFill,
                "opsz": root.effectiveOpsz,
            })
        }
    }

    Rectangle {
        id: gradientFill
        anchors.fill: iconText
        visible: root.gradientActive
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root.color, 1.45) }
            GradientStop { position: 1.0; color: Qt.darker(root.color, 1.18) }
        }
        layer.enabled: root.gradientActive
        layer.smooth: true
        layer.effect: GE.OpacityMask { maskSource: iconText }
    }

    Behavior on fill {
        enabled: root.animateFill && Appearance.animationsEnabled && !Appearance.regaliaEverywhere
        NumberAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}
