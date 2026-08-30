pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 6
    pageTitle: Translation.tr("Interface")
    pageIcon: "apps"
    pageDescription: Translation.tr("Notifications, OSD, and other UI elements")

    property bool recordingCapabilitiesLoaded: false
    property var detectedVideoCodecs: []
    property var detectedAudioCodecs: []
    property var detectedAudioSources: []
    property var detectedHardwareDevices: []
    property string detectedDefaultSink: ""
    property string detectedDefaultSource: ""
    property bool audioMixAvailable: false
    property string preferredVideoCodec: "libx264"
    property bool nvidiaDetected: false
    property bool vaapiAvailable: false
    property bool nvencAvailable: false

    readonly property string recordingAudioMode: RecorderStatus.configuredAudioMode
    readonly property string detectedDefaultAudioSource: detectedDefaultSink.length > 0 ? `${detectedDefaultSink}.monitor` : ""
    readonly property bool gpuRecordingAvailable: vaapiAvailable || nvencAvailable
    readonly property bool customRecordingPreset: (Config.options?.screenRecord?.qualityPreset ?? "balanced") === "custom"

    function floatingToolsEnabled(): bool {
        return (Config.options?.enabledPanels ?? []).includes("iiOverlay")
    }

    function setFloatingToolsEnabled(enabled: bool): void {
        const panels = [...(Config.options?.enabledPanels ?? [])]
        const index = panels.indexOf("iiOverlay")
        if (enabled && index === -1)
            panels.push("iiOverlay")
        else if (!enabled && index !== -1)
            panels.splice(index, 1)
        Config.setNestedValue("enabledPanels", panels)
    }

    function openFloatingTools(): void {
        GlobalStates.settingsOverlayOpen = false
        GlobalStates.overlayOpen = true
    }
    readonly property var recordingAudioModeOptions: [
        { value: "none", displayName: Translation.tr("No audio") },
        { value: "system", displayName: Translation.tr("System audio") },
        { value: "microphone", displayName: Translation.tr("Microphone") },
        { value: "both", displayName: Translation.tr("System + microphone") }
    ]
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
    readonly property var recordingSoftwarePresetOptions: ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"].map(value => ({ value: value, displayName: value }))
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
            detectedDefaultSource = ""
            audioMixAvailable = false
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
        icon: "screenshot"

        WSettingsSpinBox {
            id: scaleSpinBox
            label: Translation.tr("UI scale")
            icon: "screenshot"
            description: Translation.tr("Takes effect immediately")
            suffix: "%"
            from: 50; to: 200; stepSize: 5
            value: Math.round((Config.options?.appearance?.typography?.sizeScale ?? 1.0) * 100)
            onValueChanged: Config.setNestedValue("appearance.typography.sizeScale", value / 100)
        }

        WSettingsButton {
            visible: Math.abs((Config.options?.appearance?.typography?.sizeScale ?? 1.0) - 1.0) > 0.01
            label: Translation.tr("Reset to 100%")
            icon: "arrow-counterclockwise"
            buttonText: Translation.tr("Reset")
            onButtonClicked: {
                Config.setNestedValue("appearance.typography.sizeScale", 1.0)
                scaleSpinBox.value = 100
            }
        }
    }

    WSettingsCard {
        title: Translation.tr("Display")
        icon: "screenshot"
        
        WSettingsDropdown {
            label: Translation.tr("Fake rounded corners")
            icon: "screenshot"
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

    WSettingsSection {
        title: Translation.tr("Notifications & Alerts")
        icon: "alert"
    }

    WSettingsCard {
        title: Translation.tr("Notifications")
        icon: "alert"
        
        WSettingsSpinBox {
            label: Translation.tr("Normal timeout")
            icon: "arrow-clockwise"
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
            icon: "alert-filled"
            description: Translation.tr("0 = never auto-dismiss")
            suffix: "ms"
            from: 0; to: 30000; stepSize: 1000
            value: Config.options?.notifications?.timeoutCritical ?? 0
            onValueChanged: Config.setNestedValue("notifications.timeoutCritical", value)
        }

        WSettingsSwitch {
            label: Translation.tr("Quiet hours")
            icon: "weather-moon"
            description: Translation.tr("Hold back popups during a daily window. Notifications still reach the history.")
            checked: Config.options?.notifications?.quietHours?.enable ?? false
            onCheckedChanged: Config.setNestedValue("notifications.quietHours.enable", checked)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            enabled: Config.options?.notifications?.quietHours?.enable ?? false
            opacity: enabled ? 1 : 0.5

            WText {
                text: Translation.tr("From")
                color: Looks.colors.subfg
            }
            WSettingsTextField {
                Layout.preferredWidth: 100
                placeholderText: "22:00"
                text: Config.options?.notifications?.quietHours?.start ?? "22:00"
                // textEdited fires per keystroke; only persist a complete HH:MM.
                onTextEdited: newText => {
                    if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(newText))
                        Config.setNestedValue("notifications.quietHours.start", newText)
                }
            }
            WText {
                text: Translation.tr("to")
                color: Looks.colors.subfg
            }
            WSettingsTextField {
                Layout.preferredWidth: 100
                placeholderText: "08:00"
                text: Config.options?.notifications?.quietHours?.end ?? "08:00"
                onTextEdited: newText => {
                    if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(newText))
                        Config.setNestedValue("notifications.quietHours.end", newText)
                }
            }
            Item { Layout.fillWidth: true }
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
            icon: "panel-left-expand"
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
            icon: "weather-moon"
            description: Translation.tr("Silence all notifications")
            checked: Config.options?.notifications?.silent ?? false
            onCheckedChanged: Config.setNestedValue("notifications.silent", checked)
        }
    }
    
    WSettingsCard {
        title: Translation.tr("Floating tools (Super+G)")
        icon: "apps"

        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Info
            message: Translation.tr("Floating image and widgets panel (Super+G)")
        }

        WSettingsSwitch {
            label: Translation.tr("Enable")
            icon: "apps"
            checked: root.floatingToolsEnabled()
            onCheckedChanged: root.setFloatingToolsEnabled(checked)
        }

        WSettingsButton {
            label: Translation.tr("Floating tools (Super+G)")
            icon: "apps"
            description: "Super+G"
            buttonText: Translation.tr("Open")
            buttonIcon: "open"
            enabled: root.floatingToolsEnabled()
            onButtonClicked: root.openFloatingTools()
        }

        WSettingsSwitch {
            label: Translation.tr("Darken screen behind overlay")
            icon: "eye"
            description: Translation.tr("Add a dark scrim behind overlay panels for better visibility")
            checked: Config.options?.overlay?.darkenScreen ?? false
            onCheckedChanged: Config.setNestedValue("overlay.darkenScreen", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Overlay scrim dim (%)")
            icon: "eye"
            suffix: "%"
            from: 0; to: 100; stepSize: 5
            enabled: Config.options?.overlay?.darkenScreen ?? false
            value: Config.options?.overlay?.scrimDim ?? 30
            onValueChanged: Config.setNestedValue("overlay.scrimDim", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Overlay background opacity (%)")
            icon: "eye"
            suffix: "%"
            from: 20; to: 100; stepSize: 5
            value: Math.round((Config.options?.overlay?.backgroundOpacity ?? 0.9) * 100)
            onValueChanged: Config.setNestedValue("overlay.backgroundOpacity", value / 100)
        }

        WSettingsSwitch {
            label: Translation.tr("Enable opening zoom animation")
            icon: "play"
            checked: Config.options?.overlay?.openingZoomAnimation ?? true
            onCheckedChanged: Config.setNestedValue("overlay.openingZoomAnimation", checked)
        }

        WSettingsSpinBox {
            label: Translation.tr("Overlay animation duration (ms)")
            icon: "arrow-clockwise"
            suffix: "ms"
            from: 0; to: 1000; stepSize: 20
            value: Config.options?.overlay?.animationDurationMs ?? 180
            onValueChanged: Config.setNestedValue("overlay.animationDurationMs", value)
        }

        WSettingsSpinBox {
            label: Translation.tr("Background dim animation (ms)")
            icon: "arrow-clockwise"
            suffix: "ms"
            from: 0; to: 1000; stepSize: 20
            value: Config.options?.overlay?.scrimAnimationDurationMs ?? 140
            onValueChanged: Config.setNestedValue("overlay.scrimAnimationDurationMs", value)
        }
    }

    WSettingsCard {
        title: Translation.tr("On-Screen Display")
        icon: "pulse"

        WSettingsSwitch {
            label: Translation.tr("Media OSD")
            icon: "music-note-2"
            description: Translation.tr("Show feedback for explicit media controls. Pill also announces automatic track changes outside games.")
            checked: Config.options?.osd?.mediaEnabled ?? true
            onCheckedChanged: Config.setNestedValue("osd.mediaEnabled", checked)
        }
        
        WSettingsSpinBox {
            label: Translation.tr("OSD timeout")
            icon: "arrow-clockwise"
            description: Translation.tr("How long volume, brightness and media OSD stays visible")
            suffix: "ms"
            from: 500; to: 5000; stepSize: 250
            value: Config.options?.osd?.timeout ?? 1000
            onValueChanged: Config.setNestedValue("osd.timeout", value)
        }
    }
    
    WSettingsSection {
        title: Translation.tr("Lock Screen")
        icon: "lock-closed"
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
            icon: "eyedropper"
            from: 0; to: 200; stepSize: 10
            value: Config.options?.lock?.blur?.radius ?? 100
            onValueChanged: Config.setNestedValue("lock.blur.radius", value)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Center clock")
            icon: "panel-left-contract"
            checked: Config.options?.lock?.centerClock ?? true
            onCheckedChanged: Config.setNestedValue("lock.centerClock", checked)
        }
        
        WSettingsSwitch {
            label: Translation.tr("Show 'Locked' text")
            icon: "lock-closed"
            checked: Config.options?.lock?.showLockedText ?? true
            onCheckedChanged: Config.setNestedValue("lock.showLockedText", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Show notifications")
            icon: "alert"
            description: Translation.tr("Display recent notifications on the lock screen")
            checked: Config.options?.lock?.notifications?.enable ?? false
            onCheckedChanged: Config.setNestedValue("lock.notifications.enable", checked)
        }

        WSettingsSwitch {
            visible: Config.options?.lock?.notifications?.enable ?? false
            label: Translation.tr("Show notification body")
            icon: "eye"
            description: Translation.tr("Display message content. Disable for privacy.")
            checked: Config.options?.lock?.notifications?.showBody ?? true
            onCheckedChanged: Config.setNestedValue("lock.notifications.showBody", checked)
        }

        WSettingsSpinBox {
            visible: Config.options?.lock?.notifications?.enable ?? false
            label: Translation.tr("Max notifications shown")
            icon: "list"
            from: 1; to: 10; stepSize: 1
            value: Config.options?.lock?.notifications?.maxCount ?? 3
            onValueChanged: Config.setNestedValue("lock.notifications.maxCount", value)
        }

        WSettingsDropdown {
            visible: Config.options?.lock?.notifications?.enable ?? false
            label: Translation.tr("Notification position")
            icon: "panel-left-expand"
            description: Translation.tr("Where notifications appear on the lock screen")
            currentValue: Config.options?.lock?.notifications?.position ?? "auto"
            options: [
                { value: "auto", displayName: Translation.tr("Auto") },
                { value: "center", displayName: Translation.tr("Center") },
                { value: "left", displayName: Translation.tr("Left") },
                { value: "right", displayName: Translation.tr("Right") }
            ]
            onSelected: newValue => Config.setNestedValue("lock.notifications.position", newValue)
        }

        WSettingsDropdown {
            label: Translation.tr("Clock style")
            icon: "arrow-clockwise"
            description: Translation.tr("Visual style for the lock screen clock")
            currentValue: Config.options?.lock?.clock?.style ?? "default"
            options: [
                { value: "default", displayName: Translation.tr("Default") },
                { value: "minimal", displayName: Translation.tr("Minimal") },
                { value: "analog", displayName: Translation.tr("Analog") }
            ]
            onSelected: newValue => Config.setNestedValue("lock.clock.style", newValue)
        }

        WSettingsDropdown {
            label: Translation.tr("Clock position")
            icon: "pin"
            description: Translation.tr("Where the clock appears on the lock screen")
            currentValue: Config.options?.lock?.clock?.position ?? "center"
            options: [
                { value: "center", displayName: Translation.tr("Center") },
                { value: "topLeft", displayName: Translation.tr("Top Left") },
                { value: "bottomLeft", displayName: Translation.tr("Bottom Left") }
            ]
            onSelected: newValue => Config.setNestedValue("lock.clock.position", newValue)
        }

        WSettingsSwitch {
            label: Translation.tr("Show status indicators")
            icon: "info"
            description: Translation.tr("Show WiFi, Bluetooth, volume and battery on the lock screen")
            checked: Config.options?.lock?.status?.enable ?? true
            onCheckedChanged: Config.setNestedValue("lock.status.enable", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Dim wallpaper")
            icon: "dark-theme"
            description: Translation.tr("Apply a dark overlay to the wallpaper for better contrast")
            checked: Config.options?.lock?.dim?.enable ?? false
            onCheckedChanged: Config.setNestedValue("lock.dim.enable", checked)
        }

        WSettingsSlider {
            visible: Config.options?.lock?.dim?.enable ?? false
            label: Translation.tr("Dim amount")
            icon: "brightness-high"
            description: Translation.tr("How much to dim the wallpaper")
            from: 10
            to: 80
            stepSize: 5
            value: Math.round((Config.options?.lock?.dim?.opacity ?? 0.3) * 100)
            onMoved: Config.setNestedValue("lock.dim.opacity", value / 100)
            suffix: "%"
        }
    }

    WSettingsSection {
        title: Translation.tr("Screen Recording")
        icon: "record"
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
            icon: "options"
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

        WSettingsDropdown {
            label: Translation.tr("Recording audio")
            icon: "speaker"
            description: Translation.tr("Choose whether recordings include system audio, microphone, both, or no audio")
            currentValue: root.recordingAudioMode
            options: root.recordingAudioModeOptions
            onSelected: newValue => RecorderStatus.setConfiguredAudioMode(newValue)
        }

        WSettingsRow {
            visible: root.recordingAudioMode === "both"
            label: Translation.tr("System + microphone")
            icon: root.audioMixAvailable ? "speaker-settings" : "info"
            description: root.audioMixAvailable
                ? Translation.tr("iNiR combines system audio and microphone automatically. The temporary audio route is removed when recording ends")
                : Translation.tr("System and microphone audio cannot be combined on this setup. Recording will continue with whichever source is available")
        }

        WSettingsDropdown {
            visible: root.recordingAudioMode === "system" || root.recordingAudioMode === "both"
            label: Translation.tr("System audio source")
            icon: "speaker"
            description: Translation.tr("Auto follows the current default output device")
            currentValue: RecorderStatus.configuredSystemAudioSource
            options: root.availableSystemAudioSourceOptions()
            onSelected: newValue => RecorderStatus.setConfiguredSystemAudioSource(newValue)
        }

        WSettingsDropdown {
            visible: root.recordingAudioMode === "microphone" || root.recordingAudioMode === "both"
            label: Translation.tr("Microphone source")
            icon: "mic"
            description: Translation.tr("Auto follows the current default microphone")
            currentValue: RecorderStatus.configuredMicrophoneSource
            options: root.availableMicrophoneSourceOptions()
            onSelected: newValue => RecorderStatus.setConfiguredMicrophoneSource(newValue)
        }

        WSettingsTextField {
            label: Translation.tr("Recordings folder")
            icon: "folder"
            description: Translation.tr("Leave empty to use the Videos folder")
            placeholderText: Translation.tr("e.g. /home/you/Videos/Recordings")
            text: Config.options?.screenRecord?.savePath ?? ""
            onTextEdited: newText => root.setRecordingConfig("screenRecord.savePath", newText)
        }

        WSettingsTextField {
            label: Translation.tr("Screenshots folder")
            icon: "image"
            description: Translation.tr("Leave empty to use Pictures/Screenshots")
            placeholderText: Translation.tr("e.g. /home/you/Pictures/Screenshots")
            text: Config.options?.regionSelector?.savePath ?? ""
            onTextEdited: newText => Config.setNestedValue("regionSelector.savePath", newText)
        }

        WSettingsTextField {
            label: Translation.tr("Filename format")
            icon: "text-font"
            description: Translation.tr("date(1) tokens for recording filenames (without extension)")
            placeholderText: "recording_%Y-%m-%d_%H.%M.%S"
            text: Config.options?.screenRecord?.recordingNameFormat ?? "recording_%Y-%m-%d_%H.%M.%S"
            onTextEdited: newText => Config.setNestedValue("screenRecord.recordingNameFormat", newText)
        }

        WSettingsSwitch {
            label: Translation.tr("Fallback if preferred encoder fails")
            icon: "arrow-sync"
            description: Translation.tr("Retry with a safer recording path if the preferred encoder fails")
            checked: Config.options?.screenRecord?.enableFallback ?? true
            onCheckedChanged: root.setRecordingConfig("screenRecord.enableFallback", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Compress recordings for Discord")
            icon: "record"
            description: Translation.tr("Creates a separate H.264 copy that fits Discord upload limits")
            checked: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            onCheckedChanged: Config.setNestedValue("screenRecord.discordCompress.enabled", checked)
        }

        WSettingsRow {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Discord compression")
            icon: "info"
            description: Translation.tr("Two-pass compression keeps the original recording and squeezes a sharing copy. Tiny file, less drama.")
        }

        WSettingsDropdown {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Discord target size")
            icon: "pulse"
            description: Translation.tr("10 MB fits Discord Free")
            currentValue: Config.options?.screenRecord?.discordCompress?.targetSizeMb ?? 10
            options: root.recordingDiscordTargetSizeOptions
            onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.targetSizeMb", newValue)
        }

        WSettingsDropdown {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Discord max dimension")
            icon: "screenshot"
            description: Translation.tr("Lower values help long clips fit without becoming a pixel smoothie")
            currentValue: Config.options?.screenRecord?.discordCompress?.maxDimension ?? 1280
            options: root.recordingDiscordDimensionOptions
            onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.maxDimension", newValue)
        }

        WSettingsDropdown {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Discord encoder speed")
            icon: "arrow-clockwise"
            description: Translation.tr("Slower is smaller and cleaner")
            currentValue: Config.options?.screenRecord?.discordCompress?.preset ?? "slow"
            options: root.recordingSoftwarePresetOptions
            onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.preset", newValue)
        }

        WSettingsDropdown {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Discord audio bitrate")
            icon: "speaker"
            description: Translation.tr("Automatically reduced when video needs the budget")
            currentValue: Config.options?.screenRecord?.discordCompress?.audioBitrateKbps ?? 96
            options: root.recordingAudioBitrateOptions
            onSelected: newValue => Config.setNestedValue("screenRecord.discordCompress.audioBitrateKbps", newValue)
        }

        WSettingsSwitch {
            visible: Config.options?.screenRecord?.discordCompress?.enabled ?? false
            label: Translation.tr("Skip compression when already under target")
            icon: "checkmark"
            checked: Config.options?.screenRecord?.discordCompress?.onlyIfNeeded ?? true
            onCheckedChanged: Config.setNestedValue("screenRecord.discordCompress.onlyIfNeeded", checked)
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
            icon: "pulse"
            currentValue: Config.options?.screenRecord?.videoBitrateKbps ?? 12000
            options: root.recordingVideoBitrateOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.videoBitrateKbps", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio codec")
            icon: "mic"
            currentValue: Config.options?.screenRecord?.audioCodec ?? "aac"
            options: root.availableAudioCodecOptions()
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioCodec", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio bitrate")
            icon: "mic"
            currentValue: Config.options?.screenRecord?.audioBitrateKbps ?? 192
            options: root.recordingAudioBitrateOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioBitrateKbps", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset
            label: Translation.tr("Audio backend")
            icon: "speaker-settings"
            currentValue: Config.options?.screenRecord?.audioBackend ?? ""
            options: root.recordingAudioBackendOptions
            onSelected: newValue => root.setRecordingConfig("screenRecord.audioBackend", newValue)
        }

        WSettingsDropdown {
            visible: root.customRecordingPreset && root.vaapiAvailable
            label: Translation.tr("Render device")
            icon: "device-eq"
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
