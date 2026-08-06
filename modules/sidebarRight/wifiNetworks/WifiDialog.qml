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

        model: ScriptModel {
            values: [...Network.wifiNetworks].sort((a, b) => {
                if (a.active && !b.active)
                    return -1;
                if (!a.active && b.active)
                    return 1;
                return b.strength - a.strength;
            })
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
            visible: Network.wifiNetworks.length === 0 && !Network.wifiScanning

            MascotImage {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 100
                Layout.preferredHeight: 100
                pose: "network-offline"
                surface: "wifi"
                fallbackSurface: "emptyStates"
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("No networks found")
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
