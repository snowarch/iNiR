pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services as Services
import qs.services.deferred

Item {
    id: root

    readonly property bool compact: width < 470
    readonly property bool editorial: Appearance.editorialEverywhere
    readonly property var presetNames: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    readonly property color accentColor: Appearance.regaliaEverywhere ? Appearance.regalia.hardwarePrimary
        : Appearance.zzzEverywhere ? Appearance.zzz.accent
        : editorial ? Appearance.editorial.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color textColor: Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.zzzEverywhere ? Appearance.zzz.ink
        : editorial ? Appearance.editorial.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer1
    readonly property color subtextColor: Appearance.regaliaEverywhere ? Appearance.regalia.onMuted
        : Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : editorial ? Appearance.editorial.muted
        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color cardInk: Appearance.regaliaEverywhere ? Appearance.regalia.onColor
        : Appearance.zzzEverywhere ? Appearance.zzz.ink
        : editorial ? Appearance.editorial.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer2

    implicitWidth: 568
    implicitHeight: contentLayout.implicitHeight + 36

    Component.onCompleted: {
        EasyEffects.fetchAvailability()
        EasyEffects.fetchActiveState()
        EasyEffects.ensureEqualizer()
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.visible
            && EasyEffects.available
            && EasyEffects.active
            && !EasyEffects.equalizerReady
            && !EasyEffects.equalizerLoading
        onTriggered: EasyEffects.ensureEqualizer()
    }

    Timer {
        id: activeRefreshTimer
        interval: 1100
        repeat: false
        onTriggered: EasyEffects.refreshEqualizer()
    }

    function statusTitle(): string {
        if (!EasyEffects.available) return Services.Translation.tr("EasyEffects is not installed")
        if (!EasyEffects.active) return Services.Translation.tr("EasyEffects is not running")
        if (!EasyEffects.equalizerServerAvailable) return Services.Translation.tr("EasyEffects local control is unavailable")
        if (!EasyEffects.equalizerSupported) return Services.Translation.tr("Equalizer control is unavailable")
        if (EasyEffects.equalizerError === "lsp_plugins_missing") return Services.Translation.tr("Linux Studio Plugins are missing")
        if (EasyEffects.equalizerError === "plugin_not_found") return Services.Translation.tr("Add an Equalizer to EasyEffects output")
        if (!EasyEffects.equalizerPluginAvailable) return Services.Translation.tr("No controllable Equalizer is active")
        if (EasyEffects.equalizerBandCount !== 10) return Services.Translation.tr("Use the iNiR 10-band layout")
        return Services.Translation.tr("Equalizer unavailable")
    }

    function statusBody(): string {
        if (!EasyEffects.available)
            return Services.Translation.tr("Install EasyEffects to control the output equalizer from iNiR.")
        if (!EasyEffects.active)
            return Services.Translation.tr("Start EasyEffects. iNiR will reconnect automatically when its local server becomes available.")
        if (!EasyEffects.equalizerServerAvailable)
            return Services.Translation.tr("EasyEffects is running, but its local control socket is unavailable. Per-band control requires EasyEffects 8.2.8 or newer and the EasyEffects local server.")
        if (!EasyEffects.equalizerSupported)
            return Services.Translation.tr("This EasyEffects build does not expose per-band equalizer control through its local server.")
        if (EasyEffects.equalizerError === "lsp_plugins_missing")
            return Services.Translation.tr("Install the Linux Studio Plugins LV2 package for your distribution, then restart EasyEffects. iNiR will detect the Equalizer automatically.")
        if (EasyEffects.equalizerError === "plugin_not_found")
            return Services.Translation.tr("EasyEffects is connected, but its output pipeline has no Equalizer. In EasyEffects, open Output → Effects, add Equalizer, and leave this panel open. iNiR will detect the new Equalizer automatically without replacing the rest of your effects chain.")
        if (!EasyEffects.equalizerPluginAvailable)
            return Services.Translation.tr("EasyEffects is connected, but the Equalizer backend is not controllable. Make sure Linux Studio Plugins (LV2) is available to EasyEffects, then refresh this panel.")
        if (EasyEffects.equalizerBandCount !== 10)
            return Services.Translation.tr("Configure this Equalizer as 10 bands at 32 Hz through 16 kHz. This resets only the Equalizer bands, not the rest of your EasyEffects pipeline.")
        return ""
    }

    PanelSurface {
        id: panelSurface
        anchors.fill: parent
        elevation: 1
        cardStyle: true
        wallpaperBackdrop: true

        // The popup is positioned by its loader. Keep the wallpaper-backed
        // glass aligned to the actual screen position instead of sampling a
        // stale origin when that loader moves or the output geometry changes.
        readonly property point _screenPos: {
            void root.x; void root.y; void root.width; void root.height
            void (root.parent?.x ?? 0); void (root.parent?.y ?? 0)
            return panelSurface.mapToItem(null, 0, 0)
        }
        backdropScreenX: _screenPos.x
        backdropScreenY: _screenPos.y
    }

    // The outer shell is a panel, not a nested card. PanelSurface supplies the
    // shared blur/backdrop/chrome; this role layer supplies the corresponding
    // panel material so Aurora/Angel keep their configured transparency without
    // letting arbitrary wallpaper luminance become the EQ's content background.
    Rectangle {
        anchors.fill: parent
        visible: Appearance.auroraEverywhere
        radius: panelSurface._radius
        color: Appearance.angelEverywhere
            ? Appearance.angel.colGlassPanel
            : Appearance.aurora.colOverlay
    }

    ColumnLayout {
        id: contentLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 18
        }
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 6 : 10

            Rectangle {
                implicitWidth: root.compact ? 40 : 46
                implicitHeight: implicitWidth
                radius: root.editorial ? Appearance.rounding.small : Appearance.rounding.full
                color: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
                    : Appearance.zzzEverywhere ? Appearance.zzz.sticker
                    : root.editorial ? Appearance.editorial.field
                    : Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                    : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                    : Appearance.colors.colPrimaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "graphic_eq"
                    iconSize: 24
                    fill: 1
                    color: Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                        : Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
                        : root.accentColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: Services.Translation.tr("Equalizer")
                    font.family: root.editorial ? Appearance.editorial.displayFamily : Appearance.font.family.title
                    font.variableAxes: Appearance.font.variableAxes.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Appearance.zzzEverywhere ? Font.Black
                        : root.editorial ? Appearance.editorial.titleWeight
                        : Font.DemiBold
                    font.letterSpacing: root.editorial ? Appearance.editorial.titleTracking : 0
                    color: root.textColor
                }

                StyledText {
                    Layout.fillWidth: true
                    text: EasyEffects.equalizerReady
                        ? Services.Translation.tr("EasyEffects output • %1").arg(EasyEffects.equalizerPreset)
                        : Services.Translation.tr("EasyEffects output")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.subtextColor
                }
            }

            IconToolbarButton {
                implicitHeight: root.compact ? 32 : 34
                enabled: !EasyEffects.equalizerLoading
                text: EasyEffects.equalizerLoading ? "progress_activity" : "refresh"
                iconSize: 19
                onClicked: EasyEffects.refreshEqualizer()
                StyledToolTip { text: Services.Translation.tr("Refresh") }
            }

            IconToolbarButton {
                implicitHeight: root.compact ? 32 : 34
                enabled: EasyEffects.available
                text: "power_settings_new"
                iconSize: 19
                toggled: EasyEffects.active
                onClicked: {
                    EasyEffects.toggle()
                    activeRefreshTimer.restart()
                }
                StyledToolTip { text: EasyEffects.active ? Services.Translation.tr("Disable EasyEffects") : Services.Translation.tr("Enable EasyEffects") }
            }

            IconToolbarButton {
                implicitHeight: root.compact ? 32 : 34
                text: "close"
                iconSize: 19
                onClicked: GlobalStates.closeEqualizer()
                StyledToolTip { text: Services.Translation.tr("Close") }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: EasyEffects.equalizerReady
            enabled: !EasyEffects.equalizerLoading

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: bandCardLayout.implicitHeight + 28
                elevation: 2
                cardStyle: true
                wallpaperBackdrop: false

                ColumnLayout {
                    id: bandCardLayout
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                text: Services.Translation.tr("10-band equalizer")
                                font.family: root.editorial ? Appearance.editorial.displayFamily : Appearance.font.family.title
                                font.variableAxes: Appearance.font.variableAxes.title
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: root.editorial ? Appearance.editorial.titleWeight : Font.DemiBold
                                font.letterSpacing: root.editorial ? Appearance.editorial.titleTracking * 0.45 : 0
                                color: root.cardInk
                            }

                            StyledText {
                                text: Services.Translation.tr("Shape the output without leaving your current effects chain")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.subtextColor
                                visible: !root.compact
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: rangeLabel.implicitWidth + 18
                            radius: root.editorial ? Appearance.rounding.small : Appearance.rounding.full
                            color: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
                                : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                                : root.editorial ? Appearance.editorial.layer(2)
                                : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                : Appearance.colors.colSurfaceContainerHigh

                            StyledText {
                                id: rangeLabel
                                anchors.centerIn: parent
                                text: "−12  ·  +12 dB"
                                font.family: Appearance.font.family.numbers
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.subtextColor
                            }
                        }
                    }

                    GridLayout {
                        id: bandGrid
                        Layout.fillWidth: true
                        columns: 10
                        columnSpacing: root.compact ? 2 : 5
                        rowSpacing: 0

                        Repeater {
                            model: EasyEffects.equalizerBands

                            delegate: EqualizerBandSlider {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 24
                                Layout.preferredWidth: root.compact ? 29 : 42
                                onValueCommitted: (bandIndex, value) => EasyEffects.setEqualizerBand(bandIndex, value)
                            }
                        }
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: presetLayout.implicitHeight + 24
                elevation: 1
                cardStyle: true
                wallpaperBackdrop: false

                ColumnLayout {
                    id: presetLayout
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: Services.Translation.tr("Presets")
                            font.family: Appearance.font.family.title
                            font.variableAxes: Appearance.font.variableAxes.title
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: root.cardInk
                        }

                        RowLayout {
                            visible: EasyEffects.equalizerReady
                            spacing: 5

                            MaterialSymbol {
                                text: "sync_alt"
                                iconSize: 14
                                color: root.accentColor
                            }

                            StyledText {
                                text: Services.Translation.tr("L/R linked")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: root.subtextColor
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: root.compact ? 5 : 8
                        rowSpacing: 8

                        Repeater {
                            model: root.presetNames

                            delegate: EqualizerPresetButton {
                                required property string modelData
                                Layout.fillWidth: true
                                presetName: modelData
                                selected: EasyEffects.equalizerPreset === modelData
                                onClicked: EasyEffects.applyEqualizerPreset(modelData)
                            }
                        }
                    }
                }
            }
        }

        PanelSurface {
            Layout.fillWidth: true
            implicitHeight: unavailableLayout.implicitHeight + 36
            elevation: 2
            cardStyle: true
            wallpaperBackdrop: false
            visible: !EasyEffects.equalizerReady

            ColumnLayout {
                id: unavailableLayout
                anchors.fill: parent
                anchors.margins: 18
                spacing: 11

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 54
                    implicitHeight: 54
                    radius: Appearance.rounding.full
                    color: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
                        : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                        : Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                        : Appearance.colors.colPrimaryContainer

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: EasyEffects.equalizerPluginAvailable ? "tune" : "graphic_eq"
                        iconSize: 28
                        fill: 1
                        color: root.accentColor
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.statusTitle()
                    font.family: Appearance.font.family.title
                    font.variableAxes: Appearance.font.variableAxes.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: root.cardInk
                    wrapMode: Text.Wrap
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.statusBody()
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: root.subtextColor
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 3
                    spacing: 8

                    RippleButton {
                        id: openEasyEffectsButton
                        visible: EasyEffects.available && (!EasyEffects.equalizerPluginAvailable || !EasyEffects.equalizerServerAvailable)
                        implicitHeight: 40
                        implicitWidth: openEasyEffectsContent.implicitWidth + 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
                            : Appearance.zzzEverywhere ? Appearance.zzz.sticker
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                            : Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateHover
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                            : Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateActive
                            : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive
                            : Appearance.colors.colPrimaryContainerActive
                        onClicked: EasyEffects.openWindow()

                        contentItem: RowLayout {
                            id: openEasyEffectsContent
                            anchors.centerIn: parent
                            spacing: 7

                            MaterialSymbol {
                                text: "open_in_new"
                                iconSize: 17
                                color: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
                                    : Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                                    : Appearance.colors.colOnPrimaryContainer
                            }
                            StyledText {
                                text: Services.Translation.tr("Open EasyEffects")
                                font.family: Appearance.font.family.main
                                font.variableAxes: Appearance.font.variableAxes.main
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.DemiBold
                                color: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateInk
                                    : Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                                    : Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    RippleButton {
                        id: configureButton
                        visible: EasyEffects.equalizerPluginAvailable
                            && EasyEffects.equalizerSupported
                            && EasyEffects.equalizerBandCount !== 10
                        implicitHeight: 40
                        implicitWidth: configureContent.implicitWidth + 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
                            : Appearance.zzzEverywhere ? Appearance.zzz.paperAlt
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.colors.colSurfaceContainerHigh
                        colBackgroundHover: Appearance.colLayer2Hover
                        colRipple: Appearance.colLayer1Active
                        onClicked: EasyEffects.configureTenBandEqualizer()

                        contentItem: RowLayout {
                            id: configureContent
                            anchors.centerIn: parent
                            spacing: 7
                            MaterialSymbol {
                                text: "tune"
                                iconSize: 17
                                color: root.cardInk
                            }
                            StyledText {
                                text: Services.Translation.tr("Configure 10 bands")
                                font.family: Appearance.font.family.main
                                font.variableAxes: Appearance.font.variableAxes.main
                                font.pixelSize: Appearance.font.pixelSize.smallie
                                font.weight: Font.DemiBold
                                color: root.cardInk
                            }
                        }
                    }
                }
            }
        }
    }
}
