import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root
    
    color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
         : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface 
         : Appearance.colors.colLayer1
    border.width: Appearance.inirEverywhere ? 1 : 0
    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
    radius: Appearance.rounding.normal
    implicitHeight: mainColumn.implicitHeight + 20
    
    // Quick actions model - configurable
    readonly property var quickActions: [
        { icon: "dark_mode", label: Translation.tr("Dark Mode"), action: () => toggleDarkMode(), active: Appearance.m3colors.darkmode },
        { icon: "do_not_disturb_on", label: Translation.tr("DND"), action: () => Notifications.toggleDnd(), active: Notifications.dnd },
        { icon: "nightlight", label: Translation.tr("Night Light"), action: () => Hyprsunset.toggle(), active: Hyprsunset.active },
        { icon: "sports_esports", label: Translation.tr("Game Mode"), action: () => GameMode.toggle(), active: GameMode.manualActive },
        { icon: "wifi", label: Translation.tr("Network"), action: () => openNetworkSettings() },
        { icon: "bluetooth", label: Translation.tr("Bluetooth"), action: () => openBluetoothSettings() },
        { icon: "volume_up", label: Translation.tr("Sound"), action: () => openSoundSettings() },
        { icon: "settings", label: Translation.tr("Settings"), action: () => openSettings() }
    ]
    
    function toggleDarkMode() {
        const current = Config.options?.appearance?.customTheme?.darkmode ?? true
        Config.setNestedValue("appearance.customTheme.darkmode", !current)
    }
    
    function openNetworkSettings() {
        Quickshell.execDetached(["/usr/bin/nm-connection-editor"])
    }
    
    function openBluetoothSettings() {
        Quickshell.execDetached(["/usr/bin/blueman-manager"])
    }
    
    function openSoundSettings() {
        Quickshell.execDetached(["/usr/bin/pavucontrol"])
    }
    
    function openSettings() {
        Quickshell.execDetached(["qs", "-c", "ii", "ipc", "call", "settings", "open"])
    }
    
    ColumnLayout {
        id: mainColumn
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 8
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            
            MaterialSymbol {
                text: "widgets"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Quick Actions")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
        
        // Actions grid
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 6
            columnSpacing: 6
            
            Repeater {
                model: root.quickActions
                
                Rectangle {
                    id: actionButton
                    required property var modelData
                    required property int index
                    
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    radius: Appearance.rounding.small
                    color: modelData.active ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: actionButton.modelData.icon
                            iconSize: 20
                            fill: actionButton.modelData.active ? 1 : 0
                            color: actionButton.modelData.active 
                                ? Appearance.colors.colOnPrimary 
                                : Appearance.colors.colOnLayer2
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        
                        onClicked: actionButton.modelData.action()
                        
                        onContainsMouseChanged: {
                            if (!actionButton.modelData.active) {
                                actionButton.color = containsMouse 
                                    ? Appearance.colors.colLayer2Hover 
                                    : Appearance.colors.colLayer2
                            }
                        }
                    }
                    
                    StyledToolTip {
                        text: actionButton.modelData.label
                        visible: parent.children[1].containsMouse
                    }
                }
            }
        }
        
        // Sliders section
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colOutlineVariant
        }
        
        // Volume slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Audio.sink !== null
            
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (Audio.sink?.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted
                }
            }
            
            StyledSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: if (Audio.sink?.audio) Audio.sink.audio.volume = value
                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colSecondaryContainer
            }
            
            StyledText {
                text: Math.round((Audio.sink?.audio?.volume ?? 0) * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                Layout.preferredWidth: 32
            }
        }
        
        // Brightness slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: Brightness.available ?? false
            
            MaterialSymbol {
                text: "brightness_6"
                iconSize: 18
                color: Appearance.colors.colOnLayer1
            }
            
            StyledSlider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                value: Brightness.brightness ?? 0
                onMoved: Brightness.setBrightness(value)
                highlightColor: Appearance.colors.colPrimary
                trackColor: Appearance.colors.colSecondaryContainer
            }
            
            StyledText {
                text: Math.round(Brightness.brightness * 100) + "%"
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                Layout.preferredWidth: 32
            }
        }
    }
}
