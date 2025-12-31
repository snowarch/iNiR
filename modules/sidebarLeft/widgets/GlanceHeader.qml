pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root
    implicitHeight: col.implicitHeight

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
        anchors.topMargin: Appearance.inirEverywhere ? 12 : 0
        spacing: Appearance.inirEverywhere ? 2 : 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                text: Qt.formatTime(DateTime.clock.date, "HH:mm")
                font.pixelSize: Appearance.font.pixelSize.huge * 2
                font.weight: Font.Light
                font.family: Appearance.font.family.numbers
                color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
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
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : (Appearance.colors.colTertiaryContainerHover ?? Appearance.colors.colTertiaryContainer)
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : (Appearance.colors.colTertiaryContainerActive ?? Appearance.colors.colTertiaryContainer)
                    visible: GameMode.active && (Config.options?.sidebar?.widgets?.glance?.showGameMode ?? true)
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
                    buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                    colBackground: Appearance.inirEverywhere ? "transparent" 
                        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colPrimaryContainerActive
                    visible: Notifications.silent && (Config.options?.sidebar?.widgets?.glance?.showDnd ?? true)
                    onClicked: Notifications.toggleSilent()

                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "do_not_disturb_on"
                            iconSize: 18
                            fill: 1
                            color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    StyledToolTip { text: Translation.tr("Do not disturb is on") }
                }

                // Volume button with scroll support
                Item {
                    implicitWidth: volumeBtn.implicitWidth
                    implicitHeight: volumeBtn.implicitHeight
                    visible: Audio.sink !== null && (Config.options?.sidebar?.widgets?.glance?.showVolume ?? true)

                    RippleButton {
                        id: volumeBtn
                        anchors.fill: parent
                        implicitWidth: 60
                        implicitHeight: 36
                        buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover 
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1Hover
                        colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer1Active 
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer1Active
                        onClicked: Audio.toggleMute()

                        contentItem: Item {
                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Audio.sink?.audio?.muted ? "volume_off" : 
                                          (Audio.sink?.audio?.volume ?? 0) < 0.01 ? "volume_mute" :
                                          (Audio.sink?.audio?.volume ?? 0) < 0.5 ? "volume_down" : "volume_up"
                                    iconSize: 18
                                    fill: Audio.sink?.audio?.muted ? 1 : 0
                                    color: Audio.sink?.audio?.muted 
                                        ? (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext) 
                                        : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)
                                    Behavior on fill { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                                    Behavior on color { enabled: Appearance.animationsEnabled; animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Math.round((Audio.sink?.audio?.volume ?? 0) * 100)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.numbers
                                    color: Audio.sink?.audio?.muted 
                                        ? (Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext) 
                                        : (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)

                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }
                            }
                        }

                        StyledToolTip { text: Audio.sink?.audio?.muted ? Translation.tr("Unmute") : Translation.tr("Scroll to adjust volume") }
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
            }
        }

        // Subtitle with complementary info
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Appearance.inirEverywhere ? 10 : 0
            spacing: 8
            
            StyledText {
                // For inir: show weekday and month only (no day number since calendar shows it)
                text: Appearance.inirEverywhere 
                    ? root.locale.toString(DateTime.clock.date, "dddd, MMMM yyyy")
                    : root.locale.toString(DateTime.clock.date, "dddd, d MMMM")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            }
        }
    }
}
