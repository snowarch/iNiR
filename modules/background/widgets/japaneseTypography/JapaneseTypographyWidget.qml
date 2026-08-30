pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import "JapaneseTypographyPresets.js" as JapanesePresets

AbstractBackgroundWidget {
    id: root

    configEntryName: "japaneseTypography"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        preset: "exhibition",
        primaryText: "夏の記憶",
        secondaryText: "潮風と、あの子と、終わらない夏",
        sealText: "特別展",
        footerText: "PACIFIC DRIVE-IN",
        dateText: "7.12 — 8.31",
        showSecondary: true,
        showSeal: true,
        showFooter: true,
        showRule: true,
        fontPreset: "mincho",
        fontFamily: "serif",
        secondaryFontFamily: "",
        latinFontFamily: "",
        primaryWeight: 500,
        secondaryWeight: 400,
        latinWeight: 600,
        primarySize: 72,
        secondarySize: 18,
        footerSize: 14,
        dateSize: 12,
        primaryColumns: 2,
        secondaryColumns: 2,
        columnGap: 14,
        letterSpacing: 2,
        secondaryLetterSpacing: 1,
        mirrorLayout: false,
        rotateLatin: false,
        paletteMode: "adaptive",
        palettePreset: "adaptive",
        primaryColor: "#E7D4B2",
        secondaryColor: "#CDB48D",
        sealColor: "#A64B39",
        detailColor: "#D0B996",
        ruleColor: "#C18A53",
        primaryOpacity: 100,
        secondaryOpacity: 78,
        sealOpacity: 100,
        detailOpacity: 72,
        ruleOpacity: 78,
        sealFillOpacity: 0,
        ruleThickness: 1,
        outlineColor: "#000000",
        outlineOpacity: 0,
        shadowStrength: 35,
        contentWidth: 330,
        contentHeight: 600,
        dim: 10,
        widgetScale: 100,
        widgetOpacity: 100,
        showBackground: false,
        useBlur: false,
        showBorder: false,
        backgroundOpacity: 0,
        borderWidth: 0,
        borderOpacity: 0.12,
        cornerRadius: -1,
        colorMode: "auto",
        x: 56,
        y: 120
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 330) * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 600) * root.scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 220
    resizeMinHeight: 320
    resizeMaxWidth: 720
    resizeMaxHeight: 1000
    needsColText: true
    liveColorTracking: true

    readonly property string compositionPreset: Config.getNestedValue("background.widgets.japaneseTypography.preset", "exhibition")
    readonly property string palettePreset: Config.getNestedValue("background.widgets.japaneseTypography.palettePreset", "adaptive")
    readonly property string fontPreset: Config.getNestedValue("background.widgets.japaneseTypography.fontPreset", "mincho")

    function applyCompositionPreset(preset: string): void {
        Config.setNestedValues(JapanesePresets.composition(root._configPath, preset));
    }

    function applyPalettePreset(preset: string): void {
        Config.setNestedValues(JapanesePresets.palette(root._configPath, preset));
    }

    function applyFontPreset(preset: string): void {
        Config.setNestedValues(JapanesePresets.font(root._configPath, preset));
    }

    function setCompositionOption(key: string, value: var): void {
        Config.setNestedValues(JapanesePresets.setValue(root._configPath, key, value, "composition"));
    }

    editPopoverContent: Component {
        GridLayout {
            implicitWidth: 520
            columns: 2
            columnSpacing: 10
            rowSpacing: 0

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                StyledText {
                    text: Translation.tr("Composition")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { label: "Exhibition", icon: "museum", value: "exhibition" },
                            { label: "Magazine", icon: "newspaper", value: "magazine" },
                            { label: "Minimal", icon: "view_agenda", value: "minimal" },
                            { label: "Traditional", icon: "history_edu", value: "traditional" }
                        ]
                        SelectionGroupButton {
                            required property var modelData
                            Layout.fillWidth: true
                            leftmost: true; rightmost: true
                            buttonIcon: modelData.icon
                            buttonText: Translation.tr(modelData.label)
                            toggled: root.compositionPreset === modelData.value
                            onClicked: root.applyCompositionPreset(modelData.value)
                        }
                    }
                }

                StyledText {
                    Layout.topMargin: 4
                    text: Translation.tr("Typography")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { label: "Mincho", icon: "history_edu", value: "mincho" },
                            { label: "Mixed", icon: "format_shapes", value: "mixed" },
                            { label: "Gothic", icon: "text_fields", value: "gothic" }
                        ]
                        SelectionGroupButton {
                            required property var modelData
                            Layout.fillWidth: true
                            leftmost: true; rightmost: true
                            buttonIcon: modelData.icon
                            buttonText: Translation.tr(modelData.label)
                            toggled: root.fontPreset === modelData.value
                            onClicked: root.applyFontPreset(modelData.value)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 6

                StyledText {
                    text: Translation.tr("Palette")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { label: "Auto", icon: "auto_awesome", value: "adaptive" },
                            { label: "Sumi", icon: "dark_mode", value: "sumi" },
                            { label: "Ivory", icon: "light_mode", value: "ivory" },
                            { label: "Sunset", icon: "wb_twilight", value: "sunset" },
                            { label: "Cinema", icon: "movie", value: "cinema" }
                        ]
                        SelectionGroupButton {
                            required property var modelData
                            Layout.fillWidth: true
                            leftmost: true; rightmost: true
                            buttonIcon: modelData.icon
                            buttonText: Translation.tr(modelData.label)
                            toggled: root.palettePreset === modelData.value
                            onClicked: root.applyPalettePreset(modelData.value)
                        }
                    }
                }

                StyledText {
                    Layout.topMargin: 4
                    text: Translation.tr("Visible elements")
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { key: "showSecondary", label: "Secondary", icon: "notes", value: root.showSecondary },
                            { key: "showSeal", label: "Seal", icon: "ink_pen", value: root.showSeal },
                            { key: "showFooter", label: "Footer", icon: "subtitles", value: root.showFooter },
                            { key: "mirrorLayout", label: "Mirror", icon: "swap_horiz", value: root.mirrorLayout }
                        ]
                        SelectionGroupButton {
                            required property var modelData
                            Layout.fillWidth: true
                            leftmost: true; rightmost: true
                            buttonIcon: modelData.icon
                            buttonText: Translation.tr(modelData.label)
                            toggled: Boolean(modelData.value)
                            onClicked: root.setCompositionOption(modelData.key, !Boolean(modelData.value))
                        }
                    }
                }
            }
        }
    }

    readonly property string primaryText: Config.getNestedValue("background.widgets.japaneseTypography.primaryText", "夏の記憶")
    readonly property string secondaryText: Config.getNestedValue("background.widgets.japaneseTypography.secondaryText", "潮風と、あの子と、終わらない夏")
    readonly property string sealText: Config.getNestedValue("background.widgets.japaneseTypography.sealText", "特別展")
    readonly property string footerText: Config.getNestedValue("background.widgets.japaneseTypography.footerText", "PACIFIC DRIVE-IN")
    readonly property string dateText: Config.getNestedValue("background.widgets.japaneseTypography.dateText", "7.12 — 8.31")
    readonly property bool showSecondary: Config.getNestedValue("background.widgets.japaneseTypography.showSecondary", true)
    readonly property bool showSeal: Config.getNestedValue("background.widgets.japaneseTypography.showSeal", true)
    readonly property bool showFooter: Config.getNestedValue("background.widgets.japaneseTypography.showFooter", true)
    readonly property bool showRule: Config.getNestedValue("background.widgets.japaneseTypography.showRule", true)
    readonly property bool mirrorLayout: Config.getNestedValue("background.widgets.japaneseTypography.mirrorLayout", false)
    readonly property bool rotateLatin: Config.getNestedValue("background.widgets.japaneseTypography.rotateLatin", false)

    readonly property string fontFamily: Config.getNestedValue("background.widgets.japaneseTypography.fontFamily", "serif")
    readonly property string secondaryFontFamily: {
        const configured = Config.getNestedValue("background.widgets.japaneseTypography.secondaryFontFamily", "");
        return configured.length > 0 ? configured : root.fontFamily;
    }
    readonly property string latinFontFamily: {
        const configured = Config.getNestedValue("background.widgets.japaneseTypography.latinFontFamily", "");
        return configured.length > 0 ? configured : Appearance.font.family.main;
    }
    readonly property int primaryWeight: Config.getNestedValue("background.widgets.japaneseTypography.primaryWeight", 500)
    readonly property int secondaryWeight: Config.getNestedValue("background.widgets.japaneseTypography.secondaryWeight", 400)
    readonly property int latinWeight: Config.getNestedValue("background.widgets.japaneseTypography.latinWeight", 600)
    readonly property real primarySize: Config.getNestedValue("background.widgets.japaneseTypography.primarySize", 72)
    readonly property real secondarySize: Config.getNestedValue("background.widgets.japaneseTypography.secondarySize", 18)
    readonly property real footerSize: Config.getNestedValue("background.widgets.japaneseTypography.footerSize", 14)
    readonly property real dateSize: Config.getNestedValue("background.widgets.japaneseTypography.dateSize", 12)
    readonly property int primaryColumns: Math.max(1, Math.min(4,
        Config.getNestedValue("background.widgets.japaneseTypography.primaryColumns", 2)))
    readonly property int secondaryColumns: Math.max(1, Math.min(5,
        Config.getNestedValue("background.widgets.japaneseTypography.secondaryColumns", 2)))
    readonly property real configuredColumnGap: Config.getNestedValue("background.widgets.japaneseTypography.columnGap", 14)
    readonly property real configuredLetterSpacing: Config.getNestedValue("background.widgets.japaneseTypography.letterSpacing", 2)
    readonly property real configuredSecondaryLetterSpacing: Config.getNestedValue("background.widgets.japaneseTypography.secondaryLetterSpacing", 1)

    readonly property string paletteMode: Config.getNestedValue("background.widgets.japaneseTypography.paletteMode", "adaptive")
    readonly property bool manualPalette: root.paletteMode === "manual"
    // Manual editorial colors already have dedicated controls; avoid showing a
    // second palette control that would not affect the current rendering.
    semanticPaletteQuickControls: !root.manualPalette
    readonly property real primaryOpacity: root._percent("primaryOpacity", 100)
    readonly property real secondaryOpacity: root._percent("secondaryOpacity", 78)
    readonly property real sealOpacity: root._percent("sealOpacity", 100)
    readonly property real detailOpacity: root._percent("detailOpacity", 72)
    readonly property real ruleOpacity: root._percent("ruleOpacity", 78)
    readonly property real sealFillOpacity: root._percent("sealFillOpacity", 0)
    readonly property real outlineOpacity: root._percent("outlineOpacity", 0)
    readonly property real shadowStrength: root._percent("shadowStrength", 35)
    readonly property int ruleThickness: Math.max(1, Math.min(6,
        Config.getNestedValue("background.widgets.japaneseTypography.ruleThickness", 1)))

    readonly property real outerPad: Math.round(Math.max(12 * root.scaleFactor, Math.min(root.width, root.height) * 0.035))
    readonly property bool compact: root.width < 270 * root.scaleFactor || root.height < 430 * root.scaleFactor
    readonly property real footerExtent: root.showFooter
        ? Math.round(Math.max(54 * root.scaleFactor, Math.min(98 * root.scaleFactor, root.height * 0.16)))
        : 0
    readonly property real leadPixelSize: Math.max(28 * root.scaleFactor, Math.min(
        root.primarySize * root.scaleFactor,
        Math.max(28 * root.scaleFactor, body.height / 5.2),
        Math.max(28 * root.scaleFactor, body.width * (root.compact ? 0.27 : 0.23))))
    readonly property real notePixelSize: Math.max(11 * root.scaleFactor, Math.min(
        root.secondarySize * root.scaleFactor,
        Math.max(11 * root.scaleFactor, body.height / 16),
        Math.max(11 * root.scaleFactor, body.width * 0.085)))
    readonly property real effectiveColumnGap: Math.max(6 * root.scaleFactor, root.configuredColumnGap * root.scaleFactor)
    readonly property real effectiveLetterSpacing: Math.max(0, root.configuredLetterSpacing * root.scaleFactor)
    readonly property real effectiveSecondaryLetterSpacing: Math.max(0, root.configuredSecondaryLetterSpacing * root.scaleFactor)
    readonly property real leadNaturalWidth: root.leadPixelSize * 1.08 * root.primaryColumns
        + root.effectiveColumnGap * Math.max(0, root.primaryColumns - 1)
    readonly property real noteNaturalWidth: root.notePixelSize * 1.08 * root.secondaryColumns
        + Math.max(5 * root.scaleFactor, root.effectiveColumnGap * 0.65) * Math.max(0, root.secondaryColumns - 1)
    readonly property real leadWidth: Math.min(
        body.width * (root.showSecondary ? (root.compact ? 0.62 : 0.54) : 0.94),
        Math.max(root.leadNaturalWidth, body.width * (root.compact ? 0.48 : 0.38)))
    readonly property real noteWidth: Math.min(body.width * 0.30,
        Math.max(root.noteNaturalWidth, root.notePixelSize * 1.8))

    // Adaptive mode selects only generated semantic tokens. Manual palette mode
    // remains explicit user RGB intent and is intentionally left untouched.
    readonly property color adaptivePrimaryInk: root.widgetSemanticForeground(root.widgetPrimaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveSecondaryInk: root.widgetSemanticForeground(root.widgetSecondaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveDetailInk: root.widgetSemanticForeground(root.widgetTertiaryRole, root.accentBackdrop, 4.5)
    readonly property color adaptiveRuleInk: root.widgetSemanticForeground(root.widgetTertiaryRole, root.accentBackdrop, 3.0)
    readonly property color adaptiveSealInk: root.widgetSemanticForeground(root.widgetSignalRole, root.accentBackdrop, 3.0)

    readonly property color leadInk: root._roleColor(
        Config.getNestedValue("background.widgets.japaneseTypography.primaryColor", "#E7D4B2"),
        root.adaptivePrimaryInk, root.primaryOpacity)
    readonly property color noteInk: root._roleColor(
        Config.getNestedValue("background.widgets.japaneseTypography.secondaryColor", "#CDB48D"),
        root.adaptiveSecondaryInk, root.secondaryOpacity)
    readonly property color sealBase: root.manualPalette
        ? root._safeColor(Config.getNestedValue("background.widgets.japaneseTypography.sealColor", "#A64B39"), root.adaptiveSealInk)
        : root.adaptiveSealInk
    readonly property color sealInk: ColorUtils.applyAlpha(root.sealBase, root.sealOpacity)
    readonly property color detailInk: root._roleColor(
        Config.getNestedValue("background.widgets.japaneseTypography.detailColor", "#D0B996"),
        root.adaptiveDetailInk, root.detailOpacity)
    readonly property color ruleInk: root._roleColor(
        Config.getNestedValue("background.widgets.japaneseTypography.ruleColor", "#C18A53"),
        root.adaptiveRuleInk, root.ruleOpacity)
    readonly property color editorialHalo: ColorUtils.applyAlpha(
        ColorUtils.relativeLuminance(root.leadInk) >= 0.42
            ? Qt.rgba(0, 0, 0, 1)
            : Qt.rgba(1, 0.97, 0.92, 1),
        0.92)
    readonly property color outlineInk: ColorUtils.applyAlpha(
        root._safeColor(Config.getNestedValue("background.widgets.japaneseTypography.outlineColor", "#000000"), root.editorialHalo),
        root.outlineOpacity)
    readonly property int glyphTextStyle: root.outlineOpacity > 0 ? Text.Outline : Text.Normal

    function _percent(key: string, fallback: real): real {
        const value = Number(Config.getNestedValue("background.widgets.japaneseTypography." + key, fallback));
        return Math.max(0, Math.min(1, (Number.isFinite(value) ? value : fallback) / 100));
    }

    function _safeColor(value: var, fallback: color): color {
        const parsed = Qt.color(String(value ?? ""));
        return parsed.valid ? parsed : fallback;
    }

    function _roleColor(manualValue: var, adaptiveValue: color, opacity: real): color {
        const base = root.manualPalette ? root._safeColor(manualValue, adaptiveValue) : adaptiveValue;
        return ColorUtils.applyAlpha(base, opacity);
    }

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetPlateColor
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    Item {
        id: editorialComposition
        anchors.fill: parent
        anchors.margins: root.outerPad
        clip: true

        layer.enabled: root.shadowStrength > 0 && !root.widgetHasSurface
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.editorialHalo
            shadowOpacity: root.shadowStrength
                * (ColorUtils.relativeLuminance(root.leadInk) >= 0.42 ? 1.0 : 0.58)
            shadowBlur: 0.62
            shadowHorizontalOffset: 1
            shadowVerticalOffset: 2
        }

        Item {
            id: body
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: footerBlock.visible ? footerBlock.top : parent.bottom
                bottomMargin: footerBlock.visible ? Math.round(12 * root.scaleFactor) : 0
            }
            clip: true

            VerticalJapaneseText {
                id: leadColumn
                x: root.mirrorLayout ? body.width - width : 0
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                }
                width: root.leadWidth
                text: root.primaryText
                fontFamily: root.fontFamily
                fontPixelSize: root.leadPixelSize
                fontWeight: root.primaryWeight
                letterSpacing: root.effectiveLetterSpacing
                columnGap: root.effectiveColumnGap
                maxColumns: root.compact ? 1 : root.primaryColumns
                rotateLatin: root.rotateLatin
                color: root.leadInk
                textStyle: root.glyphTextStyle
                styleColor: root.outlineInk
            }

            VerticalJapaneseText {
                id: editorialNote
                visible: root.showSecondary && body.width >= 210 * root.scaleFactor && body.height >= 240 * root.scaleFactor
                x: root.mirrorLayout
                    ? Math.max(0, leadColumn.x - root.effectiveColumnGap - width)
                    : Math.min(body.width - width, leadColumn.x + leadColumn.width + root.effectiveColumnGap)
                anchors {
                    top: parent.top
                    topMargin: Math.round(root.leadPixelSize * 0.18)
                    bottom: parent.bottom
                }
                width: root.noteWidth
                text: root.secondaryText
                fontFamily: root.secondaryFontFamily
                fontPixelSize: root.notePixelSize
                fontWeight: root.secondaryWeight
                letterSpacing: root.effectiveSecondaryLetterSpacing
                columnGap: Math.max(5 * root.scaleFactor, root.effectiveColumnGap * 0.65)
                maxColumns: root.compact ? 1 : root.secondaryColumns
                rotateLatin: root.rotateLatin
                color: root.noteInk
                textStyle: root.glyphTextStyle
                styleColor: root.outlineInk
            }

            Rectangle {
                id: seal
                visible: root.showSeal && body.width >= 220 * root.scaleFactor && body.height >= 260 * root.scaleFactor
                x: root.mirrorLayout ? 0 : body.width - width
                anchors.top: parent.top
                width: Math.max(34 * root.scaleFactor, root.notePixelSize * 2.35)
                height: Math.min(body.height * 0.30,
                    Math.max(74 * root.scaleFactor, Array.from(root.sealText).length * root.notePixelSize * 1.22 + 18 * root.scaleFactor))
                color: ColorUtils.applyAlpha(root.sealBase, root.sealFillOpacity)
                border.width: Math.max(1, Math.round(root.scaleFactor))
                border.color: root.sealInk
                radius: 0

                VerticalJapaneseText {
                    id: sealTypography
                    readonly property real innerPadding: Math.round(5 * root.scaleFactor)
                    anchors.centerIn: parent
                    width: Math.max(1, Math.min(
                        parent.width - sealTypography.innerPadding * 2,
                        sealTypography.cellSize))
                    height: Math.max(1, Math.min(
                        parent.height - sealTypography.innerPadding * 2,
                        Math.max(sealTypography.cellAdvance,
                            Array.from(root.sealText).length * sealTypography.cellAdvance)))
                    text: root.sealText
                    fontFamily: root.fontFamily
                    fontPixelSize: Math.max(10 * root.scaleFactor, root.notePixelSize * 0.86)
                    fontWeight: Font.DemiBold
                    letterSpacing: 0
                    columnGap: 0
                    maxColumns: 1
                    rotateLatin: root.rotateLatin
                    color: root.sealInk
                }
            }
        }

        Item {
            id: footerBlock
            visible: root.showFooter && root.footerExtent > 0
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: root.footerExtent

            Rectangle {
                visible: root.showRule
                x: root.mirrorLayout ? parent.width - width : 0
                anchors.top: parent.top
                width: Math.min(parent.width * 0.78, 250 * root.scaleFactor)
                height: Math.max(1, Math.round(root.ruleThickness * root.scaleFactor))
                color: root.ruleInk
            }

            StyledText {
                anchors {
                    left: parent.left
                    top: parent.top
                    topMargin: Math.round(10 * root.scaleFactor)
                    right: parent.right
                }
                text: root.footerText
                color: root.detailInk
                horizontalAlignment: root.mirrorLayout ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                style: root.glyphTextStyle
                styleColor: root.outlineInk
                font {
                    family: root.latinFontFamily
                    pixelSize: Math.max(9 * root.scaleFactor, Math.min(root.footerSize * root.scaleFactor, root.footerExtent * 0.28))
                    weight: root.latinWeight
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor))
                }
            }

            StyledText {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                text: root.dateText
                color: root.detailInk
                horizontalAlignment: root.mirrorLayout ? Text.AlignRight : Text.AlignLeft
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
                style: root.glyphTextStyle
                styleColor: root.outlineInk
                font {
                    family: root.latinFontFamily
                    pixelSize: Math.max(9 * root.scaleFactor, Math.min(root.dateSize * root.scaleFactor, root.footerExtent * 0.24))
                    weight: Font.Medium
                    letterSpacing: Math.max(0, Math.round(root.scaleFactor * 0.8))
                }
            }
        }
    }
}
