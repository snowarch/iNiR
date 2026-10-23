pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// Home, the first entry of every layout: what people touch every day. The wallpaper with the last ones set (a click
// flies the thumb into place), dark or light, the one signal and the Design; quick tiles for what gets flipped daily
// (Night Light, Do Not Disturb, glass, game mode, sound, the Island's layout); what needs you with its fix; the areas
// opened most; and the last rows changed with their control in place, so touching one again is the undo.
Item {
    id: root
    property Item host
    property string voice: ""
    readonly property real d: Number(root.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * root.d) }
    readonly property bool wide: root.width >= root.u(820)
    readonly property real gap: root.u(root.voice === "console" ? 10 : 14)
    readonly property real cardRadius: root.voice === "console" ? root.u(24) : IrisStyle.radiusSheet
    readonly property color plate: IrisStyle.glassy || root.voice !== "console" ? IrisStyle.readingCard : IrisStyle.fillQuiet
    readonly property color signal: IrisStyle.signal
    readonly property alias flick: flick

    function specAt(path: string): var { return IrisOptions.settings.find(spec => spec.path === path && !spec.mirror) ?? null }
    readonly property var schemeSpec: root.specAt("iris.appearance.scheme")
    readonly property var signalSpec: root.specAt("iris.appearance.signal")
    readonly property var lookSpec: root.specAt("iris.appearance.look")
    readonly property var designSpec: root.specAt("iris.appearance.design")
    readonly property var silentSpec: root.specAt("notifications.silent")
    readonly property var glassSpec: root.specAt("iris.appearance.glass.mode")
    readonly property var layoutSpec: root.specAt("iris.bar.layout")

    // Every area's notes, newest config first; each carries the area it lives in.
    readonly property var needs: {
        const notes = root.host?.notes ?? {}
        const out = []
        for (const entry of root.host?.sections ?? [])
            for (const note of notes[entry.id] ?? []) out.push(Object.assign({ section: entry.id, area: String(entry.title ?? "") }, note))
        return out
    }
    // Minutes tick on their own: "2 min ago" turns into "3 min ago" while Home is open.
    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.now = Date.now() }
    function ago(at: real): string {
        const minutes = Math.floor((root.now - at) / 60000)
        if (minutes < 1) return Translation.tr("just now")
        if (minutes < 60) return Translation.tr("%1 min ago").arg(minutes)
        const hours = Math.floor(minutes / 60)
        if (hours < 24) return Translation.tr("%1 h ago").arg(hours)
        return hours < 48 ? Translation.tr("yesterday") : Translation.tr("%1 days ago").arg(Math.floor(hours / 24))
    }
    readonly property var recent: {
        IrisOptions.recent
        Config.revision
        return IrisOptions.recentRows().slice(0, 6)
    }
    function areaTitle(id: string): string { return Translation.tr(String(IrisOptions.sectionById(id)?.title ?? "")) }
    // As many as the card holds (two a line), the ones opened most first, the daily areas after them.
    property int visitedLines: 2
    readonly property var visited: IrisOptions.mostVisited(2 * root.visitedLines, ["appearance", "wallpaper", "dock", "bar", "colour", "widgets", "notifications", "display"])
        .map(id => IrisOptions.sectionById(id)).filter(entry => entry)

    // The wallpapers set lately (the one on screen first), topped up from the folder when the history is short.
    readonly property string wallNow: FileUtils.trimFileProtocol(String(Config.options?.background?.wallpaperPath ?? ""))
    readonly property var walls: {
        const seen = new Set([root.wallNow])
        const out = []
        for (const path of Wallpapers.recentWallpapers.concat(Wallpapers.shuffleCount > 0 ? Wallpapers.folderSample(12) : []))
            if (!seen.has(path) && out.length < 6) { seen.add(path); out.push(path) }
        return out
    }
    // A thumb flies into the big picture; it rests there until the wallpaper under it has changed.
    function setWall(thumb: Item, path: string): void {
        if (path === root.wallNow) return
        const from = thumb.mapToItem(root, 0, 0)
        const to = heroPicture.mapToItem(root, 0, 0)
        flight.source = thumb.source
        flight.path = path
        flight.x = from.x; flight.y = from.y; flight.width = thumb.width; flight.height = thumb.height
        flight.radius = thumb.radius ?? root.u(10)
        flyX.to = to.x; flyY.to = to.y; flyW.to = heroPicture.width; flyH.to = heroPicture.height; flyR.to = heroPicture.radius
        flight.opacity = 1
        fly.restart()
        settle.restart()
        Wallpapers.select(path)
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: column.implicitHeight + root.u(6)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        ScrollBar.vertical: IrisScrollBar {}

        Column {
            id: column
            width: flick.width
            spacing: root.gap
            readonly property real lead: root.wide ? Math.floor((width - root.gap) * 0.58) : width
            readonly property real side: root.wide ? width - lead - root.gap : width

            // ── Row one: the wallpaper | what needs you, and the look.
            Grid {
                id: rowOne
                columns: root.wide ? 2 : 1
                columnSpacing: root.gap
                rowSpacing: root.gap

                Card {
                    id: wall
                    width: column.lead
                    height: wallBody.implicitHeight + wall.headroom + wall.pad
                    caption: Translation.tr("Wallpaper")
                    actions: [
                        { label: Translation.tr("Shuffle"), run: () => Wallpapers.nextWallpaper() },
                        { label: Translation.tr("Change"), run: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.wallpaperSelectorOpen = true } }
                    ]
                    Column {
                        id: wallBody
                        x: wall.pad
                        y: wall.headroom
                        width: wall.width - 2 * wall.pad
                        spacing: root.u(10)
                        ClippingRectangle {
                            id: heroPicture
                            width: parent.width
                            height: Math.round(Math.min(width * 9 / 16, root.u(root.wide ? 236 : 210)))
                            radius: IrisStyle.fieldChamfer ? 0 : Math.max(root.u(8), wall.radius - wall.pad)
                            color: IrisStyle.fillQuiet
                            IrisWallpaperView {
                                anchors.fill: parent
                                live: false
                                screen: GlobalStates.focusedScreen
                                decodeSize: Qt.size(Math.round(parent.width), Math.round(parent.height))
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr("Change")
                                onClicked: { GlobalStates.settingsOverlayOpen = false; GlobalStates.wallpaperSelectorOpen = true }
                            }
                        }
                        // The last ones set: one click puts it back.
                        Row {
                            id: strip
                            visible: root.walls.length > 0
                            width: parent.width
                            spacing: root.u(8)
                            readonly property real cell: Math.floor((width - 5 * spacing) / 6)
                            Repeater {
                                model: root.walls
                                MouseArea {
                                    id: shot
                                    required property string modelData
                                    width: strip.cell
                                    height: Math.round(strip.cell * 10 / 16)
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: Translation.tr("Set this wallpaper")
                                    onClicked: root.setWall(shotClip, shot.modelData)
                                    scale: shot.pressed ? 0.96 : 1
                                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                    ClippingRectangle {
                                        id: shotClip
                                        readonly property url source: shotImage.source
                                        anchors.fill: parent
                                        radius: IrisStyle.fieldChamfer ? 0 : root.u(10)
                                        color: IrisStyle.fillQuiet
                                        ThumbnailImage {
                                            id: shotImage
                                            anchors.fill: parent
                                            sourcePath: shot.modelData
                                            sourceSize: Qt.size(Math.round(shot.width * 1.5), Math.round(shot.height * 1.5))
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            opacity: status === Image.Ready ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            radius: shotClip.radius
                                            color: "transparent"
                                            border.width: shot.containsMouse ? Math.max(1, root.u(1.5)) : 1
                                            border.color: shot.containsMouse ? IrisStyle.text : IrisStyle.hairline
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    id: sideOne
                    width: column.side
                    spacing: root.gap

                    // ── What needs you: every area's notes, each with what fixes it.
                    Card {
                        id: needsCard
                        width: parent.width
                        height: needsBody.implicitHeight + needsCard.headroom + needsCard.pad
                        caption: Translation.tr("Needs you")
                        Column {
                            id: needsBody
                            x: needsCard.pad
                            y: needsCard.headroom
                            width: needsCard.width - 2 * needsCard.pad
                            spacing: root.u(12)
                            Row {
                                visible: root.needs.length === 0
                                spacing: root.u(10)
                                MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "check"; iconSize: root.u(18); color: IrisStyle.muted }
                                IrisText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Translation.tr("Nothing needs you.")
                                    color: IrisStyle.muted
                                    font.pixelSize: IrisStyle.typeBody
                                }
                            }
                            Repeater {
                                model: root.needs.slice(0, 3)
                                Item {
                                    id: need
                                    required property var modelData
                                    width: needsBody.width
                                    height: needText.implicitHeight + root.u(4) + needMeta.implicitHeight
                                    Rectangle { y: root.u(7); width: root.u(6); height: width; radius: width / 2; color: root.signal }
                                    IrisText {
                                        id: needText
                                        x: root.u(16)
                                        width: parent.width - x
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        text: String(need.modelData.text ?? "")
                                        color: IrisStyle.text
                                        font.pixelSize: IrisStyle.typeBody
                                    }
                                    Row {
                                        id: needMeta
                                        x: needText.x - root.u(10)
                                        anchors.top: needText.bottom
                                        anchors.topMargin: root.u(2)
                                        spacing: root.u(2)
                                        IrisText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            leftPadding: root.u(10)
                                            rightPadding: root.u(6)
                                            text: Translation.tr(String(need.modelData.area ?? "")) + (String(need.modelData.kind ?? "").length > 0 ? " · " + need.modelData.kind : "")
                                            color: IrisStyle.muted
                                            font.pixelSize: IrisStyle.typeMeta
                                        }
                                        TextKey {
                                            visible: String(need.modelData.app ?? "").length > 0
                                            label: Translation.tr("Unpin")
                                            onClicked: Config.setNestedValue("dock.pinnedApps", (Config.options?.dock?.pinnedApps ?? []).map(String).filter(id => id !== String(need.modelData.app)))
                                        }
                                        TextKey {
                                            label: Translation.tr("Show")
                                            onClicked: { root.host.selectSection(String(need.modelData.section)); root.host.landOn(String(need.modelData.path)) }
                                        }
                                    }
                                }
                            }
                            TextKey {
                                visible: root.needs.length > 3
                                label: Translation.tr("%1 more").arg(root.needs.length - 3)
                                onClicked: root.host.selectSection(String(root.needs[3]?.section ?? ""))
                            }
                        }
                    }

                    // ── The look at once: dark or light, the signal, the Design. It takes the column's rest.
                    Card {
                        id: lookCard
                        width: parent.width
                        height: Math.max(3 * root.u(48) + lookCard.headroom + lookCard.pad - root.u(8),
                            root.wide ? wall.height - needsCard.height - root.gap : 0)
                        caption: Translation.tr("Look")
                        Column {
                            id: lookBody
                            x: lookCard.pad
                            y: lookCard.headroom
                            width: lookCard.width - 2 * lookCard.pad
                            spacing: 0
                            Line {
                                id: schemeLine
                                visible: root.schemeSpec !== null
                                name: Translation.tr("Scheme")
                                IrisSegmented {
                                    id: scheme
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth > 0 ? implicitWidth : options.length * root.u(64), schemeLine.room)
                                    voice: root.voice
                                    accessibleName: Translation.tr("Scheme")
                                    readonly property var words: ({ dark: "Dark", light: "Light", auto: "Auto", ink: "Ink" })
                                    options: ["dark", "light", "auto", "ink"]
                                        .filter(value => IrisOptions.choicesOf(root.schemeSpec ?? {}).some(choice => choice.value === value))
                                        .map(value => ({ label: Translation.tr(scheme.words[value]), value: value }))
                                    current: { Config.revision; return root.schemeSpec ? IrisOptions.currentValue(root.schemeSpec) : "" }
                                    onPicked: value => IrisOptions.commit(root.schemeSpec, value)
                                }
                            }
                            Line {
                                visible: root.lookSpec !== null
                                name: Translation.tr("Look")
                                IrisSegmented {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    voice: root.voice
                                    accessibleName: Translation.tr("Look")
                                    options: ["apple", "nothing"].map(value => ({ label: Translation.tr(value === "apple" ? "Apple" : "Nothing OS"), value: value }))
                                    current: { Config.revision; return root.lookSpec ? IrisOptions.currentValue(root.lookSpec) : "apple" }
                                    onPicked: value => IrisOptions.commit(root.lookSpec, value)
                                }
                            }
                            Line {
                                id: signalLine
                                visible: root.signalSpec !== null
                                name: Translation.tr("Signal")
                                Swatches { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Line {
                                id: designLine
                                visible: root.designSpec !== null && IrisOptions.shown(root.designSpec)
                                name: Translation.tr("Design")
                                last: true
                                IrisSegmented {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth > 0 ? implicitWidth : options.length * root.u(84), designLine.room)
                                    voice: root.voice
                                    accessibleName: Translation.tr("Design")
                                    options: root.designSpec ? IrisOptions.choicesOf(root.designSpec).map(choice => ({ label: Translation.tr(String(choice.label ?? "")), value: choice.value })) : []
                                    current: { Config.revision; return root.designSpec ? IrisOptions.currentValue(root.designSpec) : "" }
                                    onPicked: value => IrisOptions.commit(root.designSpec, value)
                                }
                            }
                        }
                    }
                }
            }

            // ── Row two: the quick tiles, flipped every day.
            Card {
                id: quick
                width: column.width
                height: quickRow.height + quick.headroom + quick.pad
                caption: Translation.tr("Quick")
                Flow {
                    id: quickRow
                    x: quick.pad
                    y: quick.headroom
                    width: quick.width - 2 * quick.pad
                    spacing: root.u(10)
                    // Four 1x1 keys and two 2x1 that share what the row has left; a narrow page wraps them.
                    readonly property real unit: Math.min(root.u(88), Math.floor((width - 7 * spacing) / 8))
                    readonly property bool oneLine: width >= 4 * unit + 5 * spacing + 2 * root.u(170)
                    readonly property real wideTile: quickRow.oneLine ? Math.floor((width - 4 * unit - 5 * spacing) / 2) : Math.floor((width - spacing) / 2)
                    IrisTile {
                        width: quickRow.unit; height: quickRow.unit; unit: quickRow.unit
                        glyph: "nightlight"
                        title: Translation.tr("Night Light")
                        label: Translation.tr("Night")
                        on: Hyprsunset.active
                        Accessible.name: Translation.tr("Night Light")
                        onClicked: Hyprsunset.toggle()
                    }
                    IrisTile {
                        width: quickRow.unit; height: quickRow.unit; unit: quickRow.unit
                        visible: root.silentSpec !== null
                        glyph: "do_not_disturb_on"
                        title: Translation.tr("Do Not Disturb")
                        label: Translation.tr("Quiet")
                        on: { Config.revision; return Boolean(Config.options?.notifications?.silent ?? false) }
                        Accessible.name: Translation.tr("Do Not Disturb")
                        onClicked: IrisOptions.commit(root.silentSpec, !on)
                    }
                    IrisTile {
                        width: quickRow.unit; height: quickRow.unit; unit: quickRow.unit
                        visible: root.glassSpec !== null
                        glyph: "blur_on"
                        title: Translation.tr("Glass")
                        label: Translation.tr("Glass")
                        on: { Config.revision; return String(IrisOptions.currentValue(root.glassSpec ?? {}) ?? "off") !== "off" }
                        Accessible.name: Translation.tr("Glass")
                        onClicked: IrisOptions.commit(root.glassSpec, on ? "off" : "wallpaper")
                    }
                    IrisTile {
                        width: quickRow.unit; height: quickRow.unit; unit: quickRow.unit
                        glyph: "sports_esports"
                        title: Translation.tr("Game mode")
                        label: Translation.tr("Game")
                        on: GameMode.active
                        Accessible.name: Translation.tr("Game mode")
                        onClicked: GameMode.toggle()
                    }
                    // Sound: the level as dots, set by a press or a drag anywhere on the tile.
                    IrisTile {
                        id: soundTile
                        width: quickRow.wideTile; height: quickRow.unit; unit: quickRow.unit
                        wide: true
                        glyph: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        title: Translation.tr("Sound")
                        Accessible.role: Accessible.Slider
                        Accessible.name: Translation.tr("Sound")
                        label: Audio.ready ? "" : Translation.tr("No output")
                        IrisDotStrip {
                            visible: Audio.ready
                            x: root.u(12)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.u(14)
                            width: parent.width - root.u(24)
                            height: root.u(12)
                            value: Audio.value
                            knobSize: root.u(10)
                        }
                        MouseArea {
                            enabled: Audio.ready
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            function set(x: real): void { Audio.setSinkVolume(Math.max(0, Math.min(1, (x - root.u(12)) / (width - root.u(24))))) }
                            onPressed: mouse => set(mouse.x)
                            onPositionChanged: mouse => { if (pressed) set(mouse.x) }
                        }
                    }
                    // The Island's layout: a press moves to the next, the dots say which of them it is.
                    IrisTile {
                        id: islandTile
                        readonly property var choices: root.layoutSpec ? IrisOptions.choicesOf(root.layoutSpec) : []
                        readonly property int at: { Config.revision; return Math.max(0, islandTile.choices.findIndex(choice => IrisOptions.same(choice.value, IrisOptions.currentValue(root.layoutSpec ?? {})))) }
                        visible: root.layoutSpec !== null
                        width: quickRow.wideTile; height: quickRow.unit; unit: quickRow.unit
                        wide: true
                        glyph: String(islandTile.choices[islandTile.at]?.glyph ?? "pill")
                        title: Translation.tr("Island")
                        // where it sits, in the words the layout row uses ("Island" itself reads as the middle)
                        readonly property string where: String(islandTile.choices[islandTile.at]?.value ?? "") === "island" ? Translation.tr("Middle") : Translation.tr(String(islandTile.choices[islandTile.at]?.label ?? ""))
                        Accessible.name: Translation.tr("Island layout")
                        onClicked: if (islandTile.choices.length > 0) IrisOptions.commit(root.layoutSpec, islandTile.choices[(islandTile.at + 1) % islandTile.choices.length].value)
                        IrisDotStrip {
                            x: root.u(12)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.u(14)
                            width: Math.min(parent.width - root.u(24), islandTile.choices.length * root.u(16))
                            height: root.u(12)
                            count: Math.max(2, islandTile.choices.length)
                            value: islandTile.choices.length > 1 ? islandTile.at / (islandTile.choices.length - 1) : 0
                            knobSize: root.u(10)
                            fillColor: IrisStyle.dotEmpty
                            knobColor: IrisStyle.text
                        }
                        IrisLabel {
                            anchors.right: parent.right
                            anchors.rightMargin: root.u(12)
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: root.u(11)
                            text: islandTile.where
                            color: IrisStyle.subtext
                        }
                    }
                }
            }

            // ── Row three: what you changed last | the areas you open most. Both take what the page has left.
            Grid {
                id: rowThree
                columns: root.wide ? 2 : 1
                columnSpacing: root.gap
                rowSpacing: root.gap
                readonly property real rest: root.wide ? Math.max(0, flick.height - rowOne.height - quick.height - 2 * root.gap - root.u(6)) : 0

                Card {
                    id: recentCard
                    width: column.lead
                    height: Math.max(recentBody.implicitHeight + recentCard.headroom + root.u(10), rowThree.rest, root.u(220))
                    caption: Translation.tr("Recently changed")
                    hint: root.recent.length > 0 ? Translation.tr("Undo in place") : ""
                    Column {
                        id: recentBody
                        visible: root.recent.length > 0
                        x: root.u(4)
                        y: recentCard.headroom - root.u(6)
                        width: recentCard.width - root.u(8)
                        Repeater {
                            model: ScriptModel { values: root.recent; objectProp: "key" }
                            Item {
                                id: change
                                required property var modelData
                                required property int index
                                width: recentBody.width
                                height: changeRow.implicitHeight
                                IrisSetting {
                                    id: changeRow
                                    width: parent.width - undo.width - root.u(8)
                                    // The row says where it lives and when it changed instead of what it does.
                                    spec: Object.assign({}, change.modelData.spec, {
                                        label: change.modelData.spec.label,
                                        description: root.areaTitle(String(change.modelData.spec.section ?? "")) + " · " + root.ago(change.modelData.at)
                                    })
                                    voice: root.voice
                                    last: change.index === root.recent.length - 1
                                }
                                MouseArea {
                                    id: undo
                                    anchors.right: parent.right
                                    anchors.rightMargin: root.u(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.u(32)
                                    height: width
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    Accessible.role: Accessible.Button
                                    Accessible.name: Translation.tr("Set back")
                                    onClicked: IrisOptions.commit(change.modelData.spec, change.modelData.before)
                                    Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(width); color: undo.containsMouse ? IrisStyle.fillHover : "transparent" }
                                    MaterialSymbol { anchors.centerIn: parent; text: "undo"; iconSize: root.u(18); color: undo.containsMouse ? IrisStyle.text : IrisStyle.muted }
                                }
                            }
                        }
                    }
                    // Nothing changed yet: the paper and the ghosts of the rows that will land here.
                    Item {
                        id: ghosts
                        visible: root.recent.length === 0
                        x: recentCard.pad
                        y: recentCard.headroom
                        width: recentCard.width - 2 * recentCard.pad
                        height: recentCard.height - y - recentCard.pad
                        IrisDotGrid { anchors.fill: parent; opacity: 0.9 }
                        Column {
                            id: ghostRows
                            width: parent.width
                            spacing: root.u(10)
                            Repeater {
                                model: [{ w: 0.34, kind: "switch" }, { w: 0.26, kind: "range" }, { w: 0.3, kind: "choice" }]
                                    .slice(0, Math.max(1, Math.min(3, Math.floor((ghosts.height - root.u(40)) / root.u(58)))))
                                Rectangle {
                                    id: ghost
                                    required property var modelData
                                    required property int index
                                    width: ghostRows.width
                                    height: root.u(48)
                                    radius: IrisStyle.fieldChamfer ? 0 : root.u(14)
                                    color: root.plate
                                    border.width: 1
                                    border.color: IrisStyle.hairline
                                    opacity: 1 - ghost.index * 0.28
                                    Rectangle { x: root.u(16); y: root.u(14); width: Math.round(ghostRows.width * ghost.modelData.w); height: root.u(8); radius: height / 2; color: IrisStyle.dotEmpty }
                                    Rectangle { x: root.u(16); y: root.u(28); width: Math.round(ghostRows.width * ghost.modelData.w * 0.6); height: root.u(6); radius: height / 2; color: IrisStyle.paperDot }
                                    // the control each would bring: a switch ring, a dot scrubber, a two-word track
                                    Rectangle {
                                        visible: ghost.modelData.kind === "switch"
                                        anchors.right: parent.right; anchors.rightMargin: root.u(16); anchors.verticalCenter: parent.verticalCenter
                                        width: root.u(36); height: root.u(20); radius: height / 2
                                        color: "transparent"; border.width: 1; border.color: IrisStyle.ringInk
                                        Rectangle { x: root.u(4); anchors.verticalCenter: parent.verticalCenter; width: root.u(12); height: width; radius: width / 2; color: "transparent"; border.width: 1; border.color: IrisStyle.ringInk }
                                    }
                                    IrisDotStrip {
                                        visible: ghost.modelData.kind === "range"
                                        anchors.right: parent.right; anchors.rightMargin: root.u(16); anchors.verticalCenter: parent.verticalCenter
                                        width: root.u(120); height: root.u(10)
                                        value: 0.4; knobSize: root.u(9); stagger: false
                                        fillColor: IrisStyle.ringInk; emptyColor: IrisStyle.dotEmpty
                                    }
                                    Rectangle {
                                        visible: ghost.modelData.kind === "choice"
                                        anchors.right: parent.right; anchors.rightMargin: root.u(16); anchors.verticalCenter: parent.verticalCenter
                                        width: root.u(110); height: root.u(24); radius: height / 2
                                        color: "transparent"; border.width: 1; border.color: IrisStyle.hairline
                                        Rectangle { x: root.u(2); anchors.verticalCenter: parent.verticalCenter; width: root.u(54); height: root.u(20); radius: height / 2; color: IrisStyle.dotEmpty }
                                    }
                                }
                            }
                        }
                        IrisText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: ghostRows.height + Math.max(root.u(14), (parent.height - ghostRows.height - implicitHeight) / 2)
                            width: Math.min(implicitWidth, parent.width)
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: Translation.tr("What you change shows up here, ready to set back.")
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeBody
                        }
                    }
                }

                Card {
                    id: visitedCard
                    width: column.side
                    height: root.wide ? recentCard.height : visitedGrid.height + visitedCard.headroom + visitedCard.pad
                    caption: Translation.tr("Most visited")
                    Binding { target: root; property: "visitedLines"; value: root.wide ? Math.max(2, Math.min(4, Math.floor((visitedCard.height - visitedCard.headroom - visitedCard.pad + root.u(10)) / root.u(86)))) : 2 }
                    Grid {
                        id: visitedGrid
                        x: visitedCard.pad
                        y: visitedCard.headroom
                        width: visitedCard.width - 2 * visitedCard.pad
                        columns: 2
                        spacing: root.u(10)
                        readonly property real cell: Math.floor((width - spacing) / 2)
                        Repeater {
                            model: root.visited
                            MouseArea {
                                id: place
                                required property var modelData
                                readonly property int noted: Number(root.host?.noteCounts?.[place.modelData.id] ?? 0)
                                width: visitedGrid.cell
                                height: root.u(76)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: Translation.tr(String(place.modelData.title ?? ""))
                                onClicked: root.host.selectSection(place.modelData.id)
                                scale: place.pressed ? 0.97 : 1
                                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: place.containsMouse ? IrisStyle.fillHover : IrisStyle.fill }
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !IrisStyle.fieldChamfer
                                    radius: IrisStyle.radiusTile
                                    color: place.containsMouse ? IrisStyle.fillHover : IrisStyle.fill
                                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                                }
                                MaterialSymbol { x: root.u(12); y: root.u(12); text: String(place.modelData.icon ?? "settings"); iconSize: root.u(18); color: IrisStyle.text }
                                Rectangle { visible: place.noted > 0; x: parent.width - width - root.u(12); y: root.u(14); width: root.u(6); height: width; radius: width / 2; color: root.signal }
                                IrisText {
                                    x: root.u(12)
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: root.u(10)
                                    width: parent.width - root.u(24)
                                    elide: Text.ElideRight
                                    text: Translation.tr(String(place.modelData.title ?? ""))
                                    color: IrisStyle.text
                                    font.pixelSize: IrisStyle.typeMeta
                                    font.weight: IrisStyle.weight(Font.DemiBold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The thumb on its way to the big picture.
    ClippingRectangle {
        id: flight
        property url source
        property string path: ""
        visible: opacity > 0
        opacity: 0
        z: 20
        color: "transparent"
        Image { anchors.fill: parent; source: flight.source; fillMode: Image.PreserveAspectCrop; asynchronous: false }
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(220); easing.type: Easing.OutCubic } }
    }
    ParallelAnimation {
        id: fly
        NumberAnimation { id: flyX; target: flight; property: "x"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { id: flyY; target: flight; property: "y"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { id: flyW; target: flight; property: "width"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { id: flyH; target: flight; property: "height"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        NumberAnimation { id: flyR; target: flight; property: "radius"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
    }
    // It lets go once the picture under it is the new one, or after a while if the switch takes long.
    Timer { id: settle; interval: 2600; onTriggered: flight.opacity = 0 }
    onWallNowChanged: if (flight.opacity > 0 && root.wallNow === flight.path) landed.restart()
    Timer { id: landed; interval: 450; onTriggered: flight.opacity = 0 }

    // A card: a plate with its caption in the Label voice and, at its right, what can be done to it.
    component Card: Item {
        id: card
        property string caption: ""
        property string hint: ""
        property var actions: []
        property bool live: false
        readonly property real pad: root.u(root.voice === "console" ? 18 : 20)
        readonly property real headroom: root.u(46)
        readonly property real radius: IrisStyle.fieldChamfer ? 0 : root.cardRadius
        IrisCutPlate { anchors.fill: parent; visible: IrisStyle.fieldChamfer; color: root.plate; stroke: IrisStyle.hairline; strokeWidth: 1 }
        Rectangle {
            anchors.fill: parent
            visible: !IrisStyle.fieldChamfer
            radius: card.radius
            color: root.plate
            border.width: root.voice === "console" ? 0 : 1
            border.color: IrisStyle.hairline
        }
        Row {
            x: card.pad
            y: root.u(18)
            spacing: root.u(10)
            Rectangle { visible: card.live; anchors.verticalCenter: parent.verticalCenter; width: root.u(6); height: width; radius: width / 2; color: root.signal }
            Mono { text: card.caption; color: IrisStyle.subtext }
            Mono { visible: card.hint.length > 0; text: "·  " + card.hint; color: IrisStyle.textTertiary }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: card.pad - root.u(10)
            y: root.u(10)
            spacing: root.u(2)
            Repeater {
                model: card.actions
                TextKey { required property var modelData; label: modelData.label; onClicked: modelData.run() }
            }
        }
    }
    // A line of the Look card: its name in the Label voice, its control at the right, a hairline under it.
    component Line: Item {
        id: line
        property string name
        property bool last: false
        readonly property real room: line.width - nameText.implicitWidth - root.u(16)
        readonly property int lines: [schemeLine, signalLine, designLine].filter(item => item.visible).length
        width: parent.width
        height: visible ? Math.max(root.u(48), Math.floor((lookCard.height - lookCard.headroom - lookCard.pad + root.u(8)) / Math.max(1, line.lines))) : 0
        Mono { id: nameText; anchors.verticalCenter: parent.verticalCenter; text: line.name; color: IrisStyle.muted }
        Rectangle { visible: !line.last; anchors.bottom: parent.bottom; width: parent.width; height: 1; color: IrisStyle.hairline }
    }
    // The signal: Nothing red, ink, the wallpaper's own (its picture in the dot), or a colour of your own that opens
    // the presets beside it.
    component Swatches: Row {
        id: swatches
        spacing: root.u(8)
        readonly property var current: { Config.revision; return root.signalSpec ? IrisOptions.currentValue(root.signalSpec) : null }
        readonly property var presets: root.signalSpec ? IrisOptions.choicesOf(root.signalSpec).filter(choice => /^#/.test(String(choice.value))) : []
        readonly property bool custom: /^#/.test(String(swatches.current ?? ""))
        property bool open: false
        Swatch { value: "nothing"; name: Translation.tr("Nothing red"); Rectangle { anchors.centerIn: parent; width: root.u(18); height: width; radius: width / 2; color: IrisStyle.signalRed } }
        Swatch { value: "ink"; name: Translation.tr("Ink"); Rectangle { anchors.centerIn: parent; width: root.u(18); height: width; radius: width / 2; color: IrisStyle.text } }
        Swatch {
            value: "wallpaper"
            name: Translation.tr("From wallpaper")
            ClippingRectangle {
                anchors.centerIn: parent
                width: root.u(18); height: width; radius: width / 2
                color: IrisStyle.fillQuiet
                ThumbnailImage {
                    anchors.fill: parent
                    sourcePath: root.wallNow
                    sourceSize: Qt.size(root.u(36), root.u(36))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
        }
        // The presets slide out from the custom dot, the one picked stays beside it.
        Item {
            height: root.u(26)
            width: swatches.open ? presetRow.implicitWidth : 0
            clip: true
            Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
            Row {
                id: presetRow
                anchors.right: parent.right
                spacing: root.u(8)
                Repeater {
                    model: swatches.presets
                    Swatch {
                        required property var modelData
                        value: modelData.value
                        name: Translation.tr(String(modelData.label ?? ""))
                        onPicked: swatches.open = false
                        Rectangle { anchors.centerIn: parent; width: root.u(18); height: width; radius: width / 2; color: parent.modelData.swatch }
                    }
                }
            }
        }
        MouseArea {
            id: customKey
            readonly property bool on: swatches.custom
            width: root.u(26)
            height: width
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Custom")
            onClicked: swatches.open = !swatches.open
            Rectangle {
                anchors.centerIn: parent
                width: customKey.on || swatches.open ? parent.width : root.u(18)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: customKey.on || swatches.open ? Math.max(1, root.u(1.5)) : 0
                border.color: IrisStyle.text
                Behavior on width { NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
            }
            // a hue ring, or the colour picked once there is one
            Shape {
                anchors.centerIn: parent
                width: root.u(18); height: width
                visible: !customKey.on
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: ConicalGradient {
                        centerX: root.u(9); centerY: root.u(9)
                        GradientStop { position: 0; color: "#ff4fa3" } // iris-literal: the custom colour key shows every hue
                        GradientStop { position: 0.25; color: "#ff8a00" } // iris-literal: the custom colour key shows every hue
                        GradientStop { position: 0.5; color: "#36c46b" } // iris-literal: the custom colour key shows every hue
                        GradientStop { position: 0.75; color: "#2f7bf6" } // iris-literal: the custom colour key shows every hue
                        GradientStop { position: 1; color: "#ff4fa3" } // iris-literal: the custom colour key shows every hue
                    }
                    PathAngleArc { centerX: root.u(9); centerY: root.u(9); radiusX: root.u(9); radiusY: root.u(9); startAngle: 0; sweepAngle: 360 }
                }
            }
            Rectangle { visible: customKey.on; anchors.centerIn: parent; width: root.u(18); height: width; radius: width / 2; color: String(swatches.current ?? "#000000") } // iris-literal: fallback before a colour is picked
        }
    }
    component Swatch: MouseArea {
        id: swatch
        property var value
        property string name
        signal picked()
        readonly property bool on: IrisOptions.same(swatch.value, IrisOptions.currentValue(root.signalSpec ?? {}) ?? null) && Config.revision >= 0
        width: root.u(26)
        height: width
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.RadioButton
        Accessible.name: swatch.name
        Accessible.checked: swatch.on
        onClicked: { IrisOptions.commit(root.signalSpec, swatch.value); swatch.picked() }
        Rectangle {
            anchors.centerIn: parent
            width: swatch.on ? parent.width : root.u(18)
            height: width
            radius: width / 2
            color: "transparent"
            border.width: swatch.on ? Math.max(1, root.u(1.5)) : 0
            border.color: IrisStyle.text
            Behavior on width { NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
        }
    }
    component Mono: IrisText {
        font.family: IrisStyle.fontMono
        font.pixelSize: Math.max(10, IrisStyle.typeCaption)
        font.weight: Font.Medium
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Math.round(Math.max(10, IrisStyle.typeCaption) * 0.08)
    }
    // A word that does something: Label voice, a capsule under the pointer.
    component TextKey: MouseArea {
        id: key
        property string label
        width: keyText.implicitWidth + root.u(20)
        height: root.u(28)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.label
        Rectangle { anchors.fill: parent; radius: IrisStyle.capsule(height); color: key.containsMouse ? IrisStyle.fillHover : "transparent" }
        Mono { id: keyText; anchors.centerIn: parent; text: key.label; color: IrisStyle.text }
    }
}
