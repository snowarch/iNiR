pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Loader {
    id: root

    property var model: []
    property Item anchorItem: parent
    property real padding: 4
    property bool noSmoothClosing: false
    property bool closeOnFocusLost: true
    property bool closeOnHoverLost: true
    property bool closeOnHoverLostAfterEntered: false
    property int closeOnHoverLostDelay: 500  // ms before closing when hover lost (waffle uses 500)
    property bool anchorHovered: false
    property bool closeOnOutsideClick: false
    property var anchorRect: null
    property var popupAdjustment: null
    signal focusCleared()

    property real visualMargin: 8
    property bool popupAbove: true  // true = popup appears above anchor, false = below
    property int popupSide: 0  // For horizontal popup: Edges.Left or Edges.Right, 0 = vertical
    property real ambientShadowWidth: 1
    readonly property bool hasIcons: model.some(item => item.iconName !== undefined && item.iconName !== "")

    onFocusCleared: {
        if (!root.closeOnFocusLost) return;
        root.close()
    }

    function grabFocus(): void {
        if (item) item.grabFocus();
    }

    function close(): void {
        if (item) item.close();
        else root.active = false;
    }

    function requestOpen(): void {
        if (GlobalStates.activeContextMenu && GlobalStates.activeContextMenu !== root)
            GlobalStates.activeContextMenu.active = false
        root.active = true
    }

    function updateAnchor(): void {
        item?.anchor.updateAnchor();
    }

    active: false
    visible: active

    onActiveChanged: {
        if (active) {
            GlobalStates.activeContextMenu = root
            GlobalStates.activeContextMenuCount++
        } else {
            if (GlobalStates.activeContextMenu === root)
                GlobalStates.activeContextMenu = null
            GlobalStates.activeContextMenuCount--
        }
    }

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        grabFocus: CompositorService.isNiri
        property bool closing: false
        property bool popupWasHovered: false

        // Keep the Niri click surface below the popup content, matching the
        // SysTrayMenu stacking order so outside clicks close without blocking buttons.
        PanelWindow {
            id: clickOutsideBackdrop
            visible: CompositorService.isNiri && popupWindow.visible
                && (root.closeOnFocusLost || root.closeOnOutsideClick)
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:contextMenuBackdrop"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Component.onCompleted: {
            realContent.shown = true;
            Qt.callLater(() => keyHandler.forceActiveFocus());
            openAnim.start();
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.close();
                    event.accepted = true;
                }
            }
        }

        anchor {
            adjustment: root.popupAdjustment ?? ((root.popupSide !== 0)
                ? (PopupAdjustment.ResizeX | PopupAdjustment.SlideY)
                : (PopupAdjustment.ResizeY | PopupAdjustment.SlideX))
            item: root.anchorItem
            rect.x: Number(root.anchorRect?.x ?? 0)
            rect.y: Number(root.anchorRect?.y ?? 0)
            rect.width: Number(root.anchorRect?.width ?? (root.anchorItem?.width ?? 0))
            rect.height: Number(root.anchorRect?.height ?? (root.anchorItem?.height ?? 0))
            gravity: root.popupSide !== 0 
                ? root.popupSide 
                : (root.popupAbove ? Edges.Top : Edges.Bottom)
            edges: root.popupSide !== 0 
                ? root.popupSide 
                : (root.popupAbove ? Edges.Top : Edges.Bottom)
        }

        CompositorFocusGrab {
            id: focusGrab
            active: root.closeOnFocusLost && CompositorService.isHyprland
            windows: [popupWindow]
            onCleared: root.focusCleared();
        }

        Timer {
            id: closeTimer
            interval: root.closeOnHoverLostDelay
            running: root.closeOnHoverLost
                && popupWindow.visible
                && !popupWindow.popupContainsMouse
                && !root.anchorHovered
                && (!root.closeOnHoverLostAfterEntered || popupWindow.popupWasHovered)
            onTriggered: root.close()
        }

        function close(): void {
            if (root.noSmoothClosing || !Appearance.animationsEnabled) {
                root.active = false;
            } else {
                popupWindow.closing = true;
                realContent.shown = false;
                closeAnim.start();
            }
        }

        function grabFocus(): void {
            focusGrab.active = true;
        }

        implicitWidth: realContent.implicitWidth + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)
        implicitHeight: realContent.implicitHeight + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)
        mask: Region {
            item: realContent
        }

        readonly property real settledMargin: root.ambientShadowWidth + root.visualMargin
        // Cookie fades in at its final geometry. Sliding an overshooting spring
        // inside this fixed PopupWindow clipped the face and temporarily split
        // visual rows from their pointer regions.
        property real sourceEdgeMargin: Appearance.cookieEverywhere
            ? settledMargin : -implicitHeight
        readonly property bool isHorizontalPopup: root.popupSide !== 0
        readonly property bool isLeftSide: root.popupSide === Edges.Left

        PropertyAnimation {
            id: openAnim
            target: popupWindow
            property: "sourceEdgeMargin"
            to: popupWindow.settledMargin
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.motion.popupReveal.enterBezierCurve
        }
        SequentialAnimation {
            id: closeAnim
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: popupWindow.isHorizontalPopup ? -popupWindow.implicitWidth : -popupWindow.implicitHeight
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
            ScriptAction {
                script: root.active = false
            }
        }

        color: "transparent"

        StyledRectangularShadow {
            target: realContent
        }

        GlassBackground {
            id: realContent
            z: 1
            property bool shown: false
            anchors {
                // Vertical popup (above/below)
                left: !popupWindow.isHorizontalPopup ? parent.left : (popupWindow.isLeftSide ? undefined : parent.left)
                right: !popupWindow.isHorizontalPopup ? parent.right : (popupWindow.isLeftSide ? parent.right : undefined)
                top: !popupWindow.isHorizontalPopup ? (root.popupAbove ? undefined : parent.top) : parent.top
                bottom: !popupWindow.isHorizontalPopup ? (root.popupAbove ? parent.bottom : undefined) : parent.bottom

                margins: root.ambientShadowWidth + root.visualMargin
                bottomMargin: !popupWindow.isHorizontalPopup && root.popupAbove ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                topMargin: !popupWindow.isHorizontalPopup && !root.popupAbove ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                leftMargin: popupWindow.isHorizontalPopup && !popupWindow.isLeftSide ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                rightMargin: popupWindow.isHorizontalPopup && popupWindow.isLeftSide ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
            }
            fallbackColor: Appearance.regaliaEverywhere ? "transparent" : Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.popupTransparentize
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                : Appearance.rounding.normal
            border.width: Appearance.regaliaEverywhere ? 0 : 1
            border.color: Appearance.regaliaEverywhere ? "transparent"
                        : Appearance.angelEverywhere ? Appearance.angel.colBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.auroraEverywhere
                            ? Appearance.aurora.colTooltipBorder
                            : Appearance.colors.colSurfaceContainerHighest

            RegaliaPlate {
                anchors.fill: parent
                z: -1
                visible: Appearance.regaliaEverywhere
                fillColor: Appearance.regalia.bg2
                radius: realContent.radius
                inset: Appearance.regalia.surfaceInset
                elevated: true
            }
            opacity: Appearance.motion.popupReveal.enableFade ? (shown ? 1 : 0) : 1
            scale: shown ? 1
                : (Appearance.motion.popupReveal.enableScale
                    ? Appearance.motion.popupReveal.closedScale
                    : 1)
            transformOrigin: popupWindow.isHorizontalPopup
                ? (popupWindow.isLeftSide ? Item.Left : Item.Right)
                : (root.popupAbove ? Item.Bottom : Item.Top)

            implicitWidth: menuColumn.implicitWidth + (root.padding * 2)
            implicitHeight: menuColumn.implicitHeight + (root.padding * 2)

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation {
                    duration: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.duration
                        : Appearance.animation.elementMoveEnter.duration
                    easing.type: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.type
                        : Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.bezierCurve
                        : Appearance.motion.popupReveal.enterBezierCurve
                }
            }

            Behavior on scale {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation {
                    duration: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.duration
                        : Appearance.animation.elementMoveEnter.duration
                    easing.type: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.type
                        : Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: popupWindow.closing
                        ? Appearance.animation.elementMoveExit.bezierCurve
                        : Appearance.motion.popupReveal.enterBezierCurve
                }
            }

            ColumnLayout {
                id: menuColumn
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: root.model
                    delegate: DelegateChooser {
                        role: "type"
                        DelegateChoice {
                            roleValue: "separator"
                            Rectangle {
                                Layout.topMargin: 2
                                Layout.bottomMargin: 2
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
                                    : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                                    : Appearance.colors.colOutlineVariant
                            }
                        }
                        DelegateChoice {
                            roleValue: undefined
                            RippleButton {
                                id: menuBtn
                                Layout.fillWidth: true

                                required property var modelData
                                enabled: modelData.enabled !== false
                                opacity: enabled ? 1 : 0.45
                                buttonHovered: enabled && menuHover.hovered

                                implicitWidth: Math.max(140, menuRow.implicitWidth
                                    + (Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal * 2 : 20))
                                implicitHeight: Appearance.regaliaEverywhere ? Appearance.regalia.compactControlHeight : 32
                                buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
                                    : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                    : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                    : Appearance.rounding.small
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.regaliaEverywhere
                                    ? Appearance.regalia.controlPlateHover
                                    : Appearance.angelEverywhere
                                        ? Appearance.angel.colGlassPopupHover
                                        : Appearance.inirEverywhere
                                            ? Appearance.inir.colLayer2Hover
                                            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                                colRipple: Appearance.regaliaEverywhere
                                    ? Appearance.regalia.controlPlateActive
                                    : Appearance.angelEverywhere
                                        ? Appearance.angel.colGlassPopupActive
                                        : Appearance.inirEverywhere
                                            ? Appearance.inir.colLayer2Active
                                            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)

                                onClicked: {
                                    if (!enabled) return;
                                    // Some actions remove the delegate that owns this menu.
                                    // Close first so the follow-up does not dereference a
                                    // context-menu loader destroyed by its own action.
                                    const action = modelData.action;
                                    root.close();
                                    if (action) action();
                                }

                                HoverHandler {
                                    id: menuHover
                                }

                                contentItem: RowLayout {
                                    id: menuRow
                                    anchors.fill: parent
                                    anchors.leftMargin: Appearance.regaliaEverywhere
                                        ? Appearance.regalia.controlPaddingHorizontal : 8
                                    anchors.rightMargin: anchors.leftMargin
                                    spacing: Appearance.regaliaEverywhere ? Appearance.regalia.controlGap : 8

                                    Loader {
                                        active: root.hasIcons
                                        visible: active
                                        Layout.alignment: Qt.AlignVCenter

                                        sourceComponent: menuBtn.modelData.monochromeIcon === true ? materialIconComp : iconImageComp

                                        Component {
                                            id: materialIconComp
                                            MaterialSymbol {
                                                text: menuBtn.modelData.iconName ?? ""
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                                    : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                                            }
                                        }

                                        Component {
                                            id: iconImageComp
                                            IconImage {
                                                source: Quickshell.iconPath(menuBtn.modelData.iconName ?? "", "application-x-executable")
                                                implicitSize: Appearance.font.pixelSize.normal
                                            }
                                        }
                                    }

                                    StyledText {
                                        text: menuBtn.modelData.text ?? ""
                                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                                            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        HoverHandler {
            id: popupHoverHandler
            onHoveredChanged: if (hovered) popupWindow.popupWasHovered = true
        }
        readonly property bool popupContainsMouse: popupHoverHandler.hovered

    }
}
