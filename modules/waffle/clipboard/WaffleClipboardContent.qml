pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks

Item {
    id: root
    signal closed

    property string searchText: ""
    property int totalCount: 0
    property string lastCopiedEntry: ""
    property bool showClearConfirmation: false

    implicitWidth: pane.implicitWidth + 24
    implicitHeight: pane.implicitHeight + 24

    function close() {
        root.closed()
    }

    function formatCliphistName(entry: string): string {
        let cleaned = StringUtils.cleanCliphistEntry(entry)
        if (Cliphist.entryIsImage(entry)) {
            cleaned = cleaned.replace(/^\s*\[\[.*?\]\]\s*/, "")
        }
        const unwrapped = StringUtils.cliphistMarkupPreview(cleaned)
        if (unwrapped !== cleaned)
            cleaned = unwrapped.length > 0 ? unwrapped : Translation.tr("Rich text")
        return cleaned.trim()
    }

    function updateFilteredModel() {
        filteredClipboardModel.clear()
        const trimmedSearch = searchText.trim().toLowerCase()

        // Pinned entries always lead the list.
        const pins = Cliphist.pinned
        for (let i = 0; i < pins.length; i++) {
            if (trimmedSearch.length === 0
                || Cliphist.pinPreview(pins[i]).toLowerCase().includes(trimmedSearch)) {
                filteredClipboardModel.append({ "rawEntry": "", "pinText": pins[i], "isPinRow": true })
            }
        }

        for (let i = 0; i < Cliphist.entries.length; i++) {
            const entry = Cliphist.entries[i]
            if (trimmedSearch.length === 0) {
                filteredClipboardModel.append({ "rawEntry": entry, "pinText": "", "isPinRow": false })
            } else {
                const content = formatCliphistName(entry).toLowerCase()
                if (content.includes(trimmedSearch)) {
                    filteredClipboardModel.append({ "rawEntry": entry, "pinText": "", "isPinRow": false })
                }
            }
        }

        totalCount = filteredClipboardModel.count
        if (totalCount > 0) {
            clipboardList.currentIndex = 0
        }
    }

    // Assigning currentIndex only moves the view once it has laid out, which it
    // has not while the model is still being rebuilt. positionViewAtBeginning()
    // forces that layout, so it is the only thing that reliably puts contentY
    // back at the top after a rebuild.
    property bool pendingViewReset: false

    function resetViewPosition(): void {
        clipboardList.currentIndex = filteredClipboardModel.count > 0 ? 0 : -1
        clipboardList.positionViewAtBeginning()
    }

    function copyEntry(entry: string) {
        lastCopiedEntry = entry
        Cliphist.copy(entry)
        GlobalStates.waffleClipboardOpen = false
    }

    function copyPinnedText(text: string) {
        Quickshell.clipboardText = text
        GlobalStates.waffleClipboardOpen = false
    }

    function activateRow(row) {
        if (row.isPin) root.copyPinnedText(row.pinText)
        else root.copyEntry(row.rawEntry)
    }

    function deleteEntry(entry: string) {
        Cliphist.deleteEntry(entry)
    }

    function clearAll() {
        if (!showClearConfirmation) {
            showClearConfirmation = true
            return
        }
        Cliphist.wipe()
        showClearConfirmation = false
        // Reset model and count immediately so the UI reflects the wipe
        // (the async refresh would miss because the panel closes below)
        filteredClipboardModel.clear()
        totalCount = 0
        GlobalStates.waffleClipboardOpen = false
    }

    function cancelClear() {
        showClearConfirmation = false
    }

    function refresh() {
        Cliphist.refresh()
    }

    Component.onCompleted: {
        // This is the open path. The panel is created by a Loader that activates
        // on waffleClipboardOpenChanged, so this component does not exist yet
        // when that signal is delivered and its own handler for it never fires
        // on open — only on close, right before the Loader tears it down.
        //
        // Cliphist is a shared singleton whose entries went stale while the panel
        // was gone, so refresh here or the list opens showing the order it had
        // last time, with anything copied since missing entirely.
        root.pendingViewReset = true
        updateFilteredModel()
        Cliphist.refresh()
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            // Only update model if clipboard panel is open to avoid lag
            if (!GlobalStates.waffleClipboardOpen) return
            root.updateFilteredModel()
            Qt.callLater(() => searchInput.forceActiveFocus())
            // The refresh started on open is asynchronous: these entries land
            // once the panel is already on screen and rebuild the model under it.
            if (root.pendingViewReset) {
                root.pendingViewReset = false
                Qt.callLater(root.resetViewPosition)
            }
        }
        function onPinnedChanged() {
            if (GlobalStates.waffleClipboardOpen) root.updateFilteredModel()
        }
    }

    Connections {
        target: GlobalStates
        function onWaffleClipboardOpenChanged() {
            if (GlobalStates.waffleClipboardOpen) {
                root.searchText = ""
                root.showClearConfirmation = false
                root.pendingViewReset = true
                root.updateFilteredModel()  // Update immediately with current entries
                root.resetViewPosition()
                // Refrescar el servicio Cliphist para obtener datos actualizados
                Cliphist.refresh()
            } else {
                root.pendingViewReset = false
            }
        }
    }

    ListModel {
        id: filteredClipboardModel
    }

    WPane {
        id: pane
        anchors.centerIn: parent
        radius: Looks.radius.large
        screenX: (Quickshell.screens[0]?.width ?? 1920) / 2 - pane.width / 2
        screenY: (Quickshell.screens[0]?.height ?? 1080) / 2 - pane.height / 2
        screenWidth: Quickshell.screens[0]?.width ?? 1920
        screenHeight: Quickshell.screens[0]?.height ?? 1080

        contentItem: ColumnLayout {
            spacing: 0

            // Header with search
            FooterRectangle {
                Layout.fillWidth: true
                implicitHeight: 56
                color: Looks.colors.bgPanelFooter

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 12
                    spacing: 12

                    FluentIcon {
                        icon: "cut"
                        implicitSize: 20
                    }

                    WText {
                        text: Translation.tr("Clipboard history")
                        font.pixelSize: Looks.font.pixelSize.larger
                        font.weight: Looks.font.weight.strong
                    }

                    Item { Layout.fillWidth: true }

                    // Normal state: count + clear button
                    WText {
                        visible: !root.showClearConfirmation
                        text: `${root.totalCount}`
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.normal
                    }

                    WPanelIconButton {
                        visible: !root.showClearConfirmation
                        iconName: "delete"
                        onClicked: root.clearAll()
                        WToolTip {
                            text: Translation.tr("Clear all")
                        }
                    }

                    // Confirmation state
                    WText {
                        visible: root.showClearConfirmation
                        text: Translation.tr("Clear all?")
                        color: Looks.colors.danger
                        font.pixelSize: Looks.font.pixelSize.normal
                    }

                    WPanelIconButton {
                        visible: root.showClearConfirmation
                        iconName: "checkmark"
                        onClicked: root.clearAll()
                        WToolTip {
                            text: Translation.tr("Confirm")
                        }
                    }

                    WPanelIconButton {
                        visible: root.showClearConfirmation
                        iconName: "dismiss"
                        onClicked: root.cancelClear()
                        WToolTip {
                            text: Translation.tr("Cancel")
                        }
                    }

                    WPanelIconButton {
                        iconName: "dismiss"
                        onClicked: root.close()
                        WToolTip {
                            text: Translation.tr("Close")
                        }
                    }
                }
            }

            // Search bar
            FooterRectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                color: Looks.colors.bgPanelFooter

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    radius: height / 2
                    color: Looks.colors.inputBg
                    border.width: 1
                    border.color: Looks.colors.bg2Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        WAppIcon {
                            iconName: "system-search-checked"
                            separateLightDark: true
                            implicitSize: 16
                        }

                        WTextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            focus: true

                            Keys.onUpPressed: event => {
                                if (clipboardList.currentIndex > 0) {
                                    clipboardList.currentIndex--
                                    clipboardList.positionViewAtIndex(clipboardList.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }
                            Keys.onDownPressed: event => {
                                if (clipboardList.currentIndex < clipboardList.count - 1) {
                                    clipboardList.currentIndex++
                                    clipboardList.positionViewAtIndex(clipboardList.currentIndex, ListView.Contain)
                                }
                                event.accepted = true
                            }
                            Keys.onReturnPressed: event => {
                                if (clipboardList.currentIndex >= 0 && clipboardList.currentIndex < filteredClipboardModel.count) {
                                    root.activateRow(filteredClipboardModel.get(clipboardList.currentIndex))
                                }
                                event.accepted = true
                            }
                            Keys.onEnterPressed: event => Keys.onReturnPressed(event)
                            Keys.onEscapePressed: event => {
                                root.close()
                                event.accepted = true
                            }

                            onTextChanged: {
                                root.searchText = text
                                root.updateFilteredModel()
                            }

                            WText {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: Looks.colors.accentUnfocused
                                text: Translation.tr("Search clipboard...")
                                visible: searchInput.text.length === 0
                                font.pixelSize: Looks.font.pixelSize.normal
                            }
                        }
                    }
                }
            }

            // Clipboard list
            BodyRectangle {
                Layout.fillWidth: true
                implicitWidth: 450
                implicitHeight: 450

                ListView {
                    id: clipboardList
                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true
                    spacing: 4
                    highlightMoveDuration: 100
                    currentIndex: 0

                    model: filteredClipboardModel

                    highlight: Rectangle {
                        color: Looks.colors.bg1
                        radius: Looks.radius.medium
                    }

                    delegate: WaffleClipboardItem {
                        id: itemDelegate
                        required property string rawEntry
                        required property string pinText
                        required property bool isPinRow
                        required property int index

                        width: clipboardList.width
                        entry: rawEntry
                        isPin: itemDelegate.isPinRow
                        pinnedText: itemDelegate.pinText
                        isSelected: clipboardList.currentIndex === index
                        isCopied: !itemDelegate.isPinRow && rawEntry === root.lastCopiedEntry
                        searchQuery: root.searchText

                        onClicked: itemDelegate.isPinRow ? root.copyPinnedText(itemDelegate.pinText) : root.copyEntry(rawEntry)
                        onDeleteRequested: root.deleteEntry(rawEntry)
                        // Toggle, not "pin again": an entry that is already pinned
                        // must unpin, whether it is the pinned row or the history
                        // row that backs it.
                        onPinToggleRequested: {
                            const pinnedAs = itemDelegate.isPinRow
                                ? itemDelegate.pinText
                                : Cliphist.pinnedTextFor(rawEntry)
                            if (pinnedAs.length > 0) Cliphist.unpin(pinnedAs)
                            else Cliphist.pinEntry(rawEntry)
                        }

                        onHoveredChanged: {
                            if (hovered) clipboardList.currentIndex = index
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: clipboardList.count === 0
                        spacing: 8

                        MascotImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 96
                            surface: "clipboard"
                            fallbackSurface: "emptyStates"
                            pose: root.searchText.length > 0 ? "fisheye-inspect" : "box-hideout"
                        }

                        WText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.searchText.length > 0
                                ? Translation.tr("No results found")
                                : Translation.tr("Clipboard is empty")
                            color: Looks.colors.subfg
                        }
                    }
                }
            }

            // Footer with keyboard hints
            FooterRectangle {
                Layout.fillWidth: true
                implicitHeight: 36

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 16

                    WText {
                        text: "↑↓ " + Translation.tr("Navigate")
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                    }
                    WText {
                        text: "Enter " + Translation.tr("Paste")
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                    }
                    WText {
                        text: "Del " + Translation.tr("Delete")
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                    }
                    Item { Layout.fillWidth: true }
                    WText {
                        text: "Esc " + Translation.tr("Close")
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.close()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Delete) {
            if (clipboardList.currentIndex >= 0 && clipboardList.currentIndex < filteredClipboardModel.count) {
                const row = filteredClipboardModel.get(clipboardList.currentIndex)
                if (row.isPinRow) Cliphist.unpin(row.pinText)
                else root.deleteEntry(row.rawEntry)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            if (clipboardList.currentIndex >= 0 && clipboardList.currentIndex < filteredClipboardModel.count) {
                const row = filteredClipboardModel.get(clipboardList.currentIndex)
                const pinnedAs = row.isPinRow ? row.pinText : Cliphist.pinnedTextFor(row.rawEntry)
                // Ctrl+P is a toggle: on an already-pinned entry it used to pin again.
                if (pinnedAs.length > 0) Cliphist.unpin(pinnedAs)
                else if (Cliphist.isPinnable(row.rawEntry)) Cliphist.pinEntry(row.rawEntry)
            }
            event.accepted = true
        }
    }
}
