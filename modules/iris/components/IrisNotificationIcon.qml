pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root

    property string appName: ""
    property string appIcon: ""
    property string image: ""
    property string summary: ""
    property bool critical: false
    property bool showImage: true
    property real size: 38

    implicitWidth: root.size
    implicitHeight: root.size

    readonly property string themedImage: {
        const themed = root.image.match(/^image:\/\/icon\/(.+)$/)
        return themed ? decodeURIComponent(themed[1]) : ""
    }
    readonly property bool hasImage: root.showImage && root.image.length > 0 && root.themedImage.length === 0
    readonly property bool fromShell: /^(inir|iris|quickshell|illogical)/i.test(root.appName)
    readonly property string resolvedIcon: {
        if (root.fromShell) return ""
        const candidates = [root.appIcon, root.themedImage, AppSearch.lookupDesktopEntry(root.appName)?.icon ?? ""]
        for (const icon of candidates) {
            const name = String(icon ?? "")
            if (name.length === 0) continue
            if (name.startsWith("/") || name.startsWith("file:") || AppSearch.iconExists(name)) return name
        }
        return ""
    }
    readonly property bool iconFile: root.resolvedIcon.startsWith("/") || root.resolvedIcon.startsWith("file:")
    readonly property var semantic: {
        const text = (root.appName + " " + root.appIcon + " " + root.summary).toLowerCase()
        const rules = [
            [/screenshot|screen shot|captur/, "screenshot_region", IrisStyle.identity.blue],
            [/record/, "videocam", IrisStyle.identity.pink],
            [/battery|charg|power/, "battery_charging_full", IrisStyle.identity.green],
            [/bluetooth/, "bluetooth", IrisStyle.identity.blue],
            [/network|wi-?fi|ethernet|vpn|connect/, "wifi", IrisStyle.identity.blue],
            [/volume|audio|sound|microphone/, "volume_up", IrisStyle.identity.orange],
            [/bright|display|monitor/, "light_mode", IrisStyle.identity.orange],
            [/update|upgrade|package|pacman|flatpak/, "system_update", IrisStyle.identity.indigo],
            [/download/, "download", IrisStyle.identity.teal],
            [/mail/, "mail", IrisStyle.identity.blue],
            [/message|chat|discord|telegram|vesktop|signal|whatsapp/, "chat_bubble", IrisStyle.identity.green],
            [/calendar|event|remind|meeting/, "event", IrisStyle.identity.red],
            [/timer|pomodoro|alarm|stopwatch/, "timer", IrisStyle.identity.orange],
            [/music|spotify|player|song|track/, "music_note", IrisStyle.identity.pink],
            [/clipboard|copied|copy/, "content_paste", IrisStyle.identity.gray],
            [/wallpaper|theme|colou?r/, "palette", IrisStyle.identity.purple],
            [/inir|iris|shell|quickshell/, "auto_awesome", IrisStyle.identity.purple]
        ]
        for (const rule of rules)
            if (rule[0].test(text)) return { glyph: rule[1], tint: rule[2] }
        return { glyph: "notifications", tint: IrisStyle.identity.gray }
    }

    ClippingRectangle {
        anchors.fill: parent
        visible: root.hasImage
        radius: IrisStyle.iconRadius(root.width)
        color: IrisStyle.surfaceHigh
        IrisImage {
            anchors.fill: parent
            source: root.hasImage ? root.image : ""
        }
    }

    Item {
        id: identity
        readonly property real extent: root.hasImage ? Math.round(root.width * 0.48) : root.width
        width: identity.extent
        height: identity.extent
        x: root.hasImage ? root.width - identity.extent + Math.round(root.width * 0.1) : 0
        y: root.hasImage ? root.height - identity.extent + Math.round(root.height * 0.1) : 0

        SmartAppIcon {
            anchors.fill: parent
            visible: root.resolvedIcon.length > 0 && !root.iconFile
            icon: root.iconFile ? "" : root.resolvedIcon
            iconSize: identity.extent
        }
        IrisImage {
            id: iconFileImage
            anchors.fill: parent
            visible: root.iconFile && status === Image.Ready
            source: root.iconFile ? (root.resolvedIcon.startsWith("/") ? "file://" + root.resolvedIcon : root.resolvedIcon) : ""
            fillMode: Image.PreserveAspectFit
        }
        Rectangle {
            anchors.fill: parent
            visible: root.resolvedIcon.length === 0 || root.iconFile && iconFileImage.status !== Image.Ready
            id: tile
            radius: IrisStyle.iconRadius(width)
            readonly property bool insignia: root.fromShell && !root.critical
            readonly property color base: root.critical ? IrisStyle.danger : tile.insignia ? IrisStyle.surfaceHigh : root.semantic.tint
            border.width: root.hasImage || tile.insignia ? Math.max(1, Math.round(root.width * 0.04)) : 0
            border.color: tile.insignia ? IrisStyle.hairlineStrong : IrisStyle.surface
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.lighter(tile.base, 1.18) }
                GradientStop { position: 1; color: tile.base }
            }
            IrisMark {
                anchors.centerIn: parent
                visible: tile.insignia
                implicitSize: Math.round(tile.width * 0.7)
            }
            MaterialSymbol {
                visible: !tile.insignia
                anchors.centerIn: parent
                text: root.critical ? "priority_high" : root.semantic.glyph
                fill: 1
                iconSize: Math.round(parent.width * 0.56)
                color: IrisStyle.onTint
            }
        }
    }
}
