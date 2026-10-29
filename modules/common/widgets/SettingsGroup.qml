import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One run of tiles: its rows sit 2 px apart and only the run's outer corners round (SettingsMaterialPreset).
ColumnLayout {
    id: root

    readonly property string settingsTileRole: "group"

    Layout.fillWidth: true
    spacing: SettingsMaterialPreset.tileGap
}
