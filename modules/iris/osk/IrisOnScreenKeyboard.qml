pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.onScreenKeyboard
import qs.modules.iris.frame
import qs.modules.iris.style
import qs.modules.iris.field as Field
import qs.modules.iris.components

// Material's on-screen keyboard (`onScreenKeyboard/OnScreenKeyboard.qml`) with the same behaviour and iRiS's look:
// the keys and layouts are the shared ones, the body is a floating iRiS surface.
Scope {
    id: root
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false
    property bool keepOnTop: Config.options?.osk?.keepOnTop ?? false
    property bool presentationVisible: true
    readonly property real d: IrisStyle.density
    readonly property real pad: Math.round(10 * root.d)
    readonly property var screen: outputHold.output

    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.presentationVisible
    }

    // Whenever one of these toggles the window re-stacks itself on top of its layer.
    readonly property int _competingStackToken:
          (GlobalStates.overviewOpen          ? (1 <<  0) : 0)
        + (GlobalStates.overlayOpen           ? (1 <<  1) : 0)
        + (GlobalStates.sidebarLeftOpen       ? (1 <<  2) : 0)
        + (GlobalStates.sidebarRightOpen      ? (1 <<  3) : 0)
        + (GlobalStates.settingsOverlayOpen   ? (1 <<  4) : 0)
        + (GlobalStates.clipboardOpen         ? (1 <<  5) : 0)
        + (GlobalStates.wallpaperSelectorOpen ? (1 <<  8) : 0)
        + (GlobalStates.coverflowSelectorOpen ? (1 <<  9) : 0)
        + (GlobalStates.cheatsheetOpen        ? (1 << 10) : 0)
        + (GlobalStates.regionSelectorOpen    ? (1 << 12) : 0)
        + (GlobalStates.sessionOpen           ? (1 << 13) : 0)
        + (GlobalStates.searchOpen            ? (1 << 14) : 0)
        + (GlobalStates.irisOrbitOpen         ? (1 << 15) : 0)

    PanelWindow {
        id: oskWindow
        // A brief unmap recreates the layer surface, which puts it back on top of the Overlay layer.
        property bool remapping: false
        visible: root.presentationVisible && !GlobalStates.screenLocked && !oskWindow.remapping
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:iris-osk"
        anchors { top: true; bottom: true; left: true; right: true }
        mask: Region { item: body }

        function restack(): void {
            if (!root.keepOnTop || !oskWindow.visible || GlobalStates.screenLocked) return
            oskWindow.remapping = true
            restackTimer.restart()
        }
        Timer { id: restackTimer; interval: 40; onTriggered: oskWindow.remapping = false }
        readonly property int competingToken: root._competingStackToken
        onCompetingTokenChanged: oskWindow.restack()

        function hide(): void { GlobalStates.oskOpen = false }

        // Left third, centre or right third; top or bottom, clear of the Island and the Dock.
        function snapToNearestEdge(): void {
            const gap = Math.round(14 * root.d)
            const cx = body.x + body.width / 2
            const cy = body.y + body.height / 2
            body.animatePosition = true
            body.x = cx < oskWindow.width / 3 ? gap + IrisFrame.safeClear("left")
                : cx > oskWindow.width * 2 / 3 ? oskWindow.width - body.width - gap - IrisFrame.safeClear("right")
                : Math.round((oskWindow.width - body.width) / 2)
            body.y = cy < oskWindow.height / 2 ? gap + IrisFrame.safeClear("top")
                : oskWindow.height - body.height - gap - IrisFrame.safeClear("bottom")
        }

        Field.IrisBlurRegion {
            window: oskWindow
            shapes: body.blurShapes
            windowWidth: oskWindow.width
            windowHeight: oskWindow.height
        }

        RectangularShadow {
            readonly property var rect: body.bodyRect
            x: rect.x
            y: rect.y + 6 * root.d * body.progress
            width: rect.width
            height: rect.height
            radius: rect.radius
            blur: 30 * root.d
            spread: -6 * root.d
            color: IrisStyle.shadow
            opacity: IrisStyle.shadowAt(body.progress)
        }

        IrisMorphSurface {
            id: body
            property bool animatePosition: false
            compositorBlurred: true
            open: GlobalStates.oskOpen
            motionSurface: "panels"
            settles: true
            ownField: true
            windowOffset: Qt.point(0, 0)
            color: IrisStyle.surface
            light: IrisStyle.surfaceLight("panels", IrisStyle.wallpaperLight)
            lightFrom: "bottom"
            radius: IrisStyle.surfaceRadius("panels", IrisStyle.radiusSheet)
            width: Math.round(board.implicitWidth + 2 * root.pad)
            height: Math.round(board.implicitHeight + 2 * root.pad)
            // Bottom centre until the first drag takes the position.
            x: Math.round((oskWindow.width - width) / 2)
            y: Math.round(oskWindow.height - height - 14 * root.d - IrisFrame.safeClear("bottom"))
            onClosed: if (!body.open) root.presentationVisible = false

            Behavior on x {
                enabled: body.animatePosition && IrisStyle.motionEnabled
                NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
            }
            Behavior on y {
                enabled: body.animatePosition && IrisStyle.motionEnabled
                NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve }
            }

            RowLayout {
                id: board
                x: root.pad
                y: root.pad
                spacing: Math.round(8 * root.d)

                // The controls are one group, a fill: pin, keep on top, close, and the handle to drag it by.
                Rectangle {
                    Layout.fillHeight: true
                    implicitWidth: rail.implicitWidth + 2 * Math.round(4 * root.d)
                    radius: IrisStyle.radiusTile
                    color: IrisStyle.fillQuiet

                    ColumnLayout {
                        id: rail
                        anchors.fill: parent
                        anchors.margins: Math.round(4 * root.d)
                        spacing: Math.round(2 * root.d)

                        IrisIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            materialIcon: root.pinned ? "lock" : "keep"
                            selected: root.pinned
                            downAction: () => root.pinned = !root.pinned
                        }
                        IrisIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            materialIcon: "flip_to_front"
                            selected: root.keepOnTop
                            downAction: () => Config.setNestedValue("osk.keepOnTop", !root.keepOnTop)
                        }
                        IrisIconButton {
                            Layout.alignment: Qt.AlignHCenter
                            materialIcon: "keyboard_hide"
                            onClicked: oskWindow.hide()
                        }

                        Item {
                            id: grip
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: Math.round(30 * root.d)
                            opacity: root.pinned ? 0.25 : 0.6
                            Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "drag_indicator"
                                iconSize: Math.round(18 * root.d)
                                color: IrisStyle.text
                            }

                            DragHandler {
                                enabled: !root.pinned
                                target: body
                                xAxis.minimum: 0
                                xAxis.maximum: oskWindow.width - body.width
                                yAxis.minimum: 0
                                yAxis.maximum: oskWindow.height - body.height
                                onActiveChanged: {
                                    if (active) body.animatePosition = false
                                    else oskWindow.snapToNearestEdge()
                                }
                            }
                        }
                    }
                }

                OskContent {
                    keySpacing: Math.round(4 * root.d)
                    keyComponent: Component {
                        IrisOskKey {
                            required property var modelData
                            keyData: modelData
                        }
                    }
                }
            }
        }
    }
}
