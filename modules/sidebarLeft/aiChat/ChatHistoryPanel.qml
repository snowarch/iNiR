import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root
    property bool open: false
    signal requestClose()

    readonly property var chatNames: {
        const names = Ai.savedChats.map(path => path.split("/").pop().replace(/\.json$/, ""));
        const rest = names.filter(name => name !== "lastSession").sort().reverse();
        return (names.includes("lastSession") ? ["lastSession"] : []).concat(rest);
    }

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    radius: Appearance.rounding.small
    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1

    // Swallow clicks so they don't land on the message list behind
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "forum"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Conversations")
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer1
            }
            RippleButton {
                implicitWidth: newChatRow.implicitWidth + 16
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                onClicked: {
                    Ai.newChat();
                    root.requestClose();
                }
                contentItem: RowLayout {
                    id: newChatRow
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol {
                        text: "add"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("New chat")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
                StyledToolTip { text: Translation.tr("Saves the current conversation and starts fresh") }
            }
            RippleButton {
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                onClicked: root.requestClose()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        StyledListView {
            id: chatListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: ScriptModel { values: root.chatNames }

            delegate: Rectangle {
                id: chatRow
                required property var modelData
                readonly property bool isLastSession: modelData === "lastSession"
                property bool renaming: false
                property bool confirmingDelete: false

                width: chatListView.width
                implicitHeight: Math.max(40, rowContent.implicitHeight + 12)
                radius: Appearance.rounding.small
                color: rowMouseArea.containsMouse
                    ? Appearance.colors.colLayer2Hover
                    : Appearance.colors.colLayer2

                MouseArea {
                    id: rowMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (chatRow.renaming) return;
                        Ai.loadChat(chatRow.modelData);
                        root.requestClose();
                    }
                    onExited: chatRow.confirmingDelete = false
                }

                RowLayout {
                    id: rowContent
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6

                    MaterialSymbol {
                        text: chatRow.isLastSession ? "history" : "chat_bubble"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        visible: !chatRow.renaming
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: chatRow.isLastSession ? Translation.tr("Last session (auto-saved)") : chatRow.modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                    }

                    MaterialTextField {
                        id: renameField
                        visible: chatRow.renaming
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("New name")
                        onAccepted: {
                            Ai.renameChat(chatRow.modelData, text);
                            chatRow.renaming = false;
                        }
                        Keys.onEscapePressed: chatRow.renaming = false
                    }

                    AiMessageControlButton {
                        visible: chatRow.renaming
                        buttonIcon: "check"
                        onClicked: {
                            Ai.renameChat(chatRow.modelData, renameField.text);
                            chatRow.renaming = false;
                        }
                        StyledToolTip { text: Translation.tr("Confirm rename") }
                    }

                    AiMessageControlButton {
                        visible: !chatRow.renaming && !chatRow.isLastSession && rowMouseArea.containsMouse
                        buttonIcon: "edit"
                        onClicked: {
                            renameField.text = chatRow.modelData;
                            chatRow.renaming = true;
                            renameField.forceActiveFocus();
                        }
                        StyledToolTip { text: Translation.tr("Rename") }
                    }

                    AiMessageControlButton {
                        visible: !chatRow.renaming && rowMouseArea.containsMouse
                        buttonIcon: chatRow.confirmingDelete ? "delete_forever" : "delete"
                        activated: chatRow.confirmingDelete
                        onClicked: {
                            if (!chatRow.confirmingDelete) {
                                chatRow.confirmingDelete = true;
                                return;
                            }
                            Ai.deleteChat(chatRow.modelData);
                        }
                        StyledToolTip { text: chatRow.confirmingDelete ? Translation.tr("Click again to delete") : Translation.tr("Delete") }
                    }
                }
            }
        }

        StyledText {
            visible: root.chatNames.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("No saved conversations yet")
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }
}
