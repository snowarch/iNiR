import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 3
    settingsPageName: Translation.tr("Background")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Waffle Mode")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("You're using Waffle style. Most background settings are in the Waffle Style page. Only the Backdrop section below applies to both styles.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "sync_alt"
        title: Translation.tr("Parallax")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "unfold_more_double"
                text: Translation.tr("Vertical")
                checked: Config.options.background.parallax.vertical
                onCheckedChanged: {
                    Config.options.background.parallax.vertical = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Enable vertical parallax movement based on mouse position")
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "counter_1"
                    text: Translation.tr("Depends on workspace")
                    checked: Config.options.background.parallax.enableWorkspace
                    onCheckedChanged: {
                        Config.options.background.parallax.enableWorkspace = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Shift wallpaper based on current workspace position")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Depends on sidebars")
                    checked: Config.options.background.parallax.enableSidebar
                    onCheckedChanged: {
                        Config.options.background.parallax.enableSidebar = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Shift wallpaper when sidebars are open")
                    }
                }
            }
            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Preferred wallpaper zoom (%)")
                value: Config.options.background.parallax.workspaceZoom * 100
                from: 100
                to: 150
                stepSize: 1
                onValueChanged: {
                    Config.options.background.parallax.workspaceZoom = value / 100;
                }
                StyledToolTip {
                    text: Translation.tr("How much to zoom the wallpaper for parallax effect")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "aspect_ratio"
        title: Translation.tr("Wallpaper scaling")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Fill crops, Fit shows bars")
                ConfigSelectionArray {
                    currentValue: Config.options?.background?.fillMode ?? "fill"
                    onSelected: newValue => {
                        Config.setNestedValue("background.fillMode", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Fill"), icon: "crop", value: "fill" },
                        { displayName: Translation.tr("Fit"), icon: "fit_screen", value: "fit" },
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Tile"), icon: "grid_view", value: "tile" }
                    ]
                }
            }
            
            SettingsSwitch {
                buttonIcon: "play_circle"
                text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                checked: Config.options?.background?.enableAnimation ?? true
                onCheckedChanged: {
                    Config.setNestedValue("background.enableAnimation", checked);
                }
                StyledToolTip {
                    text: Translation.tr("Play videos and GIFs as wallpaper. When disabled, shows thumbnail instead (better performance)")
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: true
        icon: "wallpaper"
        title: Translation.tr("Wallpaper effects")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Enable wallpaper blur")
                checked: Config.options.background.effects.enableBlur
                onCheckedChanged: {
                    Config.options.background.effects.enableBlur = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Blur the wallpaper when windows are present")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_medium"
                text: Translation.tr("Blur radius")
                value: Config.options.background.effects.blurRadius
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.background.effects.blurRadius = value;
                }
                StyledToolTip {
                    text: Translation.tr("Amount of blur applied to the wallpaper")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_linear"
                text: Translation.tr("Static blur when no windows (%)")
                value: Config.options.background.effects.blurStatic
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.blurStatic = value;
                }
                StyledToolTip {
                    text: Translation.tr("Percentage of blur to keep even when no windows are open")
                }
            }

            ConfigSpinBox {
                visible: Config.options.background.effects.enableBlur
                icon: "blur_circular"
                text: Translation.tr("Thumbnail blur strength (%)")
                value: Config.options.background.effects.thumbnailBlurStrength
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.thumbnailBlurStrength = value;
                }
                StyledToolTip {
                    text: Translation.tr("Blur strength applied to video/GIF thumbnails when animation is disabled (does not affect videos in playback)")
                }
            }

            ConfigSpinBox {
                icon: "brightness_6"
                text: Translation.tr("Dim overlay (%)")
                value: Config.options.background.effects.dim
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.dim = value;
                }
                StyledToolTip {
                    text: Translation.tr("Adds a dark overlay over the wallpaper. 0 = no dimming, 100 = completely black")
                    // Only show when hovering the spinbox; avoid always-on tooltips
                    extraVisibleCondition: false
                    alternativeVisibleCondition: parent && parent.hovered !== undefined ? parent.hovered : false
                }
            }

            ConfigSpinBox {
                icon: "brightness_low"
                text: Translation.tr("Extra dim when windows (%)")
                value: Config.options.background.effects.dynamicDim
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.background.effects.dynamicDim = value;
                }
                StyledToolTip {
                    text: Translation.tr("Additional dim applied when there are windows on the current workspace.")
                    extraVisibleCondition: false
                    alternativeVisibleCondition: parent && parent.hovered !== undefined ? parent.hovered : false
                }
            }

            ContentSubsection {
                title: Translation.tr("Backdrop (overview)")

                SettingsSwitch {
                    buttonIcon: "texture"
                    text: Translation.tr("Enable backdrop layer for overview")
                    checked: Config.options.background.backdrop.enable
                    onCheckedChanged: {
                        Config.options.background.backdrop.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a separate backdrop layer when overview is open")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "play_circle"
                    text: Translation.tr("Enable animated wallpapers (videos/GIFs)")
                    checked: Config.options.background.backdrop.enableAnimation
                    onCheckedChanged: {
                        Config.options.background.backdrop.enableAnimation = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Play videos and GIFs in backdrop (may impact performance)")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable && Config.options.background.backdrop.enableAnimation
                    buttonIcon: "blur_circular"
                    text: Translation.tr("Blur animated wallpapers (videos/GIFs)")
                    checked: Config.options?.background?.backdrop?.enableAnimatedBlur ?? false
                    onCheckedChanged: {
                        Config.setNestedValue("background.backdrop.enableAnimatedBlur", checked);
                    }
                    StyledToolTip {
                        text: Translation.tr("Apply blur effect to animated wallpapers in backdrop. Uses thumbnail blur strength setting. May significantly impact performance.")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "blur_on"
                    text: Translation.tr("Aurora glass effect")
                    checked: Config.options.background.backdrop.useAuroraStyle
                    onCheckedChanged: {
                        Config.options.background.backdrop.useAuroraStyle = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Use glass blur effect with adaptive colors from wallpaper (same as sidebars)")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable && Config.options.background.backdrop.useAuroraStyle
                    icon: "opacity"
                    text: Translation.tr("Aurora overlay opacity (%)")
                    value: Math.round((Config.options.background.backdrop.auroraOverlayOpacity) * 100)
                    from: 0
                    to: 200
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.backdrop.auroraOverlayOpacity = value / 100.0;
                    }
                    StyledToolTip {
                        text: Translation.tr("Transparency of the color overlay on the blurred wallpaper")
                    }
                }

                SettingsSwitch {
                    visible: Config.options.background.backdrop.enable
                    buttonIcon: "visibility_off"
                    text: Translation.tr("Hide main wallpaper (show only backdrop)")
                    checked: Config.options.background.backdrop.hideWallpaper
                    onCheckedChanged: {
                        Config.options.background.backdrop.hideWallpaper = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Only show the backdrop, hide the main wallpaper entirely")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "link"
                    text: Translation.tr("Use main wallpaper")
                    checked: Config.options.background.backdrop.useMainWallpaper
                    onCheckedChanged: {
                        Config.options.background.backdrop.useMainWallpaper = checked;
                        if (checked) {
                            Config.options.background.backdrop.wallpaperPath = "";
                        }
                    }
                    StyledToolTip {
                        text: Translation.tr("Use the same wallpaper for backdrop as the main wallpaper")
                    }
                }

                MaterialTextArea {
                    visible: Config.options.background.backdrop.enable
                             && !Config.options.background.backdrop.useMainWallpaper
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Backdrop wallpaper path (empty = use main wallpaper)")
                    text: Config.options.background.backdrop.wallpaperPath
                    wrapMode: TextEdit.NoWrap
                    onTextChanged: {
                        Config.options.background.backdrop.wallpaperPath = text;
                    }
                }

                RippleButtonWithIcon {
                    visible: !Config.options.background.backdrop.useMainWallpaper
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Pick backdrop wallpaper")
                    onClicked: {
                        Config.options.wallpaperSelector.selectionTarget = "backdrop";
                        Quickshell.execDetached(["/usr/bin/qs", "-c", "ii", "ipc", "call", "wallpaperSelector", "toggle"]);
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable
                    icon: "blur_on"
                    text: Translation.tr("Backdrop blur radius")
                    value: Config.options.background.backdrop.blurRadius
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: {
                        Config.options.background.backdrop.blurRadius = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Amount of blur applied to the backdrop layer")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options.background.backdrop.enable
                    icon: "brightness_5"
                    text: Translation.tr("Backdrop dim (%)")
                    value: Config.options.background.backdrop.dim
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.backdrop.dim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Darken the backdrop layer")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "palette"
                    text: Translation.tr("Backdrop saturation")
                    value: Math.round((Config.options?.background?.backdrop?.saturation ?? 0) * 100)
                    from: -100
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.saturation", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("Increase or decrease color intensity of the backdrop")
                    }
                }

                ConfigSpinBox {
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    icon: "contrast"
                    text: Translation.tr("Backdrop contrast")
                    value: Math.round((Config.options?.background?.backdrop?.contrast ?? 0) * 100)
                    from: -100
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.contrast", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("Increase or decrease light/dark difference in the backdrop")
                    }
                }

                ConfigRow {
                    uniform: true
                    visible: Config.options?.background?.backdrop?.enable ?? true
                    SettingsSwitch {
                        buttonIcon: "gradient"
                        text: Translation.tr("Enable vignette")
                        checked: Config.options?.background?.backdrop?.vignetteEnabled ?? false
                        onCheckedChanged: {
                            Config.setNestedValue("background.backdrop.vignetteEnabled", checked);
                        }
                        StyledToolTip {
                            text: Translation.tr("Add a dark gradient around the edges of the backdrop")
                        }
                    }
                }

                ConfigSpinBox {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.vignetteEnabled ?? false)
                    icon: "blur_circular"
                    text: Translation.tr("Vignette intensity")
                    value: Math.round((Config.options?.background?.backdrop?.vignetteIntensity ?? 0.5) * 100)
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.vignetteIntensity", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("How dark the vignette effect should be")
                    }
                }

                ConfigSpinBox {
                    visible: (Config.options?.background?.backdrop?.enable ?? true) && (Config.options?.background?.backdrop?.vignetteEnabled ?? false)
                    icon: "trip_origin"
                    text: Translation.tr("Vignette radius")
                    value: Math.round((Config.options?.background?.backdrop?.vignetteRadius ?? 0.7) * 100)
                    from: 10
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.setNestedValue("background.backdrop.vignetteRadius", value / 100.0);
                    }
                    StyledToolTip {
                        text: Translation.tr("How far the vignette extends from the edges")
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "clock_loader_40"
        title: Translation.tr("Widget: Clock")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show the desktop clock widget")
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.clock.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock style")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.style
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "digital"
                title: Translation.tr("Digital clock settings")

                SettingsSwitch {
                    buttonIcon: "animation"
                    text: Translation.tr("Animate time change")
                    checked: Config.options.background.widgets.clock.digital.animateChange
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.animateChange = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Smoothly animate digits when time changes")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock effects")

                ConfigSpinBox {
                    icon: "brightness_6"
                    text: Translation.tr("Clock dim (%)")
                    value: Config.options.background.widgets.clock.dim
                    from: 0
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.background.widgets.clock.dim = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Only affects the clock widget text, independent from the global wallpaper dim.")
                    }
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Cookie clock settings")

                SettingsSwitch {
                    buttonIcon: "wand_stars"
                    text: Translation.tr("Auto styling with Gemini")
                    checked: Config.options.background.widgets.clock.cookie.aiStyling
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.aiStyling = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Uses Gemini to categorize the wallpaper then picks a preset based on it.\nYou'll need to set Gemini API key on the left sidebar first.\nImages are downscaled for performance, but just to be safe,\ndo not select wallpapers with sensitive information.")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "airwave"
                    text: Translation.tr("Use old sine wave cookie implementation")
                    checked: Config.options.background.widgets.clock.cookie.useSineCookie
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.useSineCookie = checked;
                    }
                    StyledToolTip {
                        text: "Looks a bit softer and more consistent with different number of sides,\nbut has less impressive morphing"
                    }
                }

                ConfigSpinBox {
                    icon: "add_triangle"
                    text: Translation.tr("Sides")
                    value: Config.options.background.widgets.clock.cookie.sides
                    from: 0
                    to: 40
                    stepSize: 1
                    onValueChanged: {
                        Config.options.background.widgets.clock.cookie.sides = value;
                    }
                    StyledToolTip {
                        text: Translation.tr("Number of sides for the polygon shape")
                    }
                }

                SettingsSwitch {
                    buttonIcon: "autoplay"
                    text: Translation.tr("Constantly rotate")
                    checked: Config.options.background.widgets.clock.cookie.constantlyRotate
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.constantlyRotate = checked;
                    }
                    StyledToolTip {
                        text: "Makes the clock always rotate. This is extremely expensive\n(expect 50% usage on Intel UHD Graphics) and thus impractical."
                    }
                }

                ConfigRow {

                    SettingsSwitch {
                        enabled: Config.options.background.widgets.clock.style === "cookie" && Config.options.background.widgets.clock.cookie.dialNumberStyle === "dots" || Config.options.background.widgets.clock.cookie.dialNumberStyle === "full"
                        buttonIcon: "brightness_7"
                        text: Translation.tr("Hour marks")
                        checked: Config.options.background.widgets.clock.cookie.hourMarks
                        onEnabledChanged: {
                            checked = Config.options.background.widgets.clock.cookie.hourMarks;
                        }
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.hourMarks = checked;
                        }
                        StyledToolTip {
                            text: "Can only be turned on using the 'Dots' or 'Full' dial style for aesthetic reasons"
                        }
                    }

                    SettingsSwitch {
                        enabled: Config.options.background.widgets.clock.style === "cookie" && Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                        buttonIcon: "timer_10"
                        text: Translation.tr("Digits in the middle")
                        checked: Config.options.background.widgets.clock.cookie.timeIndicators
                        onEnabledChanged: {
                            checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                        }
                        onCheckedChanged: {
                            Config.options.background.widgets.clock.cookie.timeIndicators = checked;
                        }
                        StyledToolTip {
                            text: "Can't be turned on when using 'Numbers' dial style for aesthetic reasons"
                        }
                    }
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Dial style")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dialNumberStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dialNumberStyle = newValue;
                        if (newValue !== "dots" && newValue !== "full") {
                            Config.options.background.widgets.clock.cookie.hourMarks = false;
                        }
                        if (newValue === "numbers") {
                            Config.options.background.widgets.clock.cookie.timeIndicators = false;
                        }
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "none"
                        },
                        {
                            displayName: Translation.tr("Dots"),
                            icon: "graph_6",
                            value: "dots"
                        },
                        {
                            displayName: Translation.tr("Full"),
                            icon: "history_toggle_off",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Numbers"),
                            icon: "counter_1",
                            value: "numbers"
                        }
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Hour hand")
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.hourHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.hourHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Hollow"),
                            icon: "circle",
                            value: "hollow"
                        },
                        {
                            displayName: Translation.tr("Fill"),
                            icon: "eraser_size_5",
                            value: "fill"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Minute hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.minuteHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.minuteHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Thin"),
                            icon: "line_end",
                            value: "thin"
                        },
                        {
                            displayName: Translation.tr("Medium"),
                            icon: "eraser_size_2",
                            value: "medium"
                        },
                        {
                            displayName: Translation.tr("Bold"),
                            icon: "eraser_size_4",
                            value: "bold"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Second hand")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.secondHandStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.secondHandStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        },
                        {
                            displayName: Translation.tr("Line"),
                            icon: "line_end",
                            value: "line"
                        },
                        {
                            displayName: Translation.tr("Dot"),
                            icon: "adjust",
                            value: "dot"
                        },
                    ]
                }
            }

            ContentSubsection {
                visible: Config.options.background.widgets.clock.style === "cookie"
                title: Translation.tr("Date style")

                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.cookie.dateStyle
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.cookie.dateStyle = newValue;
                    }
                    options: [
                        {
                            displayName: "",
                            icon: "block",
                            value: "hide"
                        },
                        {
                            displayName: Translation.tr("Bubble"),
                            icon: "bubble_chart",
                            value: "bubble"
                        },
                        {
                            displayName: Translation.tr("Border"),
                            icon: "rotate_right",
                            value: "border"
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "rectangle",
                            value: "rect"
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Quote")

                SettingsSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.clock.quote.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.quote.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show a quote text widget below the clock")
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Quote")
                    text: Config.options.background.widgets.clock.quote.text
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.background.widgets.clock.quote.text = text;
                    }
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "cloud"
        title: Translation.tr("Widget: Weather")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                visible: !(Config.options?.bar?.weather?.enable ?? false)
                text: Translation.tr("Enable weather service first in Services → Weather")
                color: Appearance.colors.colTertiary
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            ConfigRow {
                Layout.fillWidth: true
                enabled: Config.options?.bar?.weather?.enable ?? false

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.weather.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.weather.enable = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Show the desktop weather widget")
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.weather.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.weather.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }
        }
    }

    SettingsCardSection {
        visible: root.isIiActive
        expanded: false
        icon: "album"
        title: Translation.tr("Widget: Media Controls")

        SettingsGroup {
            ConfigRow {
                Layout.fillWidth: true

                SettingsSwitch {
                    Layout.fillWidth: false
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.background.widgets.mediaControls.enable
                    onCheckedChanged: {
                        Config.options.background.widgets.mediaControls.enable = checked;
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ConfigSelectionArray {
                    Layout.fillWidth: false
                    currentValue: Config.options.background.widgets.mediaControls.placementStrategy
                    onSelected: newValue => {
                        Config.options.background.widgets.mediaControls.placementStrategy = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Draggable"),
                            icon: "drag_pan",
                            value: "free"
                        },
                        {
                            displayName: Translation.tr("Least busy"),
                            icon: "category",
                            value: "leastBusy"
                        },
                        {
                            displayName: Translation.tr("Most busy"),
                            icon: "shapes",
                            value: "mostBusy"
                        },
                    ]
                }
            }
            
            ContentSubsectionLabel {
                text: Translation.tr("Player Style")
            }
            
            ConfigRow {
                Layout.fillWidth: true
                
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: Config.options.background.widgets.mediaControls.playerPreset
                    onSelected: newValue => {
                        Config.options.background.widgets.mediaControls.playerPreset = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Full"),
                            icon: "featured_video",
                            value: "full"
                        },
                        {
                            displayName: Translation.tr("Compact"),
                            icon: "view_compact",
                            value: "compact"
                        },
                        {
                            displayName: Translation.tr("Album Art"),
                            icon: "image",
                            value: "albumart"
                        },
                        {
                            displayName: Translation.tr("Classic"),
                            icon: "radio",
                            value: "classic"
                        }
                    ]
                }
            }
        }
    }
}
