import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root
    property var today: new Date()

    function usageColor(value) {
        if (value > 0.9) return Appearance.colors.colError
        if (value > 0.6) return Appearance.m3colors.m3tertiary
        return Appearance.colors.colPrimary
    }

    ColumnLayout {
        id: popupColumn
        spacing: Appearance.sizes.spacingSmall
        implicitWidth: Math.max(390, Math.round(410 * Appearance.fontSizeScale))

        Row {
            Layout.fillWidth: true
            Layout.maximumWidth: popupColumn.implicitWidth

            StyledText {
                text: Qt.locale().toString(root.today, " MMMM")
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                text: " " + Qt.locale().toString(root.today, "yyyy")
                font.pixelSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSurfaceVariant
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: popupColumn.implicitWidth
            spacing: 4

            Repeater {
                model: 7
                delegate: Rectangle {
                    required property int index

                    readonly property var date: {
                        const today = root.today
                        const dow = today.getDay()
                        const d = new Date(today)
                        d.setDate(today.getDate() - dow + index)
                        return d
                    }
                    readonly property bool isToday: {
                        const t = root.today
                        return date.getDate()     === t.getDate() &&
                               date.getMonth()    === t.getMonth() &&
                               date.getFullYear() === t.getFullYear()
                    }

                    Layout.fillWidth: true
                    height: Math.max(58, Math.round(60 * Appearance.fontSizeScale))
                    radius: Appearance.rounding.normal
                    color: isToday
                        ? Appearance.colors.colPrimaryContainer
                        : Appearance.colors.colSurfaceContainerHigh

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Qt.locale().toString(date, "ddd").slice(0, 2)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnSurfaceVariant
                            font.weight: isToday ? Font.Bold : Font.Normal
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: date.getDate()
                            font.pixelSize: isToday
                                ? Appearance.font.pixelSize.normal
                                : Appearance.font.pixelSize.small
                            font.weight: isToday ? Font.Bold : Font.Normal
                            color: isToday
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }

        Row {
            Layout.fillWidth: true
            Layout.maximumWidth: popupColumn.implicitWidth
            spacing: 6

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter

                MaterialShapeWrappedMaterialSymbol {
                    shape: MaterialShape.Shape.Clover4Leaf
                    text: "checklist"
                    iconSize: Appearance.font.pixelSize.large
                    implicitSize: 36
                    color: Appearance.colors.colPrimaryContainer
                    colSymbol: Appearance.colors.colPrimary
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${Todo.list.filter(t => !t.done).length}`
                    font.pixelSize: Appearance.font.pixelSize.huge
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                }
            }

            Column {
                // From the card, not from the Row: the Row sizes itself to its
                // children, so deriving this from parent.width fed back into it
                // and the block grew past the popup on both sides.
                width: popupColumn.implicitWidth - 44 - 8
                spacing: 3

                Repeater {
                    id: todoRepeater
                    model: Math.min(3, Todo.list.filter(t => !t.done).length)

                    delegate: Rectangle {
                        required property int index
                        readonly property var filteredList: Todo.list.filter(t => !t.done)
                        readonly property var todo: filteredList[filteredList.length - 1 - index]
                        readonly property int total: todoRepeater.count
                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === total - 1
                        readonly property real bigRadius: Appearance.rounding.normal
                        readonly property real smallRadius: Appearance.rounding.unsharpenmore

                        width: parent.width
                        height: 32
                        topLeftRadius:     isFirst ? bigRadius : smallRadius
                        topRightRadius:    isFirst ? bigRadius : smallRadius
                        bottomLeftRadius:  isLast  ? bigRadius : smallRadius
                        bottomRightRadius: isLast  ? bigRadius : smallRadius
                        color: Appearance.colors.colSurfaceContainerHigh

                        StyledText {
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                                right: parent.right
                                rightMargin: 10
                            }
                            text: `    ${todo.content} `
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(64, Math.round(68 * Appearance.fontSizeScale))
                    visible: Todo.list.filter(t => !t.done).length === 0
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerHigh

                    StyledText {
                        anchors.centerIn: parent
                        text: Translation.tr("No pending tasks")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(20, Appearance.font.pixelSize.small + 6)
            spacing: 6

            MaterialSymbol {
                text: "timelapse"
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("System Uptime") + "  •  " + DateTime.uptime
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }
}
