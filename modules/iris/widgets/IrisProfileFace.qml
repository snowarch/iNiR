pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property string name: SystemInfo.displayName || SystemInfo.username || "user"
    readonly property string host: {
        const distro = String(SystemInfo.distroId ?? "").trim()
        const hostName = root.widget.showHostname ? String(SystemInfo.hostname ?? "") : ""
        return hostName.length > 0 ? hostName : distro.length > 0 && distro !== "unknown" ? distro : ""
    }
    readonly property string greeting: {
        const hour = DateTime.clock.date.getHours()
        return hour < 5 ? Translation.tr("Good night")
            : hour < 12 ? Translation.tr("Good morning")
            : hour < 19 ? Translation.tr("Good afternoon") : Translation.tr("Good evening")
    }
    readonly property string uptime: Translation.tr("On for %1").arg(DateTime.uptime || "--")

    component Actions: RowLayout {
        spacing: root.dp(6)
        FaceAction {
            face: root
            glyph: "lock"
            name: Translation.tr("Lock")
            onActivated: root.widget.lockScreen()
        }
        FaceAction {
            face: root
            glyph: "settings"
            name: Translation.tr("Settings")
            onActivated: GlobalStates.openSettings()
        }
        FaceAction {
            face: root
            glyph: "power_settings_new"
            name: Translation.tr("Session")
            danger: true
            onActivated: GlobalStates.sessionOpen = true
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(2)

        FaceAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.dp(64)
            Layout.preferredHeight: root.dp(64)
            visible: root.widget.showAvatar
        }
        Item { Layout.fillHeight: true }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.name
            size: 15
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.host.length > 0 ? root.host : root.uptime
            color: root.inkSecondary
            size: 12
        }
    }

    RowLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(16)

        FaceAvatar {
            visible: root.widget.showAvatar
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: root.dp(84)
            Layout.preferredHeight: root.dp(84)
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.greeting
                color: root.highlight
                size: 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.name
                size: 22
                weight: root.figureWeight
                font.family: IrisStyle.fontTitle
                font.letterSpacing: 0
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.host.length > 0 ? root.host + " · " + root.uptime : root.uptime
                color: root.inkSecondary
                size: 12
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(6)
                MaterialSymbol {
                    visible: root.widget.showWeather && Weather.enabled
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    fill: 1
                    iconSize: root.px(16)
                    color: IrisStyle.skyLight(text)
                }
                FaceText {
                    face: root
                    visible: root.widget.showWeather && Weather.enabled
                    Layout.fillWidth: true
                    text: String(Weather.data?.temp ?? "")
                    color: root.inkSecondary
                    size: 12
                }
                Item { Layout.fillWidth: !(root.widget.showWeather && Weather.enabled) }
                Actions {}
            }
        }
    }
}
