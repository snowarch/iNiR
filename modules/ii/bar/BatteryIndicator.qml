import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless

    // Easter egg: long-press the battery and she boops in
    onPressAndHold: {
        if (Config.options?.mascot?.enable ?? false)
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "appearWithLine",
                "camera-boop", "top", Translation.tr("Boop.")])
    }
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: batteryProgress.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true

    ClippedProgressBar {
        id: batteryProgress
        anchors.centerIn: parent
        value: percentage
        highlightColor: (isLow && !isCharging)
            ? (Appearance.inirEverywhere ? Appearance.inir.colError : Appearance.colors.colError)
            : (Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0)

        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            RowLayout {
                anchors.centerIn: parent
                spacing: 0

                MaterialSymbol {
                    id: boltIcon
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Appearance.font.pixelSize.smaller
                    opacity: (isCharging && percentage < 1) ? 1 : 0
                    visible: opacity > 0
                    
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { 
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                }
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
