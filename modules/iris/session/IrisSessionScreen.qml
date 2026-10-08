pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Variants {
    id: root
    model: Quickshell.screens

    PanelWindow {
        id: window
        required property var modelData
        property bool presentationVisible: GlobalStates.sessionOpen
        property bool presentationShown: false
        visible: window.presentationVisible
        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:iris-session"
        WlrLayershell.keyboardFocus: GlobalStates.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        function runAction(action: string): void {
            GlobalStates.sessionOpen = false
            switch (action) {
            case "lock": Session.lock(); break
            case "suspend": Session.suspend(); break
            case "logout": Session.logout(); break
            case "reboot": Session.reboot(); break
            case "poweroff": Session.poweroff(); break
            }
        }

        Component.onCompleted: {
            if (GlobalStates.sessionOpen)
                Qt.callLater(() => window.presentationShown = true)
        }

        Connections {
            target: GlobalStates
            function onSessionOpenChanged(): void {
                if (GlobalStates.sessionOpen) {
                    closePresentation.stop()
                    window.presentationVisible = true
                    Qt.callLater(() => window.presentationShown = true)
                } else if (window.presentationVisible) {
                    window.presentationShown = false
                    closePresentation.restart()
                }
            }
        }

        Timer {
            id: closePresentation
            interval: IrisStyle.duration(160)
            onTriggered: window.presentationVisible = false
        }

        Shortcut {
            enabled: GlobalStates.sessionOpen
            sequences: [StandardKey.Cancel]
            onActivated: {
                if ((sessionLoader.item?.pending ?? "").length > 0) sessionLoader.item.pending = ""
                else GlobalStates.sessionOpen = false
            }
        }

        Loader {
            id: sessionLoader
            anchors.fill: parent
            sourceComponent: islandComponent
        }

        Component {
            id: islandComponent

            FocusScope {
                id: stage
                readonly property real d: IrisStyle.density
                readonly property var actions: [
                    { id: "suspend", icon: "bedtime", label: Translation.tr("Sleep"), confirm: false },
                    { id: "reboot", icon: "restart_alt", label: Translation.tr("Restart"), confirm: true },
                    { id: "poweroff", icon: "power_settings_new", label: Translation.tr("Shut Down"), confirm: true },
                    { id: "lock", icon: "lock", label: Translation.tr("Lock"), confirm: false },
                    { id: "logout", icon: "logout", label: Translation.tr("Log Out"), confirm: true }
                ]
                // Lume reads the wallpaper where the clock and the row sit: a bright one gets a thicker veil.
                readonly property var backdropSample: Lume.read(String(window.modelData?.name ?? ""),
                    stage.width * 0.3, stage.height * 0.3, stage.width * 0.4, stage.height * 0.4)
                readonly property real veilAlpha: IrisStyle.mediaVeil(stage.backdropSample?.level ?? -1, stage.backdropSample?.spread ?? 0)
                property int focusIndex: 0
                property bool keyboardNavigation: false
                property string pending: ""
                readonly property var pendingAction: stage.actions.find(action => action.id === stage.pending) ?? null

                function trigger(index: int): void {
                    const action = stage.actions[index]
                    stage.focusIndex = index
                    if (action.confirm && stage.pending !== action.id) {
                        stage.pending = action.id
                        pendingExpiry.restart()
                        return
                    }
                    window.runAction(action.id)
                }

                Timer { id: pendingExpiry; interval: 5000; onTriggered: stage.pending = "" }

                focus: true
                Component.onCompleted: Qt.callLater(() => stage.forceActiveFocus())
                Keys.onPressed: event => {
                    const count = stage.actions.length
                    if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                        stage.keyboardNavigation = true
                        stage.pending = ""
                        stage.focusIndex = (stage.focusIndex + 1) % count
                    } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
                        stage.keyboardNavigation = true
                        stage.pending = ""
                        stage.focusIndex = (stage.focusIndex + count - 1) % count
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        stage.keyboardNavigation = true
                        stage.trigger(stage.focusIndex)
                    } else {
                        return
                    }
                    event.accepted = true
                }

                IrisWallpaperView {
                    id: backdropImage
                    anchors.fill: parent
                    anchors.margins: -Math.round(64 * stage.d)
                    // Hidden by opacity: a hidden subtree never renders a live wallpaper's frames into the texture.
                    opacity: 0
                    screen: window.modelData
                    // The window maps at height 0: decoding before it has its size read the picture at 1×1 and 480×1 first.
                    active: stage.width > 0 && stage.height > 0
                    live: window.presentationShown
                    provideTexture: true
                    decodeSize: Qt.size(Math.max(1, Math.round(stage.width / 4)), Math.max(1, Math.round(stage.height / 4)))
                }
                Item {
                    anchors.fill: parent
                    opacity: window.presentationShown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                    Rectangle { anchors.fill: parent; color: IrisStyle.darkSurfaceOpaque }
                    MultiEffect {
                        anchors.fill: parent
                        anchors.margins: -Math.round(64 * stage.d)
                        visible: backdropImage.ready
                        source: backdropImage.textureItem
                        // Auto padding crops the source by its size at this item's last resize; it grew first and kept the
                        // top rows stretched over the screen. The -64 margins are the padding.
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: 1
                        blurMax: 48
                        saturation: 0.1
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: backdropImage.ready
                        color: ColorUtils.applyAlpha(IrisStyle.darkSurfaceOpaque, stage.veilAlpha)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (stage.pending.length > 0) stage.pending = ""
                        else GlobalStates.sessionOpen = false
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    opacity: window.presentationShown ? 1 : 0
                    scale: window.presentationShown ? 1 : 0.96
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }

                    IrisClock {
                        Layout.alignment: Qt.AlignHCenter
                        pixelSize: Math.round(64 * IrisStyle.typeScale)
                        color: IrisStyle.onMedia
                        separatorColor: IrisStyle.highlightOnMedia
                    }
                    IrisText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.locale.toString(DateTime.clock.date, "dddd, d MMMM")
                        color: IrisStyle.onMediaSecondary
                        font.pixelSize: IrisStyle.typeHeadline
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 44 * stage.d
                        spacing: 30 * stage.d

                        Repeater {
                            model: stage.actions
                            Item {
                                id: action
                                required property var modelData
                                required property int index
                                readonly property bool armed: stage.pending === action.modelData.id
                                readonly property bool focused: stage.keyboardNavigation && stage.focusIndex === action.index
                                width: Math.round(76 * stage.d)
                                height: disc.height + label.anchors.topMargin + label.height

                                Rectangle {
                                    id: disc
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: width
                                    radius: width / 2
                                    color: action.armed ? IrisStyle.dangerOnMedia
                                        : pointer.containsMouse || action.focused ? IrisStyle.onMediaFillHover
                                        : IrisStyle.onMediaFill
                                    scale: pointer.pressed ? IrisStyle.pressScale(0.93) : 1
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + 8 * stage.d
                                        height: width
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 2
                                        border.color: action.armed ? IrisStyle.dangerOnMedia : IrisStyle.accentOnMedia
                                        visible: action.focused
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: action.modelData.icon
                                        iconSize: Math.round(30 * stage.d)
                                        fill: 1
                                        color: IrisStyle.onMedia
                                    }
                                }
                                IrisText {
                                    id: label
                                    anchors.top: disc.bottom
                                    anchors.topMargin: 10 * stage.d
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: action.armed ? Translation.tr("Confirm") : action.modelData.label
                                    color: action.armed ? IrisStyle.dangerOnMedia : IrisStyle.onMedia
                                    font.pixelSize: IrisStyle.typeLabel
                                    font.weight: IrisStyle.weight(Font.Medium)
                                }
                                MouseArea {
                                    id: pointer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: action.modelData.label
                                    onEntered: stage.keyboardNavigation = false
                                    onClicked: stage.trigger(action.index)
                                }
                            }
                        }
                    }

                    IrisText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 22 * stage.d
                        text: stage.pendingAction
                            ? Translation.tr("Press %1 again to continue").arg(stage.pendingAction.label)
                            : Translation.tr("Up %1").arg(DateTime.uptime)
                        color: stage.pendingAction ? IrisStyle.onMedia : IrisStyle.onMediaTertiary
                        font.pixelSize: IrisStyle.typeLabel
                    }
                }
            }
        }
    }
}
