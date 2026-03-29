pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * PackageSearch — Async package manager search service.
 *
 * Searches pacman repos and AUR via yay/paru for packages matching a query.
 * Results are parsed into structured objects with name, version, repo,
 * description, and installed status.
 *
 * Usage:
 *   PackageSearch.search("vesktop")
 *   // results available in PackageSearch.results after search completes
 */
Singleton {
    id: root

    property string query: ""
    property bool searching: false
    property var results: []
    property string error: ""

    // Debounce to avoid spamming package manager
    property int debounceMs: 300

    function _safeTerminal(): string {
        const configured = (Config.options?.apps?.terminal ?? "kitty").trim()
        if (configured.length === 0)
            return "kitty"
        if (!/^[A-Za-z0-9._+-]+$/.test(configured))
            return "kitty"
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

    function isSafePackageName(name: string): bool {
        const pkg = (name ?? "").trim()
        return pkg.length > 0 && /^[A-Za-z0-9@._+-]+$/.test(pkg)
    }

    function installPackage(name: string, preferAurHelper: bool): bool {
        const pkg = (name ?? "").trim()
        if (!root.isSafePackageName(pkg)) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Install Package"),
                Translation.tr("Invalid package name"), "-a", "Shell"])
            return false
        }

        const script = preferAurHelper
            ? "if command -v yay &>/dev/null; then yay -S -- \"$1\"; elif command -v paru &>/dev/null; then paru -S -- \"$1\"; else sudo pacman -S -- \"$1\"; fi"
            : "sudo pacman -S -- \"$1\""
        root._runTerminalScript(script, [pkg])
        return true
    }

    function removePackage(name: string): bool {
        const pkg = (name ?? "").trim()
        if (!root.isSafePackageName(pkg)) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Remove Package"),
                Translation.tr("Invalid package name"), "-a", "Shell"])
            return false
        }

        root._runTerminalScript("sudo pacman -Rns -- \"$1\"", [pkg])
        return true
    }

    function updateSystem(): void {
        root._runTerminalScript("if command -v yay &>/dev/null; then yay; elif command -v paru &>/dev/null; then paru; else sudo pacman -Syu; fi", [])
    }

    function search(q: string): void {
        root.query = q.trim()
        if (root.query === "") {
            root.results = []
            root.searching = false
            root.error = ""
            _debounceTimer.stop()
            return
        }
        _debounceTimer.restart()
    }

    function clear(): void {
        root.query = ""
        root.results = []
        root.searching = false
        root.error = ""
        _debounceTimer.stop()
        _searchProc.running = false
    }

    Timer {
        id: _debounceTimer
        interval: root.debounceMs
        onTriggered: {
            if (root.query === "") return
            root.searching = true
            root.error = ""
            _stdout = ""
            _searchProc.command = ["/usr/bin/bash", "-lc",
                "if command -v yay &>/dev/null; then yay -Ss \"$1\" 2>/dev/null | head -200; elif command -v paru &>/dev/null; then paru -Ss \"$1\" 2>/dev/null | head -200; else pacman -Ss \"$1\" 2>/dev/null | head -200; fi",
                "bash", root.query
            ]
            _searchProc.running = true
        }
    }

    property string _stdout: ""

    Process {
        id: _searchProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._stdout += data }
        }
        onExited: (exitCode, exitStatus) => {
            root.searching = false
            if (exitCode !== 0 && root._stdout.trim() === "") {
                root.results = []
                return
            }
            root.results = root._parseResults(root._stdout)
        }
    }

    // Timeout for slow searches
    Timer {
        id: _timeoutTimer
        interval: 15000
        running: _searchProc.running
        onTriggered: {
            _searchProc.running = false
            root.searching = false
            root.error = "Search timed out"
        }
    }

    function _parseResults(output: string): list<var> {
        const lines = output.split("\n")
        const pkgs = []
        let i = 0
        while (i < lines.length) {
            const line = lines[i]
            // Package line format: "repo/name version [size] [installed]"
            // or AUR: "aur/name version (+votes popularity) [installed]"
            const pkgMatch = line.match(/^(\S+)\/(\S+)\s+(\S+)\s*(.*)$/)
            if (pkgMatch) {
                const repo = pkgMatch[1]
                const name = pkgMatch[2]
                const version = pkgMatch[3]
                const rest = pkgMatch[4] || ""
                const installed = /\(Installed\)/i.test(rest) || /\[installed\]/i.test(rest) || /\[Installed\]/i.test(rest)

                // Extract AUR popularity/votes if present
                const aurMeta = rest.match(/\(([+-]?\d+)\s+([\d.]+)\)/)
                const votes = aurMeta ? parseInt(aurMeta[1]) : 0
                const popularity = aurMeta ? parseFloat(aurMeta[2]) : 0

                // Next line is description (indented)
                let description = ""
                if (i + 1 < lines.length && lines[i + 1].match(/^\s+/)) {
                    description = lines[i + 1].trim()
                    i++
                }

                pkgs.push({
                    name: name,
                    version: version,
                    repo: repo,
                    description: description,
                    installed: installed,
                    votes: votes,
                    popularity: popularity,
                    isAur: repo === "aur"
                })
            }
            i++
        }
        return pkgs
    }

    // Search for installed packages only (for remove operations)
    function searchInstalled(q: string): void {
        root.query = q.trim()
        if (root.query === "") {
            root.results = []
            root.searching = false
            return
        }
        root.searching = true
        root.error = ""
        _stdout = ""
        _installedProc.command = ["/usr/bin/bash", "-lc",
            "pacman -Qs \"$1\" 2>/dev/null | head -100",
            "bash", root.query
        ]
        _installedProc.running = true
    }

    Process {
        id: _installedProc
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => { root._stdout += data }
        }
        onExited: (exitCode, exitStatus) => {
            root.searching = false
            if (exitCode !== 0 && root._stdout.trim() === "") {
                root.results = []
                return
            }
            // Parse results and mark all as installed
            const parsed = root._parseResults(root._stdout)
            root.results = parsed.map(pkg => Object.assign({}, pkg, { installed: true }))
        }
    }

    IpcHandler {
        target: "packageSearch"

        function search(query: string): string {
            root.search(query)
            return "searching: " + query
        }

        function results(): string {
            return root.results.map(p =>
                `${p.repo}/${p.name} ${p.version}${p.installed ? " [installed]" : ""}\t${p.description}`
            ).join("\n")
        }
    }
}
