import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"
    defaultConfig: ({
        placementStrategy: "free", preset: "default", style: "pill", shape: "pill",
        size: 200, tempSize: 80, iconSize: 80,
        showTemp: true, showIcon: true, showCondition: false, showMetrics: true,
        showSunPath: true, showSunTimes: true, showLocation: true,
        padding: 20, tempFontWeight: 500, conditionOpacity: 0.7,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, useBlur: false, showBorder: true,
        backgroundOpacity: 0.16, borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1,
        x: 100, y: 200
    })

    readonly property string weatherStyle: root._readConfigKey("style") ?? "pill"
    widgetSurfaceEnabled: root.weatherStyle !== "dial"
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
    readonly property bool showSunPath: Boolean(root._readConfigKey("showSunPath") ?? true)
    readonly property bool showSunTimes: Boolean(root._readConfigKey("showSunTimes") ?? true)
    readonly property bool showLocation: Boolean(root._readConfigKey("showLocation") ?? true)

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

    implicitWidth: root.irisFaced ? root.irisFaceWidth : root.weatherStyle === "detail" ? Math.round(shapeSize * 2.2)
        : root.weatherStyle === "dial" ? Math.round(shapeSize * 1.4) : shapeSize
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.weatherStyle === "detail" ? Math.round(shapeSize * 0.95) : shapeSize
    irisFace: Component { IrisWeatherFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisOptions: [
        { key: "showLocation", raw: true, label: Translation.tr("Location"), icon: "location_on", fallback: true }
    ]
    resizableAxes: ({ uniform: "size" })
    resizeMinWidth: root.weatherStyle === "detail" ? 280
        : root.weatherStyle === "dial" ? 224 : 80
    resizeMinHeight: root.weatherStyle === "detail" ? 150
        : root.weatherStyle === "dial" ? 160 : 80
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
            spacing: 14

            WidgetQuickSection {
                title: Translation.tr("Style")
                WidgetQuickChoices {
                    maxColumns: 2
                    current: root.weatherStyle
                    model: [
                        { label: Translation.tr("Shape"), icon: "category", value: "pill" },
                        { label: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { label: Translation.tr("Detail"), icon: "dashboard", value: "detail" },
                        { label: Translation.tr("Instrument"), icon: "wb_twilight", value: "dial" }
                    ]
                    onPicked: value => root._setOutputValue("style", value)
                }
            }

            WidgetQuickSection {
                visible: root.weatherStyle === "pill"
                title: Translation.tr("Shape")
                GridLayout {
                    Layout.fillWidth: true
                    columns: 6
                    columnSpacing: 4
                    rowSpacing: 4
                    Repeater {
                        model: root._shapeOptions
                        WidgetQuickChoice {
                            id: shapeChoice
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.maximumWidth: Number.POSITIVE_INFINITY
                            implicitHeight: 40
                            selected: root.weatherShape === modelData.value
                            tooltip: modelData.label
                            onClicked: root._setOutputValue("shape", modelData.value)
                            MaterialShape {
                                anchors.centerIn: parent
                                implicitSize: 22
                                shape: root._shapeMap[shapeChoice.modelData.value] ?? MaterialShape.Shape.Pill
                                color: shapeChoice.ink
                            }
                        }
                    }
                }
            }

            WidgetQuickSection {
                title: Translation.tr("Show")
                Repeater {
                    model: [
                        { label: Translation.tr("Temperature"), icon: "thermostat", key: "showTemp" },
                        { label: Translation.tr("Icon"), icon: "cloud", key: "showIcon" },
                        { label: Translation.tr("Condition"), icon: "text_fields", key: "showCondition" }
                    ]
                    WidgetQuickToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        iconName: modelData.icon
                        label: modelData.label
                        checked: Boolean(root._readConfigKey(modelData.key) ?? (modelData.key !== "showCondition"))
                        enabled: !checked || root.visibleContentCount > 1
                        onToggled: root._setOutputValue(modelData.key, !checked)
                    }
                }
                Repeater {
                    model: root.weatherStyle === "dial" ? [
                        { label: Translation.tr("Sun path"), icon: "wb_twilight", key: "showSunPath", fallback: true },
                        { label: Translation.tr("Sunrise and sunset"), icon: "schedule", key: "showSunTimes", fallback: true },
                        { label: Translation.tr("Location"), icon: "location_on", key: "showLocation", fallback: true }
                    ] : []
                    WidgetQuickToggle {
                        required property var modelData
                        Layout.fillWidth: true
                        iconName: modelData.icon
                        label: modelData.label
                        checked: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                        enabled: modelData.key !== "showSunTimes" || root.showSunPath
                        onToggled: root._setOutputValue(modelData.key, !checked)
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
        visible: !root.irisFaced && pillBackground.visible && !Appearance.zzzEverywhere
    }

    // zzz: ShapeCanvas (MaterialShape's base) has no stroke/border property, so
    // the pill previously rendered as a flat colour blob with none of zzz's
    // hairline-outline language — the one desktop widget with no zzz edge
    // treatment at all. Fake a hairline stroke with a second, slightly larger
    // shape behind the fill in the hairline colour.
    MaterialShape {
        visible: !root.irisFaced && root.weatherStyle === "pill" && Appearance.zzzEverywhere
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.zzz.hairlineStrong
        implicitSize: root.shapeSize + Appearance.zzz.borderThick * 2
    }

    MaterialShape {
        visible: !root.irisFaced && root.weatherStyle === "pill" && (Appearance.inirEverywhere || Appearance.angelEverywhere)
        anchors.centerIn: parent
        shape: root.pillShapeEnum
        color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.angel.colCardBorder
        implicitSize: root.shapeSize + 2
    }

    MaterialShape {
        id: pillBackground
        visible: !root.irisFaced && root.weatherStyle === "pill"
        anchors.fill: parent
        shape: root.pillShapeEnum
        color: root.shapeFill
        implicitSize: root.shapeSize
    }

    // ── Card mode ──
    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        id: cardBackground
        shown: !root.irisFaced && (root.weatherStyle === "card" || root.weatherStyle === "detail")
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
        visible: !root.irisFaced && root.weatherStyle === "detail"
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
                        family: root.widgetEditorial ? root.widgetTitleFamily : Appearance.font.family.expressive
                        pixelSize: Math.round(38 * root.widgetTitleScale * root.scaleFactor)
                        weight: root.widgetEditorial ? root.widgetTitleWeight : Font.Bold
                        letterSpacing: root.widgetEditorial ? root.widgetTitleTracking : 0
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
                            font.weight: Appearance.editorialEverywhere ? Appearance.editorial.labelWeight : Font.Medium
                        }
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.irisFaced && root.weatherStyle !== "detail" && root.weatherStyle !== "dial"

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
                family: root.widgetEditorial ? root.widgetTitleFamily : Appearance.font.family.expressive
                weight: root.tempFontWeight
                letterSpacing: root.widgetEditorial ? root.widgetTitleTracking : 0
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
                family: root.widgetEditorial ? root.widgetTitleFamily : Appearance.font.family.expressive
                weight: root.widgetEditorial ? root.widgetTitleWeight : Font.Normal
                letterSpacing: root.widgetEditorial ? root.widgetTitleTracking : 0
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

    // ── Instrument: compact weather observatory ────────────────
    // The current condition owns the left side; the right side is an actual
    // daylight trajectory when sunrise/sunset data exists. The arc is local to
    // that sky stage instead of becoming an unexplained rule under the widget.
    Item {
        id: instrumentArea
        anchors.fill: parent
        opacity: root.weatherStyle === "dial" ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.weatherStyle === "dial"
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        readonly property real side: Math.min(width, height)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(12 * root.scaleFactor)
            spacing: Math.round(12 * root.scaleFactor)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(3 * root.scaleFactor)

                InstrumentLabel {
                    Layout.fillWidth: true
                    text: root.showLocation && Weather.showVisibleCity && String(Weather.visibleCity || "").length > 0
                        ? Translation.tr("Atmosphere / %1").arg(Weather.visibleCity) : Translation.tr("Atmosphere / Local")
                    color: root.widgetAccentVisible
                    scaleFactor: root.scaleFactor
                    strong: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(6 * root.scaleFactor)

                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        visible: root.showTemp
                        text: root.temperatureText
                        color: root.widgetInk
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(instrumentArea.side * 0.31)
                        font.weight: Font.Bold
                        font.features: ({ "tnum": 1 })
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 16
                    }

                    MaterialSymbol {
                        visible: root.showIcon
                        text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                        iconSize: Math.round(instrumentArea.side * 0.18)
                        color: root.widgetAccentVisible
                    }
                }

                InstrumentLabel {
                    Layout.fillWidth: true
                    visible: root.showCondition && text.length > 0
                    text: Weather.data?.description ?? ""
                    color: root.widgetInkMuted
                    scaleFactor: root.scaleFactor
                    size: 10
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Math.round(4 * root.scaleFactor)
                    visible: instrumentArea.side >= Math.round(140 * root.scaleFactor)
                    spacing: Math.round(12 * root.scaleFactor)
                    Repeater {
                        model: [
                            { label: Translation.tr("Feels"), value: String(Weather.data?.tempFeelsLike ?? "").replace(/[CF]$/, "") },
                            { label: Translation.tr("Humidity"), value: String(Weather.data?.humidity ?? "") },
                            { label: Translation.tr("Wind"), value: String(Weather.data?.wind ?? "").split(" ")[0] + " " + String(Weather.data?.windDir ?? "") }
                        ]
                        InstrumentField {
                            required property var modelData
                            Layout.alignment: Qt.AlignTop
                            scaleFactor: root.scaleFactor
                            label: modelData.label
                            value: modelData.value
                            ink: root.widgetInk
                            muted: root.widgetInkMuted
                            family: root.widgetNumbersFamily
                            valueSize: 12
                        }
                    }
                }
            }

            Item {
                id: skyStage
                Layout.preferredWidth: visible
                    ? Math.max(Math.round(102 * root.scaleFactor), Math.round(instrumentArea.side * 0.52)) : 0
                Layout.fillHeight: true
                visible: root.showSunPath
                    && Boolean(Weather.data?.sunrise) && Boolean(Weather.data?.sunset)
                readonly property real rx: Math.max(1, width * 0.43)
                readonly property real ry: Math.max(1, height * 0.28)
                readonly property real centerX: width / 2
                readonly property real centerY: height * 0.62

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: ColorUtils.applyAlpha(root.widgetInk, 0.26)
                        strokeWidth: Math.max(1, Math.round(1.5 * root.scaleFactor))
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: skyStage.centerX
                            centerY: skyStage.centerY
                            radiusX: skyStage.rx
                            radiusY: skyStage.ry
                            startAngle: 180
                            sweepAngle: 180
                        }
                    }
                }

                MaterialSymbol {
                    readonly property real markerSize: Math.round(18 * root.scaleFactor)
                    width: markerSize
                    height: markerSize
                    x: skyStage.centerX - skyStage.rx * Math.cos(Math.PI * Weather.sunProgress) - width / 2
                    y: skyStage.centerY - skyStage.ry * Math.sin(Math.PI * Weather.sunProgress) - height / 2
                    text: "light_mode"
                    iconSize: markerSize
                    color: root.widgetAccentVisible
                    visible: Weather.sunState === "day"
                }

                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Math.round(skyStage.ry * 0.55)
                    visible: Weather.sunState !== "day"
                    text: "bedtime"
                    iconSize: Math.round(20 * root.scaleFactor)
                    color: root.widgetAccentVisible
                    opacity: 0.84
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: root.showSunTimes
                    spacing: Math.round(8 * root.scaleFactor)

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            text: root.widgetCase(Translation.tr("Rise"))
                            color: root.widgetInkMuted
                            font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                            font.weight: Font.DemiBold
                            font.letterSpacing: root.widgetIris ? 0 : Math.round(1.1 * root.scaleFactor)
                        }
                        StyledText {
                            text: Weather.data?.sunrise ?? ""
                            color: root.widgetInk
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.round(10 * root.scaleFactor)
                            font.weight: Font.DemiBold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: root.widgetCase(Translation.tr("Set"))
                            color: root.widgetInkMuted
                            font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                            font.weight: Font.DemiBold
                            font.letterSpacing: root.widgetIris ? 0 : Math.round(1.1 * root.scaleFactor)
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Weather.data?.sunset ?? ""
                            color: root.widgetInk
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.round(10 * root.scaleFactor)
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }
}
