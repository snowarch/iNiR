import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.overview

ContentPage {
    id: root
    settingsPageIndex: 27
    settingsPageName: Translation.tr("Orbit")
    property string activeSection: "activation"
    property bool resetArmed: false

    Timer {
        id: resetArmTimer
        interval: 3000
        onTriggered: root.resetArmed = false
    }

    readonly property var orbitOptions: Config.options?.orbit ?? {}
    readonly property var shelfOptions: orbitOptions.shelf ?? {}
    readonly property var pocketOptions: orbitOptions.pocket ?? {}
    readonly property string configuredHotCorner: orbitOptions.hotCorner ?? "topRight"
    readonly property var hotCornerConflictOutputs: Object.keys(NiriService.outputs ?? {}).filter(outputName =>
        NiriService.isOverviewHotCornerActive(outputName, root.configuredHotCorner))
    readonly property var shelfModules: Array.isArray(shelfOptions.modules)
        ? shelfOptions.modules : ["locator", "trail", "niri", "actions", "stash"]
    readonly property var niriActionCatalog: [
        { id: "focusLeft", name: Translation.tr("Focus left"), icon: "arrow_back" },
        { id: "focusRight", name: Translation.tr("Focus right"), icon: "arrow_forward" },
        { id: "moveFirst", name: Translation.tr("Move first"), icon: "first_page" },
        { id: "moveLast", name: Translation.tr("Move last"), icon: "last_page" },
        { id: "maximize", name: Translation.tr("Maximize"), icon: "open_in_full" },
        { id: "consume", name: Translation.tr("Consume"), icon: "merge_type" },
        { id: "expel", name: Translation.tr("Expel"), icon: "call_split" }
    ]

    function hotCornerDisplayName(corner: string): string {
        if (corner === "topLeft") return Translation.tr("Top left")
        if (corner === "topRight") return Translation.tr("Top right")
        if (corner === "bottomLeft") return Translation.tr("Bottom left")
        return Translation.tr("Bottom right")
    }
    readonly property var niriActions: Array.isArray(shelfOptions.niriActions)
        ? shelfOptions.niriActions : ["maximize", "consume", "expel"]
    readonly property var availableNiriActions: niriActionCatalog
        .filter(action => !niriActions.includes(action.id))
    readonly property var actionOptions: {
        const result = [{ value: "", displayName: Translation.tr("None") }]
        for (const action of GlobalActions.allActions ?? []) {
            result.push({
                value: action.id,
                displayName: `${action.name} · ${action.category}`
            })
        }
        return result
    }

    function pinnedAction(slot: int): string {
        const defaults = ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const actions = Array.isArray(root.shelfOptions.pinnedActions)
            ? root.shelfOptions.pinnedActions : defaults
        return actions[slot] ?? ""
    }

    function actionChoiceIndex(value: string): int {
        const index = root.actionOptions.findIndex(option => option.value === value)
        return index >= 0 ? index : 0
    }

    function setPinnedAction(slot: int, actionId: string): void {
        const defaults = ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const actions = Array.isArray(root.shelfOptions.pinnedActions)
            ? [...root.shelfOptions.pinnedActions] : defaults
        while (actions.length < 3) actions.push("")
        actions[slot] = actionId
        Config.setNestedValue("orbit.shelf.pinnedActions", actions)
    }

    SettingsTaskNavigator {
        icon: "hub"
        title: Translation.tr("Orbit")
        description: Translation.tr("Shape the Niri workspace navigator around how you move through windows every day.")
        summary: Translation.tr("Activation · layout · navigation · shelf · motion")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        searchAliases: ({
            "workspace layout": "layout",
            "material motion": "motion"
        })
        options: [
            { displayName: Translation.tr("Activation"), icon: "ads_click", value: "activation" },
            { displayName: Translation.tr("Layout"), icon: "view_carousel", value: "layout" },
            { displayName: Translation.tr("Navigation"), icon: "route", value: "navigation" },
            { displayName: Translation.tr("Shelf"), icon: "shelf_auto_hide", value: "shelf" },
            { displayName: Translation.tr("Motion"), icon: "animation", value: "motion" }
        ]
    }

    SettingsTaskLoader {
        requested: root.activeSection === "activation"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "activation"
        expanded: true
        icon: "ads_click"
        title: Translation.tr("Activation")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: CompositorService.isNiri
                    ? Translation.tr("Orbit is a Material workspace navigator built for Niri. The taskview IPC remains as a compatibility alias.")
                    : Translation.tr("Orbit is currently available on Niri.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            ConfigSwitch {
                text: Translation.tr("Enable Orbit")
                description: Translation.tr("Allow Orbit to open from its hot corner and IPC entry point")
                checked: root.orbitOptions.enable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.enable", checked)
            }

            ConfigSwitch {
                enabled: root.orbitOptions.enable ?? true
                text: Translation.tr("Hot corner")
                description: Translation.tr("Open Orbit by pushing the pointer into the selected screen corner")
                checked: root.orbitOptions.hotCornerEnable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.hotCornerEnable", checked)
            }

            ContentSubsection {
                title: Translation.tr("Corner")
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)

                ConfigSelectionArray {
                    currentValue: root.configuredHotCorner
                    onSelected: value => Config.setNestedValue("orbit.hotCorner", value)
                    options: [
                        { displayName: Translation.tr("Top left"), icon: "north_west", value: "topLeft" },
                        { displayName: Translation.tr("Top right"), icon: "north_east", value: "topRight" },
                        { displayName: Translation.tr("Bottom left"), icon: "south_west", value: "bottomLeft" },
                        { displayName: Translation.tr("Bottom right"), icon: "south_east", value: "bottomRight" }
                    ]
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.hotCornerConflictOutputs.length > 0
                    text: Translation.tr("Niri Overview already owns %1 on %2. Orbit will not claim that corner there.")
                        .arg(root.hotCornerDisplayName(root.configuredHotCorner))
                        .arg(root.hotCornerConflictOutputs.join(", "))
                    color: Appearance.colors.colError
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)
                icon: "crop_free"
                text: Translation.tr("Corner capture area")
                description: Translation.tr("Invisible square that receives pointer movement near the corner")
                value: root.orbitOptions.hotCornerSize ?? 12
                from: 4
                to: 40
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.hotCornerSize", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)
                icon: "near_me"
                text: Translation.tr("Activation distance")
                description: Translation.tr("How close the pointer must get to both screen edges before Orbit opens")
                value: root.orbitOptions.hotCornerActivationDistance ?? 2
                from: 1
                to: 32
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.hotCornerActivationDistance", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.orbitOptions.enable ?? true) && (root.orbitOptions.hotCornerEnable ?? true)
                icon: "timer"
                text: Translation.tr("Corner dwell")
                description: Translation.tr("Milliseconds to hold the pointer in the exact corner; 0 opens immediately")
                value: root.orbitOptions.hotCornerDwellMs ?? 0
                from: 0
                to: 500
                stepSize: 25
                onValueChanged: Config.setNestedValue("orbit.hotCornerDwellMs", value)
            }

            RippleButtonWithIcon {
                enabled: CompositorService.isNiri && (root.orbitOptions.enable ?? true)
                materialIcon: "open_in_full"
                mainText: Translation.tr("Open Orbit")
                onClicked: GlobalStates.openOrbit("")
            }

            RippleButtonWithIcon {
                materialIcon: root.resetArmed ? "warning" : "restart_alt"
                mainText: root.resetArmed
                    ? Translation.tr("Confirm reset Orbit")
                    : Translation.tr("Reset Orbit to defaults")
                onClicked: {
                    if (!root.resetArmed) {
                        root.resetArmed = true
                        resetArmTimer.restart()
                        return
                    }
                    resetArmTimer.stop()
                    root.resetArmed = false
                    GlobalStates.orbitStageOverride = ""
                    Config.setNestedValues(OrbitTuning.defaultConfigUpdates())
                }
            }

            ContentSubsection {
                title: Translation.tr("Orbit Studio")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.studio?.surfaceStyle ?? "ricelin"
                    onSelected: value => Config.setNestedValue("orbit.studio.surfaceStyle", value)
                    options: [
                        { displayName: Translation.tr("Current style"), icon: "category", value: "current" },
                        { displayName: Translation.tr("Ricelin"), icon: "blur_on", value: "ricelin" }
                    ]
                }

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.studio?.density ?? "compact"
                    onSelected: value => Config.setNestedValue("orbit.studio.density", value)
                    options: [
                        { displayName: Translation.tr("Compact"), icon: "density_small", value: "compact" },
                        { displayName: Translation.tr("Comfortable"), icon: "density_medium", value: "comfortable" }
                    ]
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "width"
                    text: Translation.tr("Docked Studio width")
                    description: Translation.tr("Percentage of the output reserved by Focus Studio")
                    value: root.orbitOptions.studio?.widthPercent ?? 26
                    from: 20
                    to: 34
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.studio.widthPercent", value)
                }

                ConfigSwitch {
                    text: Translation.tr("Section descriptions")
                    description: Translation.tr("Show the short explanation under each Studio section title")
                    checked: root.orbitOptions.studio?.showDescriptions ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.studio.showDescriptions", checked)
                }
            }
        }
    }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "layout"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "layout"
        expanded: true
        icon: "view_carousel"
        title: Translation.tr("Workspace layout")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Orbit profile")

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Profiles apply a complete starting point across layout, motion, surfaces, Shelf and atmosphere. Fine controls remain editable afterwards.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                ConfigSelectionArray {
                    currentValue: ""
                    onSelected: value => Config.setNestedValues(OrbitTuning.profileUpdates(value))
                    options: [
                        { displayName: Translation.tr("Balanced"), icon: "balance", value: "balanced" },
                        { displayName: Translation.tr("Classic"), icon: "view_carousel", value: "classic" },
                        { displayName: Translation.tr("Spatial"), icon: "view_in_ar", value: "spatial" },
                        { displayName: Translation.tr("Minimal"), icon: "remove", value: "minimal" },
                        { displayName: Translation.tr("Cinematic"), icon: "movie", value: "cinematic" }
                    ]
                }

                RippleButtonWithIcon {
                    materialIcon: "bookmark_add"
                    mainText: Translation.tr("Save current as user preset")
                    onClicked: Config.setNestedValue("orbit.userPresetJson",
                        OrbitTuning.captureUserPreset(root.orbitOptions))
                }

                RippleButtonWithIcon {
                    enabled: String(root.orbitOptions.userPresetJson ?? "").length > 0
                    materialIcon: "bookmark"
                    mainText: Translation.tr("Apply user preset")
                    onClicked: Config.setNestedValues(OrbitTuning.userPresetUpdates(
                        String(root.orbitOptions.userPresetJson ?? "")))
                }
            }

            ContentSubsection {
                title: Translation.tr("Stage")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.stageMode ?? "stage"
                    onSelected: value => Config.setNestedValue("orbit.stageMode", value)
                    options: [
                        { displayName: Translation.tr("Stage"), icon: "view_carousel", value: "stage" },
                        { displayName: Translation.tr("Orbital"), icon: "orbit", value: "orbital" }
                    ]
                }
            }

            ContentSubsection {
                visible: (root.orbitOptions.stageMode ?? "stage") === "orbital"
                title: Translation.tr("Orbital space")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.orbital?.layout ?? "orbit"
                    onSelected: value => Config.setNestedValue("orbit.orbital.layout", value)
                    options: [
                        { displayName: Translation.tr("Orbit"), icon: "orbit", value: "orbit" },
                        { displayName: Translation.tr("Horizon"), icon: "view_in_ar", value: "horizon" },
                        { displayName: Translation.tr("Gallery"), icon: "view_carousel", value: "gallery" },
                        { displayName: Translation.tr("Deck"), icon: "stacks", value: "deck" },
                        { displayName: Translation.tr("Atlas"), icon: "grid_view", value: "atlas" }
                    ]
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "hub"
                    text: Translation.tr("Visible workspaces")
                    value: root.orbitOptions.orbital?.visibleWorkspaces ?? 5
                    from: 3
                    to: 7
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("orbit.orbital.visibleWorkspaces", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "center_focus_strong"
                    text: Translation.tr("Core size")
                    value: root.orbitOptions.orbital?.coreSizePercent ?? 48
                    from: 36
                    to: 62
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.coreSizePercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "satellite_alt"
                    text: Translation.tr("Satellite size")
                    value: root.orbitOptions.orbital?.satelliteSizePercent ?? 42
                    from: 28
                    to: 60
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.satelliteSizePercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "swap_horiz"
                    text: Translation.tr("Horizontal spread")
                    value: root.orbitOptions.orbital?.horizontalSpreadPercent ?? 82
                    from: 58
                    to: 96
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.horizontalSpreadPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "height"
                    text: Translation.tr("Vertical spread")
                    value: root.orbitOptions.orbital?.verticalSpreadPercent ?? 58
                    from: 40
                    to: 82
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.verticalSpreadPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "layers"
                    text: Translation.tr("Depth")
                    description: Translation.tr("Perspective separation between front and rear workspace satellites")
                    value: root.orbitOptions.orbital?.depthPercent ?? 18
                    from: 0
                    to: 35
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.depthPercent", value)
                }

                ContentSubsection {
                    title: Translation.tr("Advanced geometry")

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "padding"
                        text: Translation.tr("Orbit edge padding")
                        value: root.orbitOptions.orbital?.geometry?.edgePadding ?? 10
                        from: 0
                        to: 48
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.edgePadding", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "view_column"
                        text: Translation.tr("Horizon card gap")
                        value: root.orbitOptions.orbital?.geometry?.horizonGap ?? 12
                        from: 0
                        to: 48
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.horizonGap", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "width"
                        text: Translation.tr("Horizon rail inset")
                        value: root.orbitOptions.orbital?.geometry?.horizonInset ?? 24
                        from: 0
                        to: 96
                        stepSize: 4
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.horizonInset", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "vertical_align_center"
                        text: Translation.tr("Horizon base separation")
                        value: root.orbitOptions.orbital?.geometry?.horizonVerticalBase ?? 8
                        from: 0
                        to: 80
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.horizonVerticalBase", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "height"
                        text: Translation.tr("Horizon spread range")
                        value: root.orbitOptions.orbital?.geometry?.horizonVerticalRange ?? 26
                        from: 0
                        to: 96
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.horizonVerticalRange", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "space_bar"
                        text: Translation.tr("Gallery side gap")
                        value: root.orbitOptions.orbital?.geometry?.galleryBaseGap ?? 34
                        from: 0
                        to: 120
                        stepSize: 4
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.galleryBaseGap", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "swap_vert"
                        text: Translation.tr("Gallery row gap")
                        value: root.orbitOptions.orbital?.geometry?.galleryRowGap ?? 14
                        from: 0
                        to: 48
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.galleryRowGap", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "space_bar"
                        text: Translation.tr("Deck base gap")
                        value: root.orbitOptions.orbital?.geometry?.deckBaseGap ?? 26
                        from: 0
                        to: 120
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.deckBaseGap", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "stacks"
                        text: Translation.tr("Deck stack step")
                        value: root.orbitOptions.orbital?.geometry?.deckStep ?? 44
                        from: 12
                        to: 120
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.deckStep", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "swap_vert"
                        text: Translation.tr("Deck fan step")
                        value: root.orbitOptions.orbital?.geometry?.deckLiftStep ?? 24
                        from: 0
                        to: 80
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.deckLiftStep", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "grid_view"
                        text: Translation.tr("Atlas card gap")
                        value: root.orbitOptions.orbital?.geometry?.atlasGap ?? 14
                        from: 0
                        to: 48
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.atlasGap", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "view_column"
                        text: Translation.tr("Atlas columns")
                        value: root.orbitOptions.orbital?.geometry?.atlasColumns ?? 3
                        from: 2
                        to: 3
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.atlasColumns", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "center_focus_strong"
                        text: Translation.tr("Atlas Core emphasis")
                        value: root.orbitOptions.orbital?.geometry?.atlasCoreBoostPercent ?? 10
                        from: 0
                        to: 20
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.atlasCoreBoostPercent", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "crop_free"
                        text: Translation.tr("Core content inset")
                        value: root.orbitOptions.orbital?.geometry?.coreContentMargin ?? 9
                        from: 0
                        to: 28
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.coreContentMargin", value)
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "crop_din"
                        text: Translation.tr("Satellite content inset")
                        value: root.orbitOptions.orbital?.geometry?.satelliteContentMargin ?? 6
                        from: 0
                        to: 24
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("orbit.orbital.geometry.satelliteContentMargin", value)
                    }
                }

                ConfigSwitch {
                    text: Translation.tr("Satellite window previews")
                    description: Translation.tr("Disable to keep full previews only in the core workspace and reduce capture work")
                    checked: root.orbitOptions.orbital?.satellitePreviews ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.orbital.satellitePreviews", checked)
                }

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.orbital?.satelliteClickAction ?? "select"
                    onSelected: value => Config.setNestedValue("orbit.orbital.satelliteClickAction", value)
                    options: [
                        { displayName: Translation.tr("Select as core"), icon: "center_focus_strong", value: "select" },
                        { displayName: Translation.tr("Enter directly"), icon: "login", value: "enter" }
                    ]
                }

                ConfigSelectionArray {
                    currentValue: {
                        const configured = String(root.orbitOptions.orbital?.workspaceLabelMode ?? "")
                        if (["index", "name", "workspace", "full", "off"].includes(configured)) return configured
                        return (root.orbitOptions.orbital?.showWorkspaceLabels ?? true) ? "index" : "off"
                    }
                    onSelected: value => Config.setNestedValue("orbit.orbital.workspaceLabelMode", value)
                    options: [
                        { displayName: Translation.tr("Number"), icon: "tag", value: "index" },
                        { displayName: Translation.tr("Name"), icon: "label", value: "name" },
                        { displayName: Translation.tr("Workspace"), icon: "view_week", value: "workspace" },
                        { displayName: Translation.tr("Full"), icon: "subject", value: "full" },
                        { displayName: Translation.tr("Hidden"), icon: "visibility_off", value: "off" }
                    ]
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: String(root.orbitOptions.orbital?.workspaceLabelMode ?? "") === "name"
                        && !(NiriService.allWorkspaces ?? []).some(workspace =>
                            String(workspace?.name ?? "").trim().length > 0)
                    text: Translation.tr("Niri currently reports no named workspaces. Name labels will show Unnamed until workspace names are assigned.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                ConfigSwitch {
                    text: Translation.tr("Workspace wallpaper")
                    description: Translation.tr("Show the wallpaper currently in use on this output behind each virtual workspace")
                    checked: root.orbitOptions.orbital?.showWorkspaceWallpaper ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.orbital.showWorkspaceWallpaper", checked)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.orbital?.showWorkspaceWallpaper ?? true
                    icon: "opacity"
                    text: Translation.tr("Workspace wallpaper strength")
                    value: root.orbitOptions.orbital?.workspaceWallpaperOpacity ?? 70
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("orbit.orbital.workspaceWallpaperOpacity", value)
                }
            }

            ContentSubsection {
                visible: (root.orbitOptions.stageMode ?? "stage") === "stage"
                title: Translation.tr("Classic stage")

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "view_week"
                    text: Translation.tr("Visible workspaces")
                    value: root.orbitOptions.workspaceCount ?? 3
                    from: 1
                    to: 5
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.workspaceCount", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "zoom_out_map"
                    text: Translation.tr("Workspace scale")
                    description: Translation.tr("Percentage of the monitor size used by each workspace preview")
                    value: root.orbitOptions.workspaceScalePercent ?? 27
                    from: 16
                    to: 42
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.workspaceScalePercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "width"
                    text: Translation.tr("Maximum panel width")
                    value: root.orbitOptions.maxPanelWidthPercent ?? 92
                    from: 60
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.maxPanelWidthPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "space_bar"
                    text: Translation.tr("Workspace spacing")
                    value: root.orbitOptions.workspaceSpacing ?? 18
                    from: 0
                    to: 40
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.workspaceSpacing", value)
                }

                ContentSubsection {
                    title: Translation.tr("Window labels")

                    ConfigSelectionArray {
                        currentValue: root.orbitOptions.windowLabels ?? "hover"
                        onSelected: value => Config.setNestedValue("orbit.windowLabels", value)
                        options: [
                            { displayName: Translation.tr("On hover"), icon: "ads_click", value: "hover" },
                            { displayName: Translation.tr("Always"), icon: "label", value: "always" },
                            { displayName: Translation.tr("Off"), icon: "label_off", value: "off" }
                        ]
                    }
                }

                ConfigSwitch {
                    enabled: (root.orbitOptions.windowLabels ?? "hover") !== "off"
                    text: Translation.tr("App icons in window labels")
                    checked: root.orbitOptions.windowLabelIcons ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.windowLabelIcons", checked)
                }

                ConfigSwitch {
                    text: Translation.tr("Balanced window grid")
                    description: Translation.tr("Prefer readable 2D cards instead of reproducing Niri's scrolling columns literally")
                    checked: root.orbitOptions.balancedGrid ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.balancedGrid", checked)
                }
            }

            ContentSubsection {
                title: Translation.tr("Workspace surface")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.orbital?.surface?.style ?? "current"
                    onSelected: value => Config.setNestedValue("orbit.orbital.surface.style", value)
                    options: [
                        { displayName: Translation.tr("Current style"), icon: "category", value: "current" },
                        { displayName: Translation.tr("Ricelin"), icon: "blur_on", value: "ricelin" }
                    ]
                }

                ConfigSwitch {
                    text: Translation.tr("Workspace outline")
                    checked: root.orbitOptions.orbital?.surface?.outline ?? true
                    onCheckedChanged: Config.setNestedValue("orbit.orbital.surface.outline", checked)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.orbital?.surface?.outline ?? true
                    icon: "border_style"
                    text: Translation.tr("Outline width")
                    description: Translation.tr("Stroke thickness around workspace previews")
                    value: root.orbitOptions.orbital?.surface?.outlineWidth ?? 1
                    from: 0
                    to: 4
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.surface.outlineWidth", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.orbital?.surface?.outline ?? true
                    icon: "opacity"
                    text: Translation.tr("Outline intensity")
                    description: Translation.tr("Opacity of active/core workspace outlines")
                    value: root.orbitOptions.orbital?.surface?.outlineOpacityPercent ?? 72
                    from: 0
                    to: 100
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("orbit.orbital.surface.outlineOpacityPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "rounded_corner"
                    text: Translation.tr("Workspace rounding")
                    value: root.orbitOptions.orbital?.surface?.radiusPercent ?? 100
                    from: 55
                    to: 160
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("orbit.orbital.surface.radiusPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    icon: "padding"
                    text: Translation.tr("Material frame inset")
                    description: Translation.tr("Leaves a visible band of the selected workspace material around wallpaper and previews")
                    value: root.orbitOptions.orbital?.surface?.frameInset ?? 5
                    from: 0
                    to: 18
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("orbit.orbital.surface.frameInset", value)
                }

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.orbital?.surface?.shadowMode ?? "core"
                    onSelected: value => Config.setNestedValue("orbit.orbital.surface.shadowMode", value)
                    options: [
                        { displayName: Translation.tr("Off"), icon: "shadow_minus", value: "off" },
                        { displayName: Translation.tr("Core only"), icon: "filter_center_focus", value: "core" },
                        { displayName: Translation.tr("All cards"), icon: "select_all", value: "all" }
                    ]
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: (root.orbitOptions.orbital?.surface?.shadowMode ?? "core") !== "off"
                    icon: "opacity"
                    text: Translation.tr("Shadow intensity")
                    value: root.orbitOptions.orbital?.surface?.shadowOpacityPercent ?? 72
                    from: 0
                    to: 100
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("orbit.orbital.surface.shadowOpacityPercent", value)
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "grid_view"
                text: Translation.tr("Window gap")
                value: root.orbitOptions.windowGap ?? 4
                from: 0
                to: 16
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.windowGap", value)
            }

        }
    }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "navigation"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "navigation"
        expanded: true
        icon: "route"
        title: Translation.tr("Navigation")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Close after selecting a window")
                checked: root.orbitOptions.closeOnSelect ?? true
                onCheckedChanged: Config.setNestedValue("orbit.closeOnSelect", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Keyboard navigation")
                description: Translation.tr("Navigate previews and Shelf controls without leaving Orbit")
                checked: root.orbitOptions.keyboardNavigation ?? true
                onCheckedChanged: Config.setNestedValue("orbit.keyboardNavigation", checked)
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.orbitOptions.keyboardNavigation ?? true
                text: (root.orbitOptions.stageMode ?? "stage") === "orbital"
                    ? Translation.tr("Tab cycles core windows, Shelf and Pocket · ←/→ rotates Orbit · ↑/↓ selects core windows · Ctrl+←/→ or PageUp/PageDown switches Niri workspaces · Space enters the core workspace · Shift+←/→ moves the selected window · Enter activates · Delete closes · S stashes · Menu or Shift+F10 opens window actions · P opens Pocket · O switches Stage/Orbital")
                    : Translation.tr("Tab cycles previews, Shelf and Pocket · arrows navigate · Shift+←/→ moves the selected window · Ctrl+←/→ or PageUp/PageDown switches workspaces · Enter activates · Delete closes · S stashes · Menu or Shift+F10 opens window actions · P opens Pocket · O switches Stage/Orbital")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            ConfigSwitch {
                text: Translation.tr("Scroll between workspaces")
                checked: root.orbitOptions.scrollNavigation ?? true
                onCheckedChanged: Config.setNestedValue("orbit.scrollNavigation", checked)
            }

            ConfigSwitch {
                visible: (root.orbitOptions.stageMode ?? "stage") === "orbital"
                enabled: root.orbitOptions.scrollNavigation ?? true
                text: Translation.tr("Switch Niri workspace")
                description: Translation.tr("When enabled, wheel navigation changes the real Niri workspace. Disable it to preview the Orbit Core only.")
                checked: root.orbitOptions.scrollSwitchWorkspace ?? true
                onCheckedChanged: Config.setNestedValue("orbit.scrollSwitchWorkspace", checked)
            }

            ConfigSwitch {
                enabled: root.orbitOptions.scrollNavigation ?? true
                text: Translation.tr("Wrap around")
                description: Translation.tr("Continue from the last workspace to the first, and from the first back to the last")
                checked: root.orbitOptions.scrollWrapAround ?? false
                onCheckedChanged: Config.setNestedValue("orbit.scrollWrapAround", checked)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: root.orbitOptions.scrollNavigation ?? true
                icon: "speed"
                text: Translation.tr("Wheel ticks per workspace")
                description: Translation.tr("1 changes on each wheel notch; higher values require more wheel movement")
                value: root.orbitOptions.scrollSteps ?? 1
                from: 1
                to: 4
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.scrollSteps", value)
            }

            ConfigSwitch {
                text: Translation.tr("Right-drag canvas scrub")
                description: Translation.tr("Drag empty Orbit space horizontally to step through workspaces")
                checked: root.orbitOptions.canvasScrubNavigation ?? true
                onCheckedChanged: Config.setNestedValue("orbit.canvasScrubNavigation", checked)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: root.orbitOptions.canvasScrubNavigation ?? true
                icon: "swipe"
                text: Translation.tr("Scrub step distance")
                value: root.orbitOptions.canvasScrubThreshold ?? 96
                from: 48
                to: 180
                stepSize: 4
                onValueChanged: Config.setNestedValue("orbit.canvasScrubThreshold", value)
            }
        }
    }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "shelf"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "shelf"
        expanded: true
        icon: "shelf_auto_hide"
        title: Translation.tr("Orbit Shelf")

        SettingsGroup {
            ConfigSwitch {
                text: Translation.tr("Show Shelf")
                description: Translation.tr("Keep fast window history, Niri controls and shell actions below the workspace band")
                checked: root.shelfOptions.enable ?? true
                onCheckedChanged: Config.setNestedValue("orbit.shelf.enable", checked)
            }

            ConfigSwitch {
                enabled: root.shelfOptions.enable ?? true
                text: Translation.tr("Studio button")
                description: Translation.tr("Keep the live Orbit Studio editor one click away in the workspace locator")
                checked: root.shelfOptions.showStudioButton ?? true
                onCheckedChanged: Config.setNestedValue("orbit.shelf.showStudioButton", checked)
            }

            ContentSubsection {
                title: Translation.tr("Shelf layout")
                enabled: root.shelfOptions.enable ?? true

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.layout ?? "islands"
                    onSelected: value => Config.setNestedValue("orbit.shelf.layout", value)
                    options: [
                        { displayName: Translation.tr("Bar"), icon: "horizontal_rule", value: "bar" },
                        { displayName: Translation.tr("Islands"), icon: "view_week", value: "islands" },
                        { displayName: Translation.tr("Minimal"), icon: "more_horiz", value: "minimal" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Shelf density")
                enabled: root.shelfOptions.enable ?? true

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.density ?? "comfortable"
                    onSelected: value => Config.setNestedValue("orbit.shelf.density", value)
                    options: [
                        { displayName: Translation.tr("Comfortable"), icon: "density_medium", value: "comfortable" },
                        { displayName: Translation.tr("Compact"), icon: "density_small", value: "compact" },
                        { displayName: Translation.tr("HUGE AS YOUR MOM"), icon: "density_large", value: "huge" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Shelf labels")
                enabled: root.shelfOptions.enable ?? true

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.labels ?? "auto"
                    onSelected: value => Config.setNestedValue("orbit.shelf.labels", value)
                    options: [
                        { displayName: Translation.tr("Automatic"), icon: "auto_awesome", value: "auto" },
                        { displayName: Translation.tr("Always"), icon: "label", value: "always" },
                        { displayName: Translation.tr("Icons only"), icon: "apps", value: "icons" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Shelf surface")
                enabled: root.shelfOptions.enable ?? true

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Applies the selected material to Bar, Islands and Minimal without changing their layout behavior.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.islandStyle ?? "material"
                    onSelected: value => Config.setNestedValue("orbit.shelf.islandStyle", value)
                    options: [
                        { displayName: Translation.tr("Current style"), icon: "category", value: "material" },
                        { displayName: Translation.tr("Ricelin"), icon: "blur_on", value: "ricelin" }
                    ]
                }

            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: root.shelfOptions.enable ?? true
                icon: "space_bar"
                text: Translation.tr("Module spacing")
                description: Translation.tr("Gap between Shelf modules")
                value: root.shelfOptions.moduleSpacing ?? 7
                from: 0
                to: 16
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.shelf.moduleSpacing", value)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                visible: (root.shelfOptions.layout ?? "islands") === "islands"
                enabled: (root.shelfOptions.enable ?? true) && visible
                icon: "padding"
                text: Translation.tr("Island padding")
                description: Translation.tr("Horizontal breathing room inside each Shelf island; the workspace locator keeps an additional safe inset")
                value: root.shelfOptions.islandPadding ?? 8
                from: 6
                to: 16
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.shelf.islandPadding", value)
            }

            ContentSubsection {
                title: Translation.tr("Workspace locator")
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("locator")

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.locatorLabel ?? "auto"
                    onSelected: value => Config.setNestedValue("orbit.shelf.locatorLabel", value)
                    options: [
                        { displayName: Translation.tr("Automatic"), icon: "auto_awesome", value: "auto" },
                        { displayName: Translation.tr("Index"), icon: "tag", value: "index" },
                        { displayName: Translation.tr("Name"), icon: "label", value: "name" }
                    ]
                }
            }

            ConfigSwitch {
                enabled: root.shelfOptions.enable ?? true
                text: Translation.tr("Recent window Trail")
                description: Translation.tr("Allow the Trail module to surface recently focused windows")
                checked: root.orbitOptions.showTrail ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showTrail", checked)
            }

            ConfigSwitch {
                text: Translation.tr("Enable Stash")
                description: Translation.tr("Reveal the Stash drop target while dragging; its Shelf module can be hidden independently")
                checked: root.orbitOptions.showStash ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showStash", checked)
            }

            ConfigSwitch {
                text: Translation.tr("New workspace drop target")
                description: Translation.tr("Offer Niri's trailing empty workspace as a fast destination while dragging a window")
                checked: root.orbitOptions.showNewWorkspaceDrop ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showNewWorkspaceDrop", checked)
            }

            OrbitShelfEditor {
                enabled: root.shelfOptions.enable ?? true
            }

            M3LayoutSection {
                visible: root.shelfModules.includes("niri")
                enabled: (root.shelfOptions.enable ?? true) && visible
                sectionTitle: Translation.tr("Niri controls")
                layout: root.niriActions
                availableWidgets: root.availableNiriActions
                getWidgetName: id => root.niriActionCatalog.find(action => action.id === id)?.name ?? id
                onUpdate: list => Config.setNestedValue("orbit.shelf.niriActions", list)
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("trail")
                    && (root.orbitOptions.showTrail ?? true)
                icon: "history"
                text: Translation.tr("Trail windows")
                description: Translation.tr("Maximum recent windows shown before the Shelf switches to icon-only layout")
                value: root.orbitOptions.trailItems ?? 5
                from: 2
                to: 8
                stepSize: 1
                onValueChanged: Config.setNestedValue("orbit.trailItems", value)
            }

            ContentSubsection {
                title: Translation.tr("Trail scope")
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("trail")
                    && (root.orbitOptions.showTrail ?? true)

                ConfigSelectionArray {
                    currentValue: root.shelfOptions.trailScope ?? "output"
                    onSelected: value => Config.setNestedValue("orbit.shelf.trailScope", value)
                    options: [
                        { displayName: Translation.tr("This monitor"), icon: "monitor", value: "output" },
                        { displayName: Translation.tr("Current workspace"), icon: "crop_square", value: "workspace" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Restore stashed windows")
                enabled: root.orbitOptions.showStash ?? true

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.stashRestoreMode ?? "original"
                    onSelected: value => Config.setNestedValue("orbit.stashRestoreMode", value)
                    options: [
                        { displayName: Translation.tr("Original workspace"), icon: "undo", value: "original" },
                        { displayName: Translation.tr("Current workspace"), icon: "my_location", value: "current" }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Pocket layout")
                enabled: root.orbitOptions.showStash ?? true

                ConfigSelectionArray {
                    currentValue: root.pocketOptions.layout ?? "cards"
                    onSelected: value => Config.setNestedValue("orbit.pocket.layout", value)
                    options: [
                        { displayName: Translation.tr("Cards"), icon: "view_module", value: "cards" },
                        { displayName: Translation.tr("List"), icon: "view_list", value: "list" }
                    ]
                }
            }

            ConfigSwitch {
                enabled: root.orbitOptions.showStash ?? true
                text: Translation.tr("Pocket snapshots")
                description: Translation.tr("Show cached window previews in Pocket; disable for a denser icon-first view")
                checked: root.pocketOptions.showPreviews ?? true
                onCheckedChanged: Config.setNestedValue("orbit.pocket.showPreviews", checked)
            }

            ConfigSwitch {
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("actions")
                text: Translation.tr("Close Orbit after an action")
                description: Translation.tr("Dismiss Orbit before launching a pinned shell action")
                checked: root.shelfOptions.closeOnAction ?? true
                onCheckedChanged: Config.setNestedValue("orbit.shelf.closeOnAction", checked)
            }

            ColumnLayout {
                Layout.fillWidth: true
                enabled: (root.shelfOptions.enable ?? true)
                    && root.shelfModules.includes("actions")
                spacing: 8

                StyledText {
                    text: Translation.tr("Pinned actions")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Choose any built-in or custom Global Action. The Shelf also keeps an All actions button.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: 3

                    delegate: RowLayout {
                        id: actionSlot
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        StyledText {
                            Layout.preferredWidth: 72
                            text: Translation.tr("Slot %1").arg(actionSlot.index + 1)
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }

                        StyledComboBox {
                            Layout.fillWidth: true
                            model: root.actionOptions
                            textRole: "displayName"
                            currentIndex: root.actionChoiceIndex(root.pinnedAction(actionSlot.index))
                            settingsSearchLabel: Translation.tr("Orbit pinned action %1").arg(actionSlot.index + 1)
                            settingsSearchDescription: Translation.tr("Action launched from the Orbit Shelf")
                            onActivated: index => {
                                if (index >= 0 && index < root.actionOptions.length)
                                    root.setPinnedAction(actionSlot.index, root.actionOptions[index].value)
                            }
                        }
                    }
                }
            }
        }
    }
        }
    }

    SettingsTaskLoader {
        requested: root.activeSection === "motion"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "motion"
        expanded: true
        icon: "animation"
        title: Translation.tr("Material motion")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Orbit presentation")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.presentation?.preset ?? "adaptive"
                    onSelected: value => Config.setNestedValues({
                        "orbit.presentation.preset": value,
                        "orbit.presentation.advanced": false
                    })
                    options: [
                        { displayName: Translation.tr("By view"), icon: "auto_awesome_motion", value: "adaptive" },
                        { displayName: Translation.tr("Soft"), icon: "blur_on", value: "soft" },
                        { displayName: Translation.tr("Float"), icon: "air", value: "float" },
                        { displayName: Translation.tr("Sweep"), icon: "motion_blur", value: "sweep" },
                        { displayName: Translation.tr("Instant"), icon: "bolt", value: "instant" }
                    ]
                }

                ConfigSwitch {
                    text: Translation.tr("Advanced presentation")
                    description: Translation.tr("Tune entry assembly and exit travel behind the preset")
                    checked: root.orbitOptions.presentation?.advanced ?? false
                    onCheckedChanged: Config.setNestedValue("orbit.presentation.advanced", checked)
                }

                ConfigSelectionArray {
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    currentValue: root.orbitOptions.presentation?.entryStyle ?? "cascade"
                    onSelected: value => Config.setNestedValue("orbit.presentation.entryStyle", value)
                    options: [
                        { displayName: Translation.tr("Fade"), icon: "opacity", value: "fade" },
                        { displayName: Translation.tr("Drift"), icon: "air", value: "drift" },
                        { displayName: Translation.tr("Cascade"), icon: "view_timeline", value: "cascade" },
                        { displayName: Translation.tr("Instant"), icon: "bolt", value: "instant" }
                    ]
                }

                ConfigSelectionArray {
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    enabled: (root.orbitOptions.presentation?.preset ?? "float") !== "instant"
                    currentValue: root.orbitOptions.presentation?.direction ?? "top"
                    onSelected: value => Config.setNestedValue("orbit.presentation.direction", value)
                    options: [
                        { displayName: Translation.tr("Center"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Top"), icon: "north", value: "top" },
                        { displayName: Translation.tr("Bottom"), icon: "south", value: "bottom" },
                        { displayName: Translation.tr("Left"), icon: "west", value: "left" },
                        { displayName: Translation.tr("Right"), icon: "east", value: "right" }
                    ]
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    enabled: (root.orbitOptions.presentation?.preset ?? "float") !== "instant"
                    icon: "open_with"
                    text: Translation.tr("Travel distance")
                    value: root.orbitOptions.presentation?.distance ?? 92
                    from: 0
                    to: 160
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("orbit.presentation.distance", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    enabled: (root.orbitOptions.presentation?.preset ?? "float") !== "instant"
                    icon: "login"
                    text: Translation.tr("Enter duration")
                    value: root.orbitOptions.presentation?.enterDurationMs ?? 300
                    from: 80
                    to: 600
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("orbit.presentation.enterDurationMs", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    enabled: (root.orbitOptions.presentation?.preset ?? "float") !== "instant"
                    icon: "logout"
                    text: Translation.tr("Exit duration")
                    value: root.orbitOptions.presentation?.exitDurationMs ?? 220
                    from: 60
                    to: 500
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("orbit.presentation.exitDurationMs", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    icon: "hourglass_top"
                    text: Translation.tr("Entry pre-roll")
                    value: root.orbitOptions.presentation?.entryDelayMs ?? 64
                    from: 0
                    to: 240
                    stepSize: 8
                    onValueChanged: Config.setNestedValue("orbit.presentation.entryDelayMs", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    icon: "opacity"
                    text: Translation.tr("Entry start opacity")
                    value: root.orbitOptions.presentation?.entryOpacityPercent ?? 0
                    from: 0
                    to: 90
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("orbit.presentation.entryOpacityPercent", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    icon: "format_line_spacing"
                    text: Translation.tr("Card stagger")
                    value: root.orbitOptions.presentation?.entryStaggerMs ?? 42
                    from: 0
                    to: 120
                    stepSize: 4
                    onValueChanged: Config.setNestedValue("orbit.presentation.entryStaggerMs", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.presentation?.advanced ?? false
                    icon: "dock_to_bottom"
                    text: Translation.tr("Shelf entry delay")
                    value: root.orbitOptions.presentation?.shelfDelayMs ?? 72
                    from: 0
                    to: 240
                    stepSize: 8
                    onValueChanged: Config.setNestedValue("orbit.presentation.shelfDelayMs", value)
                }
            }

            ContentSubsection {
                title: Translation.tr("Workspace navigation")

                ConfigSelectionArray {
                    currentValue: root.orbitOptions.navigationMotion?.preset ?? "fluid"
                    onSelected: value => Config.setNestedValues({
                        "orbit.navigationMotion.preset": value,
                        "orbit.navigationMotion.advanced": false
                    })
                    options: [
                        { displayName: Translation.tr("Snappy"), icon: "speed", value: "snappy" },
                        { displayName: Translation.tr("Fluid"), icon: "waves", value: "fluid" },
                        { displayName: Translation.tr("Cinematic"), icon: "movie", value: "cinematic" },
                        { displayName: Translation.tr("Instant"), icon: "bolt", value: "instant" },
                        { displayName: Translation.tr("Custom"), icon: "tune", value: "custom" }
                    ]
                }

                ConfigSwitch {
                    text: Translation.tr("Advanced navigation")
                    description: Translation.tr("Tune scroll and workspace-switch motion")
                    checked: root.orbitOptions.navigationMotion?.advanced ?? false
                    onCheckedChanged: Config.setNestedValue("orbit.navigationMotion.advanced", checked)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    visible: root.orbitOptions.navigationMotion?.advanced ?? false
                    icon: "timer"
                    text: Translation.tr("Navigation duration")
                    value: root.orbitOptions.navigationMotion?.durationMs ?? 320
                    from: 80
                    to: 600
                    stepSize: 10
                    onValueChanged: Config.setNestedValue("orbit.navigationMotion.durationMs", value)
                }

                ConfigSelectionArray {
                    visible: root.orbitOptions.navigationMotion?.advanced ?? false
                    currentValue: root.orbitOptions.navigationMotion?.easing ?? "smooth"
                    onSelected: value => Config.setNestedValue("orbit.navigationMotion.easing", value)
                    options: [
                        { displayName: Translation.tr("Direct"), icon: "timeline", value: "direct" },
                        { displayName: Translation.tr("Smooth"), icon: "waves", value: "smooth" },
                        { displayName: Translation.tr("Linear"), icon: "trending_flat", value: "linear" }
                    ]
                }
            }

            ConfigSpinBox {
                Layout.fillWidth: true
                icon: "contrast"
                text: Translation.tr("Backdrop dim")
                value: root.orbitOptions.scrimDim ?? 35
                from: 0
                to: 80
                stepSize: 5
                onValueChanged: Config.setNestedValue("orbit.scrimDim", value)
            }

            ContentSubsection {
                title: Translation.tr("Backdrop blur")

                ConfigSelectionArray {
                    currentValue: {
                        const mode = String(root.orbitOptions.backdropBlurMode ?? "")
                        if (mode === "off") return "off"
                        return (root.orbitOptions.backdropBlurEnable ?? true) ? "shell" : "off"
                    }
                    onSelected: value => Config.setNestedValue("orbit.backdropBlurMode", value)
                    options: [
                        { displayName: Translation.tr("Off"), icon: "blur_off", value: "off" },
                        { displayName: Translation.tr("iNiR glass"), icon: "blur_on", value: "shell" }
                    ]
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.backdropBlurMode !== "off"
                    icon: "blur_on"
                    text: Translation.tr("Blur strength")
                    value: root.orbitOptions.backdropBlurStrength ?? 72
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("orbit.backdropBlurStrength", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.backdropBlurMode !== "off"
                    icon: "palette"
                    text: Translation.tr("Blur saturation")
                    value: root.orbitOptions.backdropBlurSaturation ?? 18
                    from: 0
                    to: 100
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("orbit.backdropBlurSaturation", value)
                }

                ConfigSpinBox {
                    Layout.fillWidth: true
                    enabled: root.orbitOptions.backdropBlurMode !== "off"
                    icon: "opacity"
                    text: Translation.tr("Glass tint")
                    value: root.orbitOptions.backdropBlurTint ?? 28
                    from: 0
                    to: 80
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("orbit.backdropBlurTint", value)
                }
            }

            ConfigSwitch {
                text: Translation.tr("Workspace numbers")
                checked: root.orbitOptions.showWorkspaceNumbers ?? true
                onCheckedChanged: Config.setNestedValue("orbit.showWorkspaceNumbers", checked)
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Colors, typography, rounding, shadows and reduced-motion policy always follow the active Material appearance.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }
    }
        }
    }
}
