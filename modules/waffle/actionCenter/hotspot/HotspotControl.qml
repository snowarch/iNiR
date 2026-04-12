pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

Item {
    id: root

    // Shared toggle model so the switch stays in sync with the toggle button
    HotspotToggle {
        id: hotspotToggle
    }

    WPanelPageColumn {
        anchors.fill: parent

        BodyRectangle {
            implicitHeight: 280
            implicitWidth: 50

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    HeaderRow {
                        id: headerRow
                        Layout.fillWidth: true
                        title: Translation.tr("Hotspot")
                    }
                    WSwitch {
                        Layout.rightMargin: 12
                        checked: hotspotToggle.toggled
                        onCheckedChanged: {
                            if (checked !== hotspotToggle.toggled)
                                hotspotToggle.mainAction()
                        }
                    }
                }

                StyledFlickable {
                    id: flickable
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    contentHeight: contentLayout.implicitHeight
                    contentWidth: width
                    clip: true
                    bottomMargin: 12

                    ColumnLayout {
                        id: contentLayout
                        width: flickable.width
                        spacing: 10

                        SectionText {
                            text: Translation.tr("Network")
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 6

                            WText {
                                text: Translation.tr("Network name (SSID)")
                                font.pixelSize: Looks.font.pixelSize.normal
                                color: Looks.colors.subfg
                            }
                            WTextField {
                                Layout.fillWidth: true
                                placeholderText: "iNiR Hotspot"
                                text: Config.options?.hotspot?.ssid ?? "iNiR Hotspot"
                                onTextEdited: Config.setNestedValue("hotspot.ssid", text)
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 12
                            Layout.rightMargin: 12
                            spacing: 6

                            WText {
                                text: Translation.tr("Password")
                                font.pixelSize: Looks.font.pixelSize.normal
                                color: Looks.colors.subfg
                            }
                            WTextField {
                                Layout.fillWidth: true
                                placeholderText: "inirhotspot"
                                text: Config.options?.hotspot?.password ?? "inirhotspot"
                                echoMode: TextInput.Password
                                onTextEdited: Config.setNestedValue("hotspot.password", text)
                            }
                        }

                        ToggleItem {
                            Layout.fillWidth: true
                            name: Translation.tr("Use 5 GHz band")
                            description: Translation.tr("Requires adapter with AP mode support (802.11a)")
                            iconName: "pulse"
                            checked: (Config.options?.hotspot?.band ?? "bg") === "a"
                            onCheckedChanged: Config.setNestedValue("hotspot.band", checked ? "a" : "bg")
                        }
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {}
    }
}
