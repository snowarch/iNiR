import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PopupWindow {
    id: root
    required property QsMenuHandle trayItemMenuHandle
    property real popupBackgroundMargin: 0
    property bool anchorHovered: false  // Set by parent to indicate if anchor is hovered

    signal menuClosed
    signal menuOpened(qsWindow: var) // Correct type is QsWindow, but QML does not like that

    color: "transparent"
    property real padding: Appearance.sizes.elevationMargin

    implicitHeight: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitHeight, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }
    implicitWidth: {
        let result = 0;
        for (let child of stackView.children) {
            result = Math.max(child.implicitWidth, result);
        }
        return result + popupBackground.padding * 2 + root.padding * 2;
    }

    function open() {
        root.visible = true;
        if (CompositorService.isNiri) clickOutsideBackdrop.visible = true;
        root.menuOpened(root);
    }

    function close() {
        clickOutsideBackdrop.visible = false;
        root.visible = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    // Fullscreen transparent backdrop for Niri to detect clicks outside
    PanelWindow {
        id: clickOutsideBackdrop
        visible: false
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell:trayMenuBackdrop"
        anchors { top: true; bottom: true; left: true; right: true }
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // Close when mouse leaves the popup AND anchor
    HoverHandler {
        id: hoverHandler
    }
    
    Timer {
        id: closeTimer
        interval: 300
        running: root.visible && !hoverHandler.hovered && !root.anchorHovered
        onTriggered: root.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.RightButton
        onPressed: event => {
            if ((event.button === Qt.BackButton || event.button === Qt.RightButton) && stackView.depth > 1)
                stackView.pop();
        }

        StyledRectangularShadow {
            target: popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            readonly property real padding: 3
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: Config.options.bar.vertical ? parent.verticalCenter : undefined
                top: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? undefined : parent.top
                bottom: Config.options.bar.vertical ? undefined : Config.options.bar.bottom ? parent.bottom : undefined
                margins: root.padding
            }

            color: Appearance.inirEverywhere ? Appearance.inir.colLayer1 
                : Appearance.colors.colLayer0
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.windowRounding
            border.width: 1
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder 
                : Appearance.colors.colLayer0Border
            clip: true

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth: stackView.implicitWidth + popupBackground.padding * 2
            implicitHeight: stackView.implicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }
            Behavior on implicitWidth {
                animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
            }

            StackView {
                id: stackView
                anchors {
                    fill: parent
                    margins: popupBackground.padding
                }
                pushEnter: NoAnim {}
                pushExit: NoAnim {}
                popEnter: NoAnim {}
                popExit: NoAnim {}

                implicitWidth: currentItem.implicitWidth
                implicitHeight: currentItem.implicitHeight

                initialItem: SubMenu {
                    handle: root.trayItemMenuHandle
                }
            }
        }
    }

    component NoAnim: Transition {
        NumberAnimation {
            duration: 0
        }
    }

    component SubMenu: ColumnLayout {
        id: submenu
        required property QsMenuHandle handle
        property bool isSubMenu: false
        property bool shown: false
        opacity: shown ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Component.onCompleted: shown = true
        StackView.onActivating: shown = true
        StackView.onDeactivating: shown = false
        StackView.onRemoved: destroy()

        QsMenuOpener {
            id: menuOpener
            menu: submenu.handle
        }

        spacing: 0

        Loader {
            Layout.fillWidth: true
            visible: submenu.isSubMenu
            active: visible
            sourceComponent: RippleButton {
                id: backButton
                buttonRadius: popupBackground.radius - popupBackground.padding
                horizontalPadding: 12
                implicitWidth: contentItem.implicitWidth + horizontalPadding * 2
                implicitHeight: 36

                downAction: () => stackView.pop()

                contentItem: RowLayout {
                    anchors {
                        verticalCenter: parent.verticalCenter
                        left: parent.left
                        right: parent.right
                        leftMargin: backButton.horizontalPadding
                        rightMargin: backButton.horizontalPadding
                    }
                    spacing: 8
                    MaterialSymbol {
                        iconSize: 20
                        text: "chevron_left"
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Back")
                    }
                }
            }
        }

        Repeater {
            id: menuEntriesRepeater
            property bool iconColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].icon.length > 0)
                        return true;
                }
                return false;
            }
            property bool specialInteractionColumnNeeded: {
                for (let i = 0; i < menuOpener.children.values.length; i++) {
                    if (menuOpener.children.values[i].buttonType !== QsMenuButtonType.None)
                        return true;
                }
                return false;
            }
            model: menuOpener.children
            delegate: SysTrayMenuEntry {
                required property QsMenuEntry modelData
                forceIconColumn: menuEntriesRepeater.iconColumnNeeded
                forceSpecialInteractionColumn: menuEntriesRepeater.specialInteractionColumnNeeded
                menuEntry: modelData

                buttonRadius: popupBackground.radius - popupBackground.padding

                onDismiss: root.close()
                onOpenSubmenu: handle => {
                    stackView.push(subMenuComponent.createObject(null, {
                        handle: handle,
                        isSubMenu: true
                    }));
                }
            }
        }
    }

    Component {
        id: subMenuComponent
        SubMenu {}
    }
}
