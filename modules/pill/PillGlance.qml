pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Glance surface: the day at one look — current weather, today's agenda and
 * pending tasks side by side, so none of them needs its own trip through the
 * pill. Not a Ricelin port; an iNiR-original surface written in the same
 * washi/flame dialect (hairline columns, tracked caption headers, one warm
 * accent for "next up").
 *
 * Interactions stay light: the weather and agenda columns jump to the calendar
 * surface, a task's ring ticks it done in place.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 14

    /** Ask the pill to morph into a sibling surface (calendar). */
    signal requestJump(string surface)

    readonly property int maxRows: 4

    SystemClock {
        id: tick
        precision: SystemClock.Minutes
    }

    readonly property var now: tick.date
    readonly property string todayKey: now.getFullYear() + "-"
        + String(now.getMonth() + 1).padStart(2, "0") + "-"
        + String(now.getDate()).padStart(2, "0")
    readonly property string nowHm: String(now.getHours()).padStart(2, "0")
        + ":" + String(now.getMinutes()).padStart(2, "0")

    readonly property var events: PillEvents.forDate(todayKey)

    /** First timed event still ahead of the clock; the accent lands on it. */
    readonly property int nextEventIdx: {
        for (var i = 0; i < events.length; i++)
            if (events[i].time.length > 0 && events[i].time >= nowHm)
                return i;
        return -1;
    }

    /** Pending tasks with their index in Todo.list kept, so a tick maps back. */
    readonly property var pendingTodos: {
        void Todo.list;
        const out = [];
        const l = Todo.list ?? [];
        for (var i = 0; i < l.length; i++)
            if (!l[i].done)
                out.push({ content: l[i].content ?? "", idx: i });
        return out;
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: PillTheme.showGlyphs
                text: PillTheme.glyph("glance")
                color: PillTheme.cream
                font.family: PillTheme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("TODAY")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale().toString(root.now, "ddd d MMM")
            color: PillTheme.dim
            font.family: PillTheme.font
            font.pixelSize: 10.5 * root.s
            font.weight: Font.Bold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2 * root.s
            font.features: ({ "tnum": 1 })
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    /** Tiny tracked caption over each column. */
    component ColCaption: Text {
        color: PillTheme.faint
        font.family: PillTheme.font
        font.pixelSize: 10 * root.s
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1.4 * root.s
    }

    component ColRule: Rectangle {
        width: 1
        color: PillTheme.hairSoft
    }

    Item {
        id: body
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Item {
            id: weatherCol
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 120 * root.s

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 14 * root.s
                spacing: 5 * root.s

                GlyphIcon {
                    name: PillWeather.ready
                        ? PillWeather.glyphFor(PillWeather.codeNow, PillWeather.isDay) : "cloud"
                    width: 20 * root.s
                    height: 20 * root.s
                    color: PillTheme.subtle
                    stroke: 1.8
                }

                Text {
                    text: PillWeather.ready ? PillWeather.tempNow + "°" : "--°"
                    color: PillTheme.cream
                    font.family: PillTheme.font
                    font.pixelSize: 27 * root.s
                    font.weight: Font.ExtraBold
                    font.letterSpacing: -0.8 * root.s
                    font.features: ({ "tnum": 1 })
                }

                Text {
                    text: PillWeather.ready ? PillWeather.labelFor(PillWeather.codeNow) : Translation.tr("No data")
                    color: PillTheme.dim
                    width: weatherCol.width - 10 * root.s
                    elide: Text.ElideRight
                    font.family: PillTheme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.1 * root.s
                }

                Row {
                    spacing: 6 * root.s
                    visible: PillWeather.ready && PillWeather.daily.length > 0
                    Text {
                        text: (PillWeather.daily[0]?.temp ?? "--") + "°"
                        color: PillTheme.subtle
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        text: (PillWeather.daily[0]?.lo ?? "--") + "°"
                        color: PillTheme.faint
                        font.family: PillTheme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestJump("calendar")
            }
        }

        ColRule {
            id: ruleA
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: weatherCol.right
        }

        Item {
            id: agendaCol
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: ruleA.right
            anchors.right: ruleB.left
            anchors.leftMargin: 12 * root.s
            anchors.rightMargin: 12 * root.s

            ColCaption {
                id: agendaCap
                text: Translation.tr("Agenda")
            }

            Column {
                anchors.top: agendaCap.bottom
                anchors.topMargin: 7 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6 * root.s

                Repeater {
                    model: root.events.slice(0, root.maxRows)

                    Row {
                        id: evRow
                        required property var modelData
                        required property int index
                        readonly property bool isNext: index === root.nextEventIdx

                        width: parent.width
                        spacing: 8 * root.s

                        Text {
                            width: 34 * root.s
                            text: evRow.modelData.time.length > 0 ? evRow.modelData.time : "—"
                            color: evRow.isNext ? PillTheme.vermLit : PillTheme.dim
                            font.family: PillTheme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: evRow.isNext ? Font.Bold : Font.Medium
                            font.features: ({ "tnum": 1 })
                        }
                        Text {
                            width: parent.width - 42 * root.s
                            text: evRow.modelData.text
                            color: evRow.isNext ? PillTheme.cream : PillTheme.subtle
                            elide: Text.ElideRight
                            font.family: PillTheme.font
                            font.pixelSize: 11 * root.s
                            font.weight: evRow.isNext ? Font.DemiBold : Font.Medium
                        }
                    }
                }

                Text {
                    visible: root.events.length > root.maxRows
                    text: "+" + (root.events.length - root.maxRows) + " " + Translation.tr("more")
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.Medium
                }
            }

            Text {
                visible: root.events.length === 0
                anchors.centerIn: parent
                text: Translation.tr("Clear day")
                color: PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestJump("calendar")
            }
        }

        ColRule {
            id: ruleB
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: taskCol.left
            anchors.rightMargin: 12 * root.s
        }

        Item {
            id: taskCol
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 164 * root.s

            ColCaption {
                id: taskCap
                text: Translation.tr("Tasks")
            }

            Text {
                anchors.right: parent.right
                anchors.baseline: taskCap.baseline
                visible: root.pendingTodos.length > 0
                text: root.pendingTodos.length
                color: PillTheme.dim
                font.family: PillTheme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
            }

            Column {
                anchors.top: taskCap.bottom
                anchors.topMargin: 7 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 5 * root.s

                Repeater {
                    model: root.pendingTodos.slice(0, root.maxRows)

                    Item {
                        id: todoRow
                        required property var modelData

                        width: parent.width
                        height: 22 * root.s

                        Rectangle {
                            id: ring
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14 * root.s
                            height: 14 * root.s
                            radius: width / 2
                            color: ringArea.containsMouse ? Qt.alpha(PillTheme.vermLit, 0.25) : "transparent"
                            border.width: 1
                            border.color: ringArea.containsMouse ? PillTheme.vermLit : PillTheme.border

                            MouseArea {
                                id: ringArea
                                anchors.fill: parent
                                anchors.margins: -4 * root.s
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Todo.markDone(todoRow.modelData.idx)
                            }
                        }

                        Text {
                            anchors.left: ring.right
                            anchors.leftMargin: 8 * root.s
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: todoRow.modelData.content
                            color: PillTheme.subtle
                            elide: Text.ElideRight
                            font.family: PillTheme.font
                            font.pixelSize: 11.5 * root.s
                            font.weight: Font.Medium
                        }
                    }
                }

                Text {
                    visible: root.pendingTodos.length > root.maxRows
                    text: "+" + (root.pendingTodos.length - root.maxRows) + " " + Translation.tr("more")
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.Medium
                }
            }

            Text {
                visible: root.pendingTodos.length === 0
                anchors.centerIn: parent
                text: Translation.tr("All done")
                color: PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
            }
        }
    }
}
