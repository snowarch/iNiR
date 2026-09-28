pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.waffle.looks

ColumnLayout {
    id: root

    readonly property string activeId: NiriAnimationPresets.activeId

    Layout.fillWidth: true
    spacing: Looks.dp(8)
    Component.onCompleted: NiriAnimationPresets.ensure()

    GridLayout {
        Layout.fillWidth: true
        visible: NiriAnimationPresets.presets.length > 0
        columns: width >= Looks.dp(420) ? 3 : 2
        columnSpacing: Looks.dp(8)
        rowSpacing: Looks.dp(8)

        Repeater {
            model: NiriAnimationPresets.presets

            Rectangle {
                id: tile
                required property var modelData
                readonly property bool on: root.activeId === tile.modelData.id
                readonly property bool busy: NiriAnimationPresets.applying && NiriAnimationPresets.pendingId === tile.modelData.id
                property real clock: 0
                property bool playOnce: false
                readonly property var frame: tile.clock > 0 ? NiriAnimationPresets.demoFrame(tile.modelData, tile.clock) : ({ opacity: 1, scale: 1, x: 0 })

                Layout.fillWidth: true
                implicitHeight: content.implicitHeight + Looks.dp(20)
                radius: Looks.settings.radiusLarge
                color: mouse.pressed ? Looks.settings.tilePressed : mouse.containsMouse ? Looks.settings.tileHover : Looks.settings.tile
                border.width: tile.on ? 2 : 1
                border.color: tile.on ? Looks.colors.accent : Looks.settings.stroke

                Behavior on color {
                    animation: ColorAnimation {
                        duration: Looks.transition.enabled ? Looks.transition.duration.fast : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                    }
                }

                FrameAnimation {
                    running: tile.visible && (mouse.containsMouse || tile.playOnce)
                    onTriggered: {
                        tile.clock += frameTime
                        if (tile.frame.done) {
                            tile.clock = 0
                            tile.playOnce = false
                        }
                    }
                    onRunningChanged: if (!running) tile.clock = 0
                }

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: Looks.dp(10)
                    spacing: Looks.dp(6)

                    Item {
                        id: stage
                        Layout.fillWidth: true
                        Layout.preferredHeight: Looks.dp(44)
                        readonly property real gap: Looks.dp(6)
                        readonly property real column: Math.round((width - gap) / 2)

                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                x: index * (stage.column + stage.gap)
                                width: stage.column
                                height: stage.height
                                radius: Looks.settings.radiusMedium
                                color: Looks.settings.tile
                                border.width: 1
                                border.color: Looks.settings.stroke
                            }
                        }
                        Rectangle {
                            x: tile.frame.x * (stage.column + stage.gap)
                            width: stage.column
                            height: stage.height
                            radius: Looks.settings.radiusMedium
                            opacity: tile.frame.opacity
                            scale: tile.frame.scale
                            color: tile.on ? Looks.colors.accent : Looks.settings.strokeStrong
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Looks.dp(6)
                        WText {
                            Layout.fillWidth: true
                            text: tile.busy ? Translation.tr("Applying…") : tile.modelData.name
                            font.pixelSize: Looks.font.pixelSize.large
                            font.weight: Looks.font.weight.strong
                            elide: Text.ElideRight
                        }
                        WText {
                            text: Translation.tr("%1 ms").arg(NiriAnimationPresets.openFeelMs(tile.modelData))
                            font.pixelSize: Looks.font.pixelSize.small
                            color: Looks.colors.subfg
                        }
                    }
                    WText {
                        Layout.fillWidth: true
                        text: tile.modelData.description
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.subfg
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
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

    WText {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: Looks.font.pixelSize.normal
        color: Looks.colors.subfg
        text: NiriAnimationPresets.error.length > 0 ? Translation.tr("Niri turned that preset down and kept your animations.")
            : !NiriAnimationPresets.loaded ? Translation.tr("Reading Niri's animations…")
            : root.activeId.length === 0 ? Translation.tr("Custom timing. Pick a preset to replace it.")
            : Translation.tr("Hover a preset to watch it. The figure is how long a window takes to open.")
    }
}
