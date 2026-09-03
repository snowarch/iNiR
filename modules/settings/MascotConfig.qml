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

/**
 * Dedicated Mascot settings page (ii family). Waffle mirror:
 * modules/waffle/settings/pages/WMascotPage.qml — keep both in sync.
 *
 * How this page is built:
 * - Registered in SettingsPageRegistry.qml: pages[] entry (this file's
 *   settingsPageIndex must equal its array position), a categories[]
 *   listing, and search entries pointing at pageIndex 19.
 * - Standard settings kit: SettingsCardSection > SettingsGroup rows of
 *   SettingsSwitch / ConfigSpinBox / RippleButtonWithIcon, writing through
 *   Config.setNestedValue (the only persisting write path).
 * - Event reactions are data-driven: a Repeater over eventDescriptors
 *   ({ key, icon, label }) emits one SettingsSwitch (mascot.companion.
 *   events.<key>) plus one MascotPoseGallery (mascot.companion.
 *   eventPoses.<key>, "" = rotate the manifest pool).
 * - MascotPoseGallery (modules/common/widgets) is the visual thumbnail
 *   picker; its options are built here by a FileView over
 *   assets/images/mascot/manifest.json (curated pickerPoses plus
 *   animatedPoses, each mapped to its asset path).
 * - Adding a new event = manifest reactions entry + Config.qml/defaults
 *   events/eventPoses keys + one eventDescriptors row here and in the
 *   waffle mirror. The companion reads everything through reactEvent().
 */
