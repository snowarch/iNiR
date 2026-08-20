pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

/**
 * Dedicated Mascot settings page (waffle family). ii mirror:
 * modules/settings/MascotConfig.qml — keep both in sync.
 *
 * How this page is built:
 * - Registered in waffleSettings.qml pages[] (settingsPageIndex must equal
 *   the array position — waffle indices are positional and hardcoded, so
 *   new pages are appended at the END) and in WSettingsContent.qml's
 *   searchIndex with pageIndex 14.
 * - Rows use the waffle kit only (WSettingsCard/WSettingsSwitch/
 *   WSettingsSpinBox/WSettingsButton, Looks tokens); the pose picker is
 *   the shared MascotPoseGallery from qs.modules.common.widgets.
 * - poseOptions live on the card (mascotCard) and are built from the
 *   manifest's curated full-body pickerPoses; the event Repeater emits a
 *   WSettingsSwitch + MascotPoseGallery pair per eventDescriptors entry.
 */
WSettingsPage {
    id: root
    settingsPageIndex: 14
    pageTitle: Translation.tr("Mascot")
    pageIcon: "image"
    pageDescription: Translation.tr("Companion behavior, reactions, poses")

    // ── Mascot ─────────────────────────────────────────────────────────
    WSettingsCard {
        id: mascotCard
        title: Translation.tr("Mascot")
        icon: "image"

        property var poseOptions: [{ displayName: Translation.tr("Auto (rotate pool)"), value: "" }]

        FileView {
            path: Quickshell.shellPath("assets/images/mascot/manifest.json")
            watchChanges: true
            onLoadedChanged: {
                if (!loaded) return
                try {
                    const m = JSON.parse(text())
                    const anim = m.animatedPoses ?? []
                    const all = m.collectionPoses ?? []
                    const ordered = all.filter(p => !anim.includes(p)).concat(all.filter(p => anim.includes(p)))
                    mascotCard.poseOptions = [{ displayName: Translation.tr("Auto (rotate pool)"), value: "", image: "" }]
                        .concat(ordered.map(p => ({
                            displayName: p,
                            value: p,
                            image: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${p}.${anim.includes(p) ? "gif" : "png"}`)
                        })))
                } catch (e) {
                    console.warn("[WQuickPage] mascot manifest load failed:", e)
                }
            }
        }

        WSettingsSwitch {
            label: Translation.tr("Show mascot illustration")
            icon: "image"
            description: Translation.tr("Show the iNiR mascot in About, empty states and other shell surfaces")
            checked: Config.options?.mascot?.enable ?? false
            onCheckedChanged: Config.setNestedValue("mascot.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Playful companion")
            icon: "wand"
            description: Translation.tr("She occasionally peeks from a screen edge and reacts to music, battery and updates. Never over fullscreen apps or games")
            checked: Config.options?.mascot?.companion?.enable ?? true
            enabled: Config.options?.mascot?.enable ?? false
            onCheckedChanged: Config.setNestedValue("mascot.companion.enable", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Companion visit interval")
            icon: "timer"
            description: Translation.tr("Roughly how often she peeks on her own")
            suffix: " min"
            from: 3
            to: 180
            stepSize: 1
            value: Config.options?.mascot?.companion?.intervalMinutes ?? 25
            onValueChanged: Config.setNestedValue("mascot.companion.intervalMinutes", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Companion size")
            icon: "image"
            suffix: " px"
            from: 100
            to: 280
            stepSize: 10
            value: Config.options?.mascot?.companion?.size ?? 150
            onValueChanged: Config.setNestedValue("mascot.companion.size", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Visit length")
            icon: "timer"
            description: Translation.tr("How long she stays before sliding away")
            suffix: " s"
            from: 3
            to: 60
            stepSize: 1
            value: Config.options?.mascot?.companion?.visibleSeconds ?? 8
            onValueChanged: Config.setNestedValue("mascot.companion.visibleSeconds", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Slide animation")
            icon: "flash-on"
            description: Translation.tr("How fast she slides in and out")
            suffix: " ms"
            from: 100
            to: 1500
            stepSize: 50
            value: Config.options?.mascot?.companion?.slideMs ?? 400
            onValueChanged: Config.setNestedValue("mascot.companion.slideMs", value)
        }

        WSettingsSwitch {
            label: Translation.tr("Panel-sitter mode")
            icon: "pin"
            description: Translation.tr("She sits on the bar/dock instead of floating off-screen edges")
            checked: Config.options?.mascot?.companion?.placement === "panel-sitter"
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.placement", checked ? "panel-sitter" : "peek")
        }

        WSettingsSwitch {
            label: Translation.tr("Contextual placement")
            icon: "drag_pan"
            description: Translation.tr("Event reactions appear near the triggering widget instead of a random edge")
            checked: Config.options?.mascot?.companion?.contextualPlacement ?? false
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.contextualPlacement", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Follow focused monitor")
            icon: "desktop"
            description: Translation.tr("She appears on the monitor with the focused workspace instead of the primary one")
            checked: (Config.options?.mascot?.companion?.monitor ?? "primary") === "focused"
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.monitor", checked ? "focused" : "primary")
        }

        WSettingsSwitch {
            label: Translation.tr("Personal commentary")
            icon: "people"
            description: Translation.tr("Observations about YOUR habits (3AM sessions, uptime, marathons); off = generic small talk only")
            checked: Config.options?.mascot?.personality?.commentary ?? true
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.personality.commentary", checked)
        }

        WSettingsDropdown {
            label: Translation.tr("Voice")
            // `chat` is not in assets/icons/fluent — it rendered blank.
            icon: "people"
            description: Translation.tr("Adaptive follows her mood; fixed modes keep one conversational register")
            currentValue: Config.options?.mascot?.personality?.voiceMode ?? "adaptive"
            options: [
                { displayName: Translation.tr("Adaptive"), value: "adaptive" },
                { displayName: Translation.tr("Casual"), value: "casual" },
                { displayName: Translation.tr("Dry"), value: "dry" },
                { displayName: Translation.tr("Composed"), value: "composed" },
                { displayName: Translation.tr("Chaotic"), value: "chaotic" }
            ]
            onSelected: newValue => Config.setNestedValue("mascot.personality.voiceMode", newValue)
        }

        WSettingsSwitch {
            label: Translation.tr("Mood personality")
            icon: "pulse"
            description: Translation.tr("Her lines change with session mood (sleepy/hyper/snarky/contemplative)")
            checked: Config.options?.mascot?.personality?.enabled ?? true
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.personality.enabled", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Mood change interval")
            icon: "timer"
            suffix: " min"
            from: 5
            to: 180
            stepSize: 5
            value: Config.options?.mascot?.personality?.idleMoodIntervalMinutes ?? 30
            onValueChanged: Config.setNestedValue("mascot.personality.idleMoodIntervalMinutes", value)
        }

        WSettingsSwitch {
            label: Translation.tr("Chaos mode")
            icon: "flash-on"
            description: Translation.tr("Rarely she runs across the desktop, bonks widgets around and rattles the taskbar")
            checked: Config.options?.mascot?.chaos?.enable ?? false
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.chaos.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Impact sounds")
            icon: "speaker-0"
            description: Translation.tr("Little thuds and bells from the system sound theme when she hits things")
            checked: Config.options?.mascot?.chaos?.sfx ?? true
            enabled: Config.options?.mascot?.chaos?.enable ?? false
            onCheckedChanged: Config.setNestedValue("mascot.chaos.sfx", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Let her rearrange widgets")
            icon: "drag_pan"
            description: Translation.tr("Displaced widgets keep their new position; otherwise everything bounces back")
            checked: Config.options?.mascot?.chaos?.allowRearrange ?? false
            enabled: Config.options?.mascot?.chaos?.enable ?? false
            onCheckedChanged: Config.setNestedValue("mascot.chaos.allowRearrange", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("React to system events")
            icon: "flash-on"
            description: Translation.tr("Rare, reason-flavored romps for low battery, a notification pileup, or very late hours")
            checked: Config.options?.mascot?.chaos?.systemEvents ?? true
            enabled: Config.options?.mascot?.chaos?.enable ?? false
            onCheckedChanged: Config.setNestedValue("mascot.chaos.systemEvents", checked)
        }

        WSettingsButton {
            label: Translation.tr("Unleash chaos")
            icon: "flash-on"
            enabled: Config.options?.mascot?.chaos?.enable ?? false
            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "romp"])
        }

        WSettingsButton {
            label: Translation.tr("Tidy up")
            description: Translation.tr("Every displaced widget returns home")
            icon: "delete"
            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "tidy"])
        }

        WSettingsSwitch {
            label: Translation.tr("Only react to real music")
            icon: "music-note-2"
            description: Translation.tr("Skips browser videos and players without artist metadata")
            checked: Config.options?.mascot?.companion?.musicRequireArtist ?? true
            enabled: Config.options?.mascot?.companion?.enable ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.musicRequireArtist", checked)
        }

        // Every event reaction: on/off + which pose she uses for it
        Repeater {
            id: mascotEventRepeater

            readonly property var eventDescriptors: [
                { key: "music", icon: "music-note-2", label: Translation.tr("React to music") },
                { key: "battery", icon: "battery-warning", label: Translation.tr("React to low battery") },
                { key: "update", icon: "arrow-clockwise", label: Translation.tr("React to updates") },
                { key: "network", icon: "wifi-1", label: Translation.tr("React to network drops") },
                { key: "dnd", icon: "weather-moon", label: Translation.tr("React to do-not-disturb") },
                { key: "notification", icon: "alert", label: Translation.tr("Notification snoop") },
                { key: "wallpaper", icon: "paint-bucket", label: Translation.tr("React to wallpaper change") },
                { key: "screenshot", icon: "screenshot", label: Translation.tr("React to screenshots") },
                { key: "gaming", icon: "gamepad", label: Translation.tr("React to game sessions") },
                { key: "workspace", icon: "desktop", label: Translation.tr("React to workspace frenzy") },
                { key: "unlock", icon: "lock-open", label: Translation.tr("React to screen unlock") }
            ]
            model: eventDescriptors
            delegate: ColumnLayout {
                id: eventCol
                required property var modelData
                Layout.fillWidth: true
                spacing: 0

                WSettingsSwitch {
                    Layout.fillWidth: true
                    label: eventCol.modelData.label
                    icon: eventCol.modelData.icon
                    checked: Config.options?.mascot?.companion?.events?.[eventCol.modelData.key] ?? true
                    enabled: Config.options?.mascot?.companion?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("mascot.companion.events." + eventCol.modelData.key, checked)
                }

                WMascotPoseGallery {
                    Layout.fillWidth: true
                    Layout.leftMargin: 12
                    visible: Config.options?.mascot?.companion?.events?.[eventCol.modelData.key] ?? true
                    label: Translation.tr("Pose for this event")
                    options: mascotCard.poseOptions
                    currentValue: Config.options?.mascot?.companion?.eventPoses?.[eventCol.modelData.key] ?? ""
                    onSelected: value => Config.setNestedValue("mascot.companion.eventPoses." + eventCol.modelData.key, value)
                }
            }
        }

        WSettingsButton {
            label: Translation.tr("Peek now")
            description: Translation.tr("Try her right now instead of waiting for the interval")
            icon: "wand"
            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "poke"])
        }

        WSettingsButton {
            label: Translation.tr("Send her away")
            icon: "eye-off"
            onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "hide"])
        }

        WSettingsSwitch {
            label: Translation.tr("Peek from left edge")
            icon: "chevron-left"
            checked: Config.options?.mascot?.companion?.edges?.left ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.edges.left", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Peek from right edge")
            icon: "chevron-right"
            checked: Config.options?.mascot?.companion?.edges?.right ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.edges.right", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Peek from top edge")
            icon: "chevron-up"
            checked: Config.options?.mascot?.companion?.edges?.top ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.edges.top", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Peek from bottom edge")
            icon: "chevron-down"
            checked: Config.options?.mascot?.companion?.edges?.bottom ?? true
            onCheckedChanged: Config.setNestedValue("mascot.companion.edges.bottom", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Mascot surfaces")

        // Per-surface pose overrides (Auto = curated default per spot)
        Repeater {
            model: [
                { key: "notifications", label: Translation.tr("Notifications pose") },
                { key: "clipboard", label: Translation.tr("Clipboard pose") },
                { key: "mediaControls", label: Translation.tr("Media controls pose") },
                { key: "todo", label: Translation.tr("Todo list pose") },
                { key: "calendar", label: Translation.tr("Calendar pose") },
                { key: "wifi", label: Translation.tr("Wi-Fi dialog pose") },
                { key: "startMenu", label: Translation.tr("Start menu pose") },
                { key: "wallpaperSelector", label: Translation.tr("Wallpaper selector pose") },
                { key: "bootGreeting", label: Translation.tr("Boot greeting pose") },
                { key: "emptyStates", label: Translation.tr("Other empty states pose") },
                { key: "about", label: Translation.tr("About pose") },
                { key: "session", label: Translation.tr("Session screen pose") },
                { key: "aiChat", label: Translation.tr("AI chat pose") },
                { key: "dashboard", label: Translation.tr("Dashboard pose") },
                { key: "cheatsheet", label: Translation.tr("Cheatsheet pose") },
                { key: "updates", label: Translation.tr("Update overlay pose") },
                { key: "dialogs", label: Translation.tr("Dialogs pose") }
            ]
            delegate: WMascotPoseGallery {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.label
                options: mascotCard.poseOptions
                currentValue: Config.options?.mascot?.surfacePoses?.[modelData.key] ?? ""
                onSelected: value => Config.setNestedValue("mascot.surfacePoses." + modelData.key, value)
            }
        }
        icon: "image"

        WSettingsSwitch {
            label: Translation.tr("Empty states")
            icon: "alert"
            description: Translation.tr("Notifications, clipboard, todo, media, calendar, wallpapers, search results")
            checked: Config.options?.mascot?.surfaces?.emptyStates ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.emptyStates", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("About pages")
            icon: "info"
            checked: Config.options?.mascot?.surfaces?.about ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.about", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Session screen")
            icon: "power"
            checked: Config.options?.mascot?.surfaces?.session ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.session", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("AI chat")
            icon: "alert-snooze"
            checked: Config.options?.mascot?.surfaces?.aiChat ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.aiChat", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Dashboard")
            icon: "apps"
            checked: Config.options?.mascot?.surfaces?.dashboard ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.dashboard", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Cheatsheet")
            icon: "keyboard"
            checked: Config.options?.mascot?.surfaces?.cheatsheet ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.cheatsheet", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Boot greeting")
            icon: "weather-sunny"
            checked: Config.options?.mascot?.surfaces?.bootGreeting ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.bootGreeting", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Update overlay")
            icon: "arrow-sync"
            checked: Config.options?.mascot?.surfaces?.updates ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.updates", checked)
        }
        WSettingsSwitch {
            label: Translation.tr("Dialogs")
            icon: "alert"
            description: Translation.tr("Close confirmation and similar dialogs")
            checked: Config.options?.mascot?.surfaces?.dialogs ?? true
            onCheckedChanged: Config.setNestedValue("mascot.surfaces.dialogs", checked)
        }
    }

    WSettingsCard {
        title: Translation.tr("Kira collection")
        icon: "image"

        WText {
            Layout.fillWidth: true
            text: Translation.tr("Every shipped illustration has a role here. Full-body poses power the live companion; portraits, chibis and key art stay available as a curated character archive.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.fg1
            wrapMode: Text.Wrap
        }

        MascotCollection {
            Layout.fillWidth: true
        }
    }

    // ── Quick actions ──────────────────────────────────────────────────
    WSettingsSection {
        title: Translation.tr("Quick actions")
        icon: "flash-on"
    }

    // Action buttons row — compact, horizontal, icon-heavy
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [
                { icon: "arrow-sync", label: Translation.tr("Reload"), action: "reload" },
                { icon: "settings", label: Translation.tr("Config"), action: "config" },
                { icon: "keyboard", label: Translation.tr("Shortcuts"), action: "shortcuts" }
            ]

            Rectangle {
                id: actionBtn
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: Looks.radius.large
                color: actionBtnMa.containsMouse ? Looks.colors.bg1Hover : Looks.colors.bg1Base
                border.width: 1
                border.color: Looks.colors.bg1Border

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0 }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    FluentIcon {
                        Layout.alignment: Qt.AlignHCenter
                        icon: actionBtn.modelData.icon
                        implicitSize: 18
                        color: Looks.colors.accent
                    }

                    WText {
                        Layout.alignment: Qt.AlignHCenter
                        text: actionBtn.modelData.label
                        font.pixelSize: Looks.font.pixelSize.small
                        font.weight: Looks.font.weight.regular
                        color: Looks.colors.fg
                    }
                }

                MouseArea {
                    id: actionBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        switch (actionBtn.modelData.action) {
                        case "reload":
                            Quickshell.execDetached(["/usr/bin/bash", Quickshell.shellPath("scripts/restart-shell.sh")])
                            break
                        case "config":
                            Qt.openUrlExternally(Directories.shellConfigPath)
                            break
                        case "shortcuts":
                            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "cheatsheet", "toggle"])
                            break
                        }
                    }
                }
            }
        }
    }
}
