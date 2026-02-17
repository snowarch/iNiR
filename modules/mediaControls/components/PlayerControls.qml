pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

/**
 * PlayerControls - Reusable control buttons (prev, play/pause, next)
 */
RowLayout {
    id: root
    
    // Required properties
    required property bool isPlaying
    
    // Optional properties
    property int buttonSize: 32
    property int playButtonSize: 40
    property int iconSize: 22
    property int playIconSize: 24
    property real buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall 
        : Appearance.rounding.full
    property real playButtonRadius: buttonRadius
    property color buttonColor: "transparent"
    property color buttonHoverColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover 
        : Appearance.colors.colLayer1Hover
    property color buttonRippleColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active 
        : Appearance.colors.colLayer1Active
    property color iconColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText 
        : Appearance.colors.colOnLayer0
    property color playIconColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary 
        : Appearance.colors.colOnLayer1
    property bool showLabels: true
    
    // Signals
    signal previousClicked()
    signal playPauseClicked()
    signal nextClicked()
    
    spacing: 4
    
    // Previous button
    RippleButton {
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        buttonRadius: root.buttonRadius
        colBackground: root.buttonColor
        colBackgroundHover: root.buttonHoverColor
        colRipple: root.buttonRippleColor
        onClicked: root.previousClicked()
        
        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                iconSize: root.iconSize
                fill: 1
                color: root.iconColor
            }
        }
        
        StyledToolTip { 
            text: Translation.tr("Previous")
            visible: root.showLabels && parent.hovered
        }
    }
    
    // Play/Pause button
    RippleButton {
        implicitWidth: root.playButtonSize
        implicitHeight: root.playButtonSize
        buttonRadius: root.playButtonRadius
        colBackground: root.buttonColor
        colBackgroundHover: root.buttonHoverColor
        colRipple: root.buttonRippleColor
        onClicked: root.playPauseClicked()
        
        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.isPlaying ? "pause" : "play_arrow"
                iconSize: root.playIconSize
                fill: 1
                color: root.playIconColor
                
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
        
        StyledToolTip { 
            text: root.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
            visible: root.showLabels && parent.hovered
        }
    }
    
    // Next button
    RippleButton {
        implicitWidth: root.buttonSize
        implicitHeight: root.buttonSize
        buttonRadius: root.buttonRadius
        colBackground: root.buttonColor
        colBackgroundHover: root.buttonHoverColor
        colRipple: root.buttonRippleColor
        onClicked: root.nextClicked()
        
        contentItem: Item {
            MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                iconSize: root.iconSize
                fill: 1
                color: root.iconColor
            }
        }
        
        StyledToolTip { 
            text: Translation.tr("Next")
            visible: root.showLabels && parent.hovered
        }
    }
}
