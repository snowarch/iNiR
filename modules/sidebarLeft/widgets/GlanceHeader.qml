pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    implicitHeight: col.implicitHeight + col.anchors.topMargin
    readonly property bool volumeMuted: Boolean(Audio.sink?.audio?.muted ?? false)
    readonly property real volumeLevel: Math.max(0, Audio.value)

    readonly property var locale: {
        const env = Quickshell.env("LC_TIME") || Quickshell.env("LC_ALL") || Quickshell.env("LANG") || ""
        const cleaned = (env.split(".")[0] ?? "").split("@")[0] ?? ""
        return cleaned ? Qt.locale(cleaned) : Qt.locale()
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        // Breathing room between the clock and the card's top edge in every
        // style — the header used to sit flush against the border in material.
        anchors.topMargin: 12
        spacing: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 2 : 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: DateTime.time
                font.pixelSize: Appearance.font.pixelSize.huge * 2
                font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Light
                font.family: Appearance.font.family.numbers
                font.italic: Appearance.zzzEverywhere
                color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                animateChange: true
            }

            Item { Layout.fillWidth: true }

            // Buttons container with inir styling
            Row {
                spacing: 6

                // GameMode indicator
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: Appearance.inirEverywhere ? "transparent"
                        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colTertiaryContainer
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : (Appearance.colors.colTertiaryContainerHover ?? Appearance.colors.colTertiaryContainer)
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : (Appearance.colors.colTertiaryContainerActive ?? Appearance.colors.colTertiaryContainer)
                    opacity: GameMode.active && (Config.options?.sidebar?.widgets?.glance?.showGameMode ?? true) ? 1 : 0
                    visible: opacity > 0
                    scale: opacity
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    onClicked: GameMode.toggle()

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "sports_esports"
                            iconSize: 18
                            fill: 1
                            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colOnTertiaryContainer
                        }
                    }

                    StyledToolTip { text: Translation.tr("Game mode active - click to disable") }
                }

                // DND indicator
                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : (Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full)
                    colBackground: Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.inirEverywhere ? "transparent"
                        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colPrimaryContainerActive
                    opacity: Notifications.silent && (Config.options?.sidebar?.widgets?.glance?.showDnd ?? true) ? 1 : 0
                    visible: opacity > 0
                    scale: opacity
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on scale { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    onClicked: Notifications.toggleSilent()

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "do_not_disturb_on"
                            iconSize: 18
                            fill: 1
                            color: Appearance.zzzEverywhere ? Appearance.zzz.onSticker : (Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colOnPrimaryContainer)
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                        }
                    }

                    StyledToolTip { text: Translation.tr("Do not disturb is on") }
                }

                // Volume button with scroll support
                Item {
                    implicitWidth: volumeBtn.implicitWidth
                    implicitHeight: volumeBtn.implicitHeight
                    opacity: Audio.sink !== null && (Config.options?.sidebar?.widgets?.glance?.showVolume ?? true) ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }

                    RippleButton {
                        id: volumeBtn
                        anchors.fill: parent
                        implicitWidth: 60
                        implicitHeight: 36
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active
                        onClicked: Audio.toggleMute()

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.volumeMuted ? "volume_off" :
                                          root.volumeLevel < 0.01 ? "volume_mute" :
                                          root.volumeLevel < 0.5 ? "volume_down" : "volume_up"
                                    iconSize: 18
                                    fill: root.volumeMuted ? 1 : 0
                                    animateFill: true
                                    color: root.volumeMuted
                                        ? (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
                                        : (Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)
                                    Behavior on color { enabled: Appearance.animationsEnabled; animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: String(Math.round(root.volumeLevel * 100))
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.numbers
                                    color: root.volumeMuted
                                        ? (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
                                        : (Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)

                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                }
                            }
                        }

                        StyledToolTip { text: root.volumeMuted ? Translation.tr("Unmute") : Translation.tr("Scroll to adjust volume") }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (event) => {
                            if (event.angleDelta.y > 0) Audio.incrementVolume()
                            else Audio.decrementVolume()
                        }
                    }
                }

                // Widget Management Button
                RippleButton {
                    id: settingsBtn
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer1Hover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active

                    onClicked: {
                        const isWaffle = (Config.options?.panelFamily === "waffle" && Config.options?.waffles?.settings?.useMaterialStyle !== true);
                        const settingsPath = isWaffle ? Quickshell.shellPath("waffleSettings.qml") : Quickshell.shellPath("settings.qml");
                        const pageIndex = isWaffle ? 6 : 5; // Modules (Waffle) vs Interface (ii)
                        const section = isWaffle ? Translation.tr("Widgets Panel") : Translation.tr("Widgets");

                        Quickshell.execDetached(["/usr/bin/env", "QS_SETTINGS_PAGE=" + pageIndex, "QS_SETTINGS_SECTION=" + section, Quickshell.shellPath("scripts/inir"), isWaffle ? "waffle-settings-window" : "settings-window"]);
                    }

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "tune" // or 'widgets'
                            iconSize: 18
                            fill: 0
                            color: Appearance.zzzEverywhere ? Appearance.zzz.ink : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }
                    }

                    StyledToolTip { text: Translation.tr("Manage Widgets") }
                }
            }
        }

        // Subtitle with complementary info
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.inirEverywhere ? 10 : 0
            spacing: 8

            StyledText {
                readonly property string _configFormat: Config.options?.time?.dateFormat ?? ""
                readonly property string _defaultFormat: Appearance.inirEverywhere ? "dddd, MMMM yyyy" : "dddd, d MMMM"
                text: root.locale.toString(DateTime.clock.date, _configFormat.length > 0 ? _configFormat : _defaultFormat)
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }
}
