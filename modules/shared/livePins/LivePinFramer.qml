pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

// Framing a live snip: pick a window (the focused one comes first), then drag over the part of its own live picture
// to keep. niri tells where a floating window is but not a tiled one, so the box is drawn on the window, not the screen.
Scope {
    id: root

    PanelWindow {
        id: framer
        screen: GlobalStates.focusedScreen ?? Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "inir:livepin-framer"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }

        // Every window, the focused one first, then by last use.
        readonly property var windows: {
            const list = Array.from(NiriService.windows ?? []).filter(w => !String(w.app_id ?? "").startsWith("inir"))
            const at = w => w.is_focused ? Infinity : Number(w.focus_timestamp?.secs ?? 0) * 1e3 + Number(w.focus_timestamp?.nanos ?? 0) / 1e6
            return list.sort((a, b) => at(b) - at(a))
        }
        property int chosenId: framer.windows[0]?.id ?? -1
        readonly property var chosen: framer.windows.find(w => w.id === framer.chosenId) ?? null
        readonly property size windowSize: {
            const s = framer.chosen?.layout?.window_size ?? [16, 9]
            return Qt.size(Math.max(1, Number(s[0])), Math.max(1, Number(s[1])))
        }
        // The window's picture fits the middle of the screen; the box is kept in its pixels.
        readonly property real fit: Math.min((framer.width * 0.78) / framer.windowSize.width,
            (framer.height - 260) / framer.windowSize.height, 1.25)
        property rect box: Qt.rect(0, 0, 0, 0)
        readonly property bool boxed: framer.box.width >= 16 && framer.box.height >= 16
        onChosenIdChanged: framer.box = Qt.rect(0, 0, 0, 0)

        function close(): void { LivePins.framing = false }
        function pin(): void {
            if (!framer.boxed || !framer.chosen) return
            const crop = Qt.rect(framer.box.x / framer.fit, framer.box.y / framer.fit, framer.box.width / framer.fit, framer.box.height / framer.fit)
            const at = picture.mapToItem(null, framer.box.x, framer.box.y)
            LivePins.pinWindow(framer.chosen.id, crop, framer.screen?.name ?? "", at.x, at.y, framer.box.width)
            framer.close()
        }

        Shortcut { sequence: "Escape"; onActivated: framer.close() }
        Shortcut { sequences: ["Return", "Enter"]; onActivated: framer.pin() }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            MouseArea { anchors.fill: parent; onClicked: framer.close() }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            // Which window.
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: framer.width * 0.86
                spacing: 6
                clip: true
                Repeater {
                    model: framer.windows.slice(0, 9)
                    MouseArea {
                        id: chip
                        required property var modelData
                        readonly property bool current: chip.modelData.id === framer.chosenId
                        width: chipRow.implicitWidth + 24
                        height: 34
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: framer.chosenId = chip.modelData.id
                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: chip.current ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(1, 1, 1, chip.containsMouse ? 0.16 : 0.08)
                            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                        }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 7
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 16
                                source: Quickshell.iconPath(AppSearch.lookupDesktopEntry(chip.modelData.app_id ?? "")?.icon
                                    || AppSearch.guessIcon(chip.modelData.app_id ?? ""), "application-x-executable")
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, 180)
                                text: String(chip.modelData.title ?? "").length > 0 ? chip.modelData.title : String(chip.modelData.app_id ?? "")
                                color: chip.current ? "black" : "white"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: chip.current ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // Its picture, where the box is drawn.
            Item {
                id: picture
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(framer.windowSize.width * framer.fit)
                implicitHeight: Math.round(framer.windowSize.height * framer.fit)

                ClippingRectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Qt.rgba(1, 1, 1, 0.06)
                    LiveWindowCapture {
                        id: capture
                        anchors.fill: parent
                        windowId: framer.chosenId
                        fillMode: Image.PreserveAspectFit
                    }
                    StyledText {
                        anchors.centerIn: parent
                        visible: !capture.streaming
                        text: Translation.tr("Waiting for the window's picture")
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                // Outside the box goes dark; the box keeps the picture as it is.
                Item {
                    anchors.fill: parent
                    visible: framer.boxed
                    Rectangle { x: 0; y: 0; width: parent.width; height: framer.box.y; color: Qt.rgba(0, 0, 0, 0.55) }
                    Rectangle { x: 0; y: framer.box.y + framer.box.height; width: parent.width; height: parent.height - y; color: Qt.rgba(0, 0, 0, 0.55) }
                    Rectangle { x: 0; y: framer.box.y; width: framer.box.x; height: framer.box.height; color: Qt.rgba(0, 0, 0, 0.55) }
                    Rectangle { x: framer.box.x + framer.box.width; y: framer.box.y; width: parent.width - x; height: framer.box.height; color: Qt.rgba(0, 0, 0, 0.55) }
                    Rectangle {
                        x: framer.box.x - 1
                        y: framer.box.y - 1
                        width: framer.box.width + 2
                        height: framer.box.height + 2
                        radius: 4
                        color: "transparent"
                        border.width: 2
                        border.color: "white"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    property point from: Qt.point(0, 0)
                    onPressed: mouse => {
                        from = Qt.point(mouse.x, mouse.y)
                        framer.box = Qt.rect(mouse.x, mouse.y, 0, 0)
                    }
                    onPositionChanged: mouse => {
                        const x = Math.max(0, Math.min(parent.width, mouse.x)), y = Math.max(0, Math.min(parent.height, mouse.y))
                        framer.box = Qt.rect(Math.min(from.x, x), Math.min(from.y, y), Math.abs(x - from.x), Math.abs(y - from.y))
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                StyledText {
                    text: framer.boxed ? Translation.tr("It stays live, even on another workspace")
                        : Translation.tr("Drag over the part to keep")
                    color: Qt.rgba(1, 1, 1, 0.75)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
                Item { implicitWidth: 16 }
                FramerButton { text: Translation.tr("Cancel"); onActivated: framer.close() }
                FramerButton { text: Translation.tr("Pin live"); primary: true; enabled: framer.boxed; onActivated: framer.pin() }
            }
        }
    }

    component FramerButton: MouseArea {
        id: button
        property string text: ""
        property bool primary: false
        signal activated()
        implicitWidth: label.implicitWidth + 32
        implicitHeight: 36
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        opacity: button.enabled ? 1 : 0.4
        onClicked: button.activated()
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: button.primary ? Qt.rgba(1, 1, 1, button.containsMouse ? 1 : 0.92) : Qt.rgba(1, 1, 1, button.containsMouse ? 0.18 : 0.1)
        }
        StyledText {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? "black" : "white"
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
        }
    }
}
