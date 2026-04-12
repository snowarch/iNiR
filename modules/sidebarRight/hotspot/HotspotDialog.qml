pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 310

    WindowDialogTitle {
        text: Translation.tr("Hotspot")
    }

    WindowDialogSectionHeader {
        text: Translation.tr("Configuration")
    }

    WindowDialogSeparator {
        Layout.topMargin: -22
        Layout.leftMargin: 0
        Layout.rightMargin: 0
    }

    Column {
        Layout.topMargin: -16
        Layout.fillWidth: true
        spacing: 8

        MaterialTextField {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 4
                rightMargin: 4
            }
            placeholderText: Translation.tr("Network name (SSID)")
            text: Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
            onTextEdited: Config.setNestedValue("hotspot.ssid", text)
        }

        MaterialTextField {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 4
                rightMargin: 4
            }
            placeholderText: Translation.tr("Password")
            text: Config.options?.hotspot?.password ?? "inirhotspot"
            echoMode: TextInput.Password
            onTextEdited: Config.setNestedValue("hotspot.password", text)
        }

        ConfigSwitch {
            anchors {
                left: parent.left
                right: parent.right
            }
            iconSize: Appearance.font.pixelSize.larger
            buttonIcon: "wifi_tethering"
            text: Translation.tr("Use 5 GHz band")
            checked: (Config.options?.hotspot?.band ?? "bg") === "a"
            onCheckedChanged: Config.setNestedValue("hotspot.band", checked ? "a" : "bg")
            StyledToolTip {
                text: Translation.tr("Requires adapter with AP mode support (802.11a)")
            }
        }
    }

    WindowDialogButtonRow {
        Layout.fillWidth: true

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
