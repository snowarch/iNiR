pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions as CF
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int recordDuration: Config.options?.voiceSearch?.duration ?? 8
    property string searchEngineUrl: Config.options?.search?.engineBaseUrl ?? "https://www.google.com/search?q="
    
    readonly property bool recording: recordProc.running
    readonly property bool transcribing: transcribeProc.running
    readonly property bool running: recording || transcribing
    
    property string lastTranscription: ""
    property string _audioPath: ""

    signal transcriptionReady(string text)
    signal searchReady(string url)

    function start() {
        if (root.running) return
        if (!KeyringStorage.loaded) {
            KeyringStorage.fetchKeyringData()
            root._pendingStart = true
            return
        }
        root._doStart()
    }

    property bool _pendingStart: false
    
    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (KeyringStorage.loaded && root._pendingStart) {
                root._pendingStart = false
                root._doStart()
            }
        }
    }

    function _doStart() {
        if (!root.hasApiKey) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Voice Search"), Translation.tr("Gemini API key not set"), "-a", "Shell"])
            return
        }
        root._audioPath = ""
        root.lastTranscription = ""
        recordProc.running = true
    }

    function stop() {
        if (recordProc.running) {
            recordProc.signal(15) // SIGTERM
        }
    }

    function toggle() {
        if (root.running) {
            root.stop()
        } else {
            root.start()
        }
    }

    readonly property bool hasApiKey: {
        const keys = KeyringStorage.keyringData?.apiKeys ?? {}
        const key = keys["gemini"]
        return (key?.length > 0)
    }

    Process {
        id: recordProc
        running: false
        command: ["/usr/bin/bash", `${Directories.scriptsPath}/voiceSearch/record-voice.sh`, String(root.recordDuration)]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim()
                if (path && !path.startsWith("error:")) {
                    root._audioPath = path
                    root._transcribe()
                } else {
                    Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Voice Search"), Translation.tr("Recording failed"), "-a", "Shell"])
                }
            }
        }
    }

    function _transcribe() {
        if (!root._audioPath || root._audioPath.length === 0) return
        if (!root.hasApiKey) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Voice Search"), Translation.tr("Gemini API key not set"), "-a", "Shell"])
            return
        }
        transcribeProc.running = true
    }

    Process {
        id: transcribeProc
        running: false
        command: ["/usr/bin/bash", "-c", root._buildTranscribeCommand()]
        stdout: StdioCollector {
            onStreamFinished: {
                root._handleTranscription(this.text)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Voice Search"), Translation.tr("Transcription failed"), "-a", "Shell"])
            }
        }
    }

    function _buildTranscribeCommand() {
        const apiKey = KeyringStorage.keyringData?.apiKeys?.gemini ?? ""
        const audioPath = root._audioPath
        
        return `
API_KEY='${CF.StringUtils.shellSingleQuoteEscape(apiKey)}'
AUDIO_PATH='${CF.StringUtils.shellSingleQuoteEscape(audioPath)}'
MIME_TYPE="audio/wav"
NUM_BYTES=$(wc -c < "$AUDIO_PATH")

tmp_header="/tmp/quickshell/media/voicesearch/header.tmp"
tmp_info="/tmp/quickshell/media/voicesearch/info.tmp"

curl -s "https://generativelanguage.googleapis.com/upload/v1beta/files" \\
    -H "x-goog-api-key: $API_KEY" \\
    -D "$tmp_header" \\
    -H "X-Goog-Upload-Protocol: resumable" \\
    -H "X-Goog-Upload-Command: start" \\
    -H "X-Goog-Upload-Header-Content-Length: $NUM_BYTES" \\
    -H "X-Goog-Upload-Header-Content-Type: $MIME_TYPE" \\
    -H "Content-Type: application/json" \\
    -d '{"file": {"display_name": "voice"}}' > /dev/null

upload_url=$(grep -i "x-goog-upload-url: " "$tmp_header" | cut -d" " -f2 | tr -d "\\r")

curl -s "$upload_url" \\
    -H "x-goog-api-key: $API_KEY" \\
    -H "Content-Length: $NUM_BYTES" \\
    -H "X-Goog-Upload-Offset: 0" \\
    -H "X-Goog-Upload-Command: upload, finalize" \\
    --data-binary "@$AUDIO_PATH" > "$tmp_info"

file_uri=$(jq -r ".file.uri" "$tmp_info")

curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$API_KEY" \\
    -H "Content-Type: application/json" \\
    -d '{
        "contents": [{
            "parts": [
                {"file_data": {"mime_type": "'"$MIME_TYPE"'", "file_uri": "'"$file_uri"'"}},
                {"text": "Transcribe this audio exactly. Output ONLY the transcription, nothing else. If empty or unclear, output nothing."}
            ]
        }],
        "generationConfig": {"temperature": 0}
    }' | jq -r '.candidates[0].content.parts[0].text // empty'

rm -f "$tmp_header" "$tmp_info" "$AUDIO_PATH" 2>/dev/null
`
    }

    function _handleTranscription(text) {
        const transcription = text.trim()
        if (!transcription || transcription.length === 0) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Voice Search"), Translation.tr("No speech detected"), "-a", "Shell"])
            return
        }
        
        root.lastTranscription = transcription
        root.transcriptionReady(transcription)
        
        const searchUrl = root.searchEngineUrl + encodeURIComponent(transcription)
        root.searchReady(searchUrl)
        Qt.openUrlExternally(searchUrl)
    }

    IpcHandler {
        target: "voiceSearch"

        function start(): void {
            root.start()
        }

        function stop(): void {
            root.stop()
        }

        function toggle(): void {
            root.toggle()
        }
    }
}
