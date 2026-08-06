pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services.deferred

/**
 * Provider-neutral speech-to-text for voice search and AI dictation.
 *
 * Auto prefers a fully local whisper.cpp installation, then connected Groq,
 * Gemini and OpenAI providers. API keys are passed through the process
 * environment and never embedded in argv or generated shell scripts.
 */
Singleton {
    id: root

    property int recordDuration: Config.options?.voiceSearch?.duration ?? 8
    property string configuredProvider: Config.options?.voiceSearch?.provider ?? "auto"
    property string language: Config.options?.voiceSearch?.language ?? "auto"
    property string localModelPath: Config.options?.voiceSearch?.localModelPath ?? ""
    property string searchEngineUrl: Config.options?.search?.engineBaseUrl
        ?? "https://www.google.com/search?q="

    readonly property bool recording: recordProc.running
    readonly property bool transcribing: transcribeProc.running
    readonly property bool probing: localProbe.running
    readonly property bool running: recording || transcribing

    property bool localAvailable: false
    property string detectedLocalExecutable: ""
    property string detectedLocalModel: ""
    property string lastTranscription: ""
    property string lastError: ""
    property string _audioPath: ""
    property string _transcriptionOutput: ""
    property string _transcriptionError: ""
    property bool _pendingStart: false
    property bool _cancelRequested: false
    // "search" opens the browser; "dictate" emits transcriptionReady only.
    property string mode: "search"

    readonly property string activeProvider: root._resolveProvider()
    readonly property bool hasBackend: activeProvider !== "none"
    readonly property bool hasApiKey: hasBackend // Compatibility for existing UI.
    readonly property string backendLabel: {
        if (activeProvider === "local") return Translation.tr("Local Whisper")
        if (activeProvider === "groq") return "Groq"
        if (activeProvider === "gemini") return "Google Gemini"
        if (activeProvider === "openai") return "OpenAI"
        return Translation.tr("Not configured")
    }

    signal transcriptionReady(string text)
    signal searchReady(string url)

    function _key(provider: string): string {
        const keys = KeyringStorage.keyringData?.apiKeys ?? {}
        return keys[provider] ?? ""
    }

    function _resolveProvider(): string {
        const configured = root.configuredProvider
        if (configured === "local") return root.localAvailable ? "local" : "none"
        if (configured === "groq") return root._key("groq").length > 0 ? "groq" : "none"
        if (configured === "gemini") return root._key("gemini").length > 0 ? "gemini" : "none"
        if (configured === "openai") return root._key("openai").length > 0 ? "openai" : "none"
        if (root.localAvailable) return "local"
        if (root._key("groq").length > 0) return "groq"
        if (root._key("gemini").length > 0) return "gemini"
        if (root._key("openai").length > 0) return "openai"
        return "none"
    }

    function _providerKey(provider: string): string {
        if (provider === "groq") return root._key("groq")
        if (provider === "gemini") return root._key("gemini")
        if (provider === "openai") return root._key("openai")
        return ""
    }

    function _providerEndpoint(provider: string): string {
        if (provider === "groq") return "https://api.groq.com/openai/v1/audio/transcriptions"
        if (provider === "openai") return "https://api.openai.com/v1/audio/transcriptions"
        return ""
    }

    function _providerModel(provider: string): string {
        if (provider === "groq")
            return Config.options?.voiceSearch?.groqModel ?? "whisper-large-v3-turbo"
        if (provider === "openai")
            return Config.options?.voiceSearch?.openaiModel ?? "gpt-4o-mini-transcribe"
        if (provider === "gemini")
            return Config.options?.voiceSearch?.geminiModel ?? "gemini-2.5-flash"
        return ""
    }

    function refreshBackends(): void {
        if (!localProbe.running) localProbe.running = true
        if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData()
    }

    function startDictation(): void {
        if (root.running) return
        root.mode = "dictate"
        root._begin()
    }

    function start(): void {
        if (root.running) return
        root.mode = "search"
        root._begin()
    }

    function _begin(): void {
        if (!KeyringStorage.loaded) {
            root._pendingStart = true
            KeyringStorage.fetchKeyringData()
            return
        }
        root._doStart()
    }

    function _doStart(): void {
        if (!root.hasBackend) {
            root.lastError = Translation.tr("No speech-to-text backend is ready")
            Quickshell.execDetached([
                "/usr/bin/notify-send",
                Translation.tr("Voice input"),
                Translation.tr("Connect Groq, Gemini or OpenAI in AI Settings, or install whisper.cpp locally."),
                "-a", "Shell",
            ])
            return
        }
        root._cancelRequested = false
        root._audioPath = ""
        root.lastError = ""
        root.lastTranscription = ""
        recordProc.running = true
    }

    function stop(): void {
        root._pendingStart = false
        root._cancelRequested = root.running
        if (recordProc.running) recordProc.signal(15)
        if (transcribeProc.running) transcribeProc.signal(15)
    }

    function toggle(): void {
        if (root.running) root.stop()
        else root.start()
    }

    function _transcribe(): void {
        if (!root._audioPath || root._audioPath.length === 0) return
        if (!root.hasBackend) {
            root.lastError = Translation.tr("Speech-to-text backend became unavailable")
            return
        }
        root._transcriptionOutput = ""
        root._transcriptionError = ""
        transcribeProc.running = true
    }

    function _handleTranscription(text: string): void {
        const wasDictation = root.mode === "dictate"
        const transcription = text.trim()
        if (!transcription || transcription.length === 0) {
            root.lastError = Translation.tr("No speech detected")
            Quickshell.execDetached([
                "/usr/bin/notify-send", Translation.tr("Voice input"),
                root.lastError, "-a", "Shell",
            ])
            return
        }

        root.lastTranscription = transcription
        root.transcriptionReady(transcription)
        if (wasDictation) return

        const searchUrl = root.searchEngineUrl + encodeURIComponent(transcription)
        root.searchReady(searchUrl)
        Qt.openUrlExternally(searchUrl)
    }

    Connections {
        target: KeyringStorage
        function onLoadedChanged(): void {
            if (KeyringStorage.loaded && root._pendingStart) {
                root._pendingStart = false
                root._doStart()
            }
        }
    }

    Component.onCompleted: root.refreshBackends()
    onLocalModelPathChanged: root.refreshBackends()

    Process {
        id: localProbe
        running: false
        command: [
            "/usr/bin/python3",
            `${Directories.scriptsPath}/voiceSearch/transcribe-audio.py`,
            "--provider", "probe",
            "--local-model", root.localModelPath,
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text.trim())
                    root.localAvailable = !!data.available
                    root.detectedLocalExecutable = data.executable ?? ""
                    root.detectedLocalModel = data.model ?? ""
                } catch (error) {
                    root.localAvailable = false
                    root.detectedLocalExecutable = ""
                    root.detectedLocalModel = ""
                }
            }
        }
    }

    Process {
        id: recordProc
        running: false
        command: [
            "/usr/bin/bash",
            `${Directories.scriptsPath}/voiceSearch/record-voice.sh`,
            String(root.recordDuration),
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root._cancelRequested) {
                    root._cancelRequested = false
                    return
                }
                const path = text.trim()
                if (path && !path.startsWith("error:")) {
                    root._audioPath = path
                    root._transcribe()
                } else {
                    root.lastError = Translation.tr("Recording failed")
                    Quickshell.execDetached([
                        "/usr/bin/notify-send", Translation.tr("Voice input"),
                        root.lastError, "-a", "Shell",
                    ])
                }
            }
        }
    }

    Process {
        id: transcribeProc
        running: false
        environment: ({
            "INIR_VOICE_API_KEY": root._providerKey(root.activeProvider),
        })
        command: {
            const provider = root.activeProvider
            const command = [
                "/usr/bin/python3",
                `${Directories.scriptsPath}/voiceSearch/transcribe-audio.py`,
                "--provider", provider,
                "--audio", root._audioPath,
                "--language", root.language,
                "--model", root._providerModel(provider),
                "--endpoint", root._providerEndpoint(provider),
                "--local-model", root.localModelPath,
            ]
            return command
        }
        stdout: StdioCollector {
            onStreamFinished: root._transcriptionOutput = text
        }
        stderr: StdioCollector {
            onStreamFinished: root._transcriptionError = text.trim()
        }
        onExited: (exitCode, exitStatus) => {
            if (root._cancelRequested) {
                root._cancelRequested = false
                root._transcriptionOutput = ""
                root._transcriptionError = ""
                return
            }
            if (exitCode === 0) {
                root._handleTranscription(root._transcriptionOutput)
                return
            }
            root.lastError = root._transcriptionError.length > 0
                ? root._transcriptionError : Translation.tr("Transcription failed")
            Quickshell.execDetached([
                "/usr/bin/notify-send", Translation.tr("Voice input"),
                root.lastError, "-a", "Shell",
            ])
        }
    }

    IpcHandler {
        target: "voiceSearch"

        function start(): void { root.start() }
        function stop(): void { root.stop() }
        function toggle(): void { root.toggle() }
        function refresh(): void { root.refreshBackends() }
        function status(): string {
            return JSON.stringify({
                configuredProvider: root.configuredProvider,
                activeProvider: root.activeProvider,
                backendLabel: root.backendLabel,
                localAvailable: root.localAvailable,
                localExecutable: root.detectedLocalExecutable,
                localModel: root.detectedLocalModel,
                recording: root.recording,
                transcribing: root.transcribing,
                lastError: root.lastError,
            })
        }
    }
}
