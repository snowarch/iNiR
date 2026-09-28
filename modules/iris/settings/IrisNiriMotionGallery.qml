pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property var presets: NiriAnimationPresets.presets
    readonly property string activeId: NiriAnimationPresets.activeId

    spacing: Math.round(10 * root.d)
    Component.onCompleted: NiriAnimationPresets.ensure()

    GridLayout {
        id: grid
        Layout.fillWidth: true
        visible: root.presets.length > 0
        columns: width >= 3 * Math.round(150 * root.d) ? 3 : 2
        columnSpacing: Math.round(8 * root.d)
        rowSpacing: Math.round(12 * root.d)

        Repeater {
            model: root.presets

            Item {
                id: tile
                required property var modelData
                readonly property bool on: root.activeId === tile.modelData.id
                readonly property bool busy: NiriAnimationPresets.applying && NiriAnimationPresets.pendingId === tile.modelData.id
                property real clock: 0
                property bool playOnce: false
                readonly property var frame: tile.clock > 0 ? NiriAnimationPresets.demoFrame(tile.modelData, tile.clock) : ({ opacity: 1, scale: 1, x: 0 })

                Layout.fillWidth: true
                Layout.preferredHeight: stage.height + Math.round(6 * root.d) + title.implicitHeight + detail.implicitHeight

                FrameAnimation {
                    running: tile.visible && (hover.hovered || tile.playOnce)
                    onTriggered: {
                        tile.clock += frameTime
                        if (tile.frame.done) {
                            tile.clock = 0
                            tile.playOnce = false
                        }
                    }
                    onRunningChanged: if (!running) tile.clock = 0
                }

                Rectangle {
                    id: stage
                    width: parent.width
                    height: Math.round(70 * root.d)
                    radius: IrisStyle.radiusTile
                    color: tile.on ? IrisStyle.fillActive : hover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    scale: tap.pressed ? IrisStyle.pressScale(0.97) : 1
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

                    readonly property real pad: Math.round(12 * root.d)
                    readonly property real column: Math.round((width - 3 * pad) / 2)

                    Repeater {
                        model: 2
                        Rectangle {
                            required property int index
                            x: stage.pad + index * (stage.column + stage.pad)
                            y: stage.pad
                            width: stage.column
                            height: stage.height - 2 * stage.pad
                            radius: IrisStyle.radiusChip
                            color: IrisStyle.fill
                        }
                    }
                    Rectangle {
                        x: stage.pad + tile.frame.x * (stage.column + stage.pad)
                        y: stage.pad
                        width: stage.column
                        height: stage.height - 2 * stage.pad
                        radius: IrisStyle.radiusChip
                        opacity: tile.frame.opacity
                        scale: tile.frame.scale
                        color: tile.on ? IrisStyle.accent : IrisStyle.textTertiary

                        Rectangle {
                            x: Math.round(6 * root.d)
                            y: Math.round(6 * root.d)
                            width: parent.width * 0.45
                            height: Math.round(3 * root.d)
                            radius: height / 2
                            color: tile.on ? IrisStyle.onAccent : IrisStyle.surface
                            opacity: 0.55
                        }
                    }
                }

                RowLayout {
                    id: title
                    anchors.top: stage.bottom
                    anchors.topMargin: Math.round(6 * root.d)
                    width: parent.width
                    spacing: Math.round(6 * root.d)
                    IrisText {
                        Layout.fillWidth: true
                        text: tile.busy ? Translation.tr("Applying…") : tile.modelData.name
                        color: tile.on ? IrisStyle.text : IrisStyle.subtext
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        text: Translation.tr("%1 ms").arg(NiriAnimationPresets.openFeelMs(tile.modelData))
                        color: IrisStyle.muted
                        font.pixelSize: IrisStyle.typeFootnote
                        font.features: ({ "tnum": 1 })
                    }
                }
                IrisText {
                    id: detail
                    anchors.top: title.bottom
                    width: parent.width
                    text: tile.modelData.description
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeFootnote
                    elide: Text.ElideRight
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: tap
                    onTapped: {
                        tile.clock = 0
                        tile.playOnce = true
                        NiriAnimationPresets.apply(tile.modelData.id)
                    }
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: tile.modelData.name
                Accessible.description: tile.modelData.description
                Accessible.checked: tile.on
            }
        }
    }

    IrisText {
        Layout.fillWidth: true
        visible: text.length > 0
        wrapMode: Text.WordWrap
        color: NiriAnimationPresets.error.length > 0 ? IrisStyle.danger : IrisStyle.muted
        font.pixelSize: IrisStyle.typeMeta
        text: NiriAnimationPresets.error.length > 0 ? Translation.tr("Niri turned that preset down and kept your animations.")
            : !NiriAnimationPresets.loaded ? Translation.tr("Reading Niri's animations…")
            : root.activeId.length === 0 ? Translation.tr("Your own timing. Pick one to replace it.")
            : Translation.tr("Hover a preset to watch it. The figure is how long a window takes to open.")
    }
}
