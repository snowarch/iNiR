import qs.modules.common
import qs.modules.bar as StockBar
import QtQuick

// The original component is Hyprland-only: it reads `Hyprland.workspaces`,
// `wsModel.specialWorkspaceActive` and dispatches through `hl.dsp.focus`, none
// of which exist under Niri. iNiR's Workspaces already renders the same widget
// for both compositors, so the M3 bar borrows it and only feeds it the M3
// layout's own workspace options. The M3 pill around it still comes from
// this folder's BarGroup, so the M3 grouping remains intact.
Item {
    id: root
    property bool vertical: Config.options.bar.vertical

    implicitWidth: stock.implicitWidth
    implicitHeight: stock.implicitHeight

    StockBar.Workspaces {
        id: stock
        anchors.fill: parent
        vertical: root.vertical
        syncGlobalWorkspaceConfig: false
        showAppIcons: Config.options.bar.m3.workspaces.showAppIcons
        alwaysShowNumbers: Config.options.bar.m3.workspaces.alwaysShowNumbers
        useNerdFont: Config.options.bar.m3.workspaces.useNerdFont
        monochromeIcons: Config.options.bar.m3.workspaces.monochromeIcons
        indicatorStyle: Config.options.bar.m3.workspaces.indicatorStyle
        numberMap: Config.options.bar.m3.workspaces.numberMap
        forceMaterialStyle: Config.options.bar.m3.cornerStyle === 3
            && Appearance.globalStyle === "material"
    }
}
