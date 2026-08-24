import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property string protectionMessage: ""
    property bool initialized: false
    property var excludedScreenNames: []
    readonly property var targetScreens: {
        const list = Config.options?.osd?.screenList ?? []
        const screens = Quickshell.screens
        let selected = screens
        if (list && list.length > 0) {
            const matched = screens.filter(screen => {
                const screenName = screen?.name ?? ""
                return screenName.length > 0 && list.includes(screenName)
            })
            // Fallback safety: stale monitor names should never hide the OSD everywhere.
            selected = matched.length > 0 ? matched : screens
        }
        return selected.filter(screen => !root.excludedScreenNames.includes(screen?.name ?? ""))
    }
    property string currentIndicator: "volume"
    property bool _syncingOpenStates: false
    readonly property bool osdActive: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMicOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen
    readonly property bool mediaOsdVisible: GlobalStates.osdMediaOpen
        && root.currentIndicator === "media"
    property bool _surfaceRetained: false
    property bool _visualOpen: false
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "indicators/VolumeIndicator.qml"
        },
        {
            id: "brightness",
            sourceUrl: "indicators/BrightnessIndicator.qml"
        },
        {
            id: "mic",
            sourceUrl: "indicators/MicIndicator.qml"
        },
        {
            id: "media",
            sourceUrl: "indicators/MediaIndicator.qml"
        },
        {
            id: "voiceSearch",
            sourceUrl: "indicators/VoiceSearchIndicator.qml"
        },
        {
            id: "keyboardLayout",
            sourceUrl: "indicators/KeyboardLayoutIndicator.qml"
        },
    ]

    function setOpenStates(volume, brightness, mic, media, keyboardLayout) {
        root._syncingOpenStates = true;
        GlobalStates.osdVolumeOpen = volume;
        GlobalStates.osdBrightnessOpen = brightness;
        GlobalStates.osdMicOpen = mic;
        GlobalStates.osdMediaOpen = media;
        GlobalStates.osdKeyboardLayoutOpen = keyboardLayout;
        root._syncingOpenStates = false;
        root._reconcilePresentation()
    }

    function hideOsd() {
        osdTimeout.stop();
        root.setOpenStates(false, false, false, false, false);
        root.protectionMessage = "";
    }

    function _reconcilePresentation(): void {
        if (root.osdActive) {
            osdReleaseTimer.stop()
            root._surfaceRetained = true
            Qt.callLater(() => {
                if (root.osdActive)
                    root._visualOpen = true
            })
        } else if (root._surfaceRetained) {
            root._visualOpen = false
            osdReleaseTimer.restart()
        }
    }

    onOsdActiveChanged: {
        if (!root._syncingOpenStates)
            root._reconcilePresentation()
    }

    Component.onCompleted: {
        root._reconcilePresentation()
    }

    Timer {
        id: osdReleaseTimer
        interval: Appearance.animation.elementMoveExit.duration + 60
        repeat: false
        onTriggered: {
            if (!root.osdActive)
                root._surfaceRetained = false
        }
    }

    function openIndicator(indicator, autoHide) {
        if (!initialized) return;
        root.currentIndicator = indicator;
        root.setOpenStates(
            indicator === "volume" || indicator === "voiceSearch",
            indicator === "brightness",
            indicator === "mic",
            indicator === "media",
            indicator === "keyboardLayout"
        );
        if (autoHide)
            osdTimeout.restart();
    }

    function triggerOsd() {
        root.openIndicator(root.currentIndicator, true);
    }

    Timer {
        id: initDelay
        interval: 1500
        running: true
        onTriggered: root.initialized = true
    }

    Timer {
        id: osdTimeout
        interval: root.currentIndicator === "media" 
            ? (Config.options?.osd?.timeout ?? 2000) + 1000  // Longer for media
            : (Config.options?.osd?.timeout ?? 2000)
        repeat: false
        running: false
        onTriggered: {
            root.hideOsd();
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.protectionMessage = "";
            root.currentIndicator = "brightness";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready || GameMode.suppressNiriToast)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
        function onMutedChanged() {
            if (!Audio.ready || GameMode.suppressNiriToast)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to protection triggers
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }

    Connections {
        // Listen to mic volume/mute changes
        target: Audio
        function onMicVolumeChanged() {
            if (!root.initialized) return;
            root.currentIndicator = "mic";
            root.triggerOsd();
        }
        function onMicMutedChanged() {
            if (!root.initialized) return;
            root.currentIndicator = "mic";
            root.triggerOsd();
        }
    }

    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdVolumeOpen)
                return;
            root.currentIndicator = "volume";
            osdTimeout.restart();
        }
        function onOsdBrightnessOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdBrightnessOpen)
                return;
            root.currentIndicator = "brightness";
            osdTimeout.restart();
        }
        function onOsdMicOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdMicOpen)
                return;
            root.currentIndicator = "mic";
            osdTimeout.restart();
        }
        function onOsdMediaOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdMediaOpen)
                return;
            if (!(Config.options?.osd?.mediaEnabled ?? true)
                    || !MprisController.activePlayer) {
                GlobalStates.osdMediaOpen = false;
                return;
            }
            root.currentIndicator = "media";
            osdTimeout.restart();
        }
        function onOsdKeyboardLayoutOpenChanged() {
            if (root._syncingOpenStates || !GlobalStates.osdKeyboardLayoutOpen)
                return;
            root.currentIndicator = "keyboardLayout";
            osdTimeout.restart();
        }
        function onOsdMediaActionTriggered(action: string) {
            if (!root.mediaOsdVisible || !action.length)
                return;
            root.currentIndicator = "media";
            osdTimeout.restart();
        }
    }

    Connections {
        target: VoiceSearch
        function onRunningChanged() {
            if (VoiceSearch.running) {
                root.openIndicator("voiceSearch", false);
                osdTimeout.stop(); // Don't auto-hide while active
            } else {
                osdTimeout.restart();
            }
        }
    }

    Connections {
        target: KeyboardIndicators
        function onPopupSequenceChanged() {
            root.currentIndicator = "keyboardLayout";
            root.triggerOsd();
        }
    }

    Connections {
        target: MprisController
        function onTrackChanged(reverse: bool): void {
            if (root.mediaOsdVisible)
                osdTimeout.restart()
        }
    }

    Connections {
        target: MediaArtwork
        function onDisplaySourceChanged(): void {
            if (root.mediaOsdVisible)
                osdTimeout.restart()
        }
    }

    Loader {
        id: osdLoader
        active: root._surfaceRetained

        sourceComponent: Variants {
            model: root.targetScreens
            delegate: PanelWindow {
                id: osdRoot
                required property var modelData
                screen: modelData
                color: "transparent"

                WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: root.currentIndicator === "keyboardLayout" ? true : !(Config.options?.bar?.bottom ?? false)
                bottom: root.currentIndicator === "keyboardLayout" ? false : Config.options?.bar?.bottom ?? false
            }
            mask: Region {
                item: osdValuesWrapper
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: Appearance.sizes.barHeight
                bottom: Appearance.sizes.barHeight
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                readonly property bool entersFromTop: root.currentIndicator === "keyboardLayout"
                    || !(Config.options?.bar?.bottom ?? false)
                property real openProgress: root._visualOpen ? 1 : 0
                transformOrigin: entersFromTop ? Item.Top : Item.Bottom
                scale: 0.94 + 0.06 * openProgress
                opacity: openProgress
                y: (1 - openProgress) * (entersFromTop ? -12 : 12)
                visible: openProgress > 0.001

                Behavior on openProgress {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: root._visualOpen
                            ? Appearance.animation.elementMoveEnter.duration
                            : Appearance.animation.elementMoveExit.duration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: root._visualOpen
                            ? Appearance.animation.elementMoveEnter.bezierCurve
                            : Appearance.animationCurves.standardAccel
                    }
                }

                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.currentIndicator !== "media"
                        hoverEnabled: true
                        onEntered: root.hideOsd()
                    }

                    HoverHandler {
                        enabled: root.currentIndicator === "media"
                        onHoveredChanged: {
                            if (hovered)
                                osdTimeout.stop()
                            else if (root.mediaOsdVisible)
                                osdTimeout.restart()
                        }
                    }

                    Column {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 0

                        Loader {
                            id: osdIndicatorLoader
                            source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl
                        }

                        Item {
                            id: protectionMessageWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitHeight: protectionMessageBackground.implicitHeight
                            implicitWidth: protectionMessageBackground.implicitWidth
                            opacity: root.protectionMessage !== "" ? 1 : 0

                            StyledRectangularShadow {
                                target: protectionMessageBackground
                            }
                            Rectangle {
                                id: protectionMessageBackground
                                anchors.centerIn: parent
                                color: Appearance.colors.colError
                                property real padding: 10
                                implicitHeight: protectionMessageRowLayout.implicitHeight + padding * 2
                                implicitWidth: protectionMessageRowLayout.implicitWidth + padding * 2
                                radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

                                RowLayout {
                                    id: protectionMessageRowLayout
                                    anchors.centerIn: parent
                                    MaterialSymbol {
                                        id: protectionMessageIcon
                                        text: "dangerous"
                                        iconSize: Appearance.font.pixelSize.hugeass
                                        color: Appearance.colors.colOnError
                                    }
                                    StyledText {
                                        id: protectionMessageTextWidget
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Appearance.colors.colOnError
                                        wrapMode: Text.Wrap
                                        text: root.protectionMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }

    IpcHandler {
        target: "osdVolume"

        function trigger(): void {
            root.triggerOsd();
        }

        function hide(): void {
            root.hideOsd();
        }

        function toggle(): void {
            GlobalStates.osdVolumeOpen = !GlobalStates.osdVolumeOpen;
        }
    }

    Loader {
        active: CompositorService.isHyprland
        sourceComponent: Item {
            GlobalShortcut {
                name: "osdVolumeTrigger"
                description: "Triggers volume OSD on press"

                onPressed: {
                    root.triggerOsd();
                }
            }
            GlobalShortcut {
                name: "osdVolumeHide"
                description: "Hides volume OSD on press"

                onPressed: {
                    GlobalStates.osdVolumeOpen = false;
                }
            }
        }
    }
}
