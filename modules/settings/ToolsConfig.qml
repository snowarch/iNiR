import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 6
    settingsPageName: Translation.tr("Tools")
    property string activeSection: "recording"

    SettingsTaskNavigator {
        icon: "build"
        title: Translation.tr("Tools")
        description: Translation.tr("Configure capture, OCR and utility tools without mixing unrelated controls.")
        summary: Translation.tr("Recording · snipping & OCR · crosshair · Discord · OSD")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Recording"), icon: "screen_record", value: "recording" },
            { displayName: Translation.tr("Snipping"), icon: "screenshot_frame_2", value: "snipping" },
            { displayName: Translation.tr("Crosshair"), icon: "point_scan", value: "crosshair" },
            { displayName: Translation.tr("Discord"), icon: "forum", value: "discord" },
            { displayName: Translation.tr("OSD"), icon: "voting_chip", value: "osd" }
        ]
    }

    property bool recordingCapabilitiesLoaded: false
    property var detectedVideoCodecs: []
    property var detectedAudioCodecs: []
    property var detectedAudioSources: []
    property var detectedHardwareDevices: []
    property string detectedDefaultSink: ""
    property string detectedDefaultSource: ""
    property bool audioMixAvailable: false
    property string captureFolderTarget: "recordings"
    property bool showAdvancedOcr: false
    property bool showAdvancedJapanese: false
    property bool showAdvancedAnki: false

    readonly property string recordingAudioMode: RecorderStatus.configuredAudioMode
    readonly property string effectiveRecordingPath: {
        const configured = String(Config.getNestedValue("screenRecord.savePath", ""))
        return configured.length > 0 ? configured : Directories.videosPath
    }
    readonly property string effectiveScreenshotPath: Directories.screenshotsPath
    readonly property string detectedDefaultAudioSource: detectedDefaultSink.length > 0 ? `${detectedDefaultSink}.monitor` : ""
    readonly property var ocrLanguageOptions: [
        { value: "auto", displayName: Translation.tr("Auto (system language)") },
        { value: "eng", displayName: Translation.tr("English") },
        { value: "spa", displayName: Translation.tr("Spanish") },
        { value: "rus", displayName: Translation.tr("Russian") },
        { value: "jpn", displayName: Translation.tr("Japanese") },
        { value: "jpn_vert", displayName: Translation.tr("Japanese (vertical)") },
        { value: "chi_sim", displayName: Translation.tr("Chinese (Simplified)") },
        { value: "chi_sim_vert", displayName: Translation.tr("Chinese (Simplified, vertical)") },
        { value: "chi_tra", displayName: Translation.tr("Chinese (Traditional)") },
        { value: "chi_tra_vert", displayName: Translation.tr("Chinese (Traditional, vertical)") },
        { value: "eng+spa", displayName: Translation.tr("English + Spanish") },
        { value: "jpn+eng", displayName: Translation.tr("Japanese + English") }
    ]

    readonly property var ocrTranslationTargetOptions: [
        { value: "auto", displayName: Translation.tr("Auto (UI/system language)") },
        { value: "en", displayName: Translation.tr("English") },
        { value: "es", displayName: Translation.tr("Spanish") }
    ]

    readonly property var recordingAudioModeOptions: [
        { value: "none", displayName: Translation.tr("No audio") },
        { value: "system", displayName: Translation.tr("System audio") },
        { value: "microphone", displayName: Translation.tr("Microphone") },
        { value: "both", displayName: Translation.tr("System + microphone") }
    ]

    function openCaptureFolderDialog(target: string): void {
        root.captureFolderTarget = target
        captureFolderDialog.open()
    }

    FolderDialog {
        id: captureFolderDialog
        title: root.captureFolderTarget === "screenshots"
            ? Translation.tr("Select screenshots folder")
            : Translation.tr("Select recordings folder")
        currentFolder: `file://${root.captureFolderTarget === "screenshots"
            ? root.effectiveScreenshotPath : root.effectiveRecordingPath}`
        onAccepted: {
            const path = FileUtils.trimFileProtocol(String(selectedFolder))
            Config.setNestedValue(root.captureFolderTarget === "screenshots"
                ? "regionSelector.savePath" : "screenRecord.savePath", path)
        }
    }

    SettingsNativeDialogGuard {
        dialog: captureFolderDialog
        dialogKey: "tools-capture-folder"
    }

    FileDialog {
        id: japaneseDictionaryDialog
        title: Translation.tr("Import Yomitan Japanese dictionary")
        fileMode: FileDialog.OpenFile
        nameFilters: [Translation.tr("Yomitan dictionaries") + " (*.zip)", Translation.tr("All files") + " (*)"]
        onAccepted: JapaneseDictionary.importArchive(FileUtils.trimFileProtocol(String(selectedFile)))
    }

    SettingsNativeDialogGuard {
        dialog: japaneseDictionaryDialog
        dialogKey: "tools-japanese-dictionary"
    }
    readonly property bool vaapiRecordingAvailable: detectedVideoCodecs.some(codec => String(codec).indexOf("_vaapi") !== -1)
    readonly property bool nvencRecordingAvailable: detectedVideoCodecs.some(codec => String(codec).indexOf("_nvenc") !== -1)
    readonly property bool gpuRecordingAvailable: vaapiRecordingAvailable || nvencRecordingAvailable
    readonly property var recordingQualityPresetOptions: [
        { value: "compact", displayName: Translation.tr("Compact") },
        { value: "balanced", displayName: Translation.tr("Balanced") },
        { value: "quality", displayName: Translation.tr("Quality") },
        { value: "master", displayName: Translation.tr("Master") },
        { value: "custom", displayName: Translation.tr("Custom") }
    ]
    readonly property var recordingAccelerationOptions: gpuRecordingAvailable
        ? [
            { value: "auto", displayName: Translation.tr("Auto") },
            { value: "gpu", displayName: Translation.tr("Prefer GPU") },
            { value: "software", displayName: Translation.tr("Software only") }
        ]
        : [
            { value: "auto", displayName: Translation.tr("Auto") },
            { value: "software", displayName: Translation.tr("Software only") }
        ]
    readonly property var recordingFpsOptions: [24, 30, 45, 60, 90, 120, 144].map(value => ({ value: value, displayName: `${value} FPS` }))
    readonly property var recordingVideoBitrateOptions: [4000, 6000, 8000, 10000, 12000, 16000, 20000, 28000].map(value => ({ value: value, displayName: `${value} kbps` }))
    readonly property var recordingAudioBitrateOptions: [96, 128, 160, 192, 256, 320].map(value => ({ value: value, displayName: `${value} kbps` }))
    readonly property var recordingSampleRateOptions: [32000, 44100, 48000, 96000].map(value => ({ value: value, displayName: `${value} Hz` }))
    readonly property var recordingSoftwarePresetOptions: ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"].map(value => ({ value: value, displayName: value }))
    readonly property var recordingPixelFormatOptions: [
        { value: "yuv420p", displayName: Translation.tr("yuv420p — smaller files") },
        { value: "yuv444p", displayName: Translation.tr("yuv444p — sharper text, bigger files") }
    ]
    readonly property var recordingCrfOptions: [14, 18, 21, 23, 26, 28, 30, 35].map(value => ({ value: value, displayName: `CRF ${value}` }))
    readonly property var recordingDiscordTargetSizeOptions: [
        { value: 8, displayName: Translation.tr("8 MB") },
        { value: 10, displayName: Translation.tr("10 MB") },
        { value: 25, displayName: Translation.tr("25 MB") },
        { value: 50, displayName: Translation.tr("50 MB") }
    ]
    readonly property var recordingDiscordDimensionOptions: [540, 720, 960, 1280, 1440, 1920].map(value => ({ value: value, displayName: `${value}px` }))
    readonly property var recordingAudioBackendOptions: [
        { value: "", displayName: Translation.tr("Auto") },
        { value: "pipewire", displayName: "PipeWire" },
        { value: "pulse", displayName: "PulseAudio" }
    ]
    readonly property var recordingVaapiFilterOptions: [
        { value: "scale_vaapi=format=nv12:out_range=full", displayName: Translation.tr("Full range — recommended") },
        { value: "scale_vaapi=format=nv12", displayName: Translation.tr("Limited range") },
        { value: "", displayName: Translation.tr("No VAAPI filter") }
    ]

    function setRecordingConfig(path, value) {
        Config.setNestedValue(path, value)
        if (path !== "screenRecord.qualityPreset" && (Config.options?.screenRecord?.qualityPreset ?? "balanced") !== "custom")
            Config.setNestedValue("screenRecord.qualityPreset", "custom")
    }

    function choiceIndex(options, value) {
        for (let i = 0; i < options.length; ++i) {
            if (options[i].value === value)
                return i
        }
        return options.length > 0 ? 0 : -1
    }

    function ensureOption(options, value, displayName) {
        const normalized = String(value ?? "")
        const result = Array.isArray(options) ? options.slice() : []
        if (normalized.length === 0)
            return result
        if (!result.some(option => String(option.value) === normalized))
            result.push({ value: value, displayName: displayName })
        return result
    }

    function videoCodecDisplayName(codec) {
        switch (codec) {
        case "h264_vaapi": return Translation.tr("H.264 (GPU / VAAPI)")
        case "hevc_vaapi": return Translation.tr("H.265 / HEVC (GPU / VAAPI)")
        case "vp9_vaapi": return Translation.tr("VP9 (GPU / VAAPI)")
        case "av1_vaapi": return Translation.tr("AV1 (GPU / VAAPI)")
        case "h264_nvenc": return Translation.tr("H.264 (GPU / NVENC)")
        case "hevc_nvenc": return Translation.tr("H.265 / HEVC (GPU / NVENC)")
        case "av1_nvenc": return Translation.tr("AV1 (GPU / NVENC)")
        case "libx264": return Translation.tr("H.264 (software)")
        case "libx265": return Translation.tr("H.265 / HEVC (software)")
        default: return codec
        }
    }

    function audioCodecDisplayName(codec) {
        switch (codec) {
        case "aac": return Translation.tr("AAC")
        case "libopus": return Translation.tr("Libopus")
        case "opus": return Translation.tr("Opus")
        default: return codec
        }
    }

    function systemAudioSourceDisplayName(source) {
        if (source === "")
            return detectedDefaultAudioSource.length > 0
                ? `${Translation.tr("Default output monitor")} (${detectedDefaultAudioSource})`
                : Translation.tr("Default output monitor")
        if (source === detectedDefaultAudioSource)
            return `${Translation.tr("Default output monitor")} (${source})`
        return `${Translation.tr("Output monitor")} (${source})`
    }

    function microphoneSourceDisplayName(source) {
        if (source === "")
            return detectedDefaultSource.length > 0
                ? `${Translation.tr("Default microphone")} (${detectedDefaultSource})`
                : Translation.tr("Default microphone")
        if (source === detectedDefaultSource)
            return `${Translation.tr("Default microphone")} (${source})`
        return source
    }

    function hardwareDeviceDisplayName(device) {
        return device === "/dev/dri/renderD128"
            ? `${Translation.tr("Primary render device")} (${device})`
            : device
    }

    function updateRecordingCapabilities(payloadText) {
        try {
            const payload = JSON.parse((payloadText ?? "").trim() || "{}")
            detectedVideoCodecs = payload.videoCodecs ?? []
            detectedAudioCodecs = payload.audioCodecs ?? []
            detectedAudioSources = payload.audioSources ?? []
            detectedHardwareDevices = payload.hardwareDevices ?? []
            detectedDefaultSink = payload.defaultSink ?? ""
            detectedDefaultSource = payload.defaultSource ?? ""
            audioMixAvailable = payload.audioMixAvailable ?? false
        } catch (e) {
            detectedVideoCodecs = []
            detectedAudioCodecs = []
            detectedAudioSources = []
            detectedHardwareDevices = []
            detectedDefaultSink = ""
            detectedDefaultSource = ""
            audioMixAvailable = false
        }
        recordingCapabilitiesLoaded = true
    }

    function availableVideoCodecOptions() {
        let options = detectedVideoCodecs.map(codec => ({ value: codec, displayName: videoCodecDisplayName(codec) }))
        options = ensureOption(options, Config.options?.screenRecord?.videoCodec ?? "libx264", `${Translation.tr("Configured")}: ${Config.options?.screenRecord?.videoCodec ?? "libx264"}`)
        return options
    }

    function availableAudioCodecOptions() {
        let options = detectedAudioCodecs.map(codec => ({ value: codec, displayName: audioCodecDisplayName(codec) }))
        options = ensureOption(options, Config.options?.screenRecord?.audioCodec ?? "aac", `${Translation.tr("Configured")}: ${Config.options?.screenRecord?.audioCodec ?? "aac"}`)
        return options
    }

    function availableSystemAudioSourceOptions() {
        let options = [{ value: "", displayName: systemAudioSourceDisplayName("") }]
        options = options.concat(detectedAudioSources
            .filter(source => String(source).endsWith(".monitor"))
            .map(source => ({ value: source, displayName: systemAudioSourceDisplayName(source) })))
        const configured = RecorderStatus.configuredSystemAudioSource
        options = ensureOption(options, configured, `${Translation.tr("Configured source")}: ${configured}`)
        return options
    }

    function availableMicrophoneSourceOptions() {
        let options = [{ value: "", displayName: microphoneSourceDisplayName("") }]
        options = options.concat(detectedAudioSources
            .filter(source => !String(source).endsWith(".monitor"))
            .map(source => ({ value: source, displayName: microphoneSourceDisplayName(source) })))
        const configured = RecorderStatus.configuredMicrophoneSource
        options = ensureOption(options, configured, `${Translation.tr("Configured source")}: ${configured}`)
        return options
    }

    function availableHardwareDeviceOptions() {
        let options = detectedHardwareDevices.map(device => ({ value: device, displayName: hardwareDeviceDisplayName(device) }))
        options = ensureOption(options, Config.options?.screenRecord?.hardwareDevice ?? "/dev/dri/renderD128", `${Translation.tr("Configured device")}: ${Config.options?.screenRecord?.hardwareDevice ?? "/dev/dri/renderD128"}`)
        return options
    }

    component RecordingDropdownField: ColumnLayout {
        id: field
        required property string title
        required property string description
        required property var options
        required property var currentValue
        property bool fieldEnabled: true
        signal selected(var newValue)

        Layout.fillWidth: true
        spacing: 4

        StyledText {
            Layout.fillWidth: true
            text: field.title
        }

        StyledText {
            Layout.fillWidth: true
            visible: field.description.length > 0
            text: field.description
            color: Appearance.angelEverywhere ? Appearance.angel.colTextMuted
                : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
            wrapMode: Text.WordWrap
        }

        StyledComboBox {
            Layout.fillWidth: true
            enabled: field.fieldEnabled
            model: field.options
            textRole: "displayName"
            currentIndex: root.choiceIndex(field.options, field.currentValue)
            onActivated: index => {
                if (index >= 0 && index < field.options.length)
                    field.selected(field.options[index].value)
            }
        }
    }

    Process {
        id: recordingCapabilityProbe
        running: true
        command: [Directories.recordScriptPath, "--probe-capabilities"]
        stdout: StdioCollector {
            id: recordingCapabilityCollector
            onStreamFinished: root.updateRecordingCapabilities(recordingCapabilityCollector.text)
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && !root.recordingCapabilitiesLoaded)
                root.recordingCapabilitiesLoaded = true
        }
    }

    function applyRecordingPreset(preset) {
        Config.setNestedValue("screenRecord.qualityPreset", preset)
        switch (preset) {
        case "compact":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 30)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 6000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 128)
            Config.setNestedValue("screenRecord.audioSampleRate", 48000)
            Config.setNestedValue("screenRecord.pixelFormat", "yuv420p")
            Config.setNestedValue("screenRecord.preset", "veryfast")
            Config.setNestedValue("screenRecord.crf", 28)
            break
        case "balanced":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 10000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 160)
            Config.setNestedValue("screenRecord.audioSampleRate", 48000)
            Config.setNestedValue("screenRecord.pixelFormat", "yuv420p")
            Config.setNestedValue("screenRecord.preset", "veryfast")
            Config.setNestedValue("screenRecord.crf", 23)
            break
        case "quality":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 16000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 192)
            Config.setNestedValue("screenRecord.audioSampleRate", 48000)
            Config.setNestedValue("screenRecord.pixelFormat", "yuv420p")
            Config.setNestedValue("screenRecord.preset", "medium")
            Config.setNestedValue("screenRecord.crf", 18)
            break
        case "master":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 28000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 256)
            Config.setNestedValue("screenRecord.audioSampleRate", 48000)
            Config.setNestedValue("screenRecord.pixelFormat", "yuv420p")
            Config.setNestedValue("screenRecord.preset", "slow")
            Config.setNestedValue("screenRecord.crf", 14)
            break
        }
    }

    SettingsCardSection {
        id: screenRecordSection
        settingsTaskSection: "recording"
        visible: root.activeSection === "recording"
        expanded: true
        icon: "screen_record"
        title: Translation.tr("Screen recording")

        readonly property bool isCustomPreset: (Config.options?.screenRecord?.qualityPreset ?? "balanced") === "custom"

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "pip"
                text: Translation.tr("Show recording overlay")
                checked: Config.options?.screenRecord?.showOsd ?? false
                onCheckedChanged: {
                    Config.setNestedValue("screenRecord.showOsd", checked)
                    let panels = [...(Config.options?.enabledPanels ?? [])]
                    const idx = panels.indexOf("iiRecordingOsd")
                    if (checked && idx === -1) {
                        panels.push("iiRecordingOsd")
                        Config.setNestedValue("enabledPanels", panels)
                    } else if (!checked && idx !== -1) {
                        panels.splice(idx, 1)
                        Config.setNestedValue("enabledPanels", panels)
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "mouse"
                text: Translation.tr("Auto-hide recording OSD")
                checked: Config.options?.screenRecord?.recordingOsd?.autoHide ?? false
                onCheckedChanged: Config.setNestedValue("screenRecord.recordingOsd.autoHide", checked)
            }

            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Recording notifications")
                checked: Config.options?.screenRecord?.showNotifications ?? true
                onCheckedChanged: Config.setNestedValue("screenRecord.showNotifications", checked)
            }

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: recordingCapabilitiesLoaded ? (gpuRecordingAvailable ? "memory" : "developer_board") : "progress_activity"
                text: !recordingCapabilitiesLoaded
                    ? Translation.tr("Detecting available encoders…")
                    : gpuRecordingAvailable
                        ? Translation.tr("GPU recording available. Hardware acceleration will be used when possible.")
                        : Translation.tr("No GPU encoder detected. Software recording will be used.")
            }

            ContentSubsection {
                title: Translation.tr("Recording folder")

                StyledText {
                    Layout.fillWidth: true
                    text: Directories.shortHomePath(root.effectiveRecordingPath)
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.sizes.spacingSmall

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "folder_open"
                        mainText: Translation.tr("Open folder")
                        onClicked: ShellExec.openDirectory(root.effectiveRecordingPath, Translation.tr("Open recordings folder"))
                    }

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "drive_file_move"
                        mainText: Translation.tr("Change folder")
                        onClicked: root.openCaptureFolderDialog("recordings")
                    }
                }
            }

            ConfigRow {
                uniform: true

                RecordingDropdownField {
                    title: Translation.tr("Quality preset")
                    description: Translation.tr("Tradeoff between file size and quality.")
                    options: root.recordingQualityPresetOptions
                    currentValue: Config.options?.screenRecord?.qualityPreset ?? "balanced"
                    onSelected: newValue => {
                        if (newValue === "custom")
                            Config.setNestedValue("screenRecord.qualityPreset", "custom")
                        else
                            root.applyRecordingPreset(newValue)
                    }
                }

                RecordingDropdownField {
                    title: Translation.tr("Acceleration")
                    description: Translation.tr("Auto picks the best path for your hardware.")
                    options: root.recordingAccelerationOptions
                    currentValue: Config.options?.screenRecord?.accelerationMode ?? "auto"
                    onSelected: newValue => root.setRecordingConfig("screenRecord.accelerationMode", newValue)
                }
            }

            SettingsSwitch {
                buttonIcon: "swap_horiz"
                text: Translation.tr("Fallback to safe mode if preferred encoder fails")
                checked: Config.options?.screenRecord?.enableFallback ?? true
                onCheckedChanged: root.setRecordingConfig("screenRecord.enableFallback", checked)
            }

            ContentSubsection {
                title: Translation.tr("Audio capture")

                RecordingDropdownField {
                    title: Translation.tr("Recording audio")
                    description: Translation.tr("Choose whether recordings include system audio, microphone, both, or no audio.")
                    options: root.recordingAudioModeOptions
                    currentValue: root.recordingAudioMode
                    onSelected: newValue => RecorderStatus.setConfiguredAudioMode(newValue)
                }

                NoticeBox {
                    Layout.fillWidth: true
                    visible: root.recordingAudioMode === "both"
                    materialIcon: root.audioMixAvailable ? "instant_mix" : "warning"
                    text: root.audioMixAvailable
                        ? Translation.tr("iNiR combines system audio and microphone automatically. The temporary audio route is removed when recording ends.")
                        : Translation.tr("System and microphone audio cannot be combined on this setup. Recording will continue with whichever source is available.")
                }

                RecordingDropdownField {
                    visible: root.recordingAudioMode === "system" || root.recordingAudioMode === "both"
                    title: Translation.tr("System audio source")
                    description: Translation.tr("Auto follows the current default output device.")
                    options: root.availableSystemAudioSourceOptions()
                    currentValue: RecorderStatus.configuredSystemAudioSource
                    onSelected: newValue => RecorderStatus.setConfiguredSystemAudioSource(newValue)
                }

                RecordingDropdownField {
                    visible: root.recordingAudioMode === "microphone" || root.recordingAudioMode === "both"
                    title: Translation.tr("Microphone source")
                    description: Translation.tr("Auto follows the current default microphone.")
                    options: root.availableMicrophoneSourceOptions()
                    currentValue: RecorderStatus.configuredMicrophoneSource
                    onSelected: newValue => RecorderStatus.setConfiguredMicrophoneSource(newValue)
                }
            }

            ContentSubsection {
                title: Translation.tr("Discord compression")

                SettingsSwitch {
                    buttonIcon: "compress"
                    text: Translation.tr("Compress recordings for Discord")
                    checked: Config.options?.screenRecord?.discordCompress?.enabled ?? false
                    onCheckedChanged: Config.setNestedValue("screenRecord.discordCompress.enabled", checked)
                    StyledToolTip {
                        text: Translation.tr("Creates a separate Discord-ready copy after recording")
                    }
                }

                NoticeBox {
                    visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
                    Layout.fillWidth: true
                    materialIcon: "info"
                    text: Translation.tr("Uses two-pass H.264 compression and keeps the original recording untouched. Your CPU gets exercise, not a demolition derby.")
                }

                ConfigRow {
                    visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Target size")
                        description: Translation.tr("10 MB fits Discord Free. A safety margin is applied automatically.")
                        options: root.recordingDiscordTargetSizeOptions
                        currentValue: Config.options?.screenRecord?.discordCompress?.targetSizeMb ?? 10
                        onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.targetSizeMb", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Max dimension")
                        description: Translation.tr("Lower values help long clips fit without turning into soup.")
                        options: root.recordingDiscordDimensionOptions
                        currentValue: Config.options?.screenRecord?.discordCompress?.maxDimension ?? 1280
                        onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.maxDimension", newValue)
                    }
                }

                ConfigRow {
                    visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Encoder speed")
                        description: Translation.tr("Slower is smaller and cleaner, because physics remains annoying.")
                        options: root.recordingSoftwarePresetOptions
                        currentValue: Config.options?.screenRecord?.discordCompress?.preset ?? "slow"
                        onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.preset", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Audio bitrate")
                        description: Translation.tr("Automatically reduced if the clip needs more video budget.")
                        options: root.recordingAudioBitrateOptions
                        currentValue: Config.options?.screenRecord?.discordCompress?.audioBitrateKbps ?? 96
                        onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.audioBitrateKbps", newValue)
                    }
                }

                SettingsSwitch {
                    visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
                    buttonIcon: "done_all"
                    text: Translation.tr("Skip compression when already under target")
                    checked: Config.options?.screenRecord?.discordCompress?.onlyIfNeeded ?? true
                    onCheckedChanged: Config.setNestedValue("screenRecord.discordCompress.onlyIfNeeded", checked)
                }
            }

            ContentSubsection {
                visible: screenRecordSection.isCustomPreset
                title: Translation.tr("Video")

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Codec")
                        description: ""
                        options: root.availableVideoCodecOptions()
                        currentValue: Config.options?.screenRecord?.videoCodec ?? "libx264"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.videoCodec", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Frame rate")
                        description: ""
                        options: root.recordingFpsOptions
                        currentValue: Config.options?.screenRecord?.fps ?? 60
                        onSelected: newValue => root.setRecordingConfig("screenRecord.fps", newValue)
                    }
                }

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Bitrate")
                        description: Translation.tr("Higher = better quality, bigger file.")
                        options: root.recordingVideoBitrateOptions
                        currentValue: Config.options?.screenRecord?.videoBitrateKbps ?? 12000
                        onSelected: newValue => root.setRecordingConfig("screenRecord.videoBitrateKbps", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("CRF")
                        description: Translation.tr("Lower = better quality. Software mode only.")
                        options: root.recordingCrfOptions
                        currentValue: Config.options?.screenRecord?.crf ?? 21
                        onSelected: newValue => root.setRecordingConfig("screenRecord.crf", newValue)
                    }
                }

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Encoder speed")
                        description: Translation.tr("Software mode only.")
                        options: root.recordingSoftwarePresetOptions
                        currentValue: Config.options?.screenRecord?.preset ?? "veryfast"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.preset", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Pixel format")
                        description: ""
                        options: root.recordingPixelFormatOptions
                        currentValue: Config.options?.screenRecord?.pixelFormat ?? "yuv420p"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.pixelFormat", newValue)
                    }
                }
            }

            ContentSubsection {
                visible: screenRecordSection.isCustomPreset
                title: Translation.tr("Audio encoding")

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Codec")
                        description: ""
                        options: root.availableAudioCodecOptions()
                        currentValue: Config.options?.screenRecord?.audioCodec ?? "aac"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.audioCodec", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Bitrate")
                        description: ""
                        options: root.recordingAudioBitrateOptions
                        currentValue: Config.options?.screenRecord?.audioBitrateKbps ?? 192
                        onSelected: newValue => root.setRecordingConfig("screenRecord.audioBitrateKbps", newValue)
                    }
                }

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Sample rate")
                        description: ""
                        options: root.recordingSampleRateOptions
                        currentValue: Config.options?.screenRecord?.audioSampleRate ?? 48000
                        onSelected: newValue => root.setRecordingConfig("screenRecord.audioSampleRate", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("Backend")
                        description: ""
                        options: root.recordingAudioBackendOptions
                        currentValue: Config.options?.screenRecord?.audioBackend ?? ""
                        onSelected: newValue => root.setRecordingConfig("screenRecord.audioBackend", newValue)
                    }
                }
            }

            ContentSubsection {
                visible: screenRecordSection.isCustomPreset && root.vaapiRecordingAvailable
                title: Translation.tr("VAAPI hardware")

                ConfigRow {
                    uniform: true

                    RecordingDropdownField {
                        title: Translation.tr("Render device")
                        description: ""
                        options: root.availableHardwareDeviceOptions()
                        currentValue: Config.options?.screenRecord?.hardwareDevice ?? "/dev/dri/renderD128"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.hardwareDevice", newValue)
                    }

                    RecordingDropdownField {
                        title: Translation.tr("VAAPI filter")
                        description: ""
                        options: root.ensureOption(root.recordingVaapiFilterOptions, Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full", `${Translation.tr("Configured filter")}: ${Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full"}`)
                        currentValue: Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full"
                        onSelected: newValue => root.setRecordingConfig("screenRecord.vaapiFilter", newValue)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("File naming")

                ContentSubsectionLabel {
                    text: Translation.tr("Recording filename format (date tokens)")
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "recording_%Y-%m-%d_%H.%M.%S"
                    text: Config.options?.screenRecord?.recordingNameFormat ?? "recording_%Y-%m-%d_%H.%M.%S"
                    onEditingFinished: Config.setNestedValue("screenRecord.recordingNameFormat", text)
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "snipping"
        visible: root.activeSection === "snipping"
        expanded: true
        icon: "screenshot_frame_2"
        title: Translation.tr("Snipping & OCR")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Snip behavior")

                SettingsSwitch {
                    buttonIcon: "history"
                    text: Translation.tr("Remember last snip choice")
                    checked: Config.options?.regionSelector?.rememberSnipChoice ?? true
                    onCheckedChanged: Config.setNestedValue("regionSelector.rememberSnipChoice", checked)
                    StyledToolTip {
                        text: Translation.tr("Super+Shift+S reopens the unified snip menu with the action and shape last picked in its toolbar. Explicit OCR/search actions still force their requested tool. Recording is never remembered. When off, Super+Shift+S opens as a rectangle screenshot.")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Text recognition (OCR)")

                RecordingDropdownField {
                    title: Translation.tr("Text language")
                    description: Translation.tr("Pick the language you expect to capture. Auto follows the system language. Use the vertical Japanese/Chinese choices for vertical writing.")
                    readonly property string configuredLanguage: Config.options?.regionSelector?.ocrLanguage ?? "auto"
                    options: root.ensureOption(root.ocrLanguageOptions, configuredLanguage,
                        `${Translation.tr("Custom")}: ${configuredLanguage}`)
                    currentValue: configuredLanguage
                    onSelected: newValue => Config.setNestedValue("regionSelector.ocrLanguage", newValue)
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: ocrHelpRow.implicitHeight + 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    RowLayout {
                        id: ocrHelpRow
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9
                        MaterialSymbol {
                            text: "crop_free"
                            iconSize: 20
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("OCR reads pixels, not selectable app text. Tight selections around one word or one line are most accurate; small captures are enlarged automatically before recognition. Missing language data is downloaded once when needed.")
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: root.showAdvancedOcr ? "expand_less" : "tune"
                    mainText: root.showAdvancedOcr ? Translation.tr("Hide advanced OCR options") : Translation.tr("Advanced OCR options")
                    onClicked: root.showAdvancedOcr = !root.showAdvancedOcr
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAdvancedOcr
                    spacing: Appearance.sizes.spacingSmall
                    ContentSubsectionLabel { text: Translation.tr("Custom Tesseract language code") }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: customOcrLanguageField.implicitHeight
                        MaterialTextField {
                            id: customOcrLanguageField
                            anchors.left: parent.left
                            anchors.right: parent.right
                            placeholderText: "deu  ·  fra  ·  kor  ·  eng+deu"
                            text: Config.options?.regionSelector?.ocrLanguage ?? "auto"
                            onEditingFinished: {
                                const value = text.trim()
                                if (value.length > 0) Config.setNestedValue("regionSelector.ocrLanguage", value)
                            }
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Advanced: use a Tesseract model code only when it is not listed above. Combine languages with + only for genuinely mixed-language captures; more models usually reduce recognition accuracy.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Japanese study assistant")

                SettingsSwitch {
                    buttonIcon: "dictionary"
                    text: Translation.tr("Open study card after Japanese OCR")
                    checked: Config.options?.regionSelector?.japaneseLookup?.enabled ?? true
                    onCheckedChanged: Config.setNestedValue("regionSelector.japaneseLookup.enabled", checked)
                    StyledToolTip {
                        text: Translation.tr("After Japanese OCR, iNiR finds a useful word in the captured text and opens a local dictionary card. Expand the card to inspect the full OCR text and translation.")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: japaneseStatusRow.implicitHeight + 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    RowLayout {
                        id: japaneseStatusRow
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9
                        MaterialSymbol {
                            text: JapaneseDictionary.jitendexInstalled ? "check_circle" : "download"
                            iconSize: 21
                            color: JapaneseDictionary.jitendexInstalled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText {
                                Layout.fillWidth: true
                                text: JapaneseDictionary.jitendexInstalled ? Translation.tr("Japanese dictionary ready") : Translation.tr("One-time dictionary setup")
                                color: Appearance.colors.colOnLayer2
                                font.weight: Font.Medium
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: JapaneseDictionary.jitendexInstalled
                                    ? Translation.tr("Jitendex is indexed locally; dictionary lookups work offline.")
                                    : Translation.tr("Install Jitendex once. iNiR downloads and indexes it automatically; you do not need to find or import a ZIP.")
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    enabled: !JapaneseDictionary.busy
                    materialIcon: JapaneseDictionary.jitendexInstalled ? "system_update_alt" : "download"
                    mainText: JapaneseDictionary.busy
                        ? Translation.tr("Preparing Japanese dictionary…")
                        : (JapaneseDictionary.jitendexInstalled
                            ? Translation.tr("Update Japanese dictionary")
                            : Translation.tr("Install Japanese dictionary (~37 MB)"))
                    onClicked: JapaneseDictionary.installRecommended()
                }

                RecordingDropdownField {
                    title: Translation.tr("Translate to")
                    description: Translation.tr("Translation is optional and uses the existing translate-shell service, so it needs an internet connection. Dictionary definitions remain local after Jitendex is installed.")
                    options: root.ocrTranslationTargetOptions
                    currentValue: Config.options?.regionSelector?.japaneseLookup?.translationTarget ?? "auto"
                    onSelected: newValue => Config.setNestedValue("regionSelector.japaneseLookup.translationTarget", newValue)
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: JapaneseDictionary.status.length > 0
                    text: JapaneseDictionary.status
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: root.showAdvancedJapanese ? "expand_less" : "library_books"
                    mainText: root.showAdvancedJapanese ? Translation.tr("Hide dictionary tools") : Translation.tr("More dictionary options")
                    onClicked: root.showAdvancedJapanese = !root.showAdvancedJapanese
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.showAdvancedJapanese
                    spacing: Appearance.sizes.spacingSmall
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingSmall
                        RippleButtonWithIcon {
                            Layout.fillWidth: true
                            materialIcon: "library_add"
                            mainText: Translation.tr("Import another Yomitan dictionary")
                            onClicked: japaneseDictionaryDialog.open()
                        }
                        RippleButtonWithIcon {
                            Layout.fillWidth: true
                            materialIcon: "refresh"
                            mainText: Translation.tr("Refresh index")
                            onClicked: JapaneseDictionary.refresh()
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: JapaneseDictionary.dictionaryCount === 1
                            ? Translation.tr("1 local Japanese dictionary indexed")
                            : Translation.tr("%1 local Japanese dictionaries indexed").arg(JapaneseDictionary.dictionaryCount)
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Anki (optional)")

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Anki turns a recognized word into a spaced-repetition flashcard. You do not need Anki for OCR, dictionary lookup or translation. To save cards, Anki Desktop must be open with the AnkiConnect add-on enabled.")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }

                SettingsSwitch {
                    buttonIcon: "school"
                    text: Translation.tr("Show Anki actions in the study card")
                    checked: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("regionSelector.japaneseLookup.anki.enabled", checked)
                        if (checked) JapaneseDictionary.checkAnki()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
                    implicitHeight: ankiStatusRow.implicitHeight + 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    RowLayout {
                        id: ankiStatusRow
                        anchors.fill: parent
                        anchors.margins: 9
                        spacing: 9
                        MaterialSymbol {
                            text: JapaneseDictionary.ankiAvailable ? "check_circle"
                                : (JapaneseDictionary.ankiState === "app_closed" ? "play_circle" : "info")
                            iconSize: 21
                            color: JapaneseDictionary.ankiAvailable ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: JapaneseDictionary.ankiConnectionStatus
                            color: Appearance.colors.colOnLayer2
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
                    spacing: Appearance.sizes.spacingSmall
                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        visible: JapaneseDictionary.ankiState === "app_closed"
                        materialIcon: "play_arrow"
                        mainText: Translation.tr("Open Anki")
                        onClicked: JapaneseDictionary.launchAnki()
                    }
                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        visible: JapaneseDictionary.ankiState === "not_installed"
                        materialIcon: "download"
                        mainText: Translation.tr("Get Anki Desktop")
                        onClicked: Quickshell.execDetached(["xdg-open", "https://apps.ankiweb.net/"])
                    }
                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        visible: JapaneseDictionary.ankiState === "connect_unavailable"
                        materialIcon: "extension"
                        mainText: Translation.tr("Install / check AnkiConnect")
                        onClicked: Quickshell.execDetached(["xdg-open", "https://ankiweb.net/shared/info/2055492159"])
                    }
                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "refresh"
                        mainText: Translation.tr("Check connection")
                        onClicked: JapaneseDictionary.checkAnki()
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    visible: Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false
                    materialIcon: root.showAdvancedAnki ? "expand_less" : "settings"
                    mainText: root.showAdvancedAnki ? Translation.tr("Hide Anki advanced settings") : Translation.tr("Advanced Anki settings")
                    onClicked: root.showAdvancedAnki = !root.showAdvancedAnki
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: (Config.options?.regionSelector?.japaneseLookup?.anki?.enabled ?? false) && root.showAdvancedAnki
                    spacing: Appearance.sizes.spacingSmall
                    ContentSubsectionLabel { text: Translation.tr("AnkiConnect endpoint") }
                    Item {
                        Layout.fillWidth: true; implicitHeight: ankiEndpointField.implicitHeight
                        MaterialTextField { id: ankiEndpointField; anchors.left: parent.left; anchors.right: parent.right; text: Config.options?.regionSelector?.japaneseLookup?.anki?.endpoint ?? "http://127.0.0.1:8765"; onEditingFinished: { Config.setNestedValue("regionSelector.japaneseLookup.anki.endpoint", text.trim()); JapaneseDictionary.checkAnki() } }
                    }
                    ContentSubsectionLabel { text: Translation.tr("Deck name") }
                    Item {
                        Layout.fillWidth: true; implicitHeight: ankiDeckField.implicitHeight
                        MaterialTextField { id: ankiDeckField; anchors.left: parent.left; anchors.right: parent.right; text: Config.options?.regionSelector?.japaneseLookup?.anki?.deck ?? "Default"; onEditingFinished: Config.setNestedValue("regionSelector.japaneseLookup.anki.deck", text.trim()) }
                    }
                    ContentSubsectionLabel { text: Translation.tr("Note model") }
                    Item {
                        Layout.fillWidth: true; implicitHeight: ankiModelField.implicitHeight
                        MaterialTextField { id: ankiModelField; anchors.left: parent.left; anchors.right: parent.right; text: Config.options?.regionSelector?.japaneseLookup?.anki?.model ?? "Basic"; onEditingFinished: Config.setNestedValue("regionSelector.japaneseLookup.anki.model", text.trim()) }
                    }
                    ContentSubsectionLabel { text: Translation.tr("Front / back field names") }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.sizes.spacingSmall
                        Item { Layout.fillWidth: true; implicitHeight: ankiFrontField.implicitHeight; MaterialTextField { id: ankiFrontField; anchors.left: parent.left; anchors.right: parent.right; text: Config.options?.regionSelector?.japaneseLookup?.anki?.frontField ?? "Front"; onEditingFinished: Config.setNestedValue("regionSelector.japaneseLookup.anki.frontField", text.trim()) } }
                        Item { Layout.fillWidth: true; implicitHeight: ankiBackField.implicitHeight; MaterialTextField { id: ankiBackField; anchors.left: parent.left; anchors.right: parent.right; text: Config.options?.regionSelector?.japaneseLookup?.anki?.backField ?? "Back"; onEditingFinished: Config.setNestedValue("regionSelector.japaneseLookup.anki.backField", text.trim()) } }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Ready-made Japanese study decks")

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("These are optional Anki decks from their original upstream projects. iNiR downloads the latest .apkg to Downloads and opens it for import; the deck files are not bundled with iNiR.")
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    enabled: !JapaneseDictionary.deckBusy
                    materialIcon: "download"
                    mainText: Translation.tr("Kaishi 1.5k · Japanese → English · beginner vocabulary")
                    onClicked: JapaneseDictionary.downloadStudyDeck("kaishi")
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    enabled: !JapaneseDictionary.deckBusy
                    materialIcon: "download"
                    mainText: Translation.tr("Manabi 2.7k · Japanese → English · vocabulary + sentences")
                    onClicked: JapaneseDictionary.downloadStudyDeck("manabi")
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    enabled: !JapaneseDictionary.deckBusy
                    materialIcon: "download"
                    mainText: Translation.tr("Niponismo · Japanese → Spanish · grammar")
                    onClicked: JapaneseDictionary.downloadStudyDeck("niponismo")
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: JapaneseDictionary.studyDeckStatus.length > 0
                    text: JapaneseDictionary.studyDeckStatus
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: "travel_explore"
                    mainText: Translation.tr("Browse more shared decks")
                    onClicked: Quickshell.execDetached(["xdg-open", "https://ankiweb.net/shared/decks?search=japanese"])
                }
            }

            ContentSubsection {
                title: Translation.tr("Screenshots folder")

                StyledText {
                    Layout.fillWidth: true
                    text: Directories.shortHomePath(root.effectiveScreenshotPath)
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideMiddle
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.sizes.spacingSmall

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "folder_open"
                        mainText: Translation.tr("Open folder")
                        onClicked: ShellExec.openDirectory(root.effectiveScreenshotPath, Translation.tr("Open screenshots folder"))
                    }

                    RippleButtonWithIcon {
                        Layout.fillWidth: true
                        materialIcon: "drive_file_move"
                        mainText: Translation.tr("Change folder")
                        onClicked: root.openCaptureFolderDialog("screenshots")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Hint target regions")
                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "select_window"
                        text: Translation.tr('Windows')
                        checked: Config.options?.regionSelector?.targetRegions?.windows ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("regionSelector.targetRegions.windows", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Highlight open windows as selectable regions")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "right_panel_open"
                        text: Translation.tr('Layers')
                        checked: Config.options?.regionSelector?.targetRegions?.layers ?? true
                        onCheckedChanged: {
                            Config.setNestedValue("regionSelector.targetRegions.layers", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Highlight UI layers as selectable regions")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "nearby"
                        text: Translation.tr('Content')
                        checked: Config.options?.regionSelector?.targetRegions?.content ?? false
                        onCheckedChanged: {
                            Config.setNestedValue("regionSelector.targetRegions.content", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Could be images or parts of the screen that have some containment.\nMight not always be accurate.\nThis is done with an image processing algorithm run locally and no AI is used.")
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Google Lens")

                ConfigSelectionArray {
                    currentValue: (Config.options?.search?.imageSearch?.useCircleSelection ?? false) ? "circle" : "rectangles"
                    onSelected: newValue => {
                        Config.setNestedValue("search.imageSearch.useCircleSelection", newValue === "circle");
                    }
                    options: [
                        { icon: "activity_zone", value: "rectangles", displayName: Translation.tr("Rectangular selection") },
                        { icon: "gesture", value: "circle", displayName: Translation.tr("Circle to Search") }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Element appearance")

                ConfigSpinBox {
                    icon: "border_style"
                    text: Translation.tr("Border size (px)")
                    value: Config.options?.regionSelector?.borderSize ?? 2
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("regionSelector.borderSize", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Thickness of the selection region border")
                    }
                }
                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Numbers size (px)")
                    value: Config.options?.regionSelector?.numSize ?? 30
                    from: 10
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.setNestedValue("regionSelector.numSize", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Font size of the region index numbers")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Rectangular selection")

                SettingsSwitch {
                    buttonIcon: "point_scan"
                    text: Translation.tr("Show aim lines")
                    checked: Config.options?.regionSelector?.rect?.showAimLines ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("regionSelector.rect.showAimLines", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Show crosshair lines when selecting a region")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Circle selection")

                ConfigSpinBox {
                    icon: "eraser_size_3"
                    text: Translation.tr("Stroke width")
                    value: Config.options?.regionSelector?.circle?.strokeWidth ?? 3
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.setNestedValue("regionSelector.circle.strokeWidth", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Thickness of the circle selection stroke")
                    }
                }

                ConfigSpinBox {
                    icon: "screenshot_frame_2"
                    text: Translation.tr("Padding")
                    value: Config.options?.regionSelector?.circle?.padding ?? 20
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("regionSelector.circle.padding", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Padding around the selected circle region")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("File naming")

                ContentSubsectionLabel {
                    text: Translation.tr("Screenshot filename format (date tokens)")
                }
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: "ss-%Y%m%d-%H%M%S"
                    text: Config.options?.regionSelector?.screenshotNameFormat ?? "ss-%Y%m%d-%H%M%S"
                    onEditingFinished: Config.setNestedValue("regionSelector.screenshotNameFormat", text)
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "crosshair"
        visible: root.activeSection === "crosshair"
        expanded: true
        icon: "point_scan"
        title: Translation.tr("Crosshair overlay")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Crosshair code (in Valorant's format)")
                text: Config.options?.crosshair?.code ?? ""
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.setNestedValue("crosshair.code", text);
                }
            }

            RowLayout {
                StyledText {
                    Layout.leftMargin: 10
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    text: Translation.tr("Floating tools (Super+G)")
                }
                Item {
                    Layout.fillWidth: true
                }
                RippleButtonWithIcon {
                    id: editorButton
                    buttonRadius: Appearance.rounding.full
                    materialIcon: "open_in_new"
                    mainText: Translation.tr("Open editor")
                    onClicked: {
                        Qt.openUrlExternally(`https://www.vcrdb.net/builder?c=${Config.options?.crosshair?.code ?? ""}`);
                    }
                    StyledToolTip {
                        text: "www.vcrdb.net"
                    }
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "discord"
        visible: root.activeSection === "discord"
        expanded: true
        icon: "forum"
        title: Translation.tr("Overlay: Discord")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Discord launch command (e.g., discord, vesktop, webcord)")
                text: Config.options?.apps?.discord ?? ""
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.setNestedValue("apps.discord", text);
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "osd"
        visible: root.activeSection === "osd"
        expanded: true
        icon: "voting_chip"
        title: Translation.tr("On-screen display")

        SettingsGroup {
            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Media OSD")
                checked: Config.options?.osd?.mediaEnabled ?? true
                onCheckedChanged: {
                    Config.setNestedValue("osd.mediaEnabled", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Show feedback for explicit media controls and Pill track changes. During games, explicit skips stay visible while automatic track progression stays hidden.")
                }
            }

            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Timeout (ms)")
                value: Config.options?.osd?.timeout ?? 1500
                from: 100
                to: 3000
                stepSize: 100
                onValueChanged: {
                    Config.setNestedValue("osd.timeout", value);
                }
                StyledToolTip {
                    text: Translation.tr("How long the volume, brightness and media indicators stay visible")
                }
            }
        }
    }
}
