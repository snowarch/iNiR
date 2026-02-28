import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int margin: 10

    // Style tokens (5-style support)
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
        : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary

    // Word count helper
    readonly property int wordCount: textArea.text.trim().length > 0
        ? textArea.text.trim().split(/\s+/).length : 0

    // When this widget gets focus (from BottomWidgetGroup.focusActiveItem),
    // move focus to the internal text area on the next event loop tick.
    onFocusChanged: (focus) => {
        if (focus) {
            Qt.callLater(() => textArea.forceActiveFocus())
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: 8

        // Header with title and stats
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Translation.tr("Notepad")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: root.colText
            }

            Item { Layout.fillWidth: true }

            // Stats badge
            Rectangle {
                visible: textArea.text.length > 0
                implicitWidth: statsRow.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                    : Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: statsRow
                    anchors.centerIn: parent
                    spacing: 6

                    StyledText {
                        text: root.wordCount + " " + (root.wordCount === 1 ? Translation.tr("word") : Translation.tr("words"))
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.m3colors.m3onSecondaryContainer
                    }
                }
            }
        }

        // Toolbar
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            NotepadToolButton {
                icon: "content_copy"
                tooltipText: Translation.tr("Copy all")
                enabled: textArea.text.length > 0
                onClicked: {
                    Quickshell.execDetached(["wl-copy", textArea.text])
                    copiedToast.show()
                }
            }

            NotepadToolButton {
                icon: "content_paste"
                tooltipText: Translation.tr("Paste from clipboard")
                onClicked: clipboardProc.running = true
            }

            NotepadToolButton {
                icon: "select_all"
                tooltipText: Translation.tr("Select all")
                enabled: textArea.text.length > 0
                onClicked: textArea.selectAll()
            }

            Item { Layout.fillWidth: true }

            NotepadToolButton {
                icon: "delete_outline"
                tooltipText: Translation.tr("Clear all")
                enabled: textArea.text.length > 0
                destructive: true
                onClicked: {
                    textArea.text = ""
                    Notepad.setTextValue("")
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer0
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
            clip: true

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: 8
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: textArea
                    width: scrollView.availableWidth
                    wrapMode: TextArea.Wrap
                    font.pixelSize: Appearance.inirEverywhere ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                    placeholderText: Translation.tr("Write your notes here...")
                    placeholderTextColor: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.m3colors.m3outline
                    text: Notepad.text
                    selectByMouse: true
                    activeFocusOnTab: true
                    background: null

                    Keys.onPressed: (event) => {
                        if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                            Notepad.setTextValue(textArea.text)
                            event.accepted = true
                        }
                    }

                    onTextChanged: {
                        saveTimer.restart()
                    }

                    onCursorRectangleChanged: {
                        scrollView.ScrollBar.vertical.position = Math.max(0, Math.min(
                            (cursorRectangle.y - scrollView.height / 2) / contentHeight,
                            1 - scrollView.height / contentHeight
                        ))
                    }
                }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 800
        repeat: false
        onTriggered: {
            Notepad.setTextValue(textArea.text)
        }
    }

    // Clipboard paste process
    Process {
        id: clipboardProc
        command: ["wl-paste", "-n"]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                if (data && data.length > 0) {
                    const cursorPos = textArea.cursorPosition
                    textArea.insert(cursorPos, data)
                }
            }
        }
    }

    // Copied toast notification
    Rectangle {
        id: copiedToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        implicitWidth: toastContent.implicitWidth + 20
        implicitHeight: 32
        radius: 16
        color: root.colPrimary
        opacity: 0
        visible: opacity > 0

        function show() {
            opacity = 1
            toastTimer.restart()
        }

        Behavior on opacity {
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            id: toastContent
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "check"
                iconSize: 14
                color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                    : Appearance.colors.colOnPrimary
            }

            StyledText {
                text: Translation.tr("Copied!")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                    : Appearance.colors.colOnPrimary
            }
        }

        Timer {
            id: toastTimer
            interval: 1500
            onTriggered: copiedToast.opacity = 0
        }
    }

    // Toolbar button component
    component NotepadToolButton: Item {
        id: toolBtn
        required property string icon
        property string tooltipText: ""
        property bool destructive: false

        signal clicked()

        implicitWidth: 32
        implicitHeight: 28

        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
            color: {
                if (!toolBtn.enabled) return "transparent"
                if (toolBtnMA.containsPress)
                    return toolBtn.destructive
                        ? ColorUtils.transparentize(Appearance.colors.colError, 0.7)
                        : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                         : Appearance.colors.colLayer1Active)
                if (toolBtnMA.containsMouse)
                    return toolBtn.destructive
                        ? ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                        : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                         : Appearance.colors.colLayer1Hover)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: toolBtn.icon
                iconSize: 18
                color: toolBtn.destructive && toolBtn.enabled
                    ? Appearance.colors.colError
                    : root.colTextSecondary
            }

            MouseArea {
                id: toolBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: toolBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (toolBtn.enabled) toolBtn.clicked()
            }

            StyledToolTip {
                visible: toolBtnMA.containsMouse && toolBtn.tooltipText !== ""
                text: toolBtn.tooltipText
            }
        }
    }
}
