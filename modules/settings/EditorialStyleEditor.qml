pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: Appearance.editorial.sectionGap

    readonly property var _defaults: ({
        paperStack: false, paperDepth: 3,
        glass: false, glassOpacity: 0.72, glassBlur: 0.85, sidebarGlassBackground: true,
        paperMode: "theme", paperTone: "neutral", paperTint: 0.35, paperColor: "#b8c4b0",
        accentRole: "primary", accentColor: "#b5a0c8",
        labelWeight: 600, metadataTracking: 0.8, titleWeight: 650, titleTracking: -0.6,
        typography: "poster", titleScale: 1.0, warmth: 0.55, accentStrength: 0.55,
        spacing: 1.0, radiusScale: 1.0, ornaments: true, motionScale: 1.0
    })
    readonly property var _presets: [
        { key: "poster", label: Translation.tr("Poster"), icon: "text_fields",
            description: Translation.tr("Bold sans display"), values: ({
                typography: "poster", titleScale: 1.0, warmth: 0.55, accentStrength: 0.55,
                spacing: 1.0, radiusScale: 1.0, ornaments: true, motionScale: 1.0
            }) },
        { key: "studio", label: Translation.tr("Studio"), icon: "tune",
            description: Translation.tr("Compact and quiet"), values: ({
                paperStack: true, paperTone: "primary", paperTint: 0.35,
                typography: "poster", titleScale: 0.9, warmth: 0.35, accentStrength: 0.4,
                spacing: 0.86, radiusScale: 0.8, ornaments: false, motionScale: 0.8
            }) },
        { key: "reading", label: Translation.tr("Reading"), icon: "auto_stories",
            description: Translation.tr("Serif-led composition"), values: ({
                typography: "reading", titleScale: 1.1, warmth: 0.65, accentStrength: 0.4,
                spacing: 1.1, radiusScale: 1.1, ornaments: true, motionScale: 1.0
            }) }
    ]

    function value(key: string, fallback): var {
        const current = Config.options?.appearance?.editorial?.[key]
        return current === undefined ? fallback : current
    }

    readonly property string currentPreset: {
        const current = {
            typography: root.value("typography", "poster"),
            titleScale: Number(root.value("titleScale", 1.0)),
            warmth: Number(root.value("warmth", 0.55)),
            accentStrength: Number(root.value("accentStrength", 0.55)),
            spacing: Number(root.value("spacing", 1.0)),
            radiusScale: Number(root.value("radiusScale", 1.0)),
            ornaments: Boolean(root.value("ornaments", true)),
            motionScale: Number(root.value("motionScale", 1.0))
        }
        for (const preset of root._presets) {
            const values = preset.values
            if (Boolean(root.value("paperStack", false)) === (values.paperStack ?? false)
                    && Number(root.value("paperDepth", 3)) === (values.paperDepth ?? 3)
                    && Boolean(root.value("glass", false)) === (values.glass ?? false)
                    && Math.abs(Number(root.value("glassOpacity", 0.72)) - (values.glassOpacity ?? 0.72)) < 0.001
                    && Math.abs(Number(root.value("glassBlur", 0.85)) - (values.glassBlur ?? 0.85)) < 0.001
                    && Boolean(root.value("sidebarGlassBackground", true)) === (values.sidebarGlassBackground ?? true)
                    && root.value("paperMode", "theme") === (values.paperMode ?? "theme")
                    && root.value("paperTone", "neutral") === (values.paperTone ?? "neutral")
                    && Math.abs(Number(root.value("paperTint", 0.35)) - (values.paperTint ?? 0.35)) < 0.001
                    && root.value("paperColor", "#b8c4b0") === (values.paperColor ?? "#b8c4b0")
                    && root.value("accentRole", "primary") === (values.accentRole ?? "primary")
                    && root.value("accentColor", "#b5a0c8") === (values.accentColor ?? "#b5a0c8")
                    && Number(root.value("labelWeight", 600)) === (values.labelWeight ?? 600)
                    && Math.abs(Number(root.value("metadataTracking", 0.8)) - (values.metadataTracking ?? 0.8)) < 0.001
                    && Number(root.value("titleWeight", 650)) === (values.titleWeight ?? (preset.key === "reading" ? 600 : 650))
                    && Math.abs(Number(root.value("titleTracking", -0.6)) - (values.titleTracking ?? (preset.key === "reading" ? 0 : -0.6))) < 0.001
                    && values.typography === current.typography
                    && Math.abs(values.titleScale - current.titleScale) < 0.001
                    && Math.abs(values.warmth - current.warmth) < 0.001
                    && Math.abs(values.accentStrength - current.accentStrength) < 0.001
                    && Math.abs(values.spacing - current.spacing) < 0.001
                    && Math.abs(values.radiusScale - current.radiusScale) < 0.001
                    && values.ornaments === current.ornaments
                    && Math.abs(values.motionScale - current.motionScale) < 0.001)
                return preset.key
        }
        return "custom"
    }

    function applyValues(values): void {
        Config.setNestedValues({
            "appearance.editorial.paperStack": values.paperStack ?? false,
            "appearance.editorial.paperDepth": values.paperDepth ?? 3,
            "appearance.editorial.glass": values.glass ?? false,
            "appearance.editorial.glassOpacity": values.glassOpacity ?? 0.72,
            "appearance.editorial.glassBlur": values.glassBlur ?? 0.85,
            "appearance.editorial.sidebarGlassBackground": values.sidebarGlassBackground ?? true,
            "appearance.editorial.paperMode": values.paperMode ?? "theme",
            "appearance.editorial.paperTone": values.paperTone ?? "neutral",
            "appearance.editorial.paperTint": values.paperTint ?? 0.35,
            "appearance.editorial.paperColor": values.paperColor ?? "#b8c4b0",
            "appearance.editorial.accentRole": values.accentRole ?? "primary",
            "appearance.editorial.accentColor": values.accentColor ?? "#b5a0c8",
            "appearance.editorial.labelWeight": values.labelWeight ?? 600,
            "appearance.editorial.metadataTracking": values.metadataTracking ?? 0.8,
            "appearance.editorial.titleWeight": values.titleWeight ?? (values.typography === "reading" ? 600 : 650),
            "appearance.editorial.titleTracking": values.titleTracking ?? (values.typography === "reading" ? 0 : -0.6),
            "appearance.editorial.typography": values.typography,
            "appearance.editorial.titleScale": values.titleScale,
            "appearance.editorial.warmth": values.warmth,
            "appearance.editorial.accentStrength": values.accentStrength,
            "appearance.editorial.spacing": values.spacing,
            "appearance.editorial.radiusScale": values.radiusScale,
            "appearance.editorial.ornaments": values.ornaments,
            "appearance.editorial.motionScale": values.motionScale
        })
    }

    function resetEditorial(): void { root.applyValues(root._defaults) }

    component SliderRow: ColumnLayout {
        id: sliderRoot
        Layout.fillWidth: true
        spacing: 3
        property string label: ""
        property string description: ""
        property real from: 0
        property real to: 1
        property real stepSize: 0.05
        property real value: 0
        property string suffix: ""
        property string configPath: ""
        property bool commitOnRelease: true

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: sliderRoot.label
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.editorial.ink
            }
            StyledText {
                text: (sliderRoot.commitOnRelease && slider.pressed ? slider.value : sliderRoot.value)
                    .toFixed(sliderRoot.stepSize >= 1 ? 0 : 2) + sliderRoot.suffix
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.editorial.accent
            }
        }
        StyledText {
            Layout.fillWidth: true
            visible: sliderRoot.description.length > 0
            text: sliderRoot.description
            wrapMode: Text.WordWrap
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.editorial.muted
        }
        StyledSlider {
            id: slider
            Layout.fillWidth: true
            from: sliderRoot.from
            to: sliderRoot.to
            stepSize: sliderRoot.stepSize
            value: sliderRoot.value
            configuration: StyledSlider.Configuration.S
            settingsSearchLabel: sliderRoot.label
            settingsSearchDescription: sliderRoot.description
            settingsSearchKeywords: ["editorial", "style", sliderRoot.label.toLowerCase()]
            property bool pendingCommit: false
            onMoved: {
                if (sliderRoot.commitOnRelease && pressed)
                    pendingCommit = true
                else
                    Config.setNestedValue(sliderRoot.configPath, Math.round(value * 100) / 100)
            }
            onPressedChanged: {
                if (!pressed && pendingCommit) {
                    pendingCommit = false
                    Config.setNestedValue(sliderRoot.configPath, Math.round(value * 100) / 100)
                }
            }
        }
    }

    component StudioColumnLabel: StyledText {
        font.pixelSize: Appearance.font.pixelSize.smallest
        font.weight: Appearance.editorial.labelWeight
        font.letterSpacing: Appearance.editorial.metadataTracking
        color: Appearance.editorial.muted
    }

    component StudioCard: Rectangle {
        id: studioCard
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: studioCardColumn.implicitHeight + Appearance.editorial.cardInset * 2
        radius: Appearance.editorial.radius
        color: Appearance.editorial.layer(1)

        property string title: ""
        property string subtitle: ""
        property string icon: ""
        default property alias contentData: studioCardBody.data

        ColumnLayout {
            id: studioCardColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Appearance.editorial.cardInset
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                MaterialSymbol {
                    visible: studioCard.icon.length > 0
                    text: studioCard.icon
                    iconSize: 18
                    color: Appearance.editorial.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: studioCard.title
                        font.family: Appearance.font.family.title
                        font.pixelSize: Appearance.font.pixelSize.larger * Appearance.editorial.titleScale
                        font.weight: Appearance.editorial.titleWeight
                        font.letterSpacing: Appearance.editorial.titleTracking
                        color: Appearance.editorial.ink
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: studioCard.subtitle.length > 0
                        text: studioCard.subtitle
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.editorial.muted
                        wrapMode: Text.WordWrap
                    }
                }
            }

            EditorialRule {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                inset: 0
            }

            ColumnLayout {
                id: studioCardBody
                Layout.fillWidth: true
                spacing: 8
            }
        }
    }

    // This is the same paper/ink/rule composition used by the shell, not a
    // decorative mock. Every control below writes the tokens this preview reads.
    PanelSurface {
        Layout.fillWidth: true
        implicitHeight: editorialPreview.implicitHeight + 28
        elevation: 1
        editorialFocus: true
        // The composition owns its footer rule; avoid PanelSurface adding a
        // second perimeter rule around the same preview.
        outlined: false
        surfaceDialect: "editorial"
        ColumnLayout {
            id: editorialPreview
            anchors.fill: parent
            anchors.margins: 14
            spacing: Math.round(7 * Appearance.editorial.spacing)
            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("EDITORIAL / LIVE COMPOSITION")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Appearance.editorial.labelWeight
                    font.letterSpacing: Appearance.editorial.metadataTracking
                    color: Appearance.editorial.paperOnInk
                }
                MaterialShape {
                    implicitSize: 18
                    visible: Appearance.editorial.ornaments
                    shape: MaterialShape.Shape.Flower
                    color: Appearance.editorial.paperOnInk
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Make room for wonder.")
                font.family: Appearance.font.family.title
                font.pixelSize: 32 * Appearance.editorial.titleScale * Appearance.fontSizeScale
                font.letterSpacing: Appearance.editorial.titleTracking
                font.weight: Appearance.editorial.titleWeight
                font.italic: Appearance.editorial.typography === "reading"
                wrapMode: Text.WordWrap
                color: Appearance.editorial.paperOnInk
            }
            EditorialRule {
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                inset: 0
                color: Appearance.editorial.paperOnInk
                emphasized: true
            }
            StyledText {
                Layout.fillWidth: true
                text: Appearance.editorial.typography === "reading"
                    ? Translation.tr("A slower page for focused reading.")
                    : Translation.tr("A clear interface with a point of view.")
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
                color: ColorUtils.applyAlpha(Appearance.editorial.paperOnInk, 0.72)
            }
        }
    }

    StudioCard {
        title: Translation.tr("Presets")
        subtitle: root.currentPreset === "custom"
            ? Translation.tr("Custom composition")
            : Translation.tr("Current direction: %1").arg(root.currentPreset)
        icon: "auto_awesome"

        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 620 ? 3 : 1
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: root._presets
                delegate: RippleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    implicitHeight: root.width >= 620 ? 64 : 54
                    buttonRadius: Appearance.rounding.small
                    colBackground: root.currentPreset === modelData.key
                        ? Appearance.editorial.field : Appearance.editorial.layer(2)
                    colBackgroundHover: root.currentPreset === modelData.key
                        ? Appearance.editorial.selectionHover : Appearance.editorial.controlHover
                    onClicked: root.applyValues(modelData.values)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 18
                            color: root.currentPreset === modelData.key
                                ? Appearance.editorial.fieldInk : Appearance.editorial.accent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.label
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Appearance.editorial.labelWeight
                                color: root.currentPreset === modelData.key
                                    ? Appearance.editorial.fieldInk : Appearance.editorial.ink
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.description
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: root.currentPreset === modelData.key
                                    ? ColorUtils.applyAlpha(Appearance.editorial.fieldInk, 0.72)
                                    : Appearance.editorial.muted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    StudioCard {
        title: Translation.tr("Material")
        subtitle: Translation.tr("Choose the paper, then shape its depth and atmosphere.")
        icon: "texture"

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 620 * Appearance.fontSizeScale ? 2 : 1
            columnSpacing: 18
            rowSpacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 8

                StudioColumnLabel { text: Translation.tr("PAPER") }

                ConfigSelectionArray {
                    currentValue: Appearance.editorial.paperMode
                    options: [
                        { displayName: Translation.tr("Follow theme"), value: "theme" },
                        { displayName: Translation.tr("Light paper"), value: "light" },
                        { displayName: Translation.tr("Charcoal"), value: "dark" }
                    ]
                    onSelected: value => Config.setNestedValue("appearance.editorial.paperMode", value)
                }

                ConfigSelectionArray {
                    currentValue: Appearance.editorial.paperTone
                    options: [
                        { displayName: Translation.tr("Neutral"), value: "neutral" },
                        { displayName: Translation.tr("Primary"), value: "primary" },
                        { displayName: Translation.tr("Secondary"), value: "secondary" },
                        { displayName: Translation.tr("Tertiary"), value: "tertiary" },
                        { displayName: Translation.tr("Custom"), value: "custom" }
                    ]
                    onSelected: value => Config.setNestedValue("appearance.editorial.paperTone", value)
                }

                ColorPickerRow {
                    visible: Appearance.editorial.paperTone === "custom"
                    label: Translation.tr("Paper pigment")
                    colorKey: "paperColor"
                    configPath: "appearance.editorial.paperColor"
                }

                SliderRow {
                    visible: Appearance.editorial.paperTone !== "neutral"
                    label: Translation.tr("Paper tint")
                    description: Translation.tr("Color depth of paper and the inverse focal cards.")
                    value: Appearance.editorial.paperTint
                    configPath: "appearance.editorial.paperTint"
                }

                SliderRow {
                    label: Translation.tr("Paper warmth")
                    description: Translation.tr("Warms the sheet without replacing its selected pigment.")
                    from: 0; to: 1; stepSize: 0.05
                    value: Number(root.value("warmth", 0.55))
                    configPath: "appearance.editorial.warmth"
                }

                ConfigSwitch {
                    buttonIcon: "layers"
                    text: Translation.tr("Second paper layer")
                    description: Translation.tr("A restrained backing sheet beneath major surfaces; compact controls stay flat.")
                    checked: Appearance.editorial.paperStack
                    onToggledByUser: checked => Config.setNestedValue("appearance.editorial.paperStack", checked)
                }

                SliderRow {
                    visible: Appearance.editorial.paperStack
                    label: Translation.tr("Layer depth")
                    description: Translation.tr("Maximum offset inside the host geometry.")
                    from: 2; to: 6; stepSize: 1; suffix: " px"
                    value: Appearance.editorial.paperDepth
                    configPath: "appearance.editorial.paperDepth"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 8

                StudioColumnLabel { text: Translation.tr("ATMOSPHERE") }

                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Glass background")
                    description: Translation.tr("Frost wallpaper beneath Editorial paper without changing host geometry.")
                    checked: Appearance.editorial.glass
                    onToggledByUser: checked => Config.setNestedValue("appearance.editorial.glass", checked)
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !Appearance.editorial.glass
                    text: Translation.tr("Enable glass to tune where wallpaper depth appears and how strongly it is diffused.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.editorial.muted
                }

                ConfigSelectionArray {
                    visible: Appearance.editorial.glass
                    currentValue: Appearance.editorial.sidebarGlassBackground ? "full" : "leading"
                    options: [
                        { displayName: Translation.tr("Leading card"), icon: "crop_portrait", value: "leading" },
                        { displayName: Translation.tr("Full sidebar"), icon: "view_sidebar", value: "full" }
                    ]
                    onSelected: value => Config.setNestedValue("appearance.editorial.sidebarGlassBackground", value === "full")
                }

                SliderRow {
                    visible: Appearance.editorial.glass
                    label: Translation.tr("Paper opacity")
                    description: Translation.tr("How much paper remains above the blurred wallpaper.")
                    from: 0.55; to: 0.9; stepSize: 0.05
                    value: Appearance.editorial.glassOpacity
                    configPath: "appearance.editorial.glassOpacity"
                }

                SliderRow {
                    visible: Appearance.editorial.glass
                    label: Translation.tr("Backdrop blur")
                    description: Translation.tr("Softens wallpaper detail while preserving the Editorial silhouette.")
                    from: 0.25; to: 1; stepSize: 0.05
                    value: Appearance.editorial.glassBlur
                    configPath: "appearance.editorial.glassBlur"
                }
            }
        }
    }

    StudioCard {
        title: Translation.tr("Voice & ink")
        subtitle: Translation.tr("Type establishes hierarchy; accent ink carries selection and emphasis.")
        icon: "edit_note"

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 620 * Appearance.fontSizeScale ? 2 : 1
            columnSpacing: 18
            rowSpacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 8

                StudioColumnLabel { text: Translation.tr("TYPOGRAPHY") }

                ConfigSelectionArray {
                    currentValue: root.value("typography", "poster")
                    options: [
                        { displayName: Translation.tr("Poster sans"), icon: "text_fields", value: "poster" },
                        { displayName: Translation.tr("Reading serif"), icon: "auto_stories", value: "reading" }
                    ]
                    onSelected: value => Config.setNestedValue("appearance.editorial.typography", value)
                }

                SliderRow {
                    label: Translation.tr("Title scale")
                    description: Translation.tr("Scales display headings without moving their targets.")
                    from: 0.8; to: 1.3; stepSize: 0.05; suffix: "×"
                    value: Number(root.value("titleScale", 1.0))
                    configPath: "appearance.editorial.titleScale"
                }

                SliderRow {
                    label: Translation.tr("Headline weight")
                    from: 400; to: 900; stepSize: 50
                    value: Appearance.editorial.titleWeight
                    configPath: "appearance.editorial.titleWeight"
                }

                SliderRow {
                    label: Translation.tr("Label weight")
                    description: Translation.tr("Weight of control labels and small headings.")
                    from: 400; to: 700; stepSize: 50
                    value: Appearance.editorial.labelWeight
                    configPath: "appearance.editorial.labelWeight"
                    commitOnRelease: true
                }

                SliderRow {
                    label: Translation.tr("Metadata tracking")
                    description: Translation.tr("Spacing for short uppercase labels.")
                    from: 0; to: 1.5; stepSize: 0.1
                    value: Appearance.editorial.metadataTracking
                    configPath: "appearance.editorial.metadataTracking"
                    commitOnRelease: true
                }

                SliderRow {
                    label: Translation.tr("Headline tracking")
                    from: -1.5; to: 1.5; stepSize: 0.1; suffix: " px"
                    value: Appearance.editorial.titleTracking
                    configPath: "appearance.editorial.titleTracking"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 8

                StudioColumnLabel { text: Translation.tr("ACCENT INK") }

                ConfigSelectionArray {
                    currentValue: Appearance.editorial.accentRole
                    options: [
                        { displayName: Translation.tr("Primary"), value: "primary" },
                        { displayName: Translation.tr("Secondary"), value: "secondary" },
                        { displayName: Translation.tr("Tertiary"), value: "tertiary" },
                        { displayName: Translation.tr("Custom"), value: "custom" }
                    ]
                    onSelected: value => Config.setNestedValue("appearance.editorial.accentRole", value)
                }

                ColorPickerRow {
                    visible: Appearance.editorial.accentRole === "custom"
                    label: Translation.tr("Accent pigment")
                    colorKey: "accentColor"
                    configPath: "appearance.editorial.accentColor"
                }

                SliderRow {
                    label: Translation.tr("Accent intensity")
                    description: Translation.tr("Moves from neutral ink to richer theme-colored highlights and tonal fields.")
                    from: 0; to: 1; stepSize: 0.05
                    value: Appearance.editorial.accentStrength
                    configPath: "appearance.editorial.accentStrength"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [
                            { label: Translation.tr("Accent"), background: Appearance.editorial.field, foreground: Appearance.editorial.fieldInk },
                            { label: Translation.tr("Secondary"), background: Appearance.editorial.secondaryField, foreground: Appearance.editorial.secondaryFieldInk },
                            { label: Translation.tr("Tertiary"), background: Appearance.editorial.tertiaryField, foreground: Appearance.editorial.tertiaryFieldInk }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            implicitHeight: toneLabel.implicitHeight + 20
                            radius: Appearance.rounding.small
                            color: modelData.background
                            StyledText {
                                id: toneLabel
                                anchors.centerIn: parent
                                width: Math.max(0, parent.width - 12)
                                text: modelData.label
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: modelData.foreground
                            }
                        }
                    }
                }
            }
        }
    }

    StudioCard {
        title: Translation.tr("Composition")
        subtitle: Translation.tr("Tune the rhythm of the page after its material and voice are established.")
        icon: "grid_view"

        GridLayout {
            Layout.fillWidth: true
            columns: width >= 620 * Appearance.fontSizeScale ? 2 : 1
            columnSpacing: 18
            rowSpacing: 10

            SliderRow {
                Layout.fillWidth: true
                label: Translation.tr("Spacing")
                description: Translation.tr("Opens or tightens Editorial gutters and section rhythm.")
                from: 0.8; to: 1.2; stepSize: 0.05; suffix: "×"
                value: Number(root.value("spacing", 1.0))
                configPath: "appearance.editorial.spacing"
                commitOnRelease: true
            }

            SliderRow {
                Layout.fillWidth: true
                label: Translation.tr("Corner radius")
                description: Translation.tr("Scales Editorial surface and compact-control corners together.")
                from: 0.5; to: 1.5; stepSize: 0.05; suffix: "×"
                value: Number(root.value("radiusScale", 1.0))
                configPath: "appearance.editorial.radiusScale"
            }

            SliderRow {
                Layout.fillWidth: true
                label: Translation.tr("Editorial motion")
                description: Translation.tr("Uses existing shell animation owners; reduced motion still wins.")
                from: 0.6; to: 1.4; stepSize: 0.05; suffix: "×"
                value: Number(root.value("motionScale", 1.0))
                configPath: "appearance.editorial.motionScale"
            }

            ConfigSwitch {
                Layout.fillWidth: true
                buttonIcon: "flare"
                text: Translation.tr("Flower accents")
                description: Translation.tr("Use the Flower as a contextual signature, not as decoration on every surface.")
                checked: Boolean(root.value("ornaments", true))
                onToggledByUser: checked => Config.setNestedValue("appearance.editorial.ornaments", checked)
            }
        }
    }

    RippleButton {
        Layout.alignment: Qt.AlignRight
        implicitWidth: resetLabel.implicitWidth + 28
        implicitHeight: 34
        buttonRadius: Appearance.rounding.small
        colBackground: Appearance.editorial.layer(1)
        colBackgroundHover: Appearance.editorial.controlHover
        onClicked: root.resetEditorial()
        contentItem: RowLayout {
            id: resetLabel
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol { text: "restart_alt"; iconSize: 15; color: Appearance.editorial.accent }
            StyledText { text: Translation.tr("Reset Editorial"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.editorial.ink }
        }
    }
}
