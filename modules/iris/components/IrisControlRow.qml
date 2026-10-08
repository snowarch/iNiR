pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets
import qs.modules.iris.style

// One row of a Control Center expansion: glyph, name, a quiet detail and a switch. Tapping anywhere toggles.
Item {
    id: row

    property string glyph: ""
    property string label: ""
    property string detail: ""
    property bool on: false
    property bool available: true
    property color tint: IrisStyle.accent
    signal toggled()
    readonly property real d: IrisStyle.density

    Layout.fillWidth: true
    implicitHeight: Math.round(44 * row.d)
    opacity: row.available ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.radiusTile
        color: tap.pressed ? IrisStyle.fillActive : hover.hovered && row.available ? IrisStyle.fillQuiet : "transparent"
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.round(10 * row.d)
        anchors.rightMargin: Math.round(10 * row.d)
        spacing: Math.round(10 * row.d)
        Rectangle {
            implicitWidth: Math.round(28 * row.d)
            implicitHeight: implicitWidth
            radius: height / 2
            color: row.on ? row.tint : IrisStyle.fill
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: row.glyph
                fill: row.on ? 1 : 0
                iconSize: Math.round(16 * row.d)
                color: row.on ? IrisStyle.onTintFor(row.tint) : IrisStyle.text
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            IrisText {
                Layout.fillWidth: true
                text: row.label
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                visible: text.length > 0
                text: row.detail
                role: IrisText.Meta
                elide: Text.ElideRight
            }
        }
        // The whole row is the target; the switch only shows the state.
        IrisSwitch {
            on: row.on
            name: row.label
            enabled: false
        }
    }
    HoverHandler { id: hover; cursorShape: row.available ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { id: tap; enabled: row.available; onTapped: row.toggled() }
    Accessible.role: Accessible.CheckBox
    Accessible.name: row.label
    Accessible.checked: row.on
}
