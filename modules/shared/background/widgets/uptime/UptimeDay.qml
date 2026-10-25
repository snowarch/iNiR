pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Material's Medium and Large uptime: the time on as the figure and the session laid on the day under it, from when
// the machine woke to now. Large adds when it started, how much of today it has been on and which day of it this is.
Item {
    id: root

    required property var widget
    property bool large: false

    readonly property real s: root.widget.scaleFactor
    function px(value: real): int { return Math.round(value * root.s) }
    readonly property color ink: root.widget.surfaceInk
    readonly property color inkMuted: ColorUtils.applyAlpha(root.ink, 0.66)

    readonly property real from: root.widget.sessionFrom
    readonly property real to: root.widget.sessionTo
    readonly property var marks: root.widget.sessionMarks
    readonly property string since: root.widget.sinceYesterday ? root.widget.startedText
        : Translation.tr("Since %1").arg(root.widget.bootLabel)
    readonly property var facts: [
        { glyph: "login", label: Translation.tr("Started"), value: root.widget.startedText },
        { glyph: "today", label: Translation.tr("On today"), value: root.widget.onTodayText },
        root.widget.sessionDay > 1
            ? { glyph: "dns", label: Translation.tr("Session day"), value: String(root.widget.sessionDay) }
            : { glyph: "dns", label: Translation.tr("Machine"), value: SystemInfo.hostname || SystemInfo.distroName }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.px(16)
        spacing: root.px(root.large ? 10 : 6)

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: root.px(10)
            Rectangle {
                implicitWidth: root.px(36)
                implicitHeight: implicitWidth
                radius: width / 2
                color: root.widget.widgetSemanticContainer(root.widget.widgetTertiaryRole)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "avg_pace"
                    fill: 1
                    iconSize: root.px(20)
                    color: root.widget.widgetSemanticOnContainer(root.widget.widgetTertiaryRole)
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Uptime")
                color: root.inkMuted
                elide: Text.ElideRight
                font.pixelSize: root.px(Appearance.font.pixelSize.small)
                font.weight: Font.Medium
            }
            StyledText {
                // large says when it started in its facts
                visible: !root.large && root.widget.showSince
                text: root.since
                color: root.inkMuted
                font.pixelSize: root.px(Appearance.font.pixelSize.smaller)
            }
        }

        Row {
            spacing: root.px(8)
            Repeater {
                model: root.widget.materialParts
                Row {
                    id: part
                    required property var modelData
                    spacing: root.px(2)
                    StyledText {
                        id: partValue
                        text: String(part.modelData.value)
                        color: root.ink
                        font.family: root.widget.widgetNumbersFamily
                        font.pixelSize: root.px(root.large ? 56 : 44)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    StyledText {
                        anchors.baseline: partValue.baseline
                        text: part.modelData.unit
                        color: root.inkMuted
                        font.pixelSize: root.px(root.large ? 22 : 18)
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; visible: !root.large }

        // The day, and the stretch of it the machine has been on.
        Rectangle {
            id: track
            Layout.fillWidth: true
            implicitHeight: root.px(root.large ? 16 : 12)
            radius: height / 2
            color: ColorUtils.applyAlpha(root.ink, 0.12)
            Rectangle {
                x: track.width * root.from
                width: Math.max(track.height, track.width * (root.to - root.from))
                height: track.height
                radius: height / 2
                color: root.widget.widgetAccentVisible
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.topMargin: -root.px(2)
            visible: root.large
            Repeater {
                model: root.marks
                StyledText {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    horizontalAlignment: index === 0 ? Text.AlignLeft : index === root.marks.length - 1 ? Text.AlignRight : Text.AlignHCenter
                    text: String(modelData)
                    color: root.inkMuted
                    font.family: root.widget.widgetNumbersFamily
                    font.pixelSize: root.px(Appearance.font.pixelSize.smallest)
                }
            }
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            visible: root.large
            spacing: root.px(6)
            Repeater {
                model: root.large ? root.facts : []
                RowLayout {
                    id: fact
                    required property var modelData
                    required property int index
                    readonly property string role: fact.index % 2 === 0 ? root.widget.widgetSecondaryRole : root.widget.widgetTertiaryRole
                    Layout.fillWidth: true
                    spacing: root.px(10)
                    Rectangle {
                        implicitWidth: root.px(28)
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: root.widget.widgetSemanticContainer(fact.role)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: fact.modelData.glyph
                            fill: 1
                            iconSize: root.px(16)
                            color: root.widget.widgetSemanticOnContainer(fact.role)
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: fact.modelData.label
                        color: root.inkMuted
                        elide: Text.ElideRight
                        font.pixelSize: root.px(Appearance.font.pixelSize.small)
                    }
                    StyledText {
                        text: fact.modelData.value
                        color: root.ink
                        font.family: root.widget.widgetNumbersFamily
                        font.pixelSize: root.px(Appearance.font.pixelSize.small)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }
}
