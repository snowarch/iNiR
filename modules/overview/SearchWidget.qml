import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item { // Wrapper
    id: root
    readonly property string xdgConfigHome: Directories.config
    property string searchingText: ""
    property bool showResults: searchingText != ""
    property real availableHeight: root.QsWindow?.window?.height ?? (root.QsWindow?.window?.screen?.height ?? 1080)
    readonly property bool actionMode: searchingText.startsWith(root.prefixAction)
    readonly property string actionQuery: actionMode ? StringUtils.cleanPrefix(searchingText, root.prefixAction) : ""
    implicitWidth: searchWidgetContent.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: searchWidgetContent.implicitHeight + Appearance.sizes.elevationMargin * 2

    readonly property var searchPrefixes: Config.options?.search?.prefix ?? {}
    readonly property string prefixAction: searchPrefixes.action ?? "/"
    readonly property string prefixApp: searchPrefixes.app ?? ">"
    readonly property string prefixClipboard: searchPrefixes.clipboard ?? ";"
    readonly property string prefixEmojis: searchPrefixes.emojis ?? ":"
    readonly property string prefixMath: searchPrefixes.math ?? "="
    readonly property string prefixShellCommand: searchPrefixes.shellCommand ?? "$"
    readonly property string prefixWebSearch: searchPrefixes.webSearch ?? "?"

    property string mathResult: ""
    property string debouncedSearchText: ""
    property var cachedResults: []
    readonly property real resultsAvailableHeight: Math.max(
        180,
        availableHeight
            - searchBar.implicitHeight
            - searchBar.verticalPadding * 2
            - Appearance.sizes.elevationMargin * 2
            - 24
    )

    property bool clipboardWorkSafetyActive: {
        const enabled = Config.options?.workSafety?.enable?.clipboard ?? false;
        const keywords = Config.options?.workSafety?.triggerCondition?.networkNameKeywords ?? [];
        const sensitiveNetwork = (StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), keywords))
        return enabled && sensitiveNetwork;
    }

    // All actions are now centralized in GlobalActions service.
    property var searchActions: GlobalActions.searchActions

    function focusAppResultCurrentOrFirst() {
        if (!appResults.visible || appResults.count <= 0)
            return

        const targetIndex = appResults.currentIndex >= 0 ? Math.min(appResults.currentIndex, appResults.count - 1) : 0
        appResults.currentIndex = targetIndex
    }

    function stepAppResultSelection(step) {
        if (!appResults.visible || appResults.count <= 0)
            return false

        const baseIndex = appResults.currentIndex >= 0 ? appResults.currentIndex : (step > 0 ? -1 : 0)
        const targetIndex = Math.max(0, Math.min(baseIndex + step, appResults.count - 1))
        appResults.currentIndex = targetIndex
        return true
    }

    function executeAppResultCurrentOrFirst() {
        if (!appResults.visible || appResults.count <= 0)
            return

        const targetIndex = appResults.currentIndex >= 0 ? Math.min(appResults.currentIndex, appResults.count - 1) : 0
        appResults.currentIndex = targetIndex

        const item = appResults.itemAtIndex(targetIndex)
        if (item && item.clicked) {
            item.clicked()
            return
        }

        Qt.callLater(() => {
            const delayedItem = appResults.itemAtIndex(targetIndex)
            if (delayedItem && delayedItem.clicked)
                delayedItem.clicked()
        })
    }

    function focusFirstItem() {
        if (root.actionMode && actionModeView.visible) {
            actionModeView.focusFirstItem()
        } else if (appResults.visible && appResults.count > 0) {
            appResults.currentIndex = 0
            root.focusAppResultCurrentOrFirst()
        }
    }

    function focusSearchInput() {
        searchBar.forceFocus();
    }

    function disableExpandAnimation() {
        searchBar.animateWidth = false;
    }

    function cancelSearch() {
        searchBar.searchInput.text = "";
        root.searchingText = "";
        searchBar.animateWidth = true;
    }

    function setSearchingText(text) {
        searchBar.searchInput.text = text;
        searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length;
        root.searchingText = text;
    }

    function containsUnsafeLink(entry) {
        if (entry == undefined) return false;
        const unsafeKeywords = Config.options?.workSafety?.triggerCondition?.linkKeywords ?? [];
        return StringUtils.stringListContainsSubstring(entry.toLowerCase(), unsafeKeywords);
    }

    function updateSearchResults(): void {
        const text = root.debouncedSearchText;
        
        if (text === "") {
            root.cachedResults = [];
            return;
        }

        // Action mode is handled entirely by ActionModeView
        if (text.startsWith(root.prefixAction)) {
            root.cachedResults = [];
            return;
        }

        // Clipboard search
        if (text.startsWith(root.prefixClipboard)) {
            const searchString = StringUtils.cleanPrefix(text, root.prefixClipboard);
            root.cachedResults = Cliphist.fuzzyQuery(searchString).map((entry, index, array) => {
                const mightBlurImage = Cliphist.entryIsImage(entry) && root.clipboardWorkSafetyActive;
                let shouldBlurImage = mightBlurImage;
                if (mightBlurImage) {
                    shouldBlurImage = shouldBlurImage && (containsUnsafeLink(array[index - 1]) || containsUnsafeLink(array[index + 1]));
                }
                const type = `#${entry.match(/^\s*(\S+)/)?.[1] || ""}`
                return {
                    key: type,
                    cliphistRawString: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    clickActionName: "",
                    type: type,
                    execute: () => { Cliphist.copy(entry) },
                    actions: [
                        { name: "Copy", materialIcon: "content_copy", execute: () => { Cliphist.copy(entry); } },
                        { name: "Delete", materialIcon: "delete", execute: () => { Cliphist.deleteEntry(entry); } }
                    ],
                    blurImage: shouldBlurImage,
                    blurImageText: Translation.tr("Work safety")
                };
            }).filter(Boolean);
            return;
        }
        
        // Emoji search
        if (text.startsWith(root.prefixEmojis)) {
            const searchString = StringUtils.cleanPrefix(text, root.prefixEmojis);
            root.cachedResults = Emojis.fuzzyQuery(searchString).map(entry => {
                const emoji = entry.match(/^\s*(\S+)/)?.[1] || ""
                return {
                    key: emoji,
                    cliphistRawString: entry,
                    bigText: emoji,
                    name: entry.replace(/^\s*\S+\s+/, ""),
                    clickActionName: "",
                    type: "Emoji",
                    execute: () => { Quickshell.clipboardText = entry.match(/^\s*(\S+)/)?.[1]; }
                };
            }).filter(Boolean);
            return;
        }

        // Default search
        nonAppResultsTimer.restart();

        // Use stable keys for non-app results to prevent unnecessary re-renders
        const mathResultObject = {
            key: "__math_result__",
            name: root.mathResult,
            clickActionName: Translation.tr("Copy"),
            type: Translation.tr("Math result"),
            fontType: "monospace",
            materialSymbol: 'calculate',
            execute: () => { Quickshell.clipboardText = root.mathResult; }
        };

        const appQuery = StringUtils.cleanPrefix(text, root.prefixApp)
        const appEntries = AppSearch.fuzzyQuery(appQuery)
        const seenAppNames = new Set()
        const appResultObjects = []
        for (let i = 0; i < appEntries.length; i++) {
            const entry = appEntries[i]
            const nameKey = (entry?.name ?? "").trim().toLowerCase()
            if (nameKey.length === 0) continue
            if (seenAppNames.has(nameKey)) continue
            seenAppNames.add(nameKey)

            appResultObjects.push({
                key: `app_${entry.name}`,
                name: entry.name,
                clickActionName: Translation.tr("Launch"),
                type: Translation.tr("App"),
                comment: entry.comment ?? "",
                icon: entry.icon,
                execute: entry.execute,
            })
        }

        const commandResultObject = {
            key: "__run_command__",
            name: StringUtils.cleanPrefix(text, root.prefixShellCommand).replace("file://", ""),
            clickActionName: Translation.tr("Run"),
            type: Translation.tr("Run command"),
            fontType: "monospace",
            materialSymbol: 'terminal',
            execute: () => {
                let cleanedCommand = text.replace("file://", "");
                cleanedCommand = StringUtils.cleanPrefix(cleanedCommand, root.prefixShellCommand);
                if (cleanedCommand.startsWith(root.prefixShellCommand)) {
                    cleanedCommand = cleanedCommand.slice(root.prefixShellCommand.length);
                }
                cleanedCommand = cleanedCommand.trim();
                if (!cleanedCommand.length) return;
                const term = Config.options?.apps?.terminal ?? "ghostty";
                if (term.indexOf("ghostty") !== -1) {
                    Quickshell.execDetached([term, "-e", "/usr/bin/sh", "-lc", cleanedCommand]);
                } else {
                    const commandToRun = `${term} /usr/bin/bash -lc '${cleanedCommand}'`;
                    Quickshell.execDetached(["/usr/bin/bash", "-c", commandToRun]);
                }
            }
        };

        const webSearchResultObject = {
            key: "__web_search__",
            name: StringUtils.cleanPrefix(text, root.prefixWebSearch),
            clickActionName: Translation.tr("Search"),
            type: Translation.tr("Search the web"),
            materialSymbol: 'travel_explore',
            execute: () => {
                let query = StringUtils.cleanPrefix(text, root.prefixWebSearch);
                let url = (Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q=") + query;
                for (let site of (Config.options?.search?.excludedSites ?? ["quora.com", "facebook.com"])) {
                    url += ` -site:${site}`;
                }
                Qt.openUrlExternally(url);
            }
        };
        
        const launcherActionObjects = root.searchActions.map(action => {
            const actionString = `${root.prefixAction}${action.action}`;
            if (actionString.startsWith(text) || text.startsWith(actionString)) {
                return {
                    key: `Action ${actionString}`,
                    name: text.startsWith(actionString) ? text : actionString,
                    clickActionName: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    materialSymbol: 'settings_suggest',
                    execute: () => { action.execute(text.split(" ").slice(1).join(" ")); }
                };
            }
            return null;
        }).filter(Boolean);

        let result = [];
        const startsWithNumber = /^\d/.test(text);
        const startsWithMathPrefix = text.startsWith(root.prefixMath);
        const startsWithShellCommandPrefix = text.startsWith(root.prefixShellCommand);
        const startsWithWebSearchPrefix = text.startsWith(root.prefixWebSearch);
        
        if (startsWithNumber || startsWithMathPrefix) {
            result.push(mathResultObject);
        } else if (startsWithShellCommandPrefix) {
            result.push(commandResultObject);
        } else if (startsWithWebSearchPrefix) {
            result.push(webSearchResultObject);
        }

        result = result.concat(appResultObjects);
        result = result.concat(launcherActionObjects);

        if (root.searchPrefixes.showDefaultActionsWithoutPrefix ?? true) {
            if (!startsWithShellCommandPrefix) result.push(commandResultObject);
            if (!startsWithNumber && !startsWithMathPrefix) result.push(mathResultObject);
            if (!startsWithWebSearchPrefix) result.push(webSearchResultObject);
        }

        root.cachedResults = result;
    }

    Timer {
        id: searchDebounceTimer
        interval: 60
        onTriggered: {
            root.debouncedSearchText = root.searchingText;
            root.updateSearchResults();
        }
    }

    onSearchingTextChanged: {
        root.mathResult = ""
        searchDebounceTimer.restart();
    }

    Timer {
        id: nonAppResultsTimer
        interval: (Config.options?.search?.nonAppResultDelay ?? 30)
        onTriggered: {
            let expr = root.debouncedSearchText;
            if (expr.startsWith(root.prefixMath)) {
                expr = expr.slice(root.prefixMath.length);
            }
            expr = expr.trim()
            if (expr.length === 0) {
                root.mathResult = ""
                root.updateSearchResults()
                return
            }
            mathProcess.calculateExpression(expr);
        }
    }

    Process {
        id: mathProcess
        property list<string> baseCommand: ["/usr/bin/qalc", "-t"]
        function calculateExpression(expression) {
            root.mathResult = "";
            mathProcess.running = false;
            mathProcess.command = baseCommand.concat(expression);
            mathProcess.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data;
                root.updateSearchResults();
            }
        }
    }

    Keys.onPressed: event => {
        // Prevent Esc and Backspace from registering
        if (event.key === Qt.Key_Escape)
            return;

        // Handle Backspace: focus and delete character if not focused
        if (event.key === Qt.Key_Backspace) {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                if (event.modifiers & Qt.ControlModifier) {
                    // Delete word before cursor
                    let text = searchBar.searchInput.text;
                    let pos = searchBar.searchInput.cursorPosition;
                    if (pos > 0) {
                        // Find the start of the previous word
                        let left = text.slice(0, pos);
                        let match = left.match(/(\s*\S+)\s*$/);
                        let deleteLen = match ? match[0].length : 1;
                        searchBar.searchInput.text = text.slice(0, pos - deleteLen) + text.slice(pos);
                        searchBar.searchInput.cursorPosition = pos - deleteLen;
                    }
                } else {
                    // Delete character before cursor if any
                    if (searchBar.searchInput.cursorPosition > 0) {
                        searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition - 1) + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                        searchBar.searchInput.cursorPosition -= 1;
                    }
                }
                // Always move cursor to end after programmatic edit
                searchBar.searchInput.cursorPosition = searchBar.searchInput.text.length;
                event.accepted = true;
            }
            // If already focused, let TextField handle it
            return;
        }

        // Only handle visible printable characters (ignore control chars, arrows, etc.)
        if (event.text && event.text.length === 1 && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Return && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) // ignore control chars like Backspace, Tab, etc.
        {
            if (!searchBar.searchInput.activeFocus) {
                root.focusSearchInput();
                // Insert the character at the cursor position
                searchBar.searchInput.text = searchBar.searchInput.text.slice(0, searchBar.searchInput.cursorPosition) + event.text + searchBar.searchInput.text.slice(searchBar.searchInput.cursorPosition);
                searchBar.searchInput.cursorPosition += 1;
                event.accepted = true;
            }
        }
    }

    StyledRectangularShadow {
        target: searchWidgetContent
    }
    GlassBackground { // Background
        id: searchWidgetContent
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: Appearance.sizes.elevationMargin
        }
        clip: true
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight
        radius: searchBar.height / 2 + searchBar.verticalPadding
        fallbackColor: Appearance.colors.colBackgroundSurfaceContainer
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: auroraEverywhere || inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border

        Behavior on implicitHeight {
            id: searchHeightBehavior
            enabled: GlobalStates.overviewOpen && root.showResults
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuart
            }
        }

        ColumnLayout {
            id: columnLayout
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 0

            // clip: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: searchWidgetContent.width
                    height: searchWidgetContent.width
                    radius: searchWidgetContent.radius
                }
            }

            SearchBar {
                id: searchBar
                property real verticalPadding: 4
                Layout.fillWidth: true
                Layout.leftMargin: 10
                Layout.rightMargin: 4
                Layout.topMargin: verticalPadding
                Layout.bottomMargin: verticalPadding
                searchingText: root.searchingText
                onSearchingTextChanged: if (searchingText !== root.searchingText) root.searchingText = searchingText
            }

            Rectangle {
                // Separator
                visible: root.showResults && !root.actionMode
                Layout.fillWidth: true
                height: 1
                color: Appearance.colors.colOutlineVariant
            }

            // ── Action Mode View (replaces normal results when in / mode) ──
            ActionModeView {
                id: actionModeView
                Layout.fillWidth: true
                visible: root.actionMode && root.showResults
                query: root.actionQuery
                availableHeight: root.resultsAvailableHeight
                onActionExecuted: GlobalStates.overviewOpen = false
                onReturnToSearch: root.focusSearchInput()
            }

            ListView { // App results
                id: appResults
                visible: root.showResults && !root.actionMode
                Layout.fillWidth: true
                implicitHeight: Math.min(root.resultsAvailableHeight, appResults.contentHeight + topMargin + bottomMargin)
                clip: true
                topMargin: 10
                bottomMargin: 10
                spacing: 2
                KeyNavigation.up: searchBar
                highlightMoveDuration: 100

                function focusCurrentOrFirst() {
                    root.focusAppResultCurrentOrFirst()
                }

                function stepSelection(step) {
                    return root.stepAppResultSelection(step)
                }

                function activateCurrentOrFirst() {
                    root.executeAppResultCurrentOrFirst()
                }

                onActiveFocusChanged: {
                    if (activeFocus && count > 0) {
                        if (currentIndex < 0)
                            currentIndex = 0;
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        stepSelection(1)
                        event.accepted = true
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && currentIndex >= 0) {
                        activateCurrentOrFirst()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        if (currentIndex > 0) {
                            stepSelection(-1)
                        } else {
                            root.focusSearchInput()
                        }
                        event.accepted = true
                    }
                }

                Connections {
                    target: root
                    function onSearchingTextChanged() {
                        if (appResults.count > 0)
                            appResults.currentIndex = 0;
                    }
                }

                model: ScriptModel {
                    id: model
                    objectProp: "key"
                    values: root.cachedResults
                }

                delegate: SearchItem {
                    // The selectable item for each search result
                    required property var modelData
                    anchors.left: parent?.left
                    anchors.right: parent?.right
                    entry: modelData
                    upTarget: searchBar.searchInput
                    query: StringUtils.cleanOnePrefix(root.debouncedSearchText, [
                        root.prefixAction,
                        root.prefixApp,
                        root.prefixClipboard,
                        root.prefixEmojis,
                        root.prefixMath,
                        root.prefixShellCommand,
                        root.prefixWebSearch
                    ])

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            if (model.values.length === 0)
                                return;
                            const tabbedText = entry.name;
                            root.setSearchingText(tabbedText);
                            event.accepted = true;
                            root.focusSearchInput();
                        }
                    }
                }
            }
        }
    }
}
