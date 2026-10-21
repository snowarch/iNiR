pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Display › Screen: every screen Niri drives, as it is. A miniature at its own shape (and, beside other
// screens, at its own size) showing the wallpaper, the name on the box, then diagonal, pixels, rate and scale. With two
// or more the cards pick the screen the rows below change; a single one only says what it is, so nothing in it looks
// clickable without doing anything.
Flow {
    id: root

    property var spec: ({})
    readonly property real d: IrisStyle.settingsDensity
    readonly property var screens: IrisNiri.outputs
    readonly property bool picks: root.screens.length > 1
    readonly property real largest: root.screens.reduce((most, out) => Math.max(most, IrisNiri.inchesOf(out)), 0)
    // Two screens of one model read apart by the port they hang from; otherwise the port is Niri's word, not theirs.
    readonly property var twins: root.screens.map(out => IrisNiri.screenName(out)).filter((name, at, all) => all.indexOf(name) !== at)
    readonly property real tileWidth: root.picks && root.width >= Math.round(520 * root.d) ? Math.floor((root.width - root.spacing) / 2) : root.width

    spacing: Math.round(8 * root.d)

    Repeater {
        model: ScriptModel { values: root.screens }
        Item {
            id: tile
            required property var modelData
            required property int index
            readonly property bool chosen: root.picks && IrisNiri.output?.name === tile.modelData?.name
            readonly property real inches: IrisNiri.inchesOf(tile.modelData)
            // Beside a bigger screen a smaller one draws smaller, never so small its picture stops reading.
            readonly property real size: root.picks && tile.inches > 0 && root.largest > 0 ? Math.max(0.62, tile.inches / root.largest) : 1
            readonly property string details: [
                tile.inches > 0 ? `${Math.round(tile.inches)}″` : "",
                IrisNiri.resolutionLabel(tile.modelData),
                IrisNiri.rateLabel(tile.modelData?.current_rate ?? 0),
                `${Math.round(Number(tile.modelData?.scale ?? 1) * 100)} %`
            ].filter(part => part.length > 0).map(part => part.replace(/ /g, "\u00a0")).join(" · ") // a figure wraps whole

            width: root.tileWidth
            // A data card never cuts its figures: the lines wrap and the card grows instead.
            height: Math.max(Math.round(84 * root.d), facts.implicitHeight + Math.round(24 * root.d))

            function choose(): void { if (root.picks) IrisNiri.applyDisplay("screen", tile.modelData.name) }

            activeFocusOnTab: root.picks
            Accessible.role: root.picks ? Accessible.RadioButton : Accessible.StaticText
            Accessible.name: IrisNiri.screenName(tile.modelData) + ", " + tile.details
            Accessible.checkable: root.picks
            Accessible.checked: tile.chosen
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    tile.choose()
                    event.accepted = true
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: root.picks
                radius: IrisStyle.radiusTile
                color: IrisStyle.fill
                opacity: tile.chosen ? 1 : press.containsMouse || tile.activeFocus ? 0.55 : 0
                border.width: tile.chosen ? 2 : 0
                border.color: IrisStyle.accent
                Behavior on opacity { NumberAnimation { duration: 120; easing.type: IrisStyle.feedbackEasing } }
            }

            // The slot is the same for every card, so names line up; the screen inside takes its shape and size.
            Item {
                id: slot
                anchors.left: parent.left
                anchors.leftMargin: Math.round((root.picks ? 12 : 0) * root.d)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(96 * root.d)
                height: Math.round(60 * root.d)

                Rectangle {
                    id: bezel
                    readonly property real aspect: IrisNiri.aspectOf(tile.modelData)
                    readonly property real fitW: Math.min(slot.width, slot.height * bezel.aspect)
                    anchors.centerIn: parent
                    width: Math.round(bezel.fitW * tile.size)
                    height: Math.round(bezel.fitW / bezel.aspect * tile.size)
                    radius: Math.round(5 * root.d) // iris-literal: a drawn monitor's bezel, not a shell surface
                    color: "#0b0b0c" // iris-literal: the bezel is the hardware's black, whatever the theme
                    border.width: 1
                    border.color: IrisStyle.hairline

                    // A panel is square inside its rounded bezel, so the picture needs no mask.
                    Image {
                        anchors.fill: parent
                        anchors.margins: Math.max(2, Math.round(2.5 * root.d))
                        // Its own wallpaper when each screen keeps one.
                        source: {
                            const own = WallpaperListener.multiMonitorEnabled ? WallpaperListener.effectivePerMonitor?.[tile.modelData?.name]?.path : ""
                            return own ? Wallpapers.stillUrlFor(own) : Wallpapers.effectiveWallpaperUrl
                        }
                        sourceSize.width: Math.round(192 * root.d)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                    }
                }
            }

            Column {
                id: facts
                anchors.left: slot.right
                anchors.leftMargin: Math.round(14 * root.d)
                anchors.right: parent.right
                anchors.rightMargin: Math.round(12 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * root.d)
                IrisText {
                    width: parent.width
                    text: IrisNiri.screenName(tile.modelData)
                    font.pixelSize: IrisStyle.typeBody
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    wrapMode: Text.WordWrap
                }
                IrisText {
                    width: parent.width
                    text: tile.details
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                    font.features: ({ "tnum": 1 })
                    wrapMode: Text.WordWrap
                }
                IrisText {
                    visible: root.twins.includes(IrisNiri.screenName(tile.modelData))
                    width: parent.width
                    text: String(tile.modelData?.name ?? "")
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: press
                anchors.fill: parent
                enabled: root.picks
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { tile.forceActiveFocus(); tile.choose() }
            }
        }
    }
}
