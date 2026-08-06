pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

/**
 * Config-backed event-sound row: the collapsed row names the sound in use
 * and previews it; it expands into the current theme's sound list with
 * per-row preview, plus a custom file path field. No dropdowns.
 *
 * Shared by both families (registered in this folder's qmldir), styled
 * with Appearance tokens on purpose. Usage:
 *
 *   SoundPicker {
 *       label: Translation.tr("Notification")
 *       eventId: "notification"   // key in Audio.soundEvents / sounds.events
 *   }
 */
ColumnLayout {
    id: root

    property string label: ""
    property string eventId: ""
    property bool expanded: false

    readonly property string currentValue: Config.options?.sounds?.events?.[root.eventId] ?? ""
    readonly property string themeDefault: Audio.soundEvents[root.eventId] ?? ""
    readonly property bool isFile: currentValue.startsWith("/") || currentValue.startsWith("file://")
    readonly property string displayValue: currentValue === ""
        ? Translation.tr("Theme default (%1)").arg(themeDefault)
        : (isFile ? currentValue.split("/").pop() : currentValue)

    function setValue(value) {
        Config.setNestedValue("sounds.events." + root.eventId, value)
    }

    spacing: 4
    Layout.fillWidth: true

    // Collapsed header: label + sound in use + preview, tap to expand
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 56
        radius: Appearance.rounding.small
        color: headerTap.pressed ? Appearance.colors.colLayer2Active
             : headerHover.hovered ? Appearance.colors.colLayer2Hover
             : Appearance.colors.colLayer2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            MaterialSymbol {
                text: root.isFile ? "audio_file" : "music_note"
                iconSize: 24
                color: Appearance.colors.colOnLayer2
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: root.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.displayValue
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideMiddle
                }
            }

            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: previewTap.pressed ? Appearance.colors.colPrimaryContainer
                     : previewHover.hovered ? Appearance.colors.colLayer2Hover
                     : "transparent"
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "play_arrow"
                    iconSize: 24
                    color: Appearance.colors.colPrimary
                }
                HoverHandler { id: previewHover }
                TapHandler {
                    id: previewTap
                    onTapped: Audio.playEvent(root.eventId)
                }
            }

            MaterialSymbol {
                text: root.expanded ? "expand_less" : "expand_more"
                iconSize: 22
                color: Appearance.colors.colOnLayer2
            }
        }

        HoverHandler { id: headerHover }
        TapHandler {
            id: headerTap
            onTapped: root.expanded = !root.expanded
        }
    }

    // Expanded: theme sound list with per-row preview
    Rectangle {
        visible: root.expanded
        Layout.fillWidth: true
        implicitHeight: 280
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        ListView {
            id: soundList
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            model: [""].concat(Audio.themeSounds)

            delegate: Rectangle {
                id: row
                required property string modelData
                readonly property bool isSelected: row.modelData === root.currentValue
                                                   && !(root.isFile && row.modelData === "")
                width: soundList.width
                height: 40
                radius: Appearance.rounding.verysmall
                color: row.isSelected ? Appearance.colors.colPrimaryContainer
                     : rowHover.hovered ? Appearance.colors.colLayer2Hover
                     : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 4
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: row.modelData === ""
                            ? Translation.tr("Theme default (%1)").arg(root.themeDefault)
                            : row.modelData
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: row.isSelected ? Appearance.colors.colOnPrimaryContainer
                             : Appearance.colors.colOnLayer2
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Appearance.rounding.full
                        color: rowPlayTap.pressed ? Appearance.colors.colPrimaryContainer : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "play_arrow"
                            iconSize: 20
                            color: Appearance.colors.colPrimary
                        }
                        HoverHandler { id: rowPlayHover }
                        TapHandler {
                            id: rowPlayTap
                            onTapped: Audio.playSystemSound(
                                row.modelData === "" ? root.themeDefault : row.modelData)
                        }
                    }
                }

                HoverHandler { id: rowHover }
                TapHandler {
                    onTapped: {
                        root.setValue(row.modelData)
                        root.expanded = false
                    }
                }
            }
        }
    }

    // Custom file path (absolute; pw-play handles ogg/oga/wav/flac)
    Rectangle {
        visible: root.expanded
        Layout.fillWidth: true
        implicitHeight: 44
        radius: Appearance.rounding.small
        color: Appearance.colors.colLayer2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            MaterialSymbol {
                text: "folder_open"
                iconSize: 20
                color: Appearance.colors.colOnLayer2
            }
            TextInput {
                id: customPathInput
                Layout.fillWidth: true
                text: root.isFile ? root.currentValue : ""
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer2
                clip: true
                selectByMouse: true
                onEditingFinished: {
                    const t = text.trim()
                    if (t.startsWith("/") || t.startsWith("file://")) {
                        root.setValue(t)
                        root.expanded = false
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: customPathInput.text.length === 0
                    text: Translation.tr("Custom file: paste an absolute path…")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
