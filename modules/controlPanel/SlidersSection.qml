pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight

PanelSurface {
    id: root
    islandSkin: (Config.options?.controlPanel?.style ?? "panel") === "island"
    Layout.fillWidth: true
    implicitHeight: slidersRow.implicitHeight + 12
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    property var screen: root.QsWindow.window?.screen ?? null
    property var brightnessMonitor: screen ? Brightness.getMonitorForScreen(screen) : null

    elevation: 1
    radiusOverride: inirEverywhere ? Appearance.inir.roundingNormal
        : Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
        : Appearance.rounding.normal

    AngelPartialBorder { targetRadius: root.radiusOverride; coverage: 0.45; visible: Appearance.angelEverywhere }

    QuickSliders {
        id: slidersRow
        anchors.fill: parent
        compactSurface: true
    }
}
