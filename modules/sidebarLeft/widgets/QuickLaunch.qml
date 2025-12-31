pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    implicitHeight: row.implicitHeight

    readonly property var defaultShortcuts: [
        { icon: "folder", name: "Files", cmd: "/usr/bin/nautilus" },
        { icon: "terminal", name: "Terminal", cmd: "/usr/bin/kitty" },
        { icon: "web", name: "Browser", cmd: "/usr/bin/firefox" },
        { icon: "code", name: "Code", cmd: "/usr/bin/code" }
    ]

    property var shortcuts: Config.options?.sidebar?.widgets?.quickLaunch ?? defaultShortcuts

    // Currently editing shortcut index
    property int editingIndex: -1

    // Check if app is running by looking at windows
    function isAppRunning(cmd) {
        if (!cmd) return false
        const appName = cmd.split("/").pop().toLowerCase()
        return NiriService.windows.some(w => 
            w.app_id?.toLowerCase().includes(appName) ||
            w.title?.toLowerCase().includes(appName)
        )
    }

    function saveShortcuts(newShortcuts) {
        Config.setNestedValue("sidebar.widgets.quickLaunch", newShortcuts)
    }

    function removeShortcut(index) {
        const newShortcuts = [...shortcuts]
        newShortcuts.splice(index, 1)
        saveShortcuts(newShortcuts)
    }

    function moveShortcut(fromIndex, direction) {
        const toIndex = fromIndex + direction
        if (toIndex < 0 || toIndex >= shortcuts.length) return
        const newShortcuts = [...shortcuts]
        const item = newShortcuts.splice(fromIndex, 1)[0]
        newShortcuts.splice(toIndex, 0, item)
        saveShortcuts(newShortcuts)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 0

        Item { Layout.fillWidth: true }

        Repeater {
            model: root.shortcuts

            Item {
                implicitWidth: 52
                implicitHeight: 56

                RippleButton {
                    id: launchBtn
                    property var modelData: parent.modelData
                    property int index: parent.index

                    readonly property bool isRunning: root.isAppRunning(modelData.cmd)

                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: 48; implicitHeight: 48
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: Appearance.inirEverywhere 
                        ? "transparent" 
                        : (isRunning ? Appearance.colors.colPrimaryContainer : "transparent")
                    colBackgroundHover: Appearance.inirEverywhere 
                        ? Appearance.inir.colLayer1Hover 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : (isRunning ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover)
                    colRipple: Appearance.inirEverywhere 
                        ? Appearance.inir.colLayer1Active 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                        : (isRunning ? Appearance.colors.colPrimaryContainerActive : Appearance.colors.colLayer1Active)
                    
                    onClicked: {
                        if (!modelData.cmd) return
                        const parts = modelData.cmd.split(" ")
                        Quickshell.execDetached(parts)
                    }

                    altAction: () => {
                        root.editingIndex = launchBtn.index
                        contextMenu.active = true
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: modelData.icon ?? "apps"
                            iconSize: 24
                            color: Appearance.inirEverywhere 
                                ? (launchBtn.isRunning ? Appearance.inir.colPrimary : Appearance.inir.colText) 
                                : (launchBtn.isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0)

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }
                        }
                    }

                    StyledToolTip { text: modelData.name ?? modelData.cmd?.split("/").pop() ?? "" }
                }

                // Running indicator - centered below button
                Rectangle {
                    anchors.top: launchBtn.bottom
                    anchors.topMargin: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Appearance.inirEverywhere ? 12 : 6
                    height: Appearance.inirEverywhere ? 2 : 6
                    radius: Appearance.inirEverywhere ? 1 : 3
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    scale: launchBtn.isRunning ? 1 : 0
                    opacity: launchBtn.isRunning ? 1 : 0

                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { 
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutBack
                        }
                    }
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }

                required property var modelData
                required property int index

                ContextMenu {
                    id: contextMenu
                    anchorItem: launchBtn
                    popupAbove: true
                    model: [
                        { 
                            text: Translation.tr("Move left"), 
                            iconName: "arrow_back",
                            action: () => root.moveShortcut(launchBtn.index, -1)
                        },
                        { 
                            text: Translation.tr("Move right"), 
                            iconName: "arrow_forward",
                            action: () => root.moveShortcut(launchBtn.index, 1)
                        },
                        { type: "separator" },
                        { 
                            text: Translation.tr("Remove"), 
                            iconName: "delete",
                            action: () => root.removeShortcut(launchBtn.index)
                        }
                    ]
                }
            }
        }

        Item { Layout.fillWidth: true }
    }
}
