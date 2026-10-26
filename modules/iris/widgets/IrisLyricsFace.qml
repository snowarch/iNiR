pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import "root:modules/common/functions/LyricsMath.js" as LyricsMath

// The song sung along: the line before slid up and dimmed, the sung one big in the middle with its words filling
// as they are sung, the next waiting below. A line climbs into the middle a moment before it starts; an
// instrumental stretch is three dots lighting one by one; paused, everything dims and holds.
IrisWidgetFace {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property string title: MprisController.titleOf(root.player) ?? ""
    readonly property string artist: MprisController.artistOf(root.player) ?? ""
    readonly property bool hasPlayer: root.player !== null && root.title.length > 0
    readonly property bool wanted: root.live && root.hasPlayer
    onWantedChanged: root.wanted ? LyricsService.subscribe(root) : LyricsService.unsubscribe(root)
    Component.onCompleted: if (root.wanted) LyricsService.subscribe(root)
    Component.onDestruction: LyricsService.unsubscribe(root)

    readonly property string status: LyricsService.status
    readonly property var lines: root.status === "ok" ? LyricsService.lyricsLines : []
    readonly property bool instrumental: root.lines.length > 0 && LyricsMath.isNotice(root.lines)
    readonly property var stageLines: root.instrumental ? [] : LyricsMath.stage(root.lines)
    readonly property string mode: !root.hasPlayer ? "idle"
        : root.stageLines.length > 0 ? "singing"
        : root.instrumental ? "instrumental"
        : root.status === "offline" ? "offline"
        : root.status === "loading" || root.status === "idle" || root.status === "ok" ? "loading" : "none"
    readonly property bool singing: root.mode === "singing"
    readonly property bool paused: !LyricsService.playing

    // The song's time, a frame at a time while it plays and is seen; held otherwise, so nothing ticks.
    property real songTime: 0
    function tick(): void { root.songTime = LyricsService.clockAt(Date.now()) }
    readonly property var _clock: [LyricsService.clockPos, LyricsService.clockMs, LyricsService.playing, root.moving, root.singing]
    on_ClockChanged: root.tick()
    FrameAnimation {
        running: root.singing && root.moving && LyricsService.playing
        onTriggered: root.tick()
    }

    readonly property real cursor: root.singing ? LyricsMath.cursor(root.stageLines, root.songTime, 0.45) : -1
    readonly property int at: Math.floor(root.cursor)
    readonly property real frac: root.cursor - root.at

    // The stack per size: slots around the sung line, type and room.
    readonly property int center: root.small ? 1 : root.medium ? 2 : 3
    readonly property int bigSize: root.px(root.small ? 24 : root.medium ? 22 : 26)
    readonly property int minSize: root.px(root.small ? 16 : 15)
    readonly property int smallSize: root.px(root.small ? 16 : root.medium ? 14 : 17)
    readonly property int farSize: root.px(14)
    readonly property int maxRows: root.small ? 3 : 2
    readonly property real edgeReach: root.dp(root.small ? 10 : 14)
    readonly property real lineGap: root.dp(root.small ? 14 : 12)
    readonly property real dot: root.dp(root.small ? 14 : root.medium ? 10 : 11)

    FontMetrics {
        id: metrics
        font.family: root.fontMain
        font.pixelSize: 100
        font.weight: IrisStyle.weight(Font.DemiBold)
    }
    // The sung line's size: as big as the face sings, stepped down until its words wrap into the rows it has at the
    // face's full width (greedy, as the text lays out); only below the smallest size does it take another row.
    function fit(text: string): int {
        if (text.length === 0)
            return root.bigSize
        const words = text.split(/\s+/).filter(word => word.length > 0).map(word => metrics.advanceWidth(word) / 100)
        const space = metrics.advanceWidth(" ") / 100
        const rows = size => {
            let count = 1, run = 0
            for (const w of words) {
                const next = run === 0 ? w * size : run + (space + w) * size
                if (next > stage.width - 2 && run > 0) {
                    count++
                    run = w * size
                } else {
                    run = next
                }
            }
            return count
        }
        let size = root.bigSize
        while (size > root.minSize && rows(size) > root.maxRows)
            size--
        // A row more for a word or two: a little smaller takes them back in.
        for (let step = 1; step <= 3 && size - step >= root.minSize; step++)
            if (rows(size - step) < rows(size))
                return size - step
        return size
    }
    // Where slot `index` stands in the stack as it reads: a gap folded away beside the sung line takes no place, so
    // the line after it is the next one, not two away.
    function gapFold(index: int): real {
        const entry = root.stageLines[root.at - root.center + index]
        return entry?.gap ? LyricsMath.smooth(Math.min(1, Math.abs(index - root.center - root.frac))) : 0
    }
    function readAt(index: int): real {
        let d = index - root.center - root.frac
        if (index > root.center)
            for (let j = root.center + 1; j < index; j++) d -= root.gapFold(j)
        else if (index < root.center)
            for (let j = index + 1; j < root.center; j++) d += root.gapFold(j)
        return d
    }
    // How strong a line is `d` lines from the middle (negative: sung already).
    function strength(d: real): real {
        const a = Math.abs(d)
        const s = LyricsMath.smooth
        if (root.small)
            return 1 - s(a)
        if (root.medium)
            return d < 0 ? (a <= 1 ? 1 - 0.42 * s(a) : 0.58 * (1 - s(a - 1))) : (a <= 1 ? 1 : 1 - s(a - 1))
        return d < 0 ? (a <= 1 ? 1 - 0.4 * s(a) : a <= 2 ? 0.6 - 0.28 * s(a - 1) : 0.32 * (1 - s(a - 2)))
            : (a <= 1 ? 1 : a <= 2 ? 1 - 0.35 * s(a - 1) : 0.65 * (1 - s(a - 2)))
    }

    // One line's text, drawn once as the words to sing and again, clipped, as the words sung. A read-only TextEdit:
    // Text cannot say where a character sits, and the three layers must lay out alike.
    component LineText: TextEdit {
        required property var line
        width: line.width
        text: line.text
        readOnly: true
        enabled: false
        selectByMouse: false
        activeFocusOnPress: false
        textFormat: TextEdit.PlainText
        textMargin: 0
        wrapMode: TextEdit.Wrap
        horizontalAlignment: TextEdit.AlignHCenter
        renderType: TextEdit.NativeRendering
        font.family: root.fontMain
        font.pixelSize: line.pixel
        font.weight: IrisStyle.weight(Font.DemiBold)
        font.hintingPreference: Font.PreferDefaultHinting
    }

    component Line: Item {
        id: line
        required property int index
        readonly property int lineIndex: root.at - root.center + line.index
        readonly property var entry: root.stageLines[line.lineIndex] ?? null
        readonly property bool gap: line.entry?.gap ?? false
        readonly property string text: line.entry && !line.gap ? line.entry.text : ""
        readonly property real d: line.index - root.center - root.frac
        // Size and strength follow the place it reads at; the fold of a gap follows its own.
        readonly property real vd: root.readAt(line.index)
        readonly property real ad: Math.abs(line.vd)
        readonly property int big: root.fit(line.text)
        readonly property int pixel: Math.round(line.ad <= 1 ? line.big + (root.smallSize - line.big) * LyricsMath.smooth(line.ad)
            : root.smallSize + (root.farSize - root.smallSize) * LyricsMath.smooth(Math.min(1, line.ad - 1)))
        readonly property real sung: line.text.length > 0 ? LyricsMath.sungTo(line.entry.words, root.songTime) : 0
        // Where the singing is: the rows above it are sung whole, its own row up to here.
        readonly property rect caret: {
            void (base.text + base.lineCount + base.contentWidth + base.contentHeight + base.font.pixelSize + base.width)
            // The edit can still hold the line before for a moment: never ask past what it holds.
            if (line.sung <= 0 || base.text !== line.text)
                return Qt.rect(0, 0, 0, 0)
            const i = Math.min(Math.floor(line.sung), base.length), f = line.sung - i
            const a = base.positionToRectangle(i)
            if (f <= 0 || i >= base.length)
                return a
            const b = base.positionToRectangle(i + 1)
            return b.y === a.y ? Qt.rect(a.x + (b.x - a.x) * f, a.y, 0, a.height) : a
        }
        readonly property real soft: root.dp(12)
        width: stage.width
        // A gap is the dots only while it is the stretch that plays: beside a sung line it folds away to nothing.
        readonly property real presence: line.gap ? 1 - LyricsMath.smooth(Math.min(1, Math.abs(line.d))) : 1
        readonly property real body: line.gap ? root.dot * 2.2 * line.presence
            : Math.max(Math.ceil(base.contentHeight), Math.ceil(root.smallSize * 1.3))
        height: line.body + root.lineGap * line.presence
        // Nothing is ever cut by the face's edge: a line fades out over the last `edgeReach` before it would touch it.
        readonly property real placedAt: stack.y + line.y
        readonly property real edgeRoom: Math.min(line.placedAt, stage.height - line.placedAt - line.body) / root.edgeReach
        opacity: line.entry ? root.strength(line.vd) * line.presence * LyricsMath.smooth(line.edgeRoom) : 0
        // Never hidden: the column skips hidden slots, and opacity follows the place, so hiding moved the place.

        LineText {
            id: base
            line: line
            visible: !line.gap
            color: root.inkTertiary
        }
        // Sung words, dimmed toward secondary as the line climbs away.
        Item {
            anchors.fill: parent
            visible: !line.gap && line.sung > 0
            opacity: line.vd < 0 ? 1 - 0.38 * LyricsMath.smooth(Math.min(1, -line.vd)) : 1
            Item {
                width: parent.width
                height: line.caret.y
                clip: true
                LineText { line: line; color: root.ink }
            }
            Item {
                y: line.caret.y
                width: base.x + line.caret.x
                height: line.caret.height
                clip: true
                LineText { line: line; y: -line.caret.y; color: root.ink }
            }
            // The edge of the fill is soft: the word being sung lights as it goes, not behind a hard cut.
            Item {
                x: base.x + line.caret.x
                y: line.caret.y
                width: line.soft
                height: line.caret.height
                clip: true
                opacity: 0.45
                visible: line.caret.x > 0 && line.sung < line.text.length
                LineText { line: line; x: -line.caret.x; y: -line.caret.y; color: root.ink }
            }
        }

        // An instrumental stretch: three dots that light one by one, and shrink away as the singing comes back.
        Row {
            id: dots
            anchors.centerIn: parent
            visible: line.gap
            spacing: root.dot * 0.8
            readonly property real p: line.gap && line.entry.until > line.entry.time
                ? Math.max(0, Math.min(1, (root.songTime - line.entry.time) / (line.entry.until - line.entry.time))) : 0
            readonly property real away: line.gap ? LyricsMath.smooth(1 - (line.entry.until - root.songTime) / 0.5) : 0
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    readonly property real lit: LyricsMath.smooth(dots.p * 3.3 - index)
                    width: root.dot
                    height: root.dot
                    radius: width / 2
                    color: root.accent
                    opacity: 0.28 + 0.72 * lit
                    scale: (0.82 + 0.18 * lit) * (1 - dots.away)
                }
            }
        }
    }

    // The header names the song on the large face.
    FaceHeader {
        id: header
        // with nothing playing it still names the face, so the empty state below has a head to wait under
        visible: root.large
        width: root.contentWidth
        face: root
        glyph: "lyrics"
        text: root.hasPlayer ? root.title : Translation.tr("Lyrics")
        trailing: root.hasPlayer ? root.artist : ""
        trailingMax: Math.round(root.contentWidth * 0.42)
    }

    Item {
        id: stage
        x: 0
        y: header.visible ? header.height + root.dp(8) : 0
        width: root.contentWidth
        height: root.height - root.padding * 2 - stage.y
        visible: root.singing
        clip: true
        opacity: root.paused ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: IrisStyle.revealDuration; easing.type: IrisStyle.feedbackEasing } }

        Column {
            id: stack
            width: stage.width
            // The point between the sung line and the next, as far as the next has climbed, sits in the middle.
            y: {
                void slots.count
                const a = slots.itemAt(root.center), b = slots.itemAt(root.center + 1)
                if (!a)
                    return 0
                const ca = a.y + a.body / 2
                const cb = b ? b.y + b.body / 2 : ca
                return Math.round(stage.height / 2 - (ca + (cb - ca) * root.frac))
            }
            Repeater {
                id: slots
                model: root.singing ? root.center * 2 + 1 + 1 : 0
                Line {}
            }
        }
    }

    FaceBlank {
        visible: !root.singing
        // a large face would lose it in the middle: it waits under the head, where the first line goes
        x: Math.round((parent.width - width) / 2)
        y: root.large ? header.height + root.dp(24) : Math.round((parent.height - height) / 2)
        width: root.contentWidth
        face: root
        glyph: root.mode === "offline" ? "wifi_off" : root.mode === "instrumental" ? "music_note"
            : root.mode === "none" ? "speaker_notes_off" : "lyrics"
        glyphFill: root.mode === "instrumental"
        tint: root.mode === "offline" ? root.inkSecondary : root.accent
        title: root.mode === "idle" ? Translation.tr("Play something with words")
            : root.mode === "loading" ? Translation.tr("Looking for lyrics")
            : root.mode === "offline" ? Translation.tr("Lyrics need an internet connection")
            : root.mode === "instrumental" ? Translation.tr("Instrumental")
            : Translation.tr("No lyrics for this song")
        detail: root.mode === "offline" ? Network.offlineReason
            : root.mode === "idle" || root.mode === "loading" || header.visible ? ""
            : [root.title, root.artist].filter(part => part.length > 0).join(" · ")
    }
}
