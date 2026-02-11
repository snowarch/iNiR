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
    settingsPageIndex: 4
    settingsPageName: Translation.tr("Themes")

    function isFontInstalled(fontName) {
        if (!fontName || fontName.trim() === "") return false
        var testFont = Qt.font({ family: fontName, pixelSize: 12 })
        return testFont.family.toLowerCase() === fontName.toLowerCase()
    }

    SettingsCardSection {
        expanded: true
        icon: "palette"
        title: Translation.tr("Color Themes")

        SettingsGroup {
            id: themesGroup

            property string searchQuery: ""
            property int selectedTab: 0  // 0=All, 1=Dark, 2=Light
            property string selectedTag: ""  // Single active tag filter

            function isDarkTheme(preset) {
                if (preset.id === "auto" || preset.id === "custom") return true
                if (!preset.colors) return true
                const bg = preset.colors.m3background ?? "#000"
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
                for (let i = 0; i < ThemePresets.presets.length; i++) {
                    const preset = ThemePresets.presets[i]
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

            // Double-click hint
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: 6

                MaterialSymbol {
                    text: "touch_app"
                    iconSize: 16
                    color: Appearance.m3colors.m3tertiary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Double-click a theme to apply it reliably. A single click may not always trigger the full color generation.")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    opacity: 0.8
                    wrapMode: Text.WordWrap
                }
            }

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
                    border.color: Appearance.m3colors.m3primary

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
                    color: Config.options?.appearance?.softenColors ? Appearance.m3colors.m3primary : Appearance.colors.colLayer1

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "opacity"
                        iconSize: 16
                        color: Config.options?.appearance?.softenColors ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
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
                                ? Appearance.m3colors.m3primary
                                : tabMouse.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: 14
                                color: themesGroup.selectedTab === index
                                    ? Appearance.m3colors.m3onPrimary
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
                        color: Appearance.m3colors.m3primary
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
                        color: Appearance.m3colors.m3tertiary
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

            // Theme grid - scrollable with 3 columns
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 10
                Layout.preferredHeight: Math.min(300, themeGridContent.implicitHeight + 12)
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.small
                clip: true

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
                            model: themesGroup.filteredPresets

                            ThemePresetCard {
                                required property var modelData
                                width: (themeGridContent.width - themeGridContent.columnSpacing * 2) / 3
                                preset: modelData
                                onClicked: ThemeService.setTheme(modelData.id)
                            }
                        }
                    }
                }

                // Empty state overlay
                ColumnLayout {
                    visible: themesGroup.filteredPresets.length === 0
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "search_off"
                        iconSize: 32
                        color: Appearance.colors.colSubtext
                        opacity: 0.5
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("No themes found")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    // Theme Scheduling Section
    SettingsCardSection {
        expanded: false
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
                    onValueModified: Config.setNestedValue("appearance.themeSchedule.dayStart",
                        `${textFromValue(value)}:${dayMinSpin.textFromValue(dayMinSpin.value)}`)
                }
                StyledText { text: ":"; font.pixelSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                StyledSpinBox {
                    id: dayMinSpin
                    from: 0; to: 59; stepSize: 5
                    value: parseInt((Config.options?.appearance?.themeSchedule?.dayStart ?? "06:00").split(":")[1]) || 0
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueModified: Config.setNestedValue("appearance.themeSchedule.dayStart",
                        `${dayHourSpin.textFromValue(dayHourSpin.value)}:${textFromValue(value)}`)
                }
            }

            RowLayout {
                visible: Config.options?.appearance?.themeSchedule?.enabled ?? false
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol { text: "nights_stay"; iconSize: 18; color: Appearance.colors.colSubtext }
                StyledText { text: Translation.tr("Night starts at"); Layout.fillWidth: true }

                StyledSpinBox {
                    id: nightHourSpin
                    from: 0; to: 23
                    value: parseInt((Config.options?.appearance?.themeSchedule?.nightStart ?? "18:00").split(":")[0]) || 18
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueModified: Config.setNestedValue("appearance.themeSchedule.nightStart",
                        `${textFromValue(value)}:${nightMinSpin.textFromValue(nightMinSpin.value)}`)
                }
                StyledText { text: ":"; font.pixelSize: Appearance.font.pixelSize.large; color: Appearance.colors.colSubtext }
                StyledSpinBox {
                    id: nightMinSpin
                    from: 0; to: 59; stepSize: 5
                    value: parseInt((Config.options?.appearance?.themeSchedule?.nightStart ?? "18:00").split(":")[1]) || 0
                    textFromValue: (v) => v.toString().padStart(2, '0')
                    onValueModified: Config.setNestedValue("appearance.themeSchedule.nightStart",
                        `${nightHourSpin.textFromValue(nightHourSpin.value)}:${textFromValue(value)}`)
                }
            }
        }
    }

    // Terminal Colors Section
    SettingsCardSection {
        id: terminalColorsSection
        expanded: false
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
                        "for term in kitty alacritty foot wezterm ghostty konsole starship; do " +
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
                            const sat = adj.saturation ?? 0.40;
                            const bright = adj.brightness ?? 0.55;
                            const harmony = adj.harmony ?? 0.15;

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
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.saturation ?? 0.40) * 100)
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
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.brightness ?? 0.55) * 100)
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
                value: Math.round((Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments?.harmony ?? 0.15) * 100)
                from: 0
                to: 50
                stepSize: 5
                property bool _ready: false
                Component.onCompleted: _ready = true
                onValueChanged: {
                    if (!_ready) return;
                    Config.setNestedValue("appearance.wallpaperTheming.terminalColorAdjustments.harmony", value / 100);
                    terminalColorDebounce.restart();
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
                    saturationSpinBox.value = 40;  // 0.40 * 100
                    brightnessSpinBox.value = 55;  // 0.55 * 100
                    harmonySpinBox.value = 15;     // 0.15 * 100
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
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colPrimaryContainerActive

                contentItem: RowLayout {
                    id: applyNowRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: "sync"
                        iconSize: 16
                        color: Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: Translation.tr("Apply to open terminals")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }

                onClicked: applyTerminalColorsProcess.running = true

                StyledToolTip {
                    text: Translation.tr("Apply current colors to all open terminal windows without restarting them")
                }

                Process {
                    id: applyTerminalColorsProcess
                    command: ["/usr/bin/bash", Directories.scriptPath + "/colors/applycolor.sh"]
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "style"
        title: Translation.tr("Global Style")

        SettingsGroup {
            id: globalStyleGroup
            readonly property bool cardsEverywhere: Config.options.dock.cardStyle && Config.options.sidebar.cardStyle && (Config.options.bar.cornerStyle === 3)

            readonly property string derivedStyle: cardsEverywhere ? "cards" : "material"
            readonly property string currentStyle: (Config.options.appearance.globalStyle && Config.options.appearance.globalStyle.length > 0)
                ? Config.options.appearance.globalStyle
                : derivedStyle

            // Get corner style for current global style
            function getCornerStyleForGlobalStyle(styleId) {
                const styles = Config.options?.appearance?.globalStyleCornerStyles
                if (!styles) return 1
                switch (styleId) {
                    case "material": return styles.material ?? 1
                    case "cards": return styles.cards ?? 3
                    case "aurora": return styles.aurora ?? 1
                    case "inir": return styles.inir ?? 1
                    default: return 1
                }
            }

            // Save corner style for a global style
            function setCornerStyleForGlobalStyle(styleId, cornerStyle) {
                Config.setNestedValue(`appearance.globalStyleCornerStyles.${styleId}`, cornerStyle)
            }

            function _applyGlobalStyle(styleId) {
                console.log("[GlobalStyle] apply", styleId)
                const cornerStyle = getCornerStyleForGlobalStyle(styleId)

                if (styleId === "cards") {
                    Config.options.dock.cardStyle = true;
                    Config.options.sidebar.cardStyle = true;
                    Config.options.bar.cornerStyle = cornerStyle;
                    Config.setNestedValue("appearance.transparency.enable", false)
                    return;
                }

                if (styleId === "aurora") {
                    Config.options.dock.cardStyle = false;
                    Config.options.sidebar.cardStyle = false;
                    Config.options.bar.cornerStyle = cornerStyle;
                    Config.setNestedValue("appearance.transparency.enable", true)
                    return;
                }

                if (styleId === "inir") {
                    Config.options.dock.cardStyle = false;
                    Config.options.sidebar.cardStyle = false;
                    Config.options.bar.cornerStyle = cornerStyle;
                    Config.setNestedValue("appearance.transparency.enable", false)
                    return;
                }

                // material
                Config.options.dock.cardStyle = false;
                Config.options.sidebar.cardStyle = false;
                Config.options.bar.cornerStyle = cornerStyle;
                Config.setNestedValue("appearance.transparency.enable", false)
            }

            ContentSubsection {
                title: Translation.tr("Style")

                ConfigSelectionArray {
                    currentValue: globalStyleGroup.currentStyle
                    onSelected: (newValue) => {
                        console.log("[GlobalStyle] selected", newValue)
                        Config.setNestedValue("appearance.globalStyle", newValue)
                        globalStyleGroup._applyGlobalStyle(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Material"), icon: "tune", value: "material" },
                        { displayName: Translation.tr("Cards"), icon: "branding_watermark", value: "cards" },
                        { displayName: Translation.tr("Aurora"), icon: "blur_on", value: "aurora" },
                        { displayName: Translation.tr("Inir"), icon: "terminal", value: "inir" }
                    ]
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Material keeps the original surfaces. Cards enables rounded card containers everywhere. Aurora enables a wallpaper-tinted glass surface style across panels. Inir uses a TUI-inspired dark theme with accent-colored borders.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: ThemeService.currentTheme === "custom"
        expanded: true
        icon: "edit"
        title: Translation.tr("Custom Theme Editor")

        SettingsGroup {
            Loader {
                Layout.fillWidth: true
                active: ThemeService.currentTheme === "custom"
                source: "CustomThemeEditor.qml"
            }
        }
    }

    SettingsCardSection {
        expanded: false
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
                                    color: Appearance.m3colors.m3onSurface
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
                                Config.options.appearance.typography.mainFont = selectedFont
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
                                Config.options.appearance.typography.titleFont = selectedFont
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
                                Config.options.appearance.typography.monospaceFont = selectedFont
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
                        Config.options.appearance.typography.sizeScale = value / 100
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
                            Config.options.appearance.typography.variableAxes.wght = value
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
                            Config.options.appearance.typography.variableAxes.wdth = value
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
                    to: 200
                    stepSize: 25
                    value: Config.options?.appearance?.typography?.variableAxes?.grad ?? 175
                    onValueChanged: {
                        if (Config.options?.appearance?.typography?.variableAxes)
                            Config.options.appearance.typography.variableAxes.grad = value
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
        expanded: false
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
        expanded: false
        icon: "info"
        title: Translation.tr("About Themes")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Themes apply a Material 3 color palette. 'Auto' generates colors from your wallpaper using matugen.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }
}
