import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MaterialShape {
    id: root
    property alias text: symbol.text
    property alias iconSize: symbol.iconSize
    property alias fill: symbol.fill
    property alias font: symbol.font
    property alias colSymbol: symbol.color
    property real padding: 6

    color: Appearance.zzzEverywhere ? ColorUtils.transparentize(Appearance.zzz.paperAlt, 0.10)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colSecondaryContainer
    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    colSymbol: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer1
        : Appearance.colors.colOnSecondaryContainer
    shape: Appearance.zzzEverywhere ? MaterialShape.Shape.Square : MaterialShape.Shape.Clover4Leaf
    implicitSize: Math.max(symbol.implicitWidth, symbol.implicitHeight) + padding * 2

    MaterialSymbol {
        id: symbol
        anchors.centerIn: parent
        color: root.colSymbol
    }
}
