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
                for (let key in theme) {
                    if (Config.options.appearance.customTheme.hasOwnProperty(key))
                        Config.options.appearance.customTheme[key] = theme[key]
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
                    color: Appearance.colors.colWarning ?? "#f0a030"
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
        for (let key in colors) Config.options.appearance.customTheme[key] = colors[key]
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
            for (let key in imported) {
                if (Config.options.appearance.customTheme.hasOwnProperty(key))
                    Config.options.appearance.customTheme[key] = imported[key]
            }
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
                        text: "~/.config/illogical-impulse/themes/"
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
            { label: "Text", key: "m3onPrimary", tip: "Text color on accent buttons" },
            { label: "Soft BG", key: "m3primaryContainer", tip: "Subtle accent backgrounds" },
            { label: "Soft Text", key: "m3onPrimaryContainer", tip: "Text on subtle backgrounds" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Secondary")
        icon: "filter_2"
        description: Translation.tr("Chips, tags, less prominent actions")
        accentKey: "m3secondary"
        colors: [
            { label: "Color", key: "m3secondary", tip: "Secondary accent color" },
            { label: "Text", key: "m3onSecondary", tip: "Text on secondary" },
            { label: "Soft BG", key: "m3secondaryContainer", tip: "Chip and tag backgrounds" },
            { label: "Soft Text", key: "m3onSecondaryContainer", tip: "Text on chips and tags" }
        ]
    }

    ColorPaletteCard {
        title: Translation.tr("Tertiary")
        icon: "filter_3"
        description: Translation.tr("Complementary accent for variety")
        accentKey: "m3tertiary"
        colors: [
            { label: "Color", key: "m3tertiary", tip: "Third accent color" },
            { label: "Text", key: "m3onTertiary", tip: "Text on tertiary" },
            { label: "Soft BG", key: "m3tertiaryContainer", tip: "Tertiary backgrounds" },
            { label: "Soft Text", key: "m3onTertiaryContainer", tip: "Text on tertiary bg" }
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
            { label: "Main Text", key: "m3onSurface", tip: "Primary text color" },
            { label: "BG Text", key: "m3onBackground", tip: "Text on base background" }
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

                        ColumnLayout {
                            id: swatchColumn
                            anchors.fill: parent
                            spacing: 4

                            // Label
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
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
                    Config.options.appearance.customTheme[paletteCard.dialogKey] = selectedColor.toString()
                    root.applyToShell()
                }
            }
        }
    }
}
