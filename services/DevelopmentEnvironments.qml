pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.models

/**
 * Searchable development environments backed by a private setup helper.
 *
 * The search consumers use this service for metadata and callbacks, while the
 * setup script remains the single source of truth for privileged operations.
 */
Singleton {
    id: root

    property list<var> environments: []
    property var statuses: ({})
    property int statusRevision: 0
    property bool loading: true
    property bool checking: false
    property bool statusReady: false

    readonly property string scriptPath: `${Directories.scriptsPath}/setup/_development.sh`

    FileView {
        id: manifestFile
        path: Qt.resolvedUrl("../defaults/dev-environments.json")
        onLoadedChanged: {
            if (!manifestFile.loaded) return
            try {
                root.environments = JSON.parse(manifestFile.text())
                root.loading = false
                root.refresh()
            } catch (error) {
                console.warn("[DevelopmentEnvironments] Failed to parse manifest:", error)
                root.environments = []
                root.loading = false
            }
        }
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            onStreamFinished: root._applyStatuses(this.text)
        }
        onExited: {
            root.checking = false
            if (!root.statusReady) {
                root.statuses = ({})
                root.statusRevision += 1
                root.statusReady = true
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 5000
        onTriggered: root.refresh()
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged(): void {
            if (GlobalStates.overviewOpen) root.refresh()
        }
    }

    function _applyStatuses(raw: string): void {
        const next = {}
        const lines = String(raw ?? "").trim().split("\n")
        for (const line of lines) {
            const parts = line.trim().split("\t")
            if (parts.length >= 2 && parts[0].length > 0)
                next[parts[0]] = parts[1]
        }
        root.statuses = next
        root.statusRevision += 1
        root.statusReady = true
    }

    function refresh(): void {
        if (root.loading || root.checking || root.environments.length === 0) return
        statusProcess.command = ["/usr/bin/bash", root.scriptPath, "status"]
        root.statusReady = false
        root.checking = true
        statusProcess.running = true
    }

    function _environment(id: string): var {
        return root.environments.find(environment => environment?.id === id) ?? null
    }

    function _safeTerminal(): string {
        const configured = (Config.options?.apps?.terminal ?? "kitty").trim()
        return /^[A-Za-z0-9._+-]+$/.test(configured) ? configured : "kitty"
    }

    function _run(operation: string, id: string): void {
        if (!_environment(id)) return

        const terminal = root._safeTerminal()
        const command = ["/usr/bin/bash", root.scriptPath, operation, id]
        if (terminal === "wezterm") {
            ShellExec.execDetachedArgs([terminal, "start", "--always-new-process", "--", ...command],
                `${operation} ${id}`)
        } else {
            ShellExec.execDetachedArgs([terminal, "-e", ...command], `${operation} ${id}`)
        }
        refreshTimer.restart()
    }

    function install(id: string): void { root._run("install", id) }
    function remove(id: string): void { root._run("remove", id) }

    function searchResults(query: string): list<var> {
        const _statusRevision = root.statusRevision
        const q = String(query ?? "").toLowerCase().trim()
        if (q.length === 0 || root.loading) return []

        const tokens = q.split(/\s+/).filter(token => token.length > 0)
        const results = []
        for (const environment of root.environments) {
            const searchable = [
                environment.id,
                environment.name,
                environment.group,
                environment.description,
                ...(environment.tags ?? []),
                "development"
            ].join(" ").toLowerCase()
            if (!tokens.every(token => searchable.includes(token))) continue

            const state = root.statuses[environment.id] ?? "unknown"
            const canMutate = root.statusReady && (state === "installed" || state === "missing")
            const installed = state === "installed"
            const operation = installed ? "remove" : "install"
            const verb = installed ? Translation.tr("Remove") : Translation.tr("Install")
            const actionName = canMutate ? `${verb} ${environment.name}` : environment.name
            const stateDescription = state === "unsupported"
                ? Translation.tr("Install/remove actions are unavailable on this system")
                : state === "unknown" && root.statusReady
                    ? Translation.tr("Installation actions are unavailable")
                    : ""
            const id = environment.id
            const result = {
                key: `development_${canMutate ? operation : "info"}_${id}`,
                id: id,
                name: actionName,
                description: `${environment.group} - ${environment.description}${stateDescription ? ` - ${stateDescription}` : ""}`,
                comment: `${Translation.tr("Development")} > ${environment.group}`,
                type: Translation.tr("Development"),
                icon: environment.icon ?? "code",
                iconName: environment.icon ?? "code",
                materialSymbol: environment.icon ?? "code",
                iconType: LauncherSearchResult.IconType.Material,
                verb: canMutate ? verb : "",
                clickActionName: canMutate ? verb : ""
            }
            if (canMutate) result.execute = () => {
                    if (operation === "remove") root.remove(id)
                    else root.install(id)
                }
            results.push(result)
        }
        return results
    }
}
