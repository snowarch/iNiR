pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.shared.background.edit
import qs.modules.shared.background.widgets

// Arranging the desktop under Material, one window per screen: a floating toolbar slides down from the top (undo,
// redo, what just happened, the grid, Done) and the shelf of widgets rises from the bottom, while the desktop recedes
// into a card between them (DesktopEditStage) and the windows of the workspace wait on an empty one. The window only
// takes input on the toolbar and the shelf; the picture in hand is drawn across all of it.
Scope {
    id: scope

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: desk
            required property var modelData
            screen: modelData
            readonly property string outputName: desk.screen?.name ?? ""
            readonly property bool present: GlobalStates.widgetEditMode
            property real p: 0
            readonly property bool shown: desk.p > 0.001
            visible: desk.shown || desk.present
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:ii-edit-desk"
            // The keyboard is held for a beat when the mode opens (Escape works at once), then left on demand so the
            // widgets under the card take the pointer.
            WlrLayershell.keyboardFocus: !desk.present ? WlrKeyboardFocus.None
                : desk.seeding ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {
                item: headBody
                Region { item: shelfBody }
            }

            property bool seeding: false
            Timer { id: seedTimer; interval: 350; onTriggered: desk.seeding = false }
            Behavior on p { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
            property bool entered: false
            Timer { id: enterTimer; interval: 0; onTriggered: desk.entered = true }
            Component.onCompleted: {
                enterTimer.start()
                DesktopEditStage.setHost(desk.outputName, true)
                // Loaded by the mode itself: it was already on, no change comes.
                if (desk.present) desk.enter()
            }
            Binding { target: desk; property: "p"; value: desk.entered && desk.present ? 1 : 0 }
            onPresentChanged: if (desk.present) desk.enter()
            function enter(): void { desk.seeding = true; seedTimer.restart(); desk.prepare() }
            function prepare(): void {
                DesktopEditStage.look = (Appearance.m3colors.darkmode ? "dark" : "light") + "-material"
                Quickshell.execDetached(["mkdir", "-p", DesktopEditStage.pictureDir])
                // The bar is away while arranging: where it rests comes from its edge and thickness.
                const insets = ShellLayoutController.desktopInsets(desk.outputName)
                const t = insets.barThickness ?? 0
                const sw = desk.screen?.width ?? 0
                const sh = desk.screen?.height ?? 0
                const band = ({ top: [0, 0, sw, t], bottom: [0, sh - t, sw, t], left: [0, 0, t, sh], right: [sw - t, 0, t, sh] })[insets.barEdge ?? ""]
                DesktopArrange.setBodies(desk.outputName, "bar", band && t > 1
                    ? [{ id: "bar", name: Translation.tr("Bar"), x: band[0], y: band[1], w: band[2], h: band[3], radius: 0 }] : [])
            }

            // ── The card between the toolbar and the shelf; windows step aside ──
            readonly property real margin: 14
            readonly property var stageNow: [desk.outputName, Math.max(0, Math.min(1, desk.p)),
                desk.margin + headBody.height, desk.margin + shelfBody.height]
            onStageNowChanged: DesktopEditStage.setStage(desk.stageNow[0], desk.stageNow[1], desk.stageNow[2], desk.stageNow[3])
            readonly property bool parks: desk.present && (GlobalStates.focusedScreen?.name ?? desk.outputName) === desk.outputName
            onParksChanged: if (desk.parks) DesktopEditStage.park(desk.outputName)
            readonly property bool settledHome: !desk.present && desk.p < 0.04
            onSettledHomeChanged: if (desk.settledHome) DesktopEditStage.unpark()
            Component.onDestruction: {
                DesktopArrange.setBodies(desk.outputName, "bar", [])
                DesktopEditStage.setStage(desk.outputName, 0, 0, 0)
                DesktopEditStage.setHost(desk.outputName, false)
                if (!desk.present) DesktopEditStage.unpark()
            }

            // ── Keys ──
            readonly property bool holdsKeyboard: desk.present && (GlobalStates.focusedScreen?.name ?? desk.outputName) === desk.outputName
            readonly property bool selecting: GlobalStates.selectedDesktopWidget.length > 0
            Shortcut { sequence: "Ctrl+F"; enabled: desk.holdsKeyboard && !shelf.searching; onActivated: shelf.openSearch() }
            Shortcut {
                sequence: "Escape"
                enabled: desk.holdsKeyboard
                onActivated: {
                    if (shelf.searching) shelf.escapeSearch()
                    else if (desk.selecting) GlobalStates.clearDesktopWidgetSelection()
                    else GlobalStates.setWidgetEditMode(false)
                }
            }
            Shortcut { sequences: [StandardKey.Undo]; enabled: desk.holdsKeyboard && !shelf.searching; onActivated: DesktopEditHistory.undo() }
            Shortcut { sequences: [StandardKey.Redo, "Ctrl+Y"]; enabled: desk.holdsKeyboard && !shelf.searching; onActivated: DesktopEditHistory.redo() }
            readonly property bool nudging: desk.holdsKeyboard && desk.selecting && !shelf.searching
            Shortcut { sequence: "Left"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(-1, 0) }
            Shortcut { sequence: "Right"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(1, 0) }
            Shortcut { sequence: "Up"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -1) }
            Shortcut { sequence: "Down"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 1) }
            Shortcut { sequence: "Shift+Left"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(-10, 0) }
            Shortcut { sequence: "Shift+Right"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(10, 0) }
            Shortcut { sequence: "Shift+Up"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, -10) }
            Shortcut { sequence: "Shift+Down"; enabled: desk.nudging; onActivated: GlobalStates.desktopWidgetNudge(0, 10) }

            // ── The toolbar ──
            component ToolKey: RippleButton {
                id: key
                property string glyph
                property bool selected: false
                implicitWidth: 40
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: key.selected ? Appearance.colors.colSecondaryContainer : "transparent"
                colBackgroundHover: key.selected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                opacity: key.enabled ? 1 : 0.38
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: key.glyph
                    iconSize: 20
                    fill: key.selected ? 1 : 0
                    color: key.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                }
            }
            Rectangle {
                id: headBody
                readonly property bool gridOn: Config.options?.background?.widgets?.editGrid?.snap ?? true
                anchors.horizontalCenter: parent.horizontalCenter
                y: desk.margin - (headBody.height + desk.margin + 12) * (1 - desk.p)
                width: headRow.implicitWidth + 16
                height: 56
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                opacity: Math.min(1, desk.p * 1.4)
                StyledRectangularShadow { target: headBody; z: -1 }
                Row {
                    id: headRow
                    anchors.centerIn: parent
                    spacing: 4
                    ToolKey {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "undo"
                        enabled: DesktopEditHistory.undoStack.length > 0
                        Accessible.name: Translation.tr("Undo")
                        onClicked: DesktopEditHistory.undo()
                    }
                    ToolKey {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "redo"
                        enabled: DesktopEditHistory.redoStack.length > 0
                        Accessible.name: Translation.tr("Redo")
                        onClicked: DesktopEditHistory.redo()
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(titleText.implicitWidth, hintText.implicitWidth) + 28
                        StyledText {
                            id: titleText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: DesktopEditHistory.notice.length > 0 ? DesktopEditHistory.notice : Translation.tr("Edit Desktop")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            id: hintText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Translation.tr("Drag to place · click to use")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                    ToolKey {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "grid_4x4"
                        selected: headBody.gridOn
                        Accessible.name: headBody.gridOn ? Translation.tr("Snap to grid: on") : Translation.tr("Snap to grid: off")
                        onClicked: Config.setNestedValue("background.widgets.editGrid.snap", !headBody.gridOn)
                    }
                    RippleButton {
                        id: doneKey
                        anchors.verticalCenter: parent.verticalCenter
                        implicitHeight: 40
                        implicitWidth: doneRow.implicitWidth + 32
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colPrimary
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        Accessible.name: Translation.tr("Done")
                        onClicked: GlobalStates.setWidgetEditMode(false)
                        contentItem: Row {
                            id: doneRow
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "check"
                                iconSize: 18
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Done")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }

            // ── The shelf ──
            Rectangle {
                id: shelfBody
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(1640, desk.width - 96)
                height: shelf.fullHeight
                y: desk.height - desk.margin - shelfBody.height + (shelfBody.height + desk.margin + 12) * (1 - desk.p)
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer1
                opacity: Math.min(1, desk.p * 1.4)
                StyledRectangularShadow { target: shelfBody; z: -1 }
                WidgetShelf {
                    id: shelf
                    anchors.fill: parent
                    outputName: desk.outputName
                    ghostLayer: ghostLayer
                    enabled: desk.present
                    face: materialFace
                    pages: materialFace.pages
                    Component.onCompleted: materialFace.shelf = shelf
                    entries: {
                        const list = DesktopWidgetRegistry.keys.map(key => materialFace.prepare({ key: key, glyph: DesktopWidgetRegistry.glyph(key),
                            name: materialFace.nameOf(key), english: materialFace.nameOf(key), tint: DesktopWidgetRegistry.tint(key),
                            words: [key, DesktopWidgetRegistry.keywordsOf(key), shelf.categoryNames[DesktopWidgetRegistry.categoryOf(key)] ?? "",
                                DesktopWidgetRegistry.categoryOf(key)].join(" "), category: DesktopWidgetRegistry.categoryOf(key) }))
                        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : []))
                            list.push(materialFace.prepare({ key: "custom." + custom.id, glyph: custom.icon || "widgets", name: custom.name,
                                english: custom.name, tint: DesktopWidgetRegistry.customTint, words: "custom hub", category: "decor" }))
                        return list
                    }
                }
            }
            Item { id: ghostLayer; anchors.fill: parent; z: 50 }

            MaterialShelfFace { id: materialFace }
        }
    }
}
