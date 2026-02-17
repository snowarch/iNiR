import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 16

    // ─── Helper: Percentage slider row with label + value readout ───
    component SliderRow: RowLayout {
        id: sliderRowRoot
        Layout.fillWidth: true
        spacing: 8

        property string label: ""
        property string icon: ""
        property string description: ""
        property real configValue: 0.0
        property real from: 0.0
        property real to: 1.0
        property real stepSize: 0.01
        property string configPath: ""

        MaterialSymbol {
            text: sliderRowRoot.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colSubtext
            visible: sliderRowRoot.icon !== ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                text: sliderRowRoot.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                visible: sliderRowRoot.description !== ""
                text: sliderRowRoot.description
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        StyledText {
            text: Math.round(slider.value * 100) + "%"
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: Appearance.font.family.monospace
            color: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary
            Layout.preferredWidth: 45
            horizontalAlignment: Text.AlignRight
        }

        StyledSlider {
            id: slider
            Layout.preferredWidth: 160
            from: sliderRowRoot.from
            to: sliderRowRoot.to
            stepSize: sliderRowRoot.stepSize
            value: sliderRowRoot.configValue
            configuration: StyledSlider.Configuration.S

            onMoved: {
                if (sliderRowRoot.configPath !== "") {
                    Config.setNestedValue(sliderRowRoot.configPath, Math.round(value * 100) / 100)
                }
            }
        }
    }

    // ─── Helper: Integer spinbox row ───
    component SpinRow: RowLayout {
        id: spinRowRoot
        Layout.fillWidth: true
        spacing: 8

        property string label: ""
        property string icon: ""
        property string description: ""
        property int configValue: 0
        property int from: 0
        property int to: 50
        property string configPath: ""

        ConfigSpinBox {
            Layout.fillWidth: true
            icon: spinRowRoot.icon
            text: spinRowRoot.label
            value: spinRowRoot.configValue
            from: spinRowRoot.from
            to: spinRowRoot.to
            onValueChanged: {
                if (spinRowRoot.configPath !== "") {
                    Config.setNestedValue(spinRowRoot.configPath, value)
                }
            }
            StyledToolTip {
                visible: spinRowRoot.description !== ""
                text: spinRowRoot.description
            }
        }
    }

    // ─── Helper: Real spinbox row (for border width etc.) ───
    component RealSpinRow: RowLayout {
        id: realSpinRowRoot
        Layout.fillWidth: true
        spacing: 8

        property string label: ""
        property string icon: ""
        property string description: ""
        property real configValue: 0.0
        property real from: 0.0
        property real to: 10.0
        property real stepSize: 0.5
        property string configPath: ""

        ConfigSpinBox {
            Layout.fillWidth: true
            icon: realSpinRowRoot.icon
            text: realSpinRowRoot.label
            value: Math.round(realSpinRowRoot.configValue * 10)
            from: Math.round(realSpinRowRoot.from * 10)
            to: Math.round(realSpinRowRoot.to * 10)
            onValueChanged: {
                if (realSpinRowRoot.configPath !== "") {
                    Config.setNestedValue(realSpinRowRoot.configPath, value / 10)
                }
            }
            StyledToolTip {
                visible: realSpinRowRoot.description !== ""
                text: realSpinRowRoot.description
            }
        }
    }

    // ─── Section keys (excludes metadata like customPreset, profiles) ───
    readonly property var _sectionKeys: ["blur", "transparency", "escalonado", "escalonadoShadow", "border", "surface", "glow", "rounding"]

    // ─── Preset definitions (JS objects) — professional variations ───
    readonly property var _presets: ({
        "default": {
            "blur": { "intensity": 0.50, "saturation": 0.15, "overlayOpacity": 0.35, "noiseOpacity": 0.20, "vignetteStrength": 0.15 },
            "transparency": { "panel": 0.35, "card": 0.50, "popup": 0.35, "tooltip": 0.25 },
            "escalonado": { "offsetX": 1, "offsetY": 1, "hoverOffsetX": 7, "hoverOffsetY": 7, "opacity": 0.50, "borderOpacity": 0.17, "hoverOpacity": 0.0 },
            "escalonadoShadow": { "offsetX": 3, "offsetY": 2, "hoverOffsetX": 7, "hoverOffsetY": 7, "opacity": 1.0, "borderOpacity": 1.0, "hoverOpacity": 0.60, "glass": true, "glassBlur": 0.70, "glassOverlay": 0.50 },
            "border": { "width": 0.8, "accentBarHeight": 10, "accentBarWidth": 10, "coverage": 0.60, "opacity": 0.52, "hoverOpacity": 0.50, "activeOpacity": 0.50, "insetGlowHeight": 1, "insetGlowOpacity": 0.20 },
            "surface": { "panelBorderWidth": 1, "cardBorderWidth": 1, "panelBorderOpacity": 0.90, "cardBorderOpacity": 0.0 },
            "glow": { "opacity": 0.0, "strongOpacity": 0.0 },
            "rounding": { "small": 0, "normal": 0, "large": 0 },
            "colorStrength": 0.6
        },
        "ethereal": {
            "blur": { "intensity": 0.65, "saturation": 0.25, "overlayOpacity": 0.45, "noiseOpacity": 0.10, "vignetteStrength": 0.25 },
            "transparency": { "panel": 0.75, "card": 0.85, "popup": 0.70, "tooltip": 0.40 },
            "escalonado": { "offsetX": 2, "offsetY": 2, "hoverOffsetX": 6, "hoverOffsetY": 6, "opacity": 0.30, "borderOpacity": 0.25, "hoverOpacity": 0.15 },
            "escalonadoShadow": { "offsetX": 4, "offsetY": 3, "hoverOffsetX": 8, "hoverOffsetY": 8, "opacity": 0.60, "borderOpacity": 0.50, "hoverOpacity": 0.40, "glass": true, "glassBlur": 0.55, "glassOverlay": 0.40 },
            "border": { "width": 0.5, "accentBarHeight": 4, "accentBarWidth": 4, "coverage": 0.40, "opacity": 0.30, "hoverOpacity": 0.45, "activeOpacity": 0.55, "insetGlowHeight": 2, "insetGlowOpacity": 0.30 },
            "surface": { "panelBorderWidth": 1, "cardBorderWidth": 1, "panelBorderOpacity": 0.40, "cardBorderOpacity": 0.15 },
            "glow": { "opacity": 0.50, "strongOpacity": 0.35 },
            "rounding": { "small": 8, "normal": 12, "large": 20 },
            "colorStrength": 0.9
        },
        "monolith": {
            "blur": { "intensity": 0.20, "saturation": 0.05, "overlayOpacity": 0.20, "noiseOpacity": 0.05, "vignetteStrength": 0.0 },
            "transparency": { "panel": 0.20, "card": 0.30, "popup": 0.20, "tooltip": 0.15 },
            "escalonado": { "offsetX": 2, "offsetY": 2, "hoverOffsetX": 5, "hoverOffsetY": 5, "opacity": 0.80, "borderOpacity": 0.60, "hoverOpacity": 0.30 },
            "escalonadoShadow": { "offsetX": 3, "offsetY": 3, "hoverOffsetX": 6, "hoverOffsetY": 6, "opacity": 1.0, "borderOpacity": 1.0, "hoverOpacity": 0.80, "glass": false, "glassBlur": 0.10, "glassOverlay": 0.80 },
            "border": { "width": 1.0, "accentBarHeight": 2, "accentBarWidth": 2, "coverage": 0.80, "opacity": 0.70, "hoverOpacity": 0.80, "activeOpacity": 0.90, "insetGlowHeight": 0, "insetGlowOpacity": 0.0 },
            "surface": { "panelBorderWidth": 1, "cardBorderWidth": 1, "panelBorderOpacity": 1.0, "cardBorderOpacity": 0.30 },
            "glow": { "opacity": 0.0, "strongOpacity": 0.0 },
            "rounding": { "small": 0, "normal": 0, "large": 0 },
            "colorStrength": 0.3
        },
        "crystalline": {
            "blur": { "intensity": 0.80, "saturation": 0.30, "overlayOpacity": 0.50, "noiseOpacity": 0.15, "vignetteStrength": 0.20 },
            "transparency": { "panel": 0.60, "card": 0.70, "popup": 0.55, "tooltip": 0.30 },
            "escalonado": { "offsetX": 1, "offsetY": 1, "hoverOffsetX": 4, "hoverOffsetY": 4, "opacity": 0.40, "borderOpacity": 0.30, "hoverOpacity": 0.10 },
            "escalonadoShadow": { "offsetX": 2, "offsetY": 2, "hoverOffsetX": 5, "hoverOffsetY": 5, "opacity": 0.70, "borderOpacity": 0.80, "hoverOpacity": 0.50, "glass": true, "glassBlur": 0.85, "glassOverlay": 0.30 },
            "border": { "width": 0.6, "accentBarHeight": 6, "accentBarWidth": 6, "coverage": 0.50, "opacity": 0.40, "hoverOpacity": 0.55, "activeOpacity": 0.65, "insetGlowHeight": 1, "insetGlowOpacity": 0.25 },
            "surface": { "panelBorderWidth": 1, "cardBorderWidth": 1, "panelBorderOpacity": 0.60, "cardBorderOpacity": 0.20 },
            "glow": { "opacity": 0.40, "strongOpacity": 0.25 },
            "rounding": { "small": 4, "normal": 6, "large": 10 },
            "colorStrength": 1.2
        }
    })

    // ─── Apply preset: sets each property individually for proper Config persistence ───
    function _applyPreset(preset): void {
        for (const section of root._sectionKeys) {
            if (preset[section] !== undefined && typeof preset[section] === "object") {
                const sectionData = preset[section]
                for (const key of Object.keys(sectionData)) {
                    Config.setNestedValue("appearance.angel." + section + "." + key, sectionData[key])
                }
            }
        }
        if (preset.colorStrength !== undefined) {
            Config.setNestedValue("appearance.angel.colorStrength", preset.colorStrength)
        }
    }

    // ─── Snapshot current config (clean, no metadata) ───
    function _snapshotCurrent() {
        const current = Config.options?.appearance?.angel ?? {}
        const clean = {}
        for (const key of root._sectionKeys) {
            if (current[key] !== undefined) {
                clean[key] = JSON.parse(JSON.stringify(current[key]))
            }
        }
        if (current.colorStrength !== undefined) clean.colorStrength = current.colorStrength
        return clean
    }

    // ─── Save/Load quick custom preset ───
    function _saveCustom(): void {
        Config.setNestedValue("appearance.angel.customPreset", JSON.stringify(root._snapshotCurrent()))
    }

    function _loadCustom(): void {
        const raw = Config.options?.appearance?.angel?.customPreset ?? ""
        if (raw === "") return
        try { root._applyPreset(JSON.parse(raw)) }
        catch(e) { console.warn("[AngelEditor] Failed to load custom preset:", e) }
    }

    // ─── Named profiles (stored as JSON map in config) ───
    function _getProfiles() {
        const raw = Config.options?.appearance?.angel?.profiles ?? ""
        if (raw === "") return {}
        try { return JSON.parse(raw) }
        catch(e) { return {} }
    }

    function _saveProfile(name): void {
        if (!name || name.length === 0) return
        const profiles = root._getProfiles()
        profiles[name] = root._snapshotCurrent()
        Config.setNestedValue("appearance.angel.profiles", JSON.stringify(profiles))
    }

    function _loadProfile(name): void {
        const profiles = root._getProfiles()
        if (profiles[name]) root._applyPreset(profiles[name])
    }

    function _deleteProfile(name): void {
        const profiles = root._getProfiles()
        delete profiles[name]
        Config.setNestedValue("appearance.angel.profiles", JSON.stringify(profiles))
    }

    property var _profileNames: {
        const raw = Config.options?.appearance?.angel?.profiles ?? ""
        if (raw === "") return []
        try { return Object.keys(JSON.parse(raw)) }
        catch(e) { return [] }
    }

    // ═══════════════════════════════════════════════════════
    // LIVE PREVIEW
    // ═══════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer1
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.colors.colOutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            // Mini preview: escalonado card
            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    x: Appearance.angel.escalonadoOffsetX
                    y: Appearance.angel.escalonadoOffsetY
                    width: 48; height: 48
                    radius: Appearance.angel.roundingSmall
                    color: Appearance.angelEverywhere
                        ? ColorUtils.transparentize(Appearance.colors.colPrimary, Appearance.angel.escalonadoOpacity)
                        : "transparent"
                    border.width: 1
                    border.color: Appearance.angelEverywhere
                        ? ColorUtils.transparentize(Appearance.colors.colPrimary, Appearance.angel.escalonadoBorderOpacity)
                        : "transparent"
                }
                Rectangle {
                    width: 48; height: 48
                    radius: Appearance.angel.roundingSmall
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                    border.width: Appearance.angel.cardBorderWidth
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.colors.colOutlineVariant

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "raven"
                        iconSize: 22
                        color: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: Translation.tr("Angel Style — Live Preview")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Changes apply instantly. Blur %1% · Escalonado %2×%3 · Rounding %4/%5/%6")
                        .arg(Math.round(Appearance.angel.blurIntensity * 100))
                        .arg(Appearance.angel.escalonadoOffsetX)
                        .arg(Appearance.angel.escalonadoOffsetY)
                        .arg(Appearance.angel.roundingSmall)
                        .arg(Appearance.angel.roundingNormal)
                        .arg(Appearance.angel.roundingLarge)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // PRESETS
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Presets")

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { key: "default", icon: "auto_awesome", label: qsTr("Default"), desc: qsTr("Your original config") },
                    { key: "ethereal", icon: "cloud", label: qsTr("Ethereal"), desc: qsTr("Soft blur, gentle glow") },
                    { key: "monolith", icon: "square", label: qsTr("Monolith"), desc: qsTr("Sharp, dark, minimal") },
                    { key: "crystalline", icon: "diamond", label: qsTr("Crystalline"), desc: qsTr("Glass-like, high blur") }
                ]

                delegate: RippleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                    onClicked: root._applyPreset(root._presets[modelData.key])

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 18
                            color: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: modelData.desc
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            Layout.alignment: Qt.AlignHCenter
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // PROFILES
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Profiles")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Save and load named style configurations. Quick save stores a single snapshot; profiles let you maintain multiple named styles.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        // Quick save/load/reset row
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                onClicked: root._saveCustom()

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "save"; iconSize: 15; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Quick Save"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                }
            }
            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                enabled: (Config.options?.appearance?.angel?.customPreset ?? "") !== ""
                opacity: enabled ? 1.0 : 0.4
                onClicked: root._loadCustom()

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "restore"; iconSize: 15; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Quick Load"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                }
            }
            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                onClicked: root._applyPreset(root._presets["default"])

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "restart_alt"; iconSize: 15; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Reset"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1 }
                }
            }
        }

        // Named profile save
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                border.width: profileNameField.activeFocus ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary

                TextInput {
                    id: profileNameField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.main
                    color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1
                    clip: true
                    selectByMouse: true

                    property string placeholderText: Translation.tr("Profile name…")
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 0
                        verticalAlignment: Text.AlignVCenter
                        text: profileNameField.placeholderText
                        font: profileNameField.font
                        color: Appearance.colors.colSubtext
                        opacity: 0.5
                        visible: !profileNameField.text && !profileNameField.activeFocus
                    }
                }
            }

            RippleButton {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 34
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colPrimaryHover
                enabled: profileNameField.text.length > 0
                opacity: enabled ? 1.0 : 0.4
                onClicked: {
                    root._saveProfile(profileNameField.text)
                    profileNameField.text = ""
                }

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    MaterialSymbol { text: "bookmark_add"; iconSize: 15; color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary : Appearance.colors.colOnPrimary }
                    StyledText { text: Translation.tr("Save"); font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium; color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary : Appearance.colors.colOnPrimary }
                }
            }
        }

        // Saved profiles list
        Repeater {
            model: root._profileNames

            delegate: RowLayout {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                    onClicked: root._loadProfile(modelData)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 6
                        MaterialSymbol { text: "bookmark"; iconSize: 15; color: Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary }
                        StyledText {
                            text: modelData
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.colors.colOnLayer1
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }

                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall : Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover : Appearance.colors.colLayer2Hover
                    onClicked: root._deleteProfile(modelData)

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete_outline"
                        iconSize: 15
                        color: Appearance.colors.colSubtext
                    }

                    StyledToolTip { text: Translation.tr("Delete profile") }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // COLOR STRENGTH
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Color & Tint")

        SliderRow {
            label: Translation.tr("Color strength")
            icon: "colorize"
            description: Translation.tr("Multiplier for accent tint intensity across all angel surfaces (0.5 = subtle, 1 = default, 2 = vivid)")
            configValue: Appearance.angel.colorStrength
            from: 0.0; to: 2.0; stepSize: 0.05
            configPath: "appearance.angel.colorStrength"
        }
    }

    // ═══════════════════════════════════════════════════════
    // BLUR & GLASS
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Blur & Glass")

        SliderRow {
            label: Translation.tr("Blur intensity")
            icon: "blur_on"
            description: Translation.tr("How strongly the background is blurred behind glass panels")
            configValue: Appearance.angel.blurIntensity
            configPath: "appearance.angel.blur.intensity"
        }

        SliderRow {
            label: Translation.tr("Blur saturation")
            icon: "palette"
            description: Translation.tr("Color saturation of the blurred glass layer")
            configValue: Appearance.angel.blurSaturation
            configPath: "appearance.angel.blur.saturation"
        }

        SliderRow {
            label: Translation.tr("Overlay tint")
            icon: "layers"
            description: Translation.tr("Color tint overlay on top of the blur (higher = more transparent tint)")
            configValue: Appearance.angel.overlayOpacity
            configPath: "appearance.angel.blur.overlayOpacity"
        }

        SliderRow {
            label: Translation.tr("Noise grain")
            icon: "grain"
            description: Translation.tr("Subtle noise texture over glass surfaces for organic feel")
            configValue: Appearance.angel.noiseOpacity
            configPath: "appearance.angel.blur.noiseOpacity"
        }

        SliderRow {
            label: Translation.tr("Vignette")
            icon: "vignette"
            description: Translation.tr("Edge darkening on glass surfaces for depth")
            configValue: Appearance.angel.vignetteStrength
            configPath: "appearance.angel.blur.vignetteStrength"
        }
    }

    // ═══════════════════════════════════════════════════════
    // GLASS TRANSPARENCY
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Glass Transparency")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Controls how see-through each UI layer is. Higher = more transparent. Combined with overlay tint above to control glass appearance.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        SliderRow {
            label: Translation.tr("Panels")
            icon: "dock_to_bottom"
            description: Translation.tr("Bar, dock, sidebar backgrounds")
            configValue: Appearance.angel.panelTransparentize
            configPath: "appearance.angel.transparency.panel"
        }

        SliderRow {
            label: Translation.tr("Cards")
            icon: "crop_square"
            description: Translation.tr("Settings cards, notification cards, internal containers")
            configValue: Appearance.angel.cardTransparentize
            configPath: "appearance.angel.transparency.card"
        }

        SliderRow {
            label: Translation.tr("Popups")
            icon: "open_in_new"
            description: Translation.tr("Context menus, dropdown overlays")
            configValue: Appearance.angel.popupTransparentize
            configPath: "appearance.angel.transparency.popup"
        }

        SliderRow {
            label: Translation.tr("Tooltips")
            icon: "chat_bubble_outline"
            description: Translation.tr("Hover tooltips — lower values improve readability")
            configValue: Appearance.angel.tooltipTransparentize
            configPath: "appearance.angel.transparency.tooltip"
        }
    }

    // ═══════════════════════════════════════════════════════
    // ESCALONADO SYSTEM (system-wide, 52+ usages)
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Escalonado System")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("The simple colored offset behind most UI elements — buttons, cards, popups. Appears everywhere across the shell.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        SpinRow {
            label: Translation.tr("Offset X")
            icon: "swap_horiz"
            configValue: Appearance.angel.escalonadoOffsetX
            from: 0; to: 20
            configPath: "appearance.angel.escalonado.offsetX"
        }

        SpinRow {
            label: Translation.tr("Offset Y")
            icon: "swap_vert"
            configValue: Appearance.angel.escalonadoOffsetY
            from: 0; to: 20
            configPath: "appearance.angel.escalonado.offsetY"
        }

        SpinRow {
            label: Translation.tr("Hover offset X")
            icon: "open_with"
            configValue: Appearance.angel.escalonadoHoverOffsetX
            from: 0; to: 30
            configPath: "appearance.angel.escalonado.hoverOffsetX"
        }

        SpinRow {
            label: Translation.tr("Hover offset Y")
            icon: "open_with"
            configValue: Appearance.angel.escalonadoHoverOffsetY
            from: 0; to: 30
            configPath: "appearance.angel.escalonado.hoverOffsetY"
        }

        SliderRow {
            label: Translation.tr("Fill opacity")
            icon: "opacity"
            configValue: Appearance.angel.escalonadoOpacity
            configPath: "appearance.angel.escalonado.opacity"
        }

        SliderRow {
            label: Translation.tr("Border opacity")
            icon: "border_style"
            configValue: Appearance.angel.escalonadoBorderOpacity
            configPath: "appearance.angel.escalonado.borderOpacity"
        }

        SliderRow {
            label: Translation.tr("Hover fill opacity")
            icon: "mouse"
            configValue: Appearance.angel.escalonadoHoverOpacity
            configPath: "appearance.angel.escalonado.hoverOpacity"
        }
    }

    // ═══════════════════════════════════════════════════════
    // ESCALONADO SHADOW (glass-backed, settings cards)
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Escalonado Shadow")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("The glass-backed shadow with wallpaper blur — used on settings cards and special containers. Independent from the system-wide escalonado above.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        SpinRow {
            label: Translation.tr("Offset X")
            icon: "swap_horiz"
            configValue: Appearance.angel.shadowOffsetX
            from: 0; to: 20
            configPath: "appearance.angel.escalonadoShadow.offsetX"
        }

        SpinRow {
            label: Translation.tr("Offset Y")
            icon: "swap_vert"
            configValue: Appearance.angel.shadowOffsetY
            from: 0; to: 20
            configPath: "appearance.angel.escalonadoShadow.offsetY"
        }

        SpinRow {
            label: Translation.tr("Hover offset X")
            icon: "open_with"
            configValue: Appearance.angel.shadowHoverOffsetX
            from: 0; to: 30
            configPath: "appearance.angel.escalonadoShadow.hoverOffsetX"
        }

        SpinRow {
            label: Translation.tr("Hover offset Y")
            icon: "open_with"
            configValue: Appearance.angel.shadowHoverOffsetY
            from: 0; to: 30
            configPath: "appearance.angel.escalonadoShadow.hoverOffsetY"
        }

        SliderRow {
            label: Translation.tr("Fill opacity")
            icon: "opacity"
            configValue: Appearance.angel.shadowOpacity
            configPath: "appearance.angel.escalonadoShadow.opacity"
        }

        SliderRow {
            label: Translation.tr("Border opacity")
            icon: "border_style"
            configValue: Appearance.angel.shadowBorderOpacity
            configPath: "appearance.angel.escalonadoShadow.borderOpacity"
        }

        SliderRow {
            label: Translation.tr("Hover fill opacity")
            icon: "mouse"
            configValue: Appearance.angel.shadowHoverOpacity
            configPath: "appearance.angel.escalonadoShadow.hoverOpacity"
        }

        ConfigSwitch {
            Layout.fillWidth: true
            text: Translation.tr("Glass blur on shadow")
            checked: Appearance.angel.shadowGlass
            onCheckedChanged: Config.setNestedValue("appearance.angel.escalonadoShadow.glass", checked)
        }

        SliderRow {
            label: Translation.tr("Shadow glass blur")
            icon: "blur_on"
            configValue: Appearance.angel.shadowGlassBlur
            configPath: "appearance.angel.escalonadoShadow.glassBlur"
        }

        SliderRow {
            label: Translation.tr("Shadow glass overlay")
            icon: "layers"
            configValue: Appearance.angel.shadowGlassOverlay
            configPath: "appearance.angel.escalonadoShadow.glassOverlay"
        }
    }

    // ═══════════════════════════════════════════════════════
    // PARTIAL BORDER
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Partial Border & Accent")

        RealSpinRow {
            label: Translation.tr("Border width")
            icon: "line_weight"
            description: Translation.tr("Thickness of gradient border lines")
            configValue: Appearance.angel.borderWidth
            from: 0.0; to: 5.0; stepSize: 0.5
            configPath: "appearance.angel.border.width"
        }

        SliderRow {
            label: Translation.tr("Border coverage")
            icon: "border_all"
            description: Translation.tr("How much of each edge the border covers")
            configValue: Appearance.angel.borderCoverage
            configPath: "appearance.angel.border.coverage"
        }

        SliderRow {
            label: Translation.tr("Border opacity")
            icon: "opacity"
            configValue: Appearance.angel.borderOpacity
            configPath: "appearance.angel.border.opacity"
        }

        SliderRow {
            label: Translation.tr("Border hover opacity")
            icon: "mouse"
            configValue: Appearance.angel.borderHoverOpacity
            configPath: "appearance.angel.border.hoverOpacity"
        }

        SliderRow {
            label: Translation.tr("Border active opacity")
            icon: "touch_app"
            configValue: Appearance.angel.borderActiveOpacity
            configPath: "appearance.angel.border.activeOpacity"
        }

        SpinRow {
            label: Translation.tr("Top accent bar (px)")
            icon: "vertical_align_top"
            configValue: Appearance.angel.accentBarHeight
            from: 0; to: 10
            configPath: "appearance.angel.border.accentBarHeight"
        }

        SpinRow {
            label: Translation.tr("Left accent bar (px)")
            icon: "align_horizontal_left"
            configValue: Appearance.angel.accentBarWidth
            from: 0; to: 10
            configPath: "appearance.angel.border.accentBarWidth"
        }

        SpinRow {
            label: Translation.tr("Inset glow height (px)")
            icon: "wb_twilight"
            configValue: Appearance.angel.insetGlowHeight
            from: 0; to: 5
            configPath: "appearance.angel.border.insetGlowHeight"
        }

        SliderRow {
            label: Translation.tr("Inset glow opacity")
            icon: "flare"
            configValue: Appearance.angel.insetGlowOpacity
            configPath: "appearance.angel.border.insetGlowOpacity"
        }
    }

    // ═══════════════════════════════════════════════════════
    // SURFACE BORDERS
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Surface Borders")

        SpinRow {
            label: Translation.tr("Panel border width (px)")
            icon: "dock_to_bottom"
            description: Translation.tr("Bar, dock, sidebar outer border")
            configValue: Appearance.angel.panelBorderWidth
            from: 0; to: 3
            configPath: "appearance.angel.surface.panelBorderWidth"
        }

        SliderRow {
            label: Translation.tr("Panel border opacity")
            icon: "opacity"
            configValue: Appearance.angel.panelBorderOpacity
            configPath: "appearance.angel.surface.panelBorderOpacity"
        }

        SpinRow {
            label: Translation.tr("Card border width (px)")
            icon: "crop_square"
            description: Translation.tr("Inner card/container border")
            configValue: Appearance.angel.cardBorderWidth
            from: 0; to: 3
            configPath: "appearance.angel.surface.cardBorderWidth"
        }

        SliderRow {
            label: Translation.tr("Card border opacity")
            icon: "opacity"
            configValue: Appearance.angel.cardBorderOpacity
            configPath: "appearance.angel.surface.cardBorderOpacity"
        }
    }

    // ═══════════════════════════════════════════════════════
    // GLOW
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Glow Effects")

        SliderRow {
            label: Translation.tr("Glow opacity")
            icon: "flare"
            configValue: Appearance.angel.glowOpacity
            configPath: "appearance.angel.glow.opacity"
        }

        SliderRow {
            label: Translation.tr("Strong glow opacity")
            icon: "auto_awesome"
            configValue: Appearance.angel.glowStrongOpacity
            configPath: "appearance.angel.glow.strongOpacity"
        }
    }

    // ═══════════════════════════════════════════════════════
    // ROUNDING
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Rounding")

        SpinRow {
            label: Translation.tr("Small radius")
            icon: "rounded_corner"
            description: Translation.tr("Buttons, badges, small elements")
            configValue: Appearance.angel.roundingSmall
            from: 0; to: 30
            configPath: "appearance.angel.rounding.small"
        }

        SpinRow {
            label: Translation.tr("Normal radius")
            icon: "rounded_corner"
            description: Translation.tr("Cards, popups, tooltips")
            configValue: Appearance.angel.roundingNormal
            from: 0; to: 40
            configPath: "appearance.angel.rounding.normal"
        }

        SpinRow {
            label: Translation.tr("Large radius")
            icon: "rounded_corner"
            description: Translation.tr("Panels, dialogs, large containers")
            configValue: Appearance.angel.roundingLarge
            from: 0; to: 50
            configPath: "appearance.angel.rounding.large"
        }
    }
}
