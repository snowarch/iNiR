import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real bottomContentPadding: 100
    // Metadatos opcionales para páginas de Settings
    property int settingsPageIndex: -1
    property string settingsPageName: ""

    default property alias data: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding
    implicitWidth: contentColumn.implicitWidth

    // Responsive horizontal margins: more breathing room on wider containers
    readonly property real _horizontalMargin: {
        const w = root.width
        if (w > 1200) return 48
        if (w > 900) return 32
        if (w > 600) return 24
        return 16
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 20
            bottomMargin: 20
            leftMargin: root._horizontalMargin
            rightMargin: root._horizontalMargin
        }
        spacing: SettingsMaterialPreset.pageSpacing
    }
}
