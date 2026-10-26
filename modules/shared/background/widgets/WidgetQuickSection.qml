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

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? FamilyStyle.density : 1

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
            color: root.iris ? FamilyStyle.textSecondary : Appearance.colors.colSubtext
            font.family: root.iris ? FamilyStyle.fontMain : Appearance.font.family.main
            font.pixelSize: root.iris ? FamilyStyle.typeMeta : Appearance.font.pixelSize.smallest
            font.weight: root.iris ? FamilyStyle.weight(Font.DemiBold) : Font.DemiBold
            font.capitalization: root.iris || Appearance.editorialEverywhere ? Font.MixedCase : Font.AllUppercase
            font.letterSpacing: root.iris ? 0 : 1
        }
        StyledText {
            visible: root.detail.length > 0
            text: root.detail
            color: root.iris ? FamilyStyle.textTertiary : Appearance.colors.colSubtext
            font.family: root.iris ? FamilyStyle.fontNumbers : Appearance.font.family.numbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: root.iris ? FamilyStyle.typeMeta : Appearance.font.pixelSize.smallest
        }
    }

    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: Math.round(4 * root.d)
    }
}
