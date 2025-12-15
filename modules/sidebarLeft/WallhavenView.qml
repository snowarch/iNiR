import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarLeft.anime
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

Item {
    id: root
    property real padding: 4

    property var inputField: tagInputField
    readonly property var responses: Wallhaven.responses
    property string previewDownloadPath: Directories.booruPreviews
    property string downloadPath: Directories.booruDownloads
    property string nsfwPath: Directories.booruDownloadsNsfw
    property string commandPrefix: "/"
    property real scrollOnNewResponse: 100
    property int tagSuggestionDelay: 210
    property var suggestionQuery: ""
    property var suggestionList: []

    property bool pullLoading: false
    property int pullLoadingGap: 80
    property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-wallhavenResponseListView.verticalOvershoot / 50)) * wallhavenResponseListView.dragging)

    // Used to auto-scroll to the next page section after the request completes.
    property int _pendingScrollToPage: -1
    property string _pendingScrollTagsKey: ""

    function _tryScrollToPendingPage() {
        if (root._pendingScrollToPage <= 0)
            return
        for (let i = 0; i < root.responses.length; ++i) {
            const r = root.responses[i]
            if (!r || r.provider !== "wallhaven")
                continue
            if (parseInt(r.page) !== root._pendingScrollToPage)
                continue
            if (root._tagsKey(r.tags) !== root._pendingScrollTagsKey)
                continue

            // Defer to next tick so delegates have a chance to size themselves.
            Qt.callLater(() => {
                wallhavenResponseListView.positionViewAtIndex(i, ListView.Beginning)
            })

            root._pendingScrollToPage = -1
            root._pendingScrollTagsKey = ""
            break
        }
    }

    function _tagsKey(tags) {
        return (tags || []).join(" ")
    }

    Connections {
        target: Wallhaven
        function onResponseFinished() {
            pullLoading = false
            root._tryScrollToPendingPage()
        }
    }

    Connections {
        target: Wallhaven
        function onTagSuggestion(query, suggestions) {
            root.suggestionQuery = query
            root.suggestionList = suggestions
        }
    }

    // Always start with an empty view and wait for explicit user input
    Component.onCompleted: {
        Wallhaven.clearResponses()
    }

    property var allCommands: [
        {
            name: "clear",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Wallhaven.clearResponses();
            }
        },
        {
            name: "clean",
            description: Translation.tr("Clear the current list of images"),
            execute: () => {
                Wallhaven.clearResponses();
            }
        },
        {
            name: "next",
            description: Translation.tr("Get the next page of results"),
            execute: () => {
                if (root.responses.length > 0) {
                    const lastResponse = root.responses[root.responses.length - 1];
                    root.handleInput(`${lastResponse.tags.join(" ")} ${parseInt(lastResponse.page) + 1}`);
                } else {
                    root.handleInput("");
                }
            }
        },
        {
            name: "safe",
            description: Translation.tr("Disable NSFW content"),
            execute: () => {
                Persistent.states.booru.allowNsfw = false;
            }
        },
        {
            name: "lewd",
            description: Translation.tr("Allow NSFW content (requires Wallhaven API key)"),
            execute: () => {
                Persistent.states.booru.allowNsfw = true;
            }
        },
        {
            name: "top",
            description: Translation.tr("Use monthly toplist (topRange=1M)"),
            execute: () => {
                Wallhaven.sortingMode = "toplist";
                Wallhaven.topRange = "1M";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to toplist (1M)"));
            }
        },
        {
            name: "topw",
            description: Translation.tr("Use weekly toplist (topRange=1w)"),
            execute: () => {
                Wallhaven.sortingMode = "toplist";
                Wallhaven.topRange = "1w";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to toplist (1w)"));
            }
        },
        {
            name: "latest",
            description: Translation.tr("Sort by newest wallpapers"),
            execute: () => {
                Wallhaven.sortingMode = "date_added";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to latest"));
            }
        },
        {
            name: "random",
            description: Translation.tr("Show random wallpapers"),
            execute: () => {
                Wallhaven.sortingMode = "random";
                Wallhaven.addSystemMessage(Translation.tr("Sorting set to random"));
            }
        }
    ]

    function parseTagsAndPage(inputText) {
        const parts = inputText.split(/\s+/).filter(p => p.length > 0)
        let pageIndex = 1
        let tags = []
        let hashParts = null

        for (let i = 0; i < parts.length; ++i) {
            const part = parts[i]

            if (part.startsWith("#")) {
                if (hashParts && hashParts.length > 0) {
                    const phrase = hashParts.join(" ").trim()
                    if (phrase.length > 0) tags.push("\"" + phrase + "\"")
                }
                hashParts = [part.substring(1)]
            } else if (hashParts) {
                hashParts.push(part)
            } else {
                if (/^\d+$/.test(part)) {
                    pageIndex = parseInt(part, 10)
                    continue
                }
                tags.push(part)
            }
        }

        if (hashParts && hashParts.length > 0) {
            const phrase = hashParts.join(" ").trim()
            if (phrase.length > 0) tags.push("\"" + phrase + "\"")
        }

        return { tags, pageIndex }
    }

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Wallhaven.addSystemMessage(Translation.tr("Unknown command: ") + command);
            }
        }
        else if (inputText.trim() == "+") {
            root.handleInput(`${root.commandPrefix}next`);
        }
        else {
            const parsed = root.parseTagsAndPage(inputText)
            Wallhaven.makeRequest(
                parsed.tags,
                Persistent.states.booru.allowNsfw,
                Config.options?.sidebar?.wallhaven?.limit ?? Wallhaven.defaultLimit,
                parsed.pageIndex
            );
        }
    }

    onFocusChanged: (focus) => {
        if (focus) {
            tagInputField.forceActiveFocus()
        }
    }

    property real pageKeyScrollAmount: wallhavenResponseListView.height / 2
    Keys.onPressed: (event) => {
        tagInputField.forceActiveFocus()
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                if (wallhavenResponseListView.atYBeginning) return;
                wallhavenResponseListView.contentY = Math.max(0, wallhavenResponseListView.contentY - root.pageKeyScrollAmount)
                event.accepted = true
            } else if (event.key === Qt.Key_PageDown) {
                if (wallhavenResponseListView.atYEnd) return;
                wallhavenResponseListView.contentY = Math.min(wallhavenResponseListView.contentHeight, wallhavenResponseListView.contentY + root.pageKeyScrollAmount)
                event.accepted = true
            }
        }
    }

    // (Tag suggestion handling follows Anime.qml pattern: searchTimer + FlowButtonGroup acceptTag)

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: wallhavenResponseListView.width
                    height: wallhavenResponseListView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: wallhavenResponseListView
                vertical: true
            }

            StyledListView {
                id: wallhavenResponseListView
                z: 0
                anchors.fill: parent
                spacing: 10

                touchpadScrollFactor: (Config.options?.interactions?.scrolling?.touchpadScrollFactor ?? 1.0) * 1.4
                mouseScrollFactor: (Config.options?.interactions?.scrolling?.mouseScrollFactor ?? 1.0) * 1.4

                footer: Item {
                    // Allow scrolling past the last response so paging buttons aren't covered
                    // by the input bar at the bottom.
                    implicitHeight: tagInputContainer.implicitHeight + 16
                }
                footerPositioning: ListView.InlineFooter

                onContentHeightChanged: {
                    // When a new page response lands, delegates need a tick to size.
                    // Retrying on contentHeightChanged makes auto-scroll reliable.
                    if (root._pendingScrollToPage > 0) {
                        Qt.callLater(() => root._tryScrollToPendingPage())
                    }
                }

                property int lastResponseLength: 0
                property bool userIsScrolling: false
                
                onMovingChanged: {
                    if (moving) userIsScrolling = true
                    else Qt.callLater(() => { userIsScrolling = false })
                }
                
                onDraggingChanged: {
                    if (dragging) userIsScrolling = true
                    else Qt.callLater(() => { userIsScrolling = false })
                }
                
                Connections {
                    target: root
                    function onResponsesChanged() {
                        if (root.responses.length > wallhavenResponseListView.lastResponseLength) {
                            // Only auto-scroll if user is not actively scrolling
                            if (!wallhavenResponseListView.userIsScrolling && wallhavenResponseListView.lastResponseLength > 0) {
                                wallhavenResponseListView.contentY = wallhavenResponseListView.contentY + root.scrollOnNewResponse
                            }
                            wallhavenResponseListView.lastResponseLength = root.responses.length

                            // If a next-page click requested an auto-scroll, position the new page section.
                            root._tryScrollToPendingPage()
                        }
                    }
                }

                model: ScriptModel {
                    values: root.responses
                }
                delegate: BooruResponse {
                    responseData: modelData
                    tagInputField: root.inputField
                    previewDownloadPath: root.previewDownloadPath
                    downloadPath: root.downloadPath
                    nsfwPath: root.nsfwPath
                    // Clean layout - no card background, just images
                    cleanLayout: true
                    showPagingButtons: true
                    rowTooShortThreshold: 140
                    rowMaxHeight: 300
                    imageSpacing: 4
                    responsePadding: 0

                    onNextPageRequested: (resp) => {
                        if (!resp)
                            return
                        root._pendingScrollToPage = parseInt(resp.page) + 1
                        root._pendingScrollTagsKey = root._tagsKey(resp.tags)
                        Qt.callLater(() => root._tryScrollToPendingPage())
                    }
                }

                onDragEnded: {
                    const gap = wallhavenResponseListView.verticalOvershoot
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true
                        root.handleInput(`${root.commandPrefix}next`)
                    }
                }
            }

            Item {
                id: placeholderHost
                z: 2
                visible: root.responses.length === 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.width - 40, 420)
                height: 220

                PagePlaceholder {
                    id: placeholderItem
                    anchors.fill: parent
                    shown: true
                    icon: "image"
                    title: Translation.tr("Wallhaven wallpapers")
                    description: Translation.tr("Type tags and hit Enter to search on wallhaven.cc\nUse #tag for multi-word tags (spaces become underscores)")
                    shape: MaterialShape.Shape.Bun
                }
            }

            FlowButtonGroup {
                id: placeholderCommands
                z: 3
                visible: root.responses.length === 0
                anchors.horizontalCenter: placeholderHost.horizontalCenter
                anchors.top: placeholderHost.bottom
                anchors.topMargin: 8
                spacing: 6

                Repeater {
                    model: [
                        { label: Translation.tr("Top weekly"), sorting: "toplist", topRange: "1w" },
                        { label: Translation.tr("Top monthly"), sorting: "toplist", topRange: "1M" },
                        { label: Translation.tr("Latest"), sorting: "date_added" },
                        { label: Translation.tr("Random"), sorting: "random" },
                    ]

                    delegate: ApiCommandButton {
                        required property var modelData
                        buttonText: modelData.label
                        colBackground: Appearance.colors.colLayer2

                        downAction: () => {
                            Wallhaven.sortingMode = modelData.sorting
                            if (modelData.topRange !== undefined) {
                                Wallhaven.topRange = modelData.topRange
                            }
                            Wallhaven.makeRequest(
                                [],
                                Persistent.states.booru.allowNsfw,
                                Config.options?.sidebar?.wallhaven?.limit ?? Wallhaven.defaultLimit,
                                1
                            )
                        }
                    }
                }
            }

            ScrollToBottomButton {
                z: 3
                target: wallhavenResponseListView
            }

            MaterialLoadingIndicator {
                id: loadingIndicator
                z: 4
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 20 + (root.pullLoading ? 0 : Math.max(0, (root.normalizedPullDistance - 0.5) * 50))
                    Behavior on bottomMargin {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                        }
                    }
                }
                loading: root.pullLoading || Wallhaven.runningRequests > 0
                pullProgress: Math.min(1, wallhavenResponseListView.verticalOvershoot / root.pullLoadingGap * wallhavenResponseListView.dragging)
                scale: root.pullLoading ? 1 : Math.min(1, root.normalizedPullDistance * 2)
            }
        }

        DescriptionBox {
            text: root.suggestionList[commandSuggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup {
            id: commandSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0 && tagInputField.text.startsWith(root.commandPrefix)
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: commandSuggestionRepeater
                model: {
                    commandSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: cmdButton
                    colBackground: commandSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.name
                    }

                    onHoveredChanged: {
                        if (cmdButton.hovered) {
                            commandSuggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        commandSuggestions.acceptCommand(modelData.name)
                    }
                }
            }

            function acceptCommand(cmd) {
                tagInputField.text = cmd + " "
                tagInputField.cursorPosition = tagInputField.text.length
                tagInputField.forceActiveFocus()
            }

            function acceptSelectedCommand() {
                if (commandSuggestions.selectedIndex >= 0 && commandSuggestions.selectedIndex < commandSuggestionRepeater.count) {
                    const cmd = root.suggestionList[commandSuggestions.selectedIndex].name;
                    commandSuggestions.acceptCommand(cmd);
                }
            }
        }

        DescriptionBox {
            text: ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup {
            id: tagSuggestions
            visible: root.suggestionList.length > 0 && tagInputField.text.length > 0 && !tagInputField.text.startsWith(root.commandPrefix)
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: tagSuggestionRepeater
                model: {
                    tagSuggestions.selectedIndex = 0
                    return root.suggestionList.slice(0, 10)
                }
                delegate: ApiCommandButton {
                    id: tagButton
                    colBackground: tagSuggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        StyledText {
                            Layout.fillWidth: false
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignRight
                            text: "#" + (modelData.name ?? "")
                        }
                        StyledText {
                            Layout.fillWidth: false
                            visible: modelData.count !== undefined
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                            horizontalAlignment: Text.AlignLeft
                            text: modelData.count ?? ""
                        }
                    }
                    onHoveredChanged: {
                        if (tagButton.hovered) {
                            tagSuggestions.selectedIndex = index
                        }
                    }
                    onClicked: {
                        tagSuggestions.acceptSuggestion(modelData)
                    }
                }
            }

            function acceptSuggestion(suggestion) {
                const raw = tagInputField.text.trim()
                const words = raw.length > 0 ? raw.split(/\s+/) : []

                const tagName = suggestion?.name ?? ""
                const tagId = suggestion?.id ?? ""
                if (tagName.length === 0)
                    return

                // Wallhaven exact tag search: id:<id> (cannot be combined).
                // Always use it when available to ensure exactness and avoid space/paren tokenization.
                if (tagId.length > 0) {
                    tagInputField.text = "id:" + tagId + " "
                    tagInputField.cursorPosition = tagInputField.text.length
                    tagInputField.forceActiveFocus()
                    return
                }

                // Otherwise, keep Anime-like behavior: replace last token, preserving '#'
                if (words.length > 0) {
                    const last = words[words.length - 1]
                    const keepHash = last.startsWith("#")
                    const needsHash = keepHash || (/\s+/.test(tagName))
                    words[words.length - 1] = (needsHash ? "#" : "") + tagName
                } else {
                    words.push("#" + tagName)
                }
                const updatedText = words.join(" ") + " "
                tagInputField.text = updatedText
                tagInputField.cursorPosition = tagInputField.text.length
                tagInputField.forceActiveFocus()
            }

            function acceptSelectedTag() {
                if (tagSuggestions.selectedIndex >= 0 && tagSuggestions.selectedIndex < tagSuggestionRepeater.count) {
                    const s = root.suggestionList[tagSuggestions.selectedIndex]
                    tagSuggestions.acceptSuggestion(s)
                }
            }
        }

        Rectangle {
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitWidth: tagInputField.implicitWidth
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin
                + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + columnSpacing, 45)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            RowLayout {
                id: inputFieldRowLayout
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 5
                spacing: 0

                StyledTextArea {
                    id: tagInputField
                    wrapMode: TextArea.Wrap
                    Layout.fillWidth: true
                    padding: 10
                    color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                    renderType: Text.NativeRendering
                    placeholderText: Translation.tr('Enter tags (use #tag for autocomplete / multi-word), or "%1" for commands').arg(root.commandPrefix)
                    background: null

                    property Timer searchTimer: Timer {
                        interval: root.tagSuggestionDelay
                        repeat: false
                        onTriggered: {
                            const inputText = tagInputField.text
                            const trimmed = (inputText || "").trim()
                            if (trimmed.length === 0)
                                return
                            if (trimmed.startsWith("id:"))
                                return
                            // If user is typing a multi-word tag fragment after '#', use the whole fragment.
                            const hashIdx = trimmed.lastIndexOf("#")
                            let q = ""
                            if (hashIdx !== -1) {
                                q = trimmed.substring(hashIdx + 1).trim()
                            } else {
                                const words = trimmed.split(/\s+/)
                                q = words.length > 0 ? words[words.length - 1] : ""
                            }
                            if (q.length < 2)
                                return
                            Wallhaven.triggerTagSearch(q)
                        }
                    }

                    onTextChanged: {
                        if (tagInputField.text.length === 0) {
                            root.suggestionQuery = ""
                            root.suggestionList = []
                            searchTimer.stop()
                            return
                        }

                        if (tagInputField.text.startsWith(root.commandPrefix)) {
                            root.suggestionQuery = tagInputField.text
                            root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(tagInputField.text.substring(1))).map(cmd => {
                                return {
                                    name: `${root.commandPrefix}${cmd.name}`,
                                    description: `${cmd.description}`,
                                }
                            })
                            searchTimer.stop()
                            return
                        }

                        searchTimer.restart()
                    }

                    function accept() {
                        root.handleInput(text)
                        text = ""
                    }

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Tab) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.acceptSelectedTag()
                            } else {
                                commandSuggestions.acceptSelectedCommand()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.selectedIndex = Math.max(0, tagSuggestions.selectedIndex - 1)
                            } else {
                                commandSuggestions.selectedIndex = Math.max(0, commandSuggestions.selectedIndex - 1)
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down) {
                            if (!tagInputField.text.startsWith(root.commandPrefix) && root.suggestionList.length > 0) {
                                tagSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, tagSuggestions.selectedIndex + 1)
                            } else {
                                commandSuggestions.selectedIndex = Math.min(root.suggestionList.length - 1, commandSuggestions.selectedIndex + 1)
                            }
                            event.accepted = true
                        } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                            if (event.modifiers & Qt.ShiftModifier) {
                                tagInputField.insert(tagInputField.cursorPosition, "\n")
                                event.accepted = true
                            } else {
                                const inputText = tagInputField.text
                                root.handleInput(inputText)
                                tagInputField.clear()
                                event.accepted = true
                            }
                        }
                    }
                 }

                RippleButton {
                    id: sendButton
                    Layout.alignment: Qt.AlignTop
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    enabled: tagInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = tagInputField.text
                            root.handleInput(inputText)
                            tagInputField.clear()
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: "arrow_upward"
                    }
                }
            }

            RowLayout {
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                spacing: 5
                property var commandsShown: [
                    {
                        name: "next",
                        sendDirectly: true,
                    },
                    {
                        name: "clear",
                        sendDirectly: true,
                    },
                ]

                ApiInputBoxIndicator {
                    icon: "image"
                    text: "wallhaven.cc"
                    tooltipText: Translation.tr("Search wallpapers from wallhaven.cc\nUse #tag for tag autocomplete and multi-word searches\nExample: #xenoblade chronicles\nTip: Tab/Enter accepts the selected suggestion\nUse %1safe or %2lewd to toggle NSFW (requires API key)\nUse %1top, %1topw, %1latest, %1random for listing modes")
                        .arg(root.commandPrefix).arg(root.commandPrefix)
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: "•"
                }

                MouseArea {
                    visible: width > 0
                    implicitWidth: switchesRow.implicitWidth
                    Layout.fillHeight: true

                    hoverEnabled: true
                    PointingHandInteraction {}
                    onPressed: {
                        nsfwSwitch.checked = !nsfwSwitch.checked
                    }

                    RowLayout {
                        id: switchesRow
                        spacing: 5
                        anchors.centerIn: parent

                        StyledText {
                            Layout.fillHeight: true
                            Layout.leftMargin: 10
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: nsfwSwitch.enabled ? Appearance.colors.colOnLayer1 : Appearance.m3colors.m3outline
                            text: Translation.tr("Allow NSFW")
                        }
                        StyledSwitch {
                            id: nsfwSwitch
                            enabled: true
                            scale: 0.6
                            Layout.alignment: Qt.AlignVCenter
                            checked: Persistent.states.booru.allowNsfw
                            onCheckedChanged: {
                                Persistent.states.booru.allowNsfw = checked;
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                ButtonGroup {
                    padding: 0
                    Repeater {
                        id: commandRepeater
                        model: commandButtonsRow.commandsShown
                        delegate: ApiCommandButton {
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            buttonText: commandRepresentation
                            colBackground: Appearance.colors.colLayer2

                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation)
                                } else {
                                    tagInputField.text = commandRepresentation + " "
                                    tagInputField.cursorPosition = tagInputField.text.length
                                    tagInputField.forceActiveFocus()
                                }
                                if (modelData.name === "clear") {
                                    tagInputField.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
