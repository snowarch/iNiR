pragma Singleton

import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string query: ""
    property string _debouncedQuery: ""
    
    // Debounce timer for search - prevents lag while typing
    Timer {
        id: debounceTimer
        interval: 80  // 80ms debounce - fast enough to feel responsive
        onTriggered: root._debouncedQuery = root.query
    }
    
    onQueryChanged: {
        // Immediate update for empty query (instant clear)
        if (query === "") {
            _debouncedQuery = ""
            debounceTimer.stop()
        } else {
            debounceTimer.restart()
        }
    }

    function ensurePrefix(prefix: string): void {
        const prefixes = [
            Config.options?.search?.prefix?.action ?? ">",
            Config.options?.search?.prefix?.app ?? "/",
            Config.options?.search?.prefix?.clipboard ?? ";",
            Config.options?.search?.prefix?.emojis ?? ":",
            Config.options?.search?.prefix?.math ?? "=",
            Config.options?.search?.prefix?.shellCommand ?? "$",
            Config.options?.search?.prefix?.webSearch ?? "?",
        ]
        if (prefixes.some(p => root.query.startsWith(p))) {
            root.query = prefix + root.query.slice(1)
        } else {
            root.query = prefix + root.query
        }
    }

    property var searchActions: [
        {
            action: "accentcolor",
            execute: args => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color", ...(args !== '' ? [`${args}`] : [])])
            }
        },
        {
            action: "dark",
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "dark", "--noswitch"])
            }
        },
        {
            action: "konachanwallpaper",
            execute: () => {
                Quickshell.execDetached([Quickshell.shellPath("scripts/colors/random/random_konachan_wall.sh")])
            }
        },
        {
            action: "light", 
            execute: () => {
                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--mode", "light", "--noswitch"])
            }
        },
        {
            action: "superpaste",
            execute: args => {
                if (!/^(\d+)/.test(args.trim())) {
                    Quickshell.execDetached(["notify-send", Translation.tr("Superpaste"), 
                        Translation.tr("Usage: >superpaste NUM[i]\nExamples: >superpaste 4i (last 4 images), >superpaste 7 (last 7 entries)"), 
                        "-a", "Shell"])
                    return
                }
                const match = /^(?:(\d+)(i)?)/.exec(args.trim())
                const count = match[1] ? parseInt(match[1]) : 1
                const isImage = !!match[2]
                Cliphist.superpaste(count, isImage)
            }
        },
        {
            action: "todo",
            execute: args => {
                Todo.addTask(args)
            }
        },
        {
            action: "wallpaper",
            execute: () => {
                GlobalStates.wallpaperSelectorOpen = true
            }
        },
        {
            action: "wipeclipboard",
            execute: () => {
                Cliphist.wipe()
            }
        },
    ]

    property string mathResult: ""

    Timer {
        id: mathTimer
        interval: Config.options?.search?.nonAppResultDelay ?? 150
        onTriggered: {
            let expr = root._debouncedQuery
            const mathPrefix = Config.options?.search?.prefix?.math ?? "="
            if (expr.startsWith(mathPrefix)) {
                expr = expr.slice(mathPrefix.length)
            }
            mathProc.calculateExpression(expr)
        }
    }

    Process {
        id: mathProc
        property list<string> baseCommand: ["qalc", "-t"]
        function calculateExpression(expression: string): void {
            mathProc.running = false
            mathProc.command = baseCommand.concat(expression)
            mathProc.running = true
        }
        stdout: SplitParser {
            onRead: data => {
                root.mathResult = data
            }
        }
    }

    property list<var> results: {
        const q = root._debouncedQuery
        if (q === "") return []

        const clipboardPrefix = Config.options?.search?.prefix?.clipboard ?? ";"
        const emojisPrefix = Config.options?.search?.prefix?.emojis ?? ":"
        const mathPrefix = Config.options?.search?.prefix?.math ?? "="
        const shellPrefix = Config.options?.search?.prefix?.shellCommand ?? "$"
        const webPrefix = Config.options?.search?.prefix?.webSearch ?? "?"
        const actionPrefix = Config.options?.search?.prefix?.action ?? ">"
        const appPrefix = Config.options?.search?.prefix?.app ?? "/"

        // Clipboard search
        if (q.startsWith(clipboardPrefix)) {
            const searchStr = StringUtils.cleanPrefix(q, clipboardPrefix)
            return Cliphist.fuzzyQuery(searchStr).map(entry => {
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: StringUtils.cleanCliphistEntry(entry),
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Clipboard"),
                    iconName: "content_copy",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => Cliphist.copy(entry)
                })
            }).filter(Boolean)
        }

        // Emoji search
        if (q.startsWith(emojisPrefix)) {
            const searchStr = StringUtils.cleanPrefix(q, emojisPrefix)
            return Emojis.fuzzyQuery(searchStr).map(entry => {
                const emoji = entry.match(/^\s*(\S+)/)?.[1] ?? ""
                return resultComp.createObject(null, {
                    rawValue: entry,
                    name: entry.replace(/^\s*\S+\s+/, ""),
                    iconName: emoji,
                    iconType: LauncherSearchResult.IconType.Text,
                    verb: Translation.tr("Copy"),
                    type: Translation.tr("Emoji"),
                    execute: () => { Quickshell.clipboardText = emoji }
                })
            }).filter(Boolean)
        }

        // Start math calculation
        mathTimer.restart()

        // Build results
        let result = []
        const startsWithNumber = /^\d/.test(q)
        const startsWithMath = q.startsWith(mathPrefix)
        const startsWithShell = q.startsWith(shellPrefix)
        const startsWithWeb = q.startsWith(webPrefix)

        // Math result (priority if starts with number or =)
        const mathObj = resultComp.createObject(null, {
            name: root.mathResult,
            verb: Translation.tr("Copy"),
            type: Translation.tr("Math"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: "calculate",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => { Quickshell.clipboardText = root.mathResult }
        })

        if (startsWithNumber || startsWithMath) {
            result.push(mathObj)
        }

        // Shell command
        const cmdObj = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(q, shellPrefix).replace("file://", ""),
            verb: Translation.tr("Run"),
            type: Translation.tr("Command"),
            fontType: LauncherSearchResult.FontType.Monospace,
            iconName: "terminal",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                let cmd = q.replace("file://", "")
                cmd = StringUtils.cleanPrefix(cmd, shellPrefix)
                Quickshell.execDetached(["bash", "-c", cmd])
            }
        })

        if (startsWithShell) {
            result.push(cmdObj)
        }

        // Web search
        const webObj = resultComp.createObject(null, {
            name: StringUtils.cleanPrefix(q, webPrefix),
            verb: Translation.tr("Search"),
            type: Translation.tr("Web"),
            iconName: "travel_explore",
            iconType: LauncherSearchResult.IconType.Material,
            execute: () => {
                const searchQuery = StringUtils.cleanPrefix(q, webPrefix)
                const baseUrl = Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q="
                Qt.openUrlExternally(baseUrl + encodeURIComponent(searchQuery))
            }
        })

        if (startsWithWeb) {
            result.push(webObj)
        }

        // Apps
        const appResults = AppSearch.fuzzyQuery(StringUtils.cleanPrefix(q, appPrefix)).map(entry => {
            return resultComp.createObject(null, {
                type: Translation.tr("App"),
                id: entry.id ?? entry.name ?? "",
                name: entry.name,
                iconName: entry.icon,
                iconType: LauncherSearchResult.IconType.System,
                verb: Translation.tr("Launch"),
                comment: entry.comment ?? "",
                runInTerminal: entry.runInTerminal ?? false,
                genericName: entry.genericName ?? "",
                execute: () => {
                    if (!entry.runInTerminal) {
                        entry.execute()
                    } else {
                        const terminal = Config.options?.apps?.terminal ?? "foot"
                        Quickshell.execDetached(["bash", "-c", `${terminal} -e '${entry.command?.join(" ") ?? ""}'`])
                    }
                }
            })
        })
        result = result.concat(appResults)

        // Actions
        const actionResults = root.searchActions.map(action => {
            const actionStr = `${actionPrefix}${action.action}`
            if (actionStr.startsWith(q) || q.startsWith(actionStr)) {
                return resultComp.createObject(null, {
                    name: q.startsWith(actionStr) ? q : actionStr,
                    verb: Translation.tr("Run"),
                    type: Translation.tr("Action"),
                    iconName: "settings_suggest",
                    iconType: LauncherSearchResult.IconType.Material,
                    execute: () => action.execute(q.split(" ").slice(1).join(" "))
                })
            }
            return null
        }).filter(Boolean)
        result = result.concat(actionResults)

        // Add fallbacks if not prefix-specific
        const showDefaults = Config.options?.search?.prefix?.showDefaultActionsWithoutPrefix ?? true
        if (showDefaults) {
            if (!startsWithShell) result.push(cmdObj)
            if (!startsWithNumber && !startsWithMath) result.push(mathObj)
            if (!startsWithWeb) result.push(webObj)
        }

        return result
    }

    Component {
        id: resultComp
        LauncherSearchResult {}
    }
}
