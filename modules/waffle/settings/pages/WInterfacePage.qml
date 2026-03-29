pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 5
    pageTitle: Translation.tr("Interface")
    pageIcon: "apps"
    pageDescription: Translation.tr("Notifications, OSD, and other UI elements")

    property bool recordingCapabilitiesLoaded: false
    property var detectedVideoCodecs: []
    property var detectedAudioCodecs: []
    property var detectedAudioSources: []
    property var detectedHardwareDevices: []
    property string detectedDefaultSink: ""
    property string preferredVideoCodec: "libx264"
    property bool nvidiaDetected: false
    property bool vaapiAvailable: false
    property bool nvencAvailable: false

    readonly property string detectedDefaultAudioSource: detectedDefaultSink.length > 0 ? `${detectedDefaultSink}.monitor` : ""
    readonly property bool gpuRecordingAvailable: vaapiAvailable || nvencAvailable
    readonly property bool customRecordingPreset: (Config.options?.screenRecord?.qualityPreset ?? "balanced") === "custom"
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
            preferredVideoCodec = payload.preferredCodec ?? "libx264"
            nvidiaDetected = payload.nvidia ?? false
            vaapiAvailable = payload.vaapiAvailable ?? false
            nvencAvailable = payload.nvencAvailable ?? false
        } catch (e) {
            detectedVideoCodecs = []
            detectedAudioCodecs = []
            detectedAudioSources = []
            detectedHardwareDevices = []
            detectedDefaultSink = ""
            preferredVideoCodec = "libx264"
            nvidiaDetected = false
            vaapiAvailable = false
            nvencAvailable = false
        }
        recordingCapabilitiesLoaded = true
    }

    function availableVideoCodecOptions() {
        let options = detectedVideoCodecs.map(codec => ({ value: codec, displayName: videoCodecDisplayName(codec) }))
        options = ensureOption(options, Config.options?.screenRecord?.videoCodec ?? preferredVideoCodec, `${Translation.tr("Configured")}: ${Config.options?.screenRecord?.videoCodec ?? preferredVideoCodec}`)
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
            break
        case "balanced":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 10000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 160)
            break
        case "quality":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 16000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 192)
            break
        case "master":
            Config.setNestedValue("screenRecord.accelerationMode", "auto")
            Config.setNestedValue("screenRecord.videoCodec", "libx264")
            Config.setNestedValue("screenRecord.audioCodec", "aac")
            Config.setNestedValue("screenRecord.fps", 60)
            Config.setNestedValue("screenRecord.videoBitrateKbps", 28000)
            Config.setNestedValue("screenRecord.audioBitrateKbps", 256)
            break
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
        onExited: exitCode => {
            if (exitCode !== 0 && !root.recordingCapabilitiesLoaded)
                root.recordingCapabilitiesLoaded = true
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Display scaling")
        icon: "aspect-ratio"

        WSettingsSpinBox {
            id: scaleSpinBox
            label: Translation.tr("UI scale")
            icon: "zoom-in"
            description: Translation.tr("Takes effect immediately")
            suffix: "%"
            from: 50; to: 200; stepSize: 5
            value: Math.round((Config.options?.appearance?.typography?.sizeScale ?? 1.0) * 100)
            onValueChanged: Config.setNestedValue("appearance.typography.sizeScale", value / 100)
        }

        WSettingsButton {
            visible: Math.abs((Config.options?.appearance?.typography?.sizeScale ?? 1.0) - 1.0) > 0.01
            label: Translation.tr("Reset to 100%")
            icon: "zoom-out"
            buttonText: Translation.tr("Reset")
            onButtonClicked: {
                Config.setNestedValue("appearance.typography.sizeScale", 1.0)
                scaleSpinBox.value = 100
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Notifications")
        icon: "alert"
        
        WSettingsSpinBox {
            label: Translation.tr("Normal timeout")
            icon: "alert"
            description: Translation.tr("How long normal notifications stay visible")
            suffix: "ms"
            from: 1000; to: 30000; stepSize: 1000
            value: Config.options?.notifications?.timeoutNormal ?? 7000
            onValueChanged: Config.setNestedValue("notifications.timeoutNormal", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Low priority timeout")
            icon: "alert-snooze"
            suffix: "ms"
            from: 1000; to: 30000; stepSize: 1000
            value: Config.options?.notifications?.timeoutLow ?? 5000
            onValueChanged: Config.setNestedValue("notifications.timeoutLow", value)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("Critical timeout")
            icon: "alert"
            description: Translation.tr("0 = never auto-dismiss")
            suffix: "ms"
            from: 0; to: 30000; stepSize: 1000
            value: Config.options?.notifications?.timeoutCritical ?? 0
            onValueChanged: Config.setNestedValue("notifications.timeoutCritical", value)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Ignore app timeout")
            icon: "alert-off"
            description: Translation.tr("Always use your timeout settings instead of app-defined ones")
            checked: Config.options?.notifications?.ignoreAppTimeout ?? false
            onCheckedChanged: Config.setNestedValue("notifications.ignoreAppTimeout", checked)
        }
        
        WSettingsDropdown {
            label: Translation.tr("Popup position")
            icon: "desktop"
            currentValue: Config.options?.notifications?.position ?? "bottomRight"
            options: [
                { value: "topLeft", displayName: Translation.tr("Top Left") },
                { value: "topRight", displayName: Translation.tr("Top Right") },
                { value: "bottomLeft", displayName: Translation.tr("Bottom Left") },
                { value: "bottomRight", displayName: Translation.tr("Bottom Right") }
            ]
            onSelected: newValue => Config.setNestedValue("notifications.position", newValue)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Do Not Disturb")
            icon: "alert-off"
            description: Translation.tr("Silence all notifications")
            checked: Config.options?.notifications?.silent ?? false
            onCheckedChanged: Config.setNestedValue("notifications.silent", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("On-Screen Display")
        icon: "speaker-2-filled"
        
        WSettingsSpinBox {
            label: Translation.tr("OSD timeout")
            icon: "speaker-2-filled"
            description: Translation.tr("How long volume/brightness OSD stays visible")
            suffix: "ms"
            from: 500; to: 5000; stepSize: 250
            value: Config.options?.osd?.timeout ?? 1000
            onValueChanged: Config.setNestedValue("osd.timeout", value)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Lock Screen")
        icon: "lock-closed"
        
        WSettingsSwitch {
            label: Translation.tr("Enable blur")
            icon: "eye"
            description: Translation.tr("Blur background on lock screen")
            checked: Config.options?.lock?.blur?.enable ?? true
            onCheckedChanged: Config.setNestedValue("lock.blur.enable", checked)
        }
        
        WSettingsSpinBox {
            visible: Config.options?.lock?.blur?.enable ?? true
            label: Translation.tr("Blur radius")
            icon: "eye"
            from: 0; to: 200; stepSize: 10
            value: Config.options?.lock?.blur?.radius ?? 100
            onValueChanged: Config.setNestedValue("lock.blur.radius", value)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Center clock")
            icon: "arrow-clockwise"
            checked: Config.options?.lock?.centerClock ?? true
            onCheckedChanged: Config.setNestedValue("lock.centerClock", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show 'Locked' text")
            icon: "lock-closed"
            checked: Config.options?.lock?.showLockedText ?? true
            onCheckedChanged: Config.setNestedValue("lock.showLockedText", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Display")
        icon: "desktop"
        
        WSettingsDropdown {
            label: Translation.tr("Fake rounded corners")
            icon: "desktop"
            description: Translation.tr("Add rounded corners to flat screens")
            currentValue: Config.options?.appearance?.fakeScreenRounding ?? 0
            options: [
                { value: 0, displayName: Translation.tr("None") },
                { value: 1, displayName: Translation.tr("Always") },
                { value: 2, displayName: Translation.tr("When not fullscreen") }
            ]
            onSelected: newValue => Config.setNestedValue("appearance.fakeScreenRounding", newValue)
        }

    }

    WSettingsCard {
        title: Translation.tr("Screen Recording")
        icon: "record"

        WSettingsRow {
            label: !recordingCapabilitiesLoaded
                ? Translation.tr("Detecting recorder capabilities")
                : (gpuRecordingAvailable
                    ? Translation.tr("Hardware acceleration available")
                    : Translation.tr("Software recording fallback"))
            icon: !recordingCapabilitiesLoaded ? "settings" : (gpuRecordingAvailable ? "desktop" : "record")
            description: !recordingCapabilitiesLoaded
                ? Translation.tr("Checking available codecs, devices, and audio sources from the recorder script")
                : (nvidiaDetected
                    ? Translation.tr("NVIDIA-compatible encoders detected. NVENC paths will be preferred when available.")
                    : (vaapiAvailable
                        ? Translation.tr("VAAPI-compatible render devices detected. AMD/Intel GPU encoding is available.")
                        : Translation.tr("No GPU encoder detected. wf-recorder will use software encoding.")))
        }

        WSettingsRow {
            label: Translation.tr("Preferred codec")
            icon: "record"
            description: Translation.tr("Auto currently resolves to %1").arg(root.videoCodecDisplayName(root.preferredVideoCodec))
        }

        WSettingsDropdown {
            label: Translation.tr("Quality preset")
            icon: "settings"
            description: Translation.tr("Trade off file size and output quality")
            currentValue: Config.options?.screenRecord?.qualityPreset ?? "balanced"
            options: root.recordingQualityPresetOptions
            onSelected: newValue => {
                if (newValue === "custom")
                    Config.setNestedValue("screenRecord.qualityPreset", "custom")
                else
                    root.applyRecordingPreset(newValue)
            }
        }

        WSettingsDropdown {
            label: Translation.tr("Acceleration")
            icon: "flash-on"
            description: Translation.tr("Auto picks the best path for your hardware")
            currentValue: Config.options?.screenRecord?.accelerationMode ?? "auto"
            options: root.recordingAccelerationOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.accelerationMode", newValue)
        }

        WSettingsTextField {
            label: Translation.tr("Save path")
            icon: "folder"
            description: Translation.tr("Leave empty to use the Videos folder")
            placeholderText: Translation.tr("e.g. /home/you/Videos/Recordings")
            text: Config.options?.screenRecord?.savePath ?? ""
            onTextEdited: newText => root.setRecordingConfig("screenRecord.savePath", newText)
        }

        WSettingsSwitch {
            label: Translation.tr("Fallback if preferred encoder fails")
            icon: "arrow-sync"
            description: Translation.tr("Retry with a safer recording path if the preferred encoder fails")
            checked: Config.options?.screenRecord?.enableFallback ?? true
            onCheckedChanged: root.setRecordingConfig("screenRecord.enableFallback", checked)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Video codec")
            icon: "record"
            currentValue: Config.options?.screenRecord?.videoCodec ?? root.preferredVideoCodec
            options: root.availableVideoCodecOptions()
            onSelected: newValue => root.setRecordingConfig("screenRecord.videoCodec", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Frame rate")
            icon: "arrow-clockwise"
            currentValue: Config.options?.screenRecord?.fps ?? 60
            options: root.recordingFpsOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.fps", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Video bitrate")
            icon: "record"
            currentValue: Config.options?.screenRecord?.videoBitrateKbps ?? 12000
            options: root.recordingVideoBitrateOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.videoBitrateKbps", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio codec")
            icon: "speaker-2-filled"
            currentValue: Config.options?.screenRecord?.audioCodec ?? "aac"
            options: root.availableAudioCodecOptions()
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioCodec", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio bitrate")
            icon: "speaker-2-filled"
            currentValue: Config.options?.screenRecord?.audioBitrateKbps ?? 192
            options: root.recordingAudioBitrateOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioBitrateKbps", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio source")
            icon: "speaker-2-filled"
            description: Translation.tr("Default output monitor captures desktop audio")
            currentValue: Config.options?.screenRecord?.audioSource ?? ""
            options: root.availableAudioSourceOptions()
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioSource", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio backend")
            icon: "speaker-2-filled"
            currentValue: Config.options?.screenRecord?.audioBackend ?? ""
            options: root.recordingAudioBackendOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioBackend", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset && root.gpuRecordingAvailable
            label: Translation.tr("Render device")
            icon: "desktop"
            currentValue: Config.options?.screenRecord?.hardwareDevice ?? "/dev/dri/renderD128"
            options: root.availableHardwareDeviceOptions()
            onSelected: newValue => root.setRecordingConfig("screenRecord.hardwareDevice", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset && root.vaapiAvailable
            label: Translation.tr("VAAPI filter")
            icon: "eyedropper"
            currentValue: Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full"
            options: root.ensureOption(root.recordingVaapiFilterOptions, Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full", `${Translation.tr("Configured filter")}: ${Config.options?.screenRecord?.vaapiFilter ?? "scale_vaapi=format=nv12:out_range=full"}`)
            onSelected: newValue => root.setRecordingConfig("screenRecord.vaapiFilter", newValue)
        }
    }
}
