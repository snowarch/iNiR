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

    ContentSection {
        icon: "point_scan"
        title: Translation.tr("Crosshair overlay")

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

    ContentSection {
        icon: "layers"
        title: Translation.tr("Overlay widgets")

        ContentSubsection {
            title: Translation.tr("Background & dim")

            ConfigSwitch {
                buttonIcon: "water"
                text: Translation.tr("Darken screen behind overlay")
                checked: Config.options.overlay.darkenScreen
                onCheckedChanged: {
                    Config.options.overlay.darkenScreen = checked;
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
            }
        }

        ContentSubsection {
            title: Translation.tr("Animations")

            ConfigSwitch {
                buttonIcon: "movie"
                text: Translation.tr("Enable opening zoom animation")
                checked: Config.options.overlay.openingZoomAnimation
                onCheckedChanged: {
                    Config.options.overlay.openingZoomAnimation = checked;
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
            }
        }
    }

    ContentSection {
        icon: "forum"
        title: Translation.tr("Overlay: Discord")

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

    ContentSection {
        visible: root.isIiActive
        icon: "keyboard_tab"
        title: Translation.tr("Alt-Tab switcher (Material ii)")

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr("Tint app icons")
            checked: Config.options.altSwitcher ? Config.options.altSwitcher.monochromeIcons : false
            onCheckedChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.monochromeIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "movie"
            text: Translation.tr("Enable slide animation")
            checked: !Config.options.altSwitcher || Config.options.altSwitcher.enableAnimation !== false
            onCheckedChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.enableAnimation = checked;
            }
        }

        ConfigSpinBox {
            icon: "speed"
            text: Translation.tr("Animation duration (ms)")
            value: Config.options.altSwitcher && Config.options.altSwitcher.animationDurationMs !== undefined
                   ? Config.options.altSwitcher.animationDurationMs
                   : 200
            from: 0
            to: 1000
            stepSize: 25
            onValueChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.animationDurationMs = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "history"
            text: Translation.tr("Most recently used first")
            checked: Config.options.altSwitcher && Config.options.altSwitcher.useMostRecentFirst !== false
            onCheckedChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.useMostRecentFirst = checked;
            }
        }

        ConfigSpinBox {
            icon: "opacity"
            text: Translation.tr("Background opacity (%)")
            value: Config.options.altSwitcher && Config.options.altSwitcher.backgroundOpacity !== undefined
                   ? Math.round(Config.options.altSwitcher.backgroundOpacity * 100)
                   : 90
            from: 10
            to: 100
            stepSize: 5
            onValueChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.backgroundOpacity = value / 100;
            }
        }

        ConfigSpinBox {
            icon: "blur_on"
            text: Translation.tr("Blur amount (%)")
            value: Config.options.altSwitcher && Config.options.altSwitcher.blurAmount !== undefined
                   ? Math.round(Config.options.altSwitcher.blurAmount * 100)
                   : 40
            from: 0
            to: 100
            stepSize: 5
            onValueChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.blurAmount = value / 100;
            }
        }

        ConfigSpinBox {
            icon: "opacity"
            text: Translation.tr("Scrim dim (%)")
            value: Config.options.altSwitcher && Config.options.altSwitcher.scrimDim !== undefined
                   ? Config.options.altSwitcher.scrimDim
                   : 35
            from: 0
            to: 100
            stepSize: 5
            onValueChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.scrimDim = value;
            }
        }

        ConfigSpinBox {
            icon: "hourglass_top"
            text: Translation.tr("Auto-hide delay after selection (ms)")
            value: Config.options.altSwitcher && Config.options.altSwitcher.autoHideDelayMs !== undefined
                   ? Config.options.altSwitcher.autoHideDelayMs
                   : 500
            from: 50
            to: 2000
            stepSize: 50
            onValueChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.autoHideDelayMs = value;
            }
        }

        ConfigSwitch {
            buttonIcon: "overview_key"
            text: Translation.tr("Show Niri overview while switching")
            checked: Config.options.altSwitcher && Config.options.altSwitcher.showOverviewWhileSwitching
            onCheckedChanged: {
                if (!Config.options.altSwitcher)
                    Config.options.altSwitcher = ({})
                Config.options.altSwitcher.showOverviewWhileSwitching = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Layout & alignment")

            ConfigSwitch {
                buttonIcon: "view_compact"
                text: Translation.tr("Compact horizontal style (icons only)")
                checked: Config.options.altSwitcher && Config.options.altSwitcher.compactStyle
                onCheckedChanged: {
                    if (!Config.options.altSwitcher)
                        Config.options.altSwitcher = ({})
                    Config.options.altSwitcher.compactStyle = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Show only app icons in a horizontal row, similar to macOS Spotlight")
                }
            }

            ConfigSelectionArray {
                enabled: !Config.options.altSwitcher || !Config.options.altSwitcher.compactStyle
                currentValue: Config.options.altSwitcher && Config.options.altSwitcher.panelAlignment
                               ? Config.options.altSwitcher.panelAlignment
                               : "right"
                onSelected: newValue => {
                    if (!Config.options.altSwitcher)
                        Config.options.altSwitcher = ({})
                    Config.options.altSwitcher.panelAlignment = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Align to right edge"),
                        icon: "align_horizontal_right",
                        value: "right"
                    },
                    {
                        displayName: Translation.tr("Center on screen"),
                        icon: "align_horizontal_center",
                        value: "center"
                    }
                ]
            }

            ConfigSwitch {
                enabled: !Config.options.altSwitcher || !Config.options.altSwitcher.compactStyle
                buttonIcon: "styler"
                text: Translation.tr("Use Material 3 card layout")
                checked: Config.options.altSwitcher && Config.options.altSwitcher.useM3Layout
                onCheckedChanged: {
                    if (!Config.options.altSwitcher)
                        Config.options.altSwitcher = ({})
                    Config.options.altSwitcher.useM3Layout = checked;
                }
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "call_to_action"
        title: Translation.tr("Dock")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.dock.enable
            onCheckedChanged: {
                Config.options.dock.enable = checked;
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "highlight_mouse_cursor"
                text: Translation.tr("Hover to reveal")
                checked: Config.options.dock.hoverToReveal
                onCheckedChanged: {
                    Config.options.dock.hoverToReveal = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Pinned on startup")
                checked: Config.options.dock.pinnedOnStartup
                onCheckedChanged: {
                    Config.options.dock.pinnedOnStartup = checked;
                }
            }
        }
        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr("Tint app icons")
            checked: Config.options.dock.monochromeIcons
            onCheckedChanged: {
                Config.options.dock.monochromeIcons = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "widgets"
            text: Translation.tr("Show dock background")
            checked: Config.options.dock.showBackground
            onCheckedChanged: {
                Config.options.dock.showBackground = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Enable dock blur glass")
            checked: Config.options.dock.enableBlurGlass
            onCheckedChanged: {
                Config.options.dock.enableBlurGlass = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Appearance")

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
            }

            ConfigSpinBox {
                icon: "vertical_align_bottom"
                text: Translation.tr("Hover reveal region height (px)")
                value: Config.options.dock.hoverRegionHeight ?? 2
                from: 1
                to: 20
                stepSize: 1
                enabled: Config.options.dock.hoverToReveal
                onValueChanged: {
                    Config.options.dock.hoverRegionHeight = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Window indicators")

            ConfigSwitch {
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

            ConfigSwitch {
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
            }
        }
    }

    ContentSection {
        icon: "lock"
        title: Translation.tr("Lock screen")

        ConfigSwitch {
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

        ConfigSwitch {
            buttonIcon: "account_circle"
            text: Translation.tr('Launch on startup')
            checked: Config.options.lock.launchOnStartup
            onCheckedChanged: {
                Config.options.lock.launchOnStartup = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Security")

            ConfigSwitch {
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

            ConfigSwitch {
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

            ConfigSwitch {
                buttonIcon: "center_focus_weak"
                text: Translation.tr('Center clock')
                checked: Config.options.lock.centerClock
                onCheckedChanged: {
                    Config.options.lock.centerClock = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "info"
                text: Translation.tr('Show "Locked" text')
                checked: Config.options.lock.showLockedText
                onCheckedChanged: {
                    Config.options.lock.showLockedText = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "shapes"
                text: Translation.tr('Use varying shapes for password characters')
                checked: Config.options.lock.materialShapeChars
                onCheckedChanged: {
                    Config.options.lock.materialShapeChars = checked;
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Style: Blurred")

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr('Enable blur')
                checked: Config.options.lock.blur.enable
                onCheckedChanged: {
                    Config.options.lock.blur.enable = checked;
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
            }
        }
    }

    ContentSection {
        icon: "notifications"
        title: Translation.tr("Notifications")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Timeout duration (if not defined by notification) (ms)")
            value: Config.options.notifications.timeout
            from: 1000
            to: 60000
            stepSize: 1000
            onValueChanged: {
                Config.options.notifications.timeout = value;
            }
        }

        ContentSubsection {
            title: Translation.tr("Timeout per urgency")

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    text: Translation.tr("Low")
                    value: Config.options.notifications.timeoutLow
                    from: 0
                    to: 60000
                    stepSize: 500
                    onValueChanged: {
                        Config.options.notifications.timeoutLow = value;
                    }
                }
                ConfigSpinBox {
                    text: Translation.tr("Normal")
                    value: Config.options.notifications.timeoutNormal
                    from: 0
                    to: 60000
                    stepSize: 500
                    onValueChanged: {
                        Config.options.notifications.timeoutNormal = value;
                    }
                }
                ConfigSpinBox {
                    text: Translation.tr("Critical")
                    value: Config.options.notifications.timeoutCritical
                    from: 0
                    to: 600000
                    stepSize: 500
                    onValueChanged: {
                        Config.options.notifications.timeoutCritical = value;
                    }
                }
            }
        }



        ContentSubsection {
            title: Translation.tr("Test notifications")
            tooltip: Translation.tr("Send a few sample notifications to preview position and style")

            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.full
                materialIcon: "notifications_active"
                mainText: Translation.tr("Send test notifications")
                onClicked: {
                    Notifications.sendTestNotifications();
                }
            }
        }
    }

    ContentSection {
        icon: "screenshot_frame_2"
        title: Translation.tr("Region selector (screen snipping/Google Lens)")

        ContentSubsection {
            title: Translation.tr("Hint target regions")
            ConfigRow {
                ConfigSwitch {
                    buttonIcon: "select_window"
                    text: Translation.tr('Windows')
                    checked: Config.options.regionSelector.targetRegions.windows
                    onCheckedChanged: {
                        Config.options.regionSelector.targetRegions.windows = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "right_panel_open"
                    text: Translation.tr('Layers')
                    checked: Config.options.regionSelector.targetRegions.layers
                    onCheckedChanged: {
                        Config.options.regionSelector.targetRegions.layers = checked;
                    }
                }
                ConfigSwitch {
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
            title: Translation.tr("Rectangular selection")

            ConfigSwitch {
                buttonIcon: "point_scan"
                text: Translation.tr("Show aim lines")
                checked: Config.options.regionSelector.rect.showAimLines
                onCheckedChanged: {
                    Config.options.regionSelector.rect.showAimLines = checked;
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
            }
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "side_navigation"
        title: Translation.tr("Sidebars")

        ConfigSwitch {
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

        ConfigSwitch {
            buttonIcon: "translate"
            text: Translation.tr('Enable translator')
            checked: Config.options.sidebar.translator.enable
            onCheckedChanged: {
                Config.options.sidebar.translator.enable = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "image"
            text: Translation.tr('Enable Wallhaven sidebar')
            checked: Config.options.sidebar?.wallhaven?.enable ?? false
            onCheckedChanged: {
                if (!Config.options.sidebar.wallhaven) Config.options.sidebar.wallhaven = ({})
                Config.options.sidebar.wallhaven.enable = checked;
            }
        }

        ConfigSpinBox {
            icon: "format_list_numbered"
            text: Translation.tr("Wallhaven results per page")
            value: Config.options.sidebar?.wallhaven?.limit ?? 24
            from: 12
            to: 72
            stepSize: 4
            onValueChanged: {
                if (!Config.options.sidebar.wallhaven) Config.options.sidebar.wallhaven = ({})
                Config.options.sidebar.wallhaven.limit = value;
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
                onTextChanged: {
                    if (!Config.options.sidebar.wallhaven) Config.options.sidebar.wallhaven = ({})
                    Config.options.sidebar.wallhaven.apiKey = text
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
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "password_2",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Android"),
                        icon: "action_key",
                        value: "android"
                    }
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
            }
        }

        ContentSubsection {
            title: Translation.tr("Sliders")

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.sidebar.quickSliders.enable
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.enable = checked;
                }
            }
            
            ConfigSwitch {
                buttonIcon: "brightness_6"
                text: Translation.tr("Brightness")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showBrightness
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showBrightness = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Volume")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showVolume
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showVolume = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Microphone")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showMic
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showMic = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Corner open")
            tooltip: Translation.tr("Allows you to open sidebars by clicking or hovering screen corners regardless of bar position")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.cornerOpen.enable
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.enable = checked;
                    }
                }
            }
            ConfigSwitch {
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
                ConfigSwitch {
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
                ConfigSwitch {
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
                ConfigSwitch {
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
            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Visualize region")
                checked: Config.options.sidebar.cornerOpen.visualize
                onCheckedChanged: {
                    Config.options.sidebar.cornerOpen.visualize = checked;
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
                }
            }
        }
    }

    ContentSection {
        icon: "voting_chip"
        title: Translation.tr("On-screen display")

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
        }
    }

    ContentSection {
        visible: root.isIiActive
        icon: "overview_key"
        title: Translation.tr("Overview")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.overview.enable
            onCheckedChanged: {
                Config.options.overview.enable = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "center_focus_strong"
            text: Translation.tr("Center icons")
            checked: Config.options.overview.centerIcons
            onCheckedChanged: {
                Config.options.overview.centerIcons = checked;
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
            }
        }
        ContentSubsection {
            title: Translation.tr("Wallpaper background")

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Enable wallpaper blur")
                checked: !Config.options.overview || Config.options.overview.backgroundBlurEnable !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.backgroundBlurEnable = checked;
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
            }
        }
        ContentSubsection {
            title: Translation.tr("Positioning")

            ConfigSwitch {
                buttonIcon: "dashboard_customize"
                text: Translation.tr("Respect bar area (never overlap)")
                checked: !Config.options.overview || Config.options.overview.respectBar !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.respectBar = checked;
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
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Behaviour")

            ConfigSwitch {
                buttonIcon: "workspaces"
                text: Translation.tr("Switch to dedicated workspace when opening Overview")
                checked: Config.options.overview && Config.options.overview.switchToWorkspaceOnOpen
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.switchToWorkspaceOnOpen = checked;
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
            }
            ConfigSwitch {
                buttonIcon: "overview_key"
                text: Translation.tr("Keep Overview open when clicking windows")
                checked: !Config.options.overview || Config.options.overview.keepOverviewOpenOnWindowClick !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.keepOverviewOpenOnWindowClick = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "close_fullscreen"
                text: Translation.tr("Close Overview after moving window")
                checked: !Config.options.overview || Config.options.overview.closeAfterWindowMove !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.closeAfterWindowMove = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "looks_one"
                text: Translation.tr("Show workspace numbers")
                checked: !Config.options.overview || Config.options.overview.showWorkspaceNumbers !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.showWorkspaceNumbers = checked;
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Animation")

            ConfigSwitch {
                buttonIcon: "motion_play"
                text: Translation.tr("Enable focus animation")
                checked: !Config.options.overview || Config.options.overview.focusAnimationEnable !== false
                onCheckedChanged: {
                    if (!Config.options.overview)
                        Config.options.overview = ({})
                    Config.options.overview.focusAnimationEnable = checked;
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
            }
        }
    }

    ContentSection {
        icon: "wallpaper_slideshow"
        title: Translation.tr("Wallpaper selector")

        ConfigSwitch {
            buttonIcon: "ad"
            text: Translation.tr('Use system file picker')
            checked: Config.options.wallpaperSelector.useSystemFileDialog
            onCheckedChanged: {
                Config.options.wallpaperSelector.useSystemFileDialog = checked;
            }
        }
    }
}
