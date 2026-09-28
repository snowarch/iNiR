//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.iris.style
import qs.modules.iris.settings
import qs.modules.iris.preview
import qs.modules.iris.components as Iris
import qs.modules.waffle.looks

Scope {
    id: root
    property string firstRunFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property int currentStep: 0

    // ─── Responsive scale ───
    readonly property real screenWidth: focusedScreen?.width ?? 1920
    readonly property real screenHeight: focusedScreen?.height ?? 1080
    readonly property bool compact: screenHeight < 1000
    readonly property bool veryCompact: screenHeight < 720
    readonly property int screenPadding: veryCompact ? 12 : compact ? 24 : 60
    readonly property int cardPadding: compact ? 22 : 30
    readonly property real stepWidth: Math.max(0, wizardCard.width
        - 2 * (root.compact ? 22 : 28)
        - (root.irisFamily ? 2 * IrisStyle.concentricPad(IrisStyle.radiusPanel, 10) : 0))
    readonly property int totalSteps: 5
    property var focusedScreen: GlobalStates.primaryScreen
    readonly property real screenAspect: root.screenWidth / Math.max(1, root.screenHeight)

    property string requestedFamily: ""
    readonly property string family: root.requestedFamily.length > 0
        ? root.requestedFamily : (Config.options?.panelFamily ?? "ii")
    readonly property bool irisFamily: root.family === "iris"
    readonly property bool waffleFamily: root.family === "waffle"
    readonly property string familyTitle: root.irisFamily ? "iRiS" : root.waffleFamily ? "Waffle" : "Material II"

    // Onboarding follows the selected family, independently of ii's Global Style.
    readonly property color welcomeSurfaceRaised: root.irisFamily ? IrisStyle.surface
        : root.waffleFamily ? Looks.colors.bg0 : Appearance.m3colors.m3surfaceContainer
    readonly property color welcomeSurfaceHigh: root.irisFamily ? IrisStyle.surfaceHigh
        : root.waffleFamily ? Looks.colors.bg1Base : Appearance.m3colors.m3surfaceContainerHigh
    readonly property color welcomeSurfaceHighest: root.irisFamily ? IrisStyle.surfaceHighest
        : root.waffleFamily ? Looks.colors.bg2Base : Appearance.m3colors.m3surfaceContainerHighest
    readonly property color welcomeSurfaceRaisedHover: root.irisFamily ? IrisStyle.fillHover
        : root.waffleFamily ? Looks.colors.bg1Hover
        : ColorUtils.mix(welcomeSurfaceRaised, welcomeOnSurface, 0.94)
    readonly property color welcomeOnSurface: root.irisFamily ? IrisStyle.textStrong
        : root.waffleFamily ? Looks.colors.fg : Appearance.m3colors.m3onSurface
    readonly property color welcomeOnSurfaceVariant: root.irisFamily ? IrisStyle.textSecondary
        : root.waffleFamily ? Looks.colors.subfg : Appearance.m3colors.m3onSurfaceVariant
    readonly property color welcomeOutline: root.irisFamily ? IrisStyle.border
        : root.waffleFamily ? Looks.settings.strokeStrong : Appearance.m3colors.m3outlineVariant
    readonly property color welcomeScrim: Appearance.m3colors.m3scrim
    readonly property color welcomePrimary: root.irisFamily ? IrisStyle.accent
        : root.waffleFamily ? Looks.colors.accent : Appearance.m3colors.m3primary
    readonly property color welcomeOnPrimary: root.irisFamily ? IrisStyle.onAccent
        : root.waffleFamily ? Looks.colors.accentFg : Appearance.m3colors.m3onPrimary
    readonly property color welcomePrimaryContainer: root.irisFamily ? IrisStyle.tintFill(IrisStyle.accent)
        : root.waffleFamily ? ColorUtils.mix(Looks.colors.bg1Base, Looks.colors.accent, 0.84)
        : ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHigh,
            Appearance.m3colors.m3primaryContainer, 0.72)
    readonly property color welcomeOnPrimaryContainer: root.irisFamily ? IrisStyle.textStrong
        : root.waffleFamily ? Looks.colors.fg : Appearance.m3colors.m3onSurface
    readonly property color welcomeSecondary: root.irisFamily ? IrisStyle.secondaryAccent
        : root.waffleFamily ? Looks.colors.accentUnfocused : Appearance.m3colors.m3secondary
    readonly property color welcomeSecondaryContainer: root.irisFamily ? IrisStyle.fill
        : root.waffleFamily ? Looks.settings.tile : Appearance.m3colors.m3surfaceContainer
    readonly property color welcomeOnSecondaryContainer: root.irisFamily ? IrisStyle.textStrong
        : root.waffleFamily ? Looks.colors.fg : Appearance.m3colors.m3onSurface
    readonly property color welcomeTertiary: root.irisFamily ? IrisStyle.secondaryAccent
        : root.waffleFamily ? Looks.colors.accentUnfocused : Appearance.m3colors.m3tertiary
    readonly property color welcomeTertiaryContainer: root.irisFamily ? IrisStyle.tintFill(IrisStyle.secondaryAccent)
        : root.waffleFamily ? Looks.settings.tile
        : ColorUtils.mix(Appearance.m3colors.m3surfaceContainer,
            Appearance.m3colors.m3tertiaryContainer, 0.84)
    readonly property color welcomeOnTertiaryContainer: root.irisFamily ? IrisStyle.textStrong
        : root.waffleFamily ? Looks.colors.subfg : Appearance.m3colors.m3onSurfaceVariant
    // Wallpaper colour provides feedback without switching ii's wizard dialect.
    readonly property color welcomeAccent: welcomePrimary
    readonly property color welcomeAccentAlt: welcomeTertiary
    readonly property color welcomeAccentContainer: welcomePrimaryContainer
    readonly property color welcomeAccentHover: root.irisFamily ? IrisStyle.tintFillHover(IrisStyle.accent)
        : root.waffleFamily ? ColorUtils.mix(Looks.colors.bg1Hover, Looks.colors.accent, 0.80)
        : ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHighest,
            Appearance.m3colors.m3primaryContainer, 0.68)
    readonly property color welcomeOnAccent: welcomeOnPrimary
    readonly property color welcomeOnAccentContainer: welcomeOnPrimaryContainer
    readonly property color welcomeGuideContainer: welcomeTertiaryContainer
    readonly property color welcomeGuideText: welcomeOnTertiaryContainer
    readonly property string welcomeFontMain: root.irisFamily ? IrisStyle.fontMain
        : root.waffleFamily ? Looks.fontFamily
        : (Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex")
    readonly property string welcomeFontTitle: root.irisFamily ? IrisStyle.fontTitle
        : root.waffleFamily ? Looks.fontFamily
        : (Config.options?.appearance?.typography?.titleFont ?? "Gabarito")
    readonly property string welcomeFontNumbers: root.irisFamily ? IrisStyle.fontNumbers : "Rubik"
    readonly property string welcomeFontExpressive: "Space Grotesk"
    readonly property int welcomeFontMeta: Math.max(13, Appearance.font.pixelSize.smallest)
    readonly property int welcomeFontCaption: Math.max(14, Appearance.font.pixelSize.smaller)
    readonly property int welcomeFontBody: Math.max(15, Appearance.font.pixelSize.small)
    readonly property int welcomeFontSection: Math.max(17, Appearance.font.pixelSize.normal)
    readonly property color welcomeSecondaryText: ColorUtils.ensureReadable(
        welcomeOnSurfaceVariant, welcomeSurfaceRaised, 4.5)
    readonly property color welcomeTertiaryText: ColorUtils.ensureReadable(
        ColorUtils.applyAlpha(welcomeOnSurfaceVariant, 0.86), welcomeSurfaceRaised, 4.0)
    readonly property real welcomePanelRadius: root.irisFamily ? IrisStyle.radiusPanel
        : root.waffleFamily ? Looks.settings.radiusXLarge : 24
    readonly property real welcomeControlRadius: root.irisFamily ? IrisStyle.radiusRow
        : root.waffleFamily ? Looks.settings.radiusMedium : 12
    readonly property real welcomeChoiceRadius: root.irisFamily ? IrisStyle.radiusTile
        : root.waffleFamily ? Looks.settings.radiusLarge : 14
    readonly property real welcomeCardRadius: root.irisFamily ? IrisStyle.radiusPlate
        : root.waffleFamily ? Looks.settings.radiusLarge : 16

    readonly property string selectedProfile: Config.options?.welcomeWizard?.profile ?? "balanced"
    readonly property string selectedStylePreset: Config.options?.welcomeWizard?.stylePreset ?? "material"
    readonly property string selectedPerformancePreset: Config.options?.welcomeWizard?.performancePreset ?? "balanced"
    property bool profileCustomized: false
    property bool initialProfileApplied: false
    property bool initialPerformanceApplied: false
    property bool initialIrisDesktopApplied: false
    readonly property bool firstRunSetup: !(Config.options?.welcomeWizard?.completed ?? false)
        && !(Config.options?.welcomeWizard?.skipped ?? false)

    readonly property string selectedProfileTitle: selectedProfile === "minimum"
        ? Translation.tr("Minimum")
        : selectedProfile === "full" ? Translation.tr("Full") : Translation.tr("Balanced")
    readonly property string selectedProfileDescription: selectedProfile === "minimum"
        ? Translation.tr("Core bar, sidebars and local controls. No desktop widgets.")
        : selectedProfile === "full"
            ? Translation.tr("More local tools, richer sidebars and a small system monitor.")
            : Translation.tr("Useful sidebars, eight everyday toggles and one desktop clock.")
    readonly property var profileChoices: [
        { id: "minimum", name: Translation.tr("Minimum"), icon: "filter_1",
            detail: Translation.tr("Core controls with no desktop widgets.") },
        { id: "balanced", name: Translation.tr("Balanced"), icon: "tune", badge: Translation.tr("Recommended"),
            detail: Translation.tr("Sidebars, daily toggles and a desktop clock.") },
        { id: "full", name: Translation.tr("Full"), icon: "auto_awesome",
            detail: Translation.tr("More local tools, fuller sidebars and a system monitor.") }
    ]
    readonly property var stylePresets: [
        {
            id: "material", name: Translation.tr("Flow"), icon: "category",
            globalStyle: "material",
            description: Translation.tr("Clean Material surfaces with the M3 bar and dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "m3",
                "bar.m3.borderless": "pills",
                "bar.m3.showBackground": true,
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "m3",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "cookie", name: Translation.tr("Expressive"), icon: "interests",
            globalStyle: "cookie",
            description: Translation.tr("Playful shapes, joined controls and a pill dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "pill",
                "bar.pill.barMode": false,
                "bar.pill.musicViz": false,
                "bar.pill.soul.enable": true,
                "bar.pill.soul.style": "orb",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "pill",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "aurora", name: Translation.tr("Glass"), icon: "blur_on",
            globalStyle: "aurora",
            description: Translation.tr("Translucent islands for the bar, dock and sidebars."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "islands",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "island",
                "dock.showBackground": true,
                "sidebar.style": "island"
            }
        },
        {
            id: "inir", name: "iNiR", icon: "terminal",
            globalStyle: "inir",
            description: Translation.tr("Sharp framed surfaces with a denser, technical feel."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "frame",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "cards", name: Translation.tr("Cards"), icon: "branding_watermark",
            globalStyle: "cards",
            description: Translation.tr("Soft rounded cards with familiar desktop structure."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "angel", name: Translation.tr("Angel"), icon: "raven",
            globalStyle: "angel",
            description: Translation.tr("Scenic glass, strong accents and a pill dock."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "appearance.angelSubStyle": "frost",
                "bar.appearanceStyle": "scenic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "pill",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "regalia", name: Translation.tr("Regalia"), icon: "event_seat",
            globalStyle: "regalia",
            description: Translation.tr("Structured surfaces, a classic bar and a macOS-style dock."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "macos",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "zzz", name: "ZZZ", icon: "bolt",
            globalStyle: "zzz",
            description: Translation.tr("Poster-like surfaces with bold graphic contrast."),
            values: {
                "appearance.iiMotionProfile": "classic",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        },
        {
            id: "editorial", name: Translation.tr("Editorial"), icon: "auto_stories",
            globalStyle: "editorial",
            description: Translation.tr("Quiet paper-like surfaces led by typography."),
            values: {
                "appearance.iiMotionProfile": "contextual",
                "bar.appearanceStyle": "classic",
                "bar.showBackground": true,
                "bar.opacity": 1.0,
                "dock.style": "panel",
                "dock.showBackground": true,
                "sidebar.style": "panel"
            }
        }
    ]

    readonly property var performancePresets: [
        {
            id: "minimum", name: Translation.tr("Save power"), icon: "energy_savings_leaf",
            description: Translation.tr("Cuts heavy effects and reduces motion for battery-first or lower-end systems."),
            values: {
                "performance.lowPower": true,
                "performance.reduceAnimations": true,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": false,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        },
        {
            id: "efficient", name: Translation.tr("Fewer effects"), icon: "speed",
            description: Translation.tr("Keeps normal motion while avoiding expensive blur."),
            values: {
                "performance.lowPower": false,
                "performance.reduceAnimations": false,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": false,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        },
        {
            id: "balanced", name: Translation.tr("Full style"), icon: "tune",
            description: Translation.tr("Uses the selected style's full motion and effects. Game Mode can still scale them back."),
            values: {
                "performance.lowPower": false,
                "performance.reduceAnimations": false,
                "performance.blurBackend": "auto",
                "performance.compositorBlur": true,
                "performance.blurAreas.bar": "inherit",
                "performance.blurAreas.dock": "inherit",
                "performance.blurAreas.panels": "inherit",
                "performance.blurAreas.islands": "inherit",
                "performance.blurAreas.widgets": "inherit"
            }
        }
    ]

    function presetById(list: var, id: string): var {
        return list.find(preset => preset.id === id) ?? list[0]
    }

    function valuesMatch(values: var): bool {
        const keys = Object.keys(values ?? {})
        for (const key of keys) {
            const current = Config.getNestedValue(key, undefined)
            if (JSON.stringify(current) !== JSON.stringify(values[key]))
                return false
        }
        return true
    }

    function flowM3Layout(profile: string): var {
        if (profile === "minimum")
            return {
                "bar.m3.layoutMode": "custom",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["clockWidget", "systemIcons", "rightSidebarButton"]
            }
        return {
            "bar.m3.layoutMode": "compact",
            "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
            "bar.m3.layouts.middleLayout": ["docktoPanel"],
            "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"]
        }
    }

    function stylePresetMatches(id: string): bool {
        const preset = root.presetById(root.stylePresets, id)
        return (Config.options?.appearance?.globalStyle ?? "material") === preset.globalStyle
            && root.valuesMatch(preset.values)
            && (id !== "material" || root.valuesMatch(root.flowM3Layout(root.selectedProfile)))
    }

    function performancePresetMatches(id: string): bool {
        return root.valuesMatch(root.presetById(root.performancePresets, id).values)
    }

    readonly property string effectiveStylePreset: root.stylePresetMatches(root.selectedStylePreset)
        ? root.selectedStylePreset : "custom"
    readonly property string effectivePerformancePreset: root.performancePresetMatches(root.selectedPerformancePreset)
        ? root.selectedPerformancePreset : "custom"
    readonly property var currentStylePreset: root.presetById(root.stylePresets, root.selectedStylePreset)
    readonly property var currentPerformancePreset: root.presetById(root.performancePresets, root.selectedPerformancePreset)
    readonly property string currentStylePresetDescription: root.effectiveStylePreset === "custom"
        ? Translation.tr("Your current settings mix styles. Pick a preset to bring the shell back into sync.")
        : root.currentStylePreset.description
    readonly property string currentPerformancePresetDescription: root.effectivePerformancePreset === "custom"
        ? Translation.tr("Your effects settings are custom. Pick a mode to restore a matched setup.")
        : root.currentPerformancePreset.description

    // Every starting profile prepares shared services and the Material II
    // family. Waffle keeps its independent `waffles.*` configuration intact,
    // so switching families never erases or silently reconfigures it.
    readonly property var profileEssentials: ({
        "dock.enable": true,
        "dock.hoverToReveal": false,
        "dock.pinnedOnStartup": true,
        "dashboard.enable": true,
        "bar.weather.enable": true,
        "bar.modules.weather": true,
        "bar.modules.battery": true,
        "bar.modules.sysTray": true,
        "bar.modules.clock": true,
        "bar.modules.workspaces": true,
        "bar.modules.activeWindow": true,
        "bar.modules.leftSidebarButton": true,
        "bar.modules.rightSidebarButton": true,
        "sounds.notifications": true,
        "gameMode.autoDetect": true,
        "audio.protection.enable": true,
        "sidebar.collapseEmptyNotifications": false,
        "sidebar.collapseWidgetsTab": false,
        "sidebar.right.headerBanner": "wallpaper",
        "sidebar.right.sectionOrder": ["system", "sliders", "toggles", "notifications", "widgets"],
        "sidebar.quickToggles.style": "android",
        "sidebar.quickToggles.android.columns": 4,
        // Material II's embedded bar taskbar duplicates the Material II dock.
        // Waffle owns a separate taskbar under `waffles.bar.*` and is unaffected.
        "bar.modules.taskbar": false
    })

    // Ordering only; no profile enables a provider-backed tab.
    readonly property var profileTabOrder: [
        "widgets", "wallhaven", "news", "tools", "software",
        "ai", "translator", "anime", "animeSchedule", "ytmusic"
    ]

    // Desktop widgets all default to the same corner and "leastBusy" cannot see
    // a sibling, so a profile composing more than one must place them by hand.
    function profileComposition(profile: string): var {
        if (profile === "minimum")
            return {
                "bar.modules.resources": false,
                "bar.modules.utilButtons": false,
                "bar.modules.media": false,
                "bar.m3.layoutMode": "custom",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["clockWidget", "systemIcons", "rightSidebarButton"],
                "sidebar.news.enable": false,
                "sidebar.wallhaven.enable": false,
                "sidebar.ytmusic.enable": false,
                "sidebar.tools.enable": false,
                "sidebar.software.enable": false,
                "sidebar.widgets.context": true,
                "sidebar.widgets.week": true,
                "sidebar.widgets.media": true,
                "sidebar.widgets.controls": false,
                "sidebar.widgets.status": false,
                "sidebar.widgets.wallpaper": true,
                "sidebar.widgets.note": false,
                "sidebar.widgets.launch": false,
                "sidebar.widgets.worldClock": false,
                "sidebar.right.enabledWidgets": ["calendar", "todo"],
                "sidebar.quickToggles.android.toggles": [
                    { "size": 1, "type": "network" },
                    { "size": 1, "type": "bluetooth" },
                    { "size": 1, "type": "audio" },
                    { "size": 1, "type": "mic" }
                ],
                "background.widgets.clock.enable": false,
                "background.widgets.clock.quote.enable": false,
                "background.widgets.visualizer.enable": false,
                "background.widgets.systemMonitor.enable": false,
                "background.widgets.weather.enable": false,
                "background.widgets.battery.enable": false,
                "background.widgets.mediaControls.enable": false,
                "background.widgets.calendarUpcoming.enable": false,
                "mascot.enable": false
            }
        if (profile === "full")
            return {
                "bar.modules.resources": true,
                "bar.modules.utilButtons": true,
                "bar.modules.media": true,
                "bar.m3.layoutMode": "compact",
                "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
                "bar.m3.layouts.middleLayout": ["docktoPanel"],
                "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"],
                "sidebar.news.enable": true,
                "sidebar.wallhaven.enable": true,
                "sidebar.ytmusic.enable": true,
                "sidebar.tools.enable": true,
                "sidebar.software.enable": true,
                "sidebar.widgets.context": true,
                "sidebar.widgets.week": true,
                "sidebar.widgets.media": true,
                "sidebar.widgets.controls": true,
                "sidebar.widgets.status": true,
                "sidebar.widgets.wallpaper": true,
                "sidebar.widgets.note": true,
                "sidebar.widgets.launch": true,
                "sidebar.widgets.worldClock": true,
                "sidebar.right.enabledWidgets": [
                    "calendar", "events", "todo", "notepad",
                    "calculator", "sysmon", "weather", "timer"
                ],
                "sidebar.quickToggles.android.toggles": [
                    { "size": 1, "type": "network" },
                    { "size": 1, "type": "bluetooth" },
                    { "size": 1, "type": "audio" },
                    { "size": 1, "type": "mic" },
                    { "size": 1, "type": "nightLight" },
                    { "size": 1, "type": "screenSnip" },
                    { "size": 1, "type": "colorPicker" },
                    { "size": 1, "type": "idleInhibitor" }
                ],
                "background.widgets.clock.enable": true,
                "background.widgets.clock.placementStrategy": "topRight",
                "background.widgets.clock.quote.enable": false,
                "background.widgets.visualizer.enable": false,
                "background.widgets.clock.backgroundOpacity": 0,
                "background.widgets.clock.borderOpacity": 0.08,
                "background.widgets.systemMonitor.enable": true,
                "background.widgets.systemMonitor.placementStrategy": "bottomRight",
                "background.widgets.weather.enable": false,
                "background.widgets.battery.enable": false,
                "background.widgets.mediaControls.enable": false,
                "background.widgets.calendarUpcoming.enable": false,
                "mascot.enable": false
            }
        return {
            "bar.modules.resources": true,
            "bar.modules.utilButtons": true,
            "bar.modules.media": true,
            "bar.m3.layoutMode": "compact",
            "bar.m3.layouts.leftLayout": ["leftSidebarButton", "media", "workspaces"],
            "bar.m3.layouts.middleLayout": ["docktoPanel"],
            "bar.m3.layouts.rightLayout": ["utilButtons", "weatherBar", "clockWidget", "systemIcons", "rightSidebarButton"],
            "sidebar.news.enable": true,
            "sidebar.wallhaven.enable": true,
            "sidebar.ytmusic.enable": false,
            "sidebar.tools.enable": false,
            "sidebar.software.enable": false,
            "sidebar.widgets.context": true,
            "sidebar.widgets.week": true,
            "sidebar.widgets.media": true,
            "sidebar.widgets.controls": true,
            "sidebar.widgets.status": true,
            "sidebar.widgets.wallpaper": true,
            "sidebar.widgets.note": false,
            "sidebar.widgets.launch": false,
            "sidebar.widgets.worldClock": false,
            "sidebar.right.enabledWidgets": [
                "calendar", "events", "todo", "notepad", "weather"
            ],
            "sidebar.quickToggles.android.toggles": [
                { "size": 1, "type": "network" },
                { "size": 1, "type": "bluetooth" },
                { "size": 1, "type": "audio" },
                { "size": 1, "type": "mic" },
                { "size": 1, "type": "nightLight" },
                { "size": 1, "type": "screenSnip" },
                { "size": 1, "type": "colorPicker" },
                { "size": 1, "type": "idleInhibitor" }
            ],
            // One widget is enough for a fresh desktop, and a named zone keeps
            // the placement deterministic across common output sizes.
            "background.widgets.clock.enable": true,
            "background.widgets.clock.placementStrategy": "topRight",
            "background.widgets.clock.quote.enable": false,
            "background.widgets.clock.backgroundOpacity": 0,
            "background.widgets.clock.borderOpacity": 0.08,
            "background.widgets.visualizer.enable": false,
            "background.widgets.systemMonitor.enable": false,
            "background.widgets.weather.enable": false,
            "background.widgets.battery.enable": false,
            "background.widgets.mediaControls.enable": false,
            "background.widgets.calendarUpcoming.enable": false,
            "mascot.enable": false
        }
    }

    function applyProfile(profile: string): void {
        Config.setNestedValues(Object.assign({},
            root.profileEssentials,
            root.profileComposition(profile), {
                "sidebar.left.tabOrder": root.profileTabOrder,
                "welcomeWizard.profile": profile
            }))
        root.profileCustomized = false
    }

    function applyStylePreset(id: string): void {
        const preset = root.presetById(root.stylePresets, id)
        ThemeService.setGlobalStyle(preset.globalStyle)
        const flowLayout = id === "material" ? root.flowM3Layout(root.selectedProfile) : {}
        Config.setNestedValues(Object.assign({}, preset.values, flowLayout, {
            "welcomeWizard.stylePreset": preset.id
        }))
    }

    function applyPerformancePreset(id: string): void {
        const preset = root.presetById(root.performancePresets, id)
        Config.setNestedValues(Object.assign({}, preset.values, {
            "welcomeWizard.performancePreset": preset.id
        }))
    }

    function setProfileFeature(path: string, value: var): void {
        root.profileCustomized = true
        Config.setNestedValue(path, value)
    }

    function chooseFamily(id: string): void {
        root.requestedFamily = id
        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "panelFamily", "set", id])
    }

    readonly property var irisArrangements: [
        {
            id: "signature", name: Translation.tr("Signature"), icon: "crop_free",
            badge: Translation.tr("Recommended"),
            description: Translation.tr("Island attached to its edge, Surround on, Dock opposite."),
            values: {
                "iris.bar.layout": "island",
                "iris.bar.notch": true,
                "iris.surround.enable": true,
                "iris.bar.composition": "cluster",
                "iris.dock.enable": true,
                "iris.dock.position": "auto",
                "iris.dock.notch": true
            }
        },
        {
            id: "floating", name: Translation.tr("Floating"), icon: "layers",
            description: Translation.tr("Island and Dock float above the wallpaper."),
            values: {
                "iris.bar.layout": "island",
                "iris.bar.notch": false,
                "iris.surround.enable": false,
                "iris.bar.composition": "cluster",
                "iris.dock.enable": true,
                "iris.dock.position": "auto",
                "iris.dock.notch": false
            }
        },
        {
            id: "full", name: Translation.tr("Full bar"), icon: "width_full",
            description: Translation.tr("Island spans the edge with start, center and end zones."),
            values: {
                "iris.bar.layout": "full",
                "iris.bar.notch": true,
                "iris.surround.enable": false,
                "iris.bar.composition": "unified",
                "iris.dock.enable": true,
                "iris.dock.position": "auto",
                "iris.dock.notch": false
            }
        }
    ]
    readonly property var irisWelcomeThemeIds: [
        "iris", "liquid-glass", "frost", "aurora", "terminal", "adaptive"
    ]
    readonly property var irisWelcomeThemes: IrisThemes.curated.filter(
        theme => root.irisWelcomeThemeIds.includes(theme.id))

    readonly property string effectiveIrisArrangement: {
        for (const arrangement of root.irisArrangements) {
            if (root.valuesMatch(arrangement.values))
                return arrangement.id
        }
        return "custom"
    }
    readonly property var currentIrisArrangement: root.presetById(root.irisArrangements,
        root.effectiveIrisArrangement)
    readonly property string irisLook: Config.options?.iris?.appearance?.preset ?? "iris"
    readonly property string irisMaterial: Config.options?.iris?.appearance?.theme?.surface ?? "black"
    readonly property string irisAccent: Config.options?.iris?.appearance?.accent ?? "blue"

    readonly property var irisDesktopDefaults: ({
        "background.effects.enableBlur": false,
        "background.effects.dim": 0,
        "background.effects.dynamicDim": 0
    })

    function applyIrisArrangement(id: string): void {
        Config.setNestedValues(root.presetById(root.irisArrangements, id).values)
    }

    function applyIrisTheme(id: string): void {
        const theme = IrisThemes.find(id)
        if (theme) IrisThemes.apply(theme)
    }

    onCurrentStepChanged: {
        if (!root.firstRunSetup)
            return
        if (root.currentStep === 1) {
            if (!root.irisFamily && !root.initialProfileApplied) {
                root.initialProfileApplied = true
                root.applyProfile(root.selectedProfile)
            }
            if (root.irisFamily && !root.initialIrisDesktopApplied) {
                root.initialIrisDesktopApplied = true
                Config.setNestedValues(root.irisDesktopDefaults)
            }
            if (!root.initialPerformanceApplied) {
                root.initialPerformanceApplied = true
                root.applyPerformancePreset(root.selectedPerformancePreset)
            }
        }
    }

    // ─── Entry/exit animation state (gate pattern) ───
    property bool _entryReady: false
    property bool _contentReady: false
    property bool _closing: false

    // The starting point runs before Appearance and Layout: a profile writes
    // composition keys wholesale and would overwrite anything refined earlier.
    readonly property var steps: [
        {
            icon: "waving_hand", title: Translation.tr("Welcome"),
            headline: Translation.tr("Welcome to iNiR"),
            subtitle: Translation.tr("Pick the desktop you want to start with. The next steps adapt to it.")
        },
        {
            icon: "tune", title: Translation.tr("Starting point"),
            headline: root.irisFamily ? Translation.tr("Choose an iRiS layout")
                : Translation.tr("Choose your starting setup"),
            subtitle: root.irisFamily
                ? Translation.tr("Signature, floating, or a full bar.")
                : Translation.tr("Start simple, balanced or with more tools. You can change every module later.")
        },
        {
            icon: "palette", title: Translation.tr("Appearance"),
            headline: root.irisFamily ? Translation.tr("Choose an iRiS theme")
                : Translation.tr("Make it yours"),
            subtitle: root.irisFamily
                ? Translation.tr("Themes set material, shape, type and motion together.")
                : root.waffleFamily
                    ? Translation.tr("Wallpaper sets the colors across the shell and your apps.")
                    : Translation.tr("Wallpaper sets the colors. Style sets the shape and feel.")
        },
        {
            icon: "dashboard", title: Translation.tr("Layout"),
            headline: Translation.tr("Arrange the desktop"),
            subtitle: root.irisFamily
                ? Translation.tr("Set the Island edge, Dock and desktop widgets.")
                : root.waffleFamily
                    ? Translation.tr("Choose where the taskbar sits and how it lines up apps.")
                    : Translation.tr("Choose where the bar and dock go.")
        },
        {
            icon: "celebration", title: Translation.tr("Ready"),
            headline: Translation.tr("You're all set"),
            subtitle: Translation.tr("A few shortcuts and actions to get you moving.")
        }
    ]

    function finish(skipped: bool): void {
        if (root._closing) return
        root._closing = true
        // Write config keys
        Config.setNestedValue("welcomeWizard.completed", !skipped)
        Config.setNestedValue("welcomeWizard.skipped", skipped)
        // Reverse the entry animation
        root._contentReady = false
        root._entryReady = false
        _exitTimer.start()
    }

    Timer {
        id: _exitTimer
        interval: Appearance.animationsEnabled ? 400 : 0
        repeat: false
        onTriggered: {
            // first_run.txt is already written by FirstRunExperience before launching us
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Welcome to inir"), Translation.tr("Press Super+/ for all keyboard shortcuts."), "-a", "Shell"])
            Qt.quit()
        }
    }

    Component.onCompleted: {
        Quickshell.watchFiles = false
        MaterialThemeLoader.reapplyTheme()
        Config.readWriteDelay = 0
        // Staggered entry: scrim first, then card content
        if (Appearance.animationsEnabled) {
            _entryTimer.start()
        } else {
            root._entryReady = true
            root._contentReady = true
        }
    }

    Timer {
        id: _entryTimer
        interval: 80
        repeat: false
        onTriggered: {
            root._entryReady = true
            _contentEntryTimer.start()
        }
    }
    Timer {
        id: _contentEntryTimer
        interval: 120
        repeat: false
        onTriggered: root._contentReady = true
    }

    component WelcomeMetric: Item {
        id: metric

        property string value: "—"
        property string label: ""
        property color accent: root.welcomeAccent

        implicitHeight: 58

        RowLayout {
            anchors.fill: parent
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 3
                Layout.preferredHeight: 34
                radius: 2
                color: metric.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -1

                WelcomeText {
                    Layout.fillWidth: true
                    text: metric.value
                    font.family: root.welcomeFontNumbers
                    font.pixelSize: Appearance.font.pixelSize.huge * 1.12
                    font.weight: Font.Bold
                    color: metric.accent
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: metric.label
                    font.pixelSize: root.welcomeFontMeta
                    font.weight: Font.Medium
                    color: root.welcomeSecondaryText
                    elide: Text.ElideRight
                }
            }
        }
    }


    component WelcomeText: StyledText {
        defaultFont: root.welcomeFontMain
        font.letterSpacing: 0
        font.variableAxes: ({})
    }

    component WelcomeIrisFill: Rectangle {
        anchors.fill: parent
        visible: root.irisFamily
        radius: IrisStyle.radiusPlate
        color: IrisStyle.fillQuiet
        border.width: 0
    }

    component WelcomeActionButton: RippleButton {
        id: actionButton

        property string label: ""
        property string materialIcon: ""
        property bool primary: false

        implicitWidth: actionContent.implicitWidth + 24
        implicitHeight: 42
        buttonRadius: root.welcomeControlRadius
        rippleEnabled: true
        cookieMorphing: false
        colBackground: primary ? root.welcomeAccent : "transparent"
        colBackgroundHover: primary
            ? ColorUtils.mix(root.welcomeAccent, root.welcomeOnAccent, 0.88)
            : root.welcomeSurfaceHigh
        colRipple: primary
            ? ColorUtils.applyAlpha(root.welcomeOnAccent, 0.22)
            : root.welcomeSurfaceHighest

        contentItem: RowLayout {
            id: actionContent
            anchors.centerIn: parent
            spacing: actionButton.materialIcon.length > 0 ? 6 : 0

            MaterialSymbol {
                visible: actionButton.materialIcon.length > 0
                text: actionButton.materialIcon
                iconSize: 17
                color: actionButton.primary ? root.welcomeOnAccent : root.welcomeAccent
            }

            WelcomeText {
                text: actionButton.label
                font.family: root.welcomeFontTitle
                font.pixelSize: root.welcomeFontBody
                font.weight: actionButton.primary ? Font.Bold : Font.Medium
                color: actionButton.primary ? root.welcomeOnAccent : root.welcomeOnSurface
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    component WelcomeSegmentedControl: RowLayout {
        id: segmented

        property var options: []
        property var currentValue: null
        signal selected(var value)

        spacing: 6

        Repeater {
            model: segmented.options

            RippleButton {
                id: segmentButton
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 36
                readonly property bool active: segmented.currentValue != null
                    && segmented.currentValue == modelData.value
                buttonRadius: root.welcomeControlRadius
                rippleEnabled: true
                cookieMorphing: false
                colBackground: active ? root.welcomeAccentContainer
                    : root.irisFamily ? IrisStyle.fill : root.welcomeSurfaceRaised
                colBackgroundHover: active ? root.welcomeAccentHover : root.welcomeSurfaceHigh
                colRipple: root.welcomeSurfaceHighest
                onClicked: segmented.selected(modelData.value)

                contentItem: Item {
                    WelcomeText {
                        anchors.centerIn: parent
                        text: segmentButton.modelData.displayName
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontCaption
                        font.weight: segmentButton.active ? Font.Bold : Font.Medium
                        color: segmentButton.active ? root.welcomeOnSurface : root.welcomeSecondaryText
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MaterialSymbol {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: segmentButton.modelData.icon || ""
                        iconSize: 15
                        color: segmentButton.active ? root.welcomeAccent : root.welcomeSecondaryText
                    }
                }
            }
        }
    }

    component WelcomeKey: Rectangle {
        id: keyCap
        property string key: ""

        implicitWidth: keyLabel.implicitWidth + 14
        implicitHeight: 24
        radius: root.irisFamily ? IrisStyle.radiusChip : 7
        color: root.welcomeSurfaceHighest
        border.width: 1
        border.color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)

        WelcomeText {
            id: keyLabel
            anchors.centerIn: parent
            text: keyCap.key
            font.family: root.welcomeFontMain
            font.pixelSize: root.welcomeFontMeta
            font.weight: Font.Medium
            color: root.welcomeOnSurface
        }
    }

    component WelcomeListAction: RippleButton {
        id: listAction

        property string materialIcon: ""
        property string title: ""
        property string subtitle: ""

        implicitHeight: 46
        buttonRadius: root.welcomeControlRadius
        rippleEnabled: true
        cookieMorphing: false
        colBackground: root.irisFamily ? IrisStyle.fill : root.welcomeSurfaceRaised
        colBackgroundHover: root.welcomeSurfaceHigh
        colRipple: root.welcomeSurfaceHighest

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            MaterialSymbol {
                text: listAction.materialIcon
                iconSize: 18
                color: root.welcomeAccent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                WelcomeText {
                    Layout.fillWidth: true
                    text: listAction.title
                    font.family: root.welcomeFontTitle
                    font.pixelSize: root.welcomeFontBody
                    font.weight: Font.DemiBold
                    color: root.welcomeOnSurface
                    elide: Text.ElideRight
                }
                WelcomeText {
                    Layout.fillWidth: true
                    text: listAction.subtitle
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    elide: Text.ElideRight
                }
            }

            MaterialSymbol {
                text: "arrow_forward"
                iconSize: 16
                color: root.welcomeSecondaryText
                opacity: 0.7
            }
        }
    }

    PanelWindow {
        id: wizardPanel
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:welcome"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root._closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
        anchors { top: true; bottom: true; left: true; right: true }
        implicitWidth: root.focusedScreen?.width ?? 1920
        implicitHeight: root.focusedScreen?.height ?? 1080

        // Keep the live desktop readable behind onboarding. Re-rendering and blurring
        // the wallpaper hid the bar/dock changes being configured and paid a full-screen
        // GPU cost for no useful first-run information.
        Item {
            id: scrim
            anchors.fill: parent
            opacity: root._entryReady ? 1.0 : 0.0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(320)
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                color: root.welcomeScrim
                opacity: 0.28
            }
        }

        // Click outside does NOT dismiss — just absorb clicks
        MouseArea {
            anchors.fill: parent
        }

        // Main wizard card: one stable onboarding frame. Page content follows the
        // same flat sections, dense rows and selective tonal groups used by iNiR.
        Item {
            id: wizardCard
            readonly property real preferredHeight: root.currentStep === 4 ? (root.compact ? 720 : 770)
                : root.currentStep === 0 ? (root.compact ? 660 : 720)
                : (root.compact ? 690 : 750)
            anchors.centerIn: parent
            width: Math.max(360, Math.min(1120,
                root.screenWidth - 2 * root.screenPadding))
            height: Math.max(360, Math.min(root.screenHeight - 2 * root.screenPadding,
                preferredHeight))
            focus: true

            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            transformOrigin: Item.Center
            scale: root._contentReady ? 1.0 : 0.96
            opacity: root._contentReady ? 1.0 : 0.0
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.calcEffectiveDuration(260)
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(220); easing.type: Easing.OutCubic }
            }

            Keys.onEscapePressed: root.finish(true)
            Keys.onLeftPressed: if (root.currentStep > 0) root.currentStep--
            Keys.onRightPressed: if (root.currentStep < root.totalSteps - 1) root.currentStep++
            Keys.onReturnPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
            Keys.onEnterPressed: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)

            PanelSurface {
                id: cardBg
                visible: !root.irisFamily
                anchors.fill: parent
                surfaceDialect: "material"
                elevation: 1
                borderless: root.irisFamily
                opaqueSurface: true
                cardStyle: true
                outlined: true
                radiusOverride: root.welcomePanelRadius
                clipContent: true

            }

            Iris.IrisMorphSurface {
                anchors.fill: parent
                visible: root.irisFamily
                open: root._contentReady
                radius: IrisStyle.radiusPanel
                color: IrisStyle.surfaceHigh
                light: IrisStyle.wallpaperLight
                motionSurface: "settings"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.irisFamily ? IrisStyle.concentricPad(IrisStyle.radiusPanel, 10) : 0
                spacing: 0

                // First-run navigation follows the same quiet tab grammar used
                // across Settings: labels and glyphs sit on the field, and the
                // active step is carried by one short accent rule.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 58 : 66

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.compact ? 16 : 22
                        anchors.rightMargin: root.compact ? 14 : 20
                        spacing: root.compact ? 6 : 10

                        RowLayout {
                            Layout.preferredWidth: wizardCard.width >= 820 ? 138 : 46
                            spacing: 9
                            Iris.IrisMark {
                                visible: root.irisFamily
                                implicitSize: 30
                            }
                            MaterialSymbol {
                                visible: !root.irisFamily
                                text: "deployed_code"
                                iconSize: 26
                                color: root.welcomeAccent
                            }
                            ColumnLayout {
                                visible: wizardCard.width >= 820
                                spacing: 0
                                WelcomeText {
                                    text: "iNiR"
                                    font.family: root.welcomeFontTitle
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: root.welcomeOnSurface
                                }
                                WelcomeText {
                                    text: Translation.tr("Setup")
                                    font.pixelSize: root.welcomeFontMeta
                                    color: root.welcomeSecondaryText
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Repeater {
                                model: root.steps

                                RippleButton {
                                    id: stepTab
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitHeight: root.compact ? 44 : 48
                                    enabled: index <= root.currentStep
                                    opacity: enabled ? 1 : 0.62
                                    buttonRadius: 10
                                    colBackground: index === root.currentStep
                                        ? root.welcomeAccentContainer
                                        : "transparent"
                                    colBackgroundHover: index === root.currentStep
                                        ? root.welcomeAccentHover
                                        : root.welcomeSurfaceHigh
                                    colRipple: root.welcomeSurfaceHighest
                                    onClicked: root.currentStep = index

                                    contentItem: Item {
                                        WelcomeText {
                                            id: stepLabel
                                            anchors.centerIn: parent
                                            visible: wizardCard.width >= 860
                                            text: stepTab.modelData.title
                                            font.family: root.welcomeFontTitle
                                            font.pixelSize: root.welcomeFontCaption
                                            font.weight: stepTab.index === root.currentStep ? Font.Bold : Font.Medium
                                            color: stepTab.index === root.currentStep
                                                ? root.welcomeOnSurface : root.welcomeSecondaryText
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            elide: Text.ElideRight
                                        }

                                        MaterialSymbol {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: stepLabel.visible
                                                ? Math.max(7, stepLabel.x - width - 6)
                                                : Math.round((parent.width - width) / 2)
                                            text: stepTab.index < root.currentStep ? "check" : stepTab.modelData.icon
                                            iconSize: 15
                                            color: stepTab.index === root.currentStep
                                                ? root.welcomeAccent
                                                : stepTab.index < root.currentStep
                                                    ? root.welcomeAccent
                                                    : root.welcomeSecondaryText
                                        }

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: stepTab.index === root.currentStep ? Math.min(parent.width - 18, 58) : 0
                                            height: 2
                                            radius: 1
                                            color: root.welcomeAccent
                                            Behavior on width {
                                                enabled: Appearance.animationsEnabled
                                                NumberAnimation {
                                                    duration: Appearance.animation.elementResize.duration
                                                    easing.type: Appearance.animation.elementResize.type
                                                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        RippleButton {
                            id: skipButton
                            visible: root.currentStep < root.totalSteps - 1
                            implicitWidth: skipContent.implicitWidth + 16
                            implicitHeight: 34
                            buttonRadius: 10
                            colBackground: "transparent"
                            colBackgroundHover: root.welcomeSurfaceHigh
                            colRipple: root.welcomeSurfaceHighest
                            onClicked: root.finish(true)

                            contentItem: RowLayout {
                                id: skipContent
                                anchors.centerIn: parent
                                spacing: 5
                                WelcomeText {
                                    visible: wizardCard.width >= 760
                                    text: Translation.tr("Skip setup")
                                    font.pixelSize: root.welcomeFontMeta
                                    color: root.welcomeSecondaryText
                                }
                                MaterialSymbol {
                                    text: "close"
                                    iconSize: 14
                                    color: root.welcomeSecondaryText
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: root.compact ? 22 : 28
                    Layout.rightMargin: root.compact ? 22 : 28
                    Layout.topMargin: root.compact ? 14 : 18
                    Layout.bottomMargin: root.compact ? 10 : 14
                    spacing: root.compact ? 10 : 13

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 18

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.steps[root.currentStep].headline
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.irisFamily ? 26 * IrisStyle.typeScale
                                    : root.compact ? 28 : 32
                                font.weight: Font.Bold
                                font.letterSpacing: -0.42
                                color: root.welcomeOnSurface
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                visible: !root.veryCompact
                                text: root.steps[root.currentStep].subtitle
                                font.pixelSize: root.welcomeFontBody
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }

                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        StackLayout {
                            id: stepStack
                            anchors.fill: parent
                            currentIndex: root.currentStep
                            property int prevStep: 0

                            onCurrentIndexChanged: {
                                stepTranslate.x = currentIndex > prevStep ? 18 : -18
                                stepFade.restart()
                                prevStep = currentIndex
                            }

                            transform: Translate { id: stepTranslate; x: 0 }
                            opacity: 1

                            SequentialAnimation {
                                id: stepFade
                                ParallelAnimation {
                                    NumberAnimation { target: stepStack; property: "opacity"; from: 0.55; to: 1; duration: 190; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: stepTranslate; property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
                                }
                            }

                            Item { WelcomeContent { id: welcomePage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: welcomePage; visible: welcomePage.contentHeight > welcomePage.height } }
                            Item {
                                FeaturesContent { id: featuresPage; visible: !root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                IrisStartContent { id: irisStartPage; visible: root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                ScrollEdgeFade { target: root.irisFamily ? irisStartPage : featuresPage; visible: target.contentHeight > target.height }
                            }
                            Item {
                                ThemeContent { id: themePage; visible: !root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                IrisAppearanceContent { id: irisAppearancePage; visible: root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                ScrollEdgeFade { target: root.irisFamily ? irisAppearancePage : themePage; visible: target.contentHeight > target.height }
                            }
                            Item {
                                LayoutContent { id: layoutPage; visible: !root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                IrisLayoutContent { id: irisLayoutPage; visible: root.irisFamily; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                ScrollEdgeFade { target: root.irisFamily ? irisLayoutPage : layoutPage; visible: target.contentHeight > target.height }
                            }
                            Item { ReadyContent { id: readyPage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } }
                        }
                    }
                }

                // Fixed footer, mirroring the proven greeter pattern: one nested
                // surface, one secondary action, one primary action.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.compact ? 56 : 62

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.55)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.compact ? 16 : 22
                        anchors.rightMargin: root.compact ? 16 : 22
                        spacing: 10

                        WelcomeActionButton {
                            visible: root.currentStep > 0
                            Layout.preferredWidth: 102
                            materialIcon: "arrow_back"
                            label: Translation.tr("Back")
                            onClicked: root.currentStep--
                        }

                        Item { Layout.fillWidth: true }

                        WelcomeActionButton {
                            Layout.preferredWidth: root.currentStep === root.totalSteps - 1 ? 148 : 124
                            primary: true
                            materialIcon: root.currentStep === root.totalSteps - 1 ? "rocket_launch" : "arrow_forward"
                            label: root.currentStep === root.totalSteps - 1 ? Translation.tr("Get Started") : Translation.tr("Continue")
                            onClicked: root.currentStep < root.totalSteps - 1 ? root.currentStep++ : root.finish(false)
                        }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP CONTENT COMPONENTS
    // ═══════════════════════════════════════════════════════════════════════

    // First-run choices use tonal selection like the established Material selectors:
    // the whole option changes mass/outline instead of repeating a decorative side rail.
    component WelcomeChoiceRow: RippleButton {
        id: choiceRow

        property string title: ""
        property string detail: ""
        property string symbol: "check"
        property string badge: ""
        property bool selected: false
        property bool compactRow: false

        Layout.fillWidth: true
        implicitHeight: compactRow ? 50 : (detail.length > 0 ? 76 : 52)
        buttonRadius: choiceRow.compactRow ? root.welcomeControlRadius : root.welcomeChoiceRadius
        colBackground: selected
            ? root.welcomeAccentContainer
            : "transparent"
        colBackgroundHover: selected
            ? root.welcomeAccentHover
            : root.welcomeSurfaceHigh
        colRipple: root.welcomeSurfaceHighest

        contentItem: Item {
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                radius: choiceRow.buttonRadius
                color: "transparent"
                border.width: choiceRow.selected ? 1 : 0
                border.color: ColorUtils.applyAlpha(root.welcomeAccent, 0.58)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 12
                spacing: 10

                Item {
                    Layout.preferredWidth: choiceRow.compactRow ? 28 : 34
                    Layout.preferredHeight: choiceRow.compactRow ? 28 : 34

                    MaterialCookie {
                        anchors.centerIn: parent
                        visible: !root.irisFamily && choiceRow.selected && !choiceRow.compactRow
                        implicitSize: 32
                        sides: 8
                        color: ColorUtils.applyAlpha(root.welcomeSurfaceHighest, 0.96)
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: choiceRow.symbol
                        iconSize: choiceRow.compactRow ? 17 : 19
                        color: choiceRow.selected ? root.welcomeAccent : root.welcomeOnSurfaceVariant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    WelcomeText {
                        Layout.fillWidth: true
                        text: choiceRow.title
                        font.family: root.welcomeFontTitle
                        font.pixelSize: choiceRow.compactRow
                            ? root.welcomeFontBody
                            : choiceRow.selected ? root.welcomeFontSection : root.welcomeFontBody
                        font.weight: choiceRow.selected ? Font.Bold : Font.Medium
                        color: choiceRow.selected ? root.welcomeOnAccentContainer : root.welcomeOnSurface
                        elide: Text.ElideRight
                    }
                    WelcomeText {
                        Layout.fillWidth: true
                        visible: choiceRow.detail.length > 0 && !choiceRow.compactRow
                        text: choiceRow.detail
                        font.pixelSize: root.welcomeFontCaption
                        color: choiceRow.selected
                            ? root.welcomeOnAccentContainer
                            : root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: choiceRow.badge.length > 0
                    implicitWidth: badgeText.implicitWidth + 14
                    implicitHeight: 24
                    radius: 12
                    color: root.welcomeGuideContainer

                    WelcomeText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: choiceRow.badge
                        font.pixelSize: root.welcomeFontMeta
                        font.weight: Font.Bold
                        color: root.welcomeGuideText
                    }
                }

                MaterialSymbol {
                    visible: choiceRow.selected
                    text: "check"
                    iconSize: 16
                    color: root.welcomeOnAccentContainer
                }
            }
        }
    }

    component WelcomeContent: Flickable {
        id: welcomeFlickable
        width: root.stepWidth
        contentHeight: welcomeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 18
        topMargin: Math.max(root.compact ? 8 : 14,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - welcomeColumn.implicitHeight - bottomMargin) / 2)))

        ColumnLayout {
            id: welcomeColumn
            width: parent.width
            spacing: root.compact ? 14 : 18

            GridLayout {
                Layout.fillWidth: true
                columns: welcomeFlickable.width < 720 ? 1 : 2
                columnSpacing: root.compact ? 22 : 34
                rowSpacing: 18

                ColumnLayout {
                    visible: !root.irisFamily || welcomeFlickable.width >= 720
                    Layout.fillWidth: true
                    Layout.preferredWidth: welcomeFlickable.width < 720
                        ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * (root.irisFamily ? 0.58 : 0.43)
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: root.compact ? 2 : 6
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / root.screenAspect
                        visible: root.irisFamily
                        IrisScreenPreview {
                            anchors.fill: parent
                            screen: root.focusedScreen
                            maxScale: 1
                        }
                    }

                    WelcomeText {
                        visible: root.irisFamily
                        text: "iRiS"
                        font.family: root.welcomeFontTitle
                        font.pixelSize: 28 * IrisStyle.typeScale
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                    WelcomeText {
                        visible: root.irisFamily
                        Layout.fillWidth: true
                        text: Translation.tr("Your desktop, built around the Island.")
                        font.pixelSize: root.welcomeFontBody
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        visible: !root.irisFamily
                        Layout.fillWidth: true
                        spacing: 6

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            MaterialCookie {
                                implicitSize: root.compact ? 42 : 48
                                sides: 8
                                color: root.welcomeAccentContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "deployed_code"
                                    iconSize: root.compact ? 22 : 25
                                    color: root.welcomeAccent
                                }
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                text: "iNiR"
                                font.family: root.welcomeFontExpressive
                                font.pixelSize: root.compact ? 42 : 54
                                font.weight: Font.Bold
                                font.letterSpacing: -0.7
                                color: root.welcomeOnSurface
                            }

                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("A complete Niri shell with sensible defaults and room to make it yours.")
                                font.pixelSize: root.welcomeFontBody
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                            }
                        }

                        MascotImage {
                            id: welcomeMascot
                            previewMode: true
                            pose: "welcome-wave"
                            visible: status === Image.Ready && welcomeFlickable.width >= 720
                            Layout.preferredWidth: visible ? (root.compact ? 142 : 176) : 0
                            Layout.preferredHeight: visible ? (root.compact ? 176 : 214) : 0
                            Layout.alignment: Qt.AlignBottom
                        }

                        Item {
                            visible: welcomeMascot.status !== Image.Ready && welcomeFlickable.width >= 720
                            Layout.preferredWidth: visible ? (root.compact ? 132 : 166) : 0
                            Layout.preferredHeight: visible ? (root.compact ? 162 : 194) : 0
                            Layout.alignment: Qt.AlignBottom

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "deployed_code"
                                iconSize: root.compact ? 42 : 50
                                color: root.welcomeAccent
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: !root.irisFamily
                        Layout.topMargin: root.compact ? 8 : 16
                        spacing: 12
                        Repeater {
                            model: [
                                { icon: "palette", label: Translation.tr("Appearance"), detail: Translation.tr("Style, theme and wallpaper") },
                                { icon: "dashboard", label: Translation.tr("Desktop"), detail: Translation.tr("Family, bar and dock placement") },
                                { icon: "tune", label: Translation.tr("Essentials"), detail: Translation.tr("Effects and useful defaults") }
                            ]
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 10
                                MaterialSymbol {
                                    Layout.preferredWidth: 24
                                    text: modelData.icon
                                    iconSize: 18
                                    color: root.welcomeAccent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    WelcomeText {
                                        text: modelData.label
                                        font.pixelSize: root.welcomeFontBody
                                        font.weight: Font.DemiBold
                                        color: root.welcomeOnSurface
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.detail
                                        font.pixelSize: root.welcomeFontCaption
                                        color: root.welcomeSecondaryText
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                PanelSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: welcomeFlickable.width < 720
                        ? welcomeFlickable.width : (welcomeFlickable.width - (root.compact ? 22 : 34)) * (root.irisFamily ? 0.42 : 0.57)
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: welcomeSetupColumn.implicitHeight + 28
                    surfaceDialect: "material"
                    elevation: 2
                    borderless: root.irisFamily
                    outlined: false
                    radiusOverride: root.irisFamily ? IrisStyle.radiusPlate : 16

                    ColumnLayout {
                        id: welcomeSetupColumn
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "dashboard"
                                iconSize: 20
                                color: root.welcomeAccent
                            }
                            WelcomeText {
                                text: Translation.tr("Desktop family")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("You can change this later in Settings.")
                            font.pixelSize: root.welcomeFontCaption
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }

                        WelcomeChoiceRow {
                            title: "Material II"
                            detail: Translation.tr("Modular bars, sidebars and Material controls.")
                            symbol: "dashboard"
                            selected: root.family === "ii"
                            onClicked: root.chooseFamily("ii")
                        }

                        WelcomeChoiceRow {
                            title: "Waffle"
                            detail: Translation.tr("Taskbar, Start menu, Action Center and notification center.")
                            symbol: "grid_view"
                            selected: root.family === "waffle"
                            onClicked: root.chooseFamily("waffle")
                        }

                        WelcomeChoiceRow {
                            title: "iRiS"
                            detail: Translation.tr("Island, pieces and a Dock on any edge.")
                            symbol: "visibility"
                            selected: root.family === "iris"
                            onClicked: root.chooseFamily("iris")
                        }

                        Item {
                            Layout.fillHeight: true
                            Layout.minimumHeight: 4
                        }

                        Rectangle {
                            visible: !root.irisFamily
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                        }

                        RowLayout {
                            visible: !root.irisFamily
                            Layout.fillWidth: true
                            spacing: 10

                            WelcomeText {
                                text: Translation.tr("Up next")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.DemiBold
                                color: root.welcomeSecondaryText
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 20
                                color: ColorUtils.applyAlpha(root.welcomeOutline, 0.42)
                            }

                            Repeater {
                                model: root.steps.slice(1, 4)
                                RowLayout {
                                    required property int index
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    WelcomeText {
                                        text: String(index + 2).padStart(2, "0")
                                        font.family: root.welcomeFontNumbers
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.DemiBold
                                        color: root.welcomeAccent
                                    }
                                    MaterialSymbol {
                                        text: modelData.icon
                                        iconSize: 16
                                        color: root.welcomeSecondaryText
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        font.pixelSize: root.welcomeFontCaption
                                        font.weight: Font.Medium
                                        color: root.welcomeOnSurface
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ThemeContent: Flickable {
        id: themeFlickable
        width: root.stepWidth
        contentHeight: themeColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 6 : 10,
            Math.min(root.compact ? 18 : 24,
                Math.round((height - themeColumn.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: themeColumn
            width: parent.width
            columns: themeFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 20 : 28
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: themeFlickable.width < 760
                    ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.34
                Layout.alignment: Qt.AlignTop
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "auto_awesome"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Style")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 3
                    text: Translation.tr("Choose the look for the whole shell.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 4
                    rowSpacing: 2

                    Repeater {
                        model: root.stylePresets
                        WelcomeChoiceRow {
                            required property var modelData
                            compactRow: true
                            title: modelData.name
                            symbol: modelData.icon
                            selected: root.effectiveStylePreset === modelData.id
                            onClicked: root.applyStylePreset(modelData.id)
                        }
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: themeFlickable.width < 760
                    ? themeFlickable.width : (themeFlickable.width - (root.compact ? 20 : 28)) * 0.66
                Layout.alignment: Qt.AlignTop
                implicitHeight: appearanceColumn.implicitHeight + 28
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: appearanceColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: root.compact ? 9 : 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 38
                            sides: 8
                            color: root.welcomeAccentContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.currentStylePreset.icon
                                iconSize: 19
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            WelcomeText {
                                text: root.effectiveStylePreset === "custom"
                                    ? Translation.tr("Custom style") : root.currentStylePreset.name
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.currentStylePresetDescription
                                font.pixelSize: root.welcomeFontCaption
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            visible: root.effectiveStylePreset === "material"
                            implicitWidth: recommendedStyleLabel.implicitWidth + 14
                            implicitHeight: 22
                            radius: 11
                            color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)

                            WelcomeText {
                                id: recommendedStyleLabel
                                anchors.centerIn: parent
                                text: Translation.tr("Recommended")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: ColorUtils.ensureReadable(root.welcomeOnSurface, parent.color, 4.5)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        LightDarkPreferenceButton { dark: false }
                        LightDarkPreferenceButton { dark: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    ColumnLayout {
                        id: wallpaperGroup
                        Layout.fillWidth: true
                        spacing: 7

                        property var wallpapersList: []
                        readonly property string wallpapersPath: Directories.wallpapersPath
                        readonly property real itemWidth: root.compact ? 156 : 180
                        readonly property real itemHeight: root.compact ? 88 : 100

                        Component.onCompleted: wallpaperScanProc.running = true

                        Process {
                            id: wallpaperScanProc
                            command: ["/bin/sh", "-c", `find '${wallpaperGroup.wallpapersPath}' -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.avif' \\) -printf '%C@\\t%p\\n' 2>/dev/null`]
                            stdout: SplitParser {
                                splitMarker: ""
                                onRead: data => {
                                    const lines = data.trim().split("\n").filter(l => l.length > 0)
                                    lines.sort((a, b) => parseFloat(b.split("\t")[0]) - parseFloat(a.split("\t")[0]))
                                    wallpaperGroup.wallpapersList = lines.map(l => l.split("\t")[1]).filter(p => p && p.length > 0)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            MaterialSymbol { text: "wallpaper"; iconSize: 17; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Wallpaper")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("Colors update automatically")
                                color: root.welcomeSecondaryText
                                font.pixelSize: root.welcomeFontMeta
                            }
                        }

                ListView {
                    id: wallpaperCarousel
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight
                    visible: wallpaperGroup.wallpapersList.length > 0
                    orientation: ListView.Horizontal
                    spacing: 7
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: wallpaperGroup.wallpapersList

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                            wallpaperCarousel.contentX = Math.max(0, Math.min(
                                wallpaperCarousel.contentWidth - wallpaperCarousel.width,
                                wallpaperCarousel.contentX - delta
                            ))
                        }
                    }

                    delegate: Item {
                        id: wpDelegate
                        required property int index
                        required property string modelData
                        readonly property string filePath: modelData
                        readonly property bool isCurrentWallpaper: (Config.options?.background?.wallpaperPath ?? "") === filePath
                        readonly property bool isHovered: wpMouseArea.containsMouse

                        width: wallpaperGroup.itemWidth
                        height: wallpaperGroup.itemHeight

                        PanelSurface {
                            id: wpThumb
                            anchors.fill: parent
                            surfaceDialect: "material"
                                    elevation: 1
                            cardStyle: true
                            outlined: wpDelegate.isCurrentWallpaper
                            borderWidthOverride: wpDelegate.isCurrentWallpaper ? 2 : 0
                                    radiusOverride: 12
                            clipContent: true

                            Image {
                                anchors.fill: parent
                                anchors.margins: wpDelegate.isCurrentWallpaper ? 3 : 0
                                source: wpDelegate.filePath ? `file://${wpDelegate.filePath}` : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.width: Math.round(wallpaperGroup.itemWidth * 2.25)
                                sourceSize.height: Math.round(wallpaperGroup.itemHeight * 2.25)
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: wpDelegate.isHovered && !wpDelegate.isCurrentWallpaper ? "#36000000" : "transparent"
                            }

                                    Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                visible: wpDelegate.isCurrentWallpaper
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: root.welcomeAccent
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "check"
                                            iconSize: 14
                                            color: root.welcomeOnAccent
                                        }
                            }

                            MouseArea {
                                id: wpMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpapers.select(wpDelegate.filePath)
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: wallpaperGroup.itemHeight
                    visible: wallpaperGroup.wallpapersList.length === 0
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol { Layout.alignment: Qt.AlignHCenter; text: "image"; iconSize: 20; color: root.welcomeOnSurfaceVariant }
                        WelcomeText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("No wallpapers found in ~/Pictures/Wallpapers").replace("~/Pictures/Wallpapers", Directories.shortHomePath(Directories.wallpapersPath))
                            color: root.welcomeSecondaryText
                            font.pixelSize: root.welcomeFontMeta
                        }
                    }
                }
            }
                }
            }
        }
    }

    component LayoutContent: Flickable {
        id: layoutFlickable
        width: root.stepWidth
        contentHeight: layoutColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - layoutColumn.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: layoutColumn
            width: parent.width
            columns: layoutFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: layoutFlickable.width < 760
                    ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.42
                Layout.alignment: Qt.AlignTop
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "dashboard"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Shell family")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose the shell family that matches how you want the desktop to work.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                WelcomeChoiceRow {
                    title: "Material II"
                    detail: Translation.tr("M3 bar, dock and sidebars with shared Material controls.")
                    symbol: "dashboard"
                    selected: root.family === "ii"
                    badge: Translation.tr("Default")
                    onClicked: root.chooseFamily("ii")
                }

                WelcomeChoiceRow {
                    title: "Waffle"
                    detail: Translation.tr("Taskbar, Start menu and Action Center.")
                    symbol: "grid_view"
                    selected: root.family === "waffle"
                    onClicked: root.chooseFamily("waffle")
                }

                WelcomeChoiceRow {
                    title: "iRiS"
                    detail: Translation.tr("Edge-aware Island, movable pieces, Dock, Themes and Studio.")
                    symbol: "visibility"
                    selected: root.family === "iris"
                    onClicked: root.chooseFamily("iris")
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: layoutFlickable.width < 760
                    ? layoutFlickable.width : (layoutFlickable.width - (root.compact ? 22 : 30)) * 0.58
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(placementColumn.implicitHeight + 28, root.compact ? 300 : 330)
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: placementColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 34
                            sides: 8
                            color: root.welcomeAccentContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "view_compact"
                                iconSize: 17
                                color: root.welcomeAccent
                            }
                        }
                        WelcomeText {
                            text: Translation.tr("Placement")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        WelcomeText {
                            text: Translation.tr("Bar position")
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeOnSurface
                        }
                        WelcomeSegmentedControl {
                            Layout.fillWidth: true
                            currentValue: (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
                            options: [
                                { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                                { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" }
                            ]
                            onSelected: value => root.setProfileFeature("bar.bottom", value === "bottom")
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5
                        WelcomeText {
                            text: Translation.tr("Dock position")
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Medium
                            color: root.welcomeOnSurface
                        }
                        WelcomeSegmentedControl {
                            Layout.fillWidth: true
                            currentValue: Config.options?.dock?.position ?? "bottom"
                            options: [
                                { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: "bottom" },
                                { displayName: Translation.tr("Left"), icon: "arrow_back", value: "left" },
                                { displayName: Translation.tr("Right"), icon: "arrow_forward", value: "right" }
                            ]
                            onSelected: value => root.setProfileFeature("dock.position", value)
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 6
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (Config.options?.panelFamily ?? "ii") === "ii"
                            && (Config.options?.bar?.appearanceStyle ?? "m3") === "m3"
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "side_navigation"
                                iconSize: 18
                                color: root.welcomeAccent
                            }
                            WelcomeText {
                                text: Translation.tr("Sidebar access")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("M3 bar")
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: root.welcomeAccentAlt
                            }
                        }

                        WelcomeText {
                            Layout.fillWidth: true
                            text: Translation.tr("A sidebar button stays at each outer edge of the bar.")
                            font.pixelSize: root.welcomeFontCaption
                            color: root.welcomeSecondaryText
                            wrapMode: Text.WordWrap
                        }

                        PanelSurface {
                            Layout.fillWidth: true
                            implicitHeight: 116
                            surfaceDialect: "material"
                            elevation: 1
                            outlined: false
                            radiusOverride: 14

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    WelcomeText {
                                        text: Translation.tr("Edge controls")
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.DemiBold
                                        color: root.welcomeSecondaryText
                                    }

                                    Item { Layout.fillWidth: true }

                                    WelcomeText {
                                        text: "M3 · COMPACT"
                                        font.family: root.welcomeFontNumbers
                                        font.pixelSize: root.welcomeFontMeta
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.7
                                        color: root.welcomeAccentAlt
                                    }
                                }

                                PanelSurface {
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    surfaceDialect: "material"
                                    elevation: 2
                                    island: true
                                    outlined: false
                                    radiusOverride: 18

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 7
                                        anchors.rightMargin: 7
                                        spacing: 7

                                        PanelSurface {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "left_panel_open"
                                                iconSize: 20
                                                color: root.welcomeAccent
                                            }
                                        }

                                        RowLayout {
                                            spacing: 4
                                            Layout.alignment: Qt.AlignVCenter

                                            Rectangle {
                                                implicitWidth: 18
                                                implicitHeight: 8
                                                radius: 4
                                                color: root.welcomeAccent
                                            }
                                            Rectangle {
                                                implicitWidth: 8
                                                implicitHeight: 8
                                                radius: 4
                                                color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                            }
                                            Rectangle {
                                                implicitWidth: 8
                                                implicitHeight: 8
                                                radius: 4
                                                color: ColorUtils.applyAlpha(root.welcomeOnSurfaceVariant, 0.34)
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        PanelSurface {
                                            Layout.preferredWidth: 156
                                            Layout.preferredHeight: 34
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 6
                                                Repeater {
                                                    model: ["folder", "terminal", "language", "music_note"]
                                                    MaterialSymbol {
                                                        required property string modelData
                                                        text: modelData
                                                        iconSize: 16
                                                        color: root.welcomeOnSurfaceVariant
                                                    }
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        RowLayout {
                                            spacing: 4
                                            Layout.alignment: Qt.AlignVCenter
                                            MaterialSymbol {
                                                text: "wifi"
                                                iconSize: 15
                                                color: root.welcomeOnSurfaceVariant
                                            }
                                            MaterialSymbol {
                                                text: "volume_up"
                                                iconSize: 15
                                                color: root.welcomeOnSurfaceVariant
                                            }
                                        }

                                        PanelSurface {
                                            Layout.preferredWidth: 38
                                            Layout.preferredHeight: 38
                                            Layout.alignment: Qt.AlignVCenter
                                            surfaceDialect: "material"
                                            elevation: 3
                                            island: true
                                            outlined: false

                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "right_panel_open"
                                                iconSize: 20
                                                color: root.welcomeAccent
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    RowLayout {
                                        spacing: 5
                                        MaterialSymbol {
                                            text: "left_panel_open"
                                            iconSize: 14
                                            color: root.welcomeAccent
                                        }
                                        WelcomeText {
                                            text: Translation.tr("Left sidebar")
                                            font.pixelSize: root.welcomeFontMeta
                                            font.weight: Font.Medium
                                            color: root.welcomeOnSurface
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    RowLayout {
                                        spacing: 5
                                        WelcomeText {
                                            text: Translation.tr("Right sidebar")
                                            font.pixelSize: root.welcomeFontMeta
                                            font.weight: Font.Medium
                                            color: root.welcomeOnSurface
                                        }
                                        MaterialSymbol {
                                            text: "right_panel_open"
                                            iconSize: 14
                                            color: root.welcomeAccent
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: (Config.options?.panelFamily ?? "ii") === "ii"
                            && (Config.options?.bar?.appearanceStyle ?? "m3") !== "m3"
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol {
                                text: "side_navigation"
                                iconSize: 18
                                color: root.welcomeAccentAlt
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("Sidebar access")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                text: String(Config.options?.bar?.appearanceStyle ?? "m3").toUpperCase()
                                font.family: root.welcomeFontNumbers
                                font.pixelSize: root.welcomeFontMeta
                                font.weight: Font.Bold
                                color: root.welcomeAccentAlt
                            }
                        }

                        PanelSurface {
                            Layout.fillWidth: true
                            implicitHeight: 82
                            surfaceDialect: "material"
                            elevation: 1
                            outlined: false
                            radiusOverride: 14

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                MaterialCookie {
                                    implicitSize: 42
                                    sides: 7
                                    color: ColorUtils.mix(root.welcomeSurfaceHighest, root.welcomeAccentAlt, 0.62)
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "visibility"
                                        iconSize: 20
                                        color: root.welcomeAccentAlt
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Sidebars stay available")
                                        font.family: root.welcomeFontTitle
                                        font.pixelSize: root.welcomeFontBody
                                        font.weight: Font.Bold
                                        color: root.welcomeOnSurface
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("This bar style uses its own controls; your sidebars remain available.")
                                        font.pixelSize: root.welcomeFontCaption
                                        color: root.welcomeSecondaryText
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component FeaturesContent: Flickable {
        id: featuresFlickable
        width: root.stepWidth
        contentHeight: featuresColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - featuresColumn.implicitHeight - bottomMargin) / 2)))

        readonly property var profileHighlights: root.selectedProfile === "minimum" ? [
            { value: "M3", label: Translation.tr("compact bar") },
            { value: "2", label: Translation.tr("sidebars") },
            { value: "4", label: Translation.tr("quick toggles") },
            { value: "0", label: Translation.tr("desktop widgets") }
        ] : root.selectedProfile === "full" ? [
            { value: "M3+", label: Translation.tr("bar + media") },
            { value: "2", label: Translation.tr("full sidebars") },
            { value: "8", label: Translation.tr("quick toggles") },
            { value: "2", label: Translation.tr("desktop widgets") }
        ] : [
            { value: "M3", label: Translation.tr("bar + dock") },
            { value: "2", label: Translation.tr("sidebars") },
            { value: "8", label: Translation.tr("quick toggles") },
            { value: "1", label: Translation.tr("desktop clock") }
        ]

        GridLayout {
            id: featuresColumn
            width: parent.width
            columns: featuresFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: featuresFlickable.width < 760
                    ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.38
                Layout.alignment: Qt.AlignTop
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    MaterialSymbol { text: "tune"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Base setup")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose how much iNiR sets up for your first session.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Minimum")
                    detail: Translation.tr("Core controls with no desktop widgets.")
                    symbol: "filter_1"
                    selected: !root.profileCustomized && root.selectedProfile === "minimum"
                    onClicked: root.applyProfile("minimum")
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Balanced")
                    detail: Translation.tr("Sidebars, daily toggles and a desktop clock.")
                    symbol: "tune"
                    badge: Translation.tr("Recommended")
                    selected: !root.profileCustomized && root.selectedProfile === "balanced"
                    onClicked: root.applyProfile("balanced")
                }

                WelcomeChoiceRow {
                    title: Translation.tr("Full")
                    detail: Translation.tr("More local tools, fuller sidebars and a system monitor.")
                    symbol: "auto_awesome"
                    selected: !root.profileCustomized && root.selectedProfile === "full"
                    onClicked: root.applyProfile("full")
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: featuresFlickable.width < 760
                    ? featuresFlickable.width : (featuresFlickable.width - (root.compact ? 22 : 30)) * 0.62
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(profileSummaryColumn.implicitHeight + 28, root.compact ? 300 : 330)
                surfaceDialect: "material"
                elevation: 2
                outlined: false
                radiusOverride: 16

                ColumnLayout {
                    id: profileSummaryColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialCookie {
                            implicitSize: 38
                            sides: 8
                            color: root.welcomeAccentContainer
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.selectedProfile === "minimum" ? "filter_1"
                                    : root.selectedProfile === "full" ? "auto_awesome" : "tune"
                                iconSize: 19
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            WelcomeText {
                                text: root.profileCustomized
                                    ? Translation.tr("Custom setup") : root.selectedProfileTitle
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.larger
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: root.selectedProfileDescription
                                font.pixelSize: root.welcomeFontCaption
                                font.weight: Font.Medium
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 2
                        Repeater {
                            model: featuresFlickable.profileHighlights
                            WelcomeMetric {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                value: modelData.value
                                label: modelData.label
                                accent: index % 2 === 0 ? root.welcomeAccent : root.welcomeAccentAlt
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.minimumHeight: 4
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        MaterialSymbol { text: "speed"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Effects")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: root.effectivePerformancePreset === "custom"
                                ? Translation.tr("Custom") : root.currentPerformancePreset.name
                            font.pixelSize: root.welcomeFontMeta
                            color: root.welcomeSecondaryText
                        }
                    }

                    WelcomeSegmentedControl {
                        Layout.fillWidth: true
                        currentValue: root.effectivePerformancePreset
                        options: root.performancePresets.map(preset => ({
                            displayName: preset.name,
                            icon: preset.icon,
                            value: preset.id
                        }))
                        onSelected: value => root.applyPerformancePreset(value)
                    }

                    WelcomeText {
                        Layout.fillWidth: true
                        text: root.currentPerformancePresetDescription
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component IrisStartContent: Flickable {
        id: irisStartFlickable
        width: root.stepWidth
        contentHeight: irisStartGrid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - irisStartGrid.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: irisStartGrid
            width: parent.width
            columns: irisStartFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: irisStartFlickable.width < 760
                    ? irisStartFlickable.width : (irisStartFlickable.width - (root.compact ? 22 : 30)) * 0.42
                Layout.alignment: Qt.AlignTop
                spacing: 7

                RowLayout {
                    spacing: 8
                    MaterialSymbol { text: "view_compact"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("iRiS layout")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Start with an Island or a full bar. Adjust its position next.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.irisArrangements
                    WelcomeChoiceRow {
                        required property var modelData
                        title: modelData.name
                        detail: modelData.description
                        symbol: modelData.icon
                        badge: modelData.badge ?? ""
                        selected: root.effectiveIrisArrangement === modelData.id
                        onClicked: root.applyIrisArrangement(modelData.id)
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: irisStartFlickable.width < 760
                    ? irisStartFlickable.width : (irisStartFlickable.width - (root.compact ? 22 : 30)) * 0.58
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(irisStartPreviewColumn.implicitHeight + 28, root.compact ? 310 : 350)
                surfaceDialect: "material"
                elevation: 2
                borderless: root.irisFamily
                outlined: false
                radiusOverride: root.irisFamily ? IrisStyle.radiusPlate : 16

                WelcomeIrisFill {}

                ColumnLayout {
                    id: irisStartPreviewColumn
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol { text: "desktop_windows"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: root.effectiveIrisArrangement === "custom"
                                ? Translation.tr("Custom layout") : root.currentIrisArrangement.name
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: root.familyTitle
                            font.pixelSize: root.welcomeFontMeta
                            font.weight: Font.Bold
                            color: root.welcomeAccent
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / root.screenAspect
                        IrisScreenPreview {
                            anchors.fill: parent
                            screen: root.focusedScreen
                            maxScale: 1
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.34)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol { text: "speed"; iconSize: 17; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Effects")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontBody
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                        Item { Layout.fillWidth: true }
                        WelcomeText {
                            text: root.effectivePerformancePreset === "custom"
                                ? Translation.tr("Custom") : root.currentPerformancePreset.name
                            font.pixelSize: root.welcomeFontMeta
                            color: root.welcomeSecondaryText
                        }
                    }

                    WelcomeSegmentedControl {
                        Layout.fillWidth: true
                        currentValue: root.effectivePerformancePreset
                        options: root.performancePresets.map(preset => ({
                            displayName: preset.name, icon: preset.icon, value: preset.id
                        }))
                        onSelected: value => root.applyPerformancePreset(value)
                    }
                }
            }
        }
    }

    component IrisAppearanceContent: Flickable {
        id: irisAppearanceFlickable
        width: root.stepWidth
        contentHeight: irisAppearanceGrid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - irisAppearanceGrid.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: irisAppearanceGrid
            width: parent.width
            columns: irisAppearanceFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: irisAppearanceFlickable.width < 760
                    ? irisAppearanceFlickable.width : (irisAppearanceFlickable.width - (root.compact ? 22 : 30)) * 0.42
                Layout.alignment: Qt.AlignTop
                spacing: 5

                RowLayout {
                    spacing: 8
                    MaterialSymbol { text: "palette"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Themes")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    Layout.fillWidth: true
                    text: Translation.tr("Material, shape and motion. More themes in Studio.")
                    font.pixelSize: root.welcomeFontCaption
                    color: root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: root.irisWelcomeThemes
                    WelcomeChoiceRow {
                        required property var modelData
                        compactRow: true
                        title: modelData.name
                        symbol: modelData.id === "terminal" ? "terminal"
                            : modelData.id === "adaptive" ? "auto_awesome"
                            : modelData.id === "frost" ? "ac_unit"
                            : modelData.id === "aurora" ? "gradient"
                            : modelData.id === "liquid-glass" ? "water_drop" : "visibility"
                        selected: IrisThemes.activeId === modelData.id && !IrisThemes.modified
                        onClicked: root.applyIrisTheme(modelData.id)
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: irisAppearanceFlickable.width < 760
                    ? irisAppearanceFlickable.width : (irisAppearanceFlickable.width - (root.compact ? 22 : 30)) * 0.58
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(irisThemePreviewColumn.implicitHeight + 28, root.compact ? 310 : 350)
                surfaceDialect: "material"
                elevation: 2
                borderless: root.irisFamily
                outlined: false
                radiusOverride: IrisStyle.radiusPlate

                WelcomeIrisFill {}

                ColumnLayout {
                    id: irisThemePreviewColumn
                    anchors.fill: parent
                    anchors.margins: IrisStyle.concentricPad(IrisStyle.radiusPlate, 14)
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            WelcomeText {
                                text: IrisThemes.active?.name ?? Translation.tr("Custom theme")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: root.welcomeFontSection
                                font.weight: Font.Bold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: IrisThemes.modified
                                    ? Translation.tr("Modified")
                                    : (IrisThemes.active?.description ?? "")
                                font.pixelSize: root.welcomeFontCaption
                                color: root.welcomeSecondaryText
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / root.screenAspect
                        IrisScreenPreview {
                            anchors.fill: parent
                            screen: root.focusedScreen
                            maxScale: 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Repeater {
                            model: [
                                { icon: "texture", value: IrisStyle.glassy ? Translation.tr("Glass") : Translation.tr("Solid") },
                                { icon: "rounded_corner", value: String(Math.round(IrisStyle.shapeScale * 100)) + "%" },
                                { icon: "motion_mode", value: IrisStyle.morphName }
                            ]
                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 5
                                MaterialSymbol { text: modelData.icon; iconSize: 15; color: root.welcomeAccent }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    font.pixelSize: root.welcomeFontMeta
                                    font.weight: Font.DemiBold
                                    color: root.welcomeSecondaryText
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component IrisLayoutContent: Flickable {
        id: irisLayoutFlickable
        width: root.stepWidth
        contentHeight: irisLayoutGrid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 24
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 20 : 28,
                Math.round((height - irisLayoutGrid.implicitHeight - bottomMargin) / 2)))

        GridLayout {
            id: irisLayoutGrid
            width: parent.width
            columns: irisLayoutFlickable.width < 760 ? 1 : 2
            columnSpacing: root.compact ? 22 : 30
            rowSpacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: irisLayoutFlickable.width < 760
                    ? irisLayoutFlickable.width : (irisLayoutFlickable.width - (root.compact ? 22 : 30)) * 0.48
                Layout.alignment: Qt.AlignTop
                spacing: 9

                RowLayout {
                    spacing: 8
                    MaterialSymbol { text: "open_in_full"; iconSize: 18; color: root.welcomeAccent }
                    WelcomeText {
                        text: Translation.tr("Placement")
                        font.family: root.welcomeFontTitle
                        font.pixelSize: root.welcomeFontSection
                        font.weight: Font.Bold
                        color: root.welcomeOnSurface
                    }
                }

                WelcomeText {
                    text: Translation.tr("Island edge")
                    font.pixelSize: root.welcomeFontBody
                    font.weight: Font.Medium
                    color: root.welcomeOnSurface
                }
                WelcomeSegmentedControl {
                    Layout.fillWidth: true
                    currentValue: Config.options?.iris?.bar?.position ?? "top"
                    options: [
                        { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                        { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                        { displayName: Translation.tr("Left"), icon: "align_horizontal_left", value: "left" },
                        { displayName: Translation.tr("Right"), icon: "align_horizontal_right", value: "right" }
                    ]
                    onSelected: value => Config.setNestedValue("iris.bar.position", value)
                }

                WelcomeText {
                    text: Translation.tr("Island layout")
                    font.pixelSize: root.welcomeFontBody
                    font.weight: Font.Medium
                    color: root.welcomeOnSurface
                }
                WelcomeSegmentedControl {
                    Layout.fillWidth: true
                    currentValue: Config.options?.iris?.bar?.layout ?? "island"
                    options: [
                        { displayName: Translation.tr("Island"), icon: "pill", value: "island" },
                        { displayName: Translation.tr("Full bar"), icon: "width_full", value: "full" }
                    ]
                    onSelected: value => Config.setNestedValue("iris.bar.layout", value)
                }

                WelcomeText {
                    text: Translation.tr("Dock edge")
                    font.pixelSize: root.welcomeFontBody
                    font.weight: Font.Medium
                    color: root.welcomeOnSurface
                }
                WelcomeSegmentedControl {
                    Layout.fillWidth: true
                    currentValue: Config.options?.iris?.dock?.position ?? "auto"
                    options: [
                        { displayName: Translation.tr("Auto"), icon: "swap_calls", value: "auto" },
                        { displayName: Translation.tr("Top"), icon: "north", value: "top" },
                        { displayName: Translation.tr("Bottom"), icon: "south", value: "bottom" },
                        { displayName: Translation.tr("Left"), icon: "west", value: "left" },
                        { displayName: Translation.tr("Right"), icon: "east", value: "right" }
                    ]
                    onSelected: value => Config.setNestedValue("iris.dock.position", value)
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    WelcomeText {
                        Layout.fillWidth: true
                        text: Translation.tr("Attach Island to edge")
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeOnSurface
                    }
                    WelcomeSegmentedControl {
                        Layout.preferredWidth: 170
                        currentValue: (Config.options?.iris?.bar?.notch ?? true) ? "on" : "off"
                        options: [
                            { displayName: Translation.tr("Off"), icon: "", value: "off" },
                            { displayName: Translation.tr("On"), icon: "", value: "on" }
                        ]
                        onSelected: value => Config.setNestedValue("iris.bar.notch", value === "on")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    WelcomeText {
                        Layout.fillWidth: true
                        text: Translation.tr("Desktop widgets")
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeOnSurface
                    }
                    WelcomeSegmentedControl {
                        Layout.preferredWidth: 170
                        currentValue: (Config.options?.iris?.modules?.desktopWidgets ?? true) ? "on" : "off"
                        options: [
                            { displayName: Translation.tr("Off"), icon: "", value: "off" },
                            { displayName: Translation.tr("On"), icon: "", value: "on" }
                        ]
                        onSelected: value => Config.setNestedValue("iris.modules.desktopWidgets", value === "on")
                    }
                }
            }

            PanelSurface {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: irisLayoutFlickable.width < 760
                    ? irisLayoutFlickable.width : (irisLayoutFlickable.width - (root.compact ? 22 : 30)) * 0.52
                Layout.alignment: Qt.AlignTop
                implicitHeight: Math.max(irisLayoutPreviewColumn.implicitHeight + 28, root.compact ? 310 : 350)
                surfaceDialect: "material"
                elevation: 2
                borderless: root.irisFamily
                outlined: false
                radiusOverride: IrisStyle.radiusPlate

                WelcomeIrisFill {}

                ColumnLayout {
                    id: irisLayoutPreviewColumn
                    anchors.fill: parent
                    anchors.margins: IrisStyle.concentricPad(IrisStyle.radiusPlate, 14)
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        MaterialSymbol { text: "desktop_windows"; iconSize: 18; color: root.welcomeAccent }
                        WelcomeText {
                            text: Translation.tr("Live layout")
                            font.family: root.welcomeFontTitle
                            font.pixelSize: root.welcomeFontSection
                            font.weight: Font.Bold
                            color: root.welcomeOnSurface
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width / root.screenAspect
                        IrisScreenPreview {
                            anchors.fill: parent
                            screen: root.focusedScreen
                            maxScale: 1
                        }
                    }

                    WelcomeText {
                        Layout.fillWidth: true
                        text: Translation.tr("Auto keeps the Dock opposite the Island. Choosing the same edge swaps them.")
                        font.pixelSize: root.welcomeFontCaption
                        color: root.welcomeSecondaryText
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    component ReadyContent: Flickable {
        id: readyFlickable
        width: root.stepWidth
        contentHeight: readyColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        bottomMargin: 12
        topMargin: Math.max(root.compact ? 8 : 12,
            Math.min(root.compact ? 12 : 16,
                Math.round((height - readyColumn.implicitHeight - bottomMargin) / 2)))

        ColumnLayout {
            id: readyColumn
            width: parent.width
            spacing: root.compact ? 10 : 14

            PanelSurface {
                Layout.fillWidth: true
                implicitHeight: readySummaryColumn.implicitHeight + 24
                surfaceDialect: "material"
                elevation: 2
                borderless: root.irisFamily
                outlined: false
                radiusOverride: root.irisFamily ? IrisStyle.radiusPlate : 16

                WelcomeIrisFill {}

                ColumnLayout {
                    id: readySummaryColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Iris.IrisMark {
                            visible: root.irisFamily
                            implicitSize: 36
                        }
                        MaterialCookie {
                            visible: !root.irisFamily
                            implicitSize: 46
                            sides: 8
                            color: root.welcomeAccentContainer

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "check"
                                iconSize: 24
                                color: root.welcomeAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            WelcomeText {
                                text: Translation.tr("Setup ready")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.large * 1.08
                                font.weight: Font.DemiBold
                                color: root.welcomeOnSurface
                            }
                            WelcomeText {
                                Layout.fillWidth: true
                                text: Translation.tr("You can change any of this later in Settings.")
                                font.pixelSize: root.welcomeFontCaption
                                color: root.welcomeSecondaryText
                                wrapMode: Text.WordWrap
                            }
                        }

                        MascotImage {
                            previewMode: true
                            pose: "about-confident"
                            visible: status === Image.Ready && readyFlickable.width >= 720
                            Layout.preferredWidth: visible ? 80 : 0
                            Layout.preferredHeight: visible ? 90 : 0
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: ColorUtils.applyAlpha(root.welcomeOutline, 0.32)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: readyFlickable.width < 720 ? 2 : 4
                        columnSpacing: 18
                        rowSpacing: 8

                        Repeater {
                            model: [
                                { icon: "tune", label: Translation.tr("Starting point"), value: root.irisFamily
                                    ? (root.effectiveIrisArrangement === "custom" ? Translation.tr("Custom") : root.currentIrisArrangement.name)
                                    : root.selectedProfileTitle },
                                { icon: "palette", label: Translation.tr("Style"), value: root.irisFamily
                                    ? (IrisThemes.active?.name ?? Translation.tr("Custom"))
                                    : (root.effectiveStylePreset === "custom" ? Translation.tr("Custom") : root.currentStylePreset.name) },
                                { icon: "dashboard", label: Translation.tr("Family"), value: root.familyTitle },
                                { icon: "speed", label: Translation.tr("Effects"), value: root.effectivePerformancePreset === "custom" ? Translation.tr("Custom") : root.currentPerformancePreset.name }
                            ]

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: 17
                                    color: root.welcomeAccent
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    WelcomeText {
                                        text: modelData.label
                                        font.pixelSize: root.welcomeFontMeta
                                        color: root.welcomeSecondaryText
                                    }
                                    WelcomeText {
                                        Layout.fillWidth: true
                                        text: modelData.value
                                        font.pixelSize: root.welcomeFontCaption
                                        font.weight: Font.DemiBold
                                        color: root.welcomeOnSurface
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Two task columns use the full content field. Like Dashboard, each
            // column owns one semantic group instead of stacking decorative cards.
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                columns: readyFlickable.width < 760 ? 1 : 2
                columnSpacing: root.compact ? 10 : 14
                rowSpacing: root.compact ? 10 : 14

                // Keyboard shortcuts card
                PanelSurface {
                    Layout.fillWidth: true
                    Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 420
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: shortcutsCardCol.implicitHeight + 20
                    surfaceDialect: "material"
                    elevation: 1
                    borderless: root.irisFamily
                    outlined: false
                    radiusOverride: root.irisFamily ? IrisStyle.radiusPlate : 16

                    WelcomeIrisFill {}

                    ColumnLayout {
                        id: shortcutsCardCol
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 8

                        RowLayout {
                            spacing: 8
                            MaterialSymbol { text: "keyboard"; iconSize: 18; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Keyboard")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                            WelcomeText {
                                text: Translation.tr("Full list: Super+/")
                                font.pixelSize: root.welcomeFontMeta
                                color: root.welcomeSecondaryText
                            }
                        }

                        Repeater {
                            model: [
                                { keys: "Super+/",     desc: Translation.tr("All shortcuts") },
                                { keys: "Super+Space", desc: Translation.tr("App launcher") },
                                { keys: "Super+,",     desc: Translation.tr("Settings") },
                                { keys: "Super+V",     desc: Translation.tr("Clipboard history") }
                            ]
                            RowLayout {
                                Layout.fillWidth: true
                                required property var modelData
                                spacing: 10

                                Row {
                                    Layout.preferredWidth: root.compact ? 138 : 154
                                    spacing: 2
                                    Repeater {
                                        model: modelData.keys.split("+")
                                        WelcomeKey {
                                            required property string modelData
                                            key: modelData
                                        }
                                    }
                                }
                                WelcomeText {
                                    Layout.fillWidth: true
                                    text: modelData.desc
                                    font.pixelSize: root.welcomeFontCaption
                                    color: root.welcomeSecondaryText
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                        }
                    }
                }

                // Try it now — interactive action card
                PanelSurface {
                    Layout.fillWidth: true
                    Layout.preferredWidth: readyFlickable.width < 760 ? readyFlickable.width : 580
                    Layout.alignment: Qt.AlignTop
                    implicitHeight: tryItCardCol.implicitHeight + 20
                    surfaceDialect: "material"
                    elevation: 2
                    borderless: root.irisFamily
                    outlined: false
                    radiusOverride: root.irisFamily ? IrisStyle.radiusPlate : 16

                    WelcomeIrisFill {}

                    ColumnLayout {
                        id: tryItCardCol
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            MaterialSymbol { text: "rocket_launch"; iconSize: 18; color: root.welcomeAccent }
                            WelcomeText {
                                text: Translation.tr("Quick actions")
                                font.family: root.welcomeFontTitle
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                            }
                            Item { Layout.fillWidth: true }
                        }

                        Repeater {
                            model: [
                                {
                                    icon: "tune",
                                    label: Translation.tr("Open quick settings"),
                                    sub: Translation.tr("Network, audio and brightness"),
                                    target: "controlPanel",
                                    fn: "toggle"
                                },
                                {
                                    icon: "wallpaper",
                                    label: Translation.tr("Pick a wallpaper"),
                                    sub: Translation.tr("Choose a background"),
                                    target: "wallpaperSelector",
                                    fn: "toggle"
                                },
                                {
                                    icon: "keyboard",
                                    label: Translation.tr("Show all shortcuts"),
                                    sub: Translation.tr("Open the full shortcut list"),
                                    target: "cheatsheet",
                                    fn: "toggle"
                                }
                            ]
                            WelcomeListAction {
                                Layout.fillWidth: true
                                required property var modelData
                                materialIcon: modelData.icon
                                title: modelData.label
                                subtitle: modelData.sub

                                onClicked: Quickshell.execDetached([
                                    Quickshell.shellPath("scripts/inir"),
                                    modelData.target,
                                    modelData.fn
                                ])
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 6

                Item { Layout.fillWidth: true }

                WelcomeActionButton {
                    materialIcon: "settings"
                    label: Translation.tr("Settings")
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                }

                WelcomeActionButton {
                    materialIcon: "open_in_new"
                    label: Translation.tr("Troubleshoot")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki/Troubleshooting")
                }

                WelcomeActionButton {
                    materialIcon: "menu_book"
                    label: Translation.tr("Docs")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/wiki")
                }

                WelcomeActionButton {
                    materialIcon: "bug_report"
                    label: Translation.tr("Report")
                    onClicked: Qt.openUrlExternally("https://github.com/snowarch/inir/issues")
                }
            }

            Item { Layout.preferredHeight: 2 }
        }
    }
}
