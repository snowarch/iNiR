import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.dashboard

ContentPage {
    id: root
    settingsPageIndex: 16
    settingsPageName: Translation.tr("Dashboard")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Not Active")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("The dashboard only applies when using the Material (ii) panel style. Go to Modules → Panel Style to switch.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "space_dashboard"
        title: Translation.tr("General")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Enable dashboard")
                description: Translation.tr("Centered hub with clock, notifications, media, weather and more")
                checked: Config.options?.dashboard?.enable ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.enable", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Show header")
                description: Translation.tr("Uptime chip and quick action buttons at the top")
                checked: Config.options?.dashboard?.showHeader ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.showHeader", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Show power buttons")
                description: Translation.tr("Lock and session buttons in the header")
                enabled: Config.options?.dashboard?.showHeader ?? true
                checked: Config.options?.dashboard?.showPowerButtons ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.showPowerButtons", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Keep loaded in memory")
                description: Translation.tr("Faster opening at the cost of RAM")
                checked: Config.options?.dashboard?.keepLoaded ?? false
                onCheckedChanged: Config.setNestedValue("dashboard.keepLoaded", checked)
            }
            ConfigSpinBox {
                text: Translation.tr("Panel width (% of screen)")
                value: Math.round((Config.options?.dashboard?.widthRatio ?? 0.62) * 100)
                from: 40
                to: 90
                stepSize: 2
                onValueChanged: Config.setNestedValue("dashboard.widthRatio", value / 100)
            }
        }

        ContentSubsection {
            title: Translation.tr("Welcome subtitle")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Custom phrase under the greeting (optional)")
                text: Config.options?.dashboard?.subtitle ?? ""
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("dashboard.subtitle", text)
                    });
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("GitHub username")
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("e.g. octocat")
                text: Config.options?.dashboard?.github?.username ?? ""
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.setNestedValue("dashboard.github.username", text)
                    });
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Powers the “GitHub activity” widget above. Leave empty to disable the contribution graph.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }

        SettingsGroup {
            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                MaterialSymbol {
                    text: "keyboard_command_key"
                    iconSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Toggle with a keybinding running: %1").arg("inir ipc dashboard toggle")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "palette"
        title: Translation.tr("Appearance")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Density")
                ConfigSelectionArray {
                    currentValue: Config.options?.dashboard?.appearance?.density ?? "comfortable"
                    onSelected: newValue => Config.setNestedValue("dashboard.appearance.density", newValue)
                    options: [
                        { displayName: Translation.tr("Comfortable"), icon: "expand", value: "comfortable" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" }
                    ]
                }
            }
            ConfigSpinBox {
                text: Translation.tr("Card opacity (%)")
                value: Math.round((Config.options?.dashboard?.appearance?.cardOpacity ?? 1) * 100)
                from: 30
                to: 100
                stepSize: 5
                onValueChanged: Config.setNestedValue("dashboard.appearance.cardOpacity", value / 100)
            }
            ConfigSwitch {
                text: Translation.tr("Show card titles")
                description: Translation.tr("Icon and name header on each widget card")
                checked: Config.options?.dashboard?.appearance?.showCardTitles ?? true
                onCheckedChanged: Config.setNestedValue("dashboard.appearance.showCardTitles", checked)
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "widgets"
        title: Translation.tr("Widgets & layout")

        SettingsGroup {
            DashLayoutEditor {
                Layout.fillWidth: true
            }
        }
    }
}
