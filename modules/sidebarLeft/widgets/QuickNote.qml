pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import "root:"

Item {
    id: root
    implicitHeight: card.implicitHeight

    property bool editing: false
    property string draft: ""

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            if (!GlobalStates.sidebarLeftOpen && root.editing) {
                root.editing = false
                textArea.focus = false
            }
        }
    }

    StyledRectangularShadow { target: card; visible: !Appearance.auroraEverywhere }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? "transparent" 
             : Appearance.colors.colLayer1
        border.width: Appearance.auroraEverywhere ? 0 : 1
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "edit_note"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    text: Translation.tr("Quick Note")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitWidth: 24; implicitHeight: 24
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                    opacity: Notepad.text.trim() !== "" ? 1 : 0
                    visible: opacity > 0
                    onClicked: Notepad.setTextValue("")

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "delete_outline"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip { text: Translation.tr("Clear") }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(120, Math.max(60, textArea.implicitHeight + 12))
                radius: Appearance.rounding.small
                color: root.editing ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                border.width: root.editing ? 2 : 0
                border.color: Appearance.colors.colPrimary

                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentHeight: textArea.implicitHeight
                    clip: true

                    TextArea {
                        id: textArea
                        width: parent.width
                        text: root.editing ? root.draft : Notepad.text
                        placeholderText: Translation.tr("Type something...")
                        wrapMode: TextEdit.Wrap
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnLayer2
                        placeholderTextColor: Appearance.colors.colOutline
                        background: null
                        padding: 0

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                root.draft = Notepad.text
                                root.editing = true
                            }
                        }

                        onTextChanged: {
                            if (root.editing) root.draft = text
                        }

                        Keys.onEscapePressed: {
                            root.editing = false
                            focus = false
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Return && event.modifiers & Qt.ControlModifier) {
                                Notepad.setTextValue(root.draft)
                                root.editing = false
                                focus = false
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                opacity: root.editing ? 1 : 0
                visible: opacity > 0
                spacing: 4

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                StyledText {
                    text: root.draft.length > 0 ? `${root.draft.length} ${Translation.tr("chars")}` : Translation.tr("Ctrl+Enter to save")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOutline
                }

                Item { Layout.fillWidth: true }

                // Cancel button
                RippleButton {
                    implicitWidth: 24; implicitHeight: 24
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer2Hover
                    colRipple: Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer2Active
                    onClicked: {
                        root.draft = Notepad.text
                        root.editing = false
                        textArea.focus = false
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip { text: Translation.tr("Cancel") }
                }

                // Save button
                RippleButton {
                    implicitWidth: saveRow.implicitWidth + 12
                    implicitHeight: 24
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    colRipple: Appearance.colors.colPrimaryActive
                    onClicked: {
                        Notepad.setTextValue(root.draft)
                        root.editing = false
                        textArea.focus = false
                    }

                    contentItem: RowLayout {
                        id: saveRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "check"
                            iconSize: 12
                            color: Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: Translation.tr("Save")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }
}
