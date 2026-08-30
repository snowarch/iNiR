pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Flow {
    id: root
    Layout.fillWidth: true
    spacing: Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 2
    // Integración con buscador global de Settings
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    property list<var> options: [
        {
            "displayName": "Option 1",
            "icon": "check",
            "value": 1
        },
        {
            "displayName": "Option 2",
            "icon": "close",
            "value": 2
        },
    ]
    property var currentValue: null
    readonly property bool hovered: _hoverHandler.hovered

    signal selected(var newValue)

    HoverHandler {
        id: _hoverHandler
    }

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
        var label = ctx.groupTitle || sectionTitle;
        var optionNames = [];
        for (var i = 0; i < root.options.length; ++i) {
            var opt = root.options[i];
            if (opt && opt.displayName)
                optionNames.push(String(opt.displayName).toLowerCase());
        }
        
        // Include option names in description for better search
        var optionsList = optionNames.join(", ");

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: sectionTitle,
            label: label,
            description: optionsList,
            keywords: optionNames
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    Repeater {
        id: optionRepeater
        model: root.options
        delegate: SelectionGroupButton {
            id: paletteButton
            required property var modelData
            required property int index

            function syncRowEdges(): void {
                const previous = index > 0 ? optionRepeater.itemAt(index - 1) : null
                const startsRow = index === 0
                    || (previous !== null && previous.y !== paletteButton.y)
                paletteButton.leftmost = startsRow
                paletteButton.rightmost = index === root.options.length - 1
                if (previous !== null)
                    previous.rightmost = startsRow
            }

            Component.onCompleted: Qt.callLater(syncRowEdges)
            onYChanged: Qt.callLater(syncRowEdges)
            leftmost: index === 0
            rightmost: index === root.options.length - 1
            buttonIcon: modelData.icon || ""
            buttonPreviewKind: modelData.previewKind || ""
            buttonText: modelData.displayName
            opacity: modelData?.dimmed === true ? 0.45 : 1
            toggled: (root.currentValue != null && root.currentValue == modelData.value) ?? false
            onClicked: {
                root.selected(modelData.value);
            }
        }
    }
}
