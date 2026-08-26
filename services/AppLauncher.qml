pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.services

Singleton {
    id: root

    property int _configRevision: 0

    Connections {
        target: Config
        function onConfigChanged(): void { root._configRevision++ }
    }

    readonly property var _slotDefinitions: [
        {
            id: "terminal",
            label: Translation.tr("Terminal"),
            description: Translation.tr("Used by shell actions, keybinds, package commands, and terminal-backed launchers."),
            defaultCommand: "kitty",
            placeholder: "kitty",
            presets: [
                { id: "foot", label: "Foot", command: "foot" },
                { id: "kitty", label: "Kitty", command: "kitty" },
                { id: "ghostty", label: "Ghostty", command: "ghostty" },
                { id: "alacritty", label: "Alacritty", command: "alacritty" },
                { id: "wezterm", label: "WezTerm", command: "wezterm" },
                { id: "konsole", label: "Konsole", command: "konsole" }
            ]
        },
        {
            id: "browser",
            label: Translation.tr("Browser"),
            description: Translation.tr("Used by browser shortcuts and app launch tiles."),
            defaultCommand: "firefox",
            placeholder: "firefox",
            presets: [
                { id: "firefox", label: "Firefox", command: "firefox" },
                { id: "zen", label: "Zen Browser", command: "zen-browser" },
                { id: "librewolf", label: "LibreWolf", command: "librewolf" },
                { id: "chromium", label: "Chromium", command: "chromium" },
                { id: "chrome", label: "Google Chrome", command: "google-chrome-stable" },
                { id: "brave", label: "Brave", command: "brave-browser" }
            ]
        },
        {
            id: "files",
            label: Translation.tr("File manager"),
            description: Translation.tr("Used by file manager shortcuts and app launch tiles."),
            defaultCommand: "nautilus",
            placeholder: "nautilus",
            presets: [
                { id: "nautilus", label: "GNOME Files", command: "nautilus" },
                { id: "dolphin", label: "Dolphin", command: "dolphin" },
                { id: "thunar", label: "Thunar", command: "thunar" },
                { id: "nemo", label: "Nemo", command: "nemo" },
                { id: "pcmanfm", label: "PCManFM", command: "pcmanfm" }
            ]
        },
        {
            id: "manageUser",
            label: Translation.tr("Manage my account"),
            description: Translation.tr("Used by the profile menu and start menu account shortcuts."),
            defaultCommand: "kcmshell6 kcm_users",
            placeholder: "kcmshell6 kcm_users",
            presets: [
                { id: "kcm-users", label: "KDE Users", command: "kcmshell6 kcm_users" },
                { id: "gnome-users", label: "GNOME Users", command: "gnome-control-center user-accounts" },
                { id: "mate-users", label: "MATE Users", command: "mate-user-admin" }
            ]
        },
        {
            id: "network",
            label: Translation.tr("Network manager (TUI)"),
            description: Translation.tr("Used by Wi-Fi details shortcuts when a text-mode network tool is preferred."),
            defaultCommand: "nm-connection-editor",
            placeholder: "kitty -1 fish -c nmtui",
            presets: [
                { id: "nm-editor", label: "NetworkManager GUI", command: "nm-connection-editor" },
                { id: "nmtui-kitty", label: "nmtui in Kitty", command: "kitty -1 fish -c nmtui" },
                { id: "nmtui-foot", label: "nmtui in Foot", command: "foot -e nmtui" },
                { id: "kcm-network", label: "KDE Network", command: "kcmshell6 kcm_networkmanagement" }
            ]
        },
        {
            id: "networkEthernet",
            label: Translation.tr("Network settings (GUI)"),
            description: Translation.tr("Used by Ethernet-oriented settings shortcuts."),
            defaultCommand: "nm-connection-editor",
            placeholder: "kcmshell6 kcm_networkmanagement",
            presets: [
                { id: "nm-editor", label: "NetworkManager GUI", command: "nm-connection-editor" },
                { id: "kcm-network", label: "KDE Network", command: "kcmshell6 kcm_networkmanagement" },
                { id: "gnome-network", label: "GNOME Network", command: "gnome-control-center network" }
            ]
        },
        {
            id: "bluetooth",
            label: Translation.tr("Bluetooth settings"),
            description: Translation.tr("Used by Bluetooth toggles, dialogs, and action center shortcuts."),
            defaultCommand: "blueman-manager",
            placeholder: "kcmshell6 kcm_bluetooth",
            presets: [
                { id: "blueman", label: "Blueman", command: "blueman-manager" },
                { id: "kcm-bluetooth", label: "KDE Bluetooth", command: "kcmshell6 kcm_bluetooth" },
                { id: "gnome-bluetooth", label: "GNOME Bluetooth", command: "gnome-control-center bluetooth" }
            ]
        },
        {
            id: "volumeMixer",
            label: Translation.tr("Volume mixer"),
            description: Translation.tr("Used by audio details buttons and quick launch surfaces."),
            defaultCommand: "pavucontrol",
            placeholder: "pavucontrol",
            presets: [
                { id: "pavucontrol", label: "Pavucontrol", command: "pavucontrol" },
                { id: "pavucontrol-qt", label: "Pavucontrol Qt", command: "pavucontrol-qt" },
                { id: "helvum", label: "Helvum", command: "helvum" }
            ]
        },
        {
            id: "taskManager",
            label: Translation.tr("Task manager"),
            description: Translation.tr("Used by the start menu, actions, and session tools."),
            defaultCommand: "missioncenter",
            placeholder: "missioncenter",
            presets: [
                { id: "missioncenter", label: "Mission Center", command: "missioncenter" },
                { id: "resources", label: "GNOME Resources", command: "resources" },
                { id: "plasma-monitor", label: "KSysGuard", command: "plasma-systemmonitor" },
                { id: "btop", label: "btop", command: "kitty -e btop" }
            ]
        }
    ]

    function slotDefinitions(): list<var> {
        return root._slotDefinitions
    }

    function slotDefinition(slotId: string): var {
        return root._slotDefinitions.find(definition => definition.id === slotId) ?? null
    }

    function configuredCommand(slotId: string): string {
        const apps = Config.options?.apps ?? {}
        const rawValue = apps[slotId]
        return typeof rawValue === "string" ? rawValue.trim() : ""
    }

    function defaultCommand(slotId: string): string {
        return String(root.slotDefinition(slotId)?.defaultCommand ?? "").trim()
    }

    function commandFor(slotId: string): string {
        const configured = root.configuredCommand(slotId)
        return configured.length > 0 ? configured : root.defaultCommand(slotId)
    }

    function presetOptions(slotId: string): list<var> {
        const definition = root.slotDefinition(slotId)
        const options = (definition?.presets ?? []).map(preset => ({
            value: preset.id,
            displayName: preset.label
        }))

        options.push({
            value: "__custom__",
            displayName: Translation.tr("Custom command")
        })

        return options
    }

    function presetIdFor(slotId: string): string {
        const definition = root.slotDefinition(slotId)
        if (!definition)
            return "__custom__"

        const currentCommand = root.commandFor(slotId)
        const preset = (definition.presets ?? []).find(candidate => candidate.command === currentCommand)
        return preset?.id ?? "__custom__"
    }

    function applyPreset(slotId: string, presetId: string): void {
        const definition = root.slotDefinition(slotId)
        if (!definition)
            return

        const preset = (definition.presets ?? []).find(candidate => candidate.id === presetId)
        if (!preset)
            return

        Config.setNestedValue(`apps.${slotId}`, preset.command)

        // Sync browser changes to xdg-settings
        if (slotId === "browser") {
            const desktopFileMap = {
                "firefox": "firefox.desktop",
                "zen-browser": "zen.desktop",
                "librewolf": "librewolf.desktop",
                "chromium": "chromium.desktop",
                "google-chrome-stable": "google-chrome.desktop",
                "brave-browser": "brave-browser.desktop"
            }
            const desktopFile = desktopFileMap[preset.command]
            if (desktopFile) {
                Quickshell.execDetached(["xdg-settings", "set", "default-web-browser", desktopFile])
            }
        }
    }

    function setCustomCommand(slotId: string, command: string): void {
        Config.setNestedValue(`apps.${slotId}`, String(command ?? "").trim())
    }

    function launch(slotId: string, extraArgs): void {
        const extras = Array.from(extraArgs ?? []).map(arg => String(arg ?? "")).filter(arg => arg.length > 0)
        const command = root.commandFor(slotId)
        if (command.length === 0)
            return

        // If the command is a single word (no args, no path), try desktop entry
        // lookup first — handles Flatpak apps that aren't in PATH but have
        // .desktop files with the correct Exec= line.
        if (!command.includes(" ") && !command.includes("/")) {
            const entry = DesktopEntries.heuristicLookup(command)
            if (entry) {
                if (extras.length === 0) {
                    AppSearch.launchEntry(entry)
                    return
                }
                const cmd = AppSearch._sanitizeDesktopArgs(entry.command)
                AppSearch.launchEntry({
                    originalEntry: entry.originalEntry ?? entry,
                    id: entry.id,
                    name: entry.name,
                    command: cmd.concat(extras),
                    workingDirectory: entry.workingDirectory,
                    runInTerminal: entry.runInTerminal
                })
                return
            }
        }

        if (extras.length === 0) {
            ShellExec.execCmd(command)
            return
        }

        const words = command.split(/\s+/).filter(word => word.length > 0)
        ShellExec.execDetachedArgs(words.concat(extras))
    }

    function launchUrl(slotId: string, url: string): void {
        const raw = String(url ?? "").trim()
        if (raw.length === 0) {
            root.launch(slotId)
            return
        }
        root.launch(slotId, [raw])
    }

    function launchNetworkSettings(useEthernet: bool): void {
        const slot = useEthernet ? "networkEthernet" : "network"
        const command = root.commandFor(slot)
        // The configured tool may simply not be installed (default is
        // nm-connection-editor); a silently failed exec looks like a dead
        // Details button. Probe and fall back through known tools.
        const fallbacks = [
            "nm-connection-editor",
            "kcmshell6 kcm_networkmanagement",
            "gnome-control-center network",
            "kitty -1 fish -c nmtui",
            "foot -e nmtui"
        ]
        const chain = [command].concat(fallbacks.filter(c => c.split(" ")[0] !== command.split(" ")[0]))
        // No brace grouping: the string runs under fish when available.
        const sh = chain
            .filter(c => c.length > 0)
            .map(c => `command -v ${c.split(" ")[0]} >/dev/null 2>&1 && exec ${c}`)
            .join(" || ")
        ShellExec.execCmd(sh)
    }
}
