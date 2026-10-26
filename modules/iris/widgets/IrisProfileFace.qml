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
    designFace: IrisDesign.skin("widgetProfile")

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

    readonly property string shellName: String(Quickshell.env("SHELL") ?? "").split("/").pop() || "sh"
    readonly property string desktopName: IrisFaceData.capitalized(String(SystemInfo.desktopEnvironment || "Wayland").split(":")[0].toLowerCase())

    // Lock, Settings and the session as one row of capsules across the face, like a contact's call keys.
    component Actions: RowLayout {
        spacing: root.dp(8)
        FaceAction {
            face: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            worded: true
            glyph: "lock"
            name: Translation.tr("Lock")
            onActivated: root.widget.lockScreen()
        }
        FaceAction {
            face: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            worded: true
            glyph: "settings"
            name: Translation.tr("Settings")
            onActivated: GlobalStates.openSettings()
        }
        FaceAction {
            face: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            worded: true
            glyph: "power_settings_new"
            name: Translation.tr("Session")
            danger: true
            onActivated: GlobalStates.sessionOpen = true
        }
    }

    // Who is here: greeting, name and machine beside the avatar.
    component Who: RowLayout {
        spacing: root.dp(12)
        FaceAvatar {
            visible: root.widget.showAvatar
            Layout.preferredWidth: root.dp(root.large ? 76 : 52)
            Layout.preferredHeight: Layout.preferredWidth
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.greeting
                color: root.heading
                size: 12.5
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.name
                size: root.large ? 26 : 19
                weight: Font.DemiBold
                font.family: IrisStyle.fontTitle
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.host.length > 0
                text: root.host
                color: root.inkSecondary
                size: 12
            }
            // medium has the room and nothing else to say: how long the machine has been on
            FaceText {
                face: root
                Layout.fillWidth: true
                Layout.topMargin: root.dp(2)
                visible: root.medium
                text: root.uptime
                color: root.inkTertiary
                size: 12
                font.features: ({ "tnum": 1 })
            }
        }
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(1)

        Item { Layout.fillHeight: true }
        FaceAvatar {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.dp(68)
            Layout.preferredHeight: root.dp(68)
            Layout.bottomMargin: root.dp(8)
            visible: root.widget.showAvatar
        }
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
        Item { Layout.fillHeight: true }
    }

    // Medium: who, then the keys along the bottom. Large: who, the machine as the Day's fact rows (and the weather,
    // when shown), the keys; the wells of facts and the date beside them were a second widget inside this one.
    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(10)

        Who { Layout.fillHeight: false; Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        ColumnLayout {
            visible: root.large
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.bottomMargin: root.dp(4)
            spacing: root.dp(8)
            FaceFact { face: root; Layout.fillWidth: true; rule: false; glyph: "avg_pace"; label: Translation.tr("Uptime"); value: DateTime.uptime || "--" }
            FaceFact { face: root; Layout.fillWidth: true; glyph: "terminal"; label: Translation.tr("Shell"); value: root.shellName }
            FaceFact { face: root; Layout.fillWidth: true; glyph: "desktop_windows"; label: Translation.tr("Desktop"); value: root.desktopName }
            FaceFact {
                face: root
                visible: root.widget.showWeather && Weather.enabled && String(Weather.data?.temp ?? "").length > 0
                Layout.fillWidth: true
                glyph: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                tint: IrisStyle.skyLight(glyph)
                label: Translation.tr("Weather")
                value: String(Weather.data?.temp ?? "").replace(/°[CF]$/, "°")
            }
        }
        Actions { Layout.fillHeight: false; Layout.fillWidth: true }
    }
}
