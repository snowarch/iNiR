import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts

// A number setting as one tile: label and its line of help on the left, the stepper on the right.
Item {
    id: root
    property string text: ""
    property string icon
    // Optional wrapping subtext under the label
    property string description: ""
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    // only a person's step or typing, never a bound value catching up
    signal valueModified()
    // Expose hover state for tooltips and other helpers
    readonly property bool hovered: rowHover.hovered
    // Integración con buscador global de Settings
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    readonly property string settingsTileRole: "tile"
    property bool tileTop: true
    property bool tileBottom: true

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + SettingsMaterialPreset.tilePaddingX * 2
    implicitHeight: Math.max(SettingsMaterialPreset.rowMinHeight, row.implicitHeight + SettingsMaterialPreset.tilePaddingY * 2)

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
        spinBoxWidget.forceActiveFocus();
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

    HoverHandler {
        id: rowHover
    }

    Rectangle {
        anchors.fill: parent
        color: SettingsMaterialPreset.tileColor
        topLeftRadius: root.tileTop ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.tileBottom ? SettingsMaterialPreset.tileOuterRadius : SettingsMaterialPreset.tileInnerRadius
        bottomRightRadius: bottomLeftRadius
    }

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: SettingsMaterialPreset.tilePaddingX
            rightMargin: SettingsMaterialPreset.tilePaddingX
            topMargin: SettingsMaterialPreset.tilePaddingY
            bottomMargin: SettingsMaterialPreset.tilePaddingY
        }
        spacing: SettingsMaterialPreset.tilePaddingX

        OptionalMaterialSymbol {
            icon: root.icon
            iconSize: SettingsMaterialPreset.iconSize
            color: SettingsMaterialPreset.supportingColor
            opacity: root.enabled ? 1 : 0.38
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.text
                font.pixelSize: SettingsMaterialPreset.labelSize
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
                wrapMode: Text.WordWrap
            }
        }

        StyledSpinBox {
            id: spinBoxWidget
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            onValueModified: root.valueModified()
        }
    }
}
