import QtQuick
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt ItemThumbnail + PlayingIndicatorBox.
// Rounded network thumbnail; when active, a black scrim fades in with either an
// animated 3-bar equalizer (playing) or a play glyph (paused).
Item {
    id: root
    property string thumbnailUrl: ""
    property int albumIndex: -1          // -1 = show image; >=0 = show track number
    property bool isActive: false
    property bool isPlaying: false
    property int cornerRadius: ITDimens.thumbnailCornerRadius
    property bool circle: false
    // Request a sharper source for large surfaces (player art / blurred backdrop). List/grid
    // thumbnails stay on the small variant — no extra bandwidth where it isn't visible.
    property bool highRes: false

    readonly property int effRadius: circle ? Math.round(Math.min(width, height) / 2) : cornerRadius
    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1

    // ytimg fallback chain: sddefault(640²) → hqdefault(480²) → original. sd/maxres can 404 on
    // some tracks, so we step down on Image.Error instead of risking a broken cover.
    property int _ytTier: 0
    readonly property string _src: root.highRes ? ITDimens.highResThumb(root.thumbnailUrl, root._ytTier) : root.thumbnailUrl
    onThumbnailUrlChanged: root._ytTier = 0

    // Track-number variant (used inside album track lists).
    StyledText {
        anchors.centerIn: parent
        visible: root.albumIndex >= 0 && !root.isActive
        text: root.albumIndex >= 0 ? (root.albumIndex + 1).toString() : ""
        color: Appearance.colors.colOnSurface
        font.pixelSize: Appearance.font.pixelSize.small
    }

    StyledImage {
        id: img
        anchors.fill: parent
        visible: root.albumIndex < 0
        source: root.albumIndex < 0 ? root._src : ""
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        // This component appears in long result, album and queue lists. Keep the
        // decoded bitmap at the physical size it can display instead of retaining
        // the server's full thumbnail in every delegate.
        sourceSize.width: Math.max(1, Math.ceil(root.width * root._dpr))
        sourceSize.height: Math.max(1, Math.ceil(root.height * root._dpr))
        // Step down the ytimg quality tier if a high-res variant isn't available.
        onStatusChanged: if (status === Image.Error && root.highRes && root._ytTier < 2) root._ytTier++
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: img.width
                height: img.height
                radius: root.effRadius
            }
        }
    }

    // Scrim + indicator overlay (fades in over 500ms when active — InnerTune tween(500)).
    Rectangle {
        id: scrim
        anchors.fill: parent
        radius: root.effRadius
        color: root.albumIndex >= 0 ? "transparent" : Qt.rgba(0, 0, 0, ITDimens.activeBoxAlpha)
        opacity: root.isActive ? 1 : 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveEnter.duration)
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        // Animated equalizer bars (playing). InnerTune: 3 bars, 4dp wide, 6dp gap, 24dp tall.
        Row {
            anchors.centerIn: parent
            height: 24
            spacing: 6
            visible: root.isActive && root.isPlaying
            Repeater {
                id: barsRepeater
                model: 3
                Rectangle {
                    width: 4
                    radius: ITDimens.thumbnailCornerRadius
                    color: root.albumIndex >= 0 ? Appearance.colors.colOnSurface : "white"
                    anchors.bottom: parent.bottom
                    property real level: 0.1
                    height: 24 * level
                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration); easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // Play glyph (active but paused).
        StyledText {
            anchors.centerIn: parent
            visible: root.isActive && !root.isPlaying
            text: "play_arrow"
            font.family: Appearance.font.family.iconMaterial
            font.pixelSize: 24
            color: root.albumIndex >= 0 ? Appearance.colors.colOnSurface : "white"
        }
    }

    // Drives the random bar heights (InnerTune retargets every ~50ms; 150ms is gentler
    // on the GPU for a sidebar list). Raw timer — gating on animationsEnabled would freeze it.
    Timer {
        running: root.isActive && root.isPlaying && root.visible
        interval: 150
        repeat: true
        onTriggered: {
            for (let i = 0; i < barsRepeater.count; i++) {
                const bar = barsRepeater.itemAt(i);
                if (bar) bar.level = Math.random() * 0.9 + 0.1;
            }
        }
    }
}
