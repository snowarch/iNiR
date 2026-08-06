pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayerProgress - Reusable progress bar/slider
 */
Item {
    id: root
    
    // Required properties
    required property real position
    required property real length
    required property bool canSeek
    required property bool isPlaying
    
    // Optional properties
    property color highlightColor: Appearance.zzzEverywhere ? Appearance.zzz.metricFill
        : Appearance.inirEverywhere
        ? Appearance.inir.colPrimary 
        : Appearance.colors.colPrimary
    property color trackColor: Appearance.zzzEverywhere ? Appearance.zzz.metricTrack
        : Appearance.inirEverywhere
        ? Appearance.inir.colLayer2 
        : Appearance.colors.colSecondaryContainer
    property bool enableWavy: true
    property bool scrollable: true
    
    // Signals
    signal seekRequested(real seconds)
    
    readonly property real progressValue: length > 0
        ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property bool waveAnimationActive: root.enableWavy && root.isPlaying
        && root.visible && Appearance.animationsEnabled
    property real displayedProgress: progressValue

    Behavior on displayedProgress {
        enabled: Appearance.animationsEnabled && root.isPlaying
        NumberAnimation { duration: 250; easing.type: Easing.Linear }
    }

    // Seekable slider
    Loader {
        anchors.fill: parent
        active: root.canSeek
        sourceComponent: StyledSlider {
            configuration: root.enableWavy ? StyledSlider.Configuration.Wavy : StyledSlider.Configuration.S
            trackWidth: root.enableWavy ? 2 : StyledSlider.Configuration.S
            handleHeight: Math.min(14, root.height)
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.waveAnimationActive
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            handleColor: root.highlightColor
            value: root.displayedProgress
            onMoved: root.seekRequested(value * root.length)
            scrollable: root.scrollable
        }
    }
    
    // Non-seekable progress bar
    Loader {
        anchors.fill: parent
        active: !root.canSeek
        sourceComponent: StyledProgressBar {
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.waveAnimationActive
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            value: root.progressValue
        }
    }
}
