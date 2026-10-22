pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.settings

// Home, the first entry of every layout: what people change every day (the wallpaper, dark or light, the signal, the
// Design), what needs them now with its fix, and the last things they changed with the control in place, so touching it
// again is the undo. Two columns when there is room, one when there is not.
Item {
    id: root
    property Item host
    property string voice: ""
    readonly property real d: Number(root.host?.d ?? IrisStyle.settingsDensity)
    function u(n: real): int { return Math.round(n * root.d) }
    readonly property bool wide: root.width >= root.u(820)
    readonly property real gap: root.u(root.voice === "console" ? 10 : 14)
    readonly property real cardRadius: root.voice === "console" ? root.u(24) : IrisStyle.radiusSheet
    readonly property color plate: IrisStyle.glassy ? IrisStyle.readingCard : root.voice === "console" ? IrisStyle.fillQuiet : IrisStyle.readingCard
    readonly property color signal: IrisStyle["signal"] ?? IrisStyle.danger
    readonly property alias flick: flick

    function specAt(path: string): var { return IrisOptions.settings.find(spec => spec.path === path && !spec.mirror) ?? null }
    readonly property var schemeSpec: root.specAt("iris.appearance.scheme")
    readonly property var signalSpec: root.specAt("iris.appearance.signal") ?? root.specAt("iris.appearance.accent")
    readonly property var designSpec: root.specAt("iris.appearance.design")

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

            Grid {
                columns: root.wide ? 2 : 1
                columnSpacing: root.gap
                rowSpacing: root.gap
                width: parent.width
                readonly property real lead: root.wide ? Math.floor((width - root.gap) * 0.58) : width

                // ── The wallpaper, dark or light, the signal.
                Card {
                    id: wall
                    width: parent.lead
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
                        spacing: root.u(12)
                        ClippingRectangle {
                            width: parent.width
                            height: Math.round(Math.min(width * 9 / 16, root.u(root.wide ? 250 : 210)))
                            radius: Math.max(root.u(8), wall.radius - wall.pad)
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
                        Item {
                            width: parent.width
                            height: Math.max(scheme.implicitHeight, swatches.height)
                            IrisSegmented {
                                id: scheme
                                visible: root.schemeSpec !== null
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth > 0 ? implicitWidth : options.length * root.u(68), parent.width - swatches.width - root.u(16))
                                voice: root.voice
                                accessibleName: Translation.tr("Scheme")
                                readonly property var words: ({ dark: "Dark", light: "Light", auto: "Auto", ink: "Ink" })
                                options: ["dark", "light", "auto", "ink"]
                                    .filter(value => IrisOptions.choicesOf(root.schemeSpec ?? {}).some(choice => choice.value === value))
                                    .map(value => ({ label: Translation.tr(scheme.words[value]), value: value }))
                                current: { Config.revision; return root.schemeSpec ? IrisOptions.currentValue(root.schemeSpec) : "" }
                                onPicked: value => IrisOptions.commit(root.schemeSpec, value)
                            }
                            Row {
                                id: swatches
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.u(8)
                                readonly property var current: { Config.revision; return root.signalSpec ? IrisOptions.currentValue(root.signalSpec) : null }
                                Repeater {
                                    model: root.signalSpec ? IrisOptions.choicesOf(root.signalSpec).filter(choice => choice.swatch !== undefined).slice(0, 5) : []
                                    MouseArea {
                                        id: swatch
                                        required property var modelData
                                        readonly property bool on: IrisOptions.same(swatch.modelData.value, swatches.current)
                                        width: root.u(26)
                                        height: width
                                        cursorShape: Qt.PointingHandCursor
                                        Accessible.role: Accessible.RadioButton
                                        Accessible.name: Translation.tr(String(swatch.modelData.label ?? ""))
                                        Accessible.checked: swatch.on
                                        onClicked: IrisOptions.commit(root.signalSpec, swatch.modelData.value)
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
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: root.u(18)
                                            height: width
                                            radius: width / 2
                                            color: swatch.modelData.swatch ?? IrisStyle.fill
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: parent.lead === parent.width ? parent.width : parent.width - parent.lead - root.gap
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
                                        x: needText.x
                                        anchors.top: needText.bottom
                                        anchors.topMargin: root.u(4)
                                        spacing: root.u(12)
                                        IrisText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Translation.tr(String(need.modelData.area ?? ""))
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

                    // ── The Design: iRiS or AIRISU, the whole look at once.
                    Card {
                        id: designCard
                        visible: root.designSpec !== null && IrisOptions.shown(root.designSpec)
                        width: parent.width
                        height: designBody.implicitHeight + designCard.headroom + designCard.pad
                        caption: Translation.tr("Design")
                        Column {
                            id: designBody
                            x: designCard.pad
                            y: designCard.headroom
                            width: designCard.width - 2 * designCard.pad
                            spacing: root.u(10)
                            IrisSegmented {
                                width: Math.min(implicitWidth > 0 ? implicitWidth : options.length * root.u(84), parent.width)
                                voice: root.voice
                                accessibleName: Translation.tr("Design")
                                options: root.designSpec ? IrisOptions.choicesOf(root.designSpec).map(choice => ({ label: Translation.tr(String(choice.label ?? "")), value: choice.value })) : []
                                current: { Config.revision; return root.designSpec ? IrisOptions.currentValue(root.designSpec) : "" }
                                onPicked: value => IrisOptions.commit(root.designSpec, value)
                            }
                            IrisText {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: Translation.tr(String(root.designSpec?.description ?? ""))
                                color: IrisStyle.muted
                                font.pixelSize: IrisStyle.typeMeta
                            }
                        }
                    }
                }
            }

            // ── What you changed last, each with its control: touch it to set it back.
            Card {
                id: recentCard
                width: parent.width
                height: recentBody.implicitHeight + recentCard.headroom + root.u(6)
                caption: Translation.tr("Recently changed")
                hint: Translation.tr("Undo in place")
                Column {
                    id: recentBody
                    x: root.u(4)
                    y: recentCard.headroom - root.u(6)
                    width: recentCard.width - root.u(8)
                    IrisText {
                        visible: root.recent.length === 0
                        x: recentCard.pad - root.u(4)
                        width: parent.width - 2 * x
                        height: implicitHeight + root.u(16)
                        topPadding: root.u(6)
                        wrapMode: Text.WordWrap
                        text: Translation.tr("What you change shows up here, ready to set back.")
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeBody
                    }
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
                                Rectangle { anchors.fill: parent; radius: width / 2; color: undo.containsMouse ? IrisStyle.fillHover : "transparent" }
                                MaterialSymbol { anchors.centerIn: parent; text: "undo"; iconSize: root.u(18); color: undo.containsMouse ? IrisStyle.text : IrisStyle.muted }
                            }
                        }
                    }
                }
            }
        }
    }

    // A card: a plate with its caption in the Label voice and, at its right, what can be done to it.
    component Card: Rectangle {
        id: card
        property string caption: ""
        property string hint: ""
        property var actions: []
        property bool live: false
        readonly property real pad: root.u(root.voice === "console" ? 18 : 20)
        readonly property real headroom: root.u(48)
        radius: root.cardRadius
        color: root.plate
        border.width: root.voice === "console" ? 0 : 1
        border.color: IrisStyle.hairline
        Behavior on height { enabled: root.visible; NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
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
        Rectangle { anchors.fill: parent; radius: height / 2; color: key.containsMouse ? IrisStyle.fillHover : "transparent" }
        Mono { id: keyText; anchors.centerIn: parent; text: key.label; color: IrisStyle.text }
    }
}
