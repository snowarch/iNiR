pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// The picker's one text field. It keeps the keyboard the whole time the picker is open: typing searches, the keys it
// doesn't use (arrows, Enter, Tab...) go to `navigate`, which the picker answers for the layout on show.
Rectangle {
    id: root

    required property var engine
    property var navigate: null
    readonly property real d: IrisStyle.density
    readonly property alias input: field

    function focusField(): void { field.forceActiveFocus() }

    implicitHeight: Math.round(36 * root.d)
    implicitWidth: Math.round(280 * root.d)
    radius: IrisStyle.capsule(height)
    color: field.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

    Connections {
        target: root.engine
        function onQueryChanged(): void { if (field.text.trim() !== root.engine.query) field.text = root.engine.query }
    }

    MaterialSymbol {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: Math.round(12 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        text: root.engine.pathMode ? "drive_file_move" : "search"
        iconSize: Math.round(17 * root.d)
        color: field.text.length > 0 ? IrisStyle.accent : IrisStyle.subtext
    }
    // A pivot (a tag, a colour, an uploader, "like this one") stands in the field as a token; × goes back.
    Rectangle {
        id: pivot
        visible: root.engine.pivotLabel.length > 0 || root.engine.colour.length > 0
        anchors.left: glyph.right
        anchors.leftMargin: Math.round(6 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(24 * root.d)
        width: visible ? pivotRow.implicitWidth + Math.round(14 * root.d) : 0
        radius: IrisStyle.capsule(height)
        color: IrisStyle.accentContainer
        Row {
            id: pivotRow
            anchors.centerIn: parent
            spacing: Math.round(4 * root.d)
            Rectangle {
                visible: root.engine.colour.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(12 * root.d)
                height: width
                radius: width / 2
                color: "#" + (root.engine.colour || "000000")
                border.width: 1
                border.color: IrisStyle.hairlineStrong
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.engine.pivotLabel.length > 0
                text: root.engine.pivotLabel
                width: Math.min(implicitWidth, Math.round(180 * root.d))
                elide: Text.ElideRight
                color: IrisStyle.inkOnAccentContainer
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "close"
                iconSize: Math.round(13 * root.d)
                color: IrisStyle.inkOnAccentContainer
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.engine.pivotLabel.length > 0) root.engine.clearPivot()
                else root.engine.setColour(root.engine.colour)
            }
        }
    }
    TextInput {
        id: field
        anchors.left: pivot.visible ? pivot.right : glyph.right
        anchors.leftMargin: Math.round(8 * root.d)
        anchors.right: tail.left
        anchors.rightMargin: Math.round(8 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        color: IrisStyle.text
        selectionColor: IrisStyle.accentContainer
        selectedTextColor: IrisStyle.inkOnAccentContainer
        font.family: IrisStyle.fontMain
        font.pixelSize: IrisStyle.typeLabel
        clip: true
        focus: true
        onTextChanged: root.engine.setQuery(field.text.trim().length === 0 ? "" : field.text.trim())
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape && field.text.length > 0) { field.text = ""; event.accepted = true; return }
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.engine.pathMode) {
                root.engine.jumpTo(root.engine.query)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backspace && field.text.length === 0) {
                if (root.engine.pivotLabel.length > 0) root.engine.clearPivot()
                else if (root.engine.colour.length > 0) root.engine.setColour(root.engine.colour)
                else if (root.engine.source === "library") root.engine.goUp()
                event.accepted = true
                return
            }
            // Left and right edit the text once there is some.
            if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && field.text.length > 0 && !(event.modifiers & Qt.AltModifier)) return
            if (root.navigate && root.navigate(event)) event.accepted = true
        }
        IrisText {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            visible: field.text.length === 0
            text: root.engine.searchHint
            elide: Text.ElideRight
            color: IrisStyle.muted
            font.pixelSize: field.font.pixelSize
        }
    }
    Item {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: Math.round(12 * root.d)
        anchors.verticalCenter: parent.verticalCenter
        width: root.engine.searching ? spinner.width : count.visible ? count.implicitWidth : 0
        height: parent.height
        MaterialSymbol {
            id: spinner
            anchors.centerIn: parent
            visible: root.engine.searching
            text: "progress_activity"
            iconSize: Math.round(16 * root.d)
            color: IrisStyle.subtext
            RotationAnimator on rotation { running: spinner.visible; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
        }
        IrisText {
            id: count
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            visible: !root.engine.searching && !root.engine.pathMode && (root.engine.query.length > 0 || root.engine.online)
            text: root.engine.online && root.engine.onlineTotal > 0 ? root.engine.compact(root.engine.onlineTotal) : String(root.engine.count)
            color: IrisStyle.secondaryAccent
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: IrisStyle.typeLabel
            font.weight: IrisStyle.weight(Font.Bold)
        }
    }
}
