import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    property bool hoverActivates: true
    property bool closeOnOutsideClick: false
    property bool popupHovered: false
    default property Item contentItem
    property real popupBackgroundMargin: 0

    signal requestClose()

    active: root.hoverActivates && hoverTarget && (hoverTarget.containsMouse ?? hoverTarget.buttonHovered ?? false)
    onActiveChanged: {
        if (!root.active)
            root.popupHovered = false;
    }

    // Fullscreen transparent backdrop for Niri to detect clicks outside
    // (same pattern as ContextMenu / SysTrayMenu)
    PanelWindow {
        id: clickOutsideBackdrop
        visible: root.active && root.closeOnOutsideClick
        color: "#01000000"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:popup-catcher"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.requestClose()
        }
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        HoverHandler {
            id: popupHoverHandler
            onHoveredChanged: root.popupHovered = hovered
        }

        anchors.left: !(Config.options?.bar?.vertical ?? false) || ((Config.options?.bar?.vertical ?? false) && !(Config.options?.bar?.bottom ?? false))
        anchors.right: (Config.options?.bar?.vertical ?? false) && (Config.options?.bar?.bottom ?? false)
        anchors.top: (Config.options?.bar?.vertical ?? false) || (!(Config.options?.bar?.vertical ?? false) && !(Config.options?.bar?.bottom ?? false))
        anchors.bottom: !(Config.options?.bar?.vertical ?? false) && (Config.options?.bar?.bottom ?? false)

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!(Config.options?.bar?.vertical ?? false) && root.QsWindow && root.hoverTarget && root.hoverTarget.width > 0) {
                    return root.QsWindow.mapFromItem(
                        root.hoverTarget,
                        (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
                    ).x;
                }
                return Appearance.sizes.verticalBarWidth
            }
            top: {
                if (!(Config.options?.bar?.vertical ?? false)) return Appearance.sizes.barHeight;
                if (root.QsWindow && root.hoverTarget && root.hoverTarget.height > 0) {
                    return root.QsWindow.mapFromItem(
                        root.hoverTarget,
                        0, (root.hoverTarget.height - popupBackground.implicitHeight) / 2
                    ).y;
                }
                return Appearance.sizes.barHeight;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10

            property bool _shown: false
            Component.onCompleted: _shown = true

            opacity: _shown ? 1 : 0
            scale: _shown ? 1.0 : 0.88
            transformOrigin: (Config.options?.bar?.bottom ?? false) ? Item.Bottom : Item.Top

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                : Appearance.m3colors.m3surfaceContainer
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.small
            children: [root.contentItem]

            border.width: 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder 
                : Appearance.colors.colLayer0Border
        }

        
    }
}
