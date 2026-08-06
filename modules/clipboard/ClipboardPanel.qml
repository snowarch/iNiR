import qs
import qs.services
import qs.services.deferred
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
    property bool _presentedOpen: false

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    property int panelWidth: 600
    property int panelMaxHeight: 700
    property string searchText: ""
    property int totalCount: 0
    property int matchCount: 0
    property bool showKeyboardHints: false
    property string lastCopiedEntry: ""
    property bool showClearConfirmation: false
    property bool navigateMode: false

    function formatCliphistName(entry) {
        let cleaned = StringUtils.cleanCliphistEntry(entry)
        if (Cliphist.entryIsImage(entry)) {
            cleaned = cleaned.replace(/^\s*\[\[.*?\]\]\s*/, "")
        }
        const unwrapped = StringUtils.cliphistMarkupPreview(cleaned)
        if (unwrapped !== cleaned)
            cleaned = unwrapped.length > 0 ? unwrapped : Translation.tr("Rich text")
        cleaned = StringUtils.sanitizeDisplayText(cleaned)
        return cleaned.trim()
    }

    function updateFilteredModel() {
        const entries = Cliphist.entries
        const entryCount = entries.length

        filteredClipboardModel.clear()

        const trimmedSearch = searchText.trim().toLowerCase()
        const hasSearch = trimmedSearch.length > 0
        let matches = 0

        // Pinned entries always lead the list, in both filter and navigate mode.
        const pins = Cliphist.pinned
        for (let i = 0; i < pins.length; i++) {
            const preview = Cliphist.pinPreview(pins[i])
            const hit = !hasSearch || preview.toLowerCase().includes(trimmedSearch)
            if (hasSearch && hit) matches++
            if (hit || navigateMode)
                filteredClipboardModel.append({ "rawEntry": "", "pinText": pins[i], "isPin": true, "isMatch": hit })
        }

        if (hasSearch && navigateMode) {
            // Navigate mode: show ALL entries, mark which ones match
            for (let i = 0; i < entryCount; i++) {
                const entry = entries[i]
                const content = formatCliphistName(entry).toLowerCase()
                const hit = content.includes(trimmedSearch)
                if (hit) matches++
                filteredClipboardModel.append({ "rawEntry": entry, "pinText": "", "isPin": false, "isMatch": hit })
            }
        } else {
            // Filter mode: only include matching entries
            for (let i = 0; i < entryCount; i++) {
                const entry = entries[i]
                if (!hasSearch) {
                    filteredClipboardModel.append({ "rawEntry": entry, "pinText": "", "isPin": false, "isMatch": true })
                } else {
                    const content = formatCliphistName(entry).toLowerCase()
                    if (content.includes(trimmedSearch)) {
                        filteredClipboardModel.append({ "rawEntry": entry, "pinText": "", "isPin": false, "isMatch": true })
                        matches++
                    }
                }
            }
        }

        totalCount = filteredClipboardModel.count
        matchCount = matches

        if (hasSearch && navigateMode && matches > 0) {
            // Auto-scroll to first match
            for (let i = 0; i < filteredClipboardModel.count; i++) {
                if (filteredClipboardModel.get(i).isMatch) {
                    listView.currentIndex = i
                    listView.positionViewAtIndex(i, ListView.Center)
                    break
                }
            }
        } else if (totalCount > 0 && typeof listView !== "undefined" && listView) {
            listView.currentIndex = 0
        }
    }

    // The panel window is hidden, not destroyed, on close, so the ListView keeps
    // the contentY it was left at. Rebuilding the model does not reset it, and
    // neither does `currentIndex = 0`: on open the model is rebuilt while the
    // window is still invisible, so the view never lays out and the highlight
    // never scrolls anything. positionViewAtBeginning() forces the layout, which
    // is the only thing that actually moves contentY back to the top.
    property bool pendingViewReset: false

    function resetViewPosition(): void {
        if (typeof listView === "undefined" || !listView) return
        listView.currentIndex = filteredClipboardModel.count > 0 ? 0 : -1
        listView.positionViewAtBeginning()
    }

    function jumpToNextMatch() {
        const count = filteredClipboardModel.count
        if (count === 0) return
        const start = listView.currentIndex
        for (let i = 1; i <= count; i++) {
            const idx = (start + i) % count
            if (filteredClipboardModel.get(idx).isMatch) {
                listView.currentIndex = idx
                listView.positionViewAtIndex(idx, ListView.Center)
                return
            }
        }
    }

    function jumpToPrevMatch() {
        const count = filteredClipboardModel.count
        if (count === 0) return
        const start = listView.currentIndex
        for (let i = 1; i <= count; i++) {
            const idx = (start - i + count) % count
            if (filteredClipboardModel.get(idx).isMatch) {
                listView.currentIndex = idx
                listView.positionViewAtIndex(idx, ListView.Center)
                return
            }
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
        _log("[ClipboardPanel] copyEntry", String(entry).slice(0, 120))
        lastCopiedEntry = entry
        Cliphist.copy(entry)
        GlobalStates.clipboardOpen = false
    }

    function copyPinnedText(text) {
        Quickshell.clipboardText = text
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
        // Reset model and count immediately so the UI reflects the wipe
        // (the async refresh would miss because the panel closes below)
        filteredClipboardModel.clear()
        totalCount = 0
        GlobalStates.clipboardOpen = false
    }

    function cancelClear() {
        showClearConfirmation = false
    }

    function refresh() {
        _log("[ClipboardPanel] Refreshing clipboard via Cliphist service...")
        Cliphist.refresh()
    }

    function prepareOpen(): void {
        refresh()
        searchText = ""
        navigateMode = false
        showClearConfirmation = false
        pendingViewReset = true
        updateFilteredModel()
        resetViewPosition()
        Qt.callLater(() => {
            searchField.forceActiveFocus()
            root.resetViewPosition()
        })
    }

    function presentOpen(): void {
        prepareOpen()
        Qt.callLater(() => { root._presentedOpen = GlobalStates.clipboardOpen })
    }

    Component.onCompleted: if (GlobalStates.clipboardOpen) root.presentOpen()

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            // Only update model if clipboard panel is open to avoid lag
            if (!GlobalStates.clipboardOpen) return
            root.updateFilteredModel()
            // The refresh started on open is asynchronous: these entries land
            // once the panel is already on screen and rebuild the model under
            // it, undoing the reset done at open time.
            if (root.pendingViewReset) {
                root.pendingViewReset = false
                Qt.callLater(root.resetViewPosition)
            }
        }
        function onPinnedChanged() {
            if (GlobalStates.clipboardOpen) {
                Qt.callLater(() => { root._presentedOpen = GlobalStates.clipboardOpen })
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
                // Always refresh on open. Skipping it for 5s after a panel copy
                // was meant to keep the list from reordering under the cursor,
                // but cliphist has already moved that entry to the top by then:
                // the panel just showed a stale order, so the entry you copied
                // last appeared wherever it used to be instead of first — and a
                // copy made outside the panel in that window did not show up.
                root.presentOpen()
            } else {
                root._presentedOpen = false
                root.pendingViewReset = false
            }
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

                // Helper to get current row from filtered model
                function currentRow() {
                    const idx = listView.currentIndex
                    if (idx < 0 || idx >= filteredClipboardModel.count)
                        return null
                    return filteredClipboardModel.get(idx)
                }

                function currentEntry() {
                    const row = currentRow()
                    return (row === null || row.isPin) ? null : row.rawEntry
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
                    // Delete current entry, or unpin a pinned one
                    const row = currentRow()
                    if (row !== null) {
                        if (row.isPin) Cliphist.unpin(row.pinText)
                        else root.deleteEntry(row.rawEntry)
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
                    // Copy current entry to clipboard
                    const row = currentRow()
                    if (row !== null) {
                        if (row.isPin) root.copyPinnedText(row.pinText)
                        else root.copyEntry(row.rawEntry)
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                    // Toggle pin on the current entry
                    const row = currentRow()
                    if (row !== null) {
                        const pinnedAs = row.isPin ? row.pinText : Cliphist.pinnedTextFor(row.rawEntry)
                        // Ctrl+P is a toggle: on an entry that is already pinned it
                        // used to pin it again instead of unpinning.
                        if (pinnedAs.length > 0) Cliphist.unpin(pinnedAs)
                        else if (Cliphist.isPinnable(row.rawEntry)) Cliphist.pinEntry(row.rawEntry)
                        event.accepted = true
                    }
                } else if (event.key === Qt.Key_Tab && root.navigateMode && root.searchText.length > 0) {
                    root.jumpToNextMatch()
                    event.accepted = true
                } else if (event.key === Qt.Key_Backtab && root.navigateMode && root.searchText.length > 0) {
                    root.jumpToPrevMatch()
                    event.accepted = true
                } else if (event.key === Qt.Key_F10) {
                    // Toggle keyboard hints
                    root.showKeyboardHints = !root.showKeyboardHints
                    event.accepted = true
                }
            }
        }

        // Scrim backdrop for glass styles
        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colScrim
            visible: Appearance.auroraEverywhere
            opacity: root._presentedOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(200)
                    easing.type: Easing.OutCubic
                }
            }
        }

        StyledRectangularShadow {
            target: panelBackground
            radius: panelBackground.radius
            opacity: panelBackground.opacity
            visible: !Appearance.zzzEverywhere
                && (Appearance.angelEverywhere || (!Appearance.inirEverywhere && !Appearance.auroraEverywhere))
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
            fallbackColor: Appearance.zzzEverywhere ? Appearance.zzz.paper : Appearance.colors.colLayer1
            inirColor: Appearance.inir.colLayer1
            auroraTransparency: Appearance.angelEverywhere
                ? Appearance.angel.panelTransparentize
                : Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14)
            screenX: (window.screen?.width ?? 1920) / 2 - width / 2
            screenY: (window.screen?.height ?? 1080) / 2 - height / 2
            screenWidth: window.screen?.width ?? 1920
            screenHeight: window.screen?.height ?? 1080
            border.width: Appearance.zzzEverywhere ? 1
                : Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth
                : Appearance.auroraEverywhere ? 1 : 1
            Behavior on border.width {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                : Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder 
                : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder 
                : Appearance.colors.colOutlineVariant
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                : Appearance.inirEverywhere ? Appearance.inir.roundingLarge : Appearance.rounding.screenRounding
            Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
            
            // Entry animation
            opacity: root._presentedOpen ? 1 : 0
            scale: root._presentedOpen ? 1 : 0.95
            
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
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
            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }

            ZzzPanelBackdrop {
                anchors.fill: parent
                label: "CLIPBOARD"
                index: "HIST"
                accentColor: Appearance.zzz.tertiary
                ghostText: "CLIP"
                showTicks: false
                showBurst: false
                showGrid: false
                horizontalBias: 0.1
                verticalBias: 0.02
                ghostStrength: 0.7
            }

            ColumnLayout {
                id: contentColumn
                anchors.fill: parent
                anchors.margins: Appearance.zzzEverywhere ? 12 : 10
                spacing: 10

                // Shell desaturation effect
                layer.enabled: Appearance.shouldDesaturate("popups") && contentColumn.visible
                layer.effect: ShellDesaturationEffect {}

                Toolbar {
                    id: headerToolbar
                    Layout.fillWidth: true
                    enableShadow: false
                    transparent: Appearance.angelEverywhere || Appearance.auroraEverywhere

                    MaterialSymbol {
                        text: "content_paste"
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.zzzEverywhere ? Appearance.zzz.accent
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignVCenter
                        text: Translation.tr("Clipboard history") + ` (${root.totalCount})`
                        font.family: Appearance.zzzEverywhere ? Appearance.font.family.title : Appearance.font.family.main
                        font.pixelSize: Appearance.zzzEverywhere ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                        font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Normal
                        font.italic: Appearance.zzzEverywhere
                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
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
                        visible: root.searchText.length > 0
                        implicitWidth: height
                        onClicked: {
                            root.navigateMode = !root.navigateMode
                            root.updateFilteredModel()
                        }
                        text: root.navigateMode ? "find_in_page" : "filter_list"
                        StyledToolTip {
                            text: root.navigateMode
                                ? Translation.tr("Navigate mode (Tab/Shift+Tab to jump)")
                                : Translation.tr("Filter mode")
                        }
                    }

                    StyledText {
                        visible: root.navigateMode && root.searchText.length > 0
                        text: root.matchCount + " " + Translation.tr("matches")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                            : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
                    color: Appearance.angelEverywhere
                        ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.76)
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere
                        ? ColorUtils.transparentize(Appearance.colors.colLayer0Base,
                            Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14))
                        : Appearance.colors.colLayer2
                    clip: true

                    Behavior on implicitHeight {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveEnter.duration
                            easing.type: Appearance.animation.elementMoveEnter.type
                            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                        }
                    }

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2
                        clip: true

                        model: filteredClipboardModel

                        delegate: ClipboardItem {
                            required property string rawEntry
                            required property string pinText
                            required property bool isPin
                            required property bool isMatch
                            required property int index
                            anchors.left: parent?.left
                            anchors.right: parent?.right
                            isSelected: ListView.isCurrentItem
                            isSearchMatch: isMatch
                            copiedFromPanel: !isPin && rawEntry === lastCopiedEntry
                            entry: {
                                if (isPin) {
                                    const text = pinText
                                    return {
                                        key: text,
                                        cliphistRawString: "",
                                        name: Cliphist.pinPreview(text),
                                        clickActionName: Translation.tr("Copy"),
                                        type: Translation.tr("Pinned"),
                                        materialSymbol: "keep",
                                        execute: () => root.copyPinnedText(text),
                                        actions: [
                                            {
                                                name: "Copy",
                                                label: Translation.tr("Copy"),
                                                materialIcon: "content_copy",
                                                execute: () => root.copyPinnedText(text),
                                            },
                                            {
                                                name: "Unpin",
                                                label: Translation.tr("Unpin"),
                                                materialIcon: "keep_off",
                                                execute: () => Cliphist.unpin(text),
                                            },
                                        ],
                                        compactClipboardPreview: true,
                                    }
                                }
                                const raw = rawEntry
                                const type = `#${raw.match(/^[\s]*(\S+)/)?.[1] || ""}`
                                const name = formatCliphistName(raw)
                                const actions = [
                                    {
                                        name: "Copy",
                                        label: Translation.tr("Copy"),
                                        materialIcon: "content_copy",
                                        execute: () => root.copyEntry(raw),
                                    },
                                    {
                                        name: "Delete",
                                        label: Translation.tr("Delete"),
                                        materialIcon: "delete",
                                        execute: () => root.deleteEntry(raw),
                                    },
                                ]
                                // An already-pinned entry offered "Pin" again and gave
                                // no sign it was pinned. Offer the action that is
                                // actually available, and badge the row.
                                const pinnedAs = Cliphist.pinnedTextFor(raw)
                                if (pinnedAs.length > 0) {
                                    actions.splice(1, 0, {
                                        name: "Unpin",
                                        label: Translation.tr("Unpin"),
                                        materialIcon: "keep_off",
                                        execute: () => Cliphist.unpin(pinnedAs),
                                    })
                                } else if (Cliphist.isPinnable(raw)) {
                                    actions.splice(1, 0, {
                                        name: "Pin",
                                        label: Translation.tr("Pin"),
                                        materialIcon: "keep",
                                        execute: () => Cliphist.pinEntry(raw),
                                    })
                                }
                                return {
                                    key: type,
                                    cliphistRawString: raw,
                                    name: name,
                                    clickActionName: Translation.tr("Copy"),
                                    type: type,
                                    materialSymbol: pinnedAs.length > 0 ? "keep" : "",
                                    execute: () => {
                                        root.copyEntry(raw)
                                    },
                                    actions: actions,
                                    blurImage: false,
                                    blurImageText: Translation.tr("Work safety"),
                                    compactClipboardPreview: true,
                                }
                            }
                            query: root.searchText


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
                            const row = filteredClipboardModel.get(currentIndex)
                            if (row.isPin) root.copyPinnedText(row.pinText)
                            else root.copyEntry(row.rawEntry)
                        }

                        ColumnLayout {
                            visible: listView.count === 0
                            anchors.centerIn: parent
                            spacing: 8

                            MascotImage {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 96
                                surface: "clipboard"
                                fallbackSurface: "emptyStates"
                                pose: "box-hideout"
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("No clipboard entries")
                                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.showKeyboardHints ? hintsContent.implicitHeight + 16 : 0
                    clip: true

                    Behavior on Layout.preferredHeight {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    Rectangle {
                        id: hintsContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        implicitHeight: hintsColumn.implicitHeight + 16
                        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                            : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                        color: Appearance.angelEverywhere
                            ? ColorUtils.transparentize(Appearance.angel.colGlassCard, 0.76)
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere
                            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base,
                                Math.max(0.12, Appearance.aurora.subSurfaceTransparentize - 0.14))
                            : Appearance.colors.colPrimaryContainer
                        opacity: root.showKeyboardHints ? 1 : 0

                        Behavior on opacity {
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
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
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnSurface 
                                    : Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Ctrl+C: Copy • Ctrl+P: Pin • Del: Delete • Shift+Del: Clear all • Esc: Close")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? Appearance.inir.colText 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnSurface 
                                    : Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Navigate mode: Tab/Shift+Tab jump between matches")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.angelEverywhere ? Appearance.angel.colText
                                    : Appearance.inirEverywhere ? Appearance.inir.colText 
                                    : Appearance.auroraEverywhere ? Appearance.colors.colOnSurface 
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
