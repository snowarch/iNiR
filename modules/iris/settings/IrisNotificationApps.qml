pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.style

// Settings › Notifications › Apps: every app that sent something, by its own icon and name, with how many and when (never
// what they said: Settings may be on a shared screen) and how it may reach you: banners, quietly (into Today with no banner, sound or unread mark) or never. An app is one key
// however it names itself (Notifications.appKey); apps set quiet or never stay listed after their history is cleared.
ColumnLayout {
    id: root

    readonly property real d: IrisStyle.settingsDensity
    readonly property var blocked: Config.options?.notifications?.blockedApps ?? []
    readonly property var quiet: Config.options?.notifications?.silentApps ?? []
    // One lookup per name the history holds, not per notification: a long history re-groups on every arrival.
    property var keyOf: ({})
    function keyFor(notif: var): string {
        const memo = String(notif.desktopEntry ?? "") + "|" + String(notif.appName ?? "")
        if (root.keyOf[memo] === undefined) root.keyOf[memo] = Notifications.appKey(notif)
        return root.keyOf[memo]
    }
    readonly property var apps: {
        const byKey = {}
        for (const notif of Notifications.list) {
            const key = root.keyFor(notif)
            if (key.length === 0) continue
            const app = byKey[key] ?? (byKey[key] = { key: key, name: "", icon: "", count: 0, time: 0 })
            app.count += 1
            if (notif.time >= app.time) {
                const entry = DesktopEntries.heuristicLookup(String(notif.desktopEntry || notif.appName || ""))
                app.time = notif.time
                app.name = entry?.name ?? String(notif.appName || key)
                app.icon = AppSearch.getIconSource(String(notif.appIcon || entry?.icon || ""), app.name)
            }
        }
        for (const key of root.blocked.concat(root.quiet))
            if (!byKey[key] && /^[a-z0-9]+$/.test(String(key))) byKey[key] = { key: key, name: key, icon: AppSearch.getIconSource(key, key), count: 0, time: -1 }
        return Object.values(byKey).sort((a, b) => b.time - a.time)
    }
    function modeOf(key: string): string { return root.blocked.includes(key) ? "never" : root.quiet.includes(key) ? "quiet" : "banners" }
    function setMode(key: string, mode: string): void {
        Config.setNestedValue("notifications.blockedApps", root.blocked.filter(value => value !== key).concat(mode === "never" ? [key] : []))
        Config.setNestedValue("notifications.silentApps", root.quiet.filter(value => value !== key).concat(mode === "quiet" ? [key] : []))
    }
    readonly property var modes: [
        { label: Translation.tr("Banners"), value: "banners" },
        { label: Translation.tr("Quietly"), value: "quiet" },
        { label: Translation.tr("Never"), value: "never" }
    ]

    spacing: 0

    Repeater {
        model: root.apps
        Item {
            id: appRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: Math.round(56 * root.d)

            IrisImage {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(32 * root.d)
                height: width
                source: appRow.modelData.icon
                fillMode: Image.PreserveAspectFit
                opacity: root.modeOf(appRow.modelData.key) === "never" ? 0.45 : 1
            }
            ColumnLayout {
                anchors.left: mark.right
                anchors.leftMargin: Math.round(12 * root.d)
                anchors.right: choice.left
                anchors.rightMargin: Math.round(16 * root.d)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: appRow.modelData.name
                    font.pixelSize: IrisStyle.typeBody
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: appRow.modelData.count > 0
                    text: Translation.tr("%1 notifications").arg(appRow.modelData.count) + "  ·  " + NotificationUtils.getFriendlyNotifTimeString(appRow.modelData.time)
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
            }
            IrisSegmented {
                id: choice
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(250 * root.d)
                options: root.modes
                current: root.modeOf(appRow.modelData.key)
                accessibleName: appRow.modelData.name
                onPicked: value => root.setMode(appRow.modelData.key, String(value))
            }
            Rectangle {
                visible: appRow.index < root.apps.length - 1
                anchors.left: parent.left
                anchors.leftMargin: mark.width + Math.round(12 * root.d)
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: IrisStyle.hairline
            }
        }
    }
}
