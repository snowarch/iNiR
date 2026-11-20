pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets
import "root:modules/common/functions/LyricsMath.js" as LyricsMath

// Lyrics on the desktop: iRiS and Prism draw their own faces; Material draws three styles:
//   - "words": word-by-word pop-in as each word is sung, with occasional outline words
//   - "karaoke": current line fills letter by letter as it is sung, with the next line waiting
//   - "classic": 3-line scrolling view (previous, active, next)
AbstractBackgroundWidget {
    id: root

    configEntryName: "lyrics"
    needsColText: true
    resizeMinWidth: 220
    resizeMinHeight: 110

    readonly property string lyricsStyle: String(root._readConfigKey("style") ?? "words")
    readonly property string wordsLines: String(root._readConfigKey("lines") ?? "two")
    readonly property bool wordsOutline: Boolean(root._readConfigKey("outline") ?? true)
    readonly property bool idleFade: Boolean(root._readConfigKey("idleFade") ?? true)

    readonly property MprisPlayer player: MprisController.activePlayer
    readonly property string trackTitle: MprisController.titleOf(root.player) ?? ""
    readonly property string trackArtist: MprisController.artistOf(root.player) ?? ""
    readonly property bool hasPlayer: root.player !== null && root.trackTitle.length > 0
    readonly property bool isPlaying: root.player?.isPlaying ?? false

    readonly property bool wanted: !root.familyFaced && root.visible && root.powerActive && root.hasPlayer
    onWantedChanged: root.wanted ? LyricsService.subscribe(root) : LyricsService.unsubscribe(root)
    Component.onCompleted: if (root.wanted) LyricsService.subscribe(root)
    Component.onDestruction: LyricsService.unsubscribe(root)

    readonly property string status: LyricsService.status
    readonly property var rawLines: root.status === "ok" ? LyricsService.lyricsLines : []
    readonly property bool isInstrumental: root.rawLines.length > 0 && LyricsMath.isNotice(root.rawLines)
    readonly property var stageLines: root.isInstrumental ? [] : LyricsMath.stage(root.rawLines)
    readonly property bool singing: root.hasPlayer && root.stageLines.length > 0

    property real songTime: 0
    function tick(): void { root.songTime = LyricsService.clockAt(Date.now()) }
    readonly property var _clockDeps: [LyricsService.clockPos, LyricsService.clockMs, LyricsService.playing, root.powerActive, root.singing]
    on_ClockDepsChanged: root.tick()
    Timer {
        interval: 60
        repeat: true
        running: !root.familyFaced && root.singing && root.motionActive && LyricsService.playing
        onTriggered: root.tick()
    }

    readonly property int activeLineIdx: root.singing ? LyricsMath.indexAt(root.stageLines, root.songTime) : -1
    readonly property var currentEntry: root.activeLineIdx >= 0 && root.activeLineIdx < root.stageLines.length
        ? root.stageLines[root.activeLineIdx] : null
    readonly property string prevLineText: root.lineTextAt(root.activeLineIdx - 1)
    readonly property string currentLineText: root.lineTextAt(root.activeLineIdx)
    readonly property string nextLineText: root.lineTextAt(root.activeLineIdx + 1)

    function lineTextAt(idx: int): string {
        if (idx < 0 || idx >= root.stageLines.length)
            return ""
        const entry = root.stageLines[idx]
        if (!entry) return ""
        return entry.gap ? "♪" : String(entry.text ?? "")
    }

    readonly property real lineProgress: {
        const entry = root.currentEntry
        if (!entry || entry.gap || !entry.words || entry.words.length === 0)
            return 0
        const chars = LyricsMath.sungTo(entry.words, root.songTime)
        const total = Math.max(1, String(entry.text ?? "").length)
        return Math.max(0, Math.min(1, chars / total))
    }

    readonly property var currentWords: {
        const entry = root.currentEntry
        if (!entry || entry.gap)
            return []
        const text = String(entry.text ?? "")
        const times = entry.words ?? []
        const out = []
        for (let i = 0; i < times.length; i++) {
            const w = times[i]
            out.push({
                word: text.slice(w.a, w.b),
                from: w.from,
                to: w.to
            })
        }
        return out
    }

    readonly property int currentWordIndex: {
        const words = root.currentWords
        if (words.length === 0) return -1
        let idx = 0
        for (let i = 0; i < words.length; i++) {
            if (root.songTime >= words[i].from)
                idx = i
            else
                break
        }
        return idx
    }

    function isOutlineWord(wordIndex: int, wordText: string): bool {
        if (!root.wordsOutline || String(wordText ?? "").length < 3 || root.activeLineIdx < 0)
            return false
        const h = ((root.activeLineIdx + 1) * 2654435761 + (wordIndex + 1) * 40503) & 0xffff
        return (h % 5) === 0
    }

    readonly property string statusMessage: !root.hasPlayer ? Translation.tr("Play something with words")
        : root.isInstrumental ? Translation.tr("Instrumental")
        : root.status === "offline" ? Translation.tr("Lyrics need an internet connection")
        : (root.status === "loading" || root.status === "idle") ? Translation.tr("Looking for lyrics")
        : Translation.tr("No lyrics for this song")

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            id: materialFace
            opacity: (!root.hasPlayer && root.idleFade && !GlobalStates.widgetEditMode) ? 0.25 : 1.0
            Behavior on opacity {
                enabled: root.animationsActive
                NumberAnimation { duration: Appearance.animation.elementMove.duration }
            }

            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.familyFaced && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
                surfaceColor: root.widgetInk
            }

            // Idle / status fallback
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Math.round(28 * root.scaleFactor)
                visible: !root.singing
                spacing: Math.round(4 * root.scaleFactor)

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.isInstrumental ? "music_note" : "lyrics"
                    iconSize: Math.round(24 * root.scaleFactor)
                    color: root.widgetAccentVisible
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: root.statusMessage
                    color: root.widgetInkMuted
                    font.family: root.widgetTitleFamily
                    font.pixelSize: Math.round(Appearance.font.pixelSize.normal * root.scaleFactor)
                    font.weight: Font.DemiBold
                }
                StyledText {
                    visible: root.hasPlayer
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.trackArtist.length > 0 ? `${root.trackTitle} · ${root.trackArtist}` : root.trackTitle
                    color: root.widgetInkSubtle
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                }
            }

            // 1. "words": word-by-word pop-in with occasional outline words
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.scaleFactor)
                visible: root.singing && root.lyricsStyle === "words"

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Math.round(6 * root.scaleFactor)

                    // Instrumental gap dots
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        visible: Boolean(root.currentEntry?.gap)
                        spacing: Math.round(8 * root.scaleFactor)
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: Math.round(10 * root.scaleFactor)
                                height: width
                                radius: width / 2
                                color: root.widgetAccentVisible
                                opacity: 0.45 + 0.55 * ((index === Math.floor(root.songTime * 2) % 3) ? 1 : 0)
                                Behavior on opacity {
                                    enabled: root.animationsActive
                                    NumberAnimation { duration: 220 }
                                }
                            }
                        }
                    }

                    Flow {
                        id: wordsFlow
                        visible: !root.currentEntry?.gap
                        Layout.fillWidth: true
                        spacing: Math.round((root.isSmall ? 6 : 8) * root.scaleFactor)

                        readonly property real wordPixelSize: Math.round((root.isSmall ? 22
                            : root.isLarge ? (root.currentWords.length > 7 ? 32 : 40)
                            : (root.currentWords.length > 7 ? 24 : 30)) * root.scaleFactor)

                        Repeater {
                            model: root.lyricsStyle === "words" ? root.currentWords : []

                            Item {
                                id: wordCell
                                required property var modelData
                                required property int index
                                readonly property bool spoken: wordCell.index <= root.currentWordIndex
                                readonly property bool current: wordCell.index === root.currentWordIndex
                                readonly property bool outlined: root.isOutlineWord(wordCell.index, wordCell.modelData.word)

                                width: wordLabel.implicitWidth
                                height: Math.round(wordsFlow.wordPixelSize * 1.18)

                                StyledText {
                                    id: wordLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: wordCell.modelData.word
                                    font.family: root.widgetTitleFamily
                                    font.pixelSize: wordsFlow.wordPixelSize
                                    font.weight: Font.Black
                                    style: wordCell.outlined ? Text.Outline : (root.widgetHasSurface ? Text.Normal : Text.Raised)
                                    styleColor: wordCell.outlined
                                        ? (wordCell.current ? root.widgetAccentVisible : root.widgetInk)
                                        : root.colHalo
                                    color: wordCell.outlined ? "transparent"
                                        : (wordCell.current ? root.widgetAccentVisible : root.widgetInk)
                                    opacity: wordCell.spoken ? 1.0 : 0.0
                                    scale: wordCell.current ? 1.05 : (wordCell.spoken ? 1.0 : 0.72)
                                    transformOrigin: Item.BottomLeft

                                    Behavior on opacity {
                                        enabled: root.animationsActive
                                        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on scale {
                                        enabled: root.animationsActive
                                        NumberAnimation {
                                            duration: Appearance.animation.elementMoveEnter.duration
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                                        }
                                    }
                                    Behavior on color {
                                        enabled: root.animationsActive
                                        ColorAnimation { duration: 160 }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: root.wordsLines === "two" && root.nextLineText.length > 0 && root.nextLineText !== "♪"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.nextLineText
                        color: root.widgetInkMuted
                        style: root.widgetHasSurface ? Text.Normal : Text.Raised
                        styleColor: root.colHalo
                        font.family: root.widgetBodyFamily
                        font.pixelSize: Math.round((root.isSmall ? 13 : 15) * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }
                }
            }

            // 2. "karaoke": letter-by-letter horizontal sweep across the active line
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.scaleFactor)
                visible: root.singing && root.lyricsStyle === "karaoke"

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Math.round(8 * root.scaleFactor)

                    Item {
                        id: karaokeStage
                        Layout.fillWidth: true
                        implicitHeight: karaokeBase.implicitHeight

                        StyledText {
                            id: karaokeBase
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: root.currentLineText.length > 0 ? root.currentLineText : "♪"
                            color: ColorUtils.applyAlpha(root.widgetInk, 0.34)
                            style: root.widgetHasSurface ? Text.Normal : Text.Raised
                            styleColor: root.colHalo
                            font.family: root.widgetTitleFamily
                            font.pixelSize: Math.round((root.isSmall ? 20 : root.isLarge ? 30 : 24) * root.scaleFactor)
                            font.weight: Font.Bold
                        }

                        Item {
                            width: Math.round(karaokeStage.width * root.lineProgress)
                            height: karaokeBase.implicitHeight
                            clip: true

                            StyledText {
                                width: karaokeStage.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: karaokeBase.text
                                color: root.widgetAccentVisible
                                font: karaokeBase.font
                            }
                        }
                    }

                    StyledText {
                        visible: root.nextLineText.length > 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.nextLineText
                        color: root.widgetInkMuted
                        font.family: root.widgetBodyFamily
                        font.pixelSize: Math.round((root.isSmall ? 12 : 14) * root.scaleFactor)
                        font.weight: Font.Medium
                    }
                }
            }

            // 3. "classic": previous, active, and next lines
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Math.round(28 * root.scaleFactor)
                visible: root.singing && root.lyricsStyle === "classic"
                spacing: Math.round(6 * root.scaleFactor)

                StyledText {
                    visible: !root.isSmall && root.prevLineText.length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.prevLineText
                    color: root.widgetInkSubtle
                    font.family: root.widgetBodyFamily
                    font.pixelSize: Math.round(13 * root.scaleFactor)
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: root.currentLineText.length > 0 ? root.currentLineText : "♪"
                    color: root.widgetAccentVisible
                    style: root.widgetHasSurface ? Text.Normal : Text.Raised
                    styleColor: root.colHalo
                    font.family: root.widgetTitleFamily
                    font.pixelSize: Math.round((root.isSmall ? 18 : root.isLarge ? 26 : 22) * root.scaleFactor)
                    font.weight: Font.Bold
                }

                StyledText {
                    visible: root.nextLineText.length > 0
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.nextLineText
                    color: root.widgetInkMuted
                    font.family: root.widgetBodyFamily
                    font.pixelSize: Math.round(14 * root.scaleFactor)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
