pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

/**
 * The surface a ringing alarm raises.
 *
 * It owns a window of its own rather than posting a notification, for two
 * reasons that are both facts about this shell:
 *   1. Nothing here can post an ACTIONABLE notification. Every shell-originated
 *      notification is a `notify-send` subprocess with no actions and no
 *      callback path (services/TimerService.qml), and services/Notifications.qml
 *      is a server for incoming notifications, not a sender.
 *   2. Notifications.popupInhibited suppresses popups while the right sidebar
 *      is open, while the waffle notification centre is open, when silent,
 *      during quiet hours and in game mode. An alarm that a suppression setting
 *      can swallow is not an alarm, so this deliberately sits outside that
 *      pipeline and outside every one of those guards.
 *
 * It is notification-sized on purpose — the spec rules out a full-screen
 * takeover. ii family only; waffle has no ringing panel.
 */
Scope {
    id: root

    readonly property int ringingId: AlarmService.ringingId
    readonly property var alarm: AlarmService.ringingAlarm
    readonly property string timeFormat: Config.options?.time?.format ?? "hh:mm"

    Loader {
        active: root.ringingId !== -1

        sourceComponent: PanelWindow {
            id: window

            // Style tokens, dispatched zzz > angel > inir > aurora > material.
            readonly property color colText: Appearance.zzzEverywhere ? Appearance.zzz.onColor : Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            readonly property color colTextSecondary: Appearance.zzzEverywhere ? Appearance.zzz.onMuted : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            readonly property color colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent : Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
            readonly property color colCard: Appearance.zzzEverywhere ? Appearance.zzz.bg2 : Appearance.angelEverywhere ? Appearance.angel.colGlassCard : Appearance.inirEverywhere ? Appearance.inir.colLayer1 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface : Appearance.colors.colLayer1
            readonly property color colBorder: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong : Appearance.angelEverywhere ? Appearance.angel.colCardBorder : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colOutlineVariant
            readonly property real cardRadius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius : Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal

            //  honesty: the ring happened, the noise did not. Muted system
            // first — that is the one the user can actually do something about.
            readonly property string silenceReason: AlarmAudio.silencedBySystem ? Translation.tr("System sound is muted, so this alarm is ringing silently.") : AlarmAudio.soundUnavailable ? Translation.tr("No alarm sound could be played, so this alarm is ringing silently.") : ""

            screen: CompositorService.isNiri ? Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen

            WlrLayershell.namespace: "quickshell:alarmRinging"
            WlrLayershell.layer: WlrLayer.Overlay
            // On demand, not exclusive: needs the ring to be stoppable
            // without a mouse, but an alarm at 07:00 must not swallow the
            // keystrokes of whatever the user was typing. On demand is the one
            // setting that is both — the compositor may hand this surface the
            // keyboard, and nothing is taken until it does.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            exclusiveZone: 0
            color: "transparent"

            // Top-centre, and that is load-bearing rather than taste. Overlay is
            // the highest layer there is, and wlroots stacks same-layer surfaces
            // by map order — so the right sidebar, opened after the ring began,
            // is drawn OVER anything anchored top-right and fails. Not
            // overlapping it is cheaper and steadier than unmapping and
            // remapping this surface to jump the stack every time a panel opens.
            // Anchoring only `top` centres the surface horizontally.
            // ponytail: still loses to a FULL-SCREEN Overlay panel (overview,
            // session screen); every one of those closes on the next keypress,
            // and beating them needs the remap trick above.
            anchors {
                top: true
            }

            implicitWidth: Appearance.sizes.notificationPopupWidth
            implicitHeight: card.implicitHeight + 8

            // Only the card takes clicks; the rest of the surface stays
            // click-through so this cannot block the desktop underneath.
            mask: Region {
                item: card
            }

            Rectangle {
                id: card

                // the ring has to be stoppable without a pointer. The
                // whole card takes the keys so it works wherever focus sits
                // inside it, and both buttons stay in the tab chain behind it.
                focus: true
                Keys.onEscapePressed: AlarmService.snoozeAlarm(root.ringingId)
                Keys.onReturnPressed: AlarmService.dismissAlarm(root.ringingId)
                Keys.onEnterPressed: AlarmService.dismissAlarm(root.ringingId)

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 4
                implicitHeight: content.implicitHeight + 24
                radius: window.cardRadius
                color: window.colCard
                border.width: window.colBorder === "transparent" ? 0 : 1
                border.color: window.colBorder

                ColumnLayout {
                    id: content
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MaterialSymbol {
                            text: "alarm"
                            iconSize: 28
                            color: window.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: AlarmService.displayName(root.alarm)
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: window.colText
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // The occurrence being rung for, never the
                                // current time: a queued or snoozed alarm rings
                                // late on purpose and has to say what it was
                                // set for.
                                StyledText {
                                    text: Qt.locale().toString(new Date(AlarmService.ringingDueMs), AlarmService.ringingLate ? "ddd " + root.timeFormat : root.timeFormat)
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: window.colTextSecondary
                                    textFormat: Text.PlainText
                                }

                                Rectangle {
                                    visible: AlarmService.ringingLate
                                    implicitWidth: lateLabel.implicitWidth + 12
                                    implicitHeight: lateLabel.implicitHeight + 4
                                    radius: Appearance.rounding.full
                                    color: Appearance.colors.colTertiaryContainer

                                    StyledText {
                                        id: lateLabel
                                        anchors.centerIn: parent
                                        text: Translation.tr("Late")
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnTertiaryContainer
                                        textFormat: Text.PlainText
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        visible: window.silenceReason !== ""
                        implicitHeight: silenceRow.implicitHeight + 12
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colErrorContainer

                        RowLayout {
                            id: silenceRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 8
                            spacing: 6

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignTop
                                text: "volume_off"
                                iconSize: 16
                                color: Appearance.colors.colOnErrorContainer
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: window.silenceReason
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnErrorContainer
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                        }

                        DialogButton {
                            buttonText: Translation.tr("Snooze %1 min").arg(AlarmService.resolveSnoozeMinutes(root.alarm))
                            // buttonText is this repo's own property, so the
                            // control's own text — the one a screen reader
                            // reads — is empty unless it is said here.
                            Accessible.role: Accessible.Button
                            Accessible.name: buttonText
                            Accessible.description: Translation.tr("Silence this alarm and ring again later. Escape does the same.")
                            onClicked: AlarmService.snoozeAlarm(root.ringingId)
                        }

                        DialogButton {
                            buttonText: Translation.tr("Dismiss")
                            Accessible.role: Accessible.Button
                            Accessible.name: buttonText
                            Accessible.description: Translation.tr("Stop this alarm. Enter does the same.")
                            colBackground: window.colPrimary
                            colBackgroundHover: Appearance.colors.colPrimaryHover
                            colText: Appearance.colors.colOnPrimary
                            onClicked: AlarmService.dismissAlarm(root.ringingId)
                        }
                    }
                }
            }
        }
    }
}
