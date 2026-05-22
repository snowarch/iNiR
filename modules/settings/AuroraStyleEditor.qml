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
            color: Appearance.colors.colPrimary
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

    // ─── Section keys for presets ───
    readonly property var _sectionKeys: ["transparency"]

    // ─── Preset definitions ───
    readonly property var _presets: ({
        "default": {
            "transparency": { "overlay": 0.30, "subSurface": 0.42, "popup": 0.32, "tooltip": 0.28, "layer": 0.32 }
        },
        "frosted": {
            "transparency": { "overlay": 0.25, "subSurface": 0.35, "popup": 0.30, "tooltip": 0.25, "layer": 0.28 }
        },
        "clear": {
            "transparency": { "overlay": 0.60, "subSurface": 0.72, "popup": 0.58, "tooltip": 0.45, "layer": 0.60 }
        },
        "subtle": {
            "transparency": { "overlay": 0.18, "subSurface": 0.28, "popup": 0.22, "tooltip": 0.18, "layer": 0.20 }
        }
    })

    function _applyPreset(preset): void {
        for (const section of root._sectionKeys) {
            if (preset[section] !== undefined && typeof preset[section] === "object") {
                const sectionData = preset[section]
                for (const key of Object.keys(sectionData)) {
                    Config.setNestedValue("appearance.aurora." + section + "." + key, sectionData[key])
                }
            }
        }
    }

    function _snapshotCurrent() {
        const current = Config.options?.appearance?.aurora ?? {}
        const clean = {}
        for (const key of root._sectionKeys) {
            if (current[key] !== undefined) {
                clean[key] = JSON.parse(JSON.stringify(current[key]))
            }
        }
        return clean
    }

    function _saveCustom(): void {
        Config.setNestedValue("appearance.aurora.customPreset", JSON.stringify(root._snapshotCurrent()))
    }

    function _loadCustom(): void {
        const raw = Config.options?.appearance?.aurora?.customPreset ?? ""
        if (raw === "") return
        try { root._applyPreset(JSON.parse(raw)) }
        catch(e) { console.warn("[AuroraEditor] Failed to load custom preset:", e) }
    }

    // ═══════════════════════════════════════════════════════
    // LIVE PREVIEW
    // ═══════════════════════════════════════════════════════
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 80
        radius: Appearance.rounding.normal
        color: Appearance.aurora.colOverlay
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            // Mini preview: nested glass layers
            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 48; height: 48
                    radius: Appearance.rounding.small
                    color: Appearance.aurora.colSubSurface
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 28
                        radius: Appearance.rounding.small
                        color: Appearance.aurora.colElevatedSurface
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "blur_on"
                            iconSize: 16
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: Translation.tr("Aurora Glass — Live Preview")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Panel %1% · Cards %2% · Popup %3% · Layer %4%")
                        .arg(Math.round(Appearance.aurora.overlayTransparentize * 100))
                        .arg(Math.round(Appearance.aurora.subSurfaceTransparentize * 100))
                        .arg(Math.round(Appearance.aurora.popupTransparentize * 100))
                        .arg(Math.round(Appearance.aurora.layerTransparentize * 100))
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
                    { key: "default", icon: "blur_on", label: qsTr("Default"), desc: qsTr("Balanced glass") },
                    { key: "frosted", icon: "ac_unit", label: qsTr("Frosted"), desc: qsTr("Opaque, muted") },
                    { key: "clear", icon: "visibility", label: qsTr("Clear"), desc: qsTr("Very transparent") },
                    { key: "subtle", icon: "blur_off", label: qsTr("Subtle"), desc: qsTr("Nearly solid") }
                ]

                delegate: RippleButton {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.aurora.colSubSurface
                    colBackgroundHover: Appearance.aurora.colSubSurfaceHover
                    onClicked: root._applyPreset(root._presets[modelData.key])

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2

                        MaterialSymbol {
                            text: modelData.icon
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
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
    // QUICK SAVE / LOAD / RESET
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Quick Actions")

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.aurora.colSubSurface
                colBackgroundHover: Appearance.aurora.colSubSurfaceHover
                onClicked: root._saveCustom()

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "save"; iconSize: 15; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Quick Save"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                }
            }
            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.aurora.colSubSurface
                colBackgroundHover: Appearance.aurora.colSubSurfaceHover
                enabled: (Config.options?.appearance?.aurora?.customPreset ?? "") !== ""
                opacity: enabled ? 1.0 : 0.4
                onClicked: root._loadCustom()

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "restore"; iconSize: 15; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Quick Load"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                }
            }
            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.aurora.colSubSurface
                colBackgroundHover: Appearance.aurora.colSubSurfaceHover
                onClicked: root._applyPreset(root._presets["default"])

                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 5
                    MaterialSymbol { text: "restart_alt"; iconSize: 15; color: Appearance.colors.colOnLayer1 }
                    StyledText { text: Translation.tr("Reset"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════
    // GLASS TRANSPARENCY
    // ═══════════════════════════════════════════════════════
    ContentSubsection {
        title: Translation.tr("Glass Transparency")

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Controls how see-through each UI layer is. Higher values make surfaces more transparent, revealing more of the wallpaper beneath.")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
            opacity: 0.7
        }

        SliderRow {
            label: Translation.tr("Panels")
            icon: "dock_to_bottom"
            description: Translation.tr("Bar, sidebar, main panel backgrounds")
            configValue: Appearance.aurora.overlayTransparentize
            configPath: "appearance.aurora.transparency.overlay"
        }

        SliderRow {
            label: Translation.tr("Cards")
            icon: "crop_square"
            description: Translation.tr("Settings cards, groups, internal containers")
            configValue: Appearance.aurora.subSurfaceTransparentize
            configPath: "appearance.aurora.transparency.subSurface"
        }

        SliderRow {
            label: Translation.tr("Popups")
            icon: "open_in_new"
            description: Translation.tr("Context menus, dropdown overlays")
            configValue: Appearance.aurora.popupTransparentize
            configPath: "appearance.aurora.transparency.popup"
        }

        SliderRow {
            label: Translation.tr("Tooltips")
            icon: "chat_bubble_outline"
            description: Translation.tr("Hover tooltips — lower values improve readability")
            configValue: Appearance.aurora.tooltipTransparentize
            configPath: "appearance.aurora.transparency.tooltip"
        }

        SliderRow {
            label: Translation.tr("Surface layers")
            icon: "layers"
            description: Translation.tr("General layer glass — affects all surface backgrounds (Layer 1/2/3)")
            configValue: Appearance.aurora.layerTransparentize
            configPath: "appearance.aurora.transparency.layer"
        }
    }
}
