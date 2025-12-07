import qs
import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root
    property bool vertical: false
    property bool borderless: Config.options?.bar?.borderless ?? false
    readonly property HyprlandMonitor monitor: CompositorService.isHyprland ? Hyprland.monitorFor(root.QsWindow.window?.screen) : null
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property var wsConfig: Config.options?.bar.workspaces ?? {}
    
    readonly property int currentWorkspaceNumber: CompositorService.isNiri
            ? NiriService.getCurrentWorkspaceNumber()
            : (monitor?.activeWorkspace?.id || 1)
    readonly property int workspacesShown: wsConfig.shown ?? 10
    readonly property int workspaceGroup: Math.floor((currentWorkspaceNumber - 1) / root.workspacesShown)
    property list<bool> workspaceOccupied: []
    property int widgetPadding: 4
    property int workspaceButtonWidth: 26
    property real activeWorkspaceMargin: 2
    property real workspaceIconSize: workspaceButtonWidth * 0.69
    property real workspaceIconSizeShrinked: workspaceButtonWidth * 0.55
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: (currentWorkspaceNumber - 1) % root.workspacesShown

    property bool showNumbers: false
    Timer {
        id: showNumbersTimer
        interval: (Config?.options.bar.autoHide.showWhenPressingSuper.delay ?? 100)
        repeat: false
        onTriggered: {
            root.showNumbers = true
        }
    }
    Connections {
        target: GlobalStates
        function onSuperDownChanged() {
            if (!Config?.options.bar.autoHide.showWhenPressingSuper.enable) return;
            if (GlobalStates.superDown) showNumbersTimer.restart();
            else {
                showNumbersTimer.stop();
                root.showNumbers = false;
            }
        }
        function onSuperReleaseMightTriggerChanged() { 
            showNumbersTimer.stop()
        }
    }

    Timer {
        id: updateWorkspaceOccupiedTimer
        interval: 16
        repeat: false
        onTriggered: doUpdateWorkspaceOccupied()
    }

    function updateWorkspaceOccupied() {
        updateWorkspaceOccupiedTimer.restart()
    }

    function doUpdateWorkspaceOccupied() {
        if (CompositorService.isNiri) {
            const wsList = NiriService.currentOutputWorkspaces || []
            const windows = NiriService.windows || []
            const base = workspaceGroup * root.workspacesShown
            workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
                const targetNumber = base + i + 1
                // Find workspace with this idx
                const ws = wsList.find(w => w.idx === targetNumber)
                if (!ws) return false
                // Check if any windows are on this workspace
                return windows.some(win => win.workspace_id === ws.id)
            })
        } else {
            workspaceOccupied = Array.from({ length: root.workspacesShown }, (_, i) => {
                return Hyprland.workspaces.values.some(ws => ws.id === workspaceGroup * root.workspacesShown + i + 1);
            })
        }
    }

    // Occupied workspace updates
    Component.onCompleted: doUpdateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            if (CompositorService.isHyprland)
                updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            if (CompositorService.isHyprland)
                updateWorkspaceOccupied();
        }
    }
    Connections {
        target: NiriService
        enabled: CompositorService.isNiri
        function onAllWorkspacesChanged() {
            updateWorkspaceOccupied();
        }
        function onCurrentOutputWorkspacesChanged() {
            updateWorkspaceOccupied();
        }
        function onWindowsChanged() {
            updateWorkspaceOccupied();
        }
    }
    onWorkspaceGroupChanged: {
        updateWorkspaceOccupied();
    }

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : (root.workspaceButtonWidth * root.workspacesShown)
    implicitHeight: root.vertical ? (root.workspaceButtonWidth * root.workspacesShown) : Appearance.sizes.barHeight

    // Scroll behavior: "workspace" = switch workspaces, "column" = cycle windows left/right in same workspace
    readonly property string scrollBehavior: wsConfig.scrollBehavior ?? "workspace"

    // Scroll to switch workspaces or cycle columns - uses horizontal scroll direction for Niri's scrolling model
    WheelHandler {
        onWheel: (event) => {
            // Use horizontal delta if available (touchpad horizontal scroll), otherwise use vertical
            const deltaX = event.angleDelta.x
            const deltaY = event.angleDelta.y
            
            // Prefer horizontal scroll for natural left/right navigation
            // Fall back to vertical scroll (inverted: scroll up = left, scroll down = right)
            const delta = deltaX !== 0 ? deltaX : -deltaY
            if (delta === 0)
                return
            
            // Positive delta = scroll right = next
            // Negative delta = scroll left = previous
            const direction = delta > 0 ? 1 : -1

            if (CompositorService.isNiri) {
                if (root.scrollBehavior === "column") {
                    // Cycle through columns (windows side by side) in the same workspace
                    if (direction > 0) {
                        NiriService.focusColumnRight()
                    } else {
                        NiriService.focusColumnLeft()
                    }
                } else {
                    // Default: switch workspaces
                    // Niri uses Up/Down for workspace navigation (vertical scrolling model)
                    if (direction > 0) {
                        NiriService.focusWorkspaceDown()  // Next workspace
                    } else {
                        NiriService.focusWorkspaceUp()    // Previous workspace
                    }
                }
            } else if (CompositorService.isHyprland) {
                if (direction > 0)
                    Hyprland.dispatch(`workspace r+1`);
                else
                    Hyprland.dispatch(`workspace r-1`);
            }
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        enabled: CompositorService.isHyprland // Niri doesn't have special workspaces
        onPressed: (event) => {
            if (event.button === Qt.BackButton) {
                Hyprland.dispatch(`togglespecialworkspace`);
            } 
        }
    }

    // Workspaces - background
    Grid {
        z: 1
        anchors.centerIn: parent

        rowSpacing: 0
        columnSpacing: 0
        columns: root.vertical ? 1 : root.workspacesShown
        rows: root.vertical ? root.workspacesShown : 1

        Repeater {
            model: root.workspacesShown

            Rectangle {
                z: 1
                implicitWidth: workspaceButtonWidth
                implicitHeight: workspaceButtonWidth
                radius: (width / 2)
                property var previousOccupied: (workspaceOccupied[index-1] && !(!activeWindow?.activated && currentWorkspaceNumber === index))
                property var rightOccupied: (workspaceOccupied[index+1] && !(!activeWindow?.activated && currentWorkspaceNumber === index+2))
                property var radiusPrev: previousOccupied ? 0 : (width / 2)
                property var radiusNext: rightOccupied ? 0 : (width / 2)

                topLeftRadius: radiusPrev
                bottomLeftRadius: root.vertical ? radiusNext : radiusPrev
                topRightRadius: root.vertical ? radiusPrev : radiusNext
                bottomRightRadius: radiusNext
                
                color: ColorUtils.transparentize(Appearance.m3colors.m3secondaryContainer, 0.4)
                opacity: (workspaceOccupied[index] && !(!activeWindow?.activated && currentWorkspaceNumber === index+1)) ? 1 : 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on radiusPrev {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Behavior on radiusNext {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

            }

        }

    }

    // Active workspace
    Rectangle {
        z: 2
        // Make active ws indicator, which has a brighter color, smaller to look like it is of the same size as ws occupied highlight
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary

        anchors {
            verticalCenter: vertical ? undefined : parent.verticalCenter
            horizontalCenter: vertical ? parent.horizontalCenter : undefined
        }

        AnimatedTabIndexPair {
            id: idxPair
            index: root.workspaceIndexInGroup
        }
        property real indicatorPosition: Math.min(idxPair.idx1, idxPair.idx2) * workspaceButtonWidth + root.activeWorkspaceMargin
        property real indicatorLength: Math.abs(idxPair.idx1 - idxPair.idx2) * workspaceButtonWidth + workspaceButtonWidth - root.activeWorkspaceMargin * 2
        property real indicatorThickness: workspaceButtonWidth - root.activeWorkspaceMargin * 2

        x: root.vertical ? null : indicatorPosition
        implicitWidth: root.vertical ? indicatorThickness : indicatorLength
        y: root.vertical ? indicatorPosition : null
        implicitHeight: root.vertical ? indicatorLength : indicatorThickness

    }

    // Workspaces - numbers
    Grid {
        z: 3

        columns: root.vertical ? 1 : root.workspacesShown
        rows: root.vertical ? root.workspacesShown : 1
        columnSpacing: 0
        rowSpacing: 0

        anchors.fill: parent

        Repeater {
            model: root.workspacesShown

            Button {
                id: button
                property int workspaceValue: workspaceGroup * root.workspacesShown + index + 1
                implicitHeight: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.barHeight
                implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth
                onPressed: {
                    if (CompositorService.isNiri) {
                        // workspaceValue is a 1-based logical slot; pass it directly as Niri idx.
                        NiriService.switchToWorkspace(workspaceValue)
                    } else if (CompositorService.isHyprland) {
                        Hyprland.dispatch(`workspace ${workspaceValue}`)
                    }
                }
                width: vertical ? undefined : workspaceButtonWidth
                height: vertical ? workspaceButtonWidth : undefined

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    readonly property var niriWorkspace: CompositorService.isNiri 
                        ? NiriService.allWorkspaces.find(w => w.idx === button.workspaceValue) 
                        : null
                    property var biggestWindow: {
                        if (CompositorService.isNiri) {
                            if (!niriWorkspace) return null
                            const wins = NiriService.windows.filter(w => w.workspace_id === niriWorkspace.id)
                            if (wins.length === 0) return null
                            return wins.find(w => w.is_focused) || wins[0]
                        } else {
                            return HyprlandData.biggestWindowForWorkspace(button.workspaceValue)
                        }
                    }
                    property var mainAppIconSource: {
                        const appClass = CompositorService.isNiri 
                            ? (biggestWindow?.app_id || biggestWindow?.appId) 
                            : biggestWindow?.class
                        return Quickshell.iconPath(AppSearch.guessIcon(appClass), "image-missing")
                    }

                    StyledText { // Workspace number text
                        opacity: root.showNumbers
                            || ((wsConfig.alwaysShowNumbers && (!wsConfig.showAppIcons || !workspaceButtonBackground.biggestWindow || root.showNumbers))
                            || (root.showNumbers && !wsConfig.showAppIcons)
                            )  ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font {
                            pixelSize: Appearance.font.pixelSize.small - ((text.length - 1) * (text !== "10") * 2)
                            family: wsConfig.useNerdFont ? Appearance.font.family.iconNerd : defaultFont
                        }
                        text: wsConfig.numberMap?.[button.workspaceValue - 1] || button.workspaceValue
                        elide: Text.ElideRight
                        color: (currentWorkspaceNumber == button.workspaceValue) ? 
                            Appearance.m3colors.m3onPrimary : 
                            (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : 
                                Appearance.colors.colOnLayer1Inactive)

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    Rectangle { // Dot instead of ws number
                        id: wsDot
                        opacity: (wsConfig.alwaysShowNumbers
                            || root.showNumbers
                            || (wsConfig.showAppIcons && workspaceButtonBackground.biggestWindow)
                            ) ? 0 : 1
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.18
                        height: width
                        radius: width / 2
                        color: (currentWorkspaceNumber == button.workspaceValue) ? 
                            Appearance.m3colors.m3onPrimary : 
                            (workspaceOccupied[index] ? Appearance.m3colors.m3onSecondaryContainer : 
                                Appearance.colors.colOnLayer1Inactive)

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }
                    Item { // Main app icon
                        anchors.centerIn: parent
                        width: workspaceButtonWidth
                        height: workspaceButtonWidth
                        opacity: !wsConfig.showAppIcons ? 0 :
                            (workspaceButtonBackground.biggestWindow && !root.showNumbers && wsConfig.showAppIcons) ? 
                            1 : workspaceButtonBackground.biggestWindow ? workspaceIconOpacityShrinked : 0
                            visible: opacity > 0
                        IconImage {
                            id: mainAppIcon
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.bottomMargin: (!root.showNumbers && wsConfig.showAppIcons) ? 
                                (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked
                            anchors.rightMargin: (!root.showNumbers && wsConfig.showAppIcons) ? 
                                (workspaceButtonWidth - workspaceIconSize) / 2 : workspaceIconMarginShrinked

                            source: workspaceButtonBackground.mainAppIconSource
                            implicitSize: (!root.showNumbers && wsConfig.showAppIcons) ? workspaceIconSize : workspaceIconSizeShrinked

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on anchors.bottomMargin {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on anchors.rightMargin {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                            Behavior on implicitSize {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }
                        }

                        Loader {
                            active: wsConfig.monochromeIcons
                            anchors.fill: mainAppIcon
                            sourceComponent: Item {
                                Desaturate {
                                    id: desaturatedIcon
                                    visible: false // There's already color overlay
                                    anchors.fill: parent
                                    source: mainAppIcon
                                    desaturation: 0.8
                                }
                                ColorOverlay {
                                    anchors.fill: desaturatedIcon
                                    source: desaturatedIcon
                                    color: ColorUtils.transparentize(wsDot.color, 0.9)
                                }
                            }
                        }
                    }
                }
                

            }

        }

    }

}
