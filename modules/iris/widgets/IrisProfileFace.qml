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

    readonly property string shellName: String(Quickshell.env("SHELL") ?? "").split("/").pop() || "sh"
    readonly property string desktopName: IrisFaceData.capitalized(String(SystemInfo.desktopEnvironment || "Wayland").split(":")[0].toLowerCase())
    readonly property real dayGone: {
        const now = DateTime.clock.date
        return (now.getHours() * 60 + now.getMinutes()) / 1440
    }

    // SekaiPop's user card in iRiS: a banner that greets you, the avatar as a sticker on its edge, your name and
    // machine, how the machine is (up, shell, desktop) as keys, and how much of today is gone on a lane.
    component Banner: Rectangle {
        radius: root.innerRadius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.accent, 0.55) }
            GradientStop { position: 1; color: Qt.alpha(root.highlight, 0.35) }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: root.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: greetText.implicitWidth + root.dp(14)
            implicitHeight: root.dp(20)
            radius: height / 2
            color: Qt.alpha(root.knockout, 0.7)
            FaceText {
                id: greetText
                face: root
                anchors.centerIn: parent
                text: root.greeting
                size: 10.5
                weight: Font.DemiBold
            }
        }
    }

    component Sticker: Rectangle {
        property real side: root.dp(60)
        visible: root.widget.showAvatar
        width: side
        height: side
        radius: side / 2
        color: root.knockout
        rotation: avatarHover.hovered ? 4 : -3
        scale: avatarTap.pressed ? 0.9 : 1
        Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        FaceAvatar {
            anchors.fill: parent
            anchors.margins: root.dp(3)
        }
        HoverHandler { id: avatarHover }
        TapHandler { id: avatarTap }
    }

    component Key: Rectangle {
        id: fact
        property string word: ""
        property string value: ""
        implicitHeight: root.dp(44)
        radius: root.innerRadius
        color: root.fillQuiet
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - root.dp(10)
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: fact.word
                size: 10
                weight: Font.DemiBold
                color: root.inkTertiary
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: fact.value
                size: 13
                weight: Font.DemiBold
            }
        }
    }

    // How much of today is gone: gates at 6, 12 and 18 h, the present as a dot, the share on a chip.
    component DayLane: RowLayout {
        spacing: root.dp(8)
        MaterialSymbol {
            text: root.dayGone < 0.25 || root.dayGone > 0.8 ? "bedtime" : "wb_sunny"
            fill: 1
            iconSize: root.px(13)
            color: root.inkSecondary
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: root.dp(10)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root.dp(4)
                radius: height / 2
                color: root.fill
                Rectangle {
                    width: parent.width * root.dayGone
                    height: parent.height
                    radius: height / 2
                    color: root.accent
                }
            }
            Repeater {
                model: [0.25, 0.5, 0.75]
                Rectangle {
                    required property real modelData
                    x: parent.width * modelData - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(1, root.dp(1.5))
                    height: root.dp(10)
                    radius: width / 2
                    color: root.inkTertiary
                }
            }
            Rectangle {
                x: parent.width * root.dayGone - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: root.dp(9)
                height: width
                radius: width / 2
                color: root.accent
                border.width: Math.max(1, root.dp(1.5))
                border.color: root.knockout
            }
        }
        Rectangle {
            implicitWidth: dayText.implicitWidth + root.dp(12)
            implicitHeight: root.dp(18)
            radius: height / 2
            color: Qt.alpha(root.accent, 0.18)
            FaceText {
                id: dayText
                face: root
                anchors.centerIn: parent
                text: Math.round(root.dayGone * 100) + "%"
                size: 10.5
                weight: Font.DemiBold
                color: root.accent
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // Medium and large: banner, sticker and name, (keys,) the day.
    Item {
        visible: !root.small
        anchors.fill: parent
        Banner {
            id: banner
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.dp(root.large ? 70 : 40)
        }
        Sticker {
            id: sticker
            anchors.left: parent.left
            anchors.leftMargin: root.dp(10)
            y: banner.height - side * 0.55
            side: root.dp(root.large ? 76 : 56)
        }
        ColumnLayout {
            anchors.left: root.widget.showAvatar ? sticker.right : parent.left
            anchors.leftMargin: root.widget.showAvatar ? root.dp(10) : 0
            anchors.right: actions.left
            anchors.rightMargin: root.dp(6)
            anchors.top: banner.bottom
            anchors.topMargin: root.dp(4)
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.name
                size: root.large ? 20 : 16
                weight: Font.Bold
                font.family: IrisStyle.fontTitle
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.host.length > 0
                text: "@" + root.host
                color: root.inkSecondary
                size: 11.5
            }
        }
        Actions {
            id: actions
            anchors.right: parent.right
            anchors.top: banner.bottom
            anchors.topMargin: root.dp(8)
        }
        RowLayout {
            id: facts
            visible: root.large
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sticker.bottom
            anchors.topMargin: root.dp(14)
            spacing: root.dp(8)
            Key { Layout.fillWidth: true; word: Translation.tr("Uptime"); value: DateTime.uptime || "--" }
            Key { Layout.fillWidth: true; word: Translation.tr("Shell"); value: root.shellName }
            Key { Layout.fillWidth: true; word: Translation.tr("Desktop"); value: root.desktopName }
        }
        // Large: today at a glance between the keys and the lane.
        RowLayout {
            visible: root.large
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: facts.bottom
            anchors.bottom: lane.top
            anchors.topMargin: root.dp(8)
            anchors.bottomMargin: root.dp(8)
            spacing: root.dp(10)
            ColumnLayout {
                Layout.fillWidth: true
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
                    size: 30
                }
            }
            MaterialSymbol {
                visible: root.widget.showWeather && Weather.enabled
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                fill: 1
                iconSize: root.px(30)
                color: IrisStyle.skyLight(text)
            }
            FaceFigure {
                visible: root.widget.showWeather && Weather.enabled
                text: String(Weather.data?.temp ?? "").replace(/°[CF]$/, "°")
                face: root
                size: 30
            }
        }
        DayLane {
            id: lane
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
        }
    }
}
