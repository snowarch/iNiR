pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.pieces

IrisWidgetFace {
    id: root

    property int revision: 0
    readonly property bool on: ScreenTime.enabled
    readonly property var today: { void root.revision; return ScreenTime.getToday() }
    readonly property int total: Number(root.today?.totalSeconds ?? 0)
    readonly property var hourly: Array.from(root.today?.hourly ?? []).concat(new Array(24).fill(0)).slice(0, 24)
    readonly property real hourPeak: Math.max(900, ...root.hourly)
    readonly property int hourNow: { void root.revision; return new Date().getHours() }
    readonly property var apps: { void root.revision; return root.on ? ScreenTime.getAppList(1) : [] }
    readonly property int appCount: root.large ? 5 : root.medium ? 2 : 1
    readonly property var topApps: root.apps.slice(0, root.appCount)
    readonly property color tint: IrisStyle.identity.indigo

    function duration(seconds: int): string {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        return hours > 0 ? Translation.tr("%1 h %2 min").arg(hours).arg(minutes) : Translation.tr("%1 min").arg(minutes)
    }
    function shortDuration(seconds: int): string {
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor(seconds % 3600 / 60)
        return hours > 0 ? hours + Translation.tr("h") + " " + minutes + Translation.tr("m") : minutes + Translation.tr("m")
    }

    Connections {
        target: ScreenTime
        enabled: root.live
        function onDataChanged(): void { root.revision++ }
    }

    component AppIcon: SmartAppIcon {
        required property var app
        implicitSize: root.dp(root.small ? 22 : 20)
        icon: IrisPieces.appIcon(String(app?.originalId ?? app?.id ?? ""))
    }

    component HourBars: Row {
        id: bars
        property real barHeight: root.dp(56)
        spacing: Math.max(1, root.dp(2))
        readonly property real barWidth: (width - bars.spacing * 23) / 24
        Repeater {
            model: 24
            Item {
                id: hour
                required property int index
                width: bars.barWidth
                height: bars.barHeight
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(root.dp(3), parent.height * root.hourly[hour.index] / root.hourPeak)
                    radius: Math.min(width / 2, IrisStyle.radiusMicro)
                    color: hour.index === root.hourNow ? root.highlight
                        : root.hourly[hour.index] > 0 ? root.accent : root.fill
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.on
        spacing: root.dp(8)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "hourglass_bottom"
            text: Translation.tr("Screen Time")
            tint: root.tint
        }
        Item { Layout.fillHeight: true }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: Translation.tr("See where your day goes")
            size: root.small ? 13 : 14
            weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
        }
        FaceChoice {
            icon: "toggle_on"
            label: Translation.tr("Turn on")
            onClicked: Config.setNestedValue("sidebar.screenTime.enable", true)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.on
        spacing: root.dp(root.small ? 2 : 6)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "hourglass_bottom"
            text: Translation.tr("Screen Time")
            trailing: root.small ? "" : Translation.tr("Today")
            tint: root.tint
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(16)

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: root.small
                // As wide as today's total, so "13h 46m" is never cut; the bars take the rest.
                Layout.preferredWidth: root.medium ? Math.max(root.dp(96), totalFigure.implicitWidth) : -1
                visible: !root.large
                spacing: root.dp(2)

                Item { Layout.fillHeight: true }
                FaceFigure {
                    id: totalFigure
                    face: root
                    Layout.fillWidth: true
                    text: root.shortDuration(root.total)
                    size: root.small ? 32 : 30
                    elide: Text.ElideRight
                }
                RowLayout {
                    visible: root.small && root.topApps.length > 0
                    Layout.fillWidth: true
                    spacing: root.dp(6)
                    AppIcon { app: root.topApps[0] ?? null }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: root.topApps[0]?.name ?? ""
                        color: root.inkSecondary
                        size: 12
                    }
                }
                FaceText {
                    face: root
                    visible: root.medium && ScreenTime.currentAppName.length > 0
                    Layout.fillWidth: true
                    text: Translation.tr("Now: %1").arg(ScreenTime.currentAppName)
                    color: root.inkTertiary
                    size: 11.5
                }
            }

            ColumnLayout {
                visible: root.medium
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(10)

                Item { Layout.fillHeight: true }
                HourBars {
                    Layout.fillWidth: true
                    barHeight: root.dp(52)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.dp(10)
                    Repeater {
                        model: root.topApps
                        RowLayout {
                            id: chip
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: root.dp(4)
                            AppIcon { app: chip.modelData }
                            FaceText {
                                face: root
                                Layout.fillWidth: true
                                text: root.shortDuration(chip.modelData.seconds)
                                color: root.inkSecondary
                                font.family: root.fontNumbers
                                font.features: ({ "tnum": 1 })
                                size: 11.5
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: root.large
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(8)

                RowLayout {
                    Layout.fillWidth: true
                    FaceFigure {
                        face: root
                        text: root.duration(root.total)
                        size: 34
                    }
                    Item { Layout.fillWidth: true }
                }
                HourBars {
                    Layout.fillWidth: true
                    barHeight: root.dp(70)
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: root.dp(4)
                    implicitHeight: 1
                    color: root.hairline
                }
                Repeater {
                    model: root.topApps
                    RowLayout {
                        id: appRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: root.dp(10)
                        AppIcon { app: appRow.modelData; implicitSize: root.dp(22) }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: root.dp(3)
                            RowLayout {
                                Layout.fillWidth: true
                                FaceText {
                                    face: root
                                    Layout.fillWidth: true
                                    text: appRow.modelData.name
                                    size: 12.5
                                    weight: Font.DemiBold
                                }
                                FaceText {
                                    face: root
                                    text: root.shortDuration(appRow.modelData.seconds)
                                    color: root.inkSecondary
                                    font.family: root.fontNumbers
                                    font.features: ({ "tnum": 1 })
                                    size: 11.5
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: root.dp(4)
                                radius: height / 2
                                color: root.fill
                                Rectangle {
                                    width: parent.width * Math.min(1, appRow.modelData.seconds / Math.max(1, root.topApps[0]?.seconds ?? 1))
                                    height: parent.height
                                    radius: height / 2
                                    color: root.accent
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
