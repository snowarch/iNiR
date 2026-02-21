import qs.modules.common.widgets
import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Time input widget for HH:mm format.
 * Compact design matching other Config* widgets.
 */
RowLayout {
    id: root
    property string text: ""
    property string icon
    property string value: "00:00" // Format: "HH:mm"
    property bool hovered: timeRow.hovered

    // Integración con buscador global de Settings
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1

    signal timeChanged(string newTime)

    spacing: 10
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    // Parse time string to components
    property int _hour: {
        const parts = value.split(":")
        return parts.length >= 1 ? parseInt(parts[0]) || 0 : 0
    }
    property int _minute: {
        const parts = value.split(":")
        return parts.length >= 2 ? parseInt(parts[1]) || 0 : 0
    }

    function _formatTime(h, m) {
        return h.toString().padStart(2, '0') + ":" + m.toString().padStart(2, '0')
    }

    function _setTime(h, m) {
        const newTime = _formatTime(h, m)
        if (root.value !== newTime) {
            root.value = newTime
            root.timeChanged(newTime)
        }
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
        spacing: 10
        Layout.fillWidth: true

        MaterialSymbol {
            visible: root.icon && root.icon.length > 0
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }

        StyledText {
            Layout.fillWidth: true
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
            elide: Text.ElideNone
        }
    }

    // Compact time display with click to edit
    Rectangle {
        id: timeRow
        property bool hovered: timeMouseArea.containsMouse

        Layout.preferredWidth: timeLabel.implicitWidth + 24
        Layout.preferredHeight: 35
        radius: Appearance.rounding.small
        color: hovered ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        opacity: root.enabled ? 1 : 0.4

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        StyledText {
            id: timeLabel
            anchors.centerIn: parent
            text: root._formatTime(root._hour, root._minute)
            color: Appearance.colors.colOnLayer2
            font.family: Appearance.font.family.numbers
            font.variableAxes: Appearance.font.variableAxes.numbers
            font.pixelSize: Appearance.font.pixelSize.small
        }

        MouseArea {
            id: timeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: (mouse) => {
                if (!root.enabled) return
                // Left half = hours, right half = minutes
                const isHour = mouse.x < width / 2
                if (mouse.button === Qt.LeftButton) {
                    if (isHour) {
                        root._setTime((root._hour + 1) % 24, root._minute)
                    } else {
                        root._setTime(root._hour, (root._minute + 5) % 60)
                    }
                } else if (mouse.button === Qt.RightButton) {
                    if (isHour) {
                        root._setTime((root._hour + 23) % 24, root._minute)
                    } else {
                        root._setTime(root._hour, (root._minute + 55) % 60)
                    }
                }
            }

            onWheel: (wheel) => {
                if (!root.enabled) return
                const isHour = wheel.x < width / 2
                const delta = wheel.angleDelta.y > 0 ? 1 : -1
                if (isHour) {
                    root._setTime((root._hour + delta + 24) % 24, root._minute)
                } else {
                    const step = delta > 0 ? 5 : -5
                    root._setTime(root._hour, (root._minute + step + 60) % 60)
                }
            }
        }

        StyledToolTip {
            visible: timeMouseArea.containsMouse
            text: Translation.tr("Click/scroll to adjust. Left=hours, Right=minutes")
        }
    }
}
