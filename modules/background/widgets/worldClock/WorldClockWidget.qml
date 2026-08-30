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

    configEntryName: "worldClock"
    defaultConfig: ({
            placementStrategy: "free",
            contentWidth: 300,
            contentHeight: 210,
            widgetScale: 100,
            widgetOpacity: 100,
            colorMode: "auto",
            dim: 0,
            showBackground: true,
            showBorder: true,
            backgroundOpacity: 0.16,
            borderWidth: 1,
            borderOpacity: 0.2,
            cornerRadius: -1,
            useBlur: false,
            timezones: ["Australia/Sydney", "Asia/Tokyo", "Europe/London", "America/New_York"],
            x: 80,
            y: 200
        })

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 300) * scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 210) * scaleFactor)
    resizableAxes: ({
            width: "contentWidth",
            height: "contentHeight"
        })
    resizeMinWidth: 240
    resizeMinHeight: 170
    needsColText: true

    readonly property color surfaceInk: root.widgetInk
    readonly property string localCity: Weather.visibleCity
    readonly property var cities: WorldClock.entries

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6

            Repeater {
                model: 4
                delegate: RowLayout {
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("City %1").arg(index + 1)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: WorldClock.comboModel
                        textRole: "label"
                        currentIndex: Math.max(0, WorldClock.comboModel.findIndex(o => o.tz === WorldClock.timezones[index]))
                        onActivated: idx => WorldClock.setTimezone(index, WorldClock.comboModel[idx].tz)
                    }
                }
            }
        }
    }

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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(8 * root.scaleFactor)

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            visible: Weather.showVisibleCity
            implicitWidth: localChip.implicitWidth + Math.round(18 * root.scaleFactor)
            implicitHeight: localChip.implicitHeight + Math.round(8 * root.scaleFactor)
            radius: height / 2
            color: root.widgetSemanticContainer(root.widgetPrimaryRole)

            RowLayout {
                id: localChip
                anchors.centerIn: parent
                spacing: Math.round(5 * root.scaleFactor)

                MaterialSymbol {
                    text: "place"
                    fill: 1
                    iconSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                }

                StyledText {
                    text: root.localCity || Translation.tr("Local")
                    elide: Text.ElideRight
                    color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: Font.Medium
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: DateTime.time || "--:--"
            color: root.surfaceInk
            elide: Text.ElideRight
            font {
                family: Appearance.font.family.numbers
                pixelSize: Math.round(Appearance.font.pixelSize.huge * root.scaleFactor)
                weight: Font.DemiBold
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Qt.locale().toString(WorldClock.now, "dddd, MMMM d yyyy")
            color: ColorUtils.applyAlpha(root.surfaceInk, 0.6)
            elide: Text.ElideRight
            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: Math.round(6 * root.scaleFactor)
            rowSpacing: Math.round(6 * root.scaleFactor)

            Repeater {
                model: root.cities

                delegate: Rectangle {
                    id: cityCell
                    required property var modelData
                    required property int index
                    readonly property bool alternate: (index % 2) === (Math.floor(index / 2) % 2)
                    readonly property string cellRole: cityCell.alternate
                        ? root.widgetSecondaryRole : root.widgetTertiaryRole
                    readonly property color cellColor: root.widgetSemanticContainer(cityCell.cellRole)
                    readonly property color cellInk: root.widgetSemanticOnContainer(cityCell.cellRole)
                    readonly property color cellAccent: root.widgetSemanticColor(cityCell.cellRole)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Math.round(44 * root.scaleFactor)
                    radius: root.widgetCardRadius * 0.72
                    color: cityCell.cellColor

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * root.scaleFactor)
                        spacing: Math.round(6 * root.scaleFactor)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -Math.round(2 * root.scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(4 * root.scaleFactor)

                                StyledText {
                                    Layout.fillWidth: true
                                    text: cityCell.modelData.name
                                    elide: Text.ElideRight
                                    color: ColorUtils.applyAlpha(cityCell.cellInk, 0.7)
                                    font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                                }

                                StyledText {
                                    text: cityCell.modelData.offset
                                    color: ColorUtils.applyAlpha(cityCell.cellInk, 0.5)
                                    font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: cityCell.modelData.time
                                elide: Text.ElideRight
                                color: cityCell.cellInk
                                font {
                                    family: Appearance.font.family.numbers
                                    pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                                    weight: Font.Bold
                                }
                            }
                        }

                        MaterialShape {
                            Layout.alignment: Qt.AlignVCenter
                            visible: cityCell.height >= Math.round(46 * root.scaleFactor)
                            implicitSize: Math.round(24 * root.scaleFactor)
                            shape: cityCell.modelData.isDay
                                ? MaterialShape.Shape.Sunny
                                : MaterialShape.Shape.ClamShell
                            color: ColorUtils.applyAlpha(cityCell.cellAccent, 0.9)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: cityCell.modelData.isDay ? "light_mode" : "dark_mode"
                                fill: 1
                                iconSize: Math.round(13 * root.scaleFactor)
                                color: root.widgetSemanticOnColor(cityCell.cellRole)
                            }
                        }
                    }
                }
            }
        }
    }
}
