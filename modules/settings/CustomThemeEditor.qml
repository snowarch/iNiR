import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 16

    // Themes directory
    readonly property string themesDir: Directories.shellConfig + "/themes"
    property var savedThemesList: []
    property string saveStatus: "" // "", "saving", "saved", "error"

    Component.onCompleted: {
        // Ensure themes directory exists
        ensureDirProcess.running = true
    }

    Process {
        id: ensureDirProcess
        command: ["/usr/bin/mkdir", "-p", root.themesDir]
        onExited: (exitCode) => {
            if (exitCode === 0) loadThemesList()
        }
    }

    function loadThemesList() {
        listThemesProcess.running = true
    }

    Process {
        id: listThemesProcess
        command: ["/usr/bin/bash", "-c", `/usr/bin/ls -1 "${root.themesDir}"/*.json 2>/dev/null | /usr/bin/xargs -I{} /usr/bin/basename {} .json`]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim()) {
                    root.savedThemesList = [...root.savedThemesList, data.trim()]
                }
            }
        }
        onStarted: root.savedThemesList = []
    }

    function saveTheme(name) {
        if (!name) return
        root.saveStatus = "saving"
        const jsonStr = JSON.stringify(Config.options.appearance.customTheme, null, 2)
        const escaped = jsonStr.replace(/'/g, "'\\''")
        const filePath = `${root.themesDir}/${name}.json`
        saveThemeProcess.command = ["/usr/bin/bash", "-c", `printf '%s' '${escaped}' > "${filePath}"`]
        saveThemeProcess.running = true
    }

    Process {
        id: saveThemeProcess
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.saveStatus = "saved"
                loadThemesList()
                saveStatusTimer.restart()
            } else {
                root.saveStatus = "error"
                saveStatusTimer.restart()
            }
        }
    }

    Timer {
        id: saveStatusTimer
        interval: 2000
        onTriggered: root.saveStatus = ""
    }

    function loadTheme(name) {
        loadThemeFileView.path = `${root.themesDir}/${name}.json`
    }

    FileView {
        id: loadThemeFileView
        path: ""
        onLoaded: {
            try {
                const theme = JSON.parse(text())
                const customTheme = Config.options?.appearance?.customTheme ?? {}
                for (let key in theme) {
                    if (customTheme.hasOwnProperty(key)) {
                        Config.setNestedValue(`appearance.customTheme.${key}`, theme[key])
                    }
                }
                root.applyToShell()
            } catch (e) {
                console.error("[CustomThemeEditor] Failed to load theme:", e)
            }
        }
    }

    function deleteTheme(name) {
        deleteThemeProcess.command = ["/usr/bin/rm", "-f", `${root.themesDir}/${name}.json`]
        deleteThemeProcess.running = true
    }

    Process {
        id: deleteThemeProcess
        onExited: loadThemesList()
    }

    function applyToShell() {
        // Force re-application by triggering a change
        ThemePresets.applyPreset("custom")
        // Also ensure ThemeService knows we're on custom
        if (ThemeService.currentTheme !== "custom") {
            ThemeService.setTheme("custom")
        }
    }

    // Invert colors for light/dark mode switch
    function invertColorsForMode(toLightMode) {
        const ct = Config.options.appearance.customTheme
        
        // Swap background and foreground colors
        const swaps = [
            ["m3background", "m3onBackground"],
            ["m3surface", "m3onSurface"],
            ["m3surfaceContainerLowest", "m3surfaceContainerHighest"],
            ["m3surfaceContainerLow", "m3surfaceContainerHigh"],
        ]
        
        swaps.forEach(([a, b]) => {
            const temp = ct[a]
            ct[a] = ct[b]
            ct[b] = temp
        })
        
        // Adjust surface containers to create proper gradient
        if (toLightMode) {
            // Light mode: lighten backgrounds
            ct.m3surfaceDim = ColorUtils.lighten(ct.m3surfaceDim, 0.7)
            ct.m3surfaceBright = "#ffffff"
            ct.m3surfaceContainer = ColorUtils.lighten(ct.m3surfaceContainer, 0.6)
        } else {
            // Dark mode: darken backgrounds  
            ct.m3surfaceDim = ColorUtils.darken(ct.m3surfaceDim, 0.7)
            ct.m3surfaceBright = ColorUtils.darken(ct.m3surfaceBright, 0.5)
            ct.m3surfaceContainer = ColorUtils.darken(ct.m3surfaceContainer, 0.6)
        }
        
        ct.darkmode = !toLightMode
        applyToShell()
    }

    // Live Preview Card
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: previewColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: previewColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "preview"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Live Preview")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                // Dark/Light segmented button
                Rectangle {
                    implicitWidth: segmentRow.implicitWidth + 8
                    implicitHeight: 32
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        id: segmentRow
                        anchors.centerIn: parent
                        spacing: 0

                        RippleButton {
                            implicitWidth: 60
                            implicitHeight: 28
                            buttonRadius: 14
                            toggled: !(Config.options.appearance.customTheme?.darkmode ?? true)
                            colBackground: toggled ? Appearance.colors.colPrimary : "transparent"
                            onClicked: {
                                if (Config.options.appearance.customTheme?.darkmode ?? true) {
                                    root.invertColorsForMode(true) // Switch to light
                                }
                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                MaterialSymbol {
                                    text: "light_mode"
                                    iconSize: 14
                                    color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                }
                                StyledText {
                                    text: "Light"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 60
                            implicitHeight: 28
                            buttonRadius: 14
                            toggled: Config.options.appearance.customTheme?.darkmode ?? true
                            colBackground: toggled ? Appearance.colors.colPrimary : "transparent"
                            onClicked: {
                                if (!(Config.options.appearance.customTheme?.darkmode ?? true)) {
                                    root.invertColorsForMode(false) // Switch to dark
                                }
                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                MaterialSymbol {
                                    text: "dark_mode"
                                    iconSize: 14
                                    color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                }
                                StyledText {
                                    text: "Dark"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: parent.parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                }
            }

            // Light mode warning
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: !(Config.options.appearance.customTheme?.darkmode ?? true)

                MaterialSymbol {
                    text: "warning"
                    iconSize: 14
                    color: Appearance.m3colors.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Light mode is experimental and may look broken. For best results, use a light preset like Angel Light, Catppuccin Latte, or Sakura.")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                }
            }

            // Mini UI Preview
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 120
                radius: Appearance.rounding.small
                color: Appearance.m3colors.m3background
                clip: true

                // Simulated bar
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 28
                    color: Appearance.m3colors.m3surfaceContainerLow

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        // Workspace indicators
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 18
                                height: 18
                                radius: Appearance.rounding.unsharpen
                                color: index === 0 ? Appearance.m3colors.m3primary : Appearance.m3colors.m3surfaceContainer
                                
                                StyledText {
                                    anchors.centerIn: parent
                                    text: (index + 1).toString()
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: index === 0 ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3onSurface
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Clock
                        StyledText {
                            text: "12:34"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.m3colors.m3onSurface
                        }

                        // Tray icons
                        Repeater {
                            model: ["wifi", "volume_up", "battery_full"]
                            MaterialSymbol {
                                required property string modelData
                                text: modelData
                                iconSize: 14
                                color: Appearance.m3colors.m3onSurfaceVariant
                            }
                        }
                    }
                }

                // Simulated content area
                RowLayout {
                    anchors.fill: parent
                    anchors.topMargin: 32
                    anchors.margins: 8
                    spacing: 8

                    // Simulated sidebar
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.fillHeight: true
                        radius: Appearance.rounding.unsharpenmore
                        color: Appearance.m3colors.m3surfaceContainerLow

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 4

                            Repeater {
                                model: ["search", "chat", "translate"]
                                Rectangle {
                                    required property int index
                                    required property string modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 22
                                    radius: Appearance.rounding.unsharpen
                                    color: index === 0 ? Appearance.m3colors.m3secondaryContainer : "transparent"

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 3
                                        MaterialSymbol {
                                            text: modelData
                                            iconSize: 12
                                            color: index === 0 ? Appearance.m3colors.m3onSecondaryContainer : Appearance.m3colors.m3onSurfaceVariant
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Simulated main content
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Appearance.rounding.unsharpenmore
                        color: Appearance.m3colors.m3surfaceContainer

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // Title
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 12
                                radius: Appearance.rounding.unsharpen
                                color: Appearance.m3colors.m3onSurface
                                opacity: 0.8
                                Layout.rightMargin: parent.width * 0.4
                            }

                            // Subtitle
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 8
                                radius: Appearance.rounding.unsharpen
                                color: Appearance.m3colors.m3onSurfaceVariant
                                opacity: 0.5
                                Layout.rightMargin: parent.width * 0.2
                            }

                            Item { Layout.fillHeight: true }

                            // Buttons row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    implicitWidth: 50
                                    implicitHeight: 20
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3primary

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "OK"
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.m3colors.m3onPrimary
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 50
                                    implicitHeight: 20
                                    radius: Appearance.rounding.verysmall
                                    color: Appearance.m3colors.m3secondaryContainer

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "Cancel"
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.m3colors.m3onSecondaryContainer
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Color strip preview
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { color: "m3primary", label: "P" },
                        { color: "m3secondary", label: "S" },
                        { color: "m3tertiary", label: "T" },
                        { color: "m3error", label: "E" },
                        { color: "m3success", label: "✓" },
                        { color: "m3background", label: "BG" },
                        { color: "m3surface", label: "SF" },
                        { color: "m3surfaceContainer", label: "SC" }
                    ]

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 24
                        radius: Appearance.rounding.unsharpen
                        color: Appearance.m3colors[modelData.color] ?? "#888"

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: ColorUtils.contrastColor(parent.color)
                        }
                    }
                }
            }
        }
    }

    // Preset categories for dropdown
    readonly property var presetCategories: [
        { name: "Angel (Dark)", colors: ThemePresets.angelColors },
        { name: "Angel (Light)", colors: ThemePresets.angelLightColors },
        { name: "Gruvbox Material", colors: ThemePresets.gruvboxMaterialColors },
        { name: "Catppuccin Mocha", colors: ThemePresets.catppuccinMochaColors },
        { name: "Catppuccin Latte", colors: ThemePresets.catppuccinLatteColors },
        { name: "Nord", colors: ThemePresets.nordColors },
        { name: "Material Black", colors: ThemePresets.materialBlackColors },
        { name: "Kanagawa", colors: ThemePresets.kanagawaColors },
        { name: "Kanagawa Dragon", colors: ThemePresets.kanagawaDragonColors },
        { name: "Samurai", colors: ThemePresets.samuraiColors },
        { name: "Tokyo Night", colors: ThemePresets.tokyoNightColors },
        { name: "Sakura", colors: ThemePresets.sakuraColors },
        { name: "Zen Garden", colors: ThemePresets.zenGardenColors }
    ]
    property string selectedPresetName: ""

    // Quick Adjustments - Global sliders for the entire palette
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: quickAdjustColumn.implicitHeight + 20
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: quickAdjustColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "tune"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Quick Adjustments")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                // Reset button
                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: 14
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "restart_alt"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }

                    onClicked: {
                        saturationSlider.value = 100
                        brightnessSlider.value = 0
                        temperatureSlider.value = 0
                    }

                    StyledToolTip { text: Translation.tr("Reset adjustments"); visible: parent.buttonHovered }
                }
            }

            // Saturation slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "palette"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Saturation")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    Layout.preferredWidth: 70
                }

                StyledSlider {
                    id: saturationSlider
                    Layout.fillWidth: true
                    from: 0
                    to: 200
                    value: 100
                    stepSize: 5
                    configuration: StyledSlider.Configuration.S

                    onMoved: { root.captureOriginalColors(); adjustDebounce.restart() }
                }

                StyledText {
                    text: Math.round(saturationSlider.value) + "%"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colSubtext
                    Layout.preferredWidth: 35
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Brightness slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "brightness_6"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Brightness")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    Layout.preferredWidth: 70
                }

                StyledSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    from: -50
                    to: 50
                    value: 0
                    stepSize: 5
                    configuration: StyledSlider.Configuration.S

                    onMoved: { root.captureOriginalColors(); adjustDebounce.restart() }
                }

                StyledText {
                    text: (brightnessSlider.value >= 0 ? "+" : "") + Math.round(brightnessSlider.value)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colSubtext
                    Layout.preferredWidth: 35
                    horizontalAlignment: Text.AlignRight
                }
            }

            // Temperature slider
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "thermostat"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    text: Translation.tr("Temperature")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    Layout.preferredWidth: 70
                }

                StyledSlider {
                    id: temperatureSlider
                    Layout.fillWidth: true
                    from: -50
                    to: 50
                    value: 0
                    stepSize: 5
                    configuration: StyledSlider.Configuration.S

                    onMoved: { root.captureOriginalColors(); adjustDebounce.restart() }
                }

                StyledText {
                    text: temperatureSlider.value > 0 ? Translation.tr("Warm") : (temperatureSlider.value < 0 ? Translation.tr("Cool") : "0")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    color: temperatureSlider.value > 0 ? Appearance.m3colors.m3tertiary 
                         : (temperatureSlider.value < 0 ? Appearance.m3colors.m3primary 
                         : Appearance.colors.colSubtext)
                    Layout.preferredWidth: 35
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    // Store original colors for quick adjustments
    property var originalColors: null
    
    // Debounce timer for quick adjustments
    Timer {
        id: adjustDebounce
        interval: 50
        onTriggered: root.applyQuickAdjustments()
    }

    function captureOriginalColors() {
        if (!originalColors) {
            originalColors = JSON.parse(JSON.stringify(Config.options?.appearance?.customTheme ?? {}))
        }
    }

    function applyQuickAdjustments() {
        captureOriginalColors()
        const satFactor = saturationSlider.value / 100
        const brightDelta = brightnessSlider.value / 100
        const tempDelta = temperatureSlider.value / 100  // -0.5 to 0.5

        // Apply to all color keys
        const colorKeys = Object.keys(originalColors).filter(k => k.startsWith("m3") && typeof originalColors[k] === "string" && originalColors[k].startsWith("#"))

        for (const key of colorKeys) {
            let c = Qt.color(originalColors[key])
            // Adjust saturation
            let newSat = Math.min(1, Math.max(0, c.hslSaturation * satFactor))
            // Adjust brightness (lightness)
            let newLight = Math.min(1, Math.max(0, c.hslLightness + brightDelta))
            // Adjust temperature (hue shift toward warm/cool)
            let newHue = c.hslHue
            if (tempDelta !== 0) {
                // Warm = shift toward orange (0.08), Cool = shift toward blue (0.58)
                const targetHue = tempDelta > 0 ? 0.08 : 0.58
                const shiftAmount = Math.abs(tempDelta) * 0.15
                newHue = c.hslHue + (targetHue - c.hslHue) * shiftAmount
                if (newHue < 0) newHue += 1
                if (newHue > 1) newHue -= 1
            }
            let newColor = Qt.hsla(newHue, newSat, newLight, c.a)
            Config.setNestedValue(`appearance.customTheme.${key}`, newColor.toString())
        }

        applyToShell()
    }

    // Color Harmony - Generate secondary/tertiary from primary
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: harmonyColumn.implicitHeight + 20
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: harmonyColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "auto_fix_high"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Color Harmony")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Generate secondary and tertiary colors from your primary color using color theory.")
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            // Harmony scheme selector
            Flow {
                Layout.fillWidth: true
                spacing: 6

                property string selectedScheme: "complementary"

                Repeater {
                    model: [
                        { id: "complementary", name: Translation.tr("Complementary"), icon: "contrast" },
                        { id: "analogous", name: Translation.tr("Analogous"), icon: "gradient" },
                        { id: "triadic", name: Translation.tr("Triadic"), icon: "change_history" },
                        { id: "split", name: Translation.tr("Split"), icon: "call_split" }
                    ]

                    RippleButton {
                        required property var modelData
                        required property int index

                        implicitWidth: schemeRow.implicitWidth + 16
                        implicitHeight: 32
                        buttonRadius: 16
                        toggled: parent.selectedScheme === modelData.id
                        colBackground: toggled ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer2Hover

                        onClicked: parent.selectedScheme = modelData.id

                        contentItem: RowLayout {
                            id: schemeRow
                            anchors.centerIn: parent
                            spacing: 4

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 14
                                color: parent.parent.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: parent.parent.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }

            // Preview of generated colors
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: Translation.tr("Preview:")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }

                // Primary (source)
                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Config.options?.appearance?.customTheme?.m3primary ?? Appearance.m3colors.m3primary
                    border.width: 2
                    border.color: Appearance.colors.colOnLayer1

                    MouseArea { id: primaryMouse; anchors.fill: parent; hoverEnabled: true }
                    StyledToolTip { text: Translation.tr("Primary (source)"); visible: primaryMouse.containsMouse }
                }

                MaterialSymbol {
                    text: "arrow_forward"
                    iconSize: 14
                    color: Appearance.colors.colSubtext
                }

                // Generated secondary
                Rectangle {
                    id: previewSecondary
                    width: 24
                    height: 24
                    radius: 12
                    color: root.getHarmonyColor("secondary")

                    MouseArea { id: secondaryMouse; anchors.fill: parent; hoverEnabled: true }
                    StyledToolTip { text: Translation.tr("Secondary (generated)"); visible: secondaryMouse.containsMouse }
                }

                // Generated tertiary
                Rectangle {
                    id: previewTertiary
                    width: 24
                    height: 24
                    radius: 12
                    color: root.getHarmonyColor("tertiary")

                    MouseArea { id: tertiaryMouse; anchors.fill: parent; hoverEnabled: true }
                    StyledToolTip { text: Translation.tr("Tertiary (generated)"); visible: tertiaryMouse.containsMouse }
                }

                Item { Layout.fillWidth: true }

                // Apply button
                RippleButton {
                    implicitWidth: applyRow.implicitWidth + 20
                    implicitHeight: 32
                    buttonRadius: 16
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover

                    onClicked: root.applyHarmonyColors()

                    contentItem: RowLayout {
                        id: applyRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: "auto_awesome"
                            iconSize: 14
                            color: Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: Translation.tr("Apply")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }

    property string _harmonyScheme: "complementary"

    function getHarmonyColor(role) {
        const primary = Config.options?.appearance?.customTheme?.m3primary ?? Appearance.m3colors.m3primary
        const scheme = harmonyColumn.children[2]?.selectedScheme ?? "complementary"

        if (scheme === "complementary") {
            // Complementary: secondary = complement, tertiary = shifted complement
            const comp = ColorUtils.complementary(primary)
            return role === "secondary" ? comp : ColorUtils.shiftHue(comp, 30)
        } else if (scheme === "analogous") {
            // Analogous: colors adjacent on wheel
            const colors = ColorUtils.analogous(primary, 30)
            return role === "secondary" ? colors[0] : colors[1]
        } else if (scheme === "triadic") {
            // Triadic: evenly spaced (120°)
            const colors = ColorUtils.triadic(primary)
            return role === "secondary" ? colors[0] : colors[1]
        } else if (scheme === "split") {
            // Split complementary
            const colors = ColorUtils.splitComplementary(primary)
            return role === "secondary" ? colors[0] : colors[1]
        }
        return primary
    }

    function applyHarmonyColors(): void {
        const secondary = getHarmonyColor("secondary")
        const tertiary = getHarmonyColor("tertiary")

        // Apply secondary colors
        Config.setNestedValue('appearance.customTheme.m3secondary', secondary.toString())
        Config.setNestedValue('appearance.customTheme.m3onSecondary', ColorUtils.contrastColor(secondary).toString())
        const secondaryContainer = ColorUtils.colorWithLightness(secondary, (Config.options?.appearance?.customTheme?.darkmode ?? true) ? 0.25 : 0.85)
        Config.setNestedValue('appearance.customTheme.m3secondaryContainer', secondaryContainer.toString())
        Config.setNestedValue('appearance.customTheme.m3onSecondaryContainer', ColorUtils.contrastColor(secondaryContainer).toString())

        // Apply tertiary colors
        Config.setNestedValue('appearance.customTheme.m3tertiary', tertiary.toString())
        Config.setNestedValue('appearance.customTheme.m3onTertiary', ColorUtils.contrastColor(tertiary).toString())
        const tertiaryContainer = ColorUtils.colorWithLightness(tertiary, (Config.options?.appearance?.customTheme?.darkmode ?? true) ? 0.25 : 0.85)
        Config.setNestedValue('appearance.customTheme.m3tertiaryContainer', tertiaryContainer.toString())
        Config.setNestedValue('appearance.customTheme.m3onTertiaryContainer', ColorUtils.contrastColor(tertiaryContainer).toString())

        applyToShell()
    }

    // Actions row: Preset selector (like FontSelector) + Export/Import
    RowLayout {
        id: actionsRow
        Layout.fillWidth: true
        spacing: 12

        // Preset selector (FontSelector style)
        Item {
            Layout.fillWidth: true
            implicitHeight: presetColumn.implicitHeight

            ColumnLayout {
                id: presetColumn
                anchors.fill: parent
                spacing: 4

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "palette"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("Base Preset")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    id: presetButton
                    Layout.fillWidth: true
                    implicitHeight: 40
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        // Color preview dots
                        Row {
                            spacing: 3
                            visible: root.selectedPresetName !== ""
                            Repeater {
                                model: {
                                    let preset = root.presetCategories.find(p => p.name === root.selectedPresetName)
                                    return preset ? [preset.colors.m3primary, preset.colors.m3secondary, preset.colors.m3tertiary] : []
                                }
                                Rectangle {
                                    required property string modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.selectedPresetName || Translation.tr("Select a preset...")
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                            color: root.selectedPresetName ? Appearance.m3colors.m3onSurface : Appearance.colors.colSubtext
                        }

                        MaterialSymbol {
                            text: presetPopup.visible ? "expand_less" : "expand_more"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                    }

                    onClicked: presetPopup.visible ? presetPopup.close() : presetPopup.open()
                }
            }

            Popup {
                id: presetPopup
                y: presetColumn.height + 4
                width: parent.width
                height: Math.min(300, presetListView.contentHeight + presetSearchField.height + 24)
                padding: 8

                background: Rectangle {
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.colors.colLayer2Base
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
                    border.width: 1
                    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                                : Appearance.colors.colLayer0Border
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    TextField {
                        id: presetSearchField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Search presets...")
                        font.pixelSize: Appearance.font.pixelSize.small
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                        }
                        color: Appearance.m3colors.m3onSurface
                        placeholderTextColor: Appearance.colors.colSubtext
                    }

                    ListView {
                        id: presetListView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: {
                            let search = presetSearchField.text.toLowerCase()
                            if (search) {
                                return root.presetCategories.filter(p => p.name.toLowerCase().includes(search))
                            }
                            return root.presetCategories
                        }

                        delegate: RippleButton {
                            required property var modelData
                            required property int index
                            width: presetListView.width
                            implicitHeight: 36
                            colBackground: modelData.name === root.selectedPresetName 
                                ? Appearance.colors.colPrimaryContainer 
                                : "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            colRipple: Appearance.colors.colLayer1Active

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 8

                                Row {
                                    spacing: 3
                                    Repeater {
                                        model: [modelData.colors.m3primary, modelData.colors.m3secondary, modelData.colors.m3tertiary]
                                        Rectangle {
                                            required property string modelData
                                            width: 14
                                            height: 14
                                            radius: 7
                                            color: modelData
                                        }
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                    color: modelData.name === root.selectedPresetName 
                                        ? Appearance.m3colors.m3onPrimaryContainer 
                                        : Appearance.m3colors.m3onSurface
                                }
                            }

                            onClicked: {
                                root.selectedPresetName = modelData.name
                                copyPreset(modelData.colors)
                                presetPopup.close()
                            }
                        }
                    }
                }
            }
        }

        // Export button
        Item {
            Layout.fillWidth: true
            implicitHeight: exportColumn.implicitHeight

            ColumnLayout {
                id: exportColumn
                anchors.fill: parent
                spacing: 4

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "upload"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("Export")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Copy to clipboard")
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            text: "content_copy"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                    }

                    onClicked: exportDialog.open()
                }
            }
        }

        // Import button
        Item {
            Layout.fillWidth: true
            implicitHeight: importColumn.implicitHeight

            ColumnLayout {
                id: importColumn
                anchors.fill: parent
                spacing: 4

                RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "download"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: Translation.tr("Import")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    colRipple: Appearance.colors.colLayer1Active

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Paste from clipboard")
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        MaterialSymbol {
                            text: "content_paste"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colSubtext
                        }
                    }

                    onClicked: importDialog.open()
                }
            }
        }
    }

    // Export Dialog
    Rectangle {
        id: exportDialog
        visible: false
        Layout.fillWidth: true
        implicitHeight: exportDialogColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 2
        border.color: Appearance.colors.colPrimary

        function open() { visible = true }
        function close() { visible = false; exportCopied = false }
        property bool exportCopied: false

        ColumnLayout {
            id: exportDialogColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "upload"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Export Theme")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    text: "close"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: exportDialog.close()
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Copy the JSON below and save it to a file, or share it with others.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 120
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8

                    TextArea {
                        id: exportTextArea
                        readOnly: true
                        text: JSON.stringify(Config.options.appearance.customTheme, null, 2)
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer2
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: exportDialog.exportCopied ? Appearance.colors.colSuccessContainer : Appearance.colors.colPrimary

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: exportDialog.exportCopied ? "check" : "content_copy"
                            iconSize: 18
                            color: exportDialog.exportCopied ? Appearance.colors.colOnSuccessContainer : Appearance.colors.colOnPrimary
                        }

                        StyledText {
                            text: exportDialog.exportCopied ? Translation.tr("Copied to clipboard!") : Translation.tr("Copy to Clipboard")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: exportDialog.exportCopied ? Appearance.colors.colOnSuccessContainer : Appearance.colors.colOnPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.clipboardText = exportTextArea.text
                            exportDialog.exportCopied = true
                        }
                    }
                }
            }
        }
    }

    // Import Dialog
    Rectangle {
        id: importDialog
        visible: false
        Layout.fillWidth: true
        implicitHeight: importDialogColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 2
        border.color: Appearance.colors.colSecondary

        function open() { visible = true; importTextArea.text = "" }
        function close() { visible = false; importError = "" }
        property string importError: ""

        ColumnLayout {
            id: importDialogColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "download"
                    iconSize: 20
                    color: Appearance.colors.colSecondary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Import Theme")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    text: "close"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: importDialog.close()
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Paste a theme JSON below to import it.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 120
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: importDialog.importError ? 2 : 0
                border.color: Appearance.colors.colError
                clip: true

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 8

                    TextArea {
                        id: importTextArea
                        placeholderText: Translation.tr("Paste theme JSON here...")
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnLayer2
                        wrapMode: TextArea.Wrap
                    }
                }
            }

            // Error message
            StyledText {
                visible: importDialog.importError !== ""
                Layout.fillWidth: true
                text: importDialog.importError
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colError
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "content_paste"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            text: Translation.tr("Paste from Clipboard")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: importTextArea.text = Quickshell.clipboardText
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Appearance.rounding.small
                    color: importTextArea.text.trim() ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            text: "check"
                            iconSize: 18
                            color: importTextArea.text.trim() ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: Translation.tr("Apply Theme")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: importTextArea.text.trim() ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: importTextArea.text.trim() ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (!importTextArea.text.trim()) return
                            if (root.importThemeFromText(importTextArea.text)) {
                                importDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    function copyPreset(colors) {
        for (let key in colors) {
            Config.setNestedValue(`appearance.customTheme.${key}`, colors[key])
        }
        // Reset quick adjustments when loading a preset
        originalColors = null
        saturationSlider.value = 100
        brightnessSlider.value = 0
        temperatureSlider.value = 0
        applyToShell()
    }

    function importThemeFromText(text) {
        try {
            const imported = JSON.parse(text)
            // Validate it has at least some expected keys
            if (!imported.m3primary || !imported.m3background) {
                importDialog.importError = Translation.tr("Invalid theme: missing required color properties")
                return false
            }
            const customTheme = Config.options?.appearance?.customTheme ?? {}
            for (let key in imported) {
                if (customTheme.hasOwnProperty(key)) {
                    // Validate color format
                    const value = imported[key]
                    if (typeof value === "string" && (value.startsWith("#") || value === "true" || value === "false")) {
                        Config.setNestedValue(`appearance.customTheme.${key}`, value)
                    } else if (typeof value === "boolean") {
                        Config.setNestedValue(`appearance.customTheme.${key}`, value)
                    }
                }
            }
            // Reset quick adjustments
            originalColors = null
            saturationSlider.value = 100
            brightnessSlider.value = 0
            temperatureSlider.value = 0
            applyToShell()
            return true
        } catch (e) {
            importDialog.importError = Translation.tr("Invalid JSON format: ") + e.message
            return false
        }
    }

    // Save/Load section
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: saveLoadColumn.implicitHeight + 24
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: saveLoadColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // Header with path info
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "folder"
                    iconSize: 20
                    color: Appearance.colors.colPrimary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: Translation.tr("Saved Themes")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: "~/.config/inir/themes/"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                    }
                }

                // Status indicator
                Rectangle {
                    visible: root.saveStatus !== ""
                    implicitWidth: statusRow.implicitWidth + 12
                    implicitHeight: 24
                    radius: Appearance.rounding.small
                    color: root.saveStatus === "saved" ? Appearance.colors.colSuccessContainer 
                         : root.saveStatus === "error" ? Appearance.colors.colErrorContainer
                         : Appearance.colors.colLayer2

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: root.saveStatus === "saved" ? "check" 
                                : root.saveStatus === "error" ? "error"
                                : "sync"
                            iconSize: 14
                            color: root.saveStatus === "saved" ? Appearance.colors.colOnSuccessContainer
                                 : root.saveStatus === "error" ? Appearance.colors.colOnErrorContainer
                                 : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            text: root.saveStatus === "saved" ? Translation.tr("Saved!")
                                : root.saveStatus === "error" ? Translation.tr("Error")
                                : Translation.tr("Saving...")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.saveStatus === "saved" ? Appearance.colors.colOnSuccessContainer
                                 : root.saveStatus === "error" ? Appearance.colors.colOnErrorContainer
                                 : Appearance.colors.colOnLayer2
                        }
                    }
                }
            }

            // Save input row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer2
                    border.width: saveNameInput.activeFocus ? 2 : 0
                    border.color: Appearance.colors.colPrimary

                    TextInput {
                        id: saveNameInput
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer2
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Enter theme name...")
                            font: parent.font
                            color: Appearance.colors.colSubtext
                            visible: !parent.text && !parent.activeFocus
                        }

                        Keys.onReturnPressed: {
                            if (saveNameInput.text.trim().length > 0) {
                                root.saveTheme(saveNameInput.text.trim())
                                saveNameInput.text = ""
                            }
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Appearance.rounding.small
                    color: saveNameInput.text.trim().length > 0 
                        ? Appearance.colors.colPrimary 
                        : Appearance.colors.colLayer2
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "save"
                        iconSize: 20
                        color: saveNameInput.text.trim().length > 0 
                            ? Appearance.colors.colOnPrimary 
                            : Appearance.colors.colSubtext
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: saveNameInput.text.trim().length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const name = saveNameInput.text.trim()
                            if (!name) return
                            root.saveTheme(name)
                            saveNameInput.text = ""
                        }
                    }
                }
            }

            // Saved themes list
            Flow {
                Layout.fillWidth: true
                spacing: 8
                visible: root.savedThemesList.length > 0

                Repeater {
                    model: root.savedThemesList

                    Rectangle {
                        required property string modelData
                        implicitWidth: themeChipRow.implicitWidth + 16
                        implicitHeight: 32
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colSecondaryContainer

                        RowLayout {
                            id: themeChipRow
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialSymbol {
                                text: "palette"
                                iconSize: 16
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            StyledText {
                                text: modelData
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSecondaryContainer
                            }

                            Rectangle {
                                width: 20
                                height: 20
                                radius: Appearance.rounding.verysmall
                                color: Appearance.colors.colOnSecondaryContainer
                                opacity: deleteArea.containsMouse ? 1 : 0.3

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "close"
                                    iconSize: 14
                                    color: Appearance.colors.colSecondaryContainer
                                }

                                MouseArea {
                                    id: deleteArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.deleteTheme(modelData)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.rightMargin: 30
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadTheme(modelData)
                        }
                    }
                }
            }

            // Empty state
            StyledText {
                visible: root.savedThemesList.length === 0
                text: Translation.tr("No saved themes yet. Create one above!")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Color palette cards with human-friendly descriptions
    ColorPaletteCard {
        title: Translation.tr("Accent Colors")
        icon: "palette"
        description: Translation.tr("Buttons, links, active states, and highlights")
        accentKey: "m3primary"
        colors: [
            { label: "Accent", key: "m3primary", tip: "Main accent for buttons and links" },
            { label: "Text", key: "m3onPrimary", tip: "Text color on accent buttons", contrastAgainst: "m3primary" },
            { label: "Soft BG", key: "m3primaryContainer", tip: "Subtle accent backgrounds" },
            { label: "Soft Text", key: "m3onPrimaryContainer", tip: "Text on subtle backgrounds", contrastAgainst: "m3primaryContainer" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Secondary")
        icon: "filter_2"
        description: Translation.tr("Chips, tags, less prominent actions")
        accentKey: "m3secondary"
        colors: [
            { label: "Color", key: "m3secondary", tip: "Secondary accent color" },
            { label: "Text", key: "m3onSecondary", tip: "Text on secondary", contrastAgainst: "m3secondary" },
            { label: "Soft BG", key: "m3secondaryContainer", tip: "Chip and tag backgrounds" },
            { label: "Soft Text", key: "m3onSecondaryContainer", tip: "Text on chips and tags", contrastAgainst: "m3secondaryContainer" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Tertiary")
        icon: "filter_3"
        description: Translation.tr("Complementary accent for variety")
        accentKey: "m3tertiary"
        colors: [
            { label: "Color", key: "m3tertiary", tip: "Third accent color" },
            { label: "Text", key: "m3onTertiary", tip: "Text on tertiary", contrastAgainst: "m3tertiary" },
            { label: "Soft BG", key: "m3tertiaryContainer", tip: "Tertiary backgrounds" },
            { label: "Soft Text", key: "m3onTertiaryContainer", tip: "Text on tertiary bg", contrastAgainst: "m3tertiaryContainer" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Backgrounds")
        icon: "layers"
        description: Translation.tr("Main backgrounds and text colors")
        accentKey: "m3surface"
        colors: [
            { label: "Base BG", key: "m3background", tip: "Deepest background layer" },
            { label: "Surface", key: "m3surface", tip: "Card and panel backgrounds" },
            { label: "Main Text", key: "m3onSurface", tip: "Primary text color", contrastAgainst: "m3surface" },
            { label: "BG Text", key: "m3onBackground", tip: "Text on base background", contrastAgainst: "m3background" }
        ]
    }

    // Surface Containers (collapsible)
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: surfaceContainersColumn.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: surfaceContainersColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            // Header (clickable to expand)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: Appearance.rounding.small
                    color: Appearance.m3colors.m3surfaceContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "stacks"
                        iconSize: 16
                        color: Appearance.m3colors.m3onSurface
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Surface Containers")
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    text: surfaceContainersExpanded ? "expand_less" : "expand_more"
                    iconSize: 20
                    color: Appearance.colors.colSubtext
                }

                property bool surfaceContainersExpanded: false

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.surfaceContainersExpanded = !parent.surfaceContainersExpanded
                }
            }

            // Visual preview of surface layers
            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: [
                        { key: "m3surfaceContainerLowest", label: "Lowest" },
                        { key: "m3surfaceContainerLow", label: "Low" },
                        { key: "m3surfaceContainer", label: "Base" },
                        { key: "m3surfaceContainerHigh", label: "High" },
                        { key: "m3surfaceContainerHighest", label: "Highest" }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: index === 0 ? Appearance.rounding.small : (index === 4 ? Appearance.rounding.small : 0)
                        color: Config.options.appearance.customTheme?.[modelData.key] ?? "#888"

                        StyledText {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: ColorUtils.contrastColor(parent.color)
                        }
                    }
                }
            }

            // Expandable color pickers
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                visible: surfaceContainersColumn.children[0].children[4].surfaceContainersExpanded

                Repeater {
                    model: [
                        { label: "Lowest", key: "m3surfaceContainerLowest" },
                        { label: "Low", key: "m3surfaceContainerLow" },
                        { label: "Container", key: "m3surfaceContainer" },
                        { label: "High", key: "m3surfaceContainerHigh" },
                        { label: "Highest", key: "m3surfaceContainerHighest" },
                        { label: "Dim", key: "m3surfaceDim" },
                        { label: "Bright", key: "m3surfaceBright" },
                        { label: "Variant", key: "m3surfaceVariant" }
                    ]

                    ColorPickerRow {
                        required property var modelData
                        Layout.fillWidth: true
                        label: modelData.label
                        colorKey: modelData.key
                        onColorChanged: root.applyToShell()
                    }
                }
            }
        }
    }

    // Outline colors
    ColorPaletteCard {
        title: Translation.tr("Borders & Shadows")
        icon: "border_style"
        description: Translation.tr("Dividers, borders, and overlay effects")
        accentKey: "m3outline"
        colors: [
            { label: "Border", key: "m3outline", tip: "Main border color" },
            { label: "Subtle", key: "m3outlineVariant", tip: "Subtle dividers" },
            { label: "Shadow", key: "m3shadow", tip: "Drop shadow color" },
            { label: "Overlay", key: "m3scrim", tip: "Modal overlay background" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Status Colors")
        icon: "info"
        description: Translation.tr("Error messages and success indicators")
        accentKey: "m3error"
        colors: [
            { label: "Error", key: "m3error", tip: "Error and warning color" },
            { label: "Error Text", key: "m3onError", tip: "Text on error backgrounds" },
            { label: "Success", key: "m3success", tip: "Success and confirmation" },
            { label: "Success Text", key: "m3onSuccess", tip: "Text on success backgrounds" }
        ]
    }

    // Color palette card component - with inline color picker
    component ColorPaletteCard: Rectangle {
        id: paletteCard
        required property string title
        required property string icon
        property string description: ""
        required property string accentKey
        required property var colors

        Layout.fillWidth: true
        implicitHeight: paletteColumn.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1

        ColumnLayout {
            id: paletteColumn
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Header with description
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 28
                    height: 28
                    radius: Appearance.rounding.small
                    color: Config.options.appearance.customTheme?.[paletteCard.accentKey] ?? "#888"

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: paletteCard.icon
                        iconSize: 16
                        color: ColorUtils.contrastColor(parent.color)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: paletteCard.title
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        visible: paletteCard.description !== ""
                        text: paletteCard.description
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            // Horizontal color swatches (FontSelector style)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: paletteCard.colors

                    Item {
                        id: swatchItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: swatchColumn.implicitHeight

                        // Contrast calculation
                        readonly property string contrastKey: modelData.contrastAgainst ?? ""
                        readonly property color fgColor: Config.options.appearance.customTheme?.[modelData.key] ?? "#888"
                        readonly property color bgColor: contrastKey ? (Config.options.appearance.customTheme?.[contrastKey] ?? "#000") : "#000"
                        readonly property real ratio: contrastKey ? ColorUtils.contrastRatio(fgColor, bgColor) : 0
                        readonly property bool showContrast: contrastKey !== ""

                        ColumnLayout {
                            id: swatchColumn
                            anchors.fill: parent
                            spacing: 4

                            // Label with contrast indicator
                            RowLayout {
                                spacing: 4

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }

                                // Contrast badge
                                Rectangle {
                                    visible: swatchItem.showContrast
                                    implicitWidth: contrastBadge.implicitWidth + 6
                                    implicitHeight: 14
                                    radius: 7
                                    color: swatchItem.ratio >= 4.5 ? "#1a3a1a" : swatchItem.ratio >= 3 ? "#3a3a1a" : "#3a1a1a"

                                    RowLayout {
                                        id: contrastBadge
                                        anchors.centerIn: parent
                                        spacing: 2

                                        MaterialSymbol {
                                            text: swatchItem.ratio >= 4.5 ? "check" : "warning"
                                            iconSize: 8
                                            color: swatchItem.ratio >= 4.5 ? "#a8d8a8" : swatchItem.ratio >= 3 ? "#d8d8a8" : "#d8a8a8"
                                        }

                                        StyledText {
                                            text: swatchItem.ratio.toFixed(1)
                                            font.pixelSize: 8
                                            font.family: Appearance.font.family.monospace
                                            color: swatchItem.ratio >= 4.5 ? "#a8d8a8" : swatchItem.ratio >= 3 ? "#d8d8a8" : "#d8a8a8"
                                        }
                                    }

                                    StyledToolTip {
                                        text: swatchItem.ratio >= 4.5 ? Translation.tr("WCAG AA ✓ Good contrast")
                                            : swatchItem.ratio >= 3 ? Translation.tr("Low contrast - may be hard to read")
                                            : Translation.tr("Poor contrast - fails accessibility")
                                    }
                                }
                            }

                            // Color button (like FontSelector dropdown)
                            RippleButton {
                                id: swatchButton
                                Layout.fillWidth: true
                                implicitHeight: 40
                                colBackground: Appearance.colors.colLayer2
                                colBackgroundHover: Appearance.colors.colLayer2Hover
                                colRipple: Appearance.colors.colLayer2Active

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    // Color preview circle
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: Config.options.appearance.customTheme?.[modelData.key] ?? "#888"
                                        border.width: 1
                                        border.color: Appearance.colors.colOutline
                                    }

                                    // Hex value
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: (Config.options.appearance.customTheme?.[modelData.key] ?? "#888").toString().toUpperCase().substring(0, 7)
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.family: Appearance.font.family.monospace
                                        elide: Text.ElideRight
                                    }

                                    // Edit icon
                                    MaterialSymbol {
                                        text: "edit"
                                        iconSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext
                                    }
                                }

                                onClicked: {
                                    paletteCard.dialogKey = modelData.key
                                    paletteCard.dialogColor = Config.options.appearance.customTheme?.[modelData.key] ?? "#888"
                                    colorPicker.open()
                                }

                                StyledToolTip {
                                    text: modelData.tip ?? ""
                                    visible: parent.buttonHovered && (modelData.tip ?? "").length > 0
                                }
                            }
                        }
                    }
                }
            }

        }

        // Color dialog
        property string dialogKey: ""
        property color dialogColor: "#888"

        ColorDialog {
            id: colorPicker
            selectedColor: paletteCard.dialogColor
            onAccepted: {
                if (paletteCard.dialogKey !== "") {
                    Config.setNestedValue(`appearance.customTheme.${paletteCard.dialogKey}`, selectedColor.toString())
                    root.applyToShell()
                }
            }
        }
    }
}
