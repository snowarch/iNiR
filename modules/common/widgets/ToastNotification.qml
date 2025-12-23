import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions

Item {
    id: root

    readonly property bool auroraEverywhere: (Config.options?.bar?.blurBackground?.enabled ?? false) && !(Config.options?.bar?.showBackground ?? true)
    
    property string title: ""
    property string message: ""
    property string icon: "info"
    property bool isError: false
    property int duration: 3000
    property string source: "system" // "quickshell" or "niri"
    property color accentColor: Appearance.colors.colPrimary
    
    signal dismissed()
    signal copyRequested()
    
    property bool copied: false
    
    implicitWidth: card.width
    implicitHeight: card.height
    
    Rectangle {
        id: card
        width: contentLayout.implicitWidth + 32
        height: contentLayout.implicitHeight + 20
        radius: Appearance.rounding.normal
        color: root.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1, Appearance.aurora.popupSurfaceTransparentize) : Appearance.colors.colLayer1
        border.width: 1
        border.color: root.isError ? Appearance.colors.colError : Appearance.colors.colOutlineVariant
        
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.dismissed()
        }
        
        RowLayout {
            id: contentLayout
            anchors.centerIn: parent
            anchors.leftMargin: 20
            spacing: 10
            
            // Icon
            MaterialSymbol {
                text: root.icon
                iconSize: 20
                color: root.isError ? Appearance.colors.colError : Appearance.colors.colOnLayer1
            }
            
            // Content
            ColumnLayout {
                spacing: 2
                Layout.maximumWidth: 400
                
                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                
                StyledText {
                    visible: root.message !== ""
                    text: root.message.length > 100 ? root.message.substring(0, 100) + "..." : root.message
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: "JetBrains Mono"
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    Layout.maximumWidth: 350
                }
            }
            
            // Copy button (only for errors with message)
            RippleButton {
                visible: root.isError && root.message !== ""
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Qt.rgba(0, 0, 0, 0.1)
                onClicked: {
                    console.log("[Toast] Copying to clipboard:", root.message.substring(0, 50))
                    copyProcess.running = true
                    root.copied = true
                    copyResetTimer.restart()
                }
                
                Process {
                    id: copyProcess
                    command: ["wl-copy", root.message]
                }
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.copied ? "check" : "content_copy"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }
                
                StyledToolTip {
                    text: root.copied ? "Copied!" : "Copy error"
                }
            }
            
            // Close button
            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Qt.rgba(0, 0, 0, 0.1)
                onClicked: root.dismissed()
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
        
        // Progress bar (centered, shorter)
        Rectangle {
            id: progressBar
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            height: 3
            radius: Appearance.rounding.unsharpen
            color: root.isError ? Appearance.colors.colError : Appearance.colors.colPrimary
            
            PropertyAnimation {
                id: progressAnim
                target: progressBar
                property: "width"
                from: Math.min(card.width * 0.5, 120)
                to: 0
                duration: root.duration
                onFinished: root.dismissed()
                paused: mouseArea.containsMouse
            }
        }
        
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 6
            height: 3
            radius: Appearance.rounding.unsharpen
            width: Math.min(card.width * 0.5, 120)
            color: Qt.rgba(0, 0, 0, 0.1)
            z: -1
        }
        
        Component.onCompleted: progressAnim.start()
    }
    
    Timer {
        id: copyResetTimer
        interval: 2000
        onTriggered: root.copied = false
    }
    
    layer.enabled: Appearance.effectsEnabled
    layer.effect: GE.DropShadow {
        horizontalOffset: 0
        verticalOffset: 4
        radius: Appearance.rounding.small
        samples: 25
        color: Appearance.colors.colShadow
    }
}
