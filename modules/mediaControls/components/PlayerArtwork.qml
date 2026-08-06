pragma ComponentBehavior: Bound
import QtQuick
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
    property int slideDirection: 1
    property string transitionKey: root.artSource
    property bool animateChanges: Appearance.animationsEnabled

    signal transitionStarted(string source)
    signal transitionFinished(string source)
    
    radius: artRadius
    color: "transparent"
    clip: true
    
    MediaCrossSlideImage {
        anchors.fill: parent
        source: root.artSource
        transitionKey: root.transitionKey
        downloaded: root.downloaded
        slideDirection: root.slideDirection
        placeholderColor: root.placeholderColor
        iconColor: root.iconColor
        iconSize: root.iconSize
        artRadius: root.artRadius
        animateChanges: root.animateChanges
        onTransitionStarted: source => root.transitionStarted(source)
        onTransitionFinished: source => root.transitionFinished(source)
    }
}
