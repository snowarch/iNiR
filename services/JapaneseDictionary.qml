pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

Singleton {
    id: root

    readonly property string backend: Quickshell.shellPath("scripts/japanese-dictionary.py")
    readonly property string installer: Quickshell.shellPath("scripts/install-japanese-dictionary.sh")
    property int dictionaryCount: 0
    property var dictionaries: []
    readonly property bool jitendexInstalled: dictionaries.some(d => String(d.title ?? "").toLowerCase().includes("jitendex"))
    property string status: ""
    property bool ankiAvailable: false
    property bool ankiInstalled: false
    property bool ankiRunning: false
    property string ankiState: "unknown"
    property string ankiConnectionStatus: Translation.tr("Checking Anki…")
    property string translationText: ""
    property string translationError: ""
    property bool translationBusy: translateProc.running
    property string studyDeckStatus: ""
    property bool deckBusy: deckProc.running
    property bool busy: importProc.running || installProc.running || listProc.running || lookupProc.running || ankiProc.running || translateProc.running || deckProc.running
    property var _pendingGeometry: ({ screen: "", x: 0, y: 0, width: 0, height: 0 })
    property string _lastLookupText: ""

    function refresh(): void {
        if (listProc.running) return
        listProc.command = ["python3", root.backend, "list"]
        listProc.running = true
    }

    function installRecommended(): void {
        if (installProc.running) return
        root.status = root.jitendexInstalled
            ? Translation.tr("Updating Jitendex…")
            : Translation.tr("Downloading Jitendex…")
        installProc.command = [root.installer]
        installProc.running = true
    }

    function importArchive(path: string): void {
        const clean = String(path ?? "").trim()
        if (!clean || importProc.running) return
        root.status = Translation.tr("Importing Japanese dictionary…")
        importProc.command = ["python3", root.backend, "import", clean]
        importProc.running = true
    }

    function lookupText(text: string, screenName: string, x: real, y: real, width: real, height: real): void {
        const clean = String(text ?? "").replace(/^\s+|\s+$/g, "")
        if (!clean || lookupProc.running) return
        root._pendingGeometry = { screen: screenName, x: x, y: y, width: width, height: height }
        root._lastLookupText = clean
        root.translationText = ""
        root.translationError = ""
        GlobalStates.japaneseLookupExpanded = false
        lookupProc.command = ["python3", root.backend, "scan-smart", clean]
        lookupProc.running = true
    }

    function checkAnki(): void {
        if (ankiCheckProc.running) return
        const cfg = Config.options?.regionSelector?.japaneseLookup?.anki ?? {}
        if (!(cfg.enabled ?? false)) {
            root.ankiAvailable = false
            root.ankiConnectionStatus = Translation.tr("Anki integration disabled")
            return
        }
        ankiCheckProc.command = ["python3", root.backend, "anki-status",
            "--endpoint", cfg.endpoint ?? "http://127.0.0.1:8765"]
        ankiCheckProc.running = true
    }

    function resolvedTranslationTarget(): string {
        const configured = String(Config.options?.regionSelector?.japaneseLookup?.translationTarget ?? "auto")
        if (configured !== "auto" && configured.length > 0) return configured
        const ui = String(Translation.languageCode ?? "en_US").toLowerCase()
        if (ui.startsWith("es")) return "es"
        return "en"
    }

    function translateCurrent(fullSelection: bool): void {
        if (translateProc.running) return
        const result = GlobalStates.japaneseLookupResult ?? {}
        const text = String(fullSelection ? (result.query ?? result.surface ?? "") : (result.surface ?? result.matched ?? result.query ?? "")).trim()
        if (!text.length) return
        root.translationText = ""
        root.translationError = ""
        translateProc.command = [Quickshell.shellPath("scripts/translate-ocr.sh"), root.resolvedTranslationTarget(), "ja", text]
        translateProc.running = true
    }

    function launchAnki(): void {
        if (ankiLaunchProc.running) return
        ankiLaunchProc.command = ["python3", root.backend, "anki-launch"]
        ankiLaunchProc.running = true
    }

    function downloadStudyDeck(deckId: string): void {
        if (deckProc.running) return
        root.studyDeckStatus = Translation.tr("Downloading study deck…")
        deckProc.command = ["python3", Quickshell.shellPath("scripts/study-decks.py"), "download", deckId]
        deckProc.running = true
    }

    function addCurrentToAnki(): void {
        const result = GlobalStates.japaneseLookupResult ?? {}
        const term = result.terms?.[0] ?? null
        if (!term || ankiProc.running) return
        if (!root.ankiAvailable) {
            root.status = Translation.tr("AnkiConnect is not available")
            return
        }
        const cfg = Config.options?.regionSelector?.japaneseLookup?.anki ?? {}
        const defs = (term.displayDefinitions ?? []).join("; ")
        ankiProc.command = ["python3", root.backend, "anki-add",
            "--endpoint", cfg.endpoint ?? "http://127.0.0.1:8765",
            "--deck", cfg.deck ?? "Default", "--model", cfg.model ?? "Basic",
            "--front-field", cfg.frontField ?? "Front", "--back-field", cfg.backField ?? "Back",
            result.matched ?? term.expression ?? "", result.reading ?? term.reading ?? "", defs]
        ankiProc.running = true
    }

    Component.onCompleted: {
        refresh()
        ankiCheckTimer.restart()
    }

    Timer {
        id: ankiCheckTimer
        interval: 10000
        repeat: true
        running: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
        triggeredOnStart: true
        onTriggered: root.checkAnki()
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.dictionaries = JSON.parse(text || "{}").dictionaries ?? []
                    root.dictionaryCount = root.dictionaries.length
                } catch (e) {
                    root.dictionaries = []
                    root.dictionaryCount = 0
                }
            }
        }
    }

    Process {
        id: installProc
        stdout: StdioCollector {
            id: installOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(installOut.text || "{}")
                    root.status = data.ok ? Translation.tr("Jitendex is ready") : (data.error ?? Translation.tr("Jitendex installation failed"))
                } catch (e) { root.status = Translation.tr("Jitendex installation failed") }
            }
        }
        onExited: (code) => {
            root.refresh()
            Quickshell.execDetached(["notify-send", code === 0 ? "Japanese dictionary" : "Japanese dictionary error", root.status, "-a", "iNiR"])
            if (code === 0 && root._lastLookupText.length > 0) {
                const g = root._pendingGeometry
                lookupRetryTimer.restart()
            }
        }
    }

    Timer {
        id: lookupRetryTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root._lastLookupText.length === 0) return
            const g = root._pendingGeometry
            root.lookupText(root._lastLookupText, g.screen, g.x, g.y, g.width, g.height)
        }
    }

    Process {
        id: importProc
        stdout: StdioCollector {
            id: importOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(importOut.text || "{}")
                    root.status = data.ok ? Translation.tr("Dictionary imported") : (data.error ?? Translation.tr("Dictionary import failed"))
                } catch (e) { root.status = Translation.tr("Dictionary import failed") }
            }
        }
        onExited: (code) => {
            root.refresh()
            Quickshell.execDetached(["notify-send", code === 0 ? "Japanese dictionary" : "Japanese dictionary error", root.status, "-a", "iNiR"])
        }
    }

    Process {
        id: lookupProc
        stdout: StdioCollector {
            id: lookupOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(lookupOut.text || "{}")
                    const g = root._pendingGeometry
                    GlobalStates.japaneseLookupResult = data
                    GlobalStates.japaneseLookupScreen = g.screen
                    GlobalStates.japaneseLookupX = g.x
                    GlobalStates.japaneseLookupY = g.y
                    GlobalStates.japaneseLookupWidth = g.width
                    GlobalStates.japaneseLookupHeight = g.height
                    GlobalStates.japaneseLookupOpen = true
                } catch (e) {
                    console.warn("[JapaneseDictionary] lookup parse failed", e)
                }
            }
        }
    }

    Process {
        id: ankiCheckProc
        stdout: StdioCollector {
            id: ankiCheckOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(ankiCheckOut.text || "{}")
                    root.ankiAvailable = data.ok === true && data.available === true
                    root.ankiInstalled = data.installed === true
                    root.ankiRunning = data.running === true
                    root.ankiState = data.state ?? "unknown"
                    if (root.ankiAvailable)
                        root.ankiConnectionStatus = Translation.tr("AnkiConnect connected")
                    else if (root.ankiState === "not_installed")
                        root.ankiConnectionStatus = Translation.tr("Anki Desktop not detected")
                    else if (root.ankiState === "app_closed")
                        root.ankiConnectionStatus = Translation.tr("Anki is closed")
                    else if (root.ankiState === "connect_unavailable")
                        root.ankiConnectionStatus = Translation.tr("Anki is open, but AnkiConnect is not listening")
                    else
                        root.ankiConnectionStatus = Translation.tr("AnkiConnect unavailable")
                } catch (e) {
                    root.ankiAvailable = false
                    root.ankiInstalled = false
                    root.ankiRunning = false
                    root.ankiState = "unknown"
                    root.ankiConnectionStatus = Translation.tr("AnkiConnect unavailable")
                }
            }
        }
        onExited: (code) => {
            if (code !== 0 && !root.ankiAvailable)
                root.ankiConnectionStatus = Translation.tr("AnkiConnect unavailable")
        }
    }

    Process {
        id: translateProc
        stdout: StdioCollector {
            id: translateOut
            onStreamFinished: root.translationText = String(translateOut.text ?? "").trim()
        }
        stderr: StdioCollector { id: translateErr }
        onExited: (code) => {
            if (code !== 0) {
                root.translationError = String(translateErr.text ?? "").trim()
                if (!root.translationError.length)
                    root.translationError = Translation.tr("Translation unavailable")
            }
        }
    }

    Process {
        id: deckProc
        stdout: StdioCollector {
            id: deckOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(deckOut.text || "{}")
                    root.studyDeckStatus = data.ok
                        ? Translation.tr("Deck downloaded; opening with the default app")
                        : (data.error ?? Translation.tr("Deck download failed"))
                    if (!data.ok && data.sourceUrl)
                        Quickshell.execDetached(["xdg-open", data.sourceUrl])
                } catch (e) {
                    root.studyDeckStatus = Translation.tr("Deck download failed")
                }
            }
        }
    }

    Process {
        id: ankiLaunchProc
        stdout: StdioCollector {
            id: ankiLaunchOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(ankiLaunchOut.text || "{}")
                    root.status = data.ok ? Translation.tr("Opening Anki…") : (data.error ?? Translation.tr("Could not open Anki"))
                } catch (e) { root.status = Translation.tr("Could not open Anki") }
            }
        }
        onExited: (code) => {
            if (code === 0) ankiRecheckTimer.restart()
        }
    }

    Timer {
        id: ankiRecheckTimer
        interval: 2500
        repeat: false
        onTriggered: root.checkAnki()
    }

    Process {
        id: ankiProc
        stdout: StdioCollector {
            id: ankiOut
            onStreamFinished: {
                try {
                    const data = JSON.parse(ankiOut.text || "{}")
                    root.status = data.ok ? Translation.tr("Added to Anki") : (data.error ?? Translation.tr("Anki request failed"))
                } catch (e) { root.status = Translation.tr("Anki request failed") }
            }
        }
        onExited: (code) => {
            if (code === 0)
                Quickshell.execDetached(["notify-send", "Anki", root.status, "-a", "iNiR"])
            else
                root.checkAnki()
        }
    }
}
