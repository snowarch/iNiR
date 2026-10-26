pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// The quick-controls sheet of a widget drawn by the ii family (or a Material-design widget under
// iRiS): the widget's name and a close button, then its pages. Its width comes from its content,
// bounded by the screen.
ColumnLayout {
    id: root

    required property real availableWidth
    required property real availableHeight
    property string title: Translation.tr("Quick controls")
    property string glyph: "widgets"
    property color tint: FamilyStyle.accent
    property real regularWidth: 360
    signal closeRequested()

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? FamilyStyle.density : 1
    readonly property bool dense: availableHeight < 760
    readonly property bool wideDense: dense && availableWidth >= 480
    readonly property int optionColumns: wideDense ? 4 : 3
    readonly property int metricColumns: wideDense ? 4 : 2
    readonly property real contentNaturalWidth: contentColumn.implicitWidth
    readonly property real resolvedWidth: {
        const safeWidth = Math.max(0, root.availableWidth)
        const natural = Math.max(Math.round(300 * root.d), root.regularWidth, root.contentNaturalWidth)
        return Math.min(safeWidth, Math.min(Math.round(440 * root.d), natural))
    }

    default property alias contentData: contentColumn.data

    implicitWidth: resolvedWidth
    width: resolvedWidth
    spacing: Math.round(12 * root.d)

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(8 * root.d)

        WidgetIdentityMark {
            glyph: root.glyph
            tint: root.tint
        }
        StyledText {
            Layout.fillWidth: true
            text: root.title
            elide: Text.ElideRight
            color: root.iris ? FamilyStyle.text : Appearance.colors.colOnLayer2
            font.family: root.iris ? FamilyStyle.fontTitle : Appearance.font.family.title
            font.pixelSize: root.iris ? FamilyStyle.typeTitle : Appearance.font.pixelSize.normal
            font.weight: root.iris ? FamilyStyle.weight(Font.DemiBold) : Font.DemiBold
        }
        WidgetEditAction {
            iconName: "close"
            label: Translation.tr("Close")
            compact: true
            implicitHeight: Math.round(28 * root.d)
            iconSize: Math.round(16 * root.d)
            onClicked: root.closeRequested()
        }
    }

    ColumnLayout {
        id: contentColumn
        Layout.fillWidth: true
        spacing: Math.round(14 * root.d)
    }
}
