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

    Layout.fillWidth: true
    implicitHeight: contentItem.implicitHeight + 6 * 2
    font.pixelSize: Appearance.font.pixelSize.small

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
        spacing: 8
        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            opacity: root.enabled ? 1 : 0.4
            iconSize: Appearance.font.pixelSize.large
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                text: root.text
                font: root.font
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                    : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                opacity: root.enabled ? 1 : 0.4
            }

            StyledText {
                visible: root.description.length > 0
                Layout.fillWidth: true
                text: root.description
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                opacity: root.enabled ? 0.9 : 0.4
                wrapMode: Text.WordWrap
            }
        }
        StyledSwitch {
            id: switchWidget
            down: root.down
            scale: 0.6
            Layout.fillWidth: false
            checked: root.checked
            onClicked: root.clicked()
        }
    }
}
