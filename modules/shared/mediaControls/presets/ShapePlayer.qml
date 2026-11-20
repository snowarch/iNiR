pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.shared.mediaControls.components

/**
 * ShapePlayer - Cover cut to a track-hashed MaterialShape silhouette that morphs on every track change,
 * with expressive PlayShape (Circle -> Square) and SkipShape (Sunny -> Clover4Leaf) transport buttons.
 * Small: the cover alone with a play key. Medium: cover, title and artist, play key. Large: Medium plus the
 * progress bar and previous / next, the cover over the rest.
 */
Item {
    id: root
    property bool motion: true
    property string sizeClass: "medium"
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.rounding.normal
    property real screenX: 0
    property real screenY: 0

    PlayerBase {
        id: playerBase
        player: root.player
    }

    property color themeSourceColor: playerBase.artDominantColor
    property QtObject blendedColors: AdaptedMaterialScheme { color: root.themeSourceColor }
    readonly property QtObject effectiveColors: Appearance.editorialEverywhere && Appearance.colors
        ? Appearance.colors : root.blendedColors

    readonly property bool small: root.sizeClass === "small"
    readonly property bool large: root.sizeClass === "large"

    readonly property var coverShapes: [
        MaterialShape.Shape.Cookie9Sided,
        MaterialShape.Shape.Clover4Leaf,
        MaterialShape.Shape.Sunny,
        MaterialShape.Shape.Flower,
        MaterialShape.Shape.Clover8Leaf,
        MaterialShape.Shape.Cookie7Sided,
        MaterialShape.Shape.PuffyDiamond,
        MaterialShape.Shape.Pentagon
    ]

    readonly property int currentCoverShape: {
        const s = `${playerBase.effectiveTitle}|${playerBase.effectiveArtist}`
        if (s.length <= 1) return MaterialShape.Shape.Cookie9Sided
        let h = 2166136261
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i)
            h = Math.imul(h, 16777619)
        }
        return root.coverShapes[(h >>> 0) % root.coverShapes.length]
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: root.radius
        color: effectiveColors?.colLayer0 ?? Appearance.colors.colLayer0
        clip: true

        // Soft blurred art wash
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.28
            visible: !Appearance.editorialEverywhere && playerBase.downloaded
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 0.35
                blurMax: 24
            }
        }

        GridLayout {
            anchors.fill: parent
            anchors.margins: 12
            columns: root.large || root.small ? 1 : 2
            rowSpacing: 8
            columnSpacing: 12

            // Track-hashed morphing MaterialShape cover
            Item {
                id: shapeArtBox
                Layout.preferredWidth: root.small ? Math.min(parent.width, parent.height)
                    : root.large ? Math.min(parent.width, parent.height * 0.5)
                    : Math.min(parent.height, parent.width * 0.42)
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: root.sizeClass === "medium" ? Qt.AlignVCenter : Qt.AlignHCenter

                MaterialShape {
                    id: artShapeMask
                    anchors.fill: parent
                    implicitSize: shapeArtBox.width
                    shape: root.currentCoverShape
                    color: effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1
                    visible: false
                }

                MaterialShape {
                    anchors.fill: parent
                    implicitSize: shapeArtBox.width
                    shape: root.currentCoverShape
                    color: effectiveColors?.colLayer1 ?? Appearance.colors.colLayer1
                    visible: !playerBase.downloaded
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "music_note"
                        iconSize: Math.round(shapeArtBox.width * 0.38)
                        color: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
                    }
                }

                Image {
                    anchors.fill: parent
                    source: playerBase.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    smooth: true
                    mipmap: true
                    visible: playerBase.downloaded
                    layer.enabled: playerBase.downloaded
                    layer.effect: GE.OpacityMask {
                        maskSource: artShapeMask
                    }
                }

                PlayKey {
                    visible: root.small
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    size: 34
                    isPlaying: playerBase.effectiveIsPlaying
                    color: root.themeSourceColor
                    onClicked: playerBase.togglePlaying()
                }
            }

            // Track info + progress + shape-morphing transport buttons
            ColumnLayout {
                visible: !root.small
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                PlayerInfo {
                    Layout.fillWidth: true
                    title: playerBase.effectiveTitle
                    artist: playerBase.effectiveArtist
                    titleColor: effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                    artistColor: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
                    titleSize: Appearance.font.pixelSize.normal
                    artistSize: Appearance.font.pixelSize.smaller
                    slideDirection: playerBase.slideDirection
                }

                Item { Layout.fillHeight: true }

                PlayKey {
                    visible: root.sizeClass === "medium"
                    Layout.alignment: Qt.AlignLeft
                    size: 40
                    isPlaying: playerBase.effectiveIsPlaying
                    color: root.themeSourceColor
                    onClicked: playerBase.togglePlaying()
                }

                PlayerProgress {
                    visible: root.large
                    motion: root.motion
                    Layout.fillWidth: true
                    implicitHeight: 16
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    live: playerBase.effectiveIsLive
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: root.themeSourceColor
                    trackColor: ColorUtils.applyAlpha(root.themeSourceColor, 0.24)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }

                RowLayout {
                    visible: root.large
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
                    }

                    Item { Layout.fillWidth: true }

                    // Previous shape button (Sunny -> Clover4Leaf on press)
                    Item {
                        width: 32; height: 32
                        enabled: playerBase.effectiveCanGoPrevious
                        opacity: enabled ? 1 : 0.4
                        MaterialShape {
                            anchors.fill: parent
                            implicitSize: 32
                            shape: prevTap.pressed ? MaterialShape.Shape.Clover4Leaf : MaterialShape.Shape.Sunny
                            color: ColorUtils.applyAlpha(root.themeSourceColor, prevTap.containsMouse ? 0.26 : 0.14)
                            scale: prevTap.pressed ? 0.88 : 1.0
                            Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 150 } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                fill: 1
                                iconSize: 18
                                color: effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                            }
                        }
                        MouseArea {
                            id: prevTap
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerBase.previous()
                        }
                    }

                    // Play/Pause shape button (Circle when paused -> Square when playing)
                    Item {
                        width: 40; height: 40
                        MaterialShape {
                            anchors.fill: parent
                            implicitSize: 40
                            shape: playerBase.effectiveIsPlaying ? MaterialShape.Shape.Square : MaterialShape.Shape.Circle
                            color: root.themeSourceColor
                            scale: playTap.pressed ? 0.90 : (playTap.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 150 } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: playerBase.effectiveIsPlaying ? "pause" : "play_arrow"
                                fill: 1
                                iconSize: 22
                                color: ColorUtils.contrastColor(root.themeSourceColor)
                            }
                        }
                        MouseArea {
                            id: playTap
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerBase.togglePlaying()
                        }
                    }

                    // Next shape button (Sunny -> Clover4Leaf on press)
                    Item {
                        width: 32; height: 32
                        enabled: playerBase.effectiveCanGoNext
                        opacity: enabled ? 1 : 0.4
                        MaterialShape {
                            anchors.fill: parent
                            implicitSize: 32
                            shape: nextTap.pressed ? MaterialShape.Shape.Clover4Leaf : MaterialShape.Shape.Sunny
                            color: ColorUtils.applyAlpha(root.themeSourceColor, nextTap.containsMouse ? 0.26 : 0.14)
                            scale: nextTap.pressed ? 0.88 : 1.0
                            Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: 150 } }
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                fill: 1
                                iconSize: 18
                                color: effectiveColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                            }
                        }
                        MouseArea {
                            id: nextTap
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerBase.next()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: playerBase.lengthText
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: effectiveColors?.colSubtext ?? Appearance.colors.colSubtext
                    }
                }
            }
        }
    }
}
