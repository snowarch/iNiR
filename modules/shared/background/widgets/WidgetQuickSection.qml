pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
// A titled group inside a widget's quick controls: one quiet caption, then its controls.
ColumnLayout {
    id: root

    property string title: ""
    property string detail: ""
    default property alias content: body.data

    readonly property var look: DesktopWidgetLook.look
    readonly property real d: root.look.density

    Layout.fillWidth: true
    spacing: Math.round(7 * root.d)

    RowLayout {
        visible: root.title.length > 0
        Layout.fillWidth: true
        spacing: Math.round(6 * root.d)

        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            color: FamilyStyle.textSecondary
            font.family: FamilyStyle.fontMain
            font.pixelSize: root.look.metaSize
            font.weight: FamilyStyle.weight(Font.DemiBold)
            font.capitalization: root.look.metaCapitalization
            font.letterSpacing: root.look.metaSpacing
        }
        StyledText {
            visible: root.detail.length > 0
            text: root.detail
            color: root.look.quietInk
            font.family: FamilyStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: root.look.metaSize
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Math.round(4 * root.d)
    }
}
