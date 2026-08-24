pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    property color textColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    property color activeColor: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
    property color indicatorColor: Appearance.colors.colPrimaryContainer
    property int textAlignment: Text.AlignHCenter
    property int lineSpacing: 8

    property int baseSize: Appearance.font.pixelSize.normal
    property real activeScale: 1.18
    property int falloff: 4
    property bool showPlaceholder: true

    implicitWidth: 160
    implicitHeight: 72

    readonly property int activeIndex: LyricsService.activeIndex
    readonly property bool hasLyrics: LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    property bool _subscribed: false

    function syncSubscription(): void {
        const shouldSubscribe = root.visible;
        if (shouldSubscribe === root._subscribed)
            return;

        root._subscribed = shouldSubscribe;
        if (shouldSubscribe)
            LyricsService.subscribe();
        else
            LyricsService.unsubscribe();
    }

    onVisibleChanged: root.syncSubscription()
    Component.onCompleted: root.syncSubscription()
    Component.onDestruction: {
        if (root._subscribed) {
            root._subscribed = false;
            LyricsService.unsubscribe();
        }
    }

    Item {
        id: placeholder
        anchors.fill: parent
        opacity: (root.hasLyrics || !root.showPlaceholder) ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        readonly property bool isLoading: LyricsService.status === "loading" || LyricsService.status === "idle"
        readonly property bool isNoTrack: LyricsService.status === "no_info"

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width, 260)
            spacing: 10

            MaterialLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                visible: placeholder.isLoading
                loading: visible
                color: root.indicatorColor
                implicitSize: 30
            }

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                visible: !placeholder.isLoading
                text: placeholder.isNoTrack ? "music_off" : "lyrics"
                iconSize: 28
                color: ColorUtils.applyAlpha(root.textColor, 0.55)
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: ColorUtils.applyAlpha(root.textColor, 0.85)
                text: placeholder.isLoading ? Translation.tr("Looking for lyrics")
                    : placeholder.isNoTrack ? Translation.tr("Nothing playing")
                    : Translation.tr("No synced lyrics for this track")
            }
        }
    }

    Item {
        id: viewport
        anchors.fill: parent
        clip: true
        opacity: root.hasLyrics ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Column {
            id: lyricColumn
            width: Math.floor(viewport.width / Math.max(1, root.activeScale))
            x: root.textAlignment === Text.AlignHCenter
                ? Math.round((viewport.width - width) / 2)
                : root.textAlignment === Text.AlignRight
                    ? viewport.width - width
                    : 0
            spacing: root.lineSpacing

            readonly property real targetY: {
                const count = lyricRepeater.count;
                if (count === 0)
                    return 0;
                const item = lyricRepeater.itemAt(Math.max(0, Math.min(root.activeIndex, count - 1)));
                if (!item)
                    return 0;
                return Math.round(viewport.height / 2 - (item.y + item.height / 2));
            }

            y: lyricColumn.targetY

            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Repeater {
                id: lyricRepeater
                model: LyricsService.lyricsLines

                delegate: StyledText {
                    id: lyricLine
                    required property int index
                    required property var modelData

                    readonly property int distance: Math.abs(index - root.activeIndex)
                    readonly property bool isActive: index === root.activeIndex

                    renderType: Text.QtRendering
                    width: lyricColumn.width
                    horizontalAlignment: root.textAlignment
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: (modelData.text && modelData.text.length > 0) ? modelData.text : "♪"

                    font.pixelSize: root.baseSize
                    font.weight: Font.Medium
                    color: lyricLine.isActive ? root.activeColor : root.textColor

                    opacity: {
                        if (lyricLine.distance === 0)
                            return 1.0;
                        if (lyricLine.distance > root.falloff)
                            return 0.0;
                        return Math.max(0.06, 0.55 - (lyricLine.distance - 1) * 0.16);
                    }

                    transformOrigin: root.textAlignment === Text.AlignHCenter ? Item.Center
                        : root.textAlignment === Text.AlignRight ? Item.Right : Item.Left
                    scale: lyricLine.isActive ? root.activeScale : 1.0

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMove.duration
                            easing.type: Appearance.animation.elementMove.type
                            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        }
                    }
                    Behavior on scale {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
            }
        }
    }
}
