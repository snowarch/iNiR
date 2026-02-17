import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    property int messageIndex
    property var messageData
    property var messageInputField

    property real messagePadding: 7
    property real contentSpacing: 3

    property bool enableMouseSelection: false
    property bool renderMarkdown: true
    property bool editing: false

    property list<var> messageBlocks: StringUtils.splitMarkdownBlocks(root.messageData?.content)

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: columnLayout.implicitHeight + root.messagePadding * 2

    radius: Appearance.rounding.normal
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1

    function saveMessage() {
        if (!root.editing) return;
        // Get all Loader children (each represents a segment)
        const segments = messageContentColumnLayout.children
            .map(child => child.segment)
            .filter(segment => (segment));

        // Reconstruct markdown
        const newContent = segments.map(segment => {
            if (segment.type === "code") {
                const lang = segment.lang ? segment.lang : "";
                // Remove trailing newlines
                const code = segment.content.replace(/\n+$/, "");
                return "```" + lang + "\n" + code + "\n```";
            } else {
                return segment.content;
            }
        }).join("");

        root.editing = false
        root.messageData.content = newContent;
    }

    Keys.onPressed: (event) => {
        if ( // Prevent de-select
            event.key === Qt.Key_Control || 
            event.key == Qt.Key_Shift || 
            event.key == Qt.Key_Alt || 
            event.key == Qt.Key_Meta
        ) {
            event.accepted = true
        }
        // Ctrl + S to save
        if ((event.key === Qt.Key_S) && event.modifiers == Qt.ControlModifier) {
            root.saveMessage();
            event.accepted = true;
        }
    }

    ColumnLayout { // Main layout of the whole thing
        id: columnLayout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: messagePadding
        spacing: root.contentSpacing

        RowLayout { // Header - compact, no background
            id: headerRowLayout
            Layout.fillWidth: true
            spacing: 8

            // Icon
            Item {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 18
                implicitHeight: 18

                CustomIcon {
                    id: modelIcon
                    anchors.centerIn: parent
                    visible: messageData?.role == 'assistant' && Ai.models[messageData?.model]?.icon
                    width: 16
                    height: 16
                    source: (messageData?.role == 'assistant' && Ai.models[messageData?.model]) 
                        ? Ai.models[messageData?.model].icon 
                        : ""
                    colorize: true
                    color: Appearance.colors.colSubtext
                }

                MaterialSymbol {
                    id: roleIcon
                    anchors.centerIn: parent
                    visible: !modelIcon.visible
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                    text: messageData?.role == 'user' ? 'person' : 
                        messageData?.role == 'interface' ? 'settings' : 
                        messageData?.role == 'assistant' ? 'neurology' : 
                        'computer'
                }
            }

            // Name
            StyledText {
                id: providerName
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                text: (messageData?.role == 'assistant' && Ai.models[messageData?.model]) 
                    ? Ai.models[messageData?.model].name 
                    : (messageData?.role == 'user' && SystemInfo.username) 
                        ? SystemInfo.username 
                        : Translation.tr("Interface")
            }

            // Not visible indicator (icon only, tooltip on hover)
            MaterialSymbol {
                id: notVisibleIcon
                visible: messageData?.role == 'interface'
                Layout.alignment: Qt.AlignVCenter
                iconSize: 12
                color: Appearance.colors.colSubtext
                text: "visibility_off"
                
                MouseArea {
                    id: notVisibleMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                StyledToolTip {
                    visible: notVisibleMouseArea.containsMouse
                    text: Translation.tr("Not visible to model")
                }
            }

            // Action buttons - smaller, inline
            RowLayout {
                spacing: 2

                AiMessageControlButton {
                    id: regenButton
                    buttonIcon: "refresh"
                    visible: messageData?.role === 'assistant'
                    onClicked: Ai.regenerate(root.messageIndex)
                    StyledToolTip { text: Translation.tr("Regenerate") }
                }

                AiMessageControlButton {
                    id: copyButton
                    buttonIcon: activated ? "inventory" : "content_copy"
                    onClicked: {
                        Quickshell.clipboardText = root.messageData?.content
                        copyButton.activated = true
                        copyIconTimer.restart()
                    }
                    Timer {
                        id: copyIconTimer
                        interval: 1500
                        onTriggered: copyButton.activated = false
                    }
                    StyledToolTip { text: Translation.tr("Copy") }
                }

                AiMessageControlButton {
                    id: editButton
                    activated: root.editing
                    enabled: root.messageData?.done ?? false
                    buttonIcon: "edit"
                    onClicked: {
                        root.editing = !root.editing
                        if (!root.editing) root.saveMessage()
                    }
                    StyledToolTip { text: root.editing ? Translation.tr("Save") : Translation.tr("Edit") }
                }

                AiMessageControlButton {
                    id: toggleMarkdownButton
                    activated: !root.renderMarkdown
                    buttonIcon: "code"
                    onClicked: root.renderMarkdown = !root.renderMarkdown
                    StyledToolTip { text: Translation.tr("View Markdown source") }
                }

                AiMessageControlButton {
                    id: deleteButton
                    buttonIcon: "close"
                    onClicked: Ai.removeMessage(root.messageIndex)
                    StyledToolTip { text: Translation.tr("Delete") }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: root.messageData?.localFilePath && root.messageData?.localFilePath.length > 0
            sourceComponent: AttachedFileIndicator {
                filePath: root.messageData?.localFilePath
                canRemove: false
            }
        }

        ColumnLayout { // Message content
            id: messageContentColumnLayout
            spacing: 0

            Item {
                Layout.fillWidth: true
                implicitHeight: loadingIndicatorLoader.shown ? loadingIndicatorLoader.implicitHeight : 0
                implicitWidth: loadingIndicatorLoader.implicitWidth
                visible: implicitHeight > 0

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                FadeLoader {
                    id: loadingIndicatorLoader
                    anchors.centerIn: parent
                    shown: (root.messageBlocks.length < 1) && (root.messageData && !root.messageData.done)
                    sourceComponent: MaterialLoadingIndicator {
                        loading: true
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: Array.from({ length: root.messageBlocks.length }, (msg, i) => {
                        return ({
                            type: root.messageBlocks[i].type
                        })
                    });
                }

                delegate: DelegateChooser {
                    id: messageDelegate
                    role: "type"

                    DelegateChoice { roleValue: "code"; MessageCodeBlock {
                        required property int index
                        property var thisBlock: root.messageBlocks[index]
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: thisBlock.content
                        segmentLang: thisBlock.lang
                        messageData: root.messageData
                    } }
                    DelegateChoice { roleValue: "think"; MessageThinkBlock {
                        required property int index
                        property var thisBlock: root.messageBlocks[index]
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: thisBlock.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        completed: thisBlock.completed ?? false
                    } }
                    DelegateChoice { roleValue: "text"; MessageTextBlock {
                        required property int index
                        property var thisBlock: root.messageBlocks[index]
                        editing: root.editing
                        renderMarkdown: root.renderMarkdown
                        enableMouseSelection: root.enableMouseSelection
                        segmentContent: thisBlock.content
                        messageData: root.messageData
                        done: root.messageData?.done ?? false
                        forceDisableChunkSplitting: root.messageData?.content.includes("```") ?? true
                    } }
                }
            }
        }

        Flow { // Annotations
            visible: root.messageData?.annotationSources?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.annotationSources || []
                }
                delegate: AnnotationSourceButton {
                    required property var modelData
                    displayText: modelData.text
                    url: modelData.url
                }
            }
        }

        Flow { // Search queries
            visible: root.messageData?.searchQueries?.length > 0
            spacing: 5
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignLeft

            Repeater {
                model: ScriptModel {
                    values: root.messageData?.searchQueries || []
                }
                delegate: SearchQueryButton {
                    required property var modelData
                    query: modelData
                }
            }
        }

    }
}

