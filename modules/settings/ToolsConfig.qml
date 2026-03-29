import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 6
    settingsPageName: Translation.tr("Tools")

    property bool recordingCapabilitiesLoaded: false
    property var detectedVideoCodecs: []
    property var detectedAudioCodecs: []
    property var detectedAudioSources: []
    property var detectedHardwareDevices: []
    property string detectedDefaultSink: ""

    readonly property string detectedDefaultAudioSource: detectedDefaultSink.length > 0 ? `${detectedDefaultSink}.monitor` : ""
    readonly property bool gpuRecordingAvailable: detectedVideoCodecs.some(codec => String(codec).indexOf("_vaapi") !== -1)
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
        case "libx264": return Translation.tr("H.264 (software)")
        case "libx265": return Translation.tr("H.265 / HEVC (software)")
        default: return codec
        }
    }

    function audioCodecDisplayName(codec) {
        switch (codec) {
        case "aac": return Translation.tr("AAC")
        case "libopus": return Translation.tr("Opus")
        case "opus": return Translation.tr("Opus")
        default: return codec
        }
    }

    function audioSourceDisplayName(source) {
        if (source === "")
            return detectedDefaultAudioSource.length > 0
                ? `${Translation.tr("Default output monitor")} (${detectedDefaultAudioSource})`
                : Translation.tr("Default output monitor")
        if (source === detectedDefaultAudioSource)
            return `${Translation.tr("Default output monitor")} (${source})`
        if (String(source).indexOf(".monitor") !== -1)
            return `${Translation.tr("Output monitor")} (${source})`
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
        } catch (e) {
            detectedVideoCodecs = []
            detectedAudioCodecs = []
            detectedAudioSources = []
            detectedHardwareDevices = []
            detectedDefaultSink = ""
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

    function availableAudioSourceOptions() {
        let options = [{ value: "", displayName: audioSourceDisplayName("") }]
        options = options.concat(detectedAudioSources.map(source => ({ value: source, displayName: audioSourceDisplayName(source) })))
        options = ensureOption(options, Config.options?.screenRecord?.audioSource ?? "", `${Translation.tr("Configured source")}: ${Config.options?.screenRecord?.audioSource ?? ""}`)
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
        property bool enabled: true
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
            enabled: field.enabled
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
        command: ["/usr/bin/bash", "-lc", "python3 - <<'PY'\nimport glob, json, subprocess\n\nenc = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], capture_output=True, text=True).stdout.splitlines()\nencoders = set()\nfor line in enc:\n    parts = line.split()\n    if len(parts) >= 2:\n        encoders.add(parts[1])\nvideo = [c for c in ['h264_vaapi','hevc_vaapi','vp9_vaapi','av1_vaapi','libx264','libx265'] if c in encoders]\naudio = [c for c in ['aac','libopus','opus'] if c in encoders]\nsources_raw = subprocess.run(['pactl', 'list', 'sources', 'short'], capture_output=True, text=True).stdout.splitlines()\nsources = []\nfor line in sources_raw:\n    parts = line.split()\n    if len(parts) >= 2:\n        sources.append(parts[1])\ndefault_sink = subprocess.run(['pactl', 'get-default-sink'], capture_output=True, text=True).stdout.strip()\ndevices = sorted(glob.glob('/dev/dri/renderD*'))\nprint(json.dumps({\n    'videoCodecs': video,\n    'audioCodecs': audio,\n    'audioSources': sources,\n    'hardwareDevices': devices,\n    'defaultSink': default_sink\n}))\nPY"]
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
        expanded: false
        icon: "screen_record"
        title: Translation.tr("Screen recording")

        readonly property bool isCustomPreset: (Config.options?.screenRecord?.qualityPreset ?? "balanced") === "custom"

        SettingsGroup {
            NoticeBox {
                Layout.fillWidth: true
                materialIcon: recordingCapabilitiesLoaded ? (gpuRecordingAvailable ? "memory" : "developer_mode") : "progress_activity"
                text: !recordingCapabilitiesLoaded
                    ? Translation.tr("Detecting available encoders…")
                    : gpuRecordingAvailable
                        ? Translation.tr("GPU recording available. Hardware acceleration will be used when possible.")
                        : Translation.tr("No GPU encoder detected. Software recording will be used.")
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
                title: Translation.tr("Audio")

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

                RecordingDropdownField {
                    title: Translation.tr("Audio source")
                    description: Translation.tr("Default output monitor captures desktop audio.")
                    options: root.availableAudioSourceOptions()
                    currentValue: Config.options?.screenRecord?.audioSource ?? ""
                    onSelected: newValue => root.setRecordingConfig("screenRecord.audioSource", newValue)
                }
            }

            ContentSubsection {
                visible: screenRecordSection.isCustomPreset && root.gpuRecordingAvailable
                title: Translation.tr("GPU hardware")

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
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "screenshot_frame_2"
        title: Translation.tr("Region selector (screen snipping/Google Lens)")

        SettingsGroup {
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
        }
    }

    SettingsCardSection {
        expanded: false
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
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    text: Translation.tr("Press Super+G to toggle appearance")
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
        expanded: false
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
        expanded: false
        icon: "layers"
        title: Translation.tr("Overlay widgets")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Background & dim")

                SettingsSwitch {
                    buttonIcon: "water"
                    text: Translation.tr("Darken screen behind overlay")
                    checked: Config.options?.overlay?.darkenScreen ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("overlay.darkenScreen", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Add a dark scrim behind overlay panels for better visibility")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay scrim dim (%)")
                    value: Config.options?.overlay?.scrimDim ?? 30
                    from: 0
                    to: 100
                    stepSize: 5
                    enabled: Config.options?.overlay?.darkenScreen ?? false
                    onValueChanged: {
                        Config.setNestedValue("overlay.scrimDim", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("How dark the background scrim should be")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay background opacity (%)")
                    value: Math.round((Config.options?.overlay?.backgroundOpacity ?? 0.9) * 100)
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("overlay.backgroundOpacity", value / 100);
                    }
                    StyledToolTip {
                        text: Translation.tr("Opacity of the overlay panel background")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Animations")

                SettingsSwitch {
                    buttonIcon: "movie"
                    text: Translation.tr("Enable opening zoom animation")
                    checked: Config.options?.overlay?.openingZoomAnimation ?? true
                    onCheckedChanged: {
                        Config.setNestedValue("overlay.openingZoomAnimation", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Animate overlay panels with a zoom effect when opening")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Overlay animation duration (ms)")
                    value: Config.options?.overlay?.animationDurationMs ?? 180
                    from: 0
                    to: 1000
                    stepSize: 20
                    onValueChanged: {
                        Config.setNestedValue("overlay.animationDurationMs", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Duration of overlay open/close animations")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Background dim animation (ms)")
                    value: Config.options?.overlay?.scrimAnimationDurationMs ?? 140
                    from: 0
                    to: 1000
                    stepSize: 20
                    onValueChanged: {
                        Config.setNestedValue("overlay.scrimAnimationDurationMs", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Duration of the background scrim fade animation")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "voting_chip"
        title: Translation.tr("On-screen display")

        SettingsGroup {
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
                    text: Translation.tr("How long the volume/brightness indicator stays visible")
                }
            }
        }
    }
}
