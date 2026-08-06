pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Options toolbar — unified snip controls: pick the action and the region shape
// inline, plus instant fullscreen capture and color picker.
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    // Signals
    signal dismiss()
    signal fullscreenRequested()
    signal colorPickerRequested()

    // Region actions selectable in-overlay (order = tab index)
    readonly property var actionList: [
        { "action": RegionSelection.SnipAction.Copy,            "icon": "content_cut",      "name": Translation.tr("Shot") },
        { "action": RegionSelection.SnipAction.Edit,            "icon": "draw",             "name": Translation.tr("Edit") },
        { "action": RegionSelection.SnipAction.CharRecognition, "icon": "document_scanner", "name": Translation.tr("OCR") },
        { "action": RegionSelection.SnipAction.Search,          "icon": "image_search",     "name": Translation.tr("Search") },
        { "action": RegionSelection.SnipAction.Record,          "icon": "videocam",         "name": Translation.tr("Record") }
    ]
    function indexForAction(a) {
        for (let i = 0; i < root.actionList.length; i++)
            if (root.actionList[i].action === a) return i;
        return 0;
    }

    function persistSnipChoice(): void {
        if (!(Config.options?.regionSelector?.rememberSnipChoice ?? true)) return
        const isRecord = root.action === RegionSelection.SnipAction.Record
            || root.action === RegionSelection.SnipAction.RecordWithSound
        const updates = { "regionSelector.lastMode": root.selectionMode }
        if (!isRecord) updates["regionSelector.lastAction"] = root.action
        Config.setNestedValues(updates)
    }

    // Action selector
    ToolbarTabBar {
        id: actionBar
        Layout.alignment: Qt.AlignVCenter
        tabButtonList: root.actionList.map(a => ({"icon": a.icon, "name": a.name}))
        onCurrentIndexChanged: {
            const a = root.actionList[currentIndex]?.action;
            if (a !== undefined && a !== root.action) root.action = a;
        }
        onUserSelected: root.persistSnipChoice()
    }

    // Region shape (applies when drawing a region)
    ToolbarTabBar {
        id: modeBar
        Layout.alignment: Qt.AlignVCenter
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]
        onCurrentIndexChanged: {
            root.selectionMode = currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
        }
        onUserSelected: root.persistSnipChoice()
    }

    // Instant tools (no region selection needed)
    FloatingActionButton {
        Layout.alignment: Qt.AlignVCenter
        baseSize: 40
        iconText: "fullscreen"
        onClicked: root.fullscreenRequested()
        StyledToolTip { text: Translation.tr("Capture fullscreen") }
        colBackground: Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
        colOnBackground: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnSecondaryContainer
    }
    FloatingActionButton {
        Layout.alignment: Qt.AlignVCenter
        baseSize: 40
        iconText: "colorize"
        onClicked: root.colorPickerRequested()
        StyledToolTip { text: Translation.tr("Color picker") }
        colBackground: Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
        colRipple: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
        colOnBackground: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnSecondaryContainer
    }

    onActionChanged: actionBar.setCurrentIndex(root.indexForAction(root.action))
    onSelectionModeChanged: {
        modeBar.setCurrentIndex(selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1);
    }

    Component.onCompleted: {
        actionBar.setCurrentIndex(root.indexForAction(root.action));
        modeBar.setCurrentIndex(selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1);
    }
}
