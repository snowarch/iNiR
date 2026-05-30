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

    default property alias contentData: contentColumn.data

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
            topMargin: 16
            bottomMargin: 16
            leftMargin: root._horizontalMargin
            rightMargin: root._horizontalMargin
        }
        spacing: SettingsMaterialPreset.pageSpacing
    }
}
