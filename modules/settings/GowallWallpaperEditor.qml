pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 2

    // --- State ---
    property string sourcePath: ""
    property string selectedFormat: "png"

    // Operation mode: "convert", "effects", "invert", "pixelate"
    property string operationMode: "convert"

    // Convert state
    property string selectedTheme: ""
    property string convertSource: "builtin"
    property string customThemeName: "custom"
    property var customColors: ["#89B4FA", "#CBA6F7", "#F38BA8", "#A6E3A1", "#F9E2AF", "#11111B"]
    property int editingColorIndex: -1

    // Effects state
    property string selectedEffect: "grayscale"
    property real brightnessFactor: 1.1

    // Pixelate state
    property real pixelateScale: 15

    // Upscale state
    property int upscaleScale: 2
    property string upscaleModel: "realesr-animevideov3"

    readonly property bool sourceIsAnimated: {
        const p = sourcePath
        if (p.length === 0) return false
        const lower = p.toLowerCase()
        return lower.endsWith(".gif") || lower.endsWith(".mp4") || lower.endsWith(".webm")
    }
    readonly property string sourceUrl: sourcePath.length > 0 ? `file://${sourcePath}` : ""
    readonly property bool canOperate: sourcePath.length > 0 && !sourceIsAnimated && GowallService.available && !GowallService.busy

    readonly property var filteredThemes: {
        const query = themeSearchField.text.trim().toLowerCase()
        if (query.length === 0) return GowallService.availableThemes
        return GowallService.availableThemes.filter(t => String(t).toLowerCase().includes(query))
    }

    function resolveDefaultSourcePath(): string {
        const paths = [
            Wallpapers.currentThemingWallpaperPath(),
            Wallpapers.currentMainWallpaperPath()
        ]
        for (const raw of paths) {
            const p = FileUtils.trimFileProtocol(String(raw ?? ""))
            if (p.length > 0) {
                const lower = p.toLowerCase()
                if (!lower.endsWith(".gif") && !lower.endsWith(".mp4") && !lower.endsWith(".webm"))
                    return p
            }
        }
        return ""
    }

    function runPreview(): void {
        if (!canOperate) return
        switch (operationMode) {
        case "convert":
            if (convertSource === "custom")
                GowallService.convertCustomTheme(sourcePath, customThemeName.trim(), customColors, selectedFormat)
            else if (convertSource === "inir")
                GowallService.convertCurrentTheme(sourcePath, selectedFormat)
            else if (selectedTheme.length > 0)
                GowallService.convertTheme(sourcePath, selectedTheme, selectedFormat)
            break
        case "effects":
            if (selectedEffect === "br")
                GowallService.effectBrightness(sourcePath, brightnessFactor, selectedFormat)
            else
                GowallService.effectSimple(sourcePath, selectedEffect, selectedFormat)
            break
        case "invert":
            GowallService.invert(sourcePath, selectedFormat)
            break
        case "pixelate":
            GowallService.pixelate(sourcePath, pixelateScale, selectedFormat)
            break
        case "upscale":
            GowallService.upscale(sourcePath, upscaleScale, upscaleModel, selectedFormat)
            break
        }
    }

    Component.onCompleted: {
        sourcePath = resolveDefaultSourcePath()
        if (GowallService.availableThemes.length > 0)
            selectedTheme = String(GowallService.availableThemes[0])
    }

    Connections {
        target: GowallService
        function onAvailableThemesChanged() {
            if (root.selectedTheme.length === 0 && GowallService.availableThemes.length > 0)
                root.selectedTheme = String(GowallService.availableThemes[0])
        }
    }

    // ── Not available warning ──
    RowLayout {
        visible: !GowallService.available
        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.topMargin: 4
        spacing: 8

        MaterialSymbol {
            text: "warning"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.m3colors.m3error
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("gowall is not installed. Install it from github.com/Achno/gowall to use this feature.")
            color: Appearance.m3colors.m3error
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
        }
    }

    // ── Source image ──
    ContentSubsection {
        visible: GowallService.available
        title: Translation.tr("Source image")

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 36
                buttonRadius: Appearance.rounding.small
                colBackground: SettingsMaterialPreset.groupColor
                colBackgroundHover: Appearance.colors.colLayer2Hover
                text: Translation.tr("Use current wallpaper")
                onClicked: {
                    const resolved = root.resolveDefaultSourcePath()
                    if (resolved.length > 0) root.sourcePath = resolved
                }
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { text: "wallpaper"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Use current wallpaper"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                }
            }

            RippleButton {
                implicitHeight: 36
                implicitWidth: browseRow.implicitWidth + 24
                buttonRadius: Appearance.rounding.small
                colBackground: SettingsMaterialPreset.groupColor
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: imageDialog.open()
                contentItem: RowLayout {
                    id: browseRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { text: "folder_open"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Browse"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.sourcePath.length > 0
            text: root.sourcePath.split("/").pop() ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.family: Appearance.font.family.monospace
            color: Appearance.colors.colSubtext
            elide: Text.ElideMiddle
        }

        StyledText {
            visible: root.sourceIsAnimated
            Layout.fillWidth: true
            text: Translation.tr("Animated files are not supported. Choose a static image.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3error
            wrapMode: Text.WordWrap
        }
    }

    // ── Operation mode ──
    ContentSubsection {
        visible: GowallService.available
        title: Translation.tr("Operation")

        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: root.operationMode
            onSelected: newValue => { root.operationMode = newValue }
            options: [
                { displayName: Translation.tr("Recolor"), icon: "palette", value: "convert" },
                { displayName: Translation.tr("Effects"), icon: "auto_fix_high", value: "effects" },
                { displayName: Translation.tr("Invert"), icon: "invert_colors", value: "invert" },
                { displayName: Translation.tr("Pixelate"), icon: "grid_on", value: "pixelate" },
                { displayName: Translation.tr("Upscale"), icon: "zoom_in", value: "upscale" }
            ]
        }
    }

    // ── Convert options ──
    ContentSubsection {
        visible: GowallService.available && root.operationMode === "convert"
        title: Translation.tr("Color scheme source")

        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: root.convertSource
            onSelected: newValue => { root.convertSource = newValue }
            options: [
                { displayName: Translation.tr("Built-in theme"), icon: "style", value: "builtin" },
                { displayName: Translation.tr("Current iNiR theme"), icon: "palette", value: "inir" },
                { displayName: Translation.tr("Custom palette"), icon: "edit", value: "custom" }
            ]
        }
    }

    // Theme selector
    ContentSubsection {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "builtin"
        title: Translation.tr("Theme")

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol { text: "search"; iconSize: 16; color: Appearance.colors.colSubtext }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: 16
                color: SettingsMaterialPreset.groupColor
                border.width: 1
                border.color: SettingsMaterialPreset.groupBorderColor

                TextInput {
                    id: themeSearchField
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.family: Appearance.font.family.main
                    color: Appearance.colors.colOnLayer1
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Translation.tr("Filter themes...")
                        font: parent.font
                        color: Appearance.colors.colSubtext
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(themeFlow.implicitHeight + 12, 150)
            radius: SettingsMaterialPreset.groupRadius
            color: SettingsMaterialPreset.groupColor
            border.width: 1
            border.color: SettingsMaterialPreset.groupBorderColor
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: themeFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: themeFlow
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: root.filteredThemes
                        delegate: RippleButton {
                            required property var modelData
                            implicitHeight: 28
                            implicitWidth: themeLabel.implicitWidth + 20
                            buttonRadius: 14
                            toggled: root.selectedTheme === String(modelData)
                            colBackground: toggled ? Appearance.colors.colPrimaryContainer : "transparent"
                            colBackgroundHover: toggled ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
                            onClicked: root.selectedTheme = String(modelData)
                            contentItem: StyledText {
                                id: themeLabel
                                anchors.centerIn: parent
                                text: String(modelData)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: parent.toggled ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: GowallService.loadingThemes
            text: Translation.tr("Loading themes...")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    ContentSubsection {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "inir"
        title: Translation.tr("Current iNiR palette")

        StyledText {
            Layout.fillWidth: true
            visible: !GowallService.hasCurrentThemePalette
            text: Translation.tr("The current iNiR Material You palette is not available yet. Regenerate your wallpaper colors and try again.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        Flow {
            visible: GowallService.hasCurrentThemePalette
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: GowallService.currentThemeColors
                delegate: Rectangle {
                    required property var modelData
                    width: 90
                    height: 32
                    radius: Appearance.rounding.small
                    color: SettingsMaterialPreset.groupColor
                    border.width: 1
                    border.color: SettingsMaterialPreset.groupBorderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: Qt.color(String(modelData ?? "#888"))
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: String(modelData).toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }
    }

    // Custom palette editor
    ContentSubsection {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "custom"
        title: Translation.tr("Custom palette")

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.customColors.length
                delegate: Rectangle {
                    required property int index
                    width: 80
                    height: 32
                    radius: Appearance.rounding.small
                    color: SettingsMaterialPreset.groupColor
                    border.width: 1
                    border.color: SettingsMaterialPreset.groupBorderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Qt.color(String(root.customColors[index] ?? "#888"))
                            border.width: 1
                            border.color: Appearance.colors.colOutline
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: String(root.customColors[index]).toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.family: Appearance.font.family.monospace
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editingColorIndex = index
                            colorDialog.selectedColor = Qt.color(String(root.customColors[index] ?? "#888"))
                            colorDialog.open()
                        }
                    }
                }
            }
        }
    }

    ContentSubsection {
        visible: GowallService.available && root.operationMode === "upscale"
        title: Translation.tr("Upscale settings")
        tooltip: Translation.tr("Uses Gowall's ESRGAN backend. Requires Vulkan support on your GPU.")

        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: root.upscaleModel
            onSelected: newValue => { root.upscaleModel = newValue }
            options: [
                { displayName: Translation.tr("Fast anime/video"), icon: "speed", value: "realesr-animevideov3" },
                { displayName: Translation.tr("Balanced x4"), icon: "high_quality", value: "realesrgan-x4plus" },
                { displayName: Translation.tr("Anime x4"), icon: "animation", value: "realesrgan-x4plus-anime" }
            ]
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol { text: "zoom_out_map"; iconSize: 16; color: Appearance.colors.colSubtext }
            Slider {
                Layout.fillWidth: true
                from: 2
                to: 4
                stepSize: 1
                value: root.upscaleScale
                onMoved: root.upscaleScale = Math.round(value)
                enabled: root.upscaleModel !== "realesrgan-x4plus"
            }
            StyledText {
                text: root.upscaleModel === "realesrgan-x4plus" ? "4x" : (root.upscaleScale.toFixed(0) + "x")
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colOnLayer1
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.upscaleModel === "realesrgan-x4plus"
                ? Translation.tr("Balanced x4 always renders at 4x scale.")
                : Translation.tr("Higher scales take longer and use more GPU memory.")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: "warning"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3error
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Upscaling uses AI (ESRGAN) and requires a GPU with Vulkan support. This operation can take 1-5 minutes depending on image size and GPU power. A black result means your GPU doesn't support Vulkan.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Effects options ──
    ContentSubsection {
        visible: GowallService.available && root.operationMode === "effects"
        title: Translation.tr("Effect")

        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: root.selectedEffect
            onSelected: newValue => { root.selectedEffect = newValue }
            options: [
                { displayName: Translation.tr("Grayscale"), icon: "filter_b_and_w", value: "grayscale" },
                { displayName: Translation.tr("Flip"), icon: "swap_vert", value: "flip" },
                { displayName: Translation.tr("Mirror"), icon: "swap_horiz", value: "mirror" },
                { displayName: Translation.tr("Brightness"), icon: "brightness_6", value: "br" }
            ]
        }

        RowLayout {
            visible: root.selectedEffect === "br"
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol { text: "brightness_low"; iconSize: 16; color: Appearance.colors.colSubtext }
            Slider {
                id: brightnessSlider
                Layout.fillWidth: true
                from: 0.3; to: 2.0; stepSize: 0.05
                value: root.brightnessFactor
                onMoved: root.brightnessFactor = value
            }
            StyledText {
                text: (root.brightnessFactor * 100).toFixed(0) + "%"
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colOnLayer1
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
            }
            MaterialSymbol { text: "brightness_high"; iconSize: 16; color: Appearance.colors.colSubtext }
        }
    }

    // ── Pixelate options ──
    ContentSubsection {
        visible: GowallService.available && root.operationMode === "pixelate"
        title: Translation.tr("Pixelation scale")
        tooltip: Translation.tr("Lower values = more pixelated. Range 1–25. Large images may need lower values (3–8).")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol { text: "grid_on"; iconSize: 16; color: Appearance.colors.colSubtext }
            Slider {
                id: pixelSlider
                Layout.fillWidth: true
                from: 1; to: 25; stepSize: 1
                value: root.pixelateScale
                onMoved: root.pixelateScale = value
            }
            StyledText {
                text: root.pixelateScale.toFixed(0)
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colOnLayer1
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignRight
            }
        }
    }

    // ── Output format ──
    ContentSubsection {
        visible: GowallService.available
        title: Translation.tr("Output format")

        ConfigSelectionArray {
            enableSettingsSearch: false
            currentValue: root.selectedFormat
            onSelected: newValue => { root.selectedFormat = newValue }
            options: [
                { displayName: "PNG", icon: "image", value: "png" },
                { displayName: "WebP", icon: "image", value: "webp" },
                { displayName: "JPG", icon: "image", value: "jpg" }
            ]
        }
    }

    // ── Actions ──
    ContentSubsection {
        visible: GowallService.available
        title: ""

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 38
                enabled: root.canOperate
                buttonRadius: Appearance.rounding.small
                colBackground: SettingsMaterialPreset.groupColor
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: root.runPreview()
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        text: GowallService.busy ? "progress_activity" : "visibility"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: GowallService.busy ? Translation.tr("Processing...") : Translation.tr("Preview")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 38
                enabled: !GowallService.busy && GowallService.previewUrl.length > 0
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive
                onClicked: GowallService.applyPreview()
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { text: "check_circle"; iconSize: 16; color: Appearance.colors.colOnPrimaryContainer }
                    StyledText {
                        text: Translation.tr("Apply as wallpaper")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }
        }

        StyledText {
            visible: GowallService.error.length > 0
            Layout.fillWidth: true
            text: GowallService.error
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3error
            wrapMode: Text.WordWrap
        }
    }

    // ── Preview comparison ──
    ContentSubsection {
        visible: GowallService.available && (root.sourcePath.length > 0 || GowallService.previewUrl.length > 0)
        title: Translation.tr("Preview")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Original")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: Appearance.rounding.small
                    color: SettingsMaterialPreset.groupColor
                    border.width: 1
                    border.color: SettingsMaterialPreset.groupBorderColor
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        source: root.sourceUrl
                        cache: false
                        asynchronous: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Result")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    radius: Appearance.rounding.small
                    color: SettingsMaterialPreset.groupColor
                    border.width: 1
                    border.color: SettingsMaterialPreset.groupBorderColor
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        fillMode: Image.PreserveAspectCrop
                        source: GowallService.previewUrl
                        cache: false
                        asynchronous: true
                        visible: GowallService.previewUrl.length > 0
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: GowallService.previewUrl.length === 0
                        spacing: 4

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "image_search"
                            iconSize: Appearance.font.pixelSize.hugeass
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Hit Preview to generate")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }

    // ── Extract colors ──
    ContentSubsection {
        visible: GowallService.available
        title: Translation.tr("Extract palette from image")

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            RippleButton {
                implicitHeight: 32
                implicitWidth: extractRow.implicitWidth + 20
                enabled: root.canOperate
                buttonRadius: Appearance.rounding.small
                colBackground: SettingsMaterialPreset.groupColor
                colBackgroundHover: Appearance.colors.colLayer2Hover
                onClicked: GowallService.extract(root.sourcePath, 8)
                contentItem: RowLayout {
                    id: extractRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { text: "colorize"; iconSize: 14; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Extract colors"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1 }
                }
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: GowallService.extractedColors
                delegate: Rectangle {
                    required property var modelData
                    width: 22; height: 22; radius: 11
                    color: {
                        try { return Qt.color(String(modelData)) }
                        catch(e) { return "#888" }
                    }
                    border.width: 1
                    border.color: Appearance.colors.colOutline
                    StyledToolTip { text: String(modelData) }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Copy to clipboard-like: add to custom palette
                            if (root.customColors.length < 16) {
                                root.customColors = [...root.customColors, String(modelData)]
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Dialogs ──
    FileDialog {
        id: imageDialog
        title: Translation.tr("Choose source image")
        fileMode: FileDialog.OpenFile
        nameFilters: [
            Translation.tr("Images") + " (*.png *.jpg *.jpeg *.webp *.bmp *.avif)",
            Translation.tr("All files") + " (*)"
        ]
        onAccepted: root.sourcePath = FileUtils.trimFileProtocol(String(selectedFile))
    }

    ColorDialog {
        id: colorDialog
        onAccepted: {
            if (root.editingColorIndex >= 0 && root.editingColorIndex < root.customColors.length) {
                const next = root.customColors.slice()
                next[root.editingColorIndex] = selectedColor.toString()
                root.customColors = next
            }
        }
    }
}
