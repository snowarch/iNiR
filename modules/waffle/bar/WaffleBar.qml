import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

Scope {
    id: root
    
    readonly property bool isBottom: Config.options?.waffles?.bar?.bottom ?? false
    
    // Variants cannot incubate asynchronously in Quickshell 0.3. Keep the
    // cheap per-screen loader delegates synchronous and incubate each heavy
    // PanelWindow independently so opening the bar never forces the complete
    // multi-output tree onto the UI thread.
    Variants {
        // Match the ii Bar.qml screen filter so multi-monitor users can
        // restrict the taskbar to specific outputs (ref #154).
        model: {
            const screens = Quickshell.screens;
            const list = Config.options?.waffles?.bar?.screenList ?? [];
            if (!list || list.length === 0)
                return screens;
            const matched = screens.filter(screen => {
                const screenName = screen?.name ?? "";
                return screenName.length > 0 && list.includes(screenName);
            });
            // Fallback safety: stale monitor names should never hide the bar everywhere.
            return matched.length > 0 ? matched : screens;
        }
        delegate: LazyLoader {
            id: barWindowLoader
            required property var modelData
            activeAsync: GlobalStates.barOpen

            component: PanelWindow { // Bar window
                id: barRoot
                screen: barWindowLoader.modelData
                visible: true
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: implicitHeight
                WlrLayershell.namespace: "quickshell:bar"
                mask: Region {
                    item: content
                }

                anchors {
                    left: true
                    right: true
                    bottom: root.isBottom
                    top: !root.isBottom
                }

                color: "transparent"

                implicitHeight: content.implicitHeight
                implicitWidth: content.implicitWidth

                BackgroundEffect.blurRegion: Region {
                    item: content.nativeBlurActive ? content : null
                }

                WaffleBarContent {
                    id: content

                    nativeBlurAllowed: true

                    // Mascot chaos: her ground slam rattles the taskbar; a kick more so
                    property real _quakeY: 0
                    property real _quakeScale: 1
                    transform: Translate { y: content._quakeY }
                    SequentialAnimation {
                        id: _quakeAnim
                        NumberAnimation { target: content; property: "_quakeY"; to: (root.isBottom ? -7 : 7) * content._quakeScale; duration: 60; easing.type: Easing.OutQuad }
                        NumberAnimation { target: content; property: "_quakeY"; to: (root.isBottom ? 5 : -5) * content._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: content; property: "_quakeY"; to: (root.isBottom ? -3 : 3) * content._quakeScale; duration: 70; easing.type: Easing.InOutQuad }
                        NumberAnimation { target: content; property: "_quakeY"; to: 0; duration: 90; easing.type: Easing.OutBack }
                    }
                    Connections {
                        target: MascotChaos
                        enabled: MascotChaos.enabled
                        function onPanelShake(intensity) {
                            content._quakeScale = Math.max(1, intensity)
                            if (Looks.transition.enabled) _quakeAnim.restart()
                        }
                    }

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: !root.isBottom ? parent.top : undefined
                        bottom: root.isBottom ? parent.bottom : undefined
                    }
                }

                ShellEditSurfaceFrame {
                    anchors.fill: content
                    surfaceId: "waffleBar"
                    label: Translation.tr("Taskbar")
                    active: ShellEditSession.blocksNormalActions(surfaceId)
                    selected: ShellEditSession.selectedSurfaceId === surfaceId
                    lifted: ShellEditSession.liftedSurfaceId === surfaceId
                    slotHint: root.isBottom ? "bottom" : "top"
                    screenWidth: barRoot.screen?.width ?? 0
                    screenHeight: barRoot.screen?.height ?? 0
                    onDragStarted: surface => ShellEditSession.beginDrag(surface)
                    onDragMoved: (surface, screenX, screenY) =>
                        ShellEditSession.updateDrag(screenX, screenY)
                    onDragEnded: () => ShellEditSession.endDrag()
                    onDragCanceled: () => ShellEditSession.cancelDrag()
                    accentColor: Looks.colors.accent
                    surfaceColor: Looks.colors.bg1Base
                    textColor: Looks.colors.fg
                    frameRadius: Looks.radius.medium
                    fontFamily: Looks.font.family.ui
                    fontPixelSize: Looks.font.pixelSize.normal
                    animationDuration: Looks.transition.enabled
                        ? Looks.transition.duration.fast : 0
                    onActivated: selectedId => ShellEditSession.selectSurface(selectedId)
                }
            }
        }
    }

    IpcHandler {
        target: "wbar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }
    // Note: GlobalShortcut removed - use Niri keybinds with IPC instead
}
