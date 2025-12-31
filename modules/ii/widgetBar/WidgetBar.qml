import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root
    
    readonly property int barWidth: Config.options?.widgetBar?.width ?? 320
    readonly property bool showMedia: Config.options?.widgetBar?.showMedia ?? true
    readonly property bool showWeather: Config.options?.widgetBar?.showWeather ?? true
    readonly property bool showCalendar: Config.options?.widgetBar?.showCalendar ?? true
    readonly property bool showQuickNav: Config.options?.widgetBar?.showQuickNav ?? true
    readonly property string position: Config.options?.widgetBar?.position ?? "left" // "left" or "right"
    
    PanelWindow {
        id: widgetBarWindow
        visible: GlobalStates.widgetBarOpen
        
        function hide() {
            GlobalStates.widgetBarOpen = false
        }
        
        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        color: "transparent"
        
        WlrLayershell.namespace: "quickshell:widgetBar"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        
        // Click outside to close (for Niri)
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(contentContainer, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > contentContainer.width ||
                    localPos.y < 0 || localPos.y > contentContainer.height) {
                    widgetBarWindow.hide()
                }
            }
        }
        
        // Content container
        Item {
            id: contentContainer
            
            anchors {
                top: parent.top
                bottom: parent.bottom
                margins: Appearance.sizes.hyprlandGapsOut
            }
            
            x: root.position === "left" 
                ? Appearance.sizes.hyprlandGapsOut 
                : (parent.width - width - Appearance.sizes.hyprlandGapsOut)
            
            width: root.barWidth
            
            // Slide animation
            property real slideOffset: GlobalStates.widgetBarOpen ? 0 : (root.position === "left" ? -width - 20 : width + 20)
            
            transform: Translate {
                x: contentContainer.slideOffset
                
                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }
            
            // Background
            StyledRectangularShadow {
                target: background
            }
            
            Rectangle {
                id: background
                anchors.fill: parent
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
                
                // Scrollable content
                Flickable {
                    id: flickable
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    contentHeight: widgetsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    
                    ColumnLayout {
                        id: widgetsColumn
                        width: flickable.width
                        spacing: 12
                        
                        // Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Widgets")
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer0
                            }
                            
                            RippleButton {
                                implicitWidth: 32
                                implicitHeight: 32
                                buttonRadius: 16
                                colBackground: "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1
                                downAction: () => widgetBarWindow.hide()
                                contentItem: MaterialSymbol {
                                    text: "close"
                                    iconSize: 18
                                    color: Appearance.colors.colOnLayer0
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                        
                        // Date/Time header
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            
                            StyledText {
                                text: Qt.formatTime(DateTime.clock.date, "HH:mm")
                                font.pixelSize: Appearance.font.pixelSize.huge * 1.5
                                font.weight: Font.Light
                                color: Appearance.colors.colOnLayer0
                            }
                            
                            StyledText {
                                text: Qt.formatDate(DateTime.clock.date, Qt.locale().dateFormat(Locale.LongFormat))
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colSubtext
                            }
                        }
                        
                        // Media Widget
                        MediaWidget {
                            Layout.fillWidth: true
                            visible: root.showMedia
                        }
                        
                        // Weather Widget
                        WeatherWidget {
                            Layout.fillWidth: true
                            visible: root.showWeather && Weather.enabled
                        }
                        
                        // Calendar Widget
                        CalendarWidget {
                            Layout.fillWidth: true
                            visible: root.showCalendar
                        }
                        
                        // Quick Nav Widget
                        QuickNavWidget {
                            Layout.fillWidth: true
                            visible: root.showQuickNav
                        }
                        
                        // Bottom spacer
                        Item { Layout.preferredHeight: 8 }
                    }
                }
            }
        }
        
        // Keyboard handling
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                widgetBarWindow.hide()
                event.accepted = true
            }
        }
    }
    
    IpcHandler {
        target: "widgetBar"
        
        function toggle(): void {
            GlobalStates.widgetBarOpen = !GlobalStates.widgetBarOpen
        }
        
        function open(): void {
            GlobalStates.widgetBarOpen = true
        }
        
        function close(): void {
            GlobalStates.widgetBarOpen = false
        }
    }
}
