import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// A titled cluster. Holding tiles (switches, steppers), its title is a sub-label over them; holding anything else
// (a button group, a field), it is one tile with its title inside (SettingsMaterialPreset.layoutTiles decides).
// Its help is written under the title, never hidden behind a hover.
Item {
    id: root
    property string title: ""
    property string tooltip: ""
    property string settingsTaskSection: ""
    default property alias contentData: sectionContent.data

    readonly property string settingsTileRole: "subsection"
    property bool tileActive: false
    property bool tileTop: true
    property bool tileBottom: true

    readonly property int _padX: root.tileActive ? SettingsMaterialPreset.tilePaddingX : 0
    readonly property int _padY: root.tileActive ? SettingsMaterialPreset.tilePaddingY : 0

    Layout.fillWidth: true
    // side by side in a row, a short column sat centred beside a tall one: titles line up at the top
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: root.tileActive ? 0 : 8
    implicitWidth: column.implicitWidth + root._padX * 2
    implicitHeight: column.implicitHeight + root._padY * 2

    Rectangle {
        anchors.fill: parent
        visible: root.tileActive
        color: SettingsMaterialPreset.tileColor
        topLeftRadius: root.tileTop ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.tileBottom ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
        bottomRightRadius: bottomLeftRadius
    }

    ColumnLayout {
        id: column
        anchors {
            fill: parent
            leftMargin: root._padX
            rightMargin: root._padX
            topMargin: root._padY
            bottomMargin: root._padY
        }
        spacing: root.tileActive ? 12 : SettingsMaterialPreset.tileGap

        ColumnLayout {
            readonly property string settingsTileRole: "caption"
            visible: root.title.length > 0
            Layout.fillWidth: true
            // as a sub-label it lines up with the text inside the tiles below it
            Layout.leftMargin: root.tileActive ? 0 : SettingsMaterialPreset.tilePaddingX
            Layout.rightMargin: root.tileActive ? 0 : SettingsMaterialPreset.tilePaddingX
            Layout.bottomMargin: root.tileActive ? 0 : 6
            spacing: 2

            ContentSubsectionLabel {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                text: root.title
                wrapMode: Text.Wrap
                font.pixelSize: root.tileActive ? SettingsMaterialPreset.labelSize : SettingsMaterialPreset.supportingSize
                font.weight: root.tileActive ? Font.Normal : Font.Medium
                color: root.tileActive ? SettingsMaterialPreset.labelColor : SettingsMaterialPreset.supportingColor
            }
            StyledText {
                visible: root.tooltip.length > 0
                Layout.fillWidth: true
                text: root.tooltip
                wrapMode: Text.Wrap
                font.pixelSize: SettingsMaterialPreset.supportingSize
                color: SettingsMaterialPreset.supportingColor
            }
        }
        ColumnLayout {
            id: sectionContent
            Layout.fillWidth: true
            spacing: SettingsMaterialPreset.tileGap
        }
    }
}
