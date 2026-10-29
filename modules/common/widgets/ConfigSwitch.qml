import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    property string buttonIcon
    property alias iconSize: iconWidget.iconSize
    property bool autoToggle: true
    // Optional wrapping subtext under the label ("what does this do?")
    property string description: ""
    // Integración con buscador global de Settings
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    signal toggledByUser(bool checked)
    focusRingInward: true

    // One setting, one tile (SettingsMaterialPreset.layoutTiles rounds its outer corners).
    readonly property string settingsTileRole: "tile"
    property bool tileTop: true
    property bool tileBottom: true

    Layout.fillWidth: true
    implicitHeight: Math.max(SettingsMaterialPreset.rowMinHeight, contentItem.implicitHeight + topPadding + bottomPadding)
    leftPadding: SettingsMaterialPreset.tilePaddingX
    rightPadding: SettingsMaterialPreset.tilePaddingX
    topPadding: SettingsMaterialPreset.tilePaddingY
    bottomPadding: SettingsMaterialPreset.tilePaddingY
    font.pixelSize: SettingsMaterialPreset.labelSize
    buttonRadiusTop: root.tileTop ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
    buttonRadiusBottom: root.tileBottom ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
    colBackground: SettingsMaterialPreset.tileColor
    colBackgroundHover: SettingsMaterialPreset.tileHoverColor
    colRipple: SettingsMaterialPreset.tilePressColor
    pressScaleEnabled: false

    function _findSettingsContext() {
        var page = null;
        var sectionTitle = "";
        var groupTitle = "";
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
            }
            if (p.hasOwnProperty("title")) {
                if (!sectionTitle && p.hasOwnProperty("icon")) {
                    sectionTitle = p.title;
                } else if (!groupTitle && !p.hasOwnProperty("icon")) {
                    groupTitle = p.title;
                }
            }
            p = p.parent;
        }
        return { page: page, sectionTitle: sectionTitle, groupTitle: groupTitle };
    }

    function focusFromSettingsSearch() {
        // Expand parent CollapsibleSection if collapsed
        var p = root.parent;
        while (p) {
            if (p.hasOwnProperty("expanded") && p.hasOwnProperty("collapsible")) {
                p.expanded = true;
                break;
            }
            p = p.parent;
        }
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        if (!enableSettingsSearch)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;
        if (!SettingsSearchRegistry.dynamicRegistrationEnabled)
            return;

        var ctx = _findSettingsContext();
        var page = ctx.page;
        var sectionTitle = ctx.sectionTitle;
        var label = root.text || ctx.groupTitle || sectionTitle;

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: sectionTitle,
            label: label,
            description: "",
            keywords: []
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    onClicked: {
        const nextChecked = !checked;
        toggledByUser(nextChecked);
        if (autoToggle)
            checked = nextChecked;
    }

    contentItem: RowLayout {
        spacing: SettingsMaterialPreset.tilePaddingX
        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            opacity: root.enabled ? 1 : 0.38
            iconSize: SettingsMaterialPreset.iconSize
            color: SettingsMaterialPreset.supportingColor
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                text: root.text
                wrapMode: Text.Wrap
                font: root.font
                color: SettingsMaterialPreset.labelColor
                opacity: root.enabled ? 1 : 0.38
            }

            StyledText {
                visible: root.description.length > 0
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: SettingsMaterialPreset.supportingSize
                color: SettingsMaterialPreset.supportingColor
                opacity: root.enabled ? 1 : 0.38
                wrapMode: Text.Wrap
            }
        }
        StyledSwitch {
            id: switchWidget
            // The row is the one Tab stop and Space toggles it; the switch inside was a second stop for the same thing.
            focusPolicy: Qt.NoFocus
            down: root.down
            scale: 1
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            checked: root.checked
            onClicked: root.clicked()
        }
    }
}
