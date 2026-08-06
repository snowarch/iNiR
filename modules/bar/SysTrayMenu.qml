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
    property bool closing: false

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
        root.closing = false;
        root.visible = true;
        popupBackground.shown = true;
        root.menuOpened(root);
    }

    function finalizeClose() {
        root.visible = false;
        popupBackground.shown = false;
        root.closing = false;
        while (stackView.depth > 1)
            stackView.pop();
        root.menuClosed();
    }

    function close() {
        if (root.closing) return;
        if (!Appearance.animationsEnabled) {
            finalizeClose();
            return;
        }
        root.closing = true;
        popupBackground.shown = false;
        closeAnimTimer.restart();
    }

    // Fullscreen transparent backdrop for Niri to detect clicks outside
    PanelWindow {
        id: clickOutsideBackdrop
        visible: root.visible && CompositorService.isNiri
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
        interval: 450
        running: root.visible && !hoverHandler.hovered && !root.anchorHovered
        onTriggered: root.close()
    }

    Timer {
        id: closeAnimTimer
        interval: Math.max(Appearance.animation.elementMoveExit.duration, Appearance.animation.elementResize.duration)
        onTriggered: root.finalizeClose()
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
            property bool shown: false
            anchors {
                left: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? undefined : parent.left)
                    : parent.left
                right: (Config.options?.bar?.vertical ?? false)
                    ? ((Config.options?.bar?.bottom ?? false) ? parent.right : undefined)
                    : parent.right
                top: (Config.options?.bar?.vertical ?? false) ? parent.top
                    : (Config.options?.bar?.bottom ?? false) ? undefined : parent.top
                bottom: (Config.options?.bar?.vertical ?? false) ? parent.bottom
                    : (Config.options?.bar?.bottom ?? false) ? parent.bottom : undefined
                margins: root.padding
            }

            color: Appearance.zzzEverywhere ? Appearance.zzz.bg1
                : Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.colors.colLayer0
            radius: Appearance.zzzEverywhere ? Appearance.zzz.cornerRadius
                : Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.windowRounding
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            border.width: Appearance.zzzEverywhere ? 0 : 1
            border.color: Appearance.zzzEverywhere ? "transparent"
                : Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder
                : Appearance.colors.colLayer0Border
            Behavior on border.width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            clip: true
            opacity: Appearance.motion.popupReveal.enableFade ? (shown ? 1 : 0) : 1
            scale: shown ? 1
                : (Appearance.motion.popupReveal.enableScale
                    ? Appearance.motion.popupReveal.closedScale
                    : 1)
            transformOrigin: (Config.options?.bar?.bottom ?? false) ? Item.Bottom : Item.Top
            implicitWidth: stackView.implicitWidth + popupBackground.padding * 2
            implicitHeight: stackView.implicitHeight + popupBackground.padding * 2

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation {
                    duration: root.closing
                        ? Appearance.animation.elementMoveExit.duration
                        : Appearance.animation.elementMoveEnter.duration
                    easing.type: root.closing
                        ? Appearance.animation.elementMoveExit.type
                        : Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: root.closing
                        ? Appearance.animation.elementMoveExit.bezierCurve
                        : Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation {
                    duration: root.closing
                        ? Appearance.animation.elementMoveExit.duration
                        : Appearance.animation.elementMoveEnter.duration
                    easing.type: root.closing
                        ? Appearance.animation.elementMoveExit.type
                        : Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: root.closing
                        ? Appearance.animation.elementMoveExit.bezierCurve
                        : Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on implicitHeight {
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on implicitWidth {
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
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
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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

            // ZZZ: chamfered hairline stroke following the cut-corner outline.
            ZzzPlate {
                anchors.fill: parent
                visible: Appearance.zzzEverywhere
                fillColor: "transparent"
                strokeColor: Appearance.zzz.hairline
                strokeWidth: 1
                chamfer: Appearance.zzz.cutCorner
                chamferBottomRight: !Appearance.zzz.round
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
