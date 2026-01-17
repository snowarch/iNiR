pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
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
    property bool anchorHovered: false
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

    function updateAnchor(): void {
        item?.anchor.updateAnchor();
    }

    active: false
    visible: active

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true

        Component.onCompleted: {
            openAnim.start();
            Qt.callLater(() => keyHandler.forceActiveFocus());
            if (CompositorService.isNiri && root.closeOnFocusLost) {
                clickOutsideBackdrop.visible = true;
            }
        }
        Component.onDestruction: {
            clickOutsideBackdrop.visible = false;
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
            adjustment: (root.popupSide !== 0) 
                ? (PopupAdjustment.ResizeX | PopupAdjustment.SlideY)
                : (PopupAdjustment.ResizeY | PopupAdjustment.SlideX)
            item: root.anchorItem
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
            interval: 300
            running: root.closeOnHoverLost && popupWindow.visible && !popupWindow.popupContainsMouse && !root.anchorHovered
            onTriggered: root.close()
        }

        function close(): void {
            clickOutsideBackdrop.visible = false;
            if (root.noSmoothClosing) root.active = false;
            else closeAnim.start();
        }

        function grabFocus(): void {
            focusGrab.active = true;
        }

        implicitWidth: realContent.implicitWidth + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)
        implicitHeight: realContent.implicitHeight + (root.ambientShadowWidth * 2) + (root.visualMargin * 2)

        property real sourceEdgeMargin: -implicitHeight
        readonly property bool isHorizontalPopup: root.popupSide !== 0
        readonly property bool isLeftSide: root.popupSide === Edges.Left
        
        PropertyAnimation {
            id: openAnim
            target: popupWindow
            property: "sourceEdgeMargin"
            to: (root.ambientShadowWidth + root.visualMargin)
            duration: 200
            easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            id: closeAnim
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: popupWindow.isHorizontalPopup ? -popupWindow.implicitWidth : -popupWindow.implicitHeight
                duration: 150
                easing.type: Easing.InCubic
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
            fallbackColor: Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.popupTransparentize
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.auroraEverywhere 
                            ? Appearance.aurora.colTooltipBorder
                            : Appearance.colors.colSurfaceContainerHighest

            implicitWidth: menuColumn.implicitWidth + (root.padding * 2)
            implicitHeight: menuColumn.implicitHeight + (root.padding * 2)

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
                                color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : Appearance.colors.colOutlineVariant
                            }
                        }
                        DelegateChoice {
                            roleValue: undefined
                            RippleButton {
                                id: menuBtn
                                Layout.fillWidth: true

                                required property var modelData

                                implicitWidth: Math.max(140, menuRow.implicitWidth + 20)
                                implicitHeight: 32
                                buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.inirEverywhere 
                                    ? Appearance.inir.colLayer2Hover
                                    : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                                colRipple: Appearance.inirEverywhere
                                    ? Appearance.inir.colLayer2Active
                                    : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)

                                onClicked: {
                                    if (modelData.action) modelData.action();
                                    root.close();
                                }

                                contentItem: RowLayout {
                                    id: menuRow
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

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
                                                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
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
                                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
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
        }
        readonly property bool popupContainsMouse: popupHoverHandler.hovered

        PanelWindow {
            id: clickOutsideBackdrop
            visible: false
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:contextMenu"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
                onPressed: event => {
                    root.close()
                    event.accepted = true
                }
            }
        }
    }
}
