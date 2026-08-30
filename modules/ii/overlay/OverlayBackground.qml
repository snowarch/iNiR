import QtQuick
import qs.modules.common
import qs.modules.common.functions

Rectangle {
    id: root
    anchors.fill: parent
    readonly property color surfaceColor: Appearance.angelEverywhere ? Appearance.angel.colGlassPanel
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Base
        : Appearance.colors.colSurfaceContainer
    color: ColorUtils.applyAlpha(
        root.surfaceColor,
        Config.options?.overlay?.backgroundOpacity ?? 1)
}
