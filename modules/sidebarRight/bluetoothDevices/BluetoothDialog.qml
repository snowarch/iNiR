import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell
import Quickshell.Wayland

WindowDialog {
    id: root
    backgroundHeight: 450
    readonly property bool bluetoothOn: Bluetooth.defaultAdapter?.enabled ?? false

    WindowDialogTitle {
        text: Translation.tr("Bluetooth devices")
    }
    WindowDialogSeparator {
        visible: !(Bluetooth.defaultAdapter?.discovering ?? false)
    }
    StyledIndeterminateProgressBar {
        visible: Bluetooth.defaultAdapter?.discovering ?? false
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
        enabled: root.bluetoothOn
        opacity: root.bluetoothOn ? 1 : 0.45

        model: ScriptModel {
            values: root.bluetoothOn ? [...Bluetooth.devices.values].sort((a, b) => {
                // Connected -> paired -> others
                let conn = (b.connected - a.connected) || (b.paired - a.paired);
                if (conn !== 0) return conn;

                // Ones with meaningful names before MAC addresses
                const macRegex = /^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$/;
                const aIsMac = macRegex.test(a.name);
                const bIsMac = macRegex.test(b.name);
                if (aIsMac !== bIsMac) return aIsMac ? 1 : -1;

                // Alphabetical by name
                return a.name.localeCompare(b.name);
            }) : []
        }
        delegate: BluetoothDeviceItem {
            required property BluetoothDevice modelData
            device: modelData
            anchors {
                left: parent?.left
                right: parent?.right
                leftMargin: 8
                rightMargin: 8
            }
        }

        // Empty state: no devices or bluetooth off
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6
            visible: Bluetooth.devices.values.length === 0 || (!root.bluetoothOn && !(Bluetooth.defaultAdapter?.discovering ?? false))

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 48
                text: !root.bluetoothOn ? "bluetooth_disabled" : "bluetooth_searching"
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (!root.bluetoothOn)
                        return Translation.tr("Bluetooth is off")
                    if (Bluetooth.defaultAdapter?.discovering)
                        return Translation.tr("Searching devices…")
                    return Translation.tr("No devices found")
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
                AppLauncher.launch("bluetooth")
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
