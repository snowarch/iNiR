pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 5
    pageTitle: Translation.tr("Gowall")
    pageIcon: "wand"
    pageDescription: Translation.tr("Wallpaper editor powered by Gowall")

    // --- State ---
    property string sourcePath: ""
    property string selectedFormat: "png"
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
    WSettingsInfoBar {
        severity: WSettingsInfoBar.Severity.Warning
        message: Translation.tr("gowall is not installed. Install it from github.com/Achno/gowall to use this feature.")
        visible: !GowallService.available
    }

    // ── Source image ──
    WSettingsCard {
        visible: GowallService.available
        title: Translation.tr("Source Image")
        icon: "image"

        // Source buttons
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            implicitHeight: sourceButtonRow.implicitHeight

            RowLayout {
                id: sourceButtonRow
                anchors {
                    left: parent.left
                    right: parent.right
                }
                spacing: 6

                Rectangle {
                    id: useCurrentBtn
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Looks.radius.medium
                    color: useCurrentMa.pressed ? Looks.colors.bg2Active
                        : useCurrentMa.containsMouse ? Looks.colors.bg2Hover
                        : Looks.colors.bg2

                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        FluentIcon { icon: "image"; implicitSize: 14; color: Looks.colors.fg }
                        WText {
                            text: Translation.tr("Use current wallpaper")
                            font.pixelSize: Looks.font.pixelSize.small
                        }
                    }

                    MouseArea {
                        id: useCurrentMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const resolved = root.resolveDefaultSourcePath()
                            if (resolved.length > 0) root.sourcePath = resolved
                        }
                    }
                }

                Rectangle {
                    id: browseBtn
                    Layout.preferredWidth: browseRow.implicitWidth + 24
                    Layout.preferredHeight: 32
                    radius: Looks.radius.medium
                    color: browseMa.pressed ? Looks.colors.bg2Active
                        : browseMa.containsMouse ? Looks.colors.bg2Hover
                        : Looks.colors.bg2

                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }

                    RowLayout {
                        id: browseRow
                        anchors.centerIn: parent
                        spacing: 6

                        FluentIcon { icon: "folder"; implicitSize: 14; color: Looks.colors.fg }
                        WText {
                            text: Translation.tr("Browse")
                            font.pixelSize: Looks.font.pixelSize.small
                        }
                    }

                    MouseArea {
                        id: browseMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: imageDialog.open()
                    }
                }
            }
        }

        // Source path display
        WText {
            visible: root.sourcePath.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            text: root.sourcePath.split("/").pop() ?? ""
            font.pixelSize: Looks.font.pixelSize.small
            font.family: Looks.font.family.monospace
            color: Looks.colors.subfg
            elide: Text.ElideMiddle
        }

        // Animated warning
        WText {
            visible: root.sourceIsAnimated
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            text: Translation.tr("Animated files are not supported. Choose a static image.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.danger
            wrapMode: Text.WordWrap
        }
    }

    // ── Operation mode ──
    WSettingsCard {
        visible: GowallService.available
        title: Translation.tr("Operation")
        icon: "options"

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            implicitHeight: operationRow.implicitHeight

            Row {
                id: operationRow
                spacing: 2

                Repeater {
                    model: [
                        { label: Translation.tr("Recolor"), value: "convert", icon: "eyedropper" },
                        { label: Translation.tr("Effects"), value: "effects", icon: "wand" },
                        { label: Translation.tr("Invert"), value: "invert", icon: "arrow-sync" },
                        { label: Translation.tr("Pixelate"), value: "pixelate", icon: "apps" },
                        { label: Translation.tr("Upscale"), value: "upscale", icon: "search" }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.operationMode === modelData.value

                        width: opLabel.implicitWidth + 28
                        height: 30
                        radius: Looks.radius.medium
                        color: isSelected
                            ? Looks.colors.accent
                            : opMa.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1

                        Behavior on color {
                            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                        }

                        WText {
                            id: opLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: parent.isSelected ? Looks.font.weight.regular : Looks.font.weight.thin
                            color: parent.isSelected ? Looks.colors.bg0 : Looks.colors.fg
                        }

                        MouseArea {
                            id: opMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.operationMode = modelData.value
                        }
                    }
                }
            }
        }
    }

    // ── Convert: Color scheme source ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "convert"
        title: Translation.tr("Color Scheme Source")
        icon: "eyedropper"

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 4
            implicitHeight: convertSourceRow.implicitHeight

            Row {
                id: convertSourceRow
                spacing: 2

                Repeater {
                    model: [
                        { label: Translation.tr("Built-in"), value: "builtin" },
                        { label: Translation.tr("iNiR theme"), value: "inir" },
                        { label: Translation.tr("Custom"), value: "custom" }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.convertSource === modelData.value

                        width: csLabel.implicitWidth + 24
                        height: 28
                        radius: Looks.radius.medium
                        color: isSelected
                            ? Looks.colors.accent
                            : csMa.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1

                        Behavior on color {
                            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                        }

                        WText {
                            id: csLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: parent.isSelected ? Looks.font.weight.regular : Looks.font.weight.thin
                            color: parent.isSelected ? Looks.colors.bg0 : Looks.colors.fg
                        }

                        MouseArea {
                            id: csMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.convertSource = modelData.value
                        }
                    }
                }
            }
        }
    }

    // ── Builtin theme selector ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "builtin"
        title: Translation.tr("Theme")
        icon: "dark-theme"

        // Search field
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            implicitHeight: 32

            Rectangle {
                anchors.fill: parent
                radius: Looks.radius.small
                color: Looks.colors.bg1
                border.width: themeSearchField.activeFocus ? 1 : 0
                border.color: Looks.colors.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    FluentIcon { icon: "search"; implicitSize: 14; color: Looks.colors.subfg }

                    WTextInput {
                        id: themeSearchField
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.fg
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Filter themes...")
                            font: parent.font
                            color: Looks.colors.subfg
                            opacity: 0.6
                            visible: !parent.text && !parent.activeFocus
                        }
                    }

                    FluentIcon {
                        visible: themeSearchField.text.length > 0
                        icon: "dismiss"
                        implicitSize: 12
                        color: Looks.colors.subfg

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: themeSearchField.text = ""
                        }
                    }
                }
            }
        }

        // Theme chip grid
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            implicitHeight: Math.min(themeFlow.implicitHeight + 12, 150)

            Rectangle {
                anchors.fill: parent
                radius: Looks.radius.small
                color: Looks.colors.bg0
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
                            delegate: Rectangle {
                                required property var modelData

                                readonly property bool isActive: root.selectedTheme === String(modelData)

                                width: chipLabel.implicitWidth + 20
                                height: 28
                                radius: Looks.radius.medium
                                color: isActive
                                    ? Qt.alpha(Looks.colors.accent, 0.15)
                                    : chipMa.containsMouse ? Looks.colors.bg2Hover : "transparent"
                                border.width: isActive ? 1 : 0
                                border.color: Qt.alpha(Looks.colors.accent, 0.4)

                                Behavior on color {
                                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                                }

                                WText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: String(modelData)
                                    font.pixelSize: Looks.font.pixelSize.small
                                    color: parent.isActive ? Looks.colors.accent : Looks.colors.fg
                                }

                                MouseArea {
                                    id: chipMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedTheme = String(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Loading state
        WText {
            visible: GowallService.loadingThemes
            Layout.leftMargin: 14
            text: Translation.tr("Loading themes...")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
        }
    }

    // ── iNiR palette preview ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "inir"
        title: Translation.tr("Current iNiR Palette")
        icon: "eyedropper"

        WText {
            visible: !GowallService.hasCurrentThemePalette
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            text: Translation.tr("The current iNiR Material You palette is not available yet. Regenerate your wallpaper colors and try again.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }

        Flow {
            visible: GowallService.hasCurrentThemePalette
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            spacing: 6

            Repeater {
                model: GowallService.currentThemeColors
                delegate: Rectangle {
                    required property var modelData

                    width: 90
                    height: 32
                    radius: Looks.radius.medium
                    color: Looks.colors.bg2
                    border.width: 1
                    border.color: Looks.colors.bg2Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Qt.color(String(modelData ?? "#888"))
                            border.width: 1
                            border.color: Looks.colors.bg2Border
                        }

                        WText {
                            Layout.fillWidth: true
                            text: String(modelData).toUpperCase()
                            font.pixelSize: Looks.font.pixelSize.tiny
                            font.family: Looks.font.family.monospace
                            elide: Text.ElideRight
                            color: Looks.colors.fg
                        }
                    }
                }
            }
        }
    }

    // ── Custom palette editor ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "convert" && root.convertSource === "custom"
        title: Translation.tr("Custom Palette")
        icon: "options"

        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            spacing: 6

            Repeater {
                model: root.customColors.length
                delegate: Rectangle {
                    required property int index

                    width: 80
                    height: 32
                    radius: Looks.radius.medium
                    color: Looks.colors.bg2
                    border.width: 1
                    border.color: Looks.colors.bg2Border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Qt.color(String(root.customColors[index] ?? "#888"))
                            border.width: 1
                            border.color: Looks.colors.bg2Border
                        }

                        WText {
                            Layout.fillWidth: true
                            text: String(root.customColors[index]).toUpperCase()
                            font.pixelSize: Looks.font.pixelSize.tiny
                            font.family: Looks.font.family.monospace
                            elide: Text.ElideRight
                            color: Looks.colors.fg
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

    // ── Upscale settings ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "upscale"
        title: Translation.tr("Upscale Settings")
        icon: "search"

        WSettingsDropdown {
            label: Translation.tr("Model")
            icon: "auto"
            description: Translation.tr("AI upscaling model (requires Vulkan GPU)")
            currentValue: root.upscaleModel
            options: [
                { value: "realesr-animevideov3", displayName: Translation.tr("Fast anime/video") },
                { value: "realesrgan-x4plus", displayName: Translation.tr("Balanced x4") },
                { value: "realesrgan-x4plus-anime", displayName: Translation.tr("Anime x4") }
            ]
            onSelected: newValue => { root.upscaleModel = newValue }
        }

        WSettingsSlider {
            label: Translation.tr("Scale")
            icon: "search"
            description: root.upscaleModel === "realesrgan-x4plus"
                ? Translation.tr("Balanced x4 always renders at 4x scale.")
                : Translation.tr("Higher scales take longer and use more GPU memory.")
            from: 2; to: 4; stepSize: 1
            value: root.upscaleScale
            suffix: "x"
            enabled: root.upscaleModel !== "realesrgan-x4plus"
            onMoved: root.upscaleScale = Math.round(value)
        }

        WSettingsInfoBar {
            severity: WSettingsInfoBar.Severity.Warning
            message: Translation.tr("Upscaling uses AI (ESRGAN) and requires a GPU with Vulkan support. A black result means your GPU doesn't support Vulkan.")
        }
    }

    // ── Effects settings ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "effects"
        title: Translation.tr("Effect")
        icon: "wand"

        // Effect type tabs
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 4
            implicitHeight: effectRow.implicitHeight

            Row {
                id: effectRow
                spacing: 2

                Repeater {
                    model: [
                        { label: Translation.tr("Grayscale"), value: "grayscale" },
                        { label: Translation.tr("Flip"), value: "flip" },
                        { label: Translation.tr("Mirror"), value: "mirror" },
                        { label: Translation.tr("Brightness"), value: "br" }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: root.selectedEffect === modelData.value

                        width: effectLabel.implicitWidth + 24
                        height: 28
                        radius: Looks.radius.medium
                        color: isSelected
                            ? Looks.colors.accent
                            : effectMa.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1

                        Behavior on color {
                            animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                        }

                        WText {
                            id: effectLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: Looks.font.pixelSize.small
                            font.weight: parent.isSelected ? Looks.font.weight.regular : Looks.font.weight.thin
                            color: parent.isSelected ? Looks.colors.bg0 : Looks.colors.fg
                        }

                        MouseArea {
                            id: effectMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedEffect = modelData.value
                        }
                    }
                }
            }
        }

        // Brightness slider (visible when brightness effect selected)
        WSettingsSlider {
            visible: root.selectedEffect === "br"
            label: Translation.tr("Brightness")
            icon: "weather-sunny"
            from: 0.3; to: 2.0; stepSize: 0.05
            value: root.brightnessFactor
            suffix: "%"
            displayDecimals: 0
            sliderWidth: 200
            tooltipContent: (root.brightnessFactor * 100).toFixed(0) + "%"
            onMoved: root.brightnessFactor = value
        }
    }

    // ── Pixelate settings ──
    WSettingsCard {
        visible: GowallService.available && root.operationMode === "pixelate"
        title: Translation.tr("Pixelation")
        icon: "apps"

        WSettingsSlider {
            label: Translation.tr("Pixel scale")
            icon: "apps"
            description: Translation.tr("Lower values = more pixelated. Large images may need lower values (3-8).")
            from: 1; to: 25; stepSize: 1
            value: root.pixelateScale
            onMoved: root.pixelateScale = value
        }
    }

    // ── Output format ──
    WSettingsCard {
        visible: GowallService.available
        title: Translation.tr("Output")
        icon: "open"

        WSettingsDropdown {
            label: Translation.tr("Format")
            icon: "image"
            currentValue: root.selectedFormat
            options: [
                { value: "png", displayName: "PNG" },
                { value: "webp", displayName: "WebP" },
                { value: "jpg", displayName: "JPG" }
            ]
            onSelected: newValue => { root.selectedFormat = newValue }
        }
    }

    // ── Actions ──
    Item {
        visible: GowallService.available
        Layout.fillWidth: true
        implicitHeight: actionRow.implicitHeight

        RowLayout {
            id: actionRow
            anchors {
                left: parent.left
                right: parent.right
            }
            spacing: 6

            Rectangle {
                id: previewBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Looks.radius.medium
                opacity: root.canOperate ? 1.0 : 0.5
                color: previewMa.pressed ? Looks.colors.bg2Active
                    : previewMa.containsMouse ? Looks.colors.bg2Hover
                    : Looks.colors.bg2

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    FluentIcon {
                        icon: GowallService.busy ? "arrow-sync" : "eye"
                        implicitSize: 14
                        color: Looks.colors.fg
                    }
                    WText {
                        text: GowallService.busy ? Translation.tr("Processing...") : Translation.tr("Preview")
                        font.pixelSize: Looks.font.pixelSize.normal
                    }
                }

                MouseArea {
                    id: previewMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root.canOperate ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.canOperate
                    onClicked: root.runPreview()
                }
            }

            Rectangle {
                id: applyBtn
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: Looks.radius.medium
                opacity: !GowallService.busy && GowallService.previewUrl.length > 0 ? 1.0 : 0.5
                color: applyMa.pressed ? Looks.colors.accentActive
                    : applyMa.containsMouse ? Looks.colors.accentHover
                    : Looks.colors.accent

                Behavior on color {
                    animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    FluentIcon {
                        icon: "checkmark"
                        implicitSize: 14
                        color: Looks.colors.accentFg
                    }
                    WText {
                        text: Translation.tr("Apply as wallpaper")
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.accentFg
                    }
                }

                MouseArea {
                    id: applyMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: !GowallService.busy && GowallService.previewUrl.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: !GowallService.busy && GowallService.previewUrl.length > 0
                    onClicked: GowallService.applyPreview()
                }
            }
        }
    }

    // Error display
    WText {
        visible: GowallService.error.length > 0
        Layout.fillWidth: true
        text: GowallService.error
        font.pixelSize: Looks.font.pixelSize.small
        color: Looks.colors.danger
        wrapMode: Text.WordWrap
    }

    // ── Preview comparison ──
    WSettingsCard {
        visible: GowallService.available && (root.sourcePath.length > 0 || GowallService.previewUrl.length > 0)
        title: Translation.tr("Preview")
        icon: "eye"

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 8
            implicitHeight: previewRow.implicitHeight

            RowLayout {
                id: previewRow
                anchors {
                    left: parent.left
                    right: parent.right
                }
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    WText {
                        text: Translation.tr("Original")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        radius: Looks.radius.small
                        color: Looks.colors.bg0
                        border.width: 1
                        border.color: Looks.colors.bg2Border
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

                    WText {
                        text: Translation.tr("Result")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 160
                        radius: Looks.radius.small
                        color: Looks.colors.bg0
                        border.width: 1
                        border.color: Looks.colors.bg2Border
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

                            FluentIcon {
                                Layout.alignment: Qt.AlignHCenter
                                icon: "eyedropper"
                                implicitSize: 32
                                color: Looks.colors.subfg
                                opacity: 0.5
                            }
                            WText {
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("Hit Preview to generate")
                                font.pixelSize: Looks.font.pixelSize.small
                                color: Looks.colors.subfg
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Extract colors ──
    WSettingsCard {
        visible: GowallService.available
        title: Translation.tr("Extract Palette")
        icon: "eyedropper"

        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 14
            Layout.rightMargin: 14
            Layout.bottomMargin: 6
            implicitHeight: extractRow.implicitHeight

            RowLayout {
                id: extractRow
                anchors {
                    left: parent.left
                    right: parent.right
                }
                spacing: 6

                Rectangle {
                    id: extractBtn
                    Layout.preferredWidth: extractBtnContent.implicitWidth + 24
                    Layout.preferredHeight: 30
                    radius: Looks.radius.medium
                    opacity: root.canOperate ? 1.0 : 0.5
                    color: extractMa.pressed ? Looks.colors.bg2Active
                        : extractMa.containsMouse ? Looks.colors.bg2Hover
                        : Looks.colors.bg2

                    Behavior on color {
                        animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                    }

                    RowLayout {
                        id: extractBtnContent
                        anchors.centerIn: parent
                        spacing: 6

                        FluentIcon { icon: "eyedropper"; implicitSize: 14; color: Looks.colors.fg }
                        WText {
                            text: Translation.tr("Extract colors")
                            font.pixelSize: Looks.font.pixelSize.small
                        }
                    }

                    MouseArea {
                        id: extractMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.canOperate ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.canOperate
                        onClicked: GowallService.extract(root.sourcePath, 8)
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
                        border.color: Looks.colors.bg2Border

                        WToolTip { text: String(modelData); extraVisibleCondition: extractDotMa.containsMouse }

                        MouseArea {
                            id: extractDotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.customColors.length < 16)
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
