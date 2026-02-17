pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root
    implicitHeight: row.implicitHeight

    property var locale: {
        const env = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (env.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }

    property int weekOffset: 0
    property var today: new Date()
    property var weekStart: {
        const fdow = locale?.firstDayOfWeek ?? Qt.locale().firstDayOfWeek
        const d = new Date(today)
        d.setDate(d.getDate() + weekOffset * 7)
        const diff = d.getDay() - fdow
        d.setDate(d.getDate() - (diff < 0 ? diff + 7 : diff))
        return d
    }

    // Nombre del mes de la semana mostrada
    readonly property string displayedMonth: locale.toString(weekStart, "MMMM yyyy")

    property var days: {
        const arr = []
        for (let i = 0; i < 7; i++) {
            const d = new Date(weekStart)
            d.setDate(weekStart.getDate() + i)
            const isToday = d.getDate() === today.getDate() &&
                           d.getMonth() === today.getMonth() &&
                           d.getFullYear() === today.getFullYear()
            arr.push({
                dayNum: d.getDate(),
                dayName: locale.toString(d, "ddd").substring(0, 2),
                isToday: isToday && weekOffset === 0,
                isWeekend: d.getDay() === 0 || d.getDay() === 6
            })
        }
        return arr
    }

    // Cached color properties to avoid repeated ternary evaluation
    readonly property color colSubtext: Appearance.inirEverywhere ? Appearance.inir?.colTextMuted ?? Appearance.colors?.colSubtext ?? "gray"
                                      : Appearance.auroraEverywhere ? Appearance.aurora?.colOnSubSurface ?? Appearance.colors?.colSubtext ?? "gray"
                                      : Appearance.colors?.colSubtext ?? "gray"
    readonly property color colPrimary: Appearance.inirEverywhere ? Appearance.inir?.colPrimary ?? Appearance.colors?.colPrimary ?? "blue"
                                      : Appearance.auroraEverywhere ? Appearance.aurora?.colAccent ?? Appearance.colors?.colPrimary ?? "blue"
                                      : Appearance.colors?.colPrimary ?? "blue"
    readonly property color colText: Appearance.inirEverywhere ? Appearance.inir?.colText ?? Appearance.colors?.colOnLayer1 ?? "white"
                                   : Appearance.auroraEverywhere ? Appearance.aurora?.colOnSurface ?? Appearance.colors?.colOnLayer1 ?? "white"
                                   : Appearance.colors?.colOnLayer1 ?? "white"
    readonly property color colLabel: Appearance.inirEverywhere ? Appearance.inir?.colLabel ?? Appearance.colors?.colPrimary ?? "blue"
                                    : Appearance.colors?.colPrimary ?? "blue"
    readonly property color colLayer1Hover: Appearance.angelEverywhere ? Appearance.angel?.colGlassCardHover ?? Appearance.colors?.colLayer1Hover ?? "gray"
                                          : Appearance.inirEverywhere ? Appearance.inir?.colLayer1Hover ?? Appearance.colors?.colLayer1Hover ?? "gray"
                                          : Appearance.auroraEverywhere ? Appearance.aurora?.colSubSurface ?? Appearance.colors?.colLayer1Hover ?? "gray"
                                          : Appearance.colors?.colLayer1Hover ?? "gray"
    readonly property color colLayer1Active: Appearance.angelEverywhere ? Appearance.angel?.colGlassCardActive ?? Appearance.colors?.colLayer1Active ?? "gray"
                                           : Appearance.inirEverywhere ? Appearance.inir?.colLayer1Active ?? Appearance.colors?.colLayer1Active ?? "gray"
                                           : Appearance.auroraEverywhere ? Appearance.aurora?.colSubSurfaceActive ?? Appearance.colors?.colLayer1Active ?? "gray"
                                           : Appearance.colors?.colLayer1Active ?? "gray"
    readonly property color colPrimaryContainer: Appearance.inirEverywhere ? Appearance.inir?.colPrimaryContainer ?? Appearance.colors?.colPrimaryContainer ?? "blue"
                                               : Appearance.colors?.colPrimaryContainer ?? "blue"
    readonly property color colPrimaryActive: Appearance.inirEverywhere ? Appearance.inir?.colPrimaryActive ?? Appearance.colors?.colPrimaryContainerActive ?? "blue"
                                            : Appearance.colors?.colPrimaryContainerActive ?? "blue"
    readonly property real buttonRadius: Appearance.angelEverywhere ? Appearance.angel?.roundingSmall ?? 2
                                       : Appearance.inirEverywhere ? Appearance.inir?.roundingSmall ?? Appearance.rounding?.small ?? 8
                                       : Appearance.rounding?.small ?? 8

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (e) => { root.weekOffset += e.angleDelta.y > 0 ? -1 : 1 }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 2

        RippleButton {
            implicitWidth: 20; implicitHeight: 36
            buttonRadius: root.buttonRadius
            colBackground: "transparent"
            colBackgroundHover: root.colLayer1Hover
            colRipple: root.colLayer1Active
            onClicked: root.weekOffset--

            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_left"
                    iconSize: 12
                    color: root.colSubtext
                }
            }

            StyledToolTip { text: Translation.tr("Previous week") }
        }

        // Indicador de mes cuando no es la semana actual
        StyledText {
            opacity: root.weekOffset !== 0 ? 1 : 0
            visible: opacity > 0
            text: root.displayedMonth
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.weight: Font.Medium
            color: root.colLabel
            Layout.leftMargin: 4

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }

        // Botón para volver a hoy
        RippleButton {
            implicitWidth: 24; implicitHeight: 36
            buttonRadius: root.buttonRadius
            colBackground: "transparent"
            colBackgroundHover: root.colPrimaryContainer
            colRipple: root.colPrimaryActive
            opacity: root.weekOffset !== 0 ? 1 : 0
            visible: opacity > 0
            onClicked: root.weekOffset = 0

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "today"
                    iconSize: 14
                    color: root.colLabel
                }
            }

            StyledToolTip { text: Translation.tr("Go to today") }
        }

        Repeater {
            model: root.days

            Item {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 36

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.dayName
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: root.colSubtext
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.dayNum
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: modelData.isToday ? Font.Bold : Font.Normal
                        font.family: Appearance.font.family.numbers
                        color: modelData.isToday ? root.colPrimary
                             : modelData.isWeekend ? root.colSubtext
                             : root.colText
                    }
                }
            }
        }

        RippleButton {
            implicitWidth: 20; implicitHeight: 36
            buttonRadius: root.buttonRadius
            colBackground: "transparent"
            colBackgroundHover: root.colLayer1Hover
            colRipple: root.colLayer1Active
            onClicked: root.weekOffset++

            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "chevron_right"
                    iconSize: 12
                    color: root.colSubtext
                }
            }

            StyledToolTip { text: Translation.tr("Next week") }
        }
    }
}
