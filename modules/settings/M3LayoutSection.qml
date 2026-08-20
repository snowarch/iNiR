pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

ContentSubsection {
    id: root

    property string sectionTitle
    property var layout: []
    property var availableWidgets: []
    property var getWidgetName: (id) => id
    property var onUpdate: (list) => {}

    title: sectionTitle
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(36, selectedFlow.implicitHeight)

            Flow {
                id: selectedFlow
                anchors.fill: parent
                spacing: 4

                Repeater {
                    id: selectedRepeater
                    model: root.layout

                    delegate: SelectionGroupButton {
                        id: selectedChip
                        required property var modelData
                        required property int index

                        leftmost: true
                        rightmost: true
                        buttonIcon: "close"
                        buttonText: root.getWidgetName(modelData)
                        toggled: !dragHandler.active
                        opacity: dragHandler.active ? 0.55 : 1
                        scale: dragHandler.active ? 0.96 : 1
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        onClicked: {
                            const next = root.layout.slice()
                            next.splice(index, 1)
                            root.onUpdate(next)
                        }

                        DragHandler {
                            id: dragHandler
                            target: null

                            function nearestIndex(sceneX, sceneY) {
                                let best = index
                                let distance = Infinity
                                for (let i = 0; i < selectedRepeater.count; ++i) {
                                    if (i === index) continue
                                    const candidate = selectedRepeater.itemAt(i)
                                    if (!candidate) continue
                                    const center = candidate.mapToItem(null,
                                        candidate.width / 2, candidate.height / 2)
                                    const dx = sceneX - center.x
                                    const dy = sceneY - center.y
                                    const nextDistance = Math.sqrt(dx * dx + dy * dy)
                                    if (nextDistance < distance) {
                                        distance = nextDistance
                                        best = i
                                    }
                                }
                                return best
                            }

                            onActiveChanged: {
                                if (active) return
                                const nextIndex = nearestIndex(
                                    centroid.scenePosition.x,
                                    centroid.scenePosition.y)
                                if (nextIndex === index) return
                                const next = root.layout.slice()
                                const moved = next.splice(index, 1)[0]
                                next.splice(nextIndex, 0, moved)
                                root.onUpdate(next)
                            }
                        }
                    }
                }

                StyledText {
                    visible: root.layout.length === 0
                    text: Translation.tr("Empty group")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        IconToolbarButton {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            text: chooser.open ? "keyboard_arrow_up" : "add"
            toggled: chooser.open
            onClicked: chooser.open = !chooser.open
        }
    }

    Item {
        id: chooser
        property bool open: false

        Layout.fillWidth: true
        visible: implicitHeight > 0
        clip: true
        opacity: open ? 1 : 0
        implicitHeight: open ? availableFlow.implicitHeight + 20 : 0

        Behavior on implicitHeight {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        Rectangle {
            anchors.fill: parent
            color: Appearance.colors.colSurfaceContainerHigh
            radius: Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            Flow {
                id: availableFlow
                anchors {
                    fill: parent
                    margins: 10
                }
                spacing: 4

                Repeater {
                    model: root.availableWidgets
                    delegate: SelectionGroupButton {
                        required property var modelData
                        leftmost: true
                        rightmost: true
                        buttonIcon: modelData.icon ?? "widgets"
                        buttonText: modelData.name
                        onClicked: {
                            const next = root.layout.slice()
                            next.push(modelData.id)
                            root.onUpdate(next)
                            if (modelData.id !== "visualizer" && modelData.id !== "divisor")
                                chooser.open = false
                        }
                    }
                }

                StyledText {
                    visible: root.availableWidgets.length === 0
                    text: Translation.tr("No widgets available")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
