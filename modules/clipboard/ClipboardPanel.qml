import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.overview as OverviewModule
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

Scope {
    id: root

    property int panelWidth: 600
    property int panelMaxHeight: 700
    property string searchText: ""
    property int totalCount: 0
    property bool showKeyboardHints: false
    property string lastCopiedEntry: ""
    property bool showClearConfirmation: false

    function formatCliphistName(entry) {
        let cleaned = StringUtils.cleanCliphistEntry(entry)
        if (Cliphist.entryIsImage(entry)) {
            cleaned = cleaned.replace(/^\s*\[\[.*?\]\]\s*/, "")
        }
        return cleaned.trim()
    }

    function updateFilteredModel() {
        // Cache entries locally to avoid repeated property lookups
        const entries = Cliphist.entries
        const entryCount = entries.length
        
        filteredClipboardModel.clear()

        const trimmedSearch = searchText.trim().toLowerCase()
        const hasSearch = trimmedSearch.length > 0

        // Build filtered list
        for (let i = 0; i < entryCount; i++) {
            const entry = entries[i]
            if (!hasSearch) {
                filteredClipboardModel.append({ "rawEntry": entry })
            } else {
                const content = formatCliphistName(entry).toLowerCase()
                if (content.includes(trimmedSearch)) {
                    filteredClipboardModel.append({ "rawEntry": entry })
                }
            }
        }

        // Update count once at the end (avoids binding re-evaluations)
        totalCount = filteredClipboardModel.count

        if (totalCount > 0 && typeof listView !== "undefined" && listView) {
            listView.currentIndex = 0
        }
    }

    function open() {
        GlobalStates.clipboardOpen = true
    }

    function close() {
        GlobalStates.clipboardOpen = false
    }

    function toggle() {
        GlobalStates.clipboardOpen = !GlobalStates.clipboardOpen
    }

    function copyEntry(entry) {
        console.log("[ClipboardPanel] copyEntry", String(entry).slice(0, 120))
        lastCopiedEntry = entry
        Cliphist.copy(entry)
        GlobalStates.clipboardOpen = false
    }

    function deleteEntry(entry) {
        Cliphist.deleteEntry(entry)
    }

    function clearAll() {
        if (!showClearConfirmation) {
            showClearConfirmation = true
            return
        }
        Cliphist.wipe()
        showClearConfirmation = false
        GlobalStates.clipboardOpen = false
    }

    function cancelClear() {
        showClearConfirmation = false
    }

    function refresh() {
        console.log("[ClipboardPanel] Refreshing clipboard via Cliphist service...")
        Cliphist.refresh()
    }

    Component.onCompleted: {
        refresh()
        updateFilteredModel()
    }

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            // Only update model if clipboard panel is open to avoid lag
            if (GlobalStates.clipboardOpen) {
                root.updateFilteredModel()
            }
        }
    }

    ListModel {
        id: filteredClipboardModel
    }

    Connections {
        target: GlobalStates
        function onClipboardOpenChanged() {
            if (GlobalStates.clipboardOpen) {
                root.refresh()
                root.updateFilteredModel()  // Update immediately with current entries
                root.searchText = ""
                root.showClearConfirmation = false
                Qt.callLater(() => searchField.forceActiveFocus())
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        enabled: Config.options?.panelFamily !== "waffle"
        function open(): void {
            root.open()
        }
        function close(): void {
            root.close()
        }
        function toggle(): void {
            root.toggle()
        }
    }

    PanelWindow {
        id: window

        Component.onCompleted: visible = GlobalStates.clipboardOpen

        Connections {
            target: GlobalStates
            function onClipboardOpenChanged() {
                if (GlobalStates.clipboardOpen) {
                    _closeTimer.stop()
                    window.visible = true
                } else {
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: 180
            onTriggered: window.visible = false
        }

        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell:clipboardPanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.clipboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: GlobalStates.clipboardOpen

            Keys.onPressed: function (event) {
                if (!GlobalStates.clipboardOpen)
                    return

                // Helper to get current entry from filtered model
                function currentEntry() {
                    const idx = listView.currentIndex
                    if (idx < 0 || idx >= filteredClipboardModel.count)
                        return null
                    return filteredClipboardModel.get(idx).rawEntry
                }

                if (event.key === Qt.Key_Escape) {
                    GlobalStates.clipboardOpen = false
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    // Paste current entry and close
                    listView.activateCurrent()
                    event.accepted = true
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    listView.moveNext()
                    event.accepted = true
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    listView.movePrevious()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                    // Clear all history (Shift+Del)
                    root.clearAll()
                    event.accepted = true
                } else if (event.key === Qt.Key_Delete && event.modifiers === Qt.NoModifier) {
                    // Delete current entry
                    const entry = currentEntry()
                    if (entry !== null) {
                        root.deleteEntry(entry)
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                    // Copy current entry to clipboard
                    const entry = currentEntry()
                    if (entry !== null) {
                        root.copyEntry(entry)
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_F10) {
                    // Toggle keyboard hints
                    root.showKeyboardHints = !root.showKeyboardHints
                    event.accepted = true
                }
            }
        }

        StyledRectangularShadow {
            target: panelBackground
            radius: panelBackground.radius
            visible: Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere)
        }

        // Click outside the panel to close
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: mouse => {
                const localPos = mapToItem(panelBackground, mouse.x, mouse.y)
                const outside = (localPos.x < 0 || localPos.x > panelBackground.width
                        || localPos.y < 0 || localPos.y > panelBackground.height)
                if (outside) {
                    GlobalStates.clipboardOpen = false
                } else {
                    mouse.accepted = false
                }
            }
        }

        GlassBackground {
            id: panelBackground
            anchors.centerIn: parent
            width: panelWidth
            height: Math.min(contentColumn.implicitHeight, panelMaxHeight)
            fallbackColor: Appearance.colors.colLayer1
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.aurora.popupTransparentize
            screenX: (window.screen?.width ?? 1920) / 2 - width / 2
            screenY: (window.screen?.height ?? 1080) / 2 - height / 2
            screenWidth: window.screen?.width ?? 1920
            screenHeight: window.screen?.height ?? 1080
            border.width: Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth
                : Appearance.auroraEverywhere ? 1 : 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder 
                : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder 
                : Appearance.colors.colOutlineVariant
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.screenRounding
            
            // Entry animation
            opacity: GlobalStates.clipboardOpen ? 1 : 0
            scale: GlobalStates.clipboardOpen ? 1 : 0.95
            
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Toolbar {
                    id: headerToolbar
                    Layout.fillWidth: true
                    enableShadow: false
                    transparent: Appearance.angelEverywhere || Appearance.auroraEverywhere

                    MaterialSymbol {
                        text: "content_paste"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Clipboard history") + ` (${root.totalCount})`
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.m3colors.m3onSurface
                        elide: Text.ElideRight
                    }

                    ToolbarTextField {
                        id: searchField
                        Layout.fillWidth: true
                        implicitHeight: 40
                        focus: true
                        text: root.searchText
                        placeholderText: Translation.tr("Search clipboard history")
                        onTextChanged: {
                            root.searchText = text
                            root.updateFilteredModel()
                        }
                        Keys.onEscapePressed: function(event) {
                            GlobalStates.clipboardOpen = false
                            event.accepted = true
                        }
                        Keys.onUpPressed: function(event) {
                            listView.movePrevious()
                            event.accepted = true
                        }
                        Keys.onDownPressed: function(event) {
                            listView.moveNext()
                            event.accepted = true
                        }
                        Keys.onReturnPressed: function(event) {
                            listView.activateCurrent()
                            event.accepted = true
                        }
                        Keys.onEnterPressed: function(event) {
                            listView.activateCurrent()
                            event.accepted = true
                        }
                    }

                    IconToolbarButton {
                        implicitWidth: height
                        onClicked: {
                            root.showKeyboardHints = !root.showKeyboardHints
                        }
                        text: "help"
                        StyledToolTip {
                            text: Translation.tr("Keyboard hints")
                        }
                    }

                    // Normal state: delete button
                    IconToolbarButton {
                        visible: !root.showClearConfirmation
                        implicitWidth: height
                        onClicked: root.clearAll()
                        text: "delete"
                        StyledToolTip {
                            text: Translation.tr("Clear all")
                        }
                    }

                    StyledText {
                        visible: root.showClearConfirmation
                        text: Translation.tr("Clear all?")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError
                    }

                    IconToolbarButton {
                        visible: root.showClearConfirmation
                        implicitWidth: height
                        onClicked: root.clearAll()
                        text: "check"
                        StyledToolTip {
                            text: Translation.tr("Confirm")
                        }
                    }

                    IconToolbarButton {
                        visible: root.showClearConfirmation
                        implicitWidth: height
                        onClicked: root.cancelClear()
                        text: "close"
                        StyledToolTip {
                            text: Translation.tr("Cancel")
                        }
                    }

                    // Close button (always visible when not confirming)
                    IconToolbarButton {
                        visible: !root.showClearConfirmation
                        implicitWidth: height
                        onClicked: GlobalStates.clipboardOpen = false
                        text: "close"
                        StyledToolTip {
                            text: Translation.tr("Close")
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: Math.min(480, Math.max(160, listView.contentHeight + 20))
                    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Base
                        : Appearance.colors.colLayer2
                    clip: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        clip: true

                        model: filteredClipboardModel

                        delegate: ClipboardItem {
                            required property string rawEntry
                            required property int index
                            anchors.left: parent?.left
                            anchors.right: parent?.right
                            isSelected: ListView.isCurrentItem
                            copiedFromPanel: rawEntry === lastCopiedEntry
                            entry: {
                                const raw = rawEntry
                                const type = `#${raw.match(/^[\s]*(\S+)/)?.[1] || ""}`
                                const name = formatCliphistName(raw)
                                return {
                                    key: type,
                                    cliphistRawString: raw,
                                    name: name,
                                    clickActionName: Translation.tr("Copy"),
                                    type: type,
                                    execute: () => {
                                        root.copyEntry(raw)
                                    },
                                    actions: [
                                        {
                                            name: "Copy",
                                            materialIcon: "content_copy",
                                            execute: () => root.copyEntry(raw),
                                        },
                                        {
                                            name: "Delete",
                                            materialIcon: "delete",
                                            execute: () => root.deleteEntry(raw),
                                        },
                                    ],
                                    blurImage: false,
                                    blurImageText: Translation.tr("Work safety"),
                                    compactClipboardPreview: true,
                                }
                            }
                            query: root.searchText

                            onHoveredChanged: {
                                if (hovered) listView.currentIndex = index
                            }
                        }

                        function moveNext() {
                            const total = count
                            if (total === 0) return
                            if (currentIndex < total - 1)
                                currentIndex++
                            positionViewAtIndex(currentIndex, ListView.Contain)
                        }

                        function movePrevious() {
                            const total = count
                            if (total === 0) return
                            if (currentIndex > 0)
                                currentIndex--
                            positionViewAtIndex(currentIndex, ListView.Contain)
                        }

                        function activateCurrent() {
                            if (currentIndex < 0 || currentIndex >= count) return
                            const rawEntry = filteredClipboardModel.get(currentIndex).rawEntry
                            Cliphist.copy(rawEntry)
                            GlobalStates.clipboardOpen = false
                        }

                        StyledText {
                            visible: listView.count === 0
                            anchors.centerIn: parent
                            text: Translation.tr("No clipboard entries")
                            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.showKeyboardHints ? hintsContent.implicitHeight + 16 : 0
                    clip: true

                    Behavior on Layout.preferredHeight {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    Rectangle {
                        id: hintsContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: hintsColumn.implicitHeight + 16
                        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2 
                            : Appearance.auroraEverywhere ? Appearance.colors.colLayer2Base
                            : Appearance.colors.colPrimaryContainer
                        opacity: root.showKeyboardHints ? 1 : 0

                        Behavior on opacity {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        ColumnLayout {
                            id: hintsColumn
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("↑/↓, J/K: Navigate • Enter: Paste")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? Appearance.inir.colText 
                                    : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface 
                                    : Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Ctrl+C: Copy • Del: Delete • Shift+Del: Clear all • Esc: Close")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? Appearance.inir.colText 
                                    : Appearance.auroraEverywhere ? Appearance.m3colors.m3onSurface 
                                    : Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
