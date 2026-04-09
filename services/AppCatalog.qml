pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

/**
 * AppCatalog — Curated software catalog with multi-distro install support.
 *
 * Loads a JSON catalog of curated apps, detects the system's package manager,
 * checks installed status, and can install/remove apps via terminal.
 *
 * Usage:
 *   AppCatalog.filteredCatalog  // current filtered list
 *   AppCatalog.installApp("firefox")
 *   AppCatalog.removeApp("firefox")
 */
Singleton {
    id: root

    // ─── Public state ──────────────────────────────────────────────

    property list<var> catalog: []
    property var installedPackages: ({})
    property string selectedCategory: "all"
    property string searchQuery: ""
    property bool loading: true
    property bool checkingInstalled: false
    property list<string> categories: []

    readonly property string packageManager: _detectedPm
    readonly property bool hasFlatpak: _flatpakAvailable
    readonly property bool hasAurHelper: _aurHelperAvailable
    readonly property string aurHelper: _detectedAurHelper

    readonly property var filteredCatalog: {
        // Depend on reactive properties
        const _cat = root.selectedCategory
        const _q = root.searchQuery.toLowerCase().trim()
        const _installed = root.installedPackages

        let result = root.catalog
        if (_cat !== "all") {
            result = result.filter(app => app.category === _cat)
        }
        if (_q.length > 0) {
            result = result.filter(app => {
                return app.name.toLowerCase().includes(_q)
                    || app.description.toLowerCase().includes(_q)
                    || (app.tags ?? []).some(t => t.toLowerCase().includes(_q))
            })
        }
        return result
    }

    // ─── Private state ─────────────────────────────────────────────

    property string _detectedPm: "unknown"
    property bool _flatpakAvailable: false
    property bool _aurHelperAvailable: false
    property string _detectedAurHelper: ""
    property string _installedRaw: ""
    property string _detectPmRaw: ""

    // ─── Catalog loading ───────────────────────────────────────────

    FileView {
        id: catalogFile
        path: Qt.resolvedUrl("../defaults/app-catalog.json")
        onLoadedChanged: {
            if (!catalogFile.loaded) return
            try {
                const content = catalogFile.text()
                const parsed = JSON.parse(content)
                root.catalog = parsed
                // Extract unique categories
                const cats = new Set()
                for (const app of parsed) {
                    if (app.category) cats.add(app.category)
                }
                root.categories = [...cats].sort()
                root.loading = false
                // Now detect PM and check installed
                _detectPmProc.running = true
            } catch (e) {
                console.warn("[AppCatalog] Failed to parse catalog:", e)
                root.loading = false
            }
        }
    }

    // ─── Package manager detection ─────────────────────────────────

    Process {
        id: _detectPmProc
        command: ["/usr/bin/bash", "-c",
            "pm=unknown; " +
            "command -v pacman &>/dev/null && pm=pacman; " +
            "[ \"$pm\" = unknown ] && command -v apt &>/dev/null && pm=apt; " +
            "[ \"$pm\" = unknown ] && command -v dnf &>/dev/null && pm=dnf; " +
            "echo \"$pm\"; " +
            "command -v flatpak &>/dev/null && echo flatpak || echo noflatpak; " +
            "command -v yay &>/dev/null && echo yay || (command -v paru &>/dev/null && echo paru || echo noaur)"
        ]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._detectPmRaw += data }
        }
        onExited: {
            const lines = root._detectPmRaw.trim().split("\n")
            if (lines.length >= 1) root._detectedPm = lines[0].trim()
            if (lines.length >= 2) root._flatpakAvailable = lines[1].trim() === "flatpak"
            if (lines.length >= 3) {
                const aurLine = lines[2].trim()
                root._aurHelperAvailable = (aurLine === "yay" || aurLine === "paru")
                root._detectedAurHelper = root._aurHelperAvailable ? aurLine : ""
            }
            root._refreshInstalled()
        }
    }

    // ─── Installed status check ────────────────────────────────────

    function _refreshInstalled(): void {
        if (root.catalog.length === 0) return
        root.checkingInstalled = true
        root._installedRaw = ""

        let cmd = ""
        switch (root._detectedPm) {
            case "pacman":
                cmd = "pacman -Qq 2>/dev/null"
                break
            case "apt":
                cmd = "dpkg --get-selections 2>/dev/null | grep -v deinstall | awk '{print $1}'"
                break
            case "dnf":
                cmd = "rpm -qa --qf '%{NAME}\\n' 2>/dev/null"
                break
            default:
                root.checkingInstalled = false
                return
        }
        // Also check flatpak if available
        if (root._flatpakAvailable) {
            cmd += "; echo '---FLATPAK---'; flatpak list --app --columns=application 2>/dev/null"
        }
        _installedProc.command = ["/usr/bin/bash", "-c", cmd]
        _installedProc.running = true
    }

    Process {
        id: _installedProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._installedRaw += data }
        }
        onExited: {
            root.checkingInstalled = false
            const raw = root._installedRaw
            const installedSet = new Set()

            // Split native and flatpak sections
            const parts = raw.split("---FLATPAK---")
            const nativeLines = (parts[0] ?? "").split("\n")
            const flatpakLines = (parts[1] ?? "").split("\n")

            for (const line of nativeLines) {
                const pkg = line.trim()
                if (pkg.length > 0) installedSet.add(pkg)
            }
            for (const line of flatpakLines) {
                const pkg = line.trim()
                if (pkg.length > 0) installedSet.add(pkg)
            }

            // Build installed map from catalog entries
            const result = {}
            for (const app of root.catalog) {
                const targets = app.targets ?? {}
                let found = false

                // Check native package
                if (targets.pacman && installedSet.has(targets.pacman)) found = true
                if (targets.aur && installedSet.has(targets.aur)) found = true
                if (targets.apt && installedSet.has(targets.apt)) found = true
                if (targets.dnf && installedSet.has(targets.dnf)) found = true
                if (targets.flatpak && installedSet.has(targets.flatpak)) found = true

                result[app.id] = found
            }
            root.installedPackages = result
        }
    }

    // ─── Install / Remove ──────────────────────────────────────────

    function _safeTerminal(): string {
        const configured = (Config.options?.apps?.terminal ?? "kitty").trim()
        if (configured.length === 0) return "kitty"
        if (!/^[A-Za-z0-9._+-]+$/.test(configured)) return "kitty"
        return configured
    }

    function _runTerminalScript(script: string, args): void {
        const command = ["/usr/bin/bash", "-lc", script + "\nprintf \"\\nPress Enter to close...\"\nread", "bash", ...(args ?? [])]
        const terminal = root._safeTerminal()
        if (terminal === "wezterm") {
            Quickshell.execDetached([terminal, "start", "--always-new-process", "--", ...command])
            return
        }
        Quickshell.execDetached([terminal, "-e", ...command])
    }

    function _getInstallTarget(app: var): var {
        const targets = app.targets ?? {}
        const pm = root._detectedPm

        // Try native package manager first
        if (pm === "pacman" && targets.pacman) return { pm: "pacman", pkg: targets.pacman }
        if (pm === "pacman" && targets.aur && root._aurHelperAvailable) return { pm: root._detectedAurHelper, pkg: targets.aur }
        if (pm === "apt" && targets.apt) return { pm: "apt", pkg: targets.apt }
        if (pm === "dnf" && targets.dnf) return { pm: "dnf", pkg: targets.dnf }

        // Flatpak fallback
        if (root._flatpakAvailable && targets.flatpak) return { pm: "flatpak", pkg: targets.flatpak }

        // AUR fallback if on pacman but package is AUR-only
        if (pm === "pacman" && targets.aur && !root._aurHelperAvailable) return { pm: "aur-missing", pkg: targets.aur }

        return null
    }

    function installApp(appId: string): bool {
        const app = root.catalog.find(a => a.id === appId)
        if (!app) return false

        const target = root._getInstallTarget(app)
        if (!target) {
            Quickshell.execDetached(["/usr/bin/notify-send",
                Translation.tr("Software"),
                Translation.tr("No package available for your system"),
                "-a", "iNiR"])
            return false
        }

        let script = ""
        switch (target.pm) {
            case "pacman":
                script = 'sudo pacman -S -- "$1"'
                break
            case "yay":
                script = 'yay -S -- "$1"'
                break
            case "paru":
                script = 'paru -S -- "$1"'
                break
            case "apt":
                script = 'sudo apt install -- "$1"'
                break
            case "dnf":
                script = 'sudo dnf install -- "$1"'
                break
            case "flatpak":
                script = 'flatpak install -y "$1"'
                break
            case "aur-missing":
                Quickshell.execDetached(["/usr/bin/notify-send",
                    Translation.tr("Software"),
                    Translation.tr("This package requires an AUR helper (yay or paru)"),
                    "-a", "iNiR"])
                return false
            default:
                return false
        }

        root._runTerminalScript(script, [target.pkg])

        // Schedule a re-check after user likely finishes
        _refreshTimer.restart()
        return true
    }

    function removeApp(appId: string): bool {
        const app = root.catalog.find(a => a.id === appId)
        if (!app) return false

        const targets = app.targets ?? {}
        const pm = root._detectedPm

        let script = ""
        let pkg = ""
        switch (pm) {
            case "pacman":
                pkg = targets.pacman ?? targets.aur ?? ""
                if (pkg.length === 0) return false
                script = 'sudo pacman -Rns -- "$1"'
                break
            case "apt":
                pkg = targets.apt ?? ""
                if (pkg.length === 0) return false
                script = 'sudo apt remove -- "$1"'
                break
            case "dnf":
                pkg = targets.dnf ?? ""
                if (pkg.length === 0) return false
                script = 'sudo dnf remove -- "$1"'
                break
            default:
                // Try flatpak remove
                if (root._flatpakAvailable && targets.flatpak) {
                    pkg = targets.flatpak
                    script = 'flatpak uninstall -y "$1"'
                } else {
                    return false
                }
        }

        root._runTerminalScript(script, [pkg])
        _refreshTimer.restart()
        return true
    }

    function isInstalled(appId: string): bool {
        return root.installedPackages[appId] ?? false
    }

    function getInstallTarget(app: var): var {
        return root._getInstallTarget(app)
    }

    function getInstallMethod(app: var): string {
        const target = root._getInstallTarget(app)
        if (!target) return ""
        const pm = target.pm ?? ""
        switch (pm) {
            case "pacman": return "pacman"
            case "yay": return "aur"
            case "paru": return "aur"
            case "apt": return "apt"
            case "dnf": return "dnf"
            case "flatpak": return "flatpak"
            case "aur-missing": return "aur"
            default: return pm
        }
    }

    function isAvailable(app: var): bool {
        return root._getInstallTarget(app) !== null
    }

    function refresh(): void {
        root._refreshInstalled()
    }

    // Re-check installed status after install/remove (give user time to finish)
    Timer {
        id: _refreshTimer
        interval: 5000
        onTriggered: root._refreshInstalled()
    }

    // ─── IPC ───────────────────────────────────────────────────────

    IpcHandler {
        target: "appCatalog"

        function refresh(): string {
            root.refresh()
            return "refreshing installed status"
        }

        function search(query: string): string {
            root.searchQuery = query
            return "filter set to: " + query
        }

        function install(id: string): string {
            const ok = root.installApp(id)
            return ok ? "installing " + id : "failed to install " + id
        }

        function list(): string {
            return root.catalog.map(a => {
                const installed = root.isInstalled(a.id) ? " [installed]" : ""
                return `${a.id}${installed}\t${a.name} — ${a.description}`
            }).join("\n")
        }
    }
}
