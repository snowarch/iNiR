import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
AbstractBackgroundWidget {
    id: root

    configEntryName: "weather"

    readonly property string weatherStyle: root._readConfigKey("style") ?? "pill"
    // Material's Medium and Large add the hours (and the days) to what the chosen style shows; the dial keeps its own.
    readonly property bool forecastFace: root.sizeClass !== "small" && root.weatherStyle !== "dial"
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

    // the dial (iNstrument) lays itself out per size instead of shrinking its medium drawing into small
    fitted: !root.forecastFace && root.weatherStyle !== "dial"
    fitPadding: 0
    drawnWidth: root.forecastFace ? 0 : root.weatherStyle === "detail" ? Math.round(shapeSize * 2.2)
        : root.weatherStyle === "dial" ? Math.round(shapeSize * 1.4) : shapeSize
    drawnHeight: root.forecastFace ? 0 : root.weatherStyle === "detail" ? Math.round(shapeSize * 0.95) : shapeSize
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
    // a loaded item is never the pill's sibling, so the Loader takes the pill's place and the shadow fills it
    Loader {
        anchors.fill: pillBackground
        active: !root.familyFaced
        sourceComponent: StyledDropShadow {
            anchors.fill: undefined
            target: pillBackground
            visible: !root.familyFaced && pillBackground.visible && root.look.softDepth
        }
    }

    // A shape has no stroke: the edge a look asks for is a slightly larger one behind the fill.
    Loader {
        anchors.fill: parent
        active: !root.familyFaced && !root.forecastFace && root.weatherStyle === "pill" && root.look.pillRingWidth > 0
        sourceComponent: Item {
            MaterialShape {
                anchors.centerIn: parent
                shape: root.pillShapeEnum
                color: root.look.pillRing
                implicitSize: root.shapeSize + root.look.pillRingWidth * 2
            }
        }
    }

    MaterialShape {
        id: pillBackground
        visible: !root.familyFaced && !root.forecastFace && root.weatherStyle === "pill"
        anchors.centerIn: parent
        width: root.fits ? root.drawnWidth : parent.width
        height: root.fits ? root.drawnHeight : parent.height
        shape: root.pillShapeEnum
        color: root.shapeFill
        implicitSize: root.shapeSize
    }

    // ── Card mode ──
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            WidgetSurface {
                widget: root
                id: cardBackground
                shown: !root.familyFaced && (root.forecastFace || root.weatherStyle === "card" || root.weatherStyle === "detail")
                    && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
                anchors.centerIn: parent
                width: root.fits ? root.drawnWidth : parent.width
                height: root.fits ? root.drawnHeight : parent.height
                surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.cardRadius
                surfaceColor: root.cardInk
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            ColumnLayout {
                id: detailLayout
                visible: !root.familyFaced && !root.forecastFace && root.weatherStyle === "detail"
                anchors.centerIn: parent
                width: (root.fits ? root.drawnWidth : parent.width) - Math.round(32 * root.scaleFactor)
                height: (root.fits ? root.drawnHeight : parent.height) - Math.round(32 * root.scaleFactor)
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
                            color: root.widgetInkMuted
                            font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: Weather.showVisibleCity
                                && root.height >= Math.round(150 * root.scaleFactor)
                            text: Weather.visibleCity
                            elide: Text.ElideRight
                            color: root.widgetInkSubtle
                            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                        }
                    }

                    MaterialShapeWrappedMaterialSymbol {
                        Layout.alignment: Qt.AlignTop
                        shape: MaterialShape.Shape.Sunny
                        color: root.widgetPrimaryMark.fill
                        colSymbol: root.widgetPrimaryMark.ink
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
                                    font.weight: root.look.labelWeight(root)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            Item {
                anchors.centerIn: parent
                width: root.fits ? root.drawnWidth : parent.width
                height: root.fits ? root.drawnHeight : parent.height
                visible: !root.familyFaced && !root.forecastFace && root.weatherStyle !== "detail" && root.weatherStyle !== "dial"

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
                    height: Math.max(1, Math.round(parent.height * 0.42))
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
                        parent.width - root.contentInset * 2
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
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced && root.forecastFace
        visible: active
        sourceComponent: WeatherForecast {
            widget: root
            large: root.isLarge
        }
    }

    // ── Instrument: compact weather observatory ────────────────
    // The current condition owns the left side; the right side is an actual
    // daylight trajectory when sunrise/sunset data exists. The arc is local to
    // that sky stage instead of becoming an unexplained rule under the widget.
    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            Item {
                id: instrumentArea
                anchors.centerIn: parent
                width: root.fits ? root.drawnWidth : parent.width
                height: root.fits ? root.drawnHeight : parent.height
                opacity: root.weatherStyle === "dial" ? 1 : 0
                visible: !root.familyFaced && opacity > 0
                enabled: root.weatherStyle === "dial"
                Behavior on opacity {
                    enabled: root.animationsActive
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                }

                // large keeps medium's stage on top and lists the days under it
                readonly property real stageHeight: root.isLarge ? Math.round(176 * root.scaleFactor) : height
                readonly property real side: Math.min(width, instrumentArea.stageHeight)

                RowLayout {
                    id: instrumentStage
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Math.round(12 * root.scaleFactor)
                    height: instrumentArea.stageHeight - Math.round(24 * root.scaleFactor)
                    spacing: Math.round(12 * root.scaleFactor)

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Math.round(3 * root.scaleFactor)

                        InstrumentLabel {
                            Layout.fillWidth: true
                            // the town alone: its province cut the label short
                            text: Weather.showVisibleCity && String(Weather.visibleCity || "").length > 0
                                ? (root.isSmall ? String(Weather.visibleCity).split(",")[0].trim()
                                    : Translation.tr("Atmosphere / %1").arg(String(Weather.visibleCity).split(",")[0].trim()))
                                : Translation.tr("Atmosphere / Local")
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
                                ].slice(0, root.isSmall ? 2 : 3)
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
                        // never narrower than its rise and set: they ran past the plate's edge
                        Layout.preferredWidth: visible
                            ? Math.max(Math.round(102 * root.scaleFactor), Math.round(instrumentArea.side * 0.52),
                                sunTimes.visible ? sunTimes.implicitWidth : 0) : 0
                        Layout.fillHeight: true
                        visible: root.showSunPath && !root.isSmall
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
                            id: sunTimes
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
                                    font.letterSpacing: root.familyDesign ? 0 : Math.round(1.1 * root.scaleFactor)
                                }
                                StyledText {
                                    text: Weather.data?.sunrise ?? ""
                                    color: root.widgetInk
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.round(10 * root.scaleFactor)
                                    font.weight: Font.DemiBold
                                }
                            }

                            // the columns can't grow past their texts: this pushes sunset to the edge
                            Item { Layout.fillWidth: true }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.alignment: Qt.AlignRight
                                    text: root.widgetCase(Translation.tr("Set"))
                                    color: root.widgetInkMuted
                                    font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: root.familyDesign ? 0 : Math.round(1.1 * root.scaleFactor)
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

                // Large: the days as a log, a rule between each, the range in the figure face.
                ColumnLayout {
                    visible: root.isLarge
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: instrumentStage.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Math.round(12 * root.scaleFactor)
                    anchors.rightMargin: Math.round(12 * root.scaleFactor)
                    anchors.topMargin: Math.round(6 * root.scaleFactor)
                    anchors.bottomMargin: Math.round(12 * root.scaleFactor)
                    spacing: 0
                    Repeater {
                        model: root.isLarge ? Array.from(Weather.data?.forecast ?? []).slice(0, 5) : []
                        Item {
                            id: logDay
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: Math.max(1, Math.round(root.scaleFactor))
                                color: ColorUtils.applyAlpha(root.widgetInk, 0.14)
                            }
                            RowLayout {
                                anchors.fill: parent
                                spacing: Math.round(10 * root.scaleFactor)
                                InstrumentLabel {
                                    Layout.preferredWidth: Math.round(64 * root.scaleFactor)
                                    text: logDay.index === 0 ? Translation.tr("Today") : String(logDay.modelData.dayName ?? "")
                                    color: logDay.index === 0 ? root.widgetAccentVisible : root.widgetInkMuted
                                    scaleFactor: root.scaleFactor
                                    strong: logDay.index === 0
                                }
                                MaterialSymbol {
                                    text: Icons.getWeatherIcon(logDay.modelData.code, false) ?? "cloud"
                                    iconSize: Math.round(16 * root.scaleFactor)
                                    color: root.widgetAccentVisible
                                }
                                Item { Layout.fillWidth: true }
                                StyledText {
                                    text: String(logDay.modelData.lo ?? "").replace(/[CF]$/, "")
                                    color: root.widgetInkMuted
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.round(13 * root.scaleFactor)
                                    font.features: ({ "tnum": 1 })
                                }
                                StyledText {
                                    Layout.preferredWidth: Math.round(38 * root.scaleFactor)
                                    horizontalAlignment: Text.AlignRight
                                    text: String(logDay.modelData.hi ?? "").replace(/[CF]$/, "")
                                    color: root.widgetInk
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.round(13 * root.scaleFactor)
                                    font.weight: Font.Bold
                                    font.features: ({ "tnum": 1 })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
