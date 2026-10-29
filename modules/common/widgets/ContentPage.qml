import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real bottomContentPadding: 48
    // Metadatos opcionales para páginas de Settings
    property int settingsPageIndex: -1
    property string settingsPageName: ""
    property var settingsTaskNavigator: null

    default property alias contentData: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + 8 + root.bottomContentPadding
    implicitWidth: contentColumn.implicitWidth

    // One column, left-aligned under the page title, capped so a row's label and its control stay one glance apart.
    readonly property real maxContentWidth: SettingsMaterialPreset.pageMaxWidth
    readonly property real _horizontalMargin: root.width > 600 ? 24 : 16

    ColumnLayout {
        id: contentColumn
        x: root._horizontalMargin
        y: 8
        width: Math.min(root.maxContentWidth, root.width - root._horizontalMargin * 2)
        spacing: SettingsMaterialPreset.pageSpacing
    }
}
