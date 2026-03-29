import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    default property alias contentData: content.data

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + SettingsMaterialPreset.groupPadding * 2

    radius: SettingsMaterialPreset.groupRadius
    color: SettingsMaterialPreset.groupColor
    border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
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
