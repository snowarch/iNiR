pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.waffle.looks
import qs.modules.waffle.settings

WSettingsPage {
    id: root
    settingsPageIndex: 4
    pageTitle: Translation.tr("Themes")
    pageIcon: "dark-theme"
    pageDescription: Translation.tr("Color themes and typography")

    // Active theme preview
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Looks.radius.medium
        color: Looks.colors.bg2

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            // Active theme color swatches
            Row {
                spacing: -4

                Repeater {
                    model: {
                        const preset = ThemePresets.getPreset(ThemeService.currentTheme)
                        const c = preset?.colors
                        return [
                            c?.m3primary ?? Appearance.m3colors.m3primary ?? Looks.colors.accent,
                            c?.m3secondary ?? Appearance.m3colors.m3secondary ?? Looks.colors.bg2,
                            c?.m3tertiary ?? Appearance.m3colors.m3tertiary ?? Looks.colors.bg1,
                            c?.m3background ?? Appearance.m3colors.m3background ?? Looks.colors.bg0
                        ]
                    }

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: 20; height: 20
                        radius: 10
                        color: modelData
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.2)
                        z: 4 - index
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                WText {
                    text: ThemePresets.getPreset(ThemeService.currentTheme)?.name ?? "Auto"
                    font.pixelSize: Looks.font.pixelSize.normal
                    font.weight: Looks.font.weight.regular
                }

                WText {
                    text: ThemePresets.getPreset(ThemeService.currentTheme)?.description ?? ""
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            FluentIcon {
                icon: "checkmark"
                implicitSize: 14
                color: Looks.colors.accent
            }
        }
    }

    // Color Theme card
    WSettingsCard {
        id: colorThemeCard
        title: Translation.tr("Color Theme")
        icon: "dark-theme"

        property string searchQuery: ""
        property int selectedTab: 0  // 0=All, 1=Dark, 2=Light
        property string selectedTag: ""

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
            selectedTag = (selectedTag === tagId) ? "" : tagId
        }

        readonly property var filteredPresets: {
            let result = []
            for (let i = 0; i < ThemePresets.presets.length; i++) {
                const preset = ThemePresets.presets[i]
                if (selectedTab === 1 && !isDarkTheme(preset)) continue
                if (selectedTab === 2 && isDarkTheme(preset)) continue
                if (selectedTag.length > 0) {
                    const presetTags = preset.tags ?? []
                    if (!presetTags.includes(selectedTag)) continue
                }
                if (searchQuery.length > 0) {
                    const query = searchQuery.toLowerCase()
                    const name = (preset.name ?? "").toLowerCase()
                    const desc = (preset.description ?? "").toLowerCase()
                    if (!name.includes(query) && !desc.includes(query)) continue
                }
                result.push(preset)
            }
            return result
        }

        // Search + filter row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Search field
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Looks.radius.small
                color: Looks.colors.bg1
                border.width: themeSearchInput.activeFocus ? 1 : 0
                border.color: Looks.colors.accent

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 6

                    FluentIcon {
                        icon: "search"
                        implicitSize: 14
                        color: Looks.colors.subfg
                    }

                    TextInput {
                        id: themeSearchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.pixelSize: Looks.font.pixelSize.small
                        font.family: Looks.font.family
                        color: Looks.colors.fg
                        clip: true
                        onTextChanged: colorThemeCard.searchQuery = text

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Translation.tr("Search themes...")
                            font: parent.font
                            color: Looks.colors.subfg
                            opacity: 0.6
                            visible: !parent.text && !parent.activeFocus
                        }
                    }

                    FluentIcon {
                        visible: themeSearchInput.text.length > 0
                        icon: "dismiss"
                        implicitSize: 12
                        color: Looks.colors.subfg

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: themeSearchInput.text = ""
                        }
                    }
                }
            }

            // Dark/Light/All tab pills
            Row {
                spacing: 4

                Repeater {
                    model: [
                        { icon: "apps", tip: Translation.tr("All") },
                        { icon: "weather-moon", tip: Translation.tr("Dark") },
                        { icon: "weather-sunny", tip: Translation.tr("Light") }
                    ]

                    Rectangle {
                        required property var modelData
                        required property int index

                        width: 28; height: 28
                        radius: 14
                        color: colorThemeCard.selectedTab === index
                            ? Looks.colors.accent
                            : tabMouseArea.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1

                        FluentIcon {
                            anchors.centerIn: parent
                            icon: modelData.icon
                            implicitSize: 14
                            color: colorThemeCard.selectedTab === index
                                ? Looks.colors.bg0
                                : Looks.colors.fg
                        }

                        MouseArea {
                            id: tabMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: colorThemeCard.selectedTab = index
                        }

                        WToolTip { text: modelData.tip; extraVisibleCondition: tabMouseArea.containsMouse }
                    }
                }
            }
        }

        // Tag filters
        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: ThemePresets.availableTags.filter(t => t.id !== "dark" && t.id !== "light")

                Rectangle {
                    required property var modelData

                    readonly property bool isActive: colorThemeCard.selectedTag === modelData.id

                    width: tagRowLayout.implicitWidth + 12
                    height: 24
                    radius: 12
                    color: isActive ? Qt.alpha(Looks.colors.accent, 0.15)
                         : tagFilterMouse.containsMouse ? Looks.colors.bg2Hover
                         : Looks.colors.bg1

                    RowLayout {
                        id: tagRowLayout
                        anchors.centerIn: parent
                        spacing: 4

                        WText {
                            text: modelData.name
                            font.pixelSize: Looks.font.pixelSize.tiny
                            color: parent.parent.isActive ? Looks.colors.accent : Looks.colors.fg
                        }
                    }

                    MouseArea {
                        id: tagFilterMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: colorThemeCard.toggleTag(modelData.id)
                    }
                }
            }

            // Clear tag button
            Rectangle {
                visible: colorThemeCard.selectedTag.length > 0
                width: 24; height: 24
                radius: 12
                color: clearTagMouse.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg1

                FluentIcon {
                    anchors.centerIn: parent
                    icon: "dismiss"
                    implicitSize: 10
                    color: Looks.colors.subfg
                }

                MouseArea {
                    id: clearTagMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: colorThemeCard.selectedTag = ""
                }
            }
        }

        // Theme grid — 3 columns
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(300, themeGridContent.implicitHeight + 12)
            color: Looks.colors.bg1
            radius: Looks.radius.small
            clip: true

            Flickable {
                id: themeGridFlickable
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: themeGridContent.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Grid {
                    id: themeGridContent
                    width: themeGridFlickable.width
                    columns: 3
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: colorThemeCard.filteredPresets

                        Rectangle {
                            id: themeCard
                            required property var modelData
                            required property int index

                            readonly property bool isActive: ThemeService.currentTheme === modelData.id

                            function getColor(key, fallback) {
                                if (!modelData.colors) return Appearance.m3colors[key] ?? fallback
                                if (modelData.colors === "custom") return Config.options?.appearance?.customTheme?.[key] ?? fallback
                                return modelData.colors[key] ?? fallback
                            }

                            width: (themeGridContent.width - themeGridContent.columnSpacing * 2) / 3
                            height: 36
                            radius: Looks.radius.small
                            color: isActive
                                ? Qt.alpha(Looks.colors.accent, 0.12)
                                : cardMouseArea.containsMouse ? Looks.colors.bg2Hover : Looks.colors.bg2

                            border.width: isActive ? 1 : 0
                            border.color: Qt.alpha(Looks.colors.accent, 0.4)

                            MouseArea {
                                id: cardMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ThemeService.setTheme(themeCard.modelData.id)
                                onDoubleClicked: ThemeService.setTheme(themeCard.modelData.id)
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 6

                                // Overlapping color circles
                                Row {
                                    spacing: -4

                                    Repeater {
                                        model: [
                                            { key: "m3primary", fallback: "#6366f1" },
                                            { key: "m3secondary", fallback: "#818cf8" },
                                            { key: "m3tertiary", fallback: "#a78bfa" },
                                            { key: "m3background", fallback: "#0f0f23" }
                                        ]

                                        Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: 14; height: 14
                                            radius: 7
                                            color: themeCard.getColor(modelData.key, modelData.fallback)
                                            border.width: 1
                                            border.color: Qt.rgba(0, 0, 0, 0.2)
                                            z: 4 - index
                                        }
                                    }
                                }

                                // Theme name
                                WText {
                                    Layout.fillWidth: true
                                    text: themeCard.modelData.name
                                    font.pixelSize: Looks.font.pixelSize.small
                                    font.weight: themeCard.isActive ? Looks.font.weight.regular : Looks.font.weight.thin
                                    color: themeCard.isActive ? Looks.colors.accent : Looks.colors.fg
                                    elide: Text.ElideRight
                                }

                                // Active checkmark
                                FluentIcon {
                                    visible: themeCard.isActive
                                    icon: "checkmark"
                                    implicitSize: 12
                                    color: Looks.colors.accent
                                }
                            }

                            WToolTip { text: themeCard.modelData.description ?? ""; extraVisibleCondition: cardMouseArea.containsMouse }
                        }
                    }
                }
            }

            // Empty state
            ColumnLayout {
                visible: colorThemeCard.filteredPresets.length === 0
                anchors.centerIn: parent
                spacing: 8

                FluentIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "search"
                    implicitSize: 32
                    color: Looks.colors.subfg
                    opacity: 0.5
                }

                WText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No themes found")
                    font.pixelSize: Looks.font.pixelSize.small
                    color: Looks.colors.subfg
                }
            }
        }
    }

    // Global Style card
    WSettingsCard {
        title: Translation.tr("Global Style")
        icon: "eyedropper"

        id: globalStyleCard

        readonly property bool cardsEverywhere: (Config.options?.dock?.cardStyle ?? false) && (Config.options?.sidebar?.cardStyle ?? false) && (Config.options?.bar?.cornerStyle === 3)

        readonly property string derivedStyle: cardsEverywhere ? "cards" : "material"
        readonly property string currentStyle: (Config.options?.appearance?.globalStyle ?? "").length > 0
            ? Config.options?.appearance?.globalStyle ?? "material"
            : derivedStyle

        function _applyGlobalStyle(styleId) {
            console.log("[GlobalStyle] apply", styleId)
            if (styleId === "cards") {
                Config.setNestedValue("dock.cardStyle", true)
                Config.setNestedValue("sidebar.cardStyle", true)
                Config.setNestedValue("bar.cornerStyle", 3)
                Config.setNestedValue("appearance.transparency.enable", false)
                return;
            }

            if (styleId === "aurora") {
                Config.setNestedValue("dock.cardStyle", false)
                Config.setNestedValue("sidebar.cardStyle", false)
                if ((Config.options?.bar?.cornerStyle ?? 1) === 3) Config.setNestedValue("bar.cornerStyle", 1)
                Config.setNestedValue("appearance.transparency.enable", true)
                return;
            }

            if (styleId === "angel") {
                Config.setNestedValue("dock.cardStyle", false)
                Config.setNestedValue("sidebar.cardStyle", false)
                if ((Config.options?.bar?.cornerStyle ?? 1) === 3) Config.setNestedValue("bar.cornerStyle", 1)
                Config.setNestedValue("appearance.transparency.enable", true)
                return;
            }

            // material
            Config.setNestedValue("dock.cardStyle", false)
            Config.setNestedValue("sidebar.cardStyle", false)
            if ((Config.options?.bar?.cornerStyle ?? 1) === 3) Config.setNestedValue("bar.cornerStyle", 1)
            Config.setNestedValue("appearance.transparency.enable", false)
        }

        WSettingsDropdown {
            label: Translation.tr("Style")
            icon: "eyedropper"
            description: Translation.tr("Choose between Material, Cards, Aurora, Inir, and Angel global styling")
            currentValue: globalStyleCard.currentStyle
            options: [
                { value: "material", displayName: Translation.tr("Material") },
                { value: "cards", displayName: Translation.tr("Cards") },
                { value: "aurora", displayName: Translation.tr("Aurora") },
                { value: "inir", displayName: Translation.tr("Inir") },
                { value: "angel", displayName: Translation.tr("Angel") }
            ]
            onSelected: newValue => {
                console.log("[GlobalStyle] selected", newValue)
                Config.setNestedValue("appearance.globalStyle", newValue)
                globalStyleCard._applyGlobalStyle(newValue)
            }
        }
    }

    // Appearance card
    WSettingsCard {
        title: Translation.tr("Appearance")
        icon: "weather-moon"

        WSettingsDropdown {
            label: Translation.tr("Mode")
            icon: "weather-moon"
            description: Translation.tr("Light or dark color scheme")
            currentValue: Appearance.m3colors.darkmode ? "dark" : "light"
            options: [
                { value: "light", displayName: Translation.tr("Light") },
                { value: "dark", displayName: Translation.tr("Dark") }
            ]
            onSelected: newValue => {
                const dark = newValue === "dark"
                ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`)
            }
        }

        WSettingsDropdown {
            label: Translation.tr("Palette type")
            icon: "dark-theme"
            description: Translation.tr("How colors are generated from wallpaper")
            currentValue: Config.options?.appearance?.palette?.type ?? "auto"
            options: [
                { value: "auto", displayName: Translation.tr("Auto") },
                { value: "scheme-content", displayName: Translation.tr("Content") },
                { value: "scheme-expressive", displayName: Translation.tr("Expressive") },
                { value: "scheme-fidelity", displayName: Translation.tr("Fidelity") },
                { value: "scheme-fruit-salad", displayName: Translation.tr("Fruit Salad") },
                { value: "scheme-monochrome", displayName: Translation.tr("Monochrome") },
                { value: "scheme-neutral", displayName: Translation.tr("Neutral") },
                { value: "scheme-rainbow", displayName: Translation.tr("Rainbow") },
                { value: "scheme-tonal-spot", displayName: Translation.tr("Tonal Spot") }
            ]
            onSelected: newValue => {
                Config.setNestedValue("appearance.palette.type", newValue)
                ShellExec.execCmd(`${Directories.wallpaperSwitchScriptPath} --noswitch --type ${newValue}`)
            }
        }
    }

    // Theming options
    WSettingsCard {
        title: Translation.tr("Theming")
        icon: "eyedropper"

        WSettingsSwitch {
            label: Translation.tr("Use Material colors")
            icon: "dark-theme"
            description: Translation.tr("Apply Material color scheme instead of Windows 11 grey")
            checked: Config.options?.waffles?.theming?.useMaterialColors ?? false
            onCheckedChanged: Config.setNestedValue("waffles.theming.useMaterialColors", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Vesktop/Discord theming")
            icon: "people"
            description: Translation.tr("Generate Discord theme from wallpaper colors")
            checked: Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true
            onCheckedChanged: Config.setNestedValue("appearance.wallpaperTheming.enableVesktop", checked)
        }

        WSettingsSwitch {
            label: Translation.tr("Transparency")
            icon: "eye"
            description: Translation.tr("Enable transparent UI elements")
            checked: Config.options?.appearance?.transparency?.enable ?? false
            onCheckedChanged: Config.setNestedValue("appearance.transparency.enable", checked)
        }
    }

    // Waffle Typography card
    WSettingsCard {
        title: Translation.tr("Waffle Typography")
        icon: "auto"

        WText {
            Layout.fillWidth: true
            text: Translation.tr("These settings only affect the Windows 11 (Waffle) style panels.")
            font.pixelSize: Looks.font.pixelSize.small
            color: Looks.colors.subfg
            wrapMode: Text.WordWrap
        }

        WSettingsDropdown {
            label: Translation.tr("Font family")
            icon: "auto"
            description: Translation.tr("Font used in Waffle panels")
            currentValue: Config.options?.waffles?.theming?.font?.family ?? "Noto Sans"
            options: [
                { value: "Segoe UI Variable", displayName: "Segoe UI" },
                { value: "Inter", displayName: "Inter" },
                { value: "Roboto", displayName: "Roboto" },
                { value: "Noto Sans", displayName: "Noto Sans" },
                { value: "Ubuntu", displayName: "Ubuntu" }
            ]
            onSelected: newValue => Config.setNestedValue("waffles.theming.font.family", newValue)
        }

        WSettingsSpinBox {
            label: Translation.tr("Font scale")
            icon: "auto"
            description: Translation.tr("Scale all text in Waffle panels")
            suffix: "%"
            from: 80; to: 150; stepSize: 5
            value: Math.round((Config.options?.waffles?.theming?.font?.scale ?? 1.0) * 100)
            onValueChanged: Config.setNestedValue("waffles.theming.font.scale", value / 100.0)
        }
    }
}
