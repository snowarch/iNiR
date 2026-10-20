pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Orbit as it opens: the workspace you are on with its windows, its neighbours peeking above and below as far as you
// let them, its name, and the shelf of recent windows when it is on.
PreviewScene {
    id: orbitRoot
    readonly property bool on: orbitRoot.opt("iris.orbit.enable", true) === true
    readonly property bool fromIsland: String(orbitRoot.opt("iris.orbit.opens", "island")) === "island"
    readonly property real peek: Math.max(0, Number(orbitRoot.opt("iris.orbit.peek", 56)))
    readonly property bool wallpapered: orbitRoot.opt("iris.orbit.wallpaper", true) === true
    readonly property bool names: String(orbitRoot.opt("iris.orbit.labels", "full")) === "full"
    readonly property bool recent: orbitRoot.opt("iris.orbit.showRecent", true) === true
    readonly property int recentCount: Math.max(2, Math.min(8, Number(orbitRoot.opt("iris.orbit.recentCount", 5))))
    readonly property real naturalWidth: Math.round(640 * orbitRoot.d)
    readonly property real naturalHeight: Math.round(360 * orbitRoot.d)
    narrowest: Math.round(400 * orbitRoot.d)
    lowest: Math.round(240 * orbitRoot.d)

    IslandPill {
        id: orbitIsland
        visible: orbitRoot.fromIsland
        anchors.horizontalCenter: parent.horizontalCenter
        y: IrisFrame.band
    }
    Plate {
        id: orbitPlate
        surface: "orbit"
        opacity: orbitRoot.on ? 1 : 0.35
        anchors.horizontalCenter: parent.horizontalCenter
        y: orbitRoot.fromIsland ? orbitIsland.y + orbitIsland.height + IrisStyle.weld : Math.round(28 * orbitRoot.d)
        width: Math.round(orbitRoot.width * 0.7)
        height: orbitColumn.implicitHeight + Math.round(28 * orbitRoot.d)
        ColumnLayout {
            id: orbitColumn
            x: Math.round(14 * orbitRoot.d)
            y: Math.round(14 * orbitRoot.d)
            width: parent.width - 2 * x
            spacing: Math.round(8 * orbitRoot.d)
            Repeater {
                // The neighbours show as much as Neighbours lets them; Hidden leaves the workspace you are on alone.
                model: orbitRoot.peek > 0 ? [-1, 0, 1] : [0]
                ClippingRectangle {
                    id: card
                    required property int modelData
                    readonly property bool current: card.modelData === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: card.current ? Math.round(150 * orbitRoot.d) : Math.round(Math.min(70, orbitRoot.peek) * 0.5 * orbitRoot.d)
                    radius: IrisStyle.radiusTile
                    color: IrisStyle.fillQuiet
                    opacity: card.current ? 1 : 0.6
                    border.width: card.current ? 2 : 0
                    border.color: IrisStyle.accent
                    IrisImage {
                        visible: orbitRoot.wallpapered
                        anchors.fill: parent
                        source: orbitRoot.wallpaper
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(8 * orbitRoot.d)
                        Repeater {
                            model: card.current ? [0.3, 0.42, 0.22] : [0.36, 0.3]
                            Rectangle {
                                required property real modelData
                                width: Math.round(card.width * modelData)
                                height: Math.round(card.height * 0.66)
                                radius: IrisStyle.radiusChip
                                color: IrisStyle.surfaceOpaque
                                border.width: 1
                                border.color: IrisStyle.border
                            }
                        }
                    }
                    Rectangle {
                        visible: card.current
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: Math.round(8 * orbitRoot.d)
                        width: workspaceName.implicitWidth + Math.round(16 * orbitRoot.d)
                        height: Math.round(22 * orbitRoot.d)
                        radius: IrisStyle.capsule(height)
                        color: IrisStyle.veilHeavy
                        IrisText {
                            id: workspaceName
                            anchors.centerIn: parent
                            text: orbitRoot.names ? "2 · " + Translation.tr("Workspace") : "2"
                            color: IrisStyle.onMedia
                            font.pixelSize: IrisStyle.typeMeta
                            font.weight: IrisStyle.weight(Font.DemiBold)
                        }
                    }
                }
            }
            Row {
                visible: orbitRoot.recent
                spacing: Math.round(6 * orbitRoot.d)
                Repeater {
                    model: orbitRoot.recentCount
                    Rectangle {
                        width: Math.round(46 * orbitRoot.d)
                        height: Math.round(30 * orbitRoot.d)
                        radius: IrisStyle.radiusChip
                        color: IrisStyle.fill
                    }
                }
            }
        }
    }

    OffState { visible: !orbitRoot.on; text: Translation.tr("Orbit off") }

    Caption {
        glyph: "workspaces"
        text: orbitRoot.on ? [orbitRoot.fromIsland ? Translation.tr("The Island") : Translation.tr("Floating"),
            orbitRoot.recent ? Translation.tr("Recent windows") + " " + orbitRoot.recentCount : ""].filter(part => part.length > 0).join(" · ")
            : Translation.tr("Off")
    }
}
