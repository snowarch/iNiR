import QtQuick
import qs.modules.common
import qs.modules.common.functions

Rectangle {
    id: root
    anchors.fill: parent
    // A negative override keeps existing surfaces on the global overlay value.
    property real surfaceOpacity: -1
    property bool useSurfaceColorOverride: false
    property color surfaceColorOverride: Qt.rgba(0, 0, 0, 0)
    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Base
        : Appearance.colors.colSurfaceContainer
    readonly property real resolvedSurfaceOpacity: root.surfaceOpacity >= 0
        ? root.surfaceOpacity : (Config.options?.overlay?.backgroundOpacity ?? 1)
    readonly property color resolvedSurfaceColor: root.useSurfaceColorOverride
        ? root.surfaceColorOverride : root.surfaceColor
    color: ColorUtils.applyAlpha(
        root.resolvedSurfaceColor,
        root.resolvedSurfaceOpacity)
}
