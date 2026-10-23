pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Material's face on the shared widget shelf: its surfaces and type, filter chips for the aisles, a search field and the
// widget settings key; widgets are found by the start of a word in their name or keywords.
QtObject {
    id: face

    readonly property real d: 1
    readonly property color ink: Appearance.colors.colOnLayer1
    readonly property color subtext: Appearance.colors.colSubtext
    readonly property color muted: ColorUtils.applyAlpha(Appearance.colors.colSubtext, 0.7)
    readonly property color accent: Appearance.colors.colPrimary
    readonly property color inkOnAccent: Appearance.colors.colOnPrimary
    readonly property color fillQuiet: Appearance.colors.colLayer2
    readonly property color fillActive: Appearance.colors.colLayer2Hover
    readonly property color raised: Appearance.colors.colLayer3
    readonly property color hairline: Appearance.colors.colOutlineVariant
    readonly property color hairlineStrong: Appearance.colors.colOutline
    readonly property string fontMain: Appearance.font.family.main
    readonly property real typeMeta: Appearance.font.pixelSize.smaller
    readonly property real typeBody: Appearance.font.pixelSize.small
    readonly property real plateRadius: Appearance.rounding.normal
    readonly property var morphCurve: Appearance.animation.elementMove.bezierCurve
    readonly property int feedbackEasing: Easing.OutCubic
    function duration(ms: int): int { return Appearance.animationsEnabled ? ms : 0 }
    function pressScale(s: real): real { return s }
    function weight(w: int): int { return w }

    readonly property var names: ({ clock: Translation.tr("Clock"), weather: Translation.tr("Weather"),
        mediaControls: Translation.tr("Now Playing"), controls: Translation.tr("Controls"), monthCalendar: Translation.tr("Calendar"),
        calendarUpcoming: Translation.tr("Up next"), todo: Translation.tr("Tasks"), notes: Translation.tr("Notes"),
        timers: Translation.tr("Timers"), screenTime: Translation.tr("Screen Time"), systemMonitor: Translation.tr("Vitals"),
        battery: Translation.tr("Batteries"), worldClock: Translation.tr("World clock"), dayProgress: Translation.tr("Day"),
        dateBadge: Translation.tr("Date"), userCard: Translation.tr("Profile"), uptime: Translation.tr("Uptime"),
        newsTicker: Translation.tr("News"), visualizer: Translation.tr("Visualizer"), editorial: Translation.tr("Editorial"),
        mascot: Translation.tr("Mascot"), japaneseTypography: Translation.tr("Japanese Typography"), customImage: Translation.tr("Image"),
        imageConverter: Translation.tr("Image converter"), shape: Translation.tr("Shape") })
    function nameOf(key: string): string { return face.names[key] ?? key }

    function fold(text: string): string { return String(text ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }
    function prepare(entry: var): var {
        entry.folded = face.fold(entry.name + " " + entry.english)
        entry.tokens = face.fold([entry.name, entry.english, entry.words].join(" ")).split(/[^a-z0-9]+/).filter(t => t.length > 0)
        return entry
    }
    function score(query: string, entry: var): real {
        const words = face.fold(query).split(/[^a-z0-9]+/).filter(w => w.length > 0)
        if (words.length === 0) return 0
        let sum = 0
        for (const word of words) {
            let best = 0
            if (entry.folded.startsWith(word)) best = 3
            else if (entry.tokens.some(t => t.startsWith(word))) best = 2
            else if (entry.folded.indexOf(word) >= 0) best = 1
            if (best === 0) return 0
            sum += best
        }
        return sum / words.length
    }

    readonly property Component head: Component {
        Item {
            id: head
            property var shelf: null
            function focusSearch(): void { searchInput.forceActiveFocus() }
            function dropSearch(): void { searchInput.focus = false }

            Row {
                id: chips
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: head.shelf?.categories ?? []
                    delegate: RippleButton {
                        id: chip
                        required property var modelData
                        readonly property bool chosen: (head.shelf?.query.length ?? 0) === 0 && head.shelf?.category === chip.modelData.value
                        implicitHeight: 30
                        implicitWidth: chipLabel.implicitWidth + (chip.chosen ? 40 : 24)
                        buttonRadius: Appearance.rounding.small
                        colBackground: chip.chosen ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: chip.chosen ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                        Behavior on implicitWidth { NumberAnimation { duration: face.duration(160); easing.type: Easing.OutCubic } }
                        onClicked: head.shelf.pick(chip.modelData.value)
                        Accessible.name: chip.modelData.label
                        contentItem: Item {
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: "transparent"
                                border.width: chip.chosen ? 0 : 1
                                border.color: Appearance.colors.colOutlineVariant
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: chip.chosen
                                    text: "check"
                                    iconSize: 16
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                StyledText {
                                    id: chipLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: chip.modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: chip.chosen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: searchBox
                anchors.right: settingsKey.left
                anchors.rightMargin: 8
                width: 260
                height: head.height
                radius: Appearance.rounding.full
                color: Appearance.colors.colLayer2
                border.width: searchInput.activeFocus ? 2 : 0
                border.color: Appearance.colors.colPrimary
                MaterialSymbol {
                    id: searchGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "search"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
                TextInput {
                    id: searchInput
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: GlobalStates.widgetSearchText
                    onTextEdited: GlobalStates.widgetSearchText = searchInput.text
                    onActiveFocusChanged: if (head.shelf) head.shelf.searchFocused = searchInput.activeFocus
                    color: Appearance.colors.colOnLayer2
                    selectionColor: Appearance.colors.colPrimaryContainer
                    selectedTextColor: Appearance.colors.colOnPrimaryContainer
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    clip: true
                    Accessible.name: Translation.tr("Search widgets")
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) head.shelf.move(1)
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) head.shelf.move(-1)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) head.shelf.takeHighlighted()
                        else if (event.key === Qt.Key_Escape) head.shelf.escapeSearch()
                        else return
                        event.accepted = true
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text.length === 0
                        text: Translation.tr("Search widgets")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
                TapHandler { onTapped: searchInput.forceActiveFocus() }
                HoverHandler { cursorShape: Qt.IBeamCursor }
            }

            RippleButton {
                id: settingsKey
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                Accessible.name: Translation.tr("Widget settings")
                onClicked: GlobalStates.openSettingsAt("widgets")
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "tune"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }
            }
        }
    }
}
