pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.iris.field
import qs.modules.iris.style

Scope {
    id: root

    // The lock surface cannot be edited while it is locking the session, so the
    // rehearsal instantiates the same surface with a context that never asks PAM.
    component RehearsalContext: QtObject {
        signal shouldReFocus()
        signal unlocked(targetAction: var)
        signal failed()
        property string currentText: ""
        property bool unlockInProgress: false
        property bool showFailure: false
        property bool fingerprintsConfigured: false
        function clearText(): void { currentText = "" }
        function resetClearTimer(): void {}
        function tryUnlock(): void {}
    }

    RehearsalContext { id: rehearsalContext }

    Variants {
        model: Quickshell.screens.filter(screen => (screen?.name ?? "")
            === (GlobalStates.focusedScreen?.name ?? Quickshell.screens[0]?.name ?? ""))

        PanelWindow {
            id: window
            required property var modelData
            screen: window.modelData
            visible: true
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:iris-lock-rehearsal"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            anchors { left: true; right: true; top: true; bottom: true }

            Shortcut {
                sequence: "Escape"
                onActivated: {
                    if (GlobalStates.irisLockSelection.length > 0) GlobalStates.irisLockSelection = ""
                    else GlobalStates.irisLockEdit = false
                }
            }

            IrisField {
                anchors.fill: parent
                shapes: inspector.fieldShapes
                opacity: inspector.peeking ? 0 : 1
                visible: opacity > 0.01
                z: 1
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
            }

            IrisLockSurface {
                id: surface
                anchors.fill: parent
                context: rehearsalContext
                editing: true
            }

            IrisLockInspector {
                id: inspector
                z: 2
                anchors.fill: parent
                screenName: window.modelData?.name ?? ""
                widget: surface.selectedWidget
                avoid: surface.selectedRect
            }
            Binding {
                target: surface
                property: "peeking"
                value: inspector.peeking
            }
        }
    }
}
