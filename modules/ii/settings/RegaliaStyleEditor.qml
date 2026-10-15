pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 14

    function applyGlassPreset(blur, tintTransparency, materialStrength, saturation): void {
        Config.setNestedValues({
            "appearance.regalia.glass": true,
            "appearance.regalia.glassBlur": blur,
            "appearance.regalia.glassTintTransparency": tintTransparency,
            "appearance.regalia.glassSurfaceOpacity": materialStrength,
            "appearance.regalia.glassSaturation": saturation
        })
    }

    component SliderRow: ColumnLayout {
        id: sliderRow
        Layout.fillWidth: true
        spacing: 5

        required property string label
        required property string valueText
        property string description: ""
        required property real from
        required property real to
        required property real stepSize
        required property real value
        required property string configPath

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    text: sliderRow.label
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.regalia.onColor
                }

                StyledText {
                    visible: sliderRow.description.length > 0
                    text: sliderRow.description
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.regalia.onMuted
                    opacity: 0.78
                }
            }

            StyledText {
                Layout.preferredWidth: 58
                text: sliderRow.valueText
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.font.family.monospace
                color: Appearance.regalia.hardwarePrimary
            }
        }

        StyledSlider {
            id: slider
            Layout.fillWidth: true
            from: sliderRow.from
            to: sliderRow.to
            stepSize: sliderRow.stepSize
            value: sliderRow.value
            configuration: StyledSlider.Configuration.S
            onMoved: Config.setNestedValue(sliderRow.configPath, Math.round(value * 100) / 100)
        }
    }

    RegaliaPlate {
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        fillColor: Appearance.regalia.barSurfaceFloating
        radius: Appearance.regalia.roundLarge
        inset: Appearance.regalia.surfaceInset
        deepFrame: true
        glassEnabled: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            RegaliaControlFace {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.alignment: Qt.AlignVCenter
                fillColor: Appearance.regalia.primaryPlate
                radius: Appearance.regalia.roundNormal
                selected: true

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Appearance.regalia.glass ? "blur_on" : "blur_off"
                    iconSize: 21
                    color: Appearance.regalia.primaryPlateInk
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                StyledText {
                    text: Translation.tr("Regalia glass preview")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.regalia.onColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Appearance.regalia.glass
                        ? Translation.tr("Blur %1% · Clear %2% · Material %3% · Color %4%")
                            .arg(Math.round(Appearance.regalia.glassBlur * 100))
                            .arg(Math.round(Appearance.regalia.glassTintTransparency * 100))
                            .arg(Math.round(Appearance.regalia.glassSurfaceOpacity * 100))
                            .arg(Math.round(Appearance.regalia.glassSaturation * 100))
                        : Translation.tr("Solid Regalia surface")
                    wrapMode: Text.WordWrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: Appearance.regalia.onMuted
                }
            }
        }
    }

    ContentSubsection {
        title: Translation.tr("Glass")

        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Wallpaper glass")
            checked: Config.options?.appearance?.regalia?.glass ?? true
            onCheckedChanged: Config.setNestedValue("appearance.regalia.glass", checked)
            StyledToolTip {
                text: Translation.tr("Use the wallpaper as a blurred backdrop for large Regalia surfaces. Internal controls remain opaque.")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { label: qsTr("Balanced"), icon: "tune", blur: 0.72, tint: 0.52, material: 0.60, saturation: 0.12 },
                    { label: qsTr("Frosted"), icon: "ac_unit", blur: 0.92, tint: 0.40, material: 0.76, saturation: 0.05 },
                    { label: qsTr("Clear"), icon: "visibility", blur: 0.42, tint: 0.70, material: 0.34, saturation: 0.20 },
                    { label: qsTr("Smoked"), icon: "dark_mode", blur: 0.78, tint: 0.48, material: 0.72, saturation: 0.00 }
                ]

                RippleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 42
                    buttonRadius: Appearance.regalia.roundSmall
                    colBackground: Appearance.regalia.controlPlate
                    colBackgroundHover: Appearance.regalia.controlPlateHover
                    onClicked: root.applyGlassPreset(modelData.blur, modelData.tint, modelData.material, modelData.saturation)

                    contentItem: RowLayout {
                        spacing: 5
                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 15
                            color: Appearance.regalia.onMuted
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.label
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.regalia.onColor
                        }
                    }
                }
            }
        }

        SliderRow {
            label: Translation.tr("Blur strength")
            description: Translation.tr("How softly the wallpaper is diffused behind the surface.")
            valueText: Math.round(value * 100) + "%"
            from: 0.15
            to: 1.0
            stepSize: 0.01
            value: Config.options?.appearance?.regalia?.glassBlur ?? 0.72
            configPath: "appearance.regalia.glassBlur"
        }

        SliderRow {
            label: Translation.tr("Wallpaper visibility")
            description: Translation.tr("Higher values reveal more of the blurred wallpaper through the Regalia tint.")
            valueText: Math.round(value * 100) + "%"
            from: 0.20
            to: 0.80
            stepSize: 0.01
            value: Config.options?.appearance?.regalia?.glassTintTransparency ?? 0.52
            configPath: "appearance.regalia.glassTintTransparency"
        }

        SliderRow {
            label: Translation.tr("Material strength")
            description: Translation.tr("Keeps the Regalia field and edge weight over glass without making it fully opaque.")
            valueText: Math.round(value * 100) + "%"
            from: 0.0
            to: 1.0
            stepSize: 0.01
            value: Config.options?.appearance?.regalia?.glassSurfaceOpacity ?? 0.60
            configPath: "appearance.regalia.glassSurfaceOpacity"
        }

        SliderRow {
            label: Translation.tr("Backdrop color")
            description: Translation.tr("Preserves or mutes wallpaper color inside the blur.")
            valueText: Math.round(value * 100) + "%"
            from: 0.0
            to: 0.60
            stepSize: 0.01
            value: Config.options?.appearance?.regalia?.glassSaturation ?? 0.12
            configPath: "appearance.regalia.glassSaturation"
        }
    }

    ContentSubsection {
        title: Translation.tr("Geometry")

        SliderRow {
            label: Translation.tr("Rounding")
            description: Translation.tr("Scales Regalia panel and control radii together.")
            valueText: value.toFixed(2) + "×"
            from: 0.80
            to: 1.20
            stepSize: 0.05
            value: Config.options?.appearance?.regalia?.radiusScale ?? 1.0
            configPath: "appearance.regalia.radiusScale"
        }
    }

    RippleButton {
        Layout.alignment: Qt.AlignRight
        implicitWidth: resetRow.implicitWidth + 22
        implicitHeight: 34
        buttonRadius: Appearance.regalia.roundSmall
        colBackground: Appearance.regalia.controlPlate
        colBackgroundHover: Appearance.regalia.controlPlateHover
        onClicked: Config.setNestedValues({
            "appearance.regalia.glass": true,
            "appearance.regalia.glassBlur": 0.72,
            "appearance.regalia.glassTintTransparency": 0.52,
            "appearance.regalia.glassSurfaceOpacity": 0.60,
            "appearance.regalia.glassSaturation": 0.12,
            "appearance.regalia.radiusScale": 1.0
        })

        contentItem: RowLayout {
            id: resetRow
            spacing: 6
            MaterialSymbol {
                text: "restart_alt"
                iconSize: 16
                color: Appearance.regalia.onMuted
            }
            StyledText {
                text: Translation.tr("Reset Regalia defaults")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.regalia.onColor
            }
        }
    }
}
