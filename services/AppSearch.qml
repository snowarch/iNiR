pragma Singleton

import QtQuick
import qs.modules.common
import qs.modules.common.functions
import Quickshell

/**
 * - Eases fuzzy searching for applications by name
 * - Guesses icon name for window class name
 */
Singleton {
    id: root
    property bool sloppySearch: Config.options?.search?.sloppy ?? false
    property real scoreThreshold: 0.2
    property var substitutions: ({
        // IDEs & Editors
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "code": "visual-studio-code",
        "code-oss": "visual-studio-code",
        "vscodium": "vscodium",
        "windsurf": "visual-studio-code",
        "cursor": "visual-studio-code",
        "zed": "dev.zed.Zed",
        "Zed": "dev.zed.Zed",
        
        // Browsers
        "firefox-esr": "firefox",
        "firefox-developer-edition": "firefox-developer-edition",
        "firefoxdeveloperedition": "firefox-developer-edition",
        "chromium-browser": "chromium",
        "google-chrome-stable": "google-chrome",
        "brave-browser": "brave",
        "Microsoft-edge": "microsoft-edge",
        "microsoft-edge-stable": "microsoft-edge",
        
        // Terminals
        "footclient": "foot",
        "foot-server": "foot",
        "kitty": "kitty",
        "Alacritty": "Alacritty",
        "alacritty": "Alacritty",
        "org.wezfurlong.wezterm": "org.wezfurlong.wezterm",
        "wezterm-gui": "org.wezfurlong.wezterm",
        
        // Media
        "spotify": "spotify",
        "Spotify": "spotify",
        "spotify-launcher": "spotify",
        "vlc": "vlc",
        "mpv": "mpv",
        "io.mpv.Mpv": "mpv",
        
        // Communication
        "discord": "discord",
        "Discord": "discord",
        "vesktop": "discord",
        "Vesktop": "discord",
        "WebCord": "webcord",
        "telegram-desktop": "telegram",
        "TelegramDesktop": "telegram",
        "org.telegram.desktop": "telegram",
        "Slack": "slack",
        "slack": "slack",
        "teams-for-linux": "teams",
        "zoom": "Zoom",
        
        // File managers
        "org.gnome.Nautilus": "org.gnome.Nautilus",
        "nautilus": "org.gnome.Nautilus",
        "dolphin": "system-file-manager",
        "org.kde.dolphin": "system-file-manager",
        "thunar": "org.xfce.thunar",
        "Thunar": "org.xfce.thunar",
        "pcmanfm": "system-file-manager",
        "nemo": "nemo",
        
        // System
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "pavucontrol": "multimedia-volume-control",
        "gnome-control-center": "org.gnome.Settings",
        "systemsettings": "systemsettings",
        
        // Office
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "libreoffice-writer": "libreoffice-writer",
        "libreoffice-calc": "libreoffice-calc",
        "libreoffice-impress": "libreoffice-impress",
        "libreoffice-startcenter": "libreoffice-startcenter",
        
        // Gaming
        "steam": "steam",
        "Steam": "steam",
        "lutris": "lutris",
        "heroic": "com.heroicgameslauncher.hgl",
        
        // Development
        "jetbrains-idea": "intellij-idea",
        "jetbrains-idea-ce": "idea",
        "jetbrains-pycharm": "pycharm",
        "jetbrains-webstorm": "webstorm",
        "jetbrains-clion": "clion",
        "jetbrains-goland": "goland",
        "jetbrains-rider": "rider",
        "jetbrains-datagrip": "datagrip",
        
        // Electron apps - common patterns
        "obsidian": "obsidian",
        "Obsidian": "obsidian",
        "notion-app": "notion-app",
        "Notion": "notion-app",
        "figma-linux": "figma",
        "Figma": "figma",
        "postman": "postman",
        "Postman": "postman",
        "insomnia": "insomnia",
        "bitwarden": "bitwarden",
        "1password": "1password",
        
        // Others
        "org.gnome.Terminal": "utilities-terminal",
        "gnome-terminal": "utilities-terminal",
        "xdg-desktop-portal-gtk": "preferences-desktop",
        "org.freedesktop.impl.portal.desktop.gtk": "preferences-desktop",
        "polkit-gnome-authentication-agent-1": "dialog-password",
        
        // YouTube Music (pear launcher)
        "com.github.th_ch.youtube_music": "youtube-music",
        "youtube-music": "youtube-music",
    })
    property var regexSubstitutions: [
        // Steam games
        { "regex": /^steam_app_(\d+)$/, "replace": "steam_icon_$1" },
        { "regex": /^steam_proton/, "replace": "steam" },
        
        // Games
        { "regex": /Minecraft.*/, "replace": "minecraft" },
        { "regex": /^net\.lutris\..*/, "replace": "lutris" },
        
        // JetBrains IDEs
        { "regex": /^jetbrains-(.+)$/, "replace": "$1" },
        
        // Electron apps with random suffixes
        { "regex": /^(discord|slack|teams|zoom).*$/i, "replace": "$1" },
        
        // LibreOffice variants
        { "regex": /^soffice\..*/, "replace": "libreoffice-startcenter" },
        { "regex": /^libreoffice-.*writer.*/, "replace": "libreoffice-writer" },
        { "regex": /^libreoffice-.*calc.*/, "replace": "libreoffice-calc" },
        
        // Flatpak reverse domain
        { "regex": /^org\.mozilla\.firefox$/, "replace": "firefox" },
        { "regex": /^com\.google\.Chrome$/, "replace": "google-chrome" },
        { "regex": /^com\.microsoft\.Edge$/, "replace": "microsoft-edge" },
        { "regex": /^io\.github\.AquariusPower\..+/, "replace": "application-x-executable" },
        
        // Security dialogs
        { "regex": /.*polkit.*/, "replace": "system-lock-screen" },
        { "regex": /gcr.prompter/, "replace": "system-lock-screen" },
        { "regex": /.*authentication.*agent.*/i, "replace": "dialog-password" },
        
        // Portal/XDG dialogs
        { "regex": /xdg-desktop-portal.*/, "replace": "preferences-desktop" },
        { "regex": /org\.freedesktop\.impl\.portal.*/, "replace": "preferences-desktop" },
        
        // Wine/Proton apps
        { "regex": /^wine-.*/, "replace": "wine" },
        { "regex": /^proton-.*/, "replace": "steam" }
    ]

    // Cached - rebuilt with debounce to avoid UI freeze on DesktopEntries updates
    property var _cachedList: []
    property var _cachedPreppedNames: []
    property var _cachedPreppedIcons: []
    // Reverse-lookup maps for matching running windows to desktop entries
    // Key: lowercased startupClass/exec-basename/desktop-id-stem → DesktopEntry
    property var _startupClassMap: ({})
    property var _execBasenameMap: ({})
    property var _desktopIdStemMap: ({})

    readonly property var list: _cachedList
    readonly property var preppedNames: _cachedPreppedNames
    readonly property var preppedIcons: _cachedPreppedIcons

    QtObject {
        id: internal
        property var rebuildTimer: Timer {
            interval: 500
            onTriggered: root._rebuildCache()
        }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { internal.rebuildTimer.restart() }
    }

    Component.onCompleted: _rebuildCache()

    function _rebuildCache(): void {
        const entries = Array.from(DesktopEntries.applications.values)
            .sort((a, b) => a.name.localeCompare(b.name))
        _cachedList = entries
        _cachedPreppedNames = entries.map(a => ({ name: Fuzzy.prepare(`${a.name} `), entry: a }))
        _cachedPreppedIcons = entries.map(a => ({ name: Fuzzy.prepare(`${a.icon} `), entry: a }))

        // Build reverse-lookup maps for matching toplevel appIds to desktop entries.
        // This is how we find icons for AppImages, Electron apps, and other apps whose
        // window appId doesn't match their desktop entry id.
        const scMap = {};
        const ebMap = {};
        const idMap = {};
        for (const entry of entries) {
            // Map by StartupWMClass (case-insensitive)
            const sc = (entry.startupClass ?? "").trim();
            if (sc.length > 0) {
                scMap[sc.toLowerCase()] = entry;
            }

            // Map by executable basename from the parsed command
            const cmd = entry.command;
            if (cmd && cmd.length > 0) {
                const execPath = cmd[0] ?? "";
                const basename = execPath.split("/").pop().toLowerCase();
                if (basename.length > 0 && !["bash", "sh", "env", "python", "python3", "java", "electron", "node"].includes(basename)) {
                    ebMap[basename] = entry;
                    // Also try without common extensions (.appimage, .AppImage, etc.)
                    const noExt = basename.replace(/\.(appimage|app|bin|exe)$/i, "");
                    if (noExt !== basename && noExt.length > 0) {
                        ebMap[noExt] = entry;
                    }
                }
            }

            // Map by desktop entry id stem (without .desktop suffix, and last segment of reverse-domain)
            const id = (entry.id ?? "").trim();
            if (id.length > 0) {
                const stem = id.replace(/\.desktop$/, "").toLowerCase();
                idMap[stem] = entry;
                // Also index the last segment of reverse-domain IDs
                // e.g., "it.mijorus.gearlever" → "gearlever"
                const parts = stem.split(".");
                if (parts.length > 1) {
                    const lastPart = parts[parts.length - 1];
                    if (lastPart.length > 2 && !idMap[lastPart]) {
                        idMap[lastPart] = entry;
                    }
                }
            }
        }
        _startupClassMap = scMap;
        _execBasenameMap = ebMap;
        _desktopIdStemMap = idMap;
    }

    function fuzzyQuery(search: string): var {
        if (_cachedList.length === 0) return []
        if (!search || search.trim() === "") return []

        const searchLower = search.toLowerCase().trim()

        // Fast path: exact prefix match gets priority
        const exactPrefixMatches = _cachedList.filter(obj =>
            obj.name?.toLowerCase().startsWith(searchLower)
        )

        if (root.sloppySearch) {
            // Levenshtein-based scoring
            const results = _cachedList.map(obj => {
                const nameLower = obj.name?.toLowerCase() ?? ""
                let score = Levendist.computeScore(nameLower, searchLower)

                // Boost for prefix match
                if (nameLower.startsWith(searchLower)) {
                    score += 0.3
                }
                // Boost for word boundary match
                else if (nameLower.includes(" " + searchLower) || nameLower.includes("-" + searchLower)) {
                    score += 0.15
                }
                // Boost for contains
                else if (nameLower.includes(searchLower)) {
                    score += 0.1
                }

                return { entry: obj, score: Math.min(1.0, score) }
            }).filter(item => item.score > root.scoreThreshold)
              .sort((a, b) => b.score - a.score)

            return results.map(item => item.entry)
        }

        // Hybrid approach: combine fuzzysort with smart scoring
        const fuzzyResults = Fuzzy.go(search, preppedNames, {
            all: true,
            key: "name",
            threshold: -10000 // Get all results, we'll filter ourselves
        })

        // Score and sort results
        const scoredResults = fuzzyResults.map(r => {
            const entry = r.obj.entry
            const nameLower = entry.name?.toLowerCase() ?? ""
            let score = r.score

            // Significant boost for exact prefix match
            if (nameLower.startsWith(searchLower)) {
                score += 50000
            }
            // Boost for word start match
            else if (nameLower.includes(" " + searchLower) || nameLower.includes("-" + searchLower)) {
                score += 20000
            }
            // Small boost for substring match
            else if (nameLower.includes(searchLower)) {
                score += 10000
            }

            return { entry, score }
        }).sort((a, b) => b.score - a.score)

        return scoredResults.map(item => item.entry)
    }

    function iconExists(iconName) {
        if (!iconName || iconName.length == 0) return false;
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    function getReverseDomainNameAppName(str) {
        return str.split('.').slice(-1)[0]
    }

    function getKebabNormalizedAppName(str) {
        return str.toLowerCase().replace(/\s+/g, "-");
    }

    function getUndescoreToKebabAppName(str) {
        return str.toLowerCase().replace(/_/g, "-");
    }

    // Enhanced desktop entry lookup: tries heuristicLookup first, then aggressive
    // normalization for Electron/AppImage apps whose window appId doesn't match
    // their .desktop file (e.g., "@trezor/suite-desktop" → "trezor-suite.desktop").
    function lookupDesktopEntry(appId) {
        if (!appId || appId.length === 0) return null;

        // 1. Quickshell's built-in heuristic (handles simple cases)
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry) return entry;

        // 2. Direct map lookups (case-insensitive, kebab-normalized)
        const lowered = appId.toLowerCase();
        const kebab = lowered.replace(/\s+/g, "-");
        const direct = _startupClassMap[lowered]
            ?? _execBasenameMap[lowered]
            ?? _desktopIdStemMap[lowered]
            ?? _execBasenameMap[kebab]
            ?? _desktopIdStemMap[kebab];
        if (direct) return direct;

        // 3. Aggressive normalization for scoped/prefixed appIds
        //    "@trezor/suite-desktop" → strip @ → split on / → join with - → strip -desktop suffix
        //    "com.example.app-desktop" → reverse-domain last segment → "app-desktop" → "app"
        const stripped = lowered.replace(/^@/, "");
        const segments = stripped.split("/").filter(s => s.length > 0);

        // Try joining all segments with hyphen: "trezor-suite-desktop"
        if (segments.length > 1) {
            const joined = segments.join("-");
            const joinedNoSuffix = joined.replace(/-(desktop|app|electron|bin)$/, "");
            const candidates = [joined, joinedNoSuffix];
            // Also try reversed segment order: "suite-desktop-trezor" → "suite-trezor"
            if (segments.length === 2) {
                const reversed = segments[1] + "-" + segments[0];
                const reversedNoSuffix = reversed.replace(/-(desktop|app|electron|bin)$/, "");
                candidates.push(reversed, reversedNoSuffix);
            }
            for (const c of candidates) {
                const found = _execBasenameMap[c] ?? _desktopIdStemMap[c] ?? _startupClassMap[c];
                if (found) return found;
            }
            // Try each segment individually
            for (const seg of segments) {
                const segClean = seg.replace(/-(desktop|app|electron|bin)$/, "");
                const found = _execBasenameMap[seg] ?? _desktopIdStemMap[seg]
                    ?? _execBasenameMap[segClean] ?? _desktopIdStemMap[segClean]
                    ?? _startupClassMap[seg] ?? _startupClassMap[segClean];
                if (found) return found;
            }
        }

        // 4. Strip common suffixes on the full appId and retry
        const noSuffix = kebab.replace(/-(desktop|app|electron|bin)$/, "");
        if (noSuffix !== kebab) {
            const found = _execBasenameMap[noSuffix] ?? _desktopIdStemMap[noSuffix] ?? _startupClassMap[noSuffix];
            if (found) return found;
        }

        // 5. Token overlap scoring as last resort — extract meaningful tokens from the appId
        //    and score against all desktop entries' names, ids, and exec basenames
        const tokens = stripped.replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/).filter(t => t.length > 2);
        if (tokens.length > 0) {
            let bestEntry = null;
            let bestScore = 0;
            for (const [key, mapEntry] of Object.entries(_desktopIdStemMap)) {
                const keyTokens = key.replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/);
                let overlap = 0;
                for (const t of tokens) {
                    if (keyTokens.some(kt => kt === t || kt.includes(t) || t.includes(kt))) overlap++;
                }
                const score = overlap / Math.max(tokens.length, keyTokens.length);
                if (score > bestScore && score >= 0.5) {
                    bestScore = score;
                    bestEntry = mapEntry;
                }
            }
            // Also check startupClassMap tokens
            for (const [key, mapEntry] of Object.entries(_startupClassMap)) {
                const keyTokens = key.replace(/[^a-z0-9]+/g, " ").trim().split(/\s+/);
                let overlap = 0;
                for (const t of tokens) {
                    if (keyTokens.some(kt => kt === t || kt.includes(t) || t.includes(kt))) overlap++;
                }
                const score = overlap / Math.max(tokens.length, keyTokens.length);
                if (score > bestScore && score >= 0.5) {
                    bestScore = score;
                    bestEntry = mapEntry;
                }
            }
            if (bestEntry) return bestEntry;
        }

        return null;
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        // Quickshell's desktop entry lookup
        const entry = DesktopEntries.heuristicLookup(str);
        if (entry) return entry.icon;

        // Normal substitutions
        if (substitutions[str]) return substitutions[str];
        if (substitutions[str.toLowerCase()]) return substitutions[str.toLowerCase()];

        // Regex substitutions
        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        // Icon exists -> return as is
        if (iconExists(str)) return str;

        // Simple guesses
        const lowercased = str.toLowerCase();
        if (iconExists(lowercased)) return lowercased;

        const reverseDomainNameAppName = getReverseDomainNameAppName(str);
        if (iconExists(reverseDomainNameAppName)) return reverseDomainNameAppName;

        const lowercasedDomainNameAppName = reverseDomainNameAppName.toLowerCase();
        if (iconExists(lowercasedDomainNameAppName)) return lowercasedDomainNameAppName;

        const kebabNormalizedGuess = getKebabNormalizedAppName(str);
        if (iconExists(kebabNormalizedGuess)) return kebabNormalizedGuess;

        const undescoreToKebabGuess = getUndescoreToKebabAppName(str);
        if (iconExists(undescoreToKebabGuess)) return undescoreToKebabGuess;

        // Reverse-lookup: use the full lookupDesktopEntry which handles scoped appIds,
        // token normalization, and aggressive matching for AppImages/Electron apps.
        const mapMatch = lookupDesktopEntry(str);
        if (mapMatch?.icon) return mapMatch.icon;

        // Search in desktop entries
        if (_cachedPreppedIcons.length > 0) {
            const iconSearchResults = Fuzzy.go(str, preppedIcons, {
                all: true,
                key: "name"
            }).map(r => r.obj.entry);
            if (iconSearchResults.length > 0) {
                const guess = iconSearchResults[0].icon
                if (iconExists(guess)) return guess;
            }
        }

        const nameSearchResults = root.fuzzyQuery(str);
        if (nameSearchResults.length > 0) {
            const guess = nameSearchResults[0].icon
            if (iconExists(guess)) return guess;
        }


        // Give up
        return str;
    }

    // Returns a ready-to-use icon source (handles both icon names and absolute paths)
    function getIconSource(str, fallback): string {
        fallback = fallback ?? "image-missing"
        const icon = guessIcon(str);
        // Absolute path - return as file:// URL
        if (icon.startsWith("/")) {
            return "file://" + icon;
        }
        // Icon name - resolve via theme
        return Quickshell.iconPath(icon, fallback);
    }

    // Resolves an icon name/path directly (for when you already have the icon from a DesktopEntry)
    // Now handles broken absolute paths from Electron apps
    function resolveIcon(iconNameOrPath, fallback): string {
        fallback = fallback ?? "image-missing"
        if (!iconNameOrPath) return Quickshell.iconPath(fallback, "");
        
        // Handle absolute paths - check for known Electron app patterns
        if (iconNameOrPath.startsWith("/") || iconNameOrPath.startsWith("file://")) {
            const path = iconNameOrPath.startsWith("file://") ? iconNameOrPath.substring(7) : iconNameOrPath;
            
            // Known Electron app patterns - return proper icon name
            if (path.includes("/Windsurf/") || path.includes("/windsurf/")) {
                return Quickshell.iconPath("visual-studio-code", fallback);
            }
            if (path.includes("/Code/") || path.includes("/code/") || path.includes("/VSCode/")) {
                return Quickshell.iconPath("visual-studio-code", fallback);
            }
            if (path.includes("/Cursor/") || path.includes("/cursor/")) {
                return Quickshell.iconPath("visual-studio-code", fallback);
            }
            if (path.includes("/Discord/") || path.includes("/discord/")) {
                return Quickshell.iconPath("discord", fallback);
            }
            if (path.includes("/Slack/") || path.includes("/slack/")) {
                return Quickshell.iconPath("slack", fallback);
            }
            if (path.includes("/Obsidian/") || path.includes("/obsidian/")) {
                return Quickshell.iconPath("obsidian", fallback);
            }
            if (path.includes("/Spotify/") || path.includes("/spotify/")) {
                return Quickshell.iconPath("spotify", fallback);
            }
            if (path.includes("/Zed/") || path.includes("/zed/")) {
                return Quickshell.iconPath("dev.zed.Zed", fallback);
            }
            
            // Check for volatile paths (Downloads, tmp, etc.)
            if (path.includes("/Descargas/") || path.includes("/Downloads/") || 
                path.includes("/tmp/") || path.includes("/resources/")) {
                const fileName = path.split("/").pop();
                let baseName = fileName.includes(".") ? fileName.split(".").slice(0, -1).join(".") : fileName;
                if (baseName === "code") return Quickshell.iconPath("visual-studio-code", fallback);
                return Quickshell.iconPath(baseName, fallback);
            }
            
            // Return as file:// URL for valid paths
            return iconNameOrPath.startsWith("file://") ? iconNameOrPath : "file://" + iconNameOrPath;
        }
        
        // Icon name - resolve via theme
        return Quickshell.iconPath(iconNameOrPath, fallback);
    }
}
