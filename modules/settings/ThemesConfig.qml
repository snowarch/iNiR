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

    readonly property string savedThemesDir: Directories.shellConfig + "/themes"
    property var savedThemePresets: []

    function refreshSavedThemes(): void {
        if (!savedThemesProcess.running)
            savedThemesProcess.running = true
    }

    function applyThemeChoice(preset): void {
        if (preset.saved !== true) {
            themesGroup.activeSavedTheme = ""
            ThemeService.setTheme(preset.id)
            return
        }
        const current = Config.options?.appearance?.customTheme ?? ({})
        const updates = ({})
        for (const key in preset.colors) {
            if (current.hasOwnProperty(key))
                updates[`appearance.customTheme.${key}`] = preset.colors[key]
        }
        Config.setNestedValues(updates)
        themesGroup.activeSavedTheme = preset.id
        ThemePresets.applyPreset("custom")
        if (ThemeService.currentTheme !== "custom")
            ThemeService.setTheme("custom")
    }

    Process {
        id: savedThemesProcess
        command: ["/usr/bin/bash", "-lc", `for f in "${root.savedThemesDir}"/*.json; do [ -f "$f" ] || continue; /usr/bin/jq -c --arg name "$(/usr/bin/basename "$f" .json)" '{id:("saved:" + $name),name:$name,description:"Saved custom theme",tags:["saved"],saved:true,colors:.}' "$f"; done`]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const preset = JSON.parse(data)
                    root.savedThemePresets = [...root.savedThemePresets, preset]
                } catch (e) {
                    console.warn("[ThemesConfig] Skipping invalid saved theme entry:", e)
                }
            }
        }
        onStarted: root.savedThemePresets = []
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.visible && customThemeEditorSection.expanded
        triggeredOnStart: true
        onTriggered: root.refreshSavedThemes()
    }

    Component.onCompleted: root.refreshSavedThemes()

    function _log(...args): void {
        if (Quickshell.env("QS_DEBUG") === "1") console.log(...args);
    }

    settingsPageIndex: 4
    settingsPageName: Translation.tr("Themes")
    property string activeSection: "colors"

    SettingsTaskNavigator {
        icon: "palette"
        title: Translation.tr("Themes")
        description: Translation.tr("Choose colors and the global visual language first; typography, motion and expert theme tooling stay in their own focused views.")
        summary: Translation.tr("Colors · style · typography · motion · advanced")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Colors"), icon: "palette", value: "colors" },
            { displayName: Translation.tr("Style"), icon: "style", value: "style" },
            { displayName: Translation.tr("Type"), icon: "text_format", value: "type" },
            { displayName: Translation.tr("Motion"), icon: "animation", value: "motion" },
            { displayName: Translation.tr("Advanced"), icon: "construction", value: "advanced" }
        ]
    }

    function isFontInstalled(fontName) {
        if (!fontName || fontName.trim() === "") return false
        var testFont = Qt.font({ family: fontName, pixelSize: 12 })
        return testFont.family.toLowerCase() === fontName.toLowerCase()
    }

    SettingsCardSection {
        settingsTaskSection: "colors"
        visible: root.activeSection === "colors"
        expanded: true
        icon: "palette"
        title: Translation.tr("Color Themes")

        SettingsGroup {
            id: themesGroup

            property string searchQuery: ""
            property int selectedTab: Persistent.states?.settings?.themeTab ?? 0  // 0=All, 1=Dark, 2=Light
            onSelectedTabChanged: if (Persistent.ready && Persistent.states?.settings)
                Persistent.states.settings.themeTab = selectedTab
            property string selectedTag: Persistent.states?.settings?.themeTag ?? ""  // Single active tag filter
            onSelectedTagChanged: if (Persistent.ready && Persistent.states?.settings)
                Persistent.states.settings.themeTag = selectedTag
            property string activeSavedTheme: ""

            function isDarkTheme(preset) {
                if (preset.id === "auto" || preset.id === "custom") return true
                if (!preset.colors) return true
                const bg = preset.colors.m3background ?? Appearance.colors.colLayer0
                const r = parseInt(bg.slice(1, 3), 16) / 255
                const g = parseInt(bg.slice(3, 5), 16) / 255
                const b = parseInt(bg.slice(5, 7), 16) / 255
                return (0.299 * r + 0.587 * g + 0.114 * b) < 0.5
            }

            function toggleTag(tagId) {
                // Single selection: click same tag to deselect, different tag to switch
                selectedTag = (selectedTag === tagId) ? "" : tagId
            }

            readonly property var filteredPresets: {
                let result = []
                const favorites = Config.options?.appearance?.favoriteThemes ?? []
                const available = ThemePresets.presets.concat(root.savedThemePresets)
                for (let i = 0; i < available.length; i++) {
                    const preset = available[i]
                    // Dark/Light filter
                    if (selectedTab === 1 && !isDarkTheme(preset)) continue
                    if (selectedTab === 2 && isDarkTheme(preset)) continue
                    // Tag filter - single tag selection
                    if (selectedTag.length > 0) {
                        const presetTags = preset.tags ?? []
                        if (!presetTags.includes(selectedTag)) continue
                    }
                    // Search filter
                    if (searchQuery.length > 0) {
                        const query = searchQuery.toLowerCase()
                        const name = (preset.name ?? "").toLowerCase()
                        const desc = (preset.description ?? "").toLowerCase()
                        if (!name.includes(query) && !desc.includes(query)) continue
                    }
                    result.push(preset)
                }
                // Sort: favorites first
                result.sort((a, b) => {
                    const aFav = favorites.includes(a.id) ? 0 : 1
                    const bFav = favorites.includes(b.id) ? 0 : 1
                    return aFav - bFav
                })
                return result
            }
            readonly property var filteredSavedPresets: filteredPresets.filter(preset => preset.saved === true)
            readonly property var filteredBuiltInPresets: filteredPresets.filter(preset => preset.saved !== true)

            // Compact search + filter row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Search
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 16
                    color: Appearance.colors.colLayer1
                    border.width: searchField.activeFocus ? 1.5 : 0
                    border.color: Appearance.colors.colPrimary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 6

                        MaterialSymbol {
                            text: "search"
                            iconSize: 14
                            color: Appearance.colors.colSubtext
                        }

                        TextInput {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.family: Appearance.font.family.main
                            color: Appearance.colors.colOnLayer1
                            clip: true
                            onTextChanged: themesGroup.searchQuery = text

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Translation.tr("Search...")
                                font: parent.font
                                color: Appearance.colors.colSubtext
                                opacity: 0.6
                                visible: !parent.text && !parent.activeFocus
                            }
                        }

                        MaterialSymbol {
                            visible: searchField.text.length > 0
                            text: "close"
                            iconSize: 12
                            color: Appearance.colors.colSubtext

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                // Soften colors toggle
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: Config.options?.appearance?.softenColors ? Appearance.colors.colPrimary : Appearance.colors.colLayer1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "opacity"
                        iconSize: 16
                        color: Config.options?.appearance?.softenColors ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                    }

                    MouseArea {
                        id: softenMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const val = !(Config.options?.appearance?.softenColors ?? true)
                            Config.setNestedValue("appearance.softenColors", val)
                            // Regenerate theme (for auto theme, regenerates from wallpaper)
                            ThemeService.regenerateAutoTheme()
                        }
                    }

                    StyledToolTip { text: Translation.tr("Soften colors (less intense)"); visible: softenMouse.containsMouse }
                }

                // Tab pills
                Row {
                    spacing: 4

                    Repeater {
                        model: [
                            { icon: "apps", tip: "All" },
                            { icon: "dark_mode", tip: "Dark" },
                            { icon: "light_mode", tip: "Light" }
                        ]

                        Rectangle {
                            required property var modelData
                            required property int index

                            width: 28
                            height: 28
                            radius: 14
                            color: themesGroup.selectedTab === index
                                ? Appearance.colors.colPrimary
                                : tabMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: 14
                                color: themesGroup.selectedTab === index
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnLayer1
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: themesGroup.selectedTab = index
                            }

                            StyledToolTip { text: modelData.tip; visible: tabMouse.containsMouse }
                        }
                    }
                }
            }

            // Tag filters
            Flow {
                id: tagFlow
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 4

                property bool hovered: false

                Repeater {
                    // Filter tags based on selectedTab (exclude dark/light since we have tabs)
                    model: ThemePresets.availableTags.filter(t => t.id !== "dark" && t.id !== "light")

                    Rectangle {
                        required property var modelData

                        readonly property bool isActive: themesGroup.selectedTag === modelData.id

                        width: tagRow.implicitWidth + 12
                        height: 24
                        radius: 12
                        color: isActive ? Appearance.colors.colPrimaryContainer
                             : tagMouse.containsMouse ? Appearance.colors.colLayer1Hover
                             : Appearance.colors.colLayer1

                        RowLayout {
                            id: tagRow
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialSymbol {
                                text: modelData.icon
                                iconSize: 12
                                color: parent.parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                text: modelData.name
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: parent.parent.isActive ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                            }
                        }

                        MouseArea {
                            id: tagMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: themesGroup.toggleTag(modelData.id)
                            onContainsMouseChanged: tagFlow.hovered = containsMouse
                        }
                    }
                }

                // Clear tag button
                Rectangle {
                    visible: themesGroup.selectedTag.length > 0
                    width: 24
                    height: 24
                    radius: 12
                    color: clearMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 12
                        color: Appearance.colors.colSubtext
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: themesGroup.selectedTag = ""
                    }

                    StyledToolTip { text: Translation.tr("Clear filter"); visible: clearMouse.containsMouse }
                }
            }

            // Quick Access - Favorites + Recent (unified)
            ColumnLayout {
                id: quickAccessSection
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 6

                // Compute quick access items: favorites first, then recent (excluding duplicates)
                readonly property var quickAccessItems: {
                    const favs = Config.options?.appearance?.favoriteThemes ?? []
                    const recent = Config.options?.appearance?.recentThemes ?? []

                    // Collect IDs: favorites first, then recent (excluding duplicates)
                    let ids = favs.slice()
                    let recentCount = 0
                    for (let i = 0; i < recent.length && recentCount < 4; i++) {
                        if (!favs.includes(recent[i])) {
                            ids.push(recent[i])
                            recentCount++
                        }
                    }

                    // Map to presets
                    let result = []
                    for (let i = 0; i < ids.length; i++) {
                        const preset = ThemePresets.presets.find(p => p.id === ids[i])
                        if (preset) result.push(preset)
                    }
                    return result
                }

                visible: quickAccessItems.length > 0 && themesGroup.selectedTag.length === 0 && themesGroup.searchQuery.length === 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "bolt"
                        iconSize: 14
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        text: Translation.tr("Quick Access")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        visible: (Config.options?.appearance?.favoriteThemes?.length ?? 0) > 0
                        text: "★ " + (Config.options?.appearance?.favoriteThemes?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colTertiary
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: quickAccessSection.quickAccessItems

                        ThemePresetCard {
                            required property var modelData
                            width: Math.min(160, (parent.width - 8) / 3)
                            preset: modelData
                            onClicked: ThemeService.setTheme(modelData.id)
                        }
                    }
                }
            }

            // Wallpaper Dominant Colors
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 6
                visible: Config.options?.background?.wallpaperPath?.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("Wallpaper Colors")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colSubtext
                    }

                    Item { Layout.fillWidth: true }

                    // Copy color button
                    StyledText {
                        text: Translation.tr("Click to copy")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                    }
                }

                ColorQuantizer {
                    id: wallpaperQuantizer
                    property string wallpaperPath: Config.options?.background?.wallpaperPath ?? ""
                    property bool isVideo: wallpaperPath.endsWith(".mp4") || wallpaperPath.endsWith(".webm")
                    source: wallpaperPath.length > 0 ? Qt.resolvedUrl(isVideo ? Config.options?.background?.thumbnailPath : wallpaperPath) : ""
                    depth: 3  // 2^3 = 8 colors
                    rescaleSize: 64
                }

                Row {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: wallpaperQuantizer.colors ?? []

                        Rectangle {
                            required property var modelData
                            required property int index

                            width: (parent.width - 28) / 8
                            height: 28
                            radius: 6
                            color: modelData ?? "transparent"
                            border.width: colorMouse.containsMouse ? 2 : 0
                            border.color: Appearance.colors.colOnLayer1

                            MouseArea {
                                id: colorMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData) Quickshell.clipboardText = String(modelData).toUpperCase()
                                }
                            }

                            StyledToolTip {
                                text: modelData ? String(modelData).toUpperCase() : ""
                                visible: colorMouse.containsMouse && modelData
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                spacing: 6
                visible: themesGroup.filteredSavedPresets.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    MaterialSymbol {
                        text: "folder_special"
                        iconSize: 15
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: Translation.tr("Saved themes")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: themesGroup.filteredSavedPresets.length.toString()
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: Translation.tr("Created in Custom Theme Editor")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: themesGroup.filteredSavedPresets

                        ThemePresetCard {
                            required property var modelData
                            width: Math.max(140, (parent.width - 8) / 3)
                            preset: modelData
                            forceActive: themesGroup.activeSavedTheme === modelData.id
                            onClicked: root.applyThemeChoice(modelData)
                        }
                    }
                }
            }

            // Built-in theme grid - scrollable with 3 columns
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: Math.min(300, themeGridContent.implicitHeight + 12)
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.small
                clip: true

                Behavior on Layout.preferredHeight {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                ScrollView {
                    id: themeScrollView
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: themeGridContent.implicitHeight > parent.height - 12 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

                    Grid {
                        id: themeGridContent
                        width: themeScrollView.availableWidth
                        columns: 3
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: themesGroup.filteredBuiltInPresets

                            ThemePresetCard {
                                required property var modelData
                                width: (themeGridContent.width - themeGridContent.columnSpacing * 2) / 3
                                preset: modelData
                                forceActive: modelData.saved === true && themesGroup.activeSavedTheme === modelData.id
                                onClicked: root.applyThemeChoice(modelData)
                            }
                        }
                    }
                }

                // Empty state overlay
                MaterialPlaceholderMessage {
                    anchors.centerIn: parent
                    maximumWidth: 300
                    shown: themesGroup.filteredPresets.length === 0
                    icon: "search_off"
                    text: Translation.tr("No themes found")
                    explanation: themesGroup.searchQuery.length > 0
                        ? Translation.tr("Try a broader search or clear the filter")
                        : Translation.tr("Theme presets will appear here")
                    compact: true
                    shape: MaterialShape.Shape.Bun
                }
            }

            ConfigSwitch {
                buttonIcon: "invert_colors"
                text: Translation.tr("Invert colors (complementary)")
                checked: Config.options?.appearance?.colorInvert ?? false
                onCheckedChanged: Config.setNestedValue("appearance.colorInvert", checked)
                StyledToolTip {
                    text: Translation.tr("Rotate every color 180° on the color wheel, producing the complementary palette. Shell-only: terminals, GTK and other external apps keep their original colors.")
                }
            }
        }
    }

    // Scheme Variant Section
    SettingsCardSection {
        settingsTaskSection: "colors"
        visible: root.activeSection === "colors"
        expanded: true
        icon: "tune"
        title: Translation.tr("Scheme Variant")

        SettingsGroup {
            StyledText {
                text: Translation.tr("Adjust the color generation algorithm. Applies to both wallpaper-based and static themes.")
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            ConfigSelectionArray {
                currentValue: Config.options?.appearance?.palette?.type ?? "auto"
                onSelected: newValue => {
                    Config.setNestedValue("appearance.palette.type", newValue)
                    if (!ThemeService.isAutoTheme) {
                        // Manual preset: apply variant immediately via MaterialThemeLoader
                        const hex = MaterialThemeLoader.colorToHex(Appearance.m3colors.m3primary)
                        const mode = Appearance.m3colors.darkmode ? "dark" : "light"
                        MaterialThemeLoader.applySchemeVariant(hex, newValue, mode)
                    }
                    // Auto theme: ThemeService detects palette type change in
                    // liveRegenSignature and regenerates automatically.
                }
                options: [
                    { "value": "auto", "displayName": Translation.tr("Auto") },
                    { "value": "scheme-content", "displayName": Translation.tr("Content") },
                    { "value": "scheme-expressive", "displayName": Translation.tr("Expressive") },
                    { "value": "scheme-fidelity", "displayName": Translation.tr("Fidelity") },
                    { "value": "scheme-fruit-salad", "displayName": Translation.tr("Fruit Salad") },
                    { "value": "scheme-monochrome", "displayName": Translation.tr("Monochrome") },
                    { "value": "scheme-neutral", "displayName": Translation.tr("Neutral") },
                    { "value": "scheme-rainbow", "displayName": Translation.tr("Rainbow") },
                    { "value": "scheme-tonal-spot", "displayName": Translation.tr("Tonal Spot") }
                ]
            }

            ConfigSwitch {
                buttonIcon: "contrast"
                text: Translation.tr("Auto light/dark from wallpaper")
                checked: Config.options?.appearance?.wallpaperTheming?.autoDarkLightMode ?? false
                onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.autoDarkLightMode", checked)
                StyledToolTip {
                    text: Translation.tr("Pick the light or dark scheme from each wallpaper's brightness so text stays readable. Applies on every wallpaper change, overriding the manual dark-mode toggle.")
                }
            }
        }
    }

    // Motion Section
    SettingsCardSection {
        settingsTaskSection: "motion"
        visible: root.activeSection === "motion" && (Config.options?.panelFamily ?? "ii") !== "waffle"
        expanded: true
        icon: "animation"
        title: Translation.tr("Motion")

        component MotionRow: RowLayout {
            id: motionRow
            Layout.fillWidth: true
            spacing: 8

            required property string label
            required property string tooltip
            required property string key

            // Short, human words instead of motion-design jargon — the label is the
            // explanation, so the dropdown never needs to truncate or carry a tooltip.
            readonly property var curveOptions: [
                { displayName: Translation.tr("Default"), value: "default" },
                { displayName: Translation.tr("Smooth"), value: "standard" },
                { displayName: Translation.tr("Speed up"), value: "standardAccel" },
                { displayName: Translation.tr("Ease out"), value: "standardDecel" },
                { displayName: Translation.tr("Swoop"), value: "emphasized" },
                { displayName: Translation.tr("Swoop in"), value: "emphasizedAccel" },
                { displayName: Translation.tr("Swoop out"), value: "emphasizedDecel" },
                { displayName: Translation.tr("Bouncy"), value: "expressive" },
                { displayName: Translation.tr("Punchy"), value: "expressiveEffects" },
                { displayName: Translation.tr("Overshoot"), value: "zzzOvershoot" },
                { displayName: Translation.tr("Snap"), value: "zzzSnap" },
                { displayName: Translation.tr("Linear"), value: "linear" }
            ]

            RowLayout {
                Layout.preferredWidth: 90
                spacing: 2

                StyledText {
                    text: motionRow.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }

                MaterialSymbol {
                    text: "info"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                    MouseArea {
                        id: infoArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.WhatsThisCursor
                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: infoArea.containsMouse
                            text: motionRow.tooltip
                        }
                    }
                }
            }

            StyledText {
                text: speedSlider.value.toFixed(2) + "x"
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colPrimary
                Layout.preferredWidth: 38
                horizontalAlignment: Text.AlignRight
            }

            StyledSlider {
                id: speedSlider
                Layout.fillWidth: true
                from: 0.5
                to: 2.0
                stepSize: 0.05
                value: Config.options?.appearance?.animationSpeed?.[motionRow.key] ?? 1.0
                configuration: StyledSlider.Configuration.S
                onMoved: if (!pressed) Config.setNestedValue(`appearance.animationSpeed.${motionRow.key}`, Math.round(value * 100) / 100)
            }

            StyledComboBox {
                Layout.preferredWidth: 145
                model: motionRow.curveOptions
                textRole: "displayName"
                currentIndex: {
                    const current = Config.options?.appearance?.animationCurve?.[motionRow.key] ?? "default"
                    const idx = motionRow.curveOptions.findIndex(o => o.value === current)
                    return idx >= 0 ? idx : 0
                }
                onActivated: index => Config.setNestedValue(`appearance.animationCurve.${motionRow.key}`, motionRow.curveOptions[index].value)
            }
        }

        SettingsGroup {
            ConfigSelectionArray {
                currentValue: Config.options?.appearance?.iiMotionProfile ?? "classic"
                onSelected: newValue => Config.setNestedValue("appearance.iiMotionProfile", newValue)
                options: [
                    { displayName: Translation.tr("Classic"), icon: "motion_photos_paused", value: "classic" },
                    { displayName: Translation.tr("Contextual"), icon: "gesture", value: "contextual" }
                ]
            }

            MotionRow { label: Translation.tr("Movement"); tooltip: Translation.tr("Element move & resize — used almost everywhere"); key: "movement" }
            MotionRow { label: Translation.tr("Enter/exit"); tooltip: Translation.tr("Panels & popups appearing or leaving"); key: "enterExit" }
            MotionRow { label: Translation.tr("Click"); tooltip: Translation.tr("Click feedback and fast reactive transitions"); key: "clickBounce" }
            MotionRow { label: Translation.tr("Scroll"); tooltip: Translation.tr("Scrolling lists and flickables"); key: "scroll" }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 36
                buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colLayer1Hover
                colRipple: Appearance.colLayer1Active

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    MaterialSymbol {
                        text: "restart_alt"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        text: Translation.tr("Reset to defaults")
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }

                onClicked: {
                    for (const key of ["movement", "enterExit", "clickBounce", "scroll"]) {
                        Config.setNestedValue(`appearance.animationSpeed.${key}`, 1.0)
                        Config.setNestedValue(`appearance.animationCurve.${key}`, "default")
                    }
                }
            }
        }
    }

    // Theme Scheduling Section
    SettingsCardSection {
        settingsTaskSection: "motion"
        visible: root.activeSection === "motion" && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "schedule"
        title: Translation.tr("Theme Scheduling")

        SettingsGroup {
            ConfigSwitch {
                buttonIcon: "schedule"
                text: Translation.tr("Enable automatic theme switching")
                checked: Config.options?.appearance?.themeSchedule?.enabled ?? false
                onCheckedChanged: Config.setNestedValue("appearance.themeSchedule.enabled", checked)
            }

            // Day theme selector
            RowLayout {
                visible: Config.options?.appearance?.themeSchedule?.enabled ?? false
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol { text: "light_mode"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledText { text: Translation.tr("Day theme"); Layout.fillWidth: true }

                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 32

                    RippleButton {
                        id: dayThemeBtn
                        anchors.fill: parent
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            StyledText {
                                Layout.fillWidth: true
                                text: ThemePresets.presets.find(p => p.id === (Config.options?.appearance?.themeSchedule?.dayTheme ?? "auto"))?.name ?? "Auto"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                            MaterialSymbol { text: dayThemePopup.visible ? "expand_less" : "expand_more"; iconSize: 14; color: Appearance.colors.colSubtext }
                        }

                        onClicked: dayThemePopup.visible ? dayThemePopup.close() : dayThemePopup.open()
                    }

                    Popup {
                        id: dayThemePopup
                        y: dayThemeBtn.height + 4
                        width: parent.width
                        height: Math.min(200, dayThemeList.contentHeight + 16)
                        padding: 8

                        background: Rectangle {
                            color: Appearance.colors.colLayer2Base
                            radius: Appearance.rounding.small
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                        }

                        ListView {
                            id: dayThemeList
                            anchors.fill: parent
                            clip: true
                            model: ThemePresets.presets

                            delegate: RippleButton {
                                required property var modelData
                                width: dayThemeList.width
                                implicitHeight: 28
                                colBackground: modelData.id === (Config.options?.appearance?.themeSchedule?.dayTheme ?? "auto") ? Appearance.colors.colPrimaryContainer : "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover

                                contentItem: StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    text: modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    Config.setNestedValue("appearance.themeSchedule.dayTheme", modelData.id)
                                    dayThemePopup.close()
                                }
                            }
                        }
                    }
                }
            }

            // Night theme selector
            RowLayout {
                visible: Config.options?.appearance?.themeSchedule?.enabled ?? false
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol { text: "dark_mode"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledText { text: Translation.tr("Night theme"); Layout.fillWidth: true }

                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 32

                    RippleButton {
                        id: nightThemeBtn
                        anchors.fill: parent
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            StyledText {
                                Layout.fillWidth: true
                                text: ThemePresets.presets.find(p => p.id === (Config.options?.appearance?.themeSchedule?.nightTheme ?? "auto"))?.name ?? "Auto"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }
                            MaterialSymbol { text: nightThemePopup.visible ? "expand_less" : "expand_more"; iconSize: 14; color: Appearance.colors.colSubtext }
                        }

                        onClicked: nightThemePopup.visible ? nightThemePopup.close() : nightThemePopup.open()
                    }

                    Popup {
                        id: nightThemePopup
                        y: nightThemeBtn.height + 4
                        width: parent.width
                        height: Math.min(200, nightThemeList.contentHeight + 16)
                        padding: 8

                        background: Rectangle {
                            color: Appearance.colors.colLayer2Base
                            radius: Appearance.rounding.small
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                        }

                        ListView {
                            id: nightThemeList
                            anchors.fill: parent
                            clip: true
                            model: ThemePresets.presets

                            delegate: RippleButton {
                                required property var modelData
                                width: nightThemeList.width
                                implicitHeight: 28
                                colBackground: modelData.id === (Config.options?.appearance?.themeSchedule?.nightTheme ?? "auto") ? Appearance.colors.colPrimaryContainer : "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover

                                contentItem: StyledText {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    text: modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    Config.setNestedValue("appearance.themeSchedule.nightTheme", modelData.id)
                                    nightThemePopup.close()
                                }
                            }
                        }
                    }
                }
            }

            // Time settings
            RowLayout {
                visible: Config.options?.appearance?.themeSchedule?.enabled ?? false
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol { text: "wb_sunny"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledText { text: Translation.tr("Day starts at"); Layout.fillWidth: true }

                StyledSpinBox {
                    id: dayHourSpin
                    from: 0; to: 23
                    value: parseInt((Config.options?.appearance?.themeSchedule?.dayStart ?? "06:00").split(":")[0]) || 6
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueChanged: Config.setNestedValue("appearance.themeSchedule.dayStart",
                        `${textFromValue(value)}:${dayMinSpin.textFromValue(dayMinSpin.value)}`)
                }
                StyledText { text: ":"; font.pixelSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                StyledSpinBox {
                    id: dayMinSpin
                    from: 0; to: 59; stepSize: 5
                    value: parseInt((Config.options?.appearance?.themeSchedule?.dayStart ?? "06:00").split(":")[1]) || 0
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueChanged: Config.setNestedValue("appearance.themeSchedule.dayStart",
                        `${dayHourSpin.textFromValue(dayHourSpin.value)}:${textFromValue(value)}`)
                }
            }

            RowLayout {
                visible: Config.options?.appearance?.themeSchedule?.enabled ?? false
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol { text: "bedtime"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledText { text: Translation.tr("Night starts at"); Layout.fillWidth: true }

                StyledSpinBox {
                    id: nightHourSpin
                    from: 0; to: 23
                    value: parseInt((Config.options?.appearance?.themeSchedule?.nightStart ?? "18:00").split(":")[0]) || 18
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueChanged: Config.setNestedValue("appearance.themeSchedule.nightStart",
                        `${textFromValue(value)}:${nightMinSpin.textFromValue(nightMinSpin.value)}`)
                }
                StyledText { text: ":"; font.pixelSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                StyledSpinBox {
                    id: nightMinSpin
                    from: 0; to: 59; stepSize: 5
                    value: parseInt((Config.options?.appearance?.themeSchedule?.nightStart ?? "18:00").split(":")[1]) || 0
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueChanged: Config.setNestedValue("appearance.themeSchedule.nightStart",
                        `${nightHourSpin.textFromValue(nightHourSpin.value)}:${textFromValue(value)}`)
                }
            }
        }
    }

    // Terminal Colors Section
    SettingsCardSection {
        id: terminalColorsSection
        settingsTaskSection: "advanced"
        visible: root.activeSection === "advanced" && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "terminal"
        title: Translation.tr("Terminal Colors")

        // Track which terminals are installed (detected by auto-detect)
        property var installedTerminals: ({})
        property bool detectionDone: false

        function runDetection() {
            terminalDetector.running = true
        }

        // Auto-detect on first expand
        onExpandedChanged: {
            if (expanded && !detectionDone) {
                runDetection()
            }
        }

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Adjust how terminal colors are generated from the current theme. Changes apply to all color themes.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            ConfigSwitch {
                buttonIcon: "terminal"
                text: Translation.tr("Enable terminal theming")
                checked: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true
                onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.enableTerminal", checked)
            }

            // Individual terminal toggles
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Generate color configs for:")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                // Installed count indicator
                StyledText {
                    visible: terminalColorsSection.detectionDone
                    text: {
                        const installed = terminalColorsSection.installedTerminals
                        const count = Object.values(installed).filter(v => v).length
                        return Translation.tr("%1 installed").arg(count)
                    }
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
            }

            ConfigRow {
                uniform: true
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "Kitty" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["kitty"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.kitty ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.kitty", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["kitty"] ?? false) ? 0.5 : 1
                }

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "Alacritty" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["alacritty"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.alacritty ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.alacritty", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["alacritty"] ?? false) ? 0.5 : 1
                }

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "Foot" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["foot"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.foot ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.foot", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["foot"] ?? false) ? 0.5 : 1
                }
            }

            ConfigRow {
                uniform: true
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "WezTerm" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["wezterm"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.wezterm ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.wezterm", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["wezterm"] ?? false) ? 0.5 : 1
                }

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "Ghostty" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["ghostty"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.ghostty ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.ghostty", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["ghostty"] ?? false) ? 0.5 : 1
                }

                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: "Konsole" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["konsole"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.konsole ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.konsole", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["konsole"] ?? false) ? 0.5 : 1
                }
            }

            ConfigRow {
                uniform: true
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true

                ConfigSwitch {
                    buttonIcon: "rocket_launch"
                    text: "Starship" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["starship"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.starship ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.starship", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["starship"] ?? false) ? 0.5 : 1
                    StyledToolTip {
                        text: Translation.tr("Starship prompt palette - use 'palette = \"ii\"' in starship.toml")
                    }
                }
            }

            ConfigRow {
                uniform: true
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true

                ConfigSwitch {
                    buttonIcon: "monitoring"
                    text: "btop" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["btop"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.btop ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.btop", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["btop"] ?? false) ? 0.5 : 1
                    StyledToolTip {
                        text: Translation.tr("btop++ system monitor theme")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "account_tree"
                    text: "lazygit" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["lazygit"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.lazygit ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.lazygit", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["lazygit"] ?? false) ? 0.5 : 1
                    StyledToolTip {
                        text: Translation.tr("lazygit terminal git UI theme")
                    }
                }

                ConfigSwitch {
                    buttonIcon: "folder_open"
                    text: "yazi" + (terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["yazi"] ?? false) ? " ⌀" : "")
                    checked: Config.options?.appearance?.wallpaperTheming?.terminals?.yazi ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.terminals.yazi", checked)
                    opacity: terminalColorsSection.detectionDone && !(terminalColorsSection.installedTerminals["yazi"] ?? false) ? 0.5 : 1
                    StyledToolTip {
                        text: Translation.tr("yazi file manager flavor")
                    }
                }
            }

            // Auto-detect button
            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 4
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true
                implicitWidth: detectRow.implicitWidth + 16
                implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover

                contentItem: RowLayout {
                    id: detectRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "search"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: terminalColorsSection.detectionDone
                            ? Translation.tr("Re-detect installed")
                            : Translation.tr("Auto-detect installed")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                onClicked: terminalColorsSection.runDetection()

                Process {
                    id: terminalDetector
                    command: [
                        "/usr/bin/bash",
                        "-c",
                        "for term in kitty alacritty foot wezterm ghostty konsole starship btop lazygit yazi; do " +
                        "if command -v $term &>/dev/null; then echo \"$term:true\"; " +
                        "else echo \"$term:false\"; fi; done"
                    ]
                    stdout: SplitParser {
                        onRead: (line) => {
                            const parts = line.split(':')
                            if (parts.length === 2) {
                                const term = parts[0].trim()
                                const installed = parts[1].trim() === 'true'
                                // Update installed tracking
                                const current = Object.assign({}, terminalColorsSection.installedTerminals)
                                current[term] = installed
                                terminalColorsSection.installedTerminals = current
                                // Auto-disable terminals that aren't installed (only on first detection)
                                if (!terminalColorsSection.detectionDone && !installed) {
                                    Config.setNestedValue(`appearance.wallpaperTheming.terminals.${term}`, false)
                                }
                            }
                        }
                    }
                    onExited: (exitCode, exitStatus) => {
                        terminalColorsSection.detectionDone = true
                    }
                }
            }

            // Terminal color preview
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 4

                Repeater {
                    model: 16

                    Rectangle {
                        required property int index
                        Layout.fillWidth: true
                        height: 24
                        radius: index === 0 ? 4 : (index === 15 ? 4 : 0)

                        // Preview colors based on current settings
                        color: {
                            const isDark = Appearance.m3colors.darkmode;
                            const adj = Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments ?? {};
                            const sat = adj.saturation ?? 0.65;
                            const bright = adj.brightness ?? 0.60;
                            const harmony = adj.harmony ?? 0.40;

                            // Simplified preview - actual generation is more complex
                            if (index === 0) return Appearance.m3colors.m3surfaceContainerLowest;
                            if (index === 7) return Appearance.m3colors.m3onSurfaceVariant;
                            if (index === 8) return Appearance.m3colors.m3outline;
                            if (index === 15) return Appearance.m3colors.m3onBackground;

                            // Semantic colors with approximate hues
                            const hues = [0, 0.98, 0.36, 0.12, 0.58, 0.85, 0.48, 0, 0, 0.98, 0.36, 0.12, 0.58, 0.85, 0.48, 0];
                            const isBright = index >= 9;
                            const l = isDark ? (isBright ? bright + 0.12 : bright) : (isBright ? (1 - bright) - 0.10 : (1 - bright));
                            const s = isBright ? sat + 0.08 : sat;
                            return Qt.hsla(hues[index], s, l, 1.0);
                        }

                        StyledToolTip {
                            text: ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
                                   "bright black", "bright red", "bright green", "bright yellow",
                                   "bright blue", "bright magenta", "bright cyan", "bright white"][index]
                            visible: previewMouse.containsMouse
                        }

                        MouseArea {
                            id: previewMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }

            // Debounce timer for terminal color regeneration
            // Waits for config to be saved to disk before regenerating
            Timer {
                id: terminalColorDebounce
                interval: 300  // Config write delay is 50ms, add extra buffer for disk I/O
                onTriggered: ThemeService.regenerateAutoTheme()
            }

            // Saturation slider
            ConfigSpinBox {
                id: saturationSpinBox
                icon: "palette"
                text: Translation.tr("Color Saturation") + " (%)"
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.saturation ?? 0.65) * 100)
                from: 10
                to: 80
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.saturation", value / 100);
                    terminalColorDebounce.restart();
                }
            }

            // Brightness slider
            ConfigSpinBox {
                id: brightnessSpinBox
                icon: "brightness_6"
                text: Translation.tr("Color Brightness") + " (%)"
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.brightness ?? 0.60) * 100)
                from: 35
                to: 75
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.brightness", value / 100);
                    terminalColorDebounce.restart();
                }
            }

            // Harmony slider
            ConfigSpinBox {
                id: harmonySpinBox
                icon: "tune"
                text: Translation.tr("Theme Harmony") + " (%)"
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.harmony ?? 0.40) * 100)
                from: 0
                to: 100
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.harmony", value / 100);
                    terminalColorDebounce.restart();
                }

                StyledToolTip {
                    text: Translation.tr("Shifts terminal color hues towards the theme's primary color. 0% = original colors, 100% = fully harmonized.")
                }
            }

            // Background brightness slider
            ConfigSpinBox {
                id: bgBrightnessSpinBox
                icon: "contrast"
                text: Translation.tr("Background Brightness") + " (%)"
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.backgroundBrightness ?? 0.50) * 100)
                from: 10
                to: 90
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.backgroundBrightness", value / 100);
                    terminalColorDebounce.restart();
                }

                StyledToolTip {
                    text: Translation.tr("Controls terminal background darkness. Lower = darker, higher = lighter. Matches shell surfaces at 50%.")
                }
            }

            // Reset button
            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 8
                implicitWidth: resetRow.implicitWidth + 16
                implicitHeight: 32
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover

                contentItem: RowLayout {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "restart_alt"
                        iconSize: 14
                        color: Appearance.colors.colOnLayer1
                    }

                    StyledText {
                        text: Translation.tr("Reset to defaults")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }

                onClicked: {
                    // Update spinbox values directly (this triggers onValueChanged which saves to config)
                    saturationSpinBox.value = 65;  // 0.65 * 100
                    brightnessSpinBox.value = 60;  // 0.60 * 100
                    harmonySpinBox.value = 40;     // 0.40 * 100
                    bgBrightnessSpinBox.value = 50; // 0.50 * 100
                    // Note: ThemeService.regenerateAutoTheme() is called by onValueChanged
                }
            }

            // Apply Now button - triggers terminal color application to all open terminals
            RippleButton {
                Layout.alignment: Qt.AlignRight
                Layout.topMargin: 4
                visible: Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true
                implicitWidth: applyNowRow.implicitWidth + 20
                implicitHeight: 36
                buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.small
                colBackground: Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimaryContainerActive

                contentItem: RowLayout {
                    id: applyNowRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: "sync"
                        iconSize: 16
                        color: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }

                    StyledText {
                        text: Translation.tr("Apply to open terminals")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : Appearance.colors.colOnPrimaryContainer
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }
                }

                onClicked: applyTerminalColorsProcess.running = true

                StyledToolTip {
                    text: Translation.tr("Apply current colors to all open terminal windows without restarting them")
                }

                Process {
                    id: applyTerminalColorsProcess
                    command: ["/usr/bin/bash", Directories.scriptsPath + "/colors/applycolor.sh"]
                }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "style"
        visible: root.activeSection === "style"
        expanded: true
        icon: "style"
        title: Translation.tr("Global Style")

        SettingsGroup {
            id: globalStyleGroup
            readonly property bool cardsEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && ((Config.options?.bar?.cornerStyle ?? 0) === 3)

            readonly property string derivedStyle: cardsEverywhere ? "cards" : "material"
            readonly property string currentStyle: (Config.options?.appearance?.globalStyle ?? "").length > 0
                ? Config.options?.appearance?.globalStyle ?? "material"
                : derivedStyle

            ContentSubsection {
                title: Translation.tr("Style")

                ConfigSelectionArray {
                    currentValue: globalStyleGroup.currentStyle
                    onSelected: (newValue) => {
                        _log("[GlobalStyle] selected", newValue)
                        ThemeService.setGlobalStyle(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Material"), icon: "tune", value: "material" },
                        { displayName: Translation.tr("Cards"), icon: "branding_watermark", value: "cards" },
                        { displayName: Translation.tr("Aurora"), icon: "blur_on", value: "aurora" },
                        { displayName: Translation.tr("Inir"), icon: "terminal", value: "inir" },
                        { displayName: Translation.tr("Angel"), icon: "raven", value: "angel" },
                        { displayName: Translation.tr("Regalia"), icon: "event_seat", value: "regalia" },
                        { displayName: Translation.tr("ZZZ"), icon: "bolt", value: "zzz" },
                        { displayName: Translation.tr("Cookie Shapes"), icon: "cookie", value: "cookie" }
                    ]
                }
            }

            SettingsNote {
                icon: "palette"
                text: Translation.tr("Restyles every surface in the shell. Applies instantly.")
            }

        }
    }

    SettingsCardSection {
        id: auroraStyleEditorSection
        settingsTaskSection: "style"
        visible: root.activeSection === "style" && Appearance.auroraEverywhere && !Appearance.angelEverywhere
        expanded: true
        icon: "blur_on"
        title: Translation.tr("Aurora Style Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "style" && auroraStyleEditorSection.expanded
                    && Appearance.auroraEverywhere && !Appearance.angelEverywhere
                source: "AuroraStyleEditor.qml"
            }
        }
    }

    SettingsCardSection {
        id: angelStyleEditorSection
        settingsTaskSection: "style"
        visible: root.activeSection === "style" && Appearance.angelEverywhere
        expanded: true
        icon: "raven"
        title: Translation.tr("Angel Style Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "style" && angelStyleEditorSection.expanded
                    && Appearance.angelEverywhere
                source: "AngelStyleEditor.qml"
            }
        }
    }

    SettingsCardSection {
        id: regaliaStyleEditorSection
        settingsTaskSection: "style"
        visible: root.activeSection === "style" && Appearance.regaliaEverywhere
        expanded: true
        icon: "event_seat"
        title: Translation.tr("Regalia Style Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "style" && regaliaStyleEditorSection.expanded
                    && Appearance.regaliaEverywhere
                source: "RegaliaStyleEditor.qml"
            }
        }
    }

    SettingsCardSection {
        id: zzzStyleEditorSection
        settingsTaskSection: "style"
        visible: root.activeSection === "style" && Appearance.zzzEverywhere
        expanded: true
        icon: "bolt"
        title: Translation.tr("ZZZ Style Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "style" && zzzStyleEditorSection.expanded
                    && Appearance.zzzEverywhere
                source: "ZzzStyleEditor.qml"
            }
        }
    }

    SettingsCardSection {
        id: customThemeEditorSection
        settingsTaskSection: "advanced"
        visible: root.activeSection === "advanced" && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "edit"
        title: Translation.tr("Custom Theme Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "advanced"
                    && !(Config.options?.settingsUi?.easyMode ?? false)
                    && customThemeEditorSection.expanded
                source: "CustomThemeEditor.qml"
            }
        }
    }

    SettingsCardSection {
        id: gowallEditorSection
        settingsTaskSection: "advanced"
        visible: root.activeSection === "advanced" && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "wallpaper"
        title: Translation.tr("Gowall Wallpaper Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: root.activeSection === "advanced"
                    && !(Config.options?.settingsUi?.easyMode ?? false)
                    && gowallEditorSection.expanded
                source: "GowallWallpaperEditor.qml"
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "type"
        visible: root.activeSection === "type"
        expanded: true
        icon: "text_format"
        title: Translation.tr("Typography")

        SettingsGroup {
            // Quick Presets first
            ContentSubsection {
                title: Translation.tr("Quick Presets")

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: StylePresets.presets

                        RippleButton {
                            required property var modelData
                            width: 90
                            height: 50
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer1
                            colBackgroundHover: Appearance.colors.colLayer1Hover

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2

                                MaterialSymbol {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.icon
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnSurface
                                }

                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }
                            }

                            onClicked: StylePresets.applyPreset(modelData.id)
                            StyledToolTip { text: modelData.description; visible: parent.buttonHovered }
                        }
                    }
                }
            }

            // Font Families
            ContentSubsection {
                title: Translation.tr("Font Families")

                ConfigRow {
                    uniform: true

                    FontSelector {
                        id: mainFontSelector
                        label: Translation.tr("Main")
                        icon: "font_download"
                        selectedFont: Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex"
                        onSelectedFontChanged: {
                            if (Config.options?.appearance?.typography)
                                Config.setNestedValue("appearance.typography.mainFont", selectedFont)
                        }
                        Connections {
                            target: Config.options?.appearance?.typography ?? null
                            function onMainFontChanged() { mainFontSelector.selectedFont = Config.options.appearance.typography.mainFont }
                        }
                    }

                    FontSelector {
                        id: titleFontSelector
                        label: Translation.tr("Title")
                        icon: "title"
                        selectedFont: Config.options?.appearance?.typography?.titleFont ?? "Gabarito"
                        onSelectedFontChanged: {
                            if (Config.options?.appearance?.typography)
                                Config.setNestedValue("appearance.typography.titleFont", selectedFont)
                        }
                        Connections {
                            target: Config.options?.appearance?.typography ?? null
                            function onTitleFontChanged() { titleFontSelector.selectedFont = Config.options.appearance.typography.titleFont }
                        }
                    }

                    FontSelector {
                        id: monoFontSelector
                        label: Translation.tr("Mono")
                        icon: "terminal"
                        selectedFont: Config.options?.appearance?.typography?.monospaceFont ?? "JetBrains Mono NF"
                        onSelectedFontChanged: {
                            if (Config.options?.appearance?.typography)
                                Config.setNestedValue("appearance.typography.monospaceFont", selectedFont)
                        }
                        Connections {
                            target: Config.options?.appearance?.typography ?? null
                            function onMonospaceFontChanged() { monoFontSelector.selectedFont = Config.options.appearance.typography.monospaceFont }
                        }
                    }
                }
            }

            // Size Scale
            ConfigSpinBox {
                icon: "format_size"
                text: Translation.tr("Size scale (%)")
                value: Math.round((Config.options?.appearance?.typography?.sizeScale ?? 1.0) * 100)
                from: 80
                to: 150
                stepSize: 5
                onValueChanged: {
                    if (Config.options?.appearance?.typography)
                        Config.setNestedValue("appearance.typography.sizeScale", value / 100)
                }
                StyledToolTip {
                    text: Translation.tr("Scale all text in the shell")
                }
            }

            // Variable Font Axes - Collapsible
            RippleButton {
                id: advancedToggle
                Layout.fillWidth: true
                implicitHeight: 32
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                property bool expanded: false

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 8

                    MaterialSymbol {
                        text: advancedToggle.expanded ? "expand_less" : "expand_more"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }

                    StyledText {
                        text: Translation.tr("Variable Font Axes")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                onClicked: expanded = !expanded
            }

            ColumnLayout {
                visible: advancedToggle.expanded
                Layout.fillWidth: true
                Layout.leftMargin: 16
                spacing: 4

                ConfigSpinBox {
                    id: weightSpinBox
                    icon: "line_weight"
                    text: Translation.tr("Weight")
                    from: 100
                    to: 900
                    stepSize: 50
                    value: Config.options?.appearance?.typography?.variableAxes?.wght ?? 300
                    onValueChanged: {
                        if (Config.options?.appearance?.typography?.variableAxes)
                            Config.setNestedValue("appearance.typography.variableAxes.wght", value)
                    }
                    Connections {
                        target: Config.options?.appearance?.typography?.variableAxes ?? null
                        function onWghtChanged() { weightSpinBox.value = Config.options.appearance.typography.variableAxes.wght }
                    }
                    StyledToolTip {
                        text: Translation.tr("Font weight (100=thin, 400=normal, 700=bold)")
                    }
                }

                ConfigSpinBox {
                    id: widthSpinBox
                    icon: "width"
                    text: Translation.tr("Width")
                    from: 75
                    to: 125
                    stepSize: 5
                    value: Config.options?.appearance?.typography?.variableAxes?.wdth ?? 105
                    onValueChanged: {
                        if (Config.options?.appearance?.typography?.variableAxes)
                            Config.setNestedValue("appearance.typography.variableAxes.wdth", value)
                    }
                    Connections {
                        target: Config.options?.appearance?.typography?.variableAxes ?? null
                        function onWdthChanged() { widthSpinBox.value = Config.options.appearance.typography.variableAxes.wdth }
                    }
                    StyledToolTip {
                        text: Translation.tr("Font width (75=condensed, 100=normal, 125=expanded)")
                    }
                }

                ConfigSpinBox {
                    id: gradeSpinBox
                    icon: "gradient"
                    text: Translation.tr("Grade")
                    from: -200
                    to: 150
                    stepSize: 25
                    value: Config.options?.appearance?.typography?.variableAxes?.grad ?? 150
                    onValueChanged: {
                        if (Config.options?.appearance?.typography?.variableAxes)
                            Config.setNestedValue("appearance.typography.variableAxes.grad", value)
                    }
                    Connections {
                        target: Config.options?.appearance?.typography?.variableAxes ?? null
                        function onGradChanged() { gradeSpinBox.value = Config.options.appearance.typography.variableAxes.grad }
                    }
                    StyledToolTip {
                        text: Translation.tr("Font grade (optical weight adjustment)")
                    }
                }
            }

            // Reset button
            RippleButtonWithIcon {
                Layout.topMargin: 8
                buttonRadius: Appearance.rounding.full
                materialIcon: "restart_alt"
                mainText: Translation.tr("Reset typography to defaults")
                onClicked: StylePresets.resetTypographyToDefaults()
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "type"
        visible: root.activeSection === "type"
        expanded: true
        icon: "folder"
        title: Translation.tr("Icon Theme")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("System (tray, apps)")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
            IconThemeSelector { mode: "system" }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 12
                text: Translation.tr("Dock")
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
            IconThemeSelector { mode: "dock" }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 8
                text: Translation.tr("Quickshell will restart to apply changes.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "advanced"
        visible: root.activeSection === "advanced" && !(Config.options?.settingsUi?.easyMode ?? false)
        expanded: true
        icon: "info"
        title: Translation.tr("About Themes")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Themes apply a Material 3 color palette. 'Auto' generates colors from your wallpaper automatically.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }
}
