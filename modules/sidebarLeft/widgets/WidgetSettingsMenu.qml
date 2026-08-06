pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Loader {
    id: root
    
    property Item anchorItem: parent
    property real visualMargin: 8
    
    function toggle() {
        active = !active
    }
    
    function close() {
        if (item && typeof item.close === "function") item.close()
        else active = false
    }

    active: false
    visible: active

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        property bool closing: false
        
        anchor.item: root.anchorItem
        anchor.gravity: Edges.Bottom
        anchor.edges: Edges.Top
        anchor.adjustment: PopupAdjustment.SlideY | PopupAdjustment.SlideX

        function close(): void {
            if (!Appearance.animationsEnabled) {
                root.active = false
                return
            }
            if (closing) return
            closing = true
            background.shown = false
            closeAnim.start()
        }

        // Close on escape
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }
            Component.onCompleted: forceActiveFocus()
        }

        // Close on click outside (Backdrop)
        PanelWindow {
            visible: true
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:widgetSettings"
            
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: (event) => {
                    root.close()
                    event.accepted = true
                }
            }
        }

        // Animation logic
        property real sourceEdgeMargin: -implicitHeight

        SequentialAnimation {
            id: openAnim
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: root.visualMargin
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        SequentialAnimation {
            id: closeAnim
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: -popupWindow.implicitHeight
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
            ScriptAction {
                script: root.active = false
            }
        }

        Component.onCompleted: {
            background.shown = true
            Qt.callLater(() => forceScope.forceActiveFocus())
            openAnim.start()
        }

        GlassBackground {
            id: background
            property bool shown: false
            anchors.top: parent.top
            anchors.topMargin: popupWindow.sourceEdgeMargin
            anchors.right: parent.right // Align right with the button usually
            
            implicitWidth: 220
            implicitHeight: contentCol.implicitHeight + 24

            fallbackColor: Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.popupTransparentize
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colOutlineVariant
            opacity: Appearance.motion.popupReveal.enableFade ? (shown ? 1 : 0) : 1
            scale: shown ? 1
                : (Appearance.motion.popupReveal.enableScale
                    ? Appearance.motion.popupReveal.closedScale
                    : 1)
            transformOrigin: Item.TopRight

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
                        : Appearance.animation.elementMoveEnter.bezierCurve
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
                        : Appearance.animation.elementMoveEnter.bezierCurve
                }
            }

            StyledRectangularShadow {
                anchors.fill: parent
                color: "black"
                opacity: 0.3
                radius: background.radius
                blur: 16
            }

            ColumnLayout {
                id: contentCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                StyledText {
                    text: Translation.tr("Widget Visibility")
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                    Layout.bottomMargin: 4
                }

                // Helper component for uniform switches
                component WidgetSwitch : ConfigSwitch {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                WidgetSwitch {
                    text: Translation.tr("Media Player")
                    buttonIcon: "music_note"
                    checked: Config.options?.sidebar?.widgets?.media ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.media", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Week Calendar")
                    buttonIcon: "calendar_view_week"
                    checked: Config.options?.sidebar?.widgets?.week ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.week", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Context Info")
                    buttonIcon: "info"
                    checked: Config.options?.sidebar?.widgets?.context ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.context", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Quick Note")
                    buttonIcon: "edit_note"
                    checked: Config.options?.sidebar?.widgets?.note ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.note", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Launcher")
                    buttonIcon: "rocket_launch"
                    checked: Config.options?.sidebar?.widgets?.launch ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.launch", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("System Controls")
                    buttonIcon: "toggle_on"
                    checked: Config.options?.sidebar?.widgets?.controls ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.controls", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Status Rings")
                    buttonIcon: "data_usage"
                    checked: Config.options?.sidebar?.widgets?.status ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.status", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Crypto Ticker")
                    buttonIcon: "currency_bitcoin"
                    checked: Config.options?.sidebar?.widgets?.crypto ?? false
                    onClicked: Config.setNestedValue("sidebar.widgets.crypto", checked)
                }
                
                WidgetSwitch {
                    text: Translation.tr("Wallpaper")
                    buttonIcon: "wallpaper"
                    checked: Config.options?.sidebar?.widgets?.wallpaper ?? false
                    onClicked: Config.setNestedValue("sidebar.widgets.wallpaper", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("World Clock")
                    buttonIcon: "public"
                    checked: Config.options?.sidebar?.widgets?.worldClock ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.worldClock", checked)
                }
            }
        }

        Item {
            id: forceScope
            anchors.fill: parent
            focus: true
        }
    }
}
