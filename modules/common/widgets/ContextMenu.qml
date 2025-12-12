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
            if (CompositorService.isNiri && root.closeOnFocusLost) {
                clickOutsideBackdrop.visible = true;
            }
        }
        Component.onDestruction: {
            clickOutsideBackdrop.visible = false;
        }

        anchor {
            adjustment: PopupAdjustment.ResizeY | PopupAdjustment.SlideX
            item: root.anchorItem
            gravity: root.popupAbove ? Edges.Top : Edges.Bottom
            edges: root.popupAbove ? Edges.Top : Edges.Bottom
        }

        CompositorFocusGrab {
            id: focusGrab
            active: root.closeOnFocusLost && CompositorService.isHyprland
            windows: [popupWindow]
            onCleared: root.focusCleared();
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
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
                to: -implicitHeight
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

        Rectangle {
            id: realContent
            z: 1
            anchors {
                left: parent.left
                right: parent.right
                top: root.popupAbove ? undefined : parent.top
                bottom: root.popupAbove ? parent.bottom : undefined
                margins: root.ambientShadowWidth + root.visualMargin
                bottomMargin: root.popupAbove ? popupWindow.sourceEdgeMargin : (root.ambientShadowWidth + root.visualMargin)
                topMargin: root.popupAbove ? (root.ambientShadowWidth + root.visualMargin) : popupWindow.sourceEdgeMargin
            }
            color: Appearance.colors.colSurfaceContainer
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colSurfaceContainerHighest

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
                                color: Appearance.colors.colOutlineVariant
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
                                buttonRadius: Appearance.rounding.small
                                colBackground: "transparent"
                                colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
                                colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)

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

                                        sourceComponent: menuBtn.modelData.monochromeIcon === false ? iconImageComp : materialIconComp

                                        Component {
                                            id: materialIconComp
                                            MaterialSymbol {
                                                text: menuBtn.modelData.iconName ?? ""
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: Appearance.m3colors.m3onSurface
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
                                        color: Appearance.m3colors.m3onSurface
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
