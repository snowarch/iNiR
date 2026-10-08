pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.background.widgets.instrument

// Screen Time as an Instrument log: the day's total, a 24-hour histogram of real minutes and the
// leading apps as ruled rows. Hours are magnitudes, so bars, never a ring.
Item {
    id: root

    required property var widget
    readonly property real s: root.widget.scaleFactor
    readonly property color ink: root.widget.widgetInk
    readonly property color muted: root.widget.widgetInkMuted
    readonly property color accent: root.widget.widgetAccentVisible

    property int revision: 0
    readonly property bool on: ScreenTime.enabled
    readonly property var today: { void root.revision; return ScreenTime.getToday() }
    readonly property int total: Number(root.today?.totalSeconds ?? 0)
    readonly property var hourly: Array.from(root.today?.hourly ?? []).concat(new Array(24).fill(0)).slice(0, 24)
    readonly property real hourPeak: Math.max(900, ...root.hourly)
    readonly property int hourNow: { void root.revision; return new Date().getHours() }
    readonly property var apps: { void root.revision; return root.on ? ScreenTime.getAppList(1) : [] }
    readonly property var topApps: root.apps.slice(0, 3)

    function hm(seconds: int): string {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        return hours > 0 ? hours + Translation.tr("h") + " " + String(minutes).padStart(2, "0") + Translation.tr("m")
            : minutes + Translation.tr("m")
    }

    Connections {
        target: ScreenTime
        enabled: root.widget.visible && root.widget.powerActive
        function onDataChanged(): void { root.revision++ }
    }

    implicitWidth: Math.round(300 * root.s)
    implicitHeight: column.implicitHeight + Math.round(24 * root.s)

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.s)
        spacing: Math.round(6 * root.s)

        InstrumentLabel {
            Layout.fillWidth: true
            text: root.on ? Translation.tr("Screen / Today") : Translation.tr("Screen / Off")
            color: root.accent
            scaleFactor: root.s
            strong: true
        }

        StyledText {
            Layout.fillWidth: true
            text: root.on ? root.hm(root.total) : Translation.tr("Not recording")
            color: root.ink
            font.family: root.on ? root.widget.widgetNumbersFamily : root.widget.widgetTitleFamily
            font.pixelSize: Math.round((root.on ? 30 : 18) * root.s)
            font.weight: Font.Bold
            font.features: ({ "tnum": 1 })
        }

        RippleButton {
            visible: !root.on
            implicitHeight: Math.round(28 * root.s)
            implicitWidth: offLabel.implicitWidth + Math.round(20 * root.s)
            buttonRadius: Math.round(6 * root.s)
            colBackground: ColorUtils.applyAlpha(root.accent, 0.14)
            colBackgroundHover: ColorUtils.applyAlpha(root.accent, 0.22)
            colRipple: ColorUtils.applyAlpha(root.accent, 0.3)
            downAction: () => Config.setNestedValue("sidebar.screenTime.enable", true)
            contentItem: InstrumentLabel {
                id: offLabel
                anchors.centerIn: parent
                text: Translation.tr("Turn on")
                color: root.ink
                scaleFactor: root.s
                size: 10
                strong: true
            }
        }

        Item {
            visible: root.on
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(40 * root.s)

            Row {
                id: bars
                anchors.fill: parent
                anchors.bottomMargin: Math.round(12 * root.s)
                spacing: Math.max(1, Math.round(2 * root.s))
                readonly property real barWidth: (width - spacing * 23) / 24
                Repeater {
                    model: 24
                    Item {
                        id: hour
                        required property int index
                        width: bars.barWidth
                        height: bars.height
                        readonly property real share: Math.min(1, root.hourly[hour.index] / root.hourPeak)
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: Math.max(1, Math.round(parent.height * hour.share))
                            color: hour.index === root.hourNow ? root.accent
                                : ColorUtils.applyAlpha(root.ink, hour.share > 0 ? 0.62 : 0.18)
                        }
                    }
                }
            }
            Repeater {
                model: [0, 6, 12, 18]
                InstrumentLabel {
                    required property int modelData
                    x: Math.round(modelData * (bars.barWidth + bars.spacing))
                    anchors.bottom: parent.bottom
                    text: String(modelData).padStart(2, "0")
                    color: root.muted
                    scaleFactor: root.s
                    size: 8
                }
            }
        }

        Repeater {
            model: root.on ? root.topApps : []
            ColumnLayout {
                id: appRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Math.round(3 * root.s)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * root.s)
                    InstrumentLabel {
                        text: String(appRow.index + 1).padStart(2, "0")
                        color: root.muted
                        scaleFactor: root.s
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: appRow.modelData.name
                        color: root.ink
                        elide: Text.ElideRight
                        font.pixelSize: Math.round(12 * root.s)
                        font.weight: Font.Medium
                    }
                    StyledText {
                        text: root.hm(appRow.modelData.seconds)
                        color: root.ink
                        font.family: root.widget.widgetNumbersFamily
                        font.pixelSize: Math.round(12 * root.s)
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: ColorUtils.applyAlpha(root.ink, 0.16)
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.min(1, appRow.modelData.seconds / Math.max(1, root.total))
                        color: root.accent
                    }
                }
            }
        }
    }
}
