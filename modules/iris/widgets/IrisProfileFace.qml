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
            glyph: "lock"
            name: Translation.tr("Lock")
            onActivated: root.widget.lockScreen()
        }
        FaceAction {
            face: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            glyph: "settings"
            name: Translation.tr("Settings")
            onActivated: GlobalStates.openSettings()
        }
        FaceAction {
            face: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.dp(34)
            glyph: "power_settings_new"
            name: Translation.tr("Session")
            danger: true
            onActivated: GlobalStates.sessionOpen = true
        }
    }

    // A fact of the machine: the word over its value, centred in a quiet well.
    component Key: Rectangle {
        id: fact
        property string word: ""
        property string value: ""
        implicitHeight: root.dp(50)
        radius: root.innerRadius
        color: root.fillQuiet
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - root.dp(12)
            spacing: root.dp(1)
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: fact.word
                size: 11
                color: root.inkSecondary
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: fact.value
                size: 14
                weight: Font.DemiBold
            }
        }
    }

    // Who is here: greeting, name and machine beside the avatar.
    component Who: RowLayout {
        spacing: root.dp(12)
        FaceAvatar {
            visible: root.widget.showAvatar
            Layout.preferredWidth: root.dp(root.large ? 64 : 52)
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
                size: root.large ? 22 : 19
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

    // Medium: who, then the keys along the bottom. Large: who, the day and the weather, the machine, the keys.
    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(10)

        Who { Layout.fillWidth: true }
        Item { Layout.fillHeight: true; visible: !root.large }

        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(10)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                spacing: 0
                FaceText {
                    face: root
                    text: IrisFaceData.capitalized(Translation.locale.toString(DateTime.clock.date, "dddd"))
                    color: root.highlight
                    size: 12.5
                    weight: Font.DemiBold
                }
                FaceFigure {
                    face: root
                    text: Translation.locale.toString(DateTime.clock.date, "d MMM").replace(/\./g, "")
                    size: 32
                }
            }
            ColumnLayout {
                visible: root.widget.showWeather && Weather.enabled
                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignRight
                    text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                    fill: 1
                    iconSize: root.px(20)
                    color: IrisStyle.skyLight(text)
                }
                FaceFigure {
                    Layout.alignment: Qt.AlignRight
                    text: String(Weather.data?.temp ?? "").replace(/°[CF]$/, "°")
                    face: root
                    size: 32
                }
            }
        }
        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            spacing: root.dp(8)
            Key { Layout.fillWidth: true; word: Translation.tr("Uptime"); value: DateTime.uptime || "--" }
            Key { Layout.fillWidth: true; word: Translation.tr("Shell"); value: root.shellName }
            Key { Layout.fillWidth: true; word: Translation.tr("Desktop"); value: root.desktopName }
        }
        Actions { Layout.fillWidth: true }
    }
}