ContentPage {
    id: root
    settingsPageIndex: 19
    settingsPageName: Translation.tr("Mascot")

    SettingsCardSection {
        expanded: true
        icon: "pets"
        title: Translation.tr("Mascot")

        SettingsGroup {
            // The art pack is an optional download (setup › Extras); probe one
            // pack asset and surface install instructions when it's missing
            Image {
                id: packProbe
                visible: false
                source: Quickshell.shellPath("assets/images/mascot/inir-mascot-edge-peek.png")
                asynchronous: true
            }
            Rectangle {
                Layout.fillWidth: true
                visible: packProbe.status === Image.Error
                implicitHeight: packMissingText.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                StyledText {
                    id: packMissingText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: Translation.tr("Kira is an optional download. Run `inir setup extras` and choose Install mascot pack. Everything below stays inert until the download finishes.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSecondaryContainer
                    wrapMode: Text.Wrap
                }
            }

            SettingsSwitch {
                buttonIcon: "pets"
                text: Translation.tr("Show mascot illustration")
                checked: Config.options?.mascot?.enable ?? false
                onCheckedChanged: Config.setNestedValue("mascot.enable", checked)
                StyledToolTip {
                    text: Translation.tr("Show the iNiR mascot in About, empty states and other shell surfaces")
                }
            }

            SettingsSwitch {
                buttonIcon: "waving_hand"
                text: Translation.tr("Playful companion")
                checked: Config.options?.mascot?.companion?.enable ?? true
                enabled: Config.options?.mascot?.enable ?? false
                onCheckedChanged: Config.setNestedValue("mascot.companion.enable", checked)
                StyledToolTip {
                    text: Translation.tr("She occasionally peeks from a screen edge and reacts to music, battery and updates. Never over fullscreen apps or games")
                }
            }

            ConfigSpinBox {
                icon: "schedule"
                text: Translation.tr("Companion visit interval") + " (min)"
                value: Config.options?.mascot?.companion?.intervalMinutes ?? 25
                from: 3
                to: 180
                stepSize: 1
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("mascot.companion.intervalMinutes", value)
                }
            }

            ConfigSpinBox {
                icon: "photo_size_select_large"
                text: Translation.tr("Companion size") + " (px)"
                value: Config.options?.mascot?.companion?.size ?? 150
                from: 100
                to: 280
                stepSize: 10
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("mascot.companion.size", value)
                }
            }

            ConfigSpinBox {
                icon: "hourglass_empty"
                text: Translation.tr("Visit length") + " (s)"
                value: Config.options?.mascot?.companion?.visibleSeconds ?? 5
                from: 3
                to: 60
                stepSize: 1
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("mascot.companion.visibleSeconds", value)
                }
            }

            ConfigSpinBox {
                icon: "speed"
                text: Translation.tr("Slide animation") + " (ms)"
                value: Config.options?.mascot?.companion?.slideMs ?? 400
                from: 100
                to: 1500
                stepSize: 50
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("mascot.companion.slideMs", value)
                }
            }

            SettingsSwitch {
                buttonIcon: "dock"
                text: Translation.tr("Panel-sitter mode")
                checked: Config.options?.mascot?.companion?.placement === "panel-sitter"
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.placement", checked ? "panel-sitter" : "peek")
                StyledToolTip {
                    text: Translation.tr("She sits on the bar/dock instead of floating off-screen edges")
                }
            }

            SettingsSwitch {
                buttonIcon: "my_location"
                text: Translation.tr("Contextual placement")
                checked: Config.options?.mascot?.companion?.contextualPlacement ?? false
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.contextualPlacement", checked)
                StyledToolTip {
                    text: Translation.tr("Event reactions appear near the triggering widget instead of a random edge")
                }
            }

            SettingsSwitch {
                buttonIcon: "monitor"
                text: Translation.tr("Follow focused monitor")
                checked: (Config.options?.mascot?.companion?.monitor ?? "primary") === "focused"
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.monitor", checked ? "focused" : "primary")
                StyledToolTip {
                    text: Translation.tr("She appears on the monitor with the focused workspace instead of the primary one")
                }
            }

            SettingsSwitch {
                buttonIcon: "record_voice_over"
                text: Translation.tr("Personal commentary")
                checked: Config.options?.mascot?.personality?.commentary ?? true
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.personality.commentary", checked)
                StyledToolTip {
                    text: Translation.tr("Observations about YOUR habits — 3AM sessions, uptime, app marathons. Off = she only makes generic small talk")
                }
            }

            ContentSubsection {
                title: Translation.tr("Voice")

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Adaptive follows her mood; fixed modes keep the same conversational register")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }

                ConfigSelectionArray {
                    currentValue: Config.options?.mascot?.personality?.voiceMode ?? "adaptive"
                    onSelected: newValue => Config.setNestedValue("mascot.personality.voiceMode", newValue)
                    options: [
                        { displayName: Translation.tr("Adaptive"), icon: "auto_awesome", value: "adaptive" },
                        { displayName: Translation.tr("Casual"), icon: "chat", value: "casual" },
                        { displayName: Translation.tr("Dry"), icon: "coffee", value: "dry" },
                        { displayName: Translation.tr("Composed"), icon: "notes", value: "composed" },
                        { displayName: Translation.tr("Chaotic"), icon: "bolt", value: "chaotic" }
                    ]
                }
            }

            SettingsSwitch {
                buttonIcon: "psychology"
                text: Translation.tr("Mood personality")
                checked: Config.options?.mascot?.personality?.enabled ?? true
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.personality.enabled", checked)
                StyledToolTip {
                    text: Translation.tr("Her lines change with session mood (sleepy/hyper/snarky/contemplative)")
                }
            }

            ConfigSpinBox {
                icon: "timer"
                text: Translation.tr("Mood change interval") + " (min)"
                value: Config.options?.mascot?.personality?.idleMoodIntervalMinutes ?? 30
                from: 5
                to: 180
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("mascot.personality.idleMoodIntervalMinutes", value)
                }
            }
        }

        // Chaos mode: she runs across the desktop and messes with it
        SettingsGroup {
            StyledText {
                text: Translation.tr("Chaos mode")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Rarely, instead of a quiet visit, she runs across the desktop and bonks your widgets, hurls them around or rattles the bar")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            SettingsSwitch {
                buttonIcon: "cyclone"
                text: Translation.tr("Enable chaos mode")
                checked: Config.options?.mascot?.chaos?.enable ?? false
                enabled: Config.options?.mascot?.companion?.enable ?? true
                onCheckedChanged: Config.setNestedValue("mascot.chaos.enable", checked)
            }
            SettingsSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Impact sounds")
                checked: Config.options?.mascot?.chaos?.sfx ?? true
                enabled: Config.options?.mascot?.chaos?.enable ?? false
                onCheckedChanged: Config.setNestedValue("mascot.chaos.sfx", checked)
                StyledToolTip {
                    text: Translation.tr("Little thuds and bells from the system sound theme when she hits things")
                }
            }
            SettingsSwitch {
                buttonIcon: "open_with"
                text: Translation.tr("Let her rearrange widgets")
                checked: Config.options?.mascot?.chaos?.allowRearrange ?? false
                enabled: Config.options?.mascot?.chaos?.enable ?? false
                onCheckedChanged: Config.setNestedValue("mascot.chaos.allowRearrange", checked)
                StyledToolTip {
                    text: Translation.tr("Displaced widgets keep their new position; otherwise everything bounces back home")
                }
            }
            SettingsSwitch {
                buttonIcon: "bolt"
                text: Translation.tr("React to system events")
                checked: Config.options?.mascot?.chaos?.systemEvents ?? true
                enabled: Config.options?.mascot?.chaos?.enable ?? false
                onCheckedChanged: Config.setNestedValue("mascot.chaos.systemEvents", checked)
                StyledToolTip {
                    text: Translation.tr("Rare, reason-flavored romps for low battery, a notification pileup, or very late hours")
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 5
                RippleButtonWithIcon {
                    materialIcon: "cyclone"
                    mainText: Translation.tr("Unleash chaos")
                    enabled: Config.options?.mascot?.chaos?.enable ?? false
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "romp"])
                }
                RippleButtonWithIcon {
                    materialIcon: "cleaning_services"
                    mainText: Translation.tr("Tidy up")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "tidy"])
                }
            }
        }

        // Try her right now instead of waiting for the interval
        SettingsGroup {
            Flow {
                Layout.fillWidth: true
                spacing: 5

                RippleButtonWithIcon {
                    materialIcon: "waving_hand"
                    mainText: Translation.tr("Peek now")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "poke"])
                }

                RippleButtonWithIcon {
                    materialIcon: "sentiment_very_satisfied"
                    mainText: Translation.tr("Say hi")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "appear", "wave-loop", "bottom"])
                }

                RippleButtonWithIcon {
                    materialIcon: "visibility_off"
                    mainText: Translation.tr("Send her away")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "hide"])
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Tip: click her when she appears — more than once at your own risk. Staring also has consequences.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
        }

        // Which screen edges she may use
        SettingsGroup {
            StyledText {
                text: Translation.tr("Edges she may peek from")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }

            SettingsSwitch {
                buttonIcon: "keyboard_arrow_left"
                text: Translation.tr("Left")
                checked: Config.options?.mascot?.companion?.edges?.left ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.edges.left", checked)
            }
            SettingsSwitch {
                buttonIcon: "keyboard_arrow_right"
                text: Translation.tr("Right")
                checked: Config.options?.mascot?.companion?.edges?.right ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.edges.right", checked)
            }
            SettingsSwitch {
                buttonIcon: "keyboard_arrow_up"
                text: Translation.tr("Top")
                checked: Config.options?.mascot?.companion?.edges?.top ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.edges.top", checked)
            }
            SettingsSwitch {
                buttonIcon: "keyboard_arrow_down"
                text: Translation.tr("Bottom")
                checked: Config.options?.mascot?.companion?.edges?.bottom ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.edges.bottom", checked)
            }
        }

        // Every event reaction: on/off + which pose she uses for it
        SettingsGroup {
            id: mascotReactionsGroup

            readonly property var eventDescriptors: [
                { key: "music", icon: "music_note", label: Translation.tr("Music starts") },
                { key: "battery", icon: "battery_alert", label: Translation.tr("Battery low") },
                { key: "update", icon: "system_update_alt", label: Translation.tr("Update available") },
                { key: "network", icon: "wifi_off", label: Translation.tr("Network drops") },
                { key: "dnd", icon: "do_not_disturb_on", label: Translation.tr("Do not disturb on") },
                { key: "notification", icon: "notifications_active", label: Translation.tr("Notification snoop") },
                { key: "wallpaper", icon: "wallpaper", label: Translation.tr("Wallpaper change") },
                { key: "screenshot", icon: "photo_camera", label: Translation.tr("Screenshot taken") },
                { key: "gaming", icon: "sports_esports", label: Translation.tr("Game session ends") },
                { key: "workspace", icon: "grid_view", label: Translation.tr("Workspace frenzy") },
                { key: "unlock", icon: "lock_open", label: Translation.tr("Screen unlock") }
            ]
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
                        mascotReactionsGroup.poseOptions = [{ displayName: Translation.tr("Auto (rotate pool)"), value: "", image: "" }]
                            .concat(ordered.map(p => ({
                                displayName: p,
                                value: p,
                                image: Quickshell.shellPath(`assets/images/mascot/inir-mascot-${p}.${anim.includes(p) ? "gif" : "png"}`)
                            })))
                    } catch (e) {
                        console.warn("[QuickConfig] mascot manifest load failed:", e)
                    }
                }
            }

            StyledText {
                text: Translation.tr("Event reactions")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose what she reacts to, and which pose each event uses")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            SettingsSwitch {
                buttonIcon: "artist"
                text: Translation.tr("Only react to real music")
                checked: Config.options?.mascot?.companion?.musicRequireArtist ?? true
                onCheckedChanged: Config.setNestedValue("mascot.companion.musicRequireArtist", checked)
                StyledToolTip {
                    text: Translation.tr("Skips browser videos and players without artist metadata")
                }
            }

            Repeater {
                model: mascotReactionsGroup.eventDescriptors
                delegate: ColumnLayout {
                    id: eventRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    SettingsSwitch {
                        Layout.fillWidth: true
                        buttonIcon: eventRow.modelData.icon
                        text: eventRow.modelData.label
                        checked: Config.options?.mascot?.companion?.events?.[eventRow.modelData.key] ?? true
                        onCheckedChanged: Config.setNestedValue("mascot.companion.events." + eventRow.modelData.key, checked)
                    }

                    MascotPoseGallery {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        visible: Config.options?.mascot?.companion?.events?.[eventRow.modelData.key] ?? true
                        label: Translation.tr("Pose for this event")
                        options: mascotReactionsGroup.poseOptions
                        currentValue: Config.options?.mascot?.companion?.eventPoses?.[eventRow.modelData.key] ?? ""
                        onSelected: value => Config.setNestedValue("mascot.companion.eventPoses." + eventRow.modelData.key, value)
                    }
                }
            }
        }

        // Which image each placement shows — override any spot's curated pose
        SettingsGroup {
            StyledText {
                text: Translation.tr("Surface poses")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Pick your own image for each placement; Auto keeps the curated default. Animated spots keep their animation.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            Repeater {
                model: [
                    { key: "notifications", label: Translation.tr("Notifications") },
                    { key: "clipboard", label: Translation.tr("Clipboard") },
                    { key: "mediaControls", label: Translation.tr("Media controls") },
                    { key: "todo", label: Translation.tr("Todo list") },
                    { key: "calendar", label: Translation.tr("Calendar") },
                    { key: "wifi", label: Translation.tr("Wi-Fi dialog") },
                    { key: "startMenu", label: Translation.tr("Start menu") },
                    { key: "wallpaperSelector", label: Translation.tr("Wallpaper selector") },
                    { key: "bootGreeting", label: Translation.tr("Boot greeting") },
                    { key: "emptyStates", label: Translation.tr("Other empty states") },
                    { key: "about", label: Translation.tr("About pages") },
                    { key: "session", label: Translation.tr("Session screen") },
                    { key: "aiChat", label: Translation.tr("AI chat") },
                    { key: "dashboard", label: Translation.tr("Dashboard") },
                    { key: "cheatsheet", label: Translation.tr("Cheatsheet") },
                    { key: "updates", label: Translation.tr("Update overlay") },
                    { key: "dialogs", label: Translation.tr("Dialogs") }
                ]
                delegate: MascotPoseGallery {
                    required property var modelData
                    Layout.fillWidth: true
                    label: modelData.label
                    options: mascotReactionsGroup.poseOptions
                    currentValue: Config.options?.mascot?.surfacePoses?.[modelData.key] ?? ""
                    onSelected: value => Config.setNestedValue("mascot.surfacePoses." + modelData.key, value)
                }
            }
        }

        // Where the static mascot may appear
        SettingsGroup {
            StyledText {
                text: Translation.tr("Surfaces")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }

            SettingsSwitch {
                buttonIcon: "inbox"
                text: Translation.tr("Empty states")
                checked: Config.options?.mascot?.surfaces?.emptyStates ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.emptyStates", checked)
                StyledToolTip { text: Translation.tr("Notifications, clipboard, todo, media, calendar, wallpapers, search results") }
            }
            SettingsSwitch {
                buttonIcon: "info"
                text: Translation.tr("About pages")
                checked: Config.options?.mascot?.surfaces?.about ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.about", checked)
            }
            SettingsSwitch {
                buttonIcon: "power_settings_new"
                text: Translation.tr("Session screen")
                checked: Config.options?.mascot?.surfaces?.session ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.session", checked)
            }
            SettingsSwitch {
                buttonIcon: "neurology"
                text: Translation.tr("AI chat")
                checked: Config.options?.mascot?.surfaces?.aiChat ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.aiChat", checked)
            }
            SettingsSwitch {
                buttonIcon: "dashboard"
                text: Translation.tr("Dashboard")
                checked: Config.options?.mascot?.surfaces?.dashboard ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.dashboard", checked)
            }
            SettingsSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Cheatsheet")
                checked: Config.options?.mascot?.surfaces?.cheatsheet ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.cheatsheet", checked)
            }
            SettingsSwitch {
                buttonIcon: "wb_sunny"
                text: Translation.tr("Boot greeting")
                checked: Config.options?.mascot?.surfaces?.bootGreeting ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.bootGreeting", checked)
            }
            SettingsSwitch {
                buttonIcon: "system_update"
                text: Translation.tr("Update overlay")
                checked: Config.options?.mascot?.surfaces?.updates ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.updates", checked)
            }
            SettingsSwitch {
                buttonIcon: "warning"
                text: Translation.tr("Dialogs")
                checked: Config.options?.mascot?.surfaces?.dialogs ?? true
                onCheckedChanged: Config.setNestedValue("mascot.surfaces.dialogs", checked)
                StyledToolTip { text: Translation.tr("Close confirmation and similar dialogs") }
            }
        }

        // Extra things she can say
        SettingsGroup {
            StyledText {
                text: Translation.tr("Custom phrases (one per line)")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Things she can say on her visits…")
                text: (Config.options?.mascot?.companion?.customLines ?? []).join("\n")
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("mascot.companion.customLines",
                            text.split("\n").map(l => l.trim()).filter(l => l.length > 0))
                    });
                }
            }
        }
    }

    SettingsCardSection {
        icon: "photo_library"
        title: Translation.tr("Kira collection")
        expanded: false

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Every shipped illustration has a role here. Full-body poses power the live companion; portraits, chibis and key art stay available as a curated character archive.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            MascotCollection {
                Layout.fillWidth: true
            }
        }
    }
}
