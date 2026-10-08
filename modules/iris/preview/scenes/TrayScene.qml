pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: trayRoot
    readonly property int columns: Math.max(2, Math.min(6, Number(trayRoot.opt("iris.tray.columns", 4))))
    readonly property bool labels: trayRoot.opt("iris.tray.labels", true)
    readonly property bool hidePassive: trayRoot.opt("iris.tray.hidePassive", false)
    readonly property var items: (SystemTray.items.values ?? []).filter(item => !trayRoot.hidePassive || item.status !== Status.Passive)
    readonly property real naturalWidth: trayPlate.width + Math.round(80 * trayRoot.d)
    readonly property real naturalHeight: trayPlate.height + Math.round(80 * trayRoot.d)
    Plate {
        id: trayPlate
        surface: "cards"
        anchors.centerIn: parent
        width: trayGrid.implicitWidth + Math.round(32 * trayRoot.d)
        height: trayGrid.implicitHeight + Math.round(64 * trayRoot.d)
        IrisText {
            x: Math.round(16 * trayRoot.d); y: Math.round(14 * trayRoot.d)
            text: Translation.tr("Tray") + "  " + trayRoot.items.length
            font.weight: IrisStyle.weight(Font.DemiBold)
        }
        Grid {
            id: trayGrid
            x: Math.round(16 * trayRoot.d); y: Math.round(46 * trayRoot.d)
            columns: trayRoot.columns
            spacing: Math.round(6 * trayRoot.d)
            Repeater {
                model: trayRoot.items.length > 0 ? trayRoot.items : [null, null, null]
                Column {
                    id: trayEntry
                    required property var modelData
                    width: Math.round(72 * trayRoot.d)
                    spacing: Math.round(5 * trayRoot.d)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.round(48 * trayRoot.d); height: width
                        radius: IrisStyle.iconRadius(width)
                        color: IrisStyle.fillQuiet
                        IconImage { anchors.centerIn: parent; implicitSize: Math.round(26 * trayRoot.d); source: trayEntry.modelData ? TrayService.getSafeIcon(trayEntry.modelData) : "" }
                    }
                    IrisText {
                        visible: trayRoot.labels
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: trayEntry.modelData?.tooltipTitle || trayEntry.modelData?.title || trayEntry.modelData?.id || Translation.tr("App")
                        elide: Text.ElideRight
                        font.pixelSize: IrisStyle.typeFootnote
                        color: IrisStyle.subtext
                    }
                }
            }
        }
    }
    Caption {
        glyph: "inventory_2"
        text: Translation.tr("%1 columns").arg(trayRoot.columns) + (trayRoot.hidePassive ? " · " + Translation.tr("passive apps hidden") : "")
    }
}
