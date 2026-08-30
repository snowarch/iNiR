pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    property bool isHeader: false
    property int eventCount: 0
    // Source colors for multi-colored dots (from CalendarSync + local events)
    property var sourceColors: []

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38
    implicitHeight: 38

    toggled: (isToday == 1) && !isHeader
    buttonRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    // ZZZ today = confident accent "sticker" chip so onSticker text stays readable
    // (RippleButton's default zzz toggled bg is near-black chrome → dark-on-dark).
    colBackgroundToggled: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
        : Appearance.zzzEverywhere ? Appearance.zzz.sticker : Appearance.colors.colPrimary
    colBackgroundToggledHover: Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlateHover
        : Appearance.zzzEverywhere ? ColorUtils.mix(Appearance.zzz.sticker, Appearance.zzz.accent, 0.5) : Appearance.colors.colPrimaryHover

    contentItem: Item {
        anchors.fill: parent

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: (button.eventCount > 0 && !button.isHeader) ? -2 : 0
            text: button.day
            horizontalAlignment: Text.AlignHCenter
            font.weight: button.bold ? Font.DemiBold : Font.Normal
            color: Appearance.regaliaEverywhere
                ? (button.isHeader && (button.isToday == 1) ? Appearance.regalia.hardwarePrimary
                    : (button.isToday == 1) ? Appearance.regalia.primaryPlateInk
                    : (button.isToday == 0) ? Appearance.regalia.onColor
                    : Appearance.regalia.onMuted)
                : Appearance.zzzEverywhere
                ? (button.isHeader && (button.isToday == 1) ? Appearance.zzz.accent
                    : (button.isToday == 1) ? Appearance.zzz.onSticker
                    : (button.isToday == 0) ? Appearance.zzz.ink
                    : Appearance.zzz.inkMuted)
                : button.isHeader && (button.isToday == 1)
                ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                : (button.isToday == 1)
                    ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                    : (button.isToday == 0)
                        ? (Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1)
                        : (Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                            : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                            : Appearance.auroraEverywhere ? Appearance.colors.colSubtext
                            : Appearance.colors.colOutlineVariant)

            Behavior on color {
                enabled: Appearance.animationsEnabled
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        // Multi-colored event indicator dots
        Row {
            scale: (button.eventCount > 0 && !button.isHeader) ? 1 : 0
            visible: scale > 0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            spacing: 2

            Repeater {
                // Show up to 3 dots, one per unique source color
                model: {
                    const colors = button.sourceColors
                    if (!colors || colors.length === 0) {
                        // Fallback: single dot in primary color (local events only)
                        if (button.eventCount > 0) {
                            const primary = Appearance.zzzEverywhere
                                ? (button.isToday == 1 ? Appearance.zzz.onSticker : Appearance.zzz.accent)
                                : button.isToday == 1
                                ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                                : (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary)
                            return [primary]
                        }
                        return []
                    }
                    return colors.slice(0, 3)
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 5
                    height: 5
                    radius: 2.5
                    color: modelData

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                }
            }

            // Overflow indicator when more than 3 sources
            StyledText {
                opacity: (button.sourceColors?.length ?? 0) > 3 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                text: "+"
                font.pixelSize: 7
                font.weight: Font.Bold
                color: button.isToday == 1
                    ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnPrimary)
                    : (Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext)
            }
        }
    }
}
