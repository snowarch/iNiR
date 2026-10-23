pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.shared.background.edit
import qs.modules.shared.background.widgets
import qs.modules.iris.style
import qs.modules.iris.settings
import qs.modules.iris.widgets
import qs.modules.iris.components

// iRiS's face on the shared shelf: its aisles slide a segmented thumb, the search is Spotlight's matcher, the plates are
// concentric with the drawer's body.
WidgetShelf {
    id: root

    property real bodyRadius: IrisStyle.radius

    entries: {
        const list = IrisFaceData.galleryEntries.concat(IrisFaceData.otherEntries).map(entry => IrisSearch.prepare({
            key: entry.key, glyph: entry.glyph, name: entry.label, english: entry.english, tint: entry.tint,
            words: entry.key + " " + DesktopWidgetIdentity.keywordsOf(entry.key), category: DesktopWidgetIdentity.categoryOf(entry.key) }))
        for (const custom of (CustomWidgets.ready ? CustomWidgets.widgets : []))
            list.push(IrisSearch.prepare({ key: "custom." + custom.id, glyph: custom.icon || "widgets", name: custom.name,
                english: custom.name, tint: DesktopWidgetIdentity.customTint, words: "custom hub", category: "decor" }))
        return list
    }

    face: QtObject {
        readonly property real d: IrisStyle.density
        readonly property color ink: IrisStyle.text
        readonly property color subtext: IrisStyle.subtext
        readonly property color muted: IrisStyle.muted
        readonly property color accent: IrisStyle.accent
        readonly property color inkOnAccent: IrisStyle.inkOnAccent
        readonly property color fillQuiet: IrisStyle.fillQuiet
        readonly property color fillActive: IrisStyle.fillActive
        readonly property color raised: IrisStyle.raised
        readonly property color hairline: IrisStyle.hairline
        readonly property color hairlineStrong: IrisStyle.hairlineStrong
        readonly property string fontMain: IrisStyle.fontMain
        readonly property real typeMeta: IrisStyle.typeMeta
        readonly property real typeBody: IrisStyle.typeBody
        readonly property real plateRadius: IrisStyle.concentric(root.bodyRadius, root.pad, Math.round(10 * IrisStyle.density))
        readonly property var morphCurve: IrisStyle.morphCurve
        readonly property int feedbackEasing: IrisStyle.feedbackEasing
        function duration(ms: int): int { return IrisStyle.duration(ms) }
        function pressScale(s: real): real { return IrisStyle.pressScale(s) }
        function weight(w: int): int { return IrisStyle.weight(w) }
        function score(query: string, entry: var): real { return IrisSearch.score(query, entry) }
        readonly property Component head: Component {
            Item {
                id: head
                property var shelf: null
                readonly property real d: IrisStyle.density
                function focusSearch(): void { searchInput.forceActiveFocus() }
                function dropSearch(): void { searchInput.focus = false }

                IrisSegmented {
                    id: aisles
                    y: Math.round((head.height - height) / 2)
                    width: Math.min(aisles.fitWidth, head.width - searchBox.width - settingsButton.width - Math.round(20 * head.d))
                    options: head.shelf?.categories ?? []
                    current: (head.shelf?.query.length ?? 0) > 0 ? "" : (head.shelf?.category ?? "all")
                    accessibleName: Translation.tr("Widget kinds")
                    onPicked: value => head.shelf.pick(value)
                }

                Rectangle {
                    id: searchBox
                    anchors.right: settingsButton.left
                    anchors.rightMargin: Math.round(8 * head.d)
                    width: Math.round(240 * head.d)
                    height: head.height
                    radius: IrisStyle.capsule(height)
                    color: searchInput.activeFocus ? IrisStyle.fillActive : IrisStyle.fillQuiet
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: IrisStyle.accent
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    MaterialSymbol {
                        id: searchGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(10 * head.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        iconSize: Math.round(16 * head.d)
                        color: IrisStyle.muted
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Math.round(6 * head.d)
                        anchors.right: clearGlyph.visible ? clearGlyph.left : parent.right
                        anchors.rightMargin: Math.round(10 * head.d)
                        anchors.verticalCenter: parent.verticalCenter
                        text: GlobalStates.widgetSearchText
                        onTextEdited: GlobalStates.widgetSearchText = searchInput.text
                        onActiveFocusChanged: if (head.shelf) head.shelf.searchFocused = searchInput.activeFocus
                        color: IrisStyle.text
                        selectionColor: IrisStyle.tintFillHover(IrisStyle.accent)
                        selectedTextColor: IrisStyle.text
                        font.family: IrisStyle.fontMain
                        font.pixelSize: IrisStyle.typeMeta
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
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text.length === 0
                            text: Translation.tr("Search widgets")
                            color: IrisStyle.muted
                            font.pixelSize: IrisStyle.typeMeta
                        }
                    }
                    MaterialSymbol {
                        id: clearGlyph
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(8 * head.d)
                        anchors.verticalCenter: parent.verticalCenter
                        visible: GlobalStates.widgetSearchText.length > 0
                        text: "close"
                        iconSize: Math.round(14 * head.d)
                        color: IrisStyle.muted
                        TapHandler { onTapped: { GlobalStates.widgetSearchText = ""; searchInput.forceActiveFocus() } }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                    TapHandler { onTapped: searchInput.forceActiveFocus() }
                    HoverHandler { cursorShape: Qt.IBeamCursor }
                }

                IrisIconButton {
                    id: settingsButton
                    anchors.right: parent.right
                    y: Math.round((head.height - height) / 2)
                    implicitWidth: head.height
                    materialIcon: "tune"
                    iconSize: Math.round(16 * head.d)
                    Accessible.name: Translation.tr("Widget settings")
                    onClicked: GlobalStates.openSettingsAt("widgets")
                }
            }
        }
    }
}
