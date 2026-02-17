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

    property bool pullLoading: false
    property int pullLoadingGap: 80
    property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-wallhavenResponseListView.verticalOvershoot / 50)) * wallhavenResponseListView.dragging)

    Connections {
        target: Wallhaven
        function onResponseFinished() {
            pullLoading = false
        }
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
        }
    ]

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
            const tagList = inputText.split(/\s+/).filter(tag => tag.length > 0);
            let pageIndex = 1;
            for (let i = 0; i < tagList.length; ++i) {
                if (/^\d+$/.test(tagList[i])) {
                    pageIndex = parseInt(tagList[i], 10);
                    tagList.splice(i, 1);
                    break;
                }
            }
            Wallhaven.makeRequest(tagList, Persistent.states.booru.allowNsfw, Config.options?.sidebar?.wallhaven?.limit ?? 24, pageIndex);
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
                    width: swipeView.width
                    height: swipeView.height
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

                touchpadScrollFactor: (Config.options?.interactions?.scrolling?.touchpadScrollFactor ?? 0.5) * 1.4
                mouseScrollFactor: (Config.options?.interactions?.scrolling?.mouseScrollFactor ?? 1.0) * 1.4

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
                }

                onDragEnded: {
                    const gap = wallhavenResponseListView.verticalOvershoot
                    if (gap > root.pullLoadingGap) {
                        root.pullLoading = true
                        root.handleInput(`${root.commandPrefix}next`)
                    }
                }
            }

            PagePlaceholder {
                id: placeholderItem
                z: 2
                shown: root.responses.length === 0
                icon: "image"
                title: Translation.tr("Wallhaven wallpapers")
                description: Translation.tr("Type tags and hit Enter to search on wallhaven.cc")
                shape: MaterialShape.Shape.Bun
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

        Rectangle {
            id: tagInputContainer
            property real columnSpacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer2 : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colLayer2
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
                    placeholderText: Translation.tr('Enter tags, or "%1" for commands').arg(root.commandPrefix)
                    background: null

                    function accept() {
                        root.handleInput(text)
                        text = ""
                    }

                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
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

                ApiInputBoxIndicator {
                    icon: "image"
                    text: "wallhaven.cc"
                    tooltipText: Translation.tr("Search wallpapers from wallhaven.cc\nUse %1safe or %2lewd to toggle NSFW (requires API key)")
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
                            colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer2

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

                    property var commandsShown: [
                        {
                            name: "clear",
                            sendDirectly: true,
                        },
                        {
                            name: "next",
                            sendDirectly: true,
                        },
                    ]
                }
            }
        }
    }
}
