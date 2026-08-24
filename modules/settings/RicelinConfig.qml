import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.pill

/**
 * Ricelin hub: every switchable piece of the Ricelin dialect in one place,
 * each labelled with the area of the shell it affects. Nothing here replaces
 * an original iNiR look — every control flips between the stock style and its
 * Ricelin counterpart, and the same keys stay available on their home pages
 * (Bar, Interface, Services).
 */
ContentPage {
    id: root
    settingsPageIndex: 21
    settingsPageName: Translation.tr("Ricelin")

    readonly property bool pillActive: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"

    /** Optional pill surfaces, data-driven so the list grows in one place. */
    readonly property var surfaceDescriptors: [
        { key: "glance", icon: "today", label: Translation.tr("Today glance"), tip: Translation.tr("Weather, agenda and pending tasks in one face.") },
        { key: "launcher", icon: "apps", label: Translation.tr("App launcher"), tip: Translation.tr("Fuzzy app search with an inline calculator.") },
        { key: "clipboard", icon: "content_paste", label: Translation.tr("Clipboard"), tip: Translation.tr("Searchable clipboard history.") },
        { key: "sysmon", icon: "monitor_heart", label: Translation.tr("System monitor"), tip: Translation.tr("CPU, memory and network dials.") },
        { key: "recorder", icon: "screen_record", label: Translation.tr("Screen recorder"), tip: Translation.tr("Region/screen capture over iNiR's recorder. Also reachable via 'inir pill open recorder'.") }
    ]

    SettingsCardSection {
        expanded: true
        icon: "blur_on"
        title: Translation.tr("Pill bar")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Pill bar style")
                checked: root.pillActive
                onCheckedChanged: {
                    if (checked !== root.pillActive)
                        Config.setNestedValue("bar.appearanceStyle", checked ? "pill" : "classic");
                }
                StyledToolTip {
                    text: Translation.tr("Affects the top bar: replaces it with the morphing centre island. Off returns to the classic bar.")
                }
            }

            SettingsSwitch {
                buttonIcon: "expand_content"
                text: Translation.tr("Bar mode")
                enabled: root.pillActive
                checked: Config.options?.bar?.pill?.barMode ?? false
                onCheckedChanged: Config.setNestedValue("bar.pill.barMode", checked)
                StyledToolTip {
                    text: Translation.tr("Keeps the pill permanently expanded: workspaces, clock and every trigger stay visible without hovering.")
                }
            }

            SettingsSwitch {
                buttonIcon: "notifications"
                text: Translation.tr("Pill toasts")
                enabled: root.pillActive
                checked: Config.options?.bar?.pill?.toasts ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.toasts", checked)
                StyledToolTip {
                    text: Translation.tr("Notifications take over the resting pill. Off hands them back to iNiR's regular notification popups.")
                }
            }

            SettingsSwitch {
                buttonIcon: "page_info"
                text: Translation.tr("Pill OSD")
                enabled: root.pillActive
                checked: Config.options?.bar?.pill?.osd ?? true
                onCheckedChanged: Config.setNestedValue("bar.pill.osd", checked)
                StyledToolTip {
                    text: Translation.tr("Volume, brightness and mic changes flash on the pill. Off hands them back to iNiR's regular on-screen display.")
                }
            }

            SettingsSwitch {
                buttonIcon: "unfold_less"
                text: Translation.tr("Compact notifications and OSD")
                enabled: root.pillActive && ((Config.options?.bar?.pill?.toasts ?? true)
                    || (Config.options?.bar?.pill?.osd ?? true))
                checked: Config.options?.bar?.pill?.compactAnnounces ?? false
                onCheckedChanged: Config.setNestedValue("bar.pill.compactAnnounces", checked)
                StyledToolTip {
                    text: Translation.tr("Keep transient notifications and OSD feedback inside the resting pill instead of expanding into a larger card.")
                }
            }

            ContentSubsection {
                title: Translation.tr("Optional surfaces")

                Repeater {
                    model: root.surfaceDescriptors

                    SettingsSwitch {
                        required property var modelData
                        buttonIcon: modelData.icon
                        text: modelData.label
                        enabled: root.pillActive
                        checked: Config.options?.bar?.pill?.surfaces?.[modelData.key] ?? (modelData.key !== "recorder")
                        onCheckedChanged: Config.setNestedValue("bar.pill.surfaces." + modelData.key, checked)
                        StyledToolTip {
                            text: modelData.tip
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Fine-tuning (scale, gaps, kanji glyphs, clock, hover-row modules) lives in Settings › Bar › Pill options. Islands bar geometry lives in Settings › Bar › Islands options.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "layers"
        title: Translation.tr("Island surfaces")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "dock_to_bottom"
                text: Translation.tr("Island dock")
                checked: (Config.options?.dock?.style ?? "panel") === "island"
                onCheckedChanged: {
                    const cur = Config.options?.dock?.style ?? "panel";
                    if (checked && cur !== "island")
                        Config.setNestedValue("dock.style", "island");
                    else if (!checked && cur === "island")
                        Config.setNestedValue("dock.style", "panel");
                }
                StyledToolTip {
                    text: Translation.tr("Affects the dock: gradient card with lit top edge and filament window indicators. Off returns to the panel dock; other dock styles stay available in Interface › Dock.")
                }
            }

            SettingsSwitch {
                buttonIcon: "view_sidebar"
                text: Translation.tr("Island sidebars")
                checked: (Config.options?.sidebar?.style ?? "panel") === "island"
                onCheckedChanged: Config.setNestedValue("sidebar.style", checked ? "island" : "panel")
                StyledToolTip {
                    text: Translation.tr("Affects both sidebars: their panels wear the gradient island card.")
                }
            }

            SettingsSwitch {
                buttonIcon: "search"
                text: Translation.tr("Island search")
                checked: (Config.options?.search?.style ?? "default") === "island"
                onCheckedChanged: Config.setNestedValue("search.style", checked ? "island" : "default")
                StyledToolTip {
                    text: Translation.tr("Affects the search overlay: island card face instead of the stock surface.")
                }
            }

            SettingsSwitch {
                buttonIcon: "tune"
                text: Translation.tr("Island control panel")
                checked: (Config.options?.controlPanel?.style ?? "panel") === "island"
                onCheckedChanged: Config.setNestedValue("controlPanel.style", checked ? "island" : "panel")
                StyledToolTip {
                    text: Translation.tr("Every control panel section wears the gradient island card with glass.")
                }
            }

            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Island desktop widgets")
                checked: (Config.options?.background?.widgets?.style ?? "panel") === "island"
                onCheckedChanged: Config.setNestedValue("background.widgets.style", checked ? "island" : "panel")
                StyledToolTip {
                    text: Translation.tr("Every desktop widget plate becomes an island card; glass follows the shared Island skin settings.")
                }
            }

            SettingsSwitch {
                buttonIcon: "dock_to_right"
                text: Translation.tr("Island workspace strip")
                checked: (Config.options?.workspaceStrip?.style ?? "auto") === "island"
                onCheckedChanged: Config.setNestedValue("workspaceStrip.style", checked ? "island" : "auto")
                StyledToolTip {
                    text: Translation.tr("Forces the strip's flyouts into the island dialect. Off returns to Follow bar (island only while the pill bar is active).")
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "tune"
        title: Translation.tr("Island skin")

        SettingsGroup {
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Corner radius (px)")
                    value: Config.options?.appearance?.island?.radius ?? 18
                    from: 4
                    to: 32
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("appearance.island.radius", value)
                }
                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Fill opacity (%)")
                    value: Math.round((Config.options?.appearance?.island?.opacity ?? 1) * 100)
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("appearance.island.opacity", value / 100)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "ev_shadow"
                    text: Translation.tr("Drop shadow")
                    checked: Config.options?.appearance?.island?.shadow ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.island.shadow", checked)
                }
                SettingsSwitch {
                    buttonIcon: "flare"
                    text: Translation.tr("Lit top edge")
                    checked: Config.options?.appearance?.island?.sheen ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.island.sheen", checked)
                    StyledToolTip {
                        text: Translation.tr("The 1px highlight along the card's top edge.")
                    }
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Glass blur")
                    checked: Config.options?.appearance?.island?.glass ?? true
                    onCheckedChanged: Config.setNestedValue("appearance.island.glass", checked)
                    StyledToolTip {
                        text: Translation.tr("Blurred wallpaper behind translucent islands, so lowering the fill opacity reads as frosted glass. Needs fill opacity below 100% and visual effects enabled.")
                    }
                }
                ConfigSpinBox {
                    icon: "lens_blur"
                    text: Translation.tr("Blur strength (%)")
                    value: Math.round((Config.options?.appearance?.island?.glassBlur ?? 1) * 100)
                    from: 20
                    to: 100
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("appearance.island.glassBlur", value / 100)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("One shared skin: these apply to every island surface at once — the pill bar itself, bar islands, dock, sidebars and search. The pill keeps its own fill opacity in Bar › Pill options, which multiplies with this one.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        id: glyphsSection
        expanded: false
        icon: "jp:字"
        title: Translation.tr("Glyphs")

        readonly property var glyphDescriptors: [
            { key: "clock", label: Translation.tr("Clock (rest face)") },
            { key: "launcher", label: Translation.tr("Launcher") },
            { key: "glance", label: Translation.tr("Today glance") },
            { key: "clipboard", label: Translation.tr("Clipboard") },
            { key: "clipboardSearch", label: Translation.tr("Clipboard search") },
            { key: "media", label: Translation.tr("Media (playing)") },
            { key: "mediaPaused", label: Translation.tr("Media (paused)") },
            { key: "mixer", label: Translation.tr("Mixer") },
            { key: "calendar", label: Translation.tr("Calendar") },
            { key: "battery", label: Translation.tr("Battery") },
            { key: "power", label: Translation.tr("Power") },
            { key: "sysmon", label: Translation.tr("System monitor") },
            { key: "recorder", label: Translation.tr("Recorder") },
            { key: "link", label: Translation.tr("Link / network") },
            { key: "workspaces", label: Translation.tr("Workspace strip") },
            { key: "notify", label: Translation.tr("Notifications") },
            { key: "dnd", label: Translation.tr("Do not disturb") },
            { key: "clear", label: Translation.tr("Clear notifications") }
        ]

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Every Japanese character the pill uses, swappable per surface — kanji, kana, an emoji, your initial. Empty returns the stock glyph. The kanji ↔ icon master switch lives in Bar › Pill options.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: glyphsSection.glyphDescriptors

                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10

                    StyledText {
                        Layout.preferredWidth: 170
                        text: parent.modelData.label
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: PillTheme.glyphDefaults[parent.modelData.key] ?? ""
                        text: Config.options?.bar?.pill?.glyphs?.[parent.modelData.key] ?? ""
                        onTextChanged: Config.setNestedValue("bar.pill.glyphs." + parent.modelData.key, text)
                    }
                }
            }
        }
    }
}
