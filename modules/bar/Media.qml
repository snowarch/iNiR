import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root
    property bool borderless: Config.options?.bar?.borderless ?? false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string fullTrackText: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    readonly property string popupMode: Config.options?.media?.popupMode ?? "dock"
    readonly property bool showVerboseLabel: Config.options?.bar?.verbose ?? true
    readonly property bool hasTrackMetadata: (activePlayer?.trackTitle?.length ?? 0) > 0
        || (activePlayer?.trackArtist?.length ?? 0) > 0
    readonly property bool lockMediaWidth: showVerboseLabel && hasTrackMetadata
    property int pendingTrackDirection: 0
    readonly property int effectiveTrackAnimationDirection: pendingTrackDirection !== 0 ? pendingTrackDirection : 1

    Layout.fillHeight: true
    // Clamp width to prevent long song titles from overflowing into Workspaces.
    // The bar's centerSideModuleWidth binding already accounts for this, but
    // a stable natural width prevents track-length changes from resizing the
    // center pill every time metadata changes.
    readonly property real maxMediaWidth: 220 * Appearance.fontSizeScale
    implicitWidth: lockMediaWidth
        ? maxMediaWidth
        : Math.min(rowLayout.implicitWidth + rowLayout.spacing * 2, maxMediaWidth)
    implicitHeight: Appearance.sizes.barHeight
    clip: true

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 3000
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    // Volume popup
    property bool volumePopupVisible: false
    property real volumePopupValue: Math.max(0, Math.min(1, MprisController.getVolume()))

    // Track switch can swap the active player object; a stale popup value
    // would then be applied to the new player on the next wheel tick.
    onActivePlayerChanged: {
        volumePopupVisible = false
        volumePopupValue = Math.max(0, Math.min(1, MprisController.getVolume()))
    }


    // Bar-anchored media popup
    property bool barMediaPopupVisible: false
    
    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: root.volumePopupVisible = false
    }

    Connections {
        target: MprisController
        function onVolumeChanged() {
            if (!root.volumePopupVisible)
                root.volumePopupValue = MprisController.getVolume()
        }
    }

    Loader {
        id: volumePopupLoader
        active: root.volumePopupVisible
        sourceComponent: PopupWindow {
            visible: true
            color: "transparent"
            anchor {
                window: root.QsWindow.window
                item: root
                edges: (Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom
                gravity: (Config.options?.bar?.bottom ?? false) ? Edges.Top : Edges.Bottom
            }
            implicitWidth: popupContent.width + 16
            implicitHeight: popupContent.height + 16

            Rectangle {
                id: popupContent
                anchors.centerIn: parent
                width: volumeRow.width + 12
                height: volumeRow.height + 8
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                      : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.colors.colLayer3
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                            : (Appearance.inirEverywhere || Appearance.auroraEverywhere) ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                            : Appearance.colors.colLayer3Hover

                Row {
                    id: volumeRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volumePopupValue === 0 ? "volume_off" : "volume_up"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer3
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(root.volumePopupValue * 100) + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer3
                    }
                }
            }
        }
    }

    // Backdrop for click-outside-to-close (Niri)
    Loader {
        active: root.barMediaPopupVisible && root.popupMode === "bar" && CompositorService.isNiri
        sourceComponent: PanelWindow {
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:mediaBackdrop"
            
            MouseArea {
                anchors.fill: parent
                onClicked: root.barMediaPopupVisible = false
            }
        }
    }

    // Bar-anchored media controls popup (when popupMode === "bar")
    Loader {
        id: barMediaPopupLoader
        active: (root.barMediaPopupVisible || _barMediaClosing) && root.popupMode === "bar"

        property bool _barMediaClosing: false

        Connections {
            target: root
            function onBarMediaPopupVisibleChanged() {
                if (!root.barMediaPopupVisible) {
                    barMediaPopupLoader._barMediaClosing = true
                    _barMediaCloseTimer.restart()
                }
            }
        }

        Timer {
            id: _barMediaCloseTimer
            // Keep the loader alive through the complete exit transition.
            interval: Math.max(50, Appearance.animation.elementMoveFast.duration + 40)
            onTriggered: barMediaPopupLoader._barMediaClosing = false
        }

        sourceComponent: PopupWindow {
            id: barMediaPopup
            visible: true
            color: "transparent"
            anchor {
                window: root.QsWindow.window
                item: root
                edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
            }
            implicitWidth: mediaPopupContent.width + Appearance.sizes.elevationMargin * 2
            implicitHeight: mediaPopupContent.height + Appearance.sizes.elevationMargin * 2

            // Click outside to close
            MouseArea {
                anchors.fill: parent
                onClicked: root.barMediaPopupVisible = false
                z: -1
            }

            BarMediaPopup {
                id: mediaPopupContent
                anchors.centerIn: parent
                onCloseRequested: root.barMediaPopupVisible = false

                // Defer presentation so the first visible frame can transition.
                property bool presented: false
                Component.onCompleted: Qt.callLater(() => {
                    mediaPopupContent.presented = root.barMediaPopupVisible
                })
                Connections {
                    target: root
                    function onBarMediaPopupVisibleChanged() {
                        mediaPopupContent.presented = root.barMediaPopupVisible
                    }
                }

                opacity: presented ? 1 : 0
                scale: presented ? 1 : 0.975
                transformOrigin: Config.options.bar.bottom ? Item.Bottom : Item.Top

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                MprisController.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                root.pendingTrackDirection = -1
                MprisController.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                root.pendingTrackDirection = 1
                MprisController.next();
            } else if (event.button === Qt.LeftButton) {
                if (root.popupMode === "bar") {
                    root.barMediaPopupVisible = !root.barMediaPopupVisible
                } else {
                    GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
                }
            }
        }
        onWheel: (event) => {
            if (!MprisController.canChangeVolume) return
            const step = 0.05
            const current = root.volumePopupVisible
                ? root.volumePopupValue : MprisController.getVolume()
            if (event.angleDelta.y > 0) root.volumePopupValue = Math.min(1, current + step)
            else if (event.angleDelta.y < 0) root.volumePopupValue = Math.max(0, current - step)
            MprisController.setVolume(root.volumePopupValue)
            volumePopupVisible = true
            hideTimer.restart()
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4
        anchors.fill: parent

        Item {
            id: compactMediaGlyph
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Appearance.zzzEverywhere && !root.showVerboseLabel ? 30 : 22
            implicitHeight: implicitWidth

            ZzzPlate {
                anchors.fill: parent
                visible: Appearance.zzzEverywhere && !root.showVerboseLabel
                fillColor: Appearance.zzz.paperAlt
                strokeColor: Appearance.zzz.hairline
                strokeWidth: 1
                chamfer: Math.min(Appearance.zzz.cutCorner, 8)
            }

            ClippedFilledCircularProgress {
                id: mediaCircProg
                anchors.centerIn: parent
                lineWidth: Appearance.zzzEverywhere ? 2 : Appearance.rounding.unsharpen
                value: (activePlayer && activePlayer.length > 0) ? (activePlayer.position / activePlayer.length) : 0
                implicitSize: Appearance.zzzEverywhere && !root.showVerboseLabel ? 22 : 22
                colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                    : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnLayer0
                enableAnimation: activePlayer?.playbackState === MprisPlaybackState.Playing

                Item {
                    anchors.centerIn: parent
                    width: mediaCircProg.implicitSize
                    height: mediaCircProg.implicitSize

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: activePlayer?.isPlaying ? "pause" : "music_note"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }

        Item {
            id: titleScroller
            visible: root.showVerboseLabel
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.rightMargin: rowLayout.spacing
            implicitWidth: titleText.implicitWidth
            implicitHeight: titleText.implicitHeight
            clip: true

            readonly property string fullText: root.fullTrackText
            readonly property bool overflowing: titleText.implicitWidth > width + 1
            // Continuous wraparound: scroll one text width + gap, then loop. The
            // trailing copy enters from the right exactly as the first exits left,
            // so it reads as a single seamless ribbon with no fade-snap.
            readonly property real gap: 40
            readonly property real loopDistance: titleText.implicitWidth + gap

            Row {
                id: marqueeRow
                height: parent.height
                spacing: titleScroller.gap
                x: 0

                StyledText {
                    id: titleText
                    height: marqueeRow.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: titleScroller.overflowing ? Text.AlignLeft : Text.AlignHCenter
                    width: titleScroller.overflowing ? implicitWidth : titleScroller.width
                    elide: Text.ElideNone
                    animateChange: true
                    animationDistanceX: root.effectiveTrackAnimationDirection * 10
                    animationDistanceY: 0
                    color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                        : Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
                        : Appearance.colors.colOnLayer1
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    text: titleScroller.fullText
                    onTextChanged: {
                        root.pendingTrackDirection = 0
                        if (!titleScroller.overflowing) marqueeRow.x = 0
                        if (!titleScroller._marqueeHovered && titleScroller.overflowing && Appearance.animationsEnabled) {
                            scrollAnim.stop()
                            titleScroller._marqueeHolding = true
                            titleScroller._startHoldTimer()
                        }
                    }
                }

                // Trailing copy — only present while scrolling, enters from the right.
                StyledText {
                    height: marqueeRow.height
                    verticalAlignment: Text.AlignVCenter
                    visible: titleScroller.overflowing
                    elide: Text.ElideNone
                    color: titleText.color
                    font: titleText.font
                    text: titleScroller.fullText
                }
            }

            // Pausable marquee: hold at start, then glide left continuously.
            // Hover pauses mid-scroll; on exit it resumes from the paused position.
            property bool _marqueeHolding: true
            property bool _marqueeHovered: false

            function _startHoldTimer() {
                if (!titleScroller.visible || !titleScroller.overflowing
                        || !Appearance.animationsEnabled || _marqueeHovered) return
                holdTimer.start()
            }

            Timer {
                id: holdTimer
                interval: 1800
                onTriggered: {
                    titleScroller._marqueeHolding = false
                    marqueeRow.x = 0
                    scrollAnim.start()
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: marqueeRow; property: "x"
                from: 0
                to: -titleScroller.loopDistance
                duration: Math.max(3500, titleScroller.loopDistance * 42)
                easing.type: Easing.Linear
                // Gate on running — binding setPaused() on a stopped animation warns.
                paused: titleScroller._marqueeHovered && scrollAnim.running
                onFinished: {
                    marqueeRow.x = 0
                    titleScroller._marqueeHolding = true
                    titleScroller._startHoldTimer()
                }
            }

            // Kick off on geometry/overflow changes
            onOverflowingChanged: {
                if (!overflowing) {
                    marqueeRow.x = 0
                    scrollAnim.stop()
                    titleScroller._marqueeHolding = true
                } else if (!_marqueeHovered) {
                    scrollAnim.stop()
                    titleScroller._marqueeHolding = true
                    titleScroller._startHoldTimer()
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    holdTimer.stop()
                    scrollAnim.stop()
                    marqueeRow.x = 0
                    _marqueeHolding = true
                } else if (overflowing && !_marqueeHovered) {
                    _startHoldTimer()
                }
            }

            HoverHandler {
                id: titleHoverHandler
                onHoveredChanged: {
                    titleScroller._marqueeHovered = hovered
                    if (hovered) {
                        holdTimer.stop()
                    } else {
                        if (titleScroller.overflowing && Appearance.animationsEnabled) {
                            if (titleScroller._marqueeHolding) {
                                titleScroller._startHoldTimer()
                            }
                            // NumberAnimation.paused is already false, so it resumes
                        }
                    }
                }
            }
        }

    }

}
