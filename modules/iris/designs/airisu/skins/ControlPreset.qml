pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.control
import "../components"

// AIRISU's layout card in the Control Center's library: the layout as the printer's imposition sheet for it. Each place
// on the panel is drawn as the ruled box it will be printed in (a round switch a circle, the Connections plate a box with
// its four keys, the player a box with its cover inked, a level its graduated rule, the notifications a box of lines),
// beside the layout's name and what it does. The layout in use carries the inspector's seal (検印) on its corner, as
// an approved proof does, and its box is ruled in the full ink; the pointer lights the sheet a step, a press runs it out
// of register. The engine keeps the packing, the click and what a layout applies.
Item {
    id: root
    property Item host
    readonly property var card: root.host
    readonly property bool chosen: root.card?.current ?? false
    readonly property bool hovered: root.card?.hovered ?? false
    readonly property bool pressed: root.card?.down ?? false
    readonly property real d: Airisu.d
    readonly property int pad: Airisu.u(3)
    readonly property color line: root.chosen ? Airisu.ink : Airisu.inkSecond

    APrint {
        anchors.fill: parent
        die: "rect"
        pressed: root.pressed
        fill: root.hovered ? Airisu.groundRaised : "transparent"
        under: Airisu.inkUnder
        stroke: root.chosen ? Airisu.ink : Airisu.rule
        strokeWidth: Airisu.hair

        // The imposition sheet: every place of the layout in its ruled box.
        Item {
            id: sheet
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.card?.miniWidth ?? 0
            height: root.card?.miniHeight ?? 0
            Repeater {
                model: root.card?.ids ?? []
                Item {
                    id: place
                    required property string modelData
                    readonly property var spot: root.card.packed.placed[place.modelData]
                    readonly property string kind: IrisControlOptions.kindOf(place.modelData)
                    readonly property bool round: root.card.modelData.controls === "round"
                    readonly property bool single: place.spot.w === 1 && place.spot.h === 1
                    readonly property bool switchPlace: place.kind !== "platter" && place.kind !== "media" && place.kind !== "levels" && place.kind !== "level"
                    x: place.spot.col * (root.card.miniCell + root.card.miniGap)
                    y: place.spot.row * (root.card.miniUnit + root.card.miniGap)
                    width: place.spot.w * root.card.miniCell + (place.spot.w - 1) * root.card.miniGap
                    height: place.spot.h * root.card.miniUnit + (place.spot.h - 1) * root.card.miniGap

                    // A box: every switch, the plate and the player.
                    Rectangle {
                        visible: (place.switchPlace && !(place.round && place.single)) || place.kind === "platter" || place.kind === "media"
                        anchors.fill: parent
                        color: "transparent"
                        border.width: Airisu.hair
                        border.color: root.line
                    }
                    // A round switch: a circle.
                    Rectangle {
                        visible: place.switchPlace && place.round && place.single
                        anchors.centerIn: parent
                        width: Math.round(Math.min(parent.width, parent.height) * 0.7)
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: Airisu.hair
                        border.color: root.line
                    }
                    // The Connections plate: its four keys.
                    Grid {
                        visible: place.kind === "platter"
                        anchors.centerIn: parent
                        columns: place.width > place.height * 1.8 ? 4 : 2
                        spacing: Math.max(2, Math.round(2 * root.d))
                        Repeater {
                            model: 4
                            Rectangle {
                                width: Math.max(3, Math.round(Math.min(place.width, place.height) * 0.22))
                                height: width
                                radius: place.round ? width / 2 : 0
                                color: root.line
                            }
                        }
                    }
                    // The player: its cover inked in the corner.
                    Rectangle {
                        visible: place.kind === "media"
                        x: Math.max(2, Math.round(2 * root.d))
                        y: x
                        width: Math.max(4, Math.round(Math.min(place.height * 0.5, 10 * root.d)))
                        height: width
                        color: root.line
                    }
                    // Levels: a graduated rule each, its mark where the level stands.
                    Row {
                        id: rules
                        visible: place.kind === "levels" || place.kind === "level"
                        anchors.centerIn: parent
                        readonly property int count: place.kind === "level" ? 1 : Math.max(1, (root.card.modelData.levels ?? []).length)
                        readonly property bool upright: place.height >= place.width * 0.6
                        spacing: Math.round(Math.min(place.width, place.height) / (rules.count + 1))
                        Repeater {
                            model: rules.count
                            Item {
                                width: rules.upright ? Math.max(3, Math.round(4 * root.d)) : (place.width - Math.round(4 * root.d) - rules.spacing * (rules.count - 1)) / rules.count
                                height: rules.upright ? place.height : Math.max(3, Math.round(4 * root.d))
                                Rectangle {
                                    color: root.line
                                    x: rules.upright ? Math.round((parent.width - width) / 2) : 0
                                    y: rules.upright ? 0 : Math.round((parent.height - height) / 2)
                                    width: rules.upright ? Airisu.hair : parent.width
                                    height: rules.upright ? parent.height : Airisu.hair
                                }
                                // The mark: a short bar across the rule at 60 %.
                                Rectangle {
                                    color: root.line
                                    x: rules.upright ? 0 : Math.round(parent.width * 0.6)
                                    y: rules.upright ? Math.round(parent.height * 0.4) : 0
                                    width: rules.upright ? parent.width : Airisu.strong
                                    height: rules.upright ? Airisu.strong : parent.height
                                }
                            }
                        }
                    }
                }
            }
            // The notifications under the grid: a box of lines.
            Rectangle {
                visible: root.card?.listed ?? false
                y: (root.card?.packed?.rows ?? 0) * ((root.card?.miniUnit ?? 0) + (root.card?.miniGap ?? 0))
                width: sheet.width
                height: root.card?.miniUnit ?? 0
                color: "transparent"
                border.width: Airisu.hair
                border.color: root.line
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(2, Math.round(4 * root.d))
                    spacing: Math.max(2, Math.round(2 * root.d))
                    Repeater {
                        model: [0.55, 0.38]
                        Rectangle {
                            required property real modelData
                            width: Math.round(sheet.width * modelData)
                            height: Airisu.hair
                            color: root.line
                        }
                    }
                }
            }
        }

        Column {
            id: words
            x: sheet.x + sheet.width + Airisu.u(3)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - root.pad - (seal.visible ? seal.width + Airisu.u(2) : 0)
            spacing: Math.round(2 * root.d)
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                text: Translation.tr(root.card?.modelData?.label ?? "")
            }
            AText {
                width: parent.width
                size: IrisStyle.typeMeta
                font.weight: Font.Normal
                color: Airisu.inkSecond
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                text: Translation.tr(root.card?.modelData?.description ?? "")
            }
        }

        // The inspector's seal: this is the layout the panel is printed from.
        Rectangle {
            id: seal
            visible: root.chosen
            x: parent.width - root.pad - width
            y: root.pad
            width: Airisu.u(5)
            height: width
            color: Airisu.seal
            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: Math.round(15 * root.d)
                fill: 1
                color: Airisu.inkOnSeal
            }
        }
    }
}
