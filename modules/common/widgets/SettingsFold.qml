import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// A row that opens what it holds in place: its glyph, what it holds, a chevron that turns.
// With `hasSwitch` it is Android's split row: the body opens, the switch past the divider turns the thing on,
// so a list of events with a pose each reads as one row per event.
RippleButton {
    id: root
    property string glyph: ""
    property string summary: ""
    property bool open: false
    property bool hasSwitch: false
    property bool switchOn: false
    signal switchToggled(bool on)

    readonly property string settingsTileRole: "tile"
    property bool tileTop: true
    property bool tileBottom: true
    property int settingsSearchOptionId: -1

    Layout.fillWidth: true
    implicitHeight: Math.max(SettingsMaterialPreset.rowMinHeight, contentItem.implicitHeight + topPadding + bottomPadding)
    leftPadding: SettingsMaterialPreset.tilePaddingX
    rightPadding: SettingsMaterialPreset.tilePaddingX
    topPadding: SettingsMaterialPreset.tilePaddingY
    bottomPadding: SettingsMaterialPreset.tilePaddingY
    buttonRadiusTop: root.tileTop ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
    buttonRadiusBottom: root.tileBottom ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
    colBackground: SettingsMaterialPreset.tileColor
    colBackgroundHover: SettingsMaterialPreset.tileHoverColor
    colRipple: SettingsMaterialPreset.tilePressColor
    pressScaleEnabled: false
    focusRingInward: true
    Accessible.name: root.text
    Accessible.description: root.summary

    function focusFromSettingsSearch() {
        root.forceActiveFocus()
    }

    Component.onCompleted: {
        if (!root.hasSwitch || typeof SettingsSearchRegistry === "undefined" || !SettingsSearchRegistry.dynamicRegistrationEnabled)
            return
        let page = null
        for (let p = root.parent; p && !page; p = p.parent)
            if (p.hasOwnProperty("settingsPageIndex"))
                page = p
        root.settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page?.settingsPageIndex ?? -1,
            pageName: page?.settingsPageName ?? "",
            section: "",
            label: root.text,
            description: root.summary,
            keywords: []
        })
    }
    Component.onDestruction: {
        if (root.settingsSearchOptionId >= 0 && typeof SettingsSearchRegistry !== "undefined")
            SettingsSearchRegistry.unregisterControl(root)
    }

    contentItem: RowLayout {
        spacing: SettingsMaterialPreset.tilePaddingX
        MaterialSymbol {
            visible: root.glyph.length > 0
            text: root.glyph
            iconSize: SettingsMaterialPreset.iconSize
            color: root.open ? SettingsMaterialPreset.subheaderColor : SettingsMaterialPreset.supportingColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: root.text
                font.pixelSize: SettingsMaterialPreset.labelSize
                color: SettingsMaterialPreset.labelColor
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.summary.length > 0
                text: root.summary
                font.pixelSize: SettingsMaterialPreset.supportingSize
                color: SettingsMaterialPreset.supportingColor
                elide: Text.ElideRight
            }
        }
        MaterialSymbol {
            text: "expand_more"
            iconSize: SettingsMaterialPreset.iconSize
            color: SettingsMaterialPreset.supportingColor
            rotation: root.open ? 180 : 0
            Behavior on rotation { animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            visible: root.hasSwitch
            implicitWidth: 1
            implicitHeight: 28
            color: Appearance.colors.colOutlineVariant
        }
        StyledSwitch {
            visible: root.hasSwitch
            Layout.alignment: Qt.AlignVCenter
            scale: 1
            checked: root.switchOn
            Accessible.name: root.text
            onClicked: root.switchToggled(checked)
        }
    }
}
