pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.widgets
import "../components"

// AIRISU's profile: a member's card (会員証). The person in a disc, the die AIRISU keeps for persons, with the logo's
// seal square at its foot; the greeting as a ruby in the data face's capitals over the name in the figure voice; the
// machine and how long it has been on as rows in the data face; and three keys for what a person does with the session
// (lock, settings, leave), the last one ruled in yamabuki since it ends things. The engine's face keeps the data.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }
    Item {
        id: person
        visible: root.widget?.showAvatar ?? true
        x: root.pad
        y: root.pad
        width: root.small ? root.dp(46) : root.dp(72)
        height: width
        FaceAvatar {
            anchors.fill: parent
            radius: width / 2
        }
        Rectangle {
            width: Math.round(parent.width * 0.2)
            height: width
            x: parent.width - Math.round(width * 0.8)
            y: parent.height - Math.round(width * 0.8)
            color: Airisu.seal
            antialiasing: false
        }
    }
    Column {
        x: person.visible ? person.x + person.width + root.dp(12) : root.pad
        y: root.pad
        width: root.width - x - root.pad
        spacing: root.dp(2)
        AText {
            width: parent.width
            voice: "mono"
            size: IrisStyle.typeCaption
            color: stock.inkSecond
            text: root.face?.greeting ?? ""
        }
        AText {
            width: parent.width
            voice: "figure"
            size: root.small ? IrisStyle.typeHeadline : IrisStyle.typeTitle
            color: stock.ink
            text: root.face?.name ?? ""
        }
        AText {
            width: parent.width
            visible: !root.small && text.length > 0
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: root.face?.host ?? ""
        }
        AText {
            width: parent.width
            visible: !root.small
            voice: "data"
            size: IrisStyle.typeCaption
            color: stock.inkThird
            text: root.face?.uptime ?? ""
        }
    }
    Row {
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        spacing: root.dp(6)
        Repeater {
            model: [
                { glyph: "lock", name: Translation.tr("Lock"), run: () => root.widget?.lockScreen() },
                { glyph: "settings", name: Translation.tr("Settings"), run: () => GlobalStates.openSettings() },
                { glyph: "power_settings_new", name: Translation.tr("Session"), run: () => { GlobalStates.sessionOpen = true }, ends: true }
            ]
            Item {
                id: key
                required property var modelData
                width: root.dp(30)
                height: width
                AKey {
                    id: plate
                    anchors.fill: parent
                    lacquer: "transparent"
                    under: stock.lacquer
                    hovered: hover.hovered
                    pressed: tap.pressed
                }
                ADie {
                    x: plate.shift
                    y: plate.shift
                    width: parent.width
                    height: parent.height
                    kind: "chamfer"
                    cut: Airisu.cutFor(height)
                    stroke: key.modelData.ends ? Airisu.tape : stock.inkThird
                    strokeWidth: Airisu.hair
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: plate.shift
                    anchors.verticalCenterOffset: plate.shift
                    text: key.modelData.glyph
                    iconSize: root.px(16)
                    color: stock.ink
                }
                Accessible.role: Accessible.Button
                Accessible.name: key.modelData.name
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: tap; onTapped: key.modelData.run() }
            }
        }
    }
}
