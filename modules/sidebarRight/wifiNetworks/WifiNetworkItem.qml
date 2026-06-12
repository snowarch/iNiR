import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property WifiAccessPoint wifiNetwork
    enabled: !(Network.wifiConnectTarget === root.wifiNetwork && !wifiNetwork?.active)

    active: (wifiNetwork?.askingPassword || wifiNetwork?.active) ?? false
    onClicked: {
        Network.connectToWifiNetwork(wifiNetwork);
    }

    contentItem: ColumnLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 0

        RowLayout {
            // Name
            spacing: 10
            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                property int strength: root.wifiNetwork?.strength ?? 0
                text: strength > 80 ? "signal_wifi_4_bar" : strength > 60 ? "network_wifi_3_bar" : strength > 40 ? "network_wifi_2_bar" : strength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnSurfaceVariant
            }
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")
                }
                Revealer {
                    vertical: true
                    reveal: root.wifiNetwork?.active ?? false
                    Layout.fillWidth: true
                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
                        elide: Text.ElideRight
                        text: {
                            if (!root.wifiNetwork || !root.wifiNetwork.active) return "";
                            let details = [];
                            details.push(Translation.tr("Connected"));
                            details.push(root.wifiNetwork.strength + "%");
                            if (root.wifiNetwork.frequency) {
                                let ghz = root.wifiNetwork.frequency > 5900 ? "6 GHz" : (root.wifiNetwork.frequency > 4000 ? "5 GHz" : "2.4 GHz");
                                details.push(ghz + " (" + root.wifiNetwork.frequency + " MHz)");
                            }
                            if (root.wifiNetwork.rate) {
                                details.push(root.wifiNetwork.rate);
                            }
                            if (root.wifiNetwork.bssid) {
                                details.push(root.wifiNetwork.bssid);
                            }
                            return details.join(" • ");
                        }
                    }
                }
            }
            MaterialSymbol {
                visible: (root.wifiNetwork?.isSecure || root.wifiNetwork?.active) ?? false
                text: root.wifiNetwork?.active ? "check" : Network.wifiConnectTarget === root.wifiNetwork ? "settings_ethernet" : "lock"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOnSurfaceVariant
            }
        }

        ColumnLayout { // Password
            id: passwordPrompt
            Layout.topMargin: 8
            visible: root.wifiNetwork?.askingPassword ?? false

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                MaterialTextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Password")

                    // Password
                    echoMode: showPasswordButton.showPassword ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData

                    onAccepted: {
                        Network.changePassword(root.wifiNetwork, passwordField.text);
                    }
                }

                RippleButton {
                    id: showPasswordButton
                    property bool showPassword: false
                    Layout.preferredHeight: passwordField.implicitHeight
                    Layout.preferredWidth: passwordField.implicitHeight
                    buttonRadius: passwordField.background ? passwordField.background.radius : 4
                    colBackground: Appearance.colors.colLayer2
                    onClicked: showPassword = !showPassword

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: showPasswordButton.showPassword ? "visibility" : "visibility_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: {
                        root.wifiNetwork.askingPassword = false;
                    }
                }

                DialogButton {
                    buttonText: Translation.tr("Connect")
                    onClicked: {
                        Network.changePassword(root.wifiNetwork, passwordField.text);
                    }
                }
            }
        }

        ColumnLayout { // Public wifi login page
            id: publicWifiPortal
            Layout.topMargin: 8
            visible: (root.wifiNetwork?.active && (root.wifiNetwork?.security ?? "").trim().length === 0) ?? false

            RowLayout {
                DialogButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Open network portal")
                    colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colLayer4
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colLayer4Hover
                    colRipple: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colLayer4Active
                    onClicked: {
                        Network.openPublicWifiPortal()
                        GlobalStates.sidebarRightOpen = false
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
