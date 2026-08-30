import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.pill

/**
 * Ricelin owns its detailed configuration here. Bar keeps only the appearance
 * selector; once Ricelin is chosen, Pill behavior and Island material live in
 * one page instead of being duplicated across unrelated settings pages.
 */
ContentPage {
    id: root
    settingsPageIndex: 21
    settingsPageName: Translation.tr("Ricelin")

    readonly property bool pillActive: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"


    SettingsCardSection {
        expanded: true
        icon: "blur_on"
        title: Translation.tr("Pill bar")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Use Pill bar")
                checked: root.pillActive
                onCheckedChanged: {
                    if (checked !== root.pillActive)
                        Config.setNestedValue("bar.appearanceStyle", checked ? "pill" : "classic");
                }
                StyledToolTip {
                    text: Translation.tr("Replaces the standard top bar with Ricelin's morphing Pill surface.")
                }
            }

            PillOptionsEditor {
                Layout.fillWidth: true
                visible: root.pillActive
            }

            SettingsNote {
                visible: !root.pillActive
                icon: "info"
                text: Translation.tr("Enable Pill to configure its navigation, scale, surfaces and hover-row modules here.")
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "layers"
        title: Translation.tr("Island surfaces")

        SettingsGroup {
            RicelinIslandEditor {
                Layout.fillWidth: true
            }
        }
    }
}
