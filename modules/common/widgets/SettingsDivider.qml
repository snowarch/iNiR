import QtQuick
import QtQuick.Layouts
import qs.modules.common.widgets

// Between tiles a line says nothing the gaps don't: a divider only ends one run of tiles and starts the next
// (SettingsMaterialPreset.layoutTiles), with a breath of space.
Item {
    readonly property string settingsTileRole: "caption"
    Layout.fillWidth: true
    implicitHeight: 4
}
