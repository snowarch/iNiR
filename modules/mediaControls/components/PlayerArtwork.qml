pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayerArtwork - Reusable cover art component with blur transitions
 */
Rectangle {
    id: root
    
    // Required properties
    required property string artSource
    required property bool downloaded
    
    // Optional properties
    property real artRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    property color placeholderColor: Appearance.inirEverywhere 
        ? Appearance.inir.colLayer2 
        : Appearance.colors.colLayer1
    property color iconColor: Appearance.inirEverywhere 
        ? Appearance.inir.colTextSecondary 
        : Appearance.colors.colSubtext
    property int iconSize: 32
    property bool enableBlurTransition: true
    
    radius: artRadius
    color: "transparent"
    clip: true
    
    layer.enabled: true
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    
    // Cover art image
    Image {
        id: coverArt
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        
        layer.enabled: Appearance.effectsEnabled && root.enableBlurTransition
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.transitioning ? 1 : 0
            blurMax: 32
            Behavior on blur {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
            }
        }
    }
    
    // Transition state
    property bool transitioning: false
    property string pendingSource: ""
    
    Timer {
        id: blurInTimer
        interval: 150
        onTriggered: {
            coverArt.source = root.pendingSource
            blurOutTimer.start()
        }
    }
    
    Timer {
        id: blurOutTimer
        interval: 50
        onTriggered: root.transitioning = false
    }
    
    // Watch for art source changes
    onArtSourceChanged: {
        if (!artSource) {
            blurInTimer.stop()
            blurOutTimer.stop()
            pendingSource = ""
            transitioning = false
            coverArt.source = ""
            return
        }
        // First set: don't animate
        if (!coverArt.source || !coverArt.source.toString()) {
            coverArt.source = artSource
            return
        }
        // Subsequent changes: blur in -> swap -> blur out
        if (enableBlurTransition) {
            pendingSource = artSource
            transitioning = true
            blurInTimer.start()
        } else {
            coverArt.source = artSource
        }
    }
    
    // Placeholder when no art
    Rectangle {
        anchors.fill: parent
        color: root.placeholderColor
        visible: !root.downloaded
        
        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            iconSize: root.iconSize
            color: root.iconColor
        }
    }
}
