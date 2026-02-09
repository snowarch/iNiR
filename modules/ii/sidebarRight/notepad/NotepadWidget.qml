import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property int margin: 10

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

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Notepad")
                font.pixelSize: Appearance.inirEverywhere ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.larger
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            }

            StyledText {
                text: textArea.text.length > 0
                      ? Translation.tr("%1 chars").arg(textArea.text.length)
                      : Translation.tr("Empty")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnLayer1
                opacity: Appearance.inirEverywhere ? 1 : 0.7
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.rounding.normal
            color: Appearance.inirEverywhere ? Appearance.inir.colLayer0
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer0
            border.width: Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
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
}
