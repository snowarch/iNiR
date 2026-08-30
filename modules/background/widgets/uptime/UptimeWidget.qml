pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "uptime"
    defaultConfig: ({
        placementStrategy: "free", contentWidth: 250, contentHeight: 96,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        showBackground: true, showBorder: true, backgroundOpacity: 0.16,
        borderWidth: 1, borderOpacity: 0.2, cornerRadius: -1, useBlur: false,
        x: 80, y: 80
    })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 250) * scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 96) * scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
    resizeMinWidth: 190
    resizeMinHeight: 76
    needsColText: true
    readonly property color surfaceInk: root.widgetInk

    WidgetSurface {
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.surfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent3
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(12 * root.scaleFactor)

        MaterialSymbol {
            text: "avg_pace"
            iconSize: Math.round(38 * root.scaleFactor)
            color: root.widgetAccent3Visible
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(2 * root.scaleFactor)

            StyledText {
                text: Translation.tr("System uptime")
                color: ColorUtils.applyAlpha(root.surfaceInk, 0.66)
                font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
            }
            StyledText {
                Layout.fillWidth: true
                text: DateTime.uptime || "--"
                color: root.surfaceInk
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
                font {
                    family: Appearance.font.family.numbers
                    pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                    weight: Font.DemiBold
                }
            }
        }
    }
}
