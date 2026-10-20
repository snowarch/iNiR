pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.control
import "../components"

// AIRISU's layout card in the Control Center's library: a key (AKey) holding the layout in miniature beside its name and
// what it does. Each place on the panel is sunk into the card as the die it will be cut with (a round switch a disc, the
// Connections plate with its four keys, the player in music's lacquer, a level its run, the notifications a long slot),
// so the card is the panel seen from far. The layout in use wears the chosen plate. The engine keeps the packing, the
// click and what a layout applies.
Item {
    id: root
    property Item host
    readonly property var card: root.host
    readonly property bool chosen: root.card?.current ?? false
    readonly property bool hovered: root.card?.hovered ?? false
    readonly property bool pressed: root.card?.down ?? false
    readonly property real d: Airisu.d
    readonly property int pad: Airisu.u(3)
    readonly property color face: root.chosen ? IrisStyle.selectionFill : Airisu.groundRaised
    readonly property color mark: root.chosen ? Airisu.inkSecondOn(root.face) : Airisu.inkThird
    readonly property int run: root.pressed ? Airisu.nudge : 0

    AKey {
        anchors.fill: parent
        lacquer: root.face
        hovered: root.hovered
        pressed: root.pressed
        keyed: root.card?.visualFocus ?? false

        // The imposition sheet: every place of the layout in its ruled box.
        Item {
            id: sheet
            x: root.pad + root.run
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.run
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

                    // A die: every switch, the plate, and the player in music's lacquer.
                    ALacquer {
                        visible: (place.switchPlace && !(place.round && place.single)) || place.kind === "platter" || place.kind === "media"
                        anchors.fill: parent
                        cut: Airisu.cutFor(Math.min(width, height))
                        lacquer: place.kind === "media" ? Airisu.lacquerOf(Airisu.pigment("music")) : Airisu.slot
                        moving: false
                    }
                    // A round switch: a disc.
                    Rectangle {
                        visible: place.switchPlace && place.round && place.single
                        anchors.centerIn: parent
                        width: Math.round(Math.min(parent.width, parent.height) * 0.8)
                        height: width
                        radius: width / 2
                        color: Airisu.slot
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
                                color: root.mark
                            }
                        }
                    }
                    // The player: its cover in the corner.
                    Rectangle {
                        visible: place.kind === "media"
                        x: Math.max(2, Math.round(2 * root.d))
                        y: x
                        width: Math.max(4, Math.round(Math.min(place.height * 0.5, 10 * root.d)))
                        height: width
                        color: Airisu.vivid(Airisu.pigment("music"))
                    }
                    // Levels: a run each, laid to 60 %.
                    Row {
                        id: rules
                        visible: place.kind === "levels" || place.kind === "level"
                        anchors.centerIn: parent
                        readonly property int count: place.kind === "level" ? 1 : Math.max(1, (root.card.modelData.levels ?? []).length)
                        readonly property bool upright: place.height >= place.width * 0.6
                        spacing: Math.max(2, Math.round(2 * root.d))
                        Repeater {
                            model: rules.count
                            Item {
                                width: rules.upright ? (place.width - rules.spacing * (rules.count - 1)) / rules.count : place.width
                                height: rules.upright ? place.height : (place.height - rules.spacing * (rules.count - 1)) / rules.count
                                ARun {
                                    width: rules.upright ? parent.height : parent.width
                                    height: rules.upright ? parent.width : parent.height
                                    anchors.centerIn: parent
                                    rotation: rules.upright ? -90 : 0
                                    value: 0.6
                                    moving: false
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
                color: Airisu.slot
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(2, Math.round(4 * root.d))
                    spacing: Math.max(2, Math.round(2 * root.d))
                    Repeater {
                        model: [0.55, 0.38]
                        Rectangle {
                            required property real modelData
                            width: Math.round(sheet.width * modelData)
                            height: Math.max(2, Math.round(2 * root.d))
                            color: root.mark
                        }
                    }
                }
            }
        }

        Column {
            id: words
            x: sheet.x + sheet.width + Airisu.u(3)
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.run
            width: parent.width - x - root.pad
            spacing: Math.round(2 * root.d)
            AText {
                width: parent.width
                size: IrisStyle.typeLabel
                font.weight: Font.Bold
                color: Airisu.inkOn(root.face)
                text: Translation.tr(root.card?.modelData?.label ?? "")
            }
            AText {
                width: parent.width
                size: IrisStyle.typeMeta
                font.weight: Font.Normal
                color: root.chosen ? Airisu.inkSecondOn(root.face) : Airisu.inkSecond
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                text: Translation.tr(root.card?.modelData?.description ?? "")
            }
        }

    }
}
