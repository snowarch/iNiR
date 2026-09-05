import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 450
    readonly property bool wifiOn: Network.wifiEnabled

    WindowDialogTitle {
        text: Translation.tr("Connect to Wi-Fi")
    }

    WindowDialogSeparator {
        opacity: !Network.wifiScanning ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }
    StyledIndeterminateProgressBar {
        opacity: Network.wifiScanning ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -(Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large)
        Layout.rightMargin: -(Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large)
    }
    StyledListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -(Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large)
        Layout.rightMargin: -(Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.large)
        leftMargin: 8
        rightMargin: 8
        topMargin: 8
        bottomMargin: 8

        clip: true
        spacing: 4
        animateAppearance: false
        enabled: root.wifiOn
        opacity: root.wifiOn ? 1 : 0.45

        model: ScriptModel {
            values: root.wifiOn ? [...Network.wifiNetworks].sort((a, b) => {
                if (a.active && !b.active)
                    return -1;
                if (!a.active && b.active)
                    return 1;
                return b.strength - a.strength;
            }) : []
        }
        delegate: WifiNetworkItem {
            required property WifiAccessPoint modelData
            wifiNetwork: modelData
            anchors {
                left: parent?.left
                right: parent?.right
                leftMargin: 8
                rightMargin: 8
            }
        }

        // Empty state: no networks and not scanning
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: Network.wifiNetworks.length === 0 || (!root.wifiOn && !Network.wifiScanning)

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 48
                text: !root.wifiOn && !Network.wifiScanning ? "signal_wifi_off" : "wifi_find"
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (!root.wifiOn && !Network.wifiScanning)
                        return Translation.tr("Wi-Fi is off")
                    if (Network.wifiScanning)
                        return Translation.tr("Searching networks…")
                    return Translation.tr("No networks found")
                }
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }
        }
    }
    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                AppLauncher.launchNetworkSettings(Network.ethernet)
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
