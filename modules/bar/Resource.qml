import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property string iconName
    required property double percentage
    property real warningThreshold: 100
    property real cautionThreshold: 0  // 0 = disabled
    property bool shown: true
    clip: true
    visible: width > 0 && height > 0
    implicitWidth: resourceRowLayout.x < 0 ? 0 : resourceRowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight
    property bool warning: percentage * 100 >= warningThreshold
    property bool caution: cautionThreshold > 0 && percentage * 100 >= cautionThreshold && !warning

    RowLayout {
        id: resourceRowLayout
        spacing: 2
        x: shown ? 0 : -resourceRowLayout.width
        anchors {
            verticalCenter: parent.verticalCenter
        }

        MaterialSymbol {
            visible: Appearance.zzzEverywhere
            Layout.alignment: Qt.AlignVCenter
            fill: 1
            text: root.iconName
            iconSize: Appearance.font.pixelSize.normal
            color: root.warning ? Appearance.zzz.signal
                : root.caution ? Appearance.zzz.tertiary
                : Appearance.zzz.inkMuted
        }

        ClippedFilledCircularProgress {
            id: resourceCircProg
            visible: !Appearance.zzzEverywhere
            Layout.alignment: Qt.AlignVCenter
            lineWidth: Appearance.rounding.unsharpen
            value: percentage
            implicitSize: 20
            colPrimary: root.warning ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError) :
                        root.caution ? (Appearance.inirEverywhere ? Appearance.inir.colWarning : Appearance.colors.colTertiary) :
                        (Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant)
            accountForLightBleeding: !root.warning && !root.caution
            enableAnimation: false

            Item {
                anchors.centerIn: parent
                width: resourceCircProg.implicitSize
                height: resourceCircProg.implicitSize
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    font.weight: Font.DemiBold
                    fill: 1
                    text: iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: fullPercentageTextMetrics.width
            implicitHeight: percentageText.implicitHeight

            TextMetrics {
                id: fullPercentageTextMetrics
                text: "100"
                font.pixelSize: Appearance.font.pixelSize.small
            }

            StyledText {
                id: percentageText
                anchors.centerIn: parent
                color: root.warning ? (Appearance.zzzEverywhere ? Appearance.zzz.signal : Appearance.colors.colError)
                    : Appearance.zzzEverywhere ? (root.caution ? Appearance.zzz.tertiary : Appearance.zzz.ink)
                    : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                font.pixelSize: Appearance.font.pixelSize.small
                font.family: Appearance.zzzEverywhere ? Appearance.font.family.numbers : Appearance.font.family.main
                font.weight: Appearance.zzzEverywhere ? Font.Black : Font.Normal
                font.italic: Appearance.zzzEverywhere
                text: `${Math.round(percentage * 100).toString()}`
            }
        }

        Behavior on x {
            animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: resourceRowLayout.x >= 0 && root.width > 0 && root.visible
    }

    Behavior on implicitWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}
