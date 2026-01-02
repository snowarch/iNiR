import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    forceWidth: true
    settingsPageIndex: 5
    settingsPageName: Translation.tr("Interface")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        expanded: false
        icon: "point_scan"
        title: Translation.tr("Crosshair overlay")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Crosshair code (in Valorant's format)")
                text: Config.options?.crosshair?.code ?? ""
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.crosshair.code = text;
                }
            }

            RowLayout {
                StyledText {
                    Layout.leftMargin: 10
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    text: Translation.tr("Press Super+G to toggle appearance")
                }
                Item {
                    Layout.fillWidth: true
                }
                RippleButtonWithIcon {
                    id: editorButton
                    buttonRadius: Appearance.rounding.full
                    materialIcon: "open_in_new"
                    mainText: Translation.tr("Open editor")
                    onClicked: {
                        Qt.openUrlExternally(`https://www.vcrdb.net/builder?c=${Config.options?.crosshair?.code ?? ""}`);
                    }
                    StyledToolTip {
                        text: "www.vcrdb.net"
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "layers"
        title: Translation.tr("Overlay widgets")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Background & dim")

                SettingsSwitch {
                    buttonIcon: "water"
                    text: Translation.tr("Darken screen behind overlay")
                    checked: Config.options.overlay.darkenScreen
                    onCheckedChanged: {
                        Config.options.overlay.darkenScreen = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Add a dark scrim behind overlay panels for better visibility")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay scrim dim (%)")
                    value: Config.options.overlay.scrimDim
                    from: 0
                    to: 100
                    stepSize: 5
                    enabled: Config.options.overlay.darkenScreen
                    onValueChanged: {
                        Config.options.overlay.scrimDim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("How dark the background scrim should be")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay background opacity (%)")
                    value: Math.round((Config.options.overlay.backgroundOpacity ?? 0.9) * 100)
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.overlay.backgroundOpacity = value / 100;
                    }
                    StyledToolTip {
                        text: Translation.tr("Opacity of the overlay panel background")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Animations")

                SettingsSwitch {
                    buttonIcon: "movie"
                    text: Translation.tr("Enable opening zoom animation")
                    checked: Config.options.overlay.openingZoomAnimation
                    onCheckedChanged: {
                        Config.options.overlay.openingZoomAnimation = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Animate overlay panels with a zoom effect when opening")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Overlay animation duration (ms)")
                    value: Config.options.overlay.animationDurationMs ?? 180
                    from: 0
                    to: 1000
                    stepSize: 20
                    onValueChanged: {
                        Config.options.overlay.animationDurationMs = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Duration of overlay open/close animations")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Background dim animation (ms)")
                    value: Config.options.overlay.scrimAnimationDurationMs ?? 140
                    from: 0
                    to: 1000
                    stepSize: 20
                    onValueChanged: {
                        Config.options.overlay.scrimAnimationDurationMs = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Duration of the background scrim fade animation")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "forum"
        title: Translation.tr("Overlay: Discord")

        SettingsGroup {
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Discord launch command (e.g., discord, vesktop, webcord)")
                text: Config.options.apps.discord
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.apps.discord = text;
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "keyboard_tab"
        title: Translation.tr("Alt-Tab switcher (Material ii)")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Tint app icons")
                checked: Config.options?.altSwitcher?.monochromeIcons ?? false
                onCheckedChanged: Config.setNestedValue("altSwitcher.monochromeIcons", checked)
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to app icons in the switcher")
                }
            }

            SettingsSwitch {
                buttonIcon: "movie"
                text: Translation.tr("Enable slide animation")
                checked: Config.options?.altSwitcher?.enableAnimation ?? true
                onCheckedChanged: Config.setNestedValue("altSwitcher.enableAnimation", checked)
                StyledToolTip {
                    text: Translation.tr("Animate window selection with a slide effect")
                }
            }

            ConfigSpinBox {
                icon: "speed"
                text: Translation.tr("Animation duration (ms)")
                value: Config.options?.altSwitcher?.animationDurationMs ?? 200
                from: 0
                to: 1000
                stepSize: 25
                onValueChanged: Config.setNestedValue("altSwitcher.animationDurationMs", value)
                StyledToolTip {
                    text: Translation.tr("Duration of the slide animation between windows")
                }
            }

            SettingsSwitch {
                buttonIcon: "history"
                text: Translation.tr("Most recently used first")
                checked: Config.options?.altSwitcher?.useMostRecentFirst ?? true
                onCheckedChanged: Config.setNestedValue("altSwitcher.useMostRecentFirst", checked)
                StyledToolTip {
                    text: Translation.tr("Order windows by most recently focused instead of position")
                }
            }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Background opacity (%)")
                value: Math.round((Config.options?.altSwitcher?.backgroundOpacity ?? 0.9) * 100)
                from: 10
                to: 100
                stepSize: 5
                onValueChanged: Config.setNestedValue("altSwitcher.backgroundOpacity", value / 100)
                StyledToolTip {
                    text: Translation.tr("Opacity of the switcher panel background")
                }
            }

            ConfigSpinBox {
                icon: "blur_on"
                text: Translation.tr("Blur amount (%)")
                value: Math.round((Config.options?.altSwitcher?.blurAmount ?? 0.4) * 100)
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: Config.setNestedValue("altSwitcher.blurAmount", value / 100)
                StyledToolTip {
                    text: Translation.tr("Amount of blur applied to the switcher background")
                }
            }

            ConfigSpinBox {
                icon: "opacity"
                text: Translation.tr("Scrim dim (%)")
                value: Config.options?.altSwitcher?.scrimDim ?? 35
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: Config.setNestedValue("altSwitcher.scrimDim", value)
                StyledToolTip {
                    text: Translation.tr("How dark the screen behind the switcher should be")
                }
            }

            ConfigSpinBox {
                icon: "hourglass_top"
                text: Translation.tr("Auto-hide delay after selection (ms)")
                value: Config.options?.altSwitcher?.autoHideDelayMs ?? 500
                from: 50
                to: 2000
                stepSize: 50
                onValueChanged: Config.setNestedValue("altSwitcher.autoHideDelayMs", value)
                StyledToolTip {
                    text: Translation.tr("How long to wait before hiding the switcher after releasing Alt")
                }
            }

            SettingsSwitch {
                buttonIcon: "overview_key"
                text: Translation.tr("Show Niri overview while switching")
                checked: Config.options?.altSwitcher?.showOverviewWhileSwitching ?? false
                onCheckedChanged: Config.setNestedValue("altSwitcher.showOverviewWhileSwitching", checked)
                StyledToolTip {
                    text: Translation.tr("Open Niri's native overview alongside the window switcher")
                }
            }

            ConfigSelectionArray {
                options: [
                    { displayName: Translation.tr("Default (sidebar)"), icon: "side_navigation", value: "default" },
                    { displayName: Translation.tr("List (centered)"), icon: "list", value: "list" }
                ]
                currentValue: Config.options?.altSwitcher?.preset ?? "default"
                onSelected: (newValue) => Config.options.altSwitcher.preset = newValue
            }

            ContentSubsection {
                title: Translation.tr("Layout & alignment")

                SettingsSwitch {
                    enabled: Config.options?.altSwitcher?.preset !== "list"
                    buttonIcon: "view_compact"
                    text: Translation.tr("Compact horizontal style (icons only)")
                    checked: Config.options?.altSwitcher?.compactStyle ?? false
                    onCheckedChanged: Config.setNestedValue("altSwitcher.compactStyle", checked)
                    StyledToolTip {
                        text: Translation.tr("Show only app icons in a horizontal row, similar to macOS Spotlight")
                    }
                }

                ConfigSelectionArray {
                    enabled: !Config.options?.altSwitcher?.compactStyle && Config.options?.altSwitcher?.preset !== "list"
                    currentValue: Config.options?.altSwitcher?.panelAlignment ?? "right"
                    onSelected: newValue => Config.setNestedValue("altSwitcher.panelAlignment", newValue)
                    options: [
                        { displayName: Translation.tr("Align to right edge"), icon: "align_horizontal_right", value: "right" },
                        { displayName: Translation.tr("Center on screen"), icon: "align_horizontal_center", value: "center" }
                    ]
                }

                SettingsSwitch {
                    enabled: !Config.options?.altSwitcher?.compactStyle && Config.options?.altSwitcher?.preset !== "list"
                    buttonIcon: "styler"
                    text: Translation.tr("Use Material 3 card layout")
                    checked: Config.options?.altSwitcher?.useM3Layout ?? false
                    onCheckedChanged: Config.setNestedValue("altSwitcher.useM3Layout", checked)
                    StyledToolTip {
                        text: Translation.tr("Use Material Design 3 style for the switching panel")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "call_to_action"
        title: Translation.tr("Dock")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.dock.enable
                onCheckedChanged: {
                    Config.options.dock.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show the macOS-style dock at the bottom of the screen")
                }
            }

            ConfigRow {
                uniform: true
                ContentSubsection {
                    title: Translation.tr("Dock position")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.position ?? "bottom"
                        onSelected: newValue => {
                            Config.setNestedValue('dock.position', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: "top" },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                        ]
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Reveal behavior")

                    ConfigSelectionArray {
                        currentValue: Config.options?.dock?.hoverToReveal ?? true
                        onSelected: newValue => {
                            Config.setNestedValue('dock.hoverToReveal', newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Hover"), icon: "highlight_mouse_cursor", value: true },
                            { displayName: Translation.tr("Empty workspace"), icon: "desktop_windows", value: false }
                        ]
                    }
                    SettingsSwitch {
                        buttonIcon: "desktop_windows"
                        text: Translation.tr("Show on desktop")
                        checked: Config.options?.dock?.showOnDesktop ?? true
                        onCheckedChanged: Config.setNestedValue('dock.showOnDesktop', checked)
                        StyledToolTip {
                            text: Translation.tr("Show dock when no window is focused")
                        }
                    }
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "keep"
                    text: Translation.tr("Pinned on startup")
                    checked: Config.options.dock.pinnedOnStartup
                    onCheckedChanged: {
                        Config.options.dock.pinnedOnStartup = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Keep dock visible when the shell starts")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Tint app icons")
                    checked: Config.options.dock.monochromeIcons
                    onCheckedChanged: {
                        Config.options.dock.monochromeIcons = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply accent color tint to dock app icons")
                    }
                }
            }
            SettingsSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Show dock background")
                checked: Config.options.dock.showBackground
                onCheckedChanged: Config.options.dock.showBackground = checked
                StyledToolTip {
                    text: Translation.tr("Show a background behind the dock")
                }
            }

            ContentSubsection {
                title: Translation.tr("Appearance")

                SettingsSwitch {
                    buttonIcon: "branding_watermark"
                    text: Translation.tr("Use Card style")
                    checked: Config.options.dock?.cardStyle ?? false
                    onCheckedChanged: {
                        Config.options.dock.cardStyle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Use the new Card style (lighter background, specific rounding) generic to settings")
                    }
                }

                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Dock height (px)")
                    value: Config.options.dock.height ?? 60
                    from: 40
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.dock.height = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Height of the dock container")
                    }
                }

                ConfigSpinBox {
                    icon: "aspect_ratio"
                    text: Translation.tr("Icon size (px)")
                    value: Config.options.dock.iconSize ?? 35
                    from: 20
                    to: 60
                    stepSize: 5
                    onValueChanged: {
                        Config.options.dock.iconSize = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of application icons in the dock")
                    }
                }

                ConfigSpinBox {
                    icon: {
                        const pos = Config.options?.dock?.position ?? "bottom"
                        switch (pos) {
                            case "top": return "vertical_align_top"
                            case "left": return "align_horizontal_left"
                            case "right": return "align_horizontal_right"
                            default: return "vertical_align_bottom"
                        }
                    }
                    text: Translation.tr("Hover reveal region size (px)")
                    value: Config.options.dock.hoverRegionHeight ?? 2
                    from: 1
                    to: 20
                    stepSize: 1
                    enabled: Config.options.dock.hoverToReveal
                    onValueChanged: {
                        Config.options.dock.hoverRegionHeight = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Size of the invisible area at screen edge that triggers dock reveal")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Window indicators")

                SettingsSwitch {
                    buttonIcon: "my_location"
                    text: Translation.tr("Smart indicator (highlight focused window)")
                    checked: Config.options.dock.smartIndicator !== false
                    onCheckedChanged: {
                        Config.options.dock.smartIndicator = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("When multiple windows of the same app are open, highlight which one is focused")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "more_horiz"
                    text: Translation.tr("Show dots for inactive apps")
                    checked: Config.options.dock.showAllWindowDots !== false
                    onCheckedChanged: {
                        Config.options.dock.showAllWindowDots = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a dot per window even for apps that aren't currently focused")
                    }
                }

                ConfigSpinBox {
                    icon: "filter_5"
                    text: Translation.tr("Maximum indicator dots")
                    value: Config.options.dock.maxIndicatorDots ?? 5
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.options.dock.maxIndicatorDots = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Limit the number of open window dots shown below an app icon")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "lock"
        title: Translation.tr("Lock screen")

        SettingsGroup {
            SettingsSwitch {
                visible: CompositorService.isHyprland
                buttonIcon: "water_drop"
                text: Translation.tr('Use Hyprlock (instead of Quickshell)')
                checked: Config.options.lock.useHyprlock
                onCheckedChanged: {
                    Config.options.lock.useHyprlock = checked;
                }
                StyledToolTip {
                    text: Translation.tr("If you want to somehow use fingerprint unlock...")
                }
            }

            SettingsSwitch {
                buttonIcon: "account_circle"
                text: Translation.tr('Launch on startup')
                checked: Config.options.lock.launchOnStartup
                onCheckedChanged: {
                    Config.options.lock.launchOnStartup = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable this if you want to use Quickshell as your lock screen provider")
                }
            }

            ContentSubsection {
                title: Translation.tr("Security")

                SettingsSwitch {
                    buttonIcon: "settings_power"
                    text: Translation.tr('Require password to power off/restart')
                    checked: Config.options.lock.security.requirePasswordToPower
                    onCheckedChanged: {
                        Config.options.lock.security.requirePasswordToPower = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Remember that on most devices one can always hold the power button to force shutdown\nThis only makes it a tiny bit harder for accidents to happen")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "key_vertical"
                    text: Translation.tr('Also unlock keyring')
                    checked: Config.options.lock.security.unlockKeyring
                    onCheckedChanged: {
                        Config.options.lock.security.unlockKeyring = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("This is usually safe and needed for your browser and AI sidebar anyway\nMostly useful for those who use lock on startup instead of a display manager that does it (GDM, SDDM, etc.)")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style: general")

                SettingsSwitch {
                    buttonIcon: "center_focus_weak"
                    text: Translation.tr('Center clock')
                    checked: Config.options.lock.centerClock
                    onCheckedChanged: {
                        Config.options.lock.centerClock = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Align the lock screen clock to the center instead of following layout rules")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "info"
                    text: Translation.tr('Show "Locked" text')
                    checked: Config.options.lock.showLockedText
                    onCheckedChanged: {
                        Config.options.lock.showLockedText = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Display a 'Locked' label on the lock screen")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "shapes"
                    text: Translation.tr('Use varying shapes for password characters')
                    checked: Config.options.lock.materialShapeChars
                    onCheckedChanged: {
                        Config.options.lock.materialShapeChars = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show different geometric shapes instead of bullets for password input")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Style: Blurred")

                SettingsSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr('Enable blur')
                    checked: Config.options.lock.blur.enable
                    onCheckedChanged: {
                        Config.options.lock.blur.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to the lock screen background")
                    }
                }

                ConfigSpinBox {
                    icon: "blur_linear"
                    text: Translation.tr("Blur radius")
                    value: Config.options?.lock?.blur?.radius ?? 100
                    from: 0
                    to: 200
                    stepSize: 10
                    onValueChanged: {
                        Config.setNestedValue("lock.blur.radius", value);
                    }
                    StyledToolTip {
                        text: Translation.tr("Intensity of the blur effect")
                    }
                }

                ConfigSpinBox {
                    icon: "loupe"
                    text: Translation.tr("Extra wallpaper zoom (%)")
                    value: Config.options.lock.blur.extraZoom * 100
                    from: 1
                    to: 150
                    stepSize: 2
                    onValueChanged: {
                        Config.options.lock.blur.extraZoom = value / 100;
                    }
                    StyledToolTip {
                        text: Translation.tr("Zoom level for the background wallpaper when blur is enabled")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "notifications"
        title: Translation.tr("Notifications")

        SettingsGroup {
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Timeout (ms)")
                value: Config.options?.notifications?.timeoutNormal ?? 7000
                from: 1000
                to: 30000
                stepSize: 500
                onValueChanged: {
                    Config.setNestedValue("notifications.timeoutNormal", value)
                }
                StyledToolTip {
                    text: Translation.tr("Duration in milliseconds before a notification automatically closes")
                }
            }

            ConfigSwitch {
                buttonIcon: "pinch"
                text: Translation.tr("Scale on hover")
                checked: Config.options?.notifications?.scaleOnHover ?? false
                onCheckedChanged: {
                    Config.setNestedValue("notifications.scaleOnHover", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Slightly enlarge notifications when the mouse hovers over them")
                }
            }
            ConfigSpinBox {
                icon: "vertical_align_top"
                text: Translation.tr("Margin (px)")
                value: Config.options?.notifications?.edgeMargin ?? 4
                from: 0
                to: 100
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("notifications.edgeMargin", value)
                }
                StyledToolTip {
                    text: Translation.tr("Spacing between notifications and the screen edge/anchor")
                }
            }

            ContentSubsection {
                title: Translation.tr("Anchor")

                ConfigSelectionArray {
                    currentValue: Config.options?.notifications?.position ?? "topRight"
                    onSelected: newValue => {
                        Config.setNestedValue("notifications.position", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Top Right"), icon: "north_east", value: "topRight" },
                        { displayName: Translation.tr("Top Left"), icon: "north_west", value: "topLeft" },
                        { displayName: Translation.tr("Bottom Right"), icon: "south_east", value: "bottomRight" },
                        { displayName: Translation.tr("Bottom Left"), icon: "south_west", value: "bottomLeft" }
                    ]
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "screenshot_frame_2"
        title: Translation.tr("Region selector (screen snipping/Google Lens)")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Hint target regions")
                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "select_window"
                        text: Translation.tr('Windows')
                        checked: Config.options.regionSelector.targetRegions.windows
                        onCheckedChanged: {
                            Config.options.regionSelector.targetRegions.windows = checked;
                        }
                        StyledToolTip {
                            text: Translation.tr("Highlight open windows as selectable regions")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "right_panel_open"
                        text: Translation.tr('Layers')
                        checked: Config.options.regionSelector.targetRegions.layers
                        onCheckedChanged: {
                            Config.options.regionSelector.targetRegions.layers = checked;
                        }
                        StyledToolTip {
                            text: Translation.tr("Highlight UI layers as selectable regions")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "nearby"
                        text: Translation.tr('Content')
                        checked: Config.options.regionSelector.targetRegions.content
                        onCheckedChanged: {
                            Config.options.regionSelector.targetRegions.content = checked;
                        }
                        StyledToolTip {
                            text: Translation.tr("Could be images or parts of the screen that have some containment.\nMight not always be accurate.\nThis is done with an image processing algorithm run locally and no AI is used.")
                        }
                    }
                }
            }
            
            ContentSubsection {
                title: Translation.tr("Google Lens")
                
                ConfigSelectionArray {
                    currentValue: Config.options.search.imageSearch.useCircleSelection ? "circle" : "rectangles"
                    onSelected: newValue => {
                        Config.options.search.imageSearch.useCircleSelection = (newValue === "circle");
                    }
                    options: [
                        { icon: "activity_zone", value: "rectangles", displayName: Translation.tr("Rectangular selection") },
                        { icon: "gesture", value: "circle", displayName: Translation.tr("Circle to Search") }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Element appearance")
                
                ConfigSpinBox {
                    icon: "border_style"
                    text: Translation.tr("Border size (px)")
                    value: Config.options.region.borderSize
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        Config.options.region.borderSize = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Thickness of the selection region border")
                    }
                }
                ConfigSpinBox {
                    icon: "format_size"
                    text: Translation.tr("Numbers size (px)")
                    value: Config.options.region.numSize
                    from: 10
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.region.numSize = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Font size of the region index numbers")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Rectangular selection")

                SettingsSwitch {
                    buttonIcon: "point_scan"
                    text: Translation.tr("Show aim lines")
                    checked: Config.options.regionSelector.rect.showAimLines
                    onCheckedChanged: {
                        Config.options.regionSelector.rect.showAimLines = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show crosshair lines when selecting a region")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Circle selection")
                
                ConfigSpinBox {
                    icon: "eraser_size_3"
                    text: Translation.tr("Stroke width")
                    value: Config.options.regionSelector.circle.strokeWidth
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.regionSelector.circle.strokeWidth = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Thickness of the circle selection stroke")
                    }
                }

                ConfigSpinBox {
                    icon: "screenshot_frame_2"
                    text: Translation.tr("Padding")
                    value: Config.options.regionSelector.circle.padding
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.regionSelector.circle.padding = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Padding around the selected circle region")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "side_navigation"
        title: Translation.tr("Sidebars")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Style")
                SettingsSwitch {
                    buttonIcon: "branding_watermark"
                    text: Translation.tr("Use Card style")
                    checked: Config.options.sidebar?.cardStyle ?? false
                    onCheckedChanged: {
                        Config.options.sidebar.cardStyle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply rounded card styling to sidebars")
                    }
                }
            }
            SettingsSwitch {
                buttonIcon: "memory"
                text: Translation.tr('Keep right sidebar loaded')
                checked: Config.options.sidebar.keepRightSidebarLoaded
                onCheckedChanged: {
                    Config.options.sidebar.keepRightSidebarLoaded = checked;
                }
                StyledToolTip {
                    text: Translation.tr("When enabled keeps the content of the right sidebar loaded to reduce the delay when opening,\nat the cost of around 15MB of consistent RAM usage. Delay significance depends on your system's performance.\nUsing a custom kernel like linux-cachyos might help")
                }
            }

            ContentSubsection {
                title: Translation.tr("Left sidebar tabs")
                tooltip: Translation.tr("Choose which tabs appear in the left sidebar")

                SettingsSwitch {
                    buttonIcon: "widgets"
                    text: Translation.tr("Widgets")
                    checked: Config.options.sidebar?.widgets?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Dashboard with clock, weather, media controls and quick actions")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "neurology"
                    text: Translation.tr("AI Chat")
                    readonly property int currentAiPolicy: Config.options?.policies?.ai ?? 0
                    checked: currentAiPolicy !== 0
                    onCheckedChanged: {
                        // Preserve "Local only" (2) if it was set, otherwise use "Yes" (1)
                        const newValue = checked ? (currentAiPolicy === 2 ? 2 : 1) : 0
                        Config.setNestedValue("policies.ai", newValue)
                    }
                    StyledToolTip {
                        text: Translation.tr("Chat with AI assistants (OpenAI, Gemini, local models)")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "translate"
                    text: Translation.tr("Translator")
                    checked: Config.options.sidebar?.translator?.enable ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.translator.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Translate text between languages")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "bookmark_heart"
                    text: Translation.tr("Anime")
                    readonly property int currentWeebPolicy: Config.options?.policies?.weeb ?? 0
                    checked: currentWeebPolicy !== 0
                    onCheckedChanged: {
                        // Preserve "Closet" (2) if it was set, otherwise use "Yes" (1)
                        const newValue = checked ? (currentWeebPolicy === 2 ? 2 : 1) : 0
                        Config.setNestedValue("policies.weeb", newValue)
                    }
                    StyledToolTip {
                        text: Translation.tr("Browse anime artwork from booru sites")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "image"
                    text: Translation.tr("Wallhaven")
                    checked: Config.options.sidebar?.wallhaven?.enable ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.wallhaven.enable", checked)
                    StyledToolTip {
                        text: Translation.tr("Browse and download wallpapers from Wallhaven")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Wallhaven")
                visible: Config.options.sidebar?.wallhaven?.enable ?? true

                ConfigSpinBox {
                    icon: "format_list_numbered"
                    text: Translation.tr("Results per page")
                    value: Config.options.sidebar?.wallhaven?.limit ?? 24
                    from: 12
                    to: 72
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("sidebar.wallhaven.limit", value)
                    StyledToolTip {
                        text: Translation.tr("Number of wallpapers to fetch per request")
                    }
                }

                ConfigRow {
                    MaterialSymbol {
                        text: "key"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("API key")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    MaterialTextField {
                        Layout.preferredWidth: 180
                        placeholderText: "••••••"
                        text: Config.options.sidebar?.wallhaven?.apiKey ?? ""
                        echoMode: TextInput.Password
                        onTextChanged: Config.setNestedValue("sidebar.wallhaven.apiKey", text)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Quick toggles")
                
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.sidebar.quickToggles.style
                    onSelected: newValue => {
                        Config.options.sidebar.quickToggles.style = newValue;
                    }
                    options: [
                        { displayName: Translation.tr("Classic"), icon: "password_2", value: "classic" },
                        { displayName: Translation.tr("Android"), icon: "action_key", value: "android" }
                    ]
                }

                ConfigSpinBox {
                    enabled: Config.options.sidebar.quickToggles.style === "android"
                    icon: "splitscreen_left"
                    text: Translation.tr("Columns")
                    value: Config.options.sidebar.quickToggles.android.columns
                    from: 1
                    to: 8
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.quickToggles.android.columns = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of columns for the Android-style quick settings grid")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Sliders")

                SettingsSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.quickSliders.enable
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show volume/brightness/mic sliders in the sidebar")
                    }
                }
                
                SettingsSwitch {
                    buttonIcon: "brightness_6"
                    text: Translation.tr("Brightness")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showBrightness
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showBrightness = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show brightness slider")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "volume_up"
                    text: Translation.tr("Volume")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showVolume
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showVolume = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show volume slider")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Microphone")
                    enabled: Config.options.sidebar.quickSliders.enable
                    checked: Config.options.sidebar.quickSliders.showMic
                    onCheckedChanged: {
                        Config.options.sidebar.quickSliders.showMic = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show microphone input level slider")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Corner open")
                tooltip: Translation.tr("Allows you to open sidebars by clicking or hovering screen corners regardless of bar position")
                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "check"
                        text: Translation.tr("Enable")
                        checked: Config.options.sidebar.cornerOpen.enable
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.enable = checked;
                        }
                        StyledToolTip {
                            text: Translation.tr("Allow opening sidebars by interacting with screen corners")
                        }
                    }
                }
                SettingsSwitch {
                    buttonIcon: "highlight_mouse_cursor"
                    text: Translation.tr("Hover to trigger")
                    checked: Config.options.sidebar.cornerOpen.clickless
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.clickless = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("When this is off you'll have to click")
                    }
                }
                ConfigRow {
                    SettingsSwitch {
                        enabled: !Config.options.sidebar.cornerOpen.clickless
                        text: Translation.tr("Force hover open at absolute corner")
                        checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked;
                        }

                        StyledToolTip {
                            text: Translation.tr("When the previous option is off and this is on,\nyou can still hover the corner's end to open sidebar,\nand the remaining area can be used for volume/brightness scroll")
                        }
                    }
                    ConfigSpinBox {
                        icon: "arrow_cool_down"
                        text: Translation.tr("with vertical offset")
                        value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                        from: 0
                        to: 20
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Why this is cool:\nFor non-0 values, it won't trigger when you reach the\nscreen corner along the horizontal edge, but it will when\nyou do along the vertical edge")
                        }
                    }
                }
                
                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "vertical_align_bottom"
                        text: Translation.tr("Place at bottom")
                        checked: Config.options.sidebar.cornerOpen.bottom
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.bottom = checked;
                        }

                        StyledToolTip {
                            text: Translation.tr("Place the corners to trigger at the bottom")
                        }
                    }
                    SettingsSwitch {
                        buttonIcon: "unfold_more_double"
                        text: Translation.tr("Value scroll")
                        checked: Config.options.sidebar.cornerOpen.valueScroll
                        onCheckedChanged: {
                            Config.options.sidebar.cornerOpen.valueScroll = checked;
                        }

                        StyledToolTip {
                            text: Translation.tr("Brightness and volume")
                        }
                    }
                }
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Visualize region")
                    checked: Config.options.sidebar.cornerOpen.visualize
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.visualize = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a colored overlay indicating the corner trigger areas (debug)")
                    }
                }
                ConfigRow {
                    ConfigSpinBox {
                        icon: "arrow_range"
                        text: Translation.tr("Region width")
                        value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.cornerRegionWidth = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Horizontal size of the active corner area")
                        }
                    }
                    ConfigSpinBox {
                        icon: "height"
                        text: Translation.tr("Region height")
                        value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                        from: 1
                        to: 300
                        stepSize: 1
                        onValueChanged: {
                            Config.options.sidebar.cornerOpen.cornerRegionHeight = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Vertical size of the active corner area")
                        }
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "widgets"
        title: Translation.tr("Widgets")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Visibility")
                tooltip: Translation.tr("Toggle which widgets appear in the sidebar")

                SettingsSwitch {
                    buttonIcon: "music_note"
                    text: Translation.tr("Media player")
                    checked: Config.options?.sidebar?.widgets?.media ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.media", checked)
                }

                SettingsSwitch {
                    buttonIcon: "calendar_today"
                    text: Translation.tr("Week strip")
                    checked: Config.options?.sidebar?.widgets?.week ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.week", checked)
                }

                SettingsSwitch {
                    buttonIcon: "partly_cloudy_day"
                    text: Translation.tr("Context card (Weather/Timer)")
                    checked: Config.options?.sidebar?.widgets?.context ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.context", checked)
                }

                SettingsSwitch {
                    buttonIcon: "cloud"
                    text: Translation.tr("Show weather in context card")
                    checked: Config.options?.sidebar?.widgets?.contextShowWeather ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.contextShowWeather", checked)
                    enabled: Config.options?.sidebar?.widgets?.context ?? true
                }

                SettingsSwitch {
                    buttonIcon: "edit_note"
                    text: Translation.tr("Quick note")
                    checked: Config.options?.sidebar?.widgets?.note ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.note", checked)
                }

                SettingsSwitch {
                    buttonIcon: "apps"
                    text: Translation.tr("Quick launch")
                    checked: Config.options?.sidebar?.widgets?.launch ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.launch", checked)
                }

                // Quick launch apps editor
                ColumnLayout {
                    id: quickLaunchEditor
                    Layout.fillWidth: true
                    Layout.leftMargin: 40
                    Layout.topMargin: 4
                    spacing: 4
                    visible: Config.options?.sidebar?.widgets?.launch ?? true

                    property var shortcuts: Config.options?.sidebar?.widgets?.quickLaunch ?? [
                        { icon: "folder", name: "Files", cmd: "/usr/bin/nautilus" },
                        { icon: "terminal", name: "Terminal", cmd: "/usr/bin/kitty" },
                        { icon: "web", name: "Browser", cmd: "/usr/bin/firefox" },
                        { icon: "code", name: "Code", cmd: "/usr/bin/code" }
                    ]

                    property int pendingIndex: -1
                    property string pendingKey: ""
                    property string pendingValue: ""

                    Timer {
                        id: saveTimer
                        interval: 500
                        onTriggered: {
                            const idx = quickLaunchEditor.pendingIndex
                            const key = quickLaunchEditor.pendingKey
                            const val = quickLaunchEditor.pendingValue
                            if (idx >= 0 && idx < quickLaunchEditor.shortcuts.length) {
                                const newShortcuts = JSON.parse(JSON.stringify(quickLaunchEditor.shortcuts))
                                newShortcuts[idx][key] = val
                                Config.setNestedValue("sidebar.widgets.quickLaunch", newShortcuts)
                            }
                        }
                    }

                    function queueUpdate(index, key, value) {
                        pendingIndex = index
                        pendingKey = key
                        pendingValue = value
                        saveTimer.restart()
                    }

                    function removeShortcut(index) {
                        const newShortcuts = shortcuts.filter((_, i) => i !== index)
                        Config.setNestedValue("sidebar.widgets.quickLaunch", newShortcuts)
                    }

                    function addShortcut() {
                        const newShortcuts = [...shortcuts, { icon: "apps", name: "", cmd: "" }]
                        Config.setNestedValue("sidebar.widgets.quickLaunch", newShortcuts)
                    }

                    Repeater {
                        model: quickLaunchEditor.shortcuts.length

                        delegate: Rectangle {
                            id: launchItem
                            required property int index
                            readonly property var itemData: quickLaunchEditor.shortcuts[index] ?? {}
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: SettingsMaterialPreset.groupRadius
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 6
                                spacing: 6

                                MaterialSymbol {
                                    text: launchItem.itemData.icon ?? "apps"
                                    iconSize: 20
                                    color: Appearance.colors.colPrimary
                                }

                                TextInput {
                                    Layout.preferredWidth: 60
                                    text: launchItem.itemData.icon ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.main
                                    color: Appearance.colors.colSubtext
                                    selectByMouse: true
                                    clip: true
                                    onTextEdited: quickLaunchEditor.queueUpdate(launchItem.index, "icon", text)

                                    Text {
                                        anchors.fill: parent
                                        text: "icon"
                                        color: Appearance.colors.colOutline
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }

                                Rectangle { width: 1; Layout.fillHeight: true; Layout.topMargin: 8; Layout.bottomMargin: 8; color: Appearance.colors.colOutlineVariant }

                                TextInput {
                                    Layout.preferredWidth: 70
                                    text: launchItem.itemData.name ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.main
                                    color: Appearance.colors.colOnLayer1
                                    selectByMouse: true
                                    clip: true
                                    onTextEdited: quickLaunchEditor.queueUpdate(launchItem.index, "name", text)

                                    Text {
                                        anchors.fill: parent
                                        text: Translation.tr("Name")
                                        color: Appearance.colors.colOutline
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }

                                Rectangle { width: 1; Layout.fillHeight: true; Layout.topMargin: 8; Layout.bottomMargin: 8; color: Appearance.colors.colOutlineVariant }

                                TextInput {
                                    Layout.fillWidth: true
                                    text: launchItem.itemData.cmd ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.family: Appearance.font.family.monospace
                                    color: Appearance.colors.colSubtext
                                    selectByMouse: true
                                    clip: true
                                    onTextEdited: quickLaunchEditor.queueUpdate(launchItem.index, "cmd", text)

                                    Text {
                                        anchors.fill: parent
                                        text: Translation.tr("Command")
                                        color: Appearance.colors.colOutline
                                        font: parent.font
                                        visible: !parent.text && !parent.activeFocus
                                    }
                                }

                                RippleButton {
                                    implicitWidth: 28; implicitHeight: 28
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colErrorContainer
                                    colRipple: Appearance.colors.colError
                                    onClicked: quickLaunchEditor.removeShortcut(launchItem.index)

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: 14
                                        color: Appearance.colors.colSubtext
                                    }

                                    StyledToolTip { text: Translation.tr("Remove") }
                                }
                            }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        buttonRadius: SettingsMaterialPreset.groupRadius
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        onClicked: quickLaunchEditor.addShortcut()

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            MaterialSymbol { text: "add"; iconSize: 16; color: Appearance.colors.colPrimary }
                            StyledText { text: Translation.tr("Add shortcut"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        }
                    }
                }

                SettingsSwitch {
                    buttonIcon: "toggle_on"
                    text: Translation.tr("Controls")
                    checked: Config.options?.sidebar?.widgets?.controls ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controls", checked)
                }

                SettingsSwitch {
                    buttonIcon: "monitoring"
                    text: Translation.tr("System status")
                    checked: Config.options?.sidebar?.widgets?.status ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.status", checked)
                }

                SettingsSwitch {
                    buttonIcon: "currency_bitcoin"
                    text: Translation.tr("Crypto prices")
                    checked: Config.options?.sidebar?.widgets?.crypto ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.crypto", checked)
                }

                SettingsSwitch {
                    buttonIcon: "wallpaper"
                    text: Translation.tr("Wallpaper picker")
                    checked: Config.options?.sidebar?.widgets?.wallpaper ?? false
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.wallpaper", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Layout")

                ConfigSpinBox {
                    icon: "format_line_spacing"
                    text: Translation.tr("Widget spacing")
                    value: Config.options?.sidebar?.widgets?.spacing ?? 8
                    from: 0
                    to: 24
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("sidebar.widgets.spacing", value)
                    StyledToolTip {
                        text: Translation.tr("Space between widgets in pixels")
                    }
                }

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: "drag_indicator"
                    text: Translation.tr("Ctrl+Click on any widget to reorder")
                }
            }

            ContentSubsection {
                id: cryptoSection
                title: Translation.tr("Crypto Widget")
                tooltip: Translation.tr("Configure cryptocurrencies to track")
                visible: Config.options?.sidebar?.widgets?.crypto ?? false

                readonly property var popularCoins: [
                    "bitcoin", "ethereum", "solana", "cardano", "dogecoin", "ripple",
                    "polkadot", "litecoin", "monero", "toncoin", "avalanche-2", "chainlink",
                    "uniswap", "stellar", "binancecoin", "tron", "shiba-inu", "pepe"
                ]

                function addCoin(coinId) {
                    const id = coinId.toLowerCase().trim()
                    if (!id) return
                    const current = Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []
                    if (current.includes(id)) return
                    Config.setNestedValue("sidebar.widgets.crypto_settings.coins", [...current, id])
                    coinInput.text = ""
                    coinPopup.close()
                }

                function removeCoin(coinId) {
                    const current = Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []
                    Config.setNestedValue("sidebar.widgets.crypto_settings.coins", current.filter(c => c !== coinId))
                }

                function filteredCoins() {
                    const q = coinInput.text.toLowerCase().trim()
                    const current = Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []
                    return popularCoins.filter(c => !current.includes(c) && c.includes(q))
                }

                ConfigSpinBox {
                    icon: "schedule"
                    text: Translation.tr("Refresh interval (seconds)")
                    value: Config.options?.sidebar?.widgets?.crypto_settings?.refreshInterval ?? 60
                    from: 30
                    to: 300
                    stepSize: 30
                    onValueChanged: Config.setNestedValue("sidebar.widgets.crypto_settings.refreshInterval", value)
                }

                // Coin input with autocomplete
                Item {
                    Layout.fillWidth: true
                    implicitHeight: coinInput.implicitHeight

                    TextField {
                        id: coinInput
                        width: parent.width
                        placeholderText: Translation.tr("Type to search coins...")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        placeholderTextColor: Appearance.colors.colSubtext
                        background: Rectangle {
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.small
                            border.width: coinInput.activeFocus ? 2 : 1
                            border.color: coinInput.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                        }
                        onTextChanged: {
                            if (text.length > 0) coinPopup.open()
                            else coinPopup.close()
                        }
                        onAccepted: {
                            const filtered = cryptoSection.filteredCoins()
                            if (filtered.length > 0) cryptoSection.addCoin(filtered[0])
                            else if (text.trim()) cryptoSection.addCoin(text)
                        }
                        Keys.onDownPressed: coinList.incrementCurrentIndex()
                        Keys.onUpPressed: coinList.decrementCurrentIndex()
                    }

                    Popup {
                        id: coinPopup
                        y: coinInput.height + 4
                        width: coinInput.width
                        height: Math.min(200, coinList.contentHeight + 16)
                        padding: 8
                        visible: coinInput.text.length > 0 && cryptoSection.filteredCoins().length > 0

                        background: Rectangle {
                            color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                 : Appearance.colors.colLayer2Base
                            radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                            border.width: 1
                            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder
                                        : Appearance.colors.colLayer0Border
                        }

                        ListView {
                            id: coinList
                            anchors.fill: parent
                            model: cryptoSection.filteredCoins()
                            clip: true
                            currentIndex: 0

                            delegate: RippleButton {
                                id: coinDelegate
                                required property string modelData
                                required property int index
                                width: coinList.width
                                implicitHeight: 32
                                buttonRadius: Appearance.rounding.small
                                colBackground: coinList.currentIndex === index ? Appearance.colors.colLayer1Hover : "transparent"
                                colBackgroundHover: Appearance.colors.colLayer1Hover
                                onClicked: cryptoSection.addCoin(modelData)

                                contentItem: StyledText {
                                    text: coinDelegate.modelData
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.family: Appearance.font.family.monospace
                                    color: Appearance.colors.colOnLayer1
                                    leftPadding: 8
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // Coin chips
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: (Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []).length > 0

                    Repeater {
                        model: Config.options?.sidebar?.widgets?.crypto_settings?.coins ?? []

                        Rectangle {
                            id: coinChip
                            required property string modelData
                            width: chipRow.implicitWidth + 8
                            height: 26
                            radius: 13
                            color: chipMouse.containsMouse ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 2

                                StyledText {
                                    text: coinChip.modelData
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.family: Appearance.font.family.monospace
                                    color: Appearance.colors.colOnSecondaryContainer
                                }

                                MaterialSymbol {
                                    text: "close"
                                    iconSize: 12
                                    color: Appearance.colors.colOnSecondaryContainer
                                    opacity: chipMouse.containsMouse ? 1 : 0.5
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cryptoSection.removeCoin(coinChip.modelData)
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Wallpaper Picker")
                tooltip: Translation.tr("Quick wallpaper selection widget")
                visible: Config.options?.sidebar?.widgets?.wallpaper ?? false

                ConfigSpinBox {
                    icon: "photo_size_select_large"
                    text: Translation.tr("Thumbnail size")
                    value: Config.options?.sidebar?.widgets?.quickWallpaper?.itemSize ?? 56
                    from: 40
                    to: 80
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("sidebar.widgets.quickWallpaper.itemSize", value)
                }

                SettingsSwitch {
                    buttonIcon: "title"
                    text: Translation.tr("Show header")
                    checked: Config.options?.sidebar?.widgets?.quickWallpaper?.showHeader ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.quickWallpaper.showHeader", checked)
                }

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: "swipe"
                    text: Translation.tr("Scroll horizontally to browse wallpapers")
                }
            }

            ContentSubsection {
                title: Translation.tr("Glance Header")
                tooltip: Translation.tr("Configure the header with time and quick indicators")

                SettingsSwitch {
                    buttonIcon: "volume_up"
                    text: Translation.tr("Volume button")
                    checked: Config.options?.sidebar?.widgets?.glance?.showVolume ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.glance.showVolume", checked)
                }

                SettingsSwitch {
                    buttonIcon: "sports_esports"
                    text: Translation.tr("Game mode indicator")
                    checked: Config.options?.sidebar?.widgets?.glance?.showGameMode ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.glance.showGameMode", checked)
                }

                SettingsSwitch {
                    buttonIcon: "do_not_disturb_on"
                    text: Translation.tr("Do not disturb indicator")
                    checked: Config.options?.sidebar?.widgets?.glance?.showDnd ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.glance.showDnd", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Status Rings")
                tooltip: Translation.tr("Configure which system metrics to show")

                SettingsSwitch {
                    buttonIcon: "memory"
                    text: Translation.tr("CPU usage")
                    checked: Config.options?.sidebar?.widgets?.statusRings?.showCpu ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.statusRings.showCpu", checked)
                }

                SettingsSwitch {
                    buttonIcon: "memory_alt"
                    text: Translation.tr("RAM usage")
                    checked: Config.options?.sidebar?.widgets?.statusRings?.showRam ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.statusRings.showRam", checked)
                }

                SettingsSwitch {
                    buttonIcon: "hard_drive"
                    text: Translation.tr("Disk usage")
                    checked: Config.options?.sidebar?.widgets?.statusRings?.showDisk ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.statusRings.showDisk", checked)
                }

                SettingsSwitch {
                    buttonIcon: "thermostat"
                    text: Translation.tr("Temperature")
                    checked: Config.options?.sidebar?.widgets?.statusRings?.showTemp ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.statusRings.showTemp", checked)
                }

                SettingsSwitch {
                    buttonIcon: "battery_full"
                    text: Translation.tr("Battery")
                    checked: Config.options?.sidebar?.widgets?.statusRings?.showBattery ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.statusRings.showBattery", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Controls Card")
                tooltip: Translation.tr("Configure which toggles and actions to show")

                ContentSubsectionLabel { text: Translation.tr("Toggles") }

                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Dark mode")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showDarkMode ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showDarkMode", checked)
                }

                SettingsSwitch {
                    buttonIcon: "do_not_disturb_on"
                    text: Translation.tr("Do not disturb")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showDnd ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showDnd", checked)
                }

                SettingsSwitch {
                    buttonIcon: "nightlight"
                    text: Translation.tr("Night light")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showNightLight ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showNightLight", checked)
                }

                SettingsSwitch {
                    buttonIcon: "sports_esports"
                    text: Translation.tr("Game mode")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showGameMode ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showGameMode", checked)
                }

                ContentSubsectionLabel { text: Translation.tr("Actions") }

                SettingsSwitch {
                    buttonIcon: "wifi"
                    text: Translation.tr("Network")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showNetwork ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showNetwork", checked)
                }

                SettingsSwitch {
                    buttonIcon: "bluetooth"
                    text: Translation.tr("Bluetooth")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showBluetooth ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showBluetooth", checked)
                }

                SettingsSwitch {
                    buttonIcon: "settings"
                    text: Translation.tr("Settings")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showSettings ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showSettings", checked)
                }

                SettingsSwitch {
                    buttonIcon: "lock"
                    text: Translation.tr("Lock")
                    checked: Config.options?.sidebar?.widgets?.controlsCard?.showLock ?? true
                    onCheckedChanged: Config.setNestedValue("sidebar.widgets.controlsCard.showLock", checked)
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "voting_chip"
        title: Translation.tr("On-screen display")

        SettingsGroup {
            ConfigSpinBox {
                icon: "av_timer"
                text: Translation.tr("Timeout (ms)")
                value: Config.options.osd.timeout
                from: 100
                to: 3000
                stepSize: 100
                onValueChanged: {
                    Config.options.osd.timeout = value;
                }
                StyledToolTip {
                    text: Translation.tr("How long the volume/brightness indicator stays visible")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "overview_key"
        title: Translation.tr("Overview")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.overview.enable
                onCheckedChanged: {
                    Config.options.overview.enable = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable the app launcher and workspace overview (Super+Space)")
                }
            }
            SettingsSwitch {
                buttonIcon: "center_focus_strong"
                text: Translation.tr("Center icons")
                checked: Config.options.overview.centerIcons
                onCheckedChanged: {
                    Config.options.overview.centerIcons = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Center app icons in the launcher grid")
                }
            }
            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Scale (%)")
                value: Config.options.overview.scale * 100
                from: 1
                to: 100
                stepSize: 1
                onValueChanged: {
                    Config.options.overview.scale = value / 100;
                }
                StyledToolTip {
                    text: Translation.tr("Scale of workspace previews in the overview")
                }
            }
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "splitscreen_bottom"
                    text: Translation.tr("Rows")
                    value: Config.options.overview.rows
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.overview.rows = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of rows in the app launcher grid")
                    }
                }
                ConfigSpinBox {
                    icon: "splitscreen_right"
                    text: Translation.tr("Columns")
                    value: Config.options.overview.columns
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.overview.columns = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of columns in the app launcher grid")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Wallpaper background")

                SettingsSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Enable wallpaper blur")
                    checked: !Config.options.overview || Config.options.overview.backgroundBlurEnable !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.backgroundBlurEnable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to the overview background")
                    }
                }

                ConfigSpinBox {
                    icon: "loupe"
                    text: Translation.tr("Wallpaper blur radius")
                    value: Config.options.overview && Config.options.overview.backgroundBlurRadius !== undefined
                           ? Config.options.overview.backgroundBlurRadius
                           : 22
                    from: 0
                    to: 100
                    stepSize: 1
                    enabled: !Config.options.overview || Config.options.overview.backgroundBlurEnable !== false
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.backgroundBlurRadius = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Intensity of the wallpaper blur")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Wallpaper dim (%)")
                    value: Config.options.overview && Config.options.overview.backgroundDim !== undefined
                           ? Config.options.overview.backgroundDim
                           : 35
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.backgroundDim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Darkness of the wallpaper behind overview")
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Overlay scrim dim (%)")
                    value: Config.options.overview && Config.options.overview.scrimDim !== undefined
                           ? Config.options.overview.scrimDim
                           : 35
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.scrimDim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Additional darkness for better contrast")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Positioning")

                SettingsSwitch {
                    buttonIcon: "dashboard_customize"
                    text: Translation.tr("Respect bar area (never overlap)")
                    checked: !Config.options.overview || Config.options.overview.respectBar !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.respectBar = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Prevent overview from covering the system bar area")
                    }
                }

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "vertical_align_top"
                        text: Translation.tr("Extra top margin (px)")
                        value: Config.options.overview && Config.options.overview.topMargin !== undefined
                               ? Config.options.overview.topMargin
                               : 0
                        from: 0
                        to: 400
                        stepSize: 1
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.topMargin = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Space reserved at the top of the screen")
                        }
                    }
                    ConfigSpinBox {
                        icon: "vertical_align_bottom"
                        text: Translation.tr("Extra bottom margin (px)")
                        value: Config.options.overview && Config.options.overview.bottomMargin !== undefined
                               ? Config.options.overview.bottomMargin
                               : 0
                        from: 0
                        to: 400
                        stepSize: 1
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.bottomMargin = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Space reserved at the bottom of the screen")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Layout & gaps")

                ConfigSpinBox {
                    icon: "open_in_full"
                    text: Translation.tr("Max panel width (%) of screen")
                    value: Config.options.overview && Config.options.overview.maxPanelWidthRatio !== undefined
                           ? Math.round(Config.options.overview.maxPanelWidthRatio * 100)
                           : 100
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.maxPanelWidthRatio = value / 100;
                    }
                    StyledToolTip {
                        text: Translation.tr("Maximum width of the overview panel as screen percentage")
                    }
                }

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "grid_3x3"
                        text: Translation.tr("Workspace gap (px)")
                        value: Config.options.overview && Config.options.overview.workspaceSpacing !== undefined
                               ? Config.options.overview.workspaceSpacing
                               : 5
                        from: 0
                        to: 80
                        stepSize: 1
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.workspaceSpacing = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Horizontal gap between workspace previews")
                        }
                    }
                    ConfigSpinBox {
                        icon: "view_comfy_alt"
                        text: Translation.tr("Window tile gap (px)")
                        value: Config.options.overview && Config.options.overview.windowTileMargin !== undefined
                               ? Config.options.overview.windowTileMargin
                               : 6
                        from: 0
                        to: 80
                        stepSize: 1
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.windowTileMargin = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Gap between windows inside a workspace preview")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Icons")

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "format_size"
                        text: Translation.tr("Min icon size (px)")
                        value: Config.options.overview && Config.options.overview.iconMinSize !== undefined
                               ? Config.options.overview.iconMinSize
                               : 0
                        from: 0
                        to: 512
                        stepSize: 2
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.iconMinSize = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Minimum size for app icons")
                        }
                    }
                    ConfigSpinBox {
                        icon: "format_overline"
                        text: Translation.tr("Max icon size (px)")
                        value: Config.options.overview && Config.options.overview.iconMaxSize !== undefined
                               ? Config.options.overview.iconMaxSize
                               : 0
                        from: 0
                        to: 512
                        stepSize: 2
                        onValueChanged: {
                            if (!Config.options.overview)
                                Config.options.overview = ({})
                            Config.options.overview.iconMaxSize = value;
                        }
                        StyledToolTip {
                            text: Translation.tr("Maximum size for app icons")
                        }
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Behaviour")

                SettingsSwitch {
                    buttonIcon: "workspaces"
                    text: Translation.tr("Switch to dedicated workspace when opening Overview")
                    checked: Config.options.overview && Config.options.overview.switchToWorkspaceOnOpen
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.switchToWorkspaceOnOpen = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Automatically switch to a specific workspace when overview opens")
                    }
                }

                ConfigSpinBox {
                    icon: "looks_one"
                    text: Translation.tr("Workspace number (1-based)")
                    enabled: Config.options.overview && Config.options.overview.switchToWorkspaceOnOpen
                    value: Config.options.overview && Config.options.overview.switchWorkspaceIndex !== undefined
                           ? Config.options.overview.switchWorkspaceIndex
                           : 1
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.switchWorkspaceIndex = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Index of the workspace to switch to")
                    }
                }
                ConfigSpinBox {
                    icon: "swap_vert"
                    text: Translation.tr("Wheel steps per workspace (Overview)")
                    value: Config.options.overview && Config.options.overview.scrollWorkspaceSteps !== undefined
                           ? Config.options.overview.scrollWorkspaceSteps
                           : 2
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.scrollWorkspaceSteps = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("How many workspaces to scroll per mouse wheel detent")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "overview_key"
                    text: Translation.tr("Keep Overview open when clicking windows")
                    checked: !Config.options.overview || Config.options.overview.keepOverviewOpenOnWindowClick !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.keepOverviewOpenOnWindowClick = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Don't close overview when clicking on a window preview")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "close_fullscreen"
                    text: Translation.tr("Close Overview after moving window")
                    checked: !Config.options.overview || Config.options.overview.closeAfterWindowMove !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.closeAfterWindowMove = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Close overview automatically after dropping a window to a new workspace")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "looks_one"
                    text: Translation.tr("Show workspace numbers")
                    checked: !Config.options.overview || Config.options.overview.showWorkspaceNumbers !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.showWorkspaceNumbers = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Overlay large numbers on workspace previews")
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Animation")

                SettingsSwitch {
                    buttonIcon: "motion_play"
                    text: Translation.tr("Enable focus animation")
                    checked: !Config.options.overview || Config.options.overview.focusAnimationEnable !== false
                    onCheckedChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.focusAnimationEnable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Animate the focus rectangle when navigating with keyboard")
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Focus animation duration (ms)")
                    enabled: !Config.options.overview || Config.options.overview.focusAnimationEnable !== false
                    value: Config.options.overview && Config.options.overview.focusAnimationDurationMs !== undefined
                           ? Config.options.overview.focusAnimationDurationMs
                           : 180
                    from: 0
                    to: 1000
                    stepSize: 10
                    onValueChanged: {
                        if (!Config.options.overview)
                            Config.options.overview = ({})
                        Config.options.overview.focusAnimationDurationMs = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Speed of the focus rectangle animation")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: false
        icon: "wallpaper_slideshow"
        title: Translation.tr("Wallpaper selector")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "ad"
                text: Translation.tr('Use system file picker')
                checked: Config.options.wallpaperSelector.useSystemFileDialog
                onCheckedChanged: {
                    Config.options.wallpaperSelector.useSystemFileDialog = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Use your system's native file picker instead of the built-in one")
                }
            }
        }
    }
}
