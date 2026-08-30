import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", style: "pill", shape: "pill",
        size: 200, tempSize: 80, iconSize: 80,
        showTemp: true, showIcon: true, showCondition: false, showMetrics: true,
        padding: 20, tempFontWeight: 500, conditionOpacity: 0.7,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1,
        x: 100, y: 200
    })

    readonly property string weatherStyle: root._readConfigKey("style") ?? "pill"
    readonly property string weatherShape: root._readConfigKey("shape") ?? "pill"
    readonly property real logicalShapeSize: Math.max(1,
        Number(root._readConfigKey("size") ?? 200))
    readonly property real contentScale: root.logicalShapeSize / 200
    readonly property int shapeSize: Math.round(root.logicalShapeSize * root.scaleFactor)
    readonly property int tempFontSize: Math.max(10, Math.round(
        Number(root._readConfigKey("tempSize") ?? 80)
            * root.scaleFactor * root.contentScale))
    readonly property int weatherIconSize: Math.max(12, Math.round(
        Number(root._readConfigKey("iconSize") ?? 80)
            * root.scaleFactor * root.contentScale))
    readonly property bool showTemp: Boolean(root._readConfigKey("showTemp") ?? true)
    readonly property bool showIcon: Boolean(root._readConfigKey("showIcon") ?? true)
    readonly property bool showCondition: Boolean(root._readConfigKey("showCondition") ?? false)
    readonly property bool showMetrics: Boolean(root._readConfigKey("showMetrics") ?? true)

    readonly property var _metricModel: {
        const d = Weather.data;
        if (!d)
            return [];
        const items = [];
        const push = (icon, value) => {
            if (value !== undefined && value !== null && String(value).length > 0)
                items.push({ icon: icon, value: String(value) });
        };
        push("humidity_percentage", d.humidity);
        push("air", d.wind);
        push("visibility", d.visib);
        push("rainy", d.precip);
        push("wb_sunny", d.sunrise);
        push("bedtime", d.sunset);
        return items;
    }
    readonly property int visibleContentCount: Number(showTemp) + Number(showIcon) + Number(showCondition)
    readonly property int weatherPadding: Math.max(4, Math.round(
        Number(root._readConfigKey("padding") ?? 20)
            * root.scaleFactor * root.contentScale))
    readonly property int contentInset: Math.max(root.weatherPadding,
        Math.round(root.shapeSize * 0.13))
    readonly property int conditionFontSize: Math.max(8, Math.round(
        Appearance.font.pixelSize.small * root.scaleFactor * root.contentScale))
    readonly property int tempFontWeight: Number(root._readConfigKey("tempFontWeight") ?? 500)
    readonly property real conditionOpacity: Number(root._readConfigKey("conditionOpacity") ?? 0.7)
    readonly property string temperatureText: {
        const raw = String(Weather.data?.temp ?? "--°");
        if (raw.endsWith("°C") || raw.endsWith("°F")) return raw.slice(0, -1);
        if (raw.endsWith("°")) return raw;
        return raw + "°";
    }

    implicitWidth: root.weatherStyle === "detail" ? Math.round(shapeSize * 2.2) : shapeSize
    implicitHeight: root.weatherStyle === "detail" ? Math.round(shapeSize * 0.95) : shapeSize
    resizableAxes: ({ uniform: "size" })
    resizeMinWidth: root.weatherStyle === "detail" ? 280 : 80
    resizeMinHeight: root.weatherStyle === "detail" ? 150 : 80
    // Analyze the region in BOTH modes: card needs colText for its overlay, pill needs
    // it so ensureVisible() and the region-aware halo can make the shape read on any
    // wallpaper instead of dissolving into a same-tone background.
    needsColText: true
    // ── Shape name → enum mapping ──
    readonly property var _shapeMap: ({
        "pill": MaterialShape.Shape.Pill, "circle": MaterialShape.Shape.Circle,
        "oval": MaterialShape.Shape.Oval, "diamond": MaterialShape.Shape.Diamond,
        "heart": MaterialShape.Shape.Heart, "flower": MaterialShape.Shape.Flower,
        "cookie4": MaterialShape.Shape.Cookie4Sided, "sunny": MaterialShape.Shape.Sunny,
        "clover": MaterialShape.Shape.Clover4Leaf, "softBurst": MaterialShape.Shape.SoftBurst,
        "gem": MaterialShape.Shape.Gem, "puffy": MaterialShape.Shape.Puffy
    })
    readonly property var pillShapeEnum: _shapeMap[weatherShape] ?? MaterialShape.Shape.Pill

    // ── Accent colors ── primary from the shared desktop-widget identity.
    readonly property color accentPrimary: root.widgetAccent
    readonly property color accentPrimaryContainer: root.widgetSemanticContainer(root.widgetPrimaryRole)
    readonly property color accentOnPrimaryContainer: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
    readonly property color shapeFill: root.accentPrimaryContainer
    readonly property color shapeInk: root.accentOnPrimaryContainer
    // Card text follows the real backdrop: widget ink uses the configured
    // surface when present and wallpaper-region ink when the card is disabled.
    readonly property color cardInk: root.widgetInk

    // ── Style tokens ──
    readonly property real cardRadius: root.widgetCardRadius

    // Shape options for popover
    readonly property var _shapeOptions: [
        { label: Translation.tr("Pill"), value: "pill" },
        { label: Translation.tr("Circle"), value: "circle" },
        { label: Translation.tr("Oval"), value: "oval" },
        { label: Translation.tr("Diamond"), value: "diamond" },
        { label: Translation.tr("Heart"), value: "heart" },
        { label: Translation.tr("Flower"), value: "flower" },
        { label: Translation.tr("Cookie"), value: "cookie4" },
        { label: Translation.tr("Sunny"), value: "sunny" },
        { label: Translation.tr("Clover"), value: "clover" },
        { label: Translation.tr("Burst"), value: "softBurst" },
        { label: Translation.tr("Gem"), value: "gem" },
        { label: Translation.tr("Puffy"), value: "puffy" }
    ]

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Shape"), icon: "category", value: "pill" },
                        { label: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { label: Translation.tr("Detail"), icon: "dashboard", value: "detail" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.weatherStyle === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.weather.style", modelData.value)
                    }
                }
            }
            // Shape picker (visible only in pill/shape mode)
            GridLayout {
                visible: root.weatherStyle === "pill"
                columns: 4
                columnSpacing: 3
                rowSpacing: 3
                Repeater {
                    model: root._shapeOptions
                    Rectangle {
                        required property var modelData
                        property alias hovered: shapeMouseArea.containsMouse
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Appearance.rounding.small
                        color: root.weatherShape === modelData.value
                            ? ColorUtils.applyAlpha(root.accentPrimary, 0.18)
                            : "transparent"
                        border.width: root.weatherShape === modelData.value ? 1.5 : 0
                        border.color: root.accentPrimary

                        MaterialShape {
                            anchors.centerIn: parent
                            implicitSize: 22
                            shape: root._shapeMap[modelData.value] ?? MaterialShape.Shape.Pill
                            color: root.weatherShape === modelData.value
                                ? root.accentPrimary : root.accentOnPrimaryContainer
                        }
                        MouseArea {
                            id: shapeMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onClicked: Config.setNestedValue("background.widgets.weather.shape", modelData.value)
                        }
                        StyledToolTip { text: modelData.label }
                    }
                }
            }
            // Content toggles
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Temp"), icon: "thermostat", key: "showTemp", active: root.showTemp },
                        { label: Translation.tr("Icon"), icon: "cloud", key: "showIcon", active: root.showIcon },
                        { label: Translation.tr("Text"), icon: "text_fields", key: "showCondition", active: root.showCondition }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: modelData.active
                        onClicked: {
                            if (modelData.active && root.visibleContentCount <= 1) return
                            Config.setNestedValue("background.widgets.weather." + modelData.key, !modelData.active)
                        }
                    }
                }
            }
        }
    }

    // Derived colors per style mode. Shared widget dimming is applied once by
    // AbstractBackgroundWidget, so these roles keep their intended contrast.
    readonly property color weatherIconColor: weatherStyle === "pill"
        ? root.shapeInk : root.widgetAccentVisible
    readonly property color weatherConditionColor: weatherStyle === "pill"
        ? ColorUtils.applyAlpha(root.shapeInk, root.conditionOpacity)
        : ColorUtils.applyAlpha(root.cardInk, root.conditionOpacity)

    // ── Pill/shape mode ──
    // Soft contact shadow detaches the pill from the wallpaper (shell shadow
    // vocabulary, same edge as every surface). The fill itself goes through
    // ensureVisible so the generated colour stays readable on any wallpaper.
    StyledDropShadow {
        target: pillBackground
        visible: pillBackground.visible && !Appearance.zzzEverywhere
    }

    // zzz: ShapeCanvas (MaterialShape's base) has no stroke/border property, so
    // the pill previously rendered as a flat colour blob with none of zzz's
    // hairline-outline language — the one desktop widget with no zzz edge
    // treatment at all. Fake a hairline stroke with a second, slightly larger
    // shape behind the fill in the hairline colour.
    MaterialShape {
        visible: root.weatherStyle === "pill" && Appearance.zzzEverywhere
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.zzz.hairlineStrong
        implicitSize: root.shapeSize + Appearance.zzz.borderThick * 2
    }

    MaterialShape {
        visible: root.weatherStyle === "pill" && (Appearance.inirEverywhere || Appearance.angelEverywhere)
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.angel.colCardBorder
        implicitSize: root.shapeSize + 2
    }

    MaterialShape {
        id: pillBackground
        visible: root.weatherStyle === "pill"
        anchors.fill: parent
        shape: root.pillShapeEnum
        color: root.shapeFill
        implicitSize: root.shapeSize
    }

    // ── Card mode ──
    WidgetSurface {
        regionBrightness: root.regionBrightness
        id: cardBackground
        visible: (root.weatherStyle === "card" || root.weatherStyle === "detail")
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.cardInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
    }

    ColumnLayout {
        id: detailLayout
        visible: root.weatherStyle === "detail"
        anchors.fill: parent
        anchors.margins: Math.round(16 * root.scaleFactor)
        clip: true
        spacing: Math.round(6 * root.scaleFactor)

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(10 * root.scaleFactor)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: -Math.round(2 * root.scaleFactor)

                StyledText {
                    Layout.fillWidth: true
                    text: root.temperatureText
                    elide: Text.ElideRight
                    color: root.widgetInk
                    font {
                        family: Appearance.font.family.expressive
                        pixelSize: Math.round(38 * root.scaleFactor)
                        weight: Font.Bold
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Weather.data?.description ?? ""
                    elide: Text.ElideRight
                    color: ColorUtils.applyAlpha(root.widgetInk, 0.72)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: Weather.showVisibleCity
                        && root.height >= Math.round(150 * root.scaleFactor)
                    text: Weather.visibleCity
                    elide: Text.ElideRight
                    color: ColorUtils.applyAlpha(root.widgetInk, 0.5)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                }
            }

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignTop
                shape: MaterialShape.Shape.Sunny
                color: root.widgetSemanticContainer(root.widgetPrimaryRole)
                colSymbol: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                fill: 1
                iconSize: Math.round(24 * root.scaleFactor)
                padding: Math.round(10 * root.scaleFactor)
            }
        }

        Item { Layout.fillHeight: true }

        Flow {
            Layout.fillWidth: true
            visible: root.showMetrics
                && root.height >= Math.round(132 * root.scaleFactor)
            spacing: Math.round(6 * root.scaleFactor)

            Repeater {
                model: root._metricModel

                Rectangle {
                    id: metricChip
                    required property var modelData
                    required property int index
                    readonly property bool alternate: index % 2 === 0
                    readonly property string chipRole: metricChip.alternate
                        ? root.widgetSecondaryRole : root.widgetTertiaryRole
                    readonly property color chipColor: root.widgetSemanticContainer(metricChip.chipRole)
                    readonly property color chipInk: root.widgetSemanticOnContainer(metricChip.chipRole)

                    width: chipRow.implicitWidth + Math.round(16 * root.scaleFactor)
                    height: chipRow.implicitHeight + Math.round(8 * root.scaleFactor)
                    radius: height / 2
                    color: metricChip.chipColor

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Math.round(4 * root.scaleFactor)

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: metricChip.modelData.icon
                            fill: 1
                            iconSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            color: ColorUtils.applyAlpha(metricChip.chipInk, 0.75)
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: metricChip.modelData.value
                            color: metricChip.chipInk
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.weatherStyle !== "detail"

        MaterialSymbol {
            visible: root.visibleContentCount === 0
            anchors.centerIn: parent
            text: "cloud_off"
            iconSize: Math.round(40 * root.scaleFactor)
            color: root.weatherStyle === "pill" ? root.shapeInk : root.widgetInkMuted
        }

        StyledText {
            id: temperatureLabel
            visible: root.showTemp
            height: Math.max(1, Math.round(root.height * 0.42))
            font {
                pixelSize: root.tempFontSize
                family: Appearance.font.family.expressive
                weight: root.tempFontWeight
            }
            fontSizeMode: Text.Fit
            minimumPixelSize: Math.max(8, Math.round(root.tempFontSize * 0.45))
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            clip: true
            // Matches weatherIconColor so the number and icon read as one coloured
            // unit in both modes, instead of the icon being tinted and the number
            // staying flat ink like it did before.
            color: root.weatherIconColor
            text: root.temperatureText
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: root.contentInset
                rightMargin: root.contentInset
                topMargin: root.contentInset
            }
        }

        MaterialSymbol {
            id: weatherIcon
            visible: root.showIcon
            iconSize: root.weatherIconSize
            color: root.weatherIconColor
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            anchors {
                left: parent.left
                bottom: parent.bottom
                leftMargin: root.contentInset
                bottomMargin: root.contentInset
            }
        }

        // Grouped with the icon's corner (or that same corner alone, icon off) instead
        // of bottom-center: organic MaterialShape fills (puffy/flower/heart/cookie...)
        // taper thinnest at the exact edge-midpoints, so bottom-center sat outside the
        // visible fill on most shapes — same reason it read as "does nothing" with the
        // icon off. Font matches the temp number's family instead of the generic body one.
        StyledText {
            visible: root.showCondition
            font {
                pixelSize: root.conditionFontSize
                family: Appearance.font.family.expressive
            }
            color: root.weatherConditionColor
            text: Weather.data?.description ?? ""
            elide: Text.ElideRight
            width: Math.max(0, Math.min(implicitWidth,
                root.width - root.contentInset * 2
                    - (root.showIcon ? weatherIcon.width + Math.round(root.contentInset * 0.4) : 0)))
            anchors {
                left: root.showIcon ? weatherIcon.right : parent.left
                leftMargin: root.showIcon ? Math.round(root.contentInset * 0.4) : root.contentInset
                verticalCenter: root.showIcon ? weatherIcon.verticalCenter : undefined
                bottom: root.showIcon ? undefined : parent.bottom
                bottomMargin: root.showIcon ? 0 : root.contentInset
            }
        }
    }
}
