import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

Rectangle {
    id: root

    default property alias data: content.data

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + SettingsMaterialPreset.groupPadding * 2

    radius: SettingsMaterialPreset.groupRadius
    color: SettingsMaterialPreset.groupColor
    border.width: 1
    border.color: SettingsMaterialPreset.groupBorderColor

    ColumnLayout {
        id: content
        anchors {
            fill: parent
            margins: SettingsMaterialPreset.groupPadding
        }
        spacing: SettingsMaterialPreset.groupSpacing
    }
}
