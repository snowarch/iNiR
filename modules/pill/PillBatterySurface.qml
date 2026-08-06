pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common
import qs.services

/**
 * 蓄 BATTERY surface: a typographic read-out for the laptop battery. The
 * percentage is the hero, set over a time-to-empty/full subline, with a thin
 * charge meter and an adaptive stat list (Rate / Health / Capacity) beneath a
 * hairline. Health drops when UPower can't report it and the time line drops
 * when no estimate exists; on AC-full the subline reads "Plugged in". Charging
 * warms the percentage, subline and meter to the flame tones. Exposes
 * `implicitHeight` from its content and docks Ame as a seam at the charge head.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 19
    mRight: 19
    mBottom: 16

    implicitHeight: content.implicitHeight

    /**
     * Where the seam docks: the head of the charge meter, mirroring the
     * seek-stroke head on the media card. Sits clear of the hero number and
     * tracks the charge level. mapToItem isn't reactive, so the void reads
     * force re-eval across the morph and on charge changes.
     */
    readonly property point chargeHead: {
        void root.width;
        void root.height;
        void PillBattery.frac;
        void meter.width;
        return meter.mapToItem(root, meter.width * PillBattery.frac, meter.height / 2);
    }

    ameForm: "seam"
    amePoint: chargeHead

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Item {
            width: parent.width
            height: 22 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: PillTheme.showGlyphs
                    text: PillTheme.glyph("battery")
                    color: PillTheme.cream
                    font.family: PillTheme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Translation.tr("BATTERY")
                    color: PillTheme.subtle
                    font.family: PillTheme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: PillBattery.stateLabel
                color: PillBattery.charging ? PillTheme.flameGlow : PillTheme.dim
                font.family: PillTheme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.1 * root.s
            }
        }

        Column {
            width: parent.width
            topPadding: 16 * root.s
            bottomPadding: 14 * root.s
            spacing: 9 * root.s

            Text {
                id: pctText
                text: PillBattery.pct + "%"
                color: PillBattery.low ? PillTheme.vermLit : (PillBattery.charging ? PillTheme.flameGlow : PillTheme.cream)
                font.family: PillTheme.font
                font.pixelSize: 46 * root.s
                font.weight: Font.Bold
                font.letterSpacing: -1 * root.s
                font.features: { "tnum": 1 }
            }

            Text {
                readonly property string body: PillBattery.full
                    ? Translation.tr("Plugged in")
                    : (PillBattery.hasTime
                        ? PillBattery.timeStr + (PillBattery.charging ? Translation.tr(" to full") : Translation.tr(" remaining"))
                        : "")
                visible: body.length > 0
                text: body
                color: PillBattery.charging ? PillTheme.flameCore : PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: meter
            width: parent.width
            height: 3 * root.s
            radius: 1.5 * root.s
            color: PillTheme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * PillBattery.frac
                radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: PillBattery.charging ? PillTheme.vermLit : PillTheme.vermDeep }
                    GradientStop { position: 1.0; color: PillBattery.charging ? PillTheme.flameGlow : PillTheme.vermLit }
                }
            }
        }

        Column {
            width: parent.width
            topPadding: 16 * root.s
            spacing: 10 * root.s

            component StatRow: Item {
                id: stat
                width: parent ? parent.width : 0
                height: vText.implicitHeight
                property string label: ""
                property string value: ""
                property bool warm: false

                Text {
                    anchors.left: parent.left
                    anchors.baseline: vText.baseline
                    text: stat.label
                    color: PillTheme.faint
                    font.family: PillTheme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8 * root.s
                }

                Text {
                    id: vText
                    anchors.right: parent.right
                    text: stat.value
                    color: stat.warm ? PillTheme.flameGlow : PillTheme.cream
                    font.family: PillTheme.font
                    font.pixelSize: 12.5 * root.s
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            StatRow {
                visible: Math.abs(PillBattery.rateW) >= 0.05
                label: Translation.tr("Rate")
                value: (PillBattery.rateW > 0 ? "+" : "−") + Math.abs(PillBattery.rateW).toFixed(1) + " W"
                warm: PillBattery.charging
            }

            StatRow {
                visible: PillBattery.healthSupported
                label: Translation.tr("Health")
                value: PillBattery.health + "%"
                warm: true
            }

            StatRow {
                visible: PillBattery.capacityWh >= 1
                label: Translation.tr("Capacity")
                value: PillBattery.capacityWh.toFixed(1) + " Wh"
            }
        }
    }
}
