import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property string text: ""
    property string icon
    // Optional wrapping subtext under the label
    property string description: ""
    property alias value: spinBoxWidget.value
    property alias stepSize: spinBoxWidget.stepSize
    property alias from: spinBoxWidget.from
    property alias to: spinBoxWidget.to
    // Expose hover state for tooltips and other helpers
    property alias hovered: spinBoxWidget.hovered
    // Integración con buscador global de Settings
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

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

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        OptionalMaterialSymbol {
            icon: root.icon
            opacity: root.enabled ? 1 : 0.4
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                id: labelWidget
                Layout.fillWidth: true
                elide: Text.ElideRight
                maximumLineCount: 1
                text: root.text
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                    : Appearance.inirEverywhere ? Appearance.inir.colText
                    : Appearance.colors.colOnSurface
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
    }

    StyledSpinBox {
        id: spinBoxWidget
        Layout.fillWidth: false
        value: root.value
    }
}
