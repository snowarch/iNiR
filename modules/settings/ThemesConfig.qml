import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true
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
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Select a color theme. Choose 'Auto' to use colors from your wallpaper.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialSymbol {
                    text: "check_circle"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3primary
                }

                StyledText {
                    text: Translation.tr("Current: %1").arg(ThemePresets.getPreset(ThemeService.currentTheme).name)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            Flow {
                id: themeFlow
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: ThemePresets.presets

                    ThemePresetCard {
                        required property var modelData
                        width: Math.max(140, (themeFlow.width - themeFlow.spacing * 3) / 4)
                        preset: modelData
                        onClicked: ThemeService.setTheme(modelData.id)
                    }
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

            function _applyGlobalStyle(styleId) {
                console.log("[GlobalStyle] apply", styleId)
                if (styleId === "cards") {
                    Config.options.dock.cardStyle = true;
                    Config.options.sidebar.cardStyle = true;
                    Config.options.bar.cornerStyle = 3;
                    Config.setNestedValue("appearance.transparency.enable", false)
                    return;
                }

                if (styleId === "aurora") {
                    Config.options.dock.cardStyle = false;
                    Config.options.sidebar.cardStyle = false;
                    if (Config.options.bar.cornerStyle === 3) Config.options.bar.cornerStyle = 1;
                    Config.setNestedValue("appearance.transparency.enable", true)
                    return;
                }

                if (styleId === "inir") {
                    Config.options.dock.cardStyle = false;
                    Config.options.sidebar.cardStyle = false;
                    if (Config.options.bar.cornerStyle === 3) Config.options.bar.cornerStyle = 1;
                    Config.setNestedValue("appearance.transparency.enable", false)
                    return;
                }

                // material
                Config.options.dock.cardStyle = false;
                Config.options.sidebar.cardStyle = false;
                if (Config.options.bar.cornerStyle === 3) Config.options.bar.cornerStyle = 1;
                Config.setNestedValue("appearance.transparency.enable", false)
            }

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
                            StyledToolTip { text: modelData.description }
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
