pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    readonly property string activeId: NiriAnimationPresets.activeId

    spacing: 8
    Component.onCompleted: NiriAnimationPresets.ensure()

    GridLayout {
        Layout.fillWidth: true
        visible: NiriAnimationPresets.presets.length > 0
        columns: width >= 420 ? 3 : 2
        columnSpacing: 8
        rowSpacing: 8

        Repeater {
            model: NiriAnimationPresets.presets

            Rectangle {
                id: card
                required property var modelData
                readonly property bool on: root.activeId === card.modelData.id
                readonly property bool busy: NiriAnimationPresets.applying && NiriAnimationPresets.pendingId === card.modelData.id
                property real clock: 0
                property bool playOnce: false
                readonly property var frame: card.clock > 0 ? NiriAnimationPresets.demoFrame(card.modelData, card.clock) : ({ opacity: 1, scale: 1, x: 0 })

                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + 20
                radius: Appearance.rounding.normal
                color: card.on ? Appearance.colors.colPrimaryContainer
                    : mouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: 120 } }

                FrameAnimation {
                    running: card.visible && (mouse.containsMouse || card.playOnce)
                    onTriggered: {
                        card.clock += frameTime
                        if (card.frame.done) {
                            card.clock = 0
                            card.playOnce = false
                        }
                    }
                    onRunningChanged: if (!running) card.clock = 0
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    Item {
                        id: stage
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        readonly property real gap: 6
                        readonly property real column: Math.round((width - gap) / 2)

                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                x: index * (stage.column + stage.gap)
                                width: stage.column
                                height: stage.height
                                radius: Appearance.rounding.small
                                color: card.on ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer3
                            }
                        }
                        Rectangle {
                            x: card.frame.x * (stage.column + stage.gap)
                            width: stage.column
                            height: stage.height
                            radius: Appearance.rounding.small
                            opacity: card.frame.opacity
                            scale: card.frame.scale
                            color: card.on ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: card.busy ? Translation.tr("Applying…") : card.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: card.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: Translation.tr("%1 ms").arg(NiriAnimationPresets.openFeelMs(card.modelData))
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            color: card.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: card.modelData.description
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: card.on ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        card.clock = 0
                        card.playOnce = true
                        NiriAnimationPresets.apply(card.modelData.id)
                    }
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: card.modelData.name
                Accessible.description: card.modelData.description
                Accessible.checked: card.on
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: NiriAnimationPresets.error.length > 0 ? Appearance.colors.colError : Appearance.colors.colSubtext
        text: NiriAnimationPresets.error.length > 0 ? Translation.tr("Niri turned that preset down and kept your animations.")
            : !NiriAnimationPresets.loaded ? Translation.tr("Reading Niri's animations…")
            : root.activeId.length === 0 ? Translation.tr("Custom timing from the sliders below. Pick a preset to replace it.")
            : Translation.tr("Hover a preset to watch it. The figure is how long a window takes to open.")
    }
}
