import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    id: root
    settingsPageIndex: 2
    settingsPageName: Translation.tr("Bar")

    property bool isIiActive: Config.options?.panelFamily !== "waffle"
    property string activeSection: "appearance"
    property int _taskLoadingCount: 0

    function activateSettingsSearchSection(section: string): bool {
        const parts = String(section || "").toLowerCase().split(/[·›]/)
        const label = parts[parts.length - 1].trim()
        const sections = {
            "appearance & layout": "appearance",
            "sizing & surface": "appearance",
            "m3 bar": "m3",
            "islands options": "islands",
            "audio spectrum": "spectrum",
            "behavior & clock": "behavior",
            "modules": "modules",
            "bar module layout": "modules",
            "resources": "modules",
            "media": "modules",
            "workspaces": "modules",
            "system tray": "modules",
            "utility buttons": "modules",
            "notifications": "modules"
        }
        const target = sections[label] ?? ""
        if (!target)
            return false
        root.activeSection = target
        return true
    }

    component LazySection: Loader {
        id: sectionLoader
        property bool requested: false
        property bool resident: false
        property bool _countedLoading: false

        Layout.fillWidth: true
        asynchronous: true
        active: resident
        visible: requested && status !== Loader.Null
        enabled: requested && status === Loader.Ready && opacity > 0.99
        opacity: requested && status === Loader.Ready ? 1 : 0
        Layout.preferredHeight: requested && status === Loader.Ready && item ? item.implicitHeight : 0

        transform: Translate {
            y: sectionLoader.requested && sectionLoader.status === Loader.Ready ? 0 : 4
            Behavior on y {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }
            }
        }

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }

        function syncLoadingState(): void {
            const shouldCount = requested && status === Loader.Loading
            if (shouldCount === _countedLoading)
                return
            root._taskLoadingCount = Math.max(0, root._taskLoadingCount + (shouldCount ? 1 : -1))
            _countedLoading = shouldCount
        }

        onRequestedChanged: {
            if (requested) {
                unloadDelay.stop()
                resident = true
            } else if (status === Loader.Ready) {
                unloadDelay.restart()
            } else {
                unloadDelay.stop()
                resident = false
            }
            syncLoadingState()
        }
        onStatusChanged: syncLoadingState()
        Component.onCompleted: {
            if (requested)
                resident = true
            syncLoadingState()
        }
        Component.onDestruction: {
            if (_countedLoading)
                root._taskLoadingCount = Math.max(0, root._taskLoadingCount - 1)
        }

        Timer {
            id: unloadDelay
            interval: 600
            repeat: false
            onTriggered: parent.resident = false
        }
    }

    SettingsTaskNavigator {
        icon: "toolbar"
        title: Translation.tr("Bar")
        description: Translation.tr("Position and sizing, the bar surface styles, and the widgets and modules that live in the bar.")
        summary: Translation.tr("Shape · M3 · Islands · Spectrum · Behavior · Modules")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        options: [
            { displayName: Translation.tr("Shape & position"), icon: "style", value: "appearance" },
            { displayName: Translation.tr("M3 bar"), icon: "category", value: "m3",
              dimmed: (Config.options?.bar?.appearanceStyle ?? "classic") !== "m3" },
            { displayName: Translation.tr("Islands"), icon: "linear_scale", value: "islands",
              dimmed: (Config.options?.bar?.appearanceStyle ?? "classic") !== "islands" },
            { displayName: Translation.tr("Audio spectrum"), icon: "graphic_eq", value: "spectrum" },
            { displayName: Translation.tr("Behavior & clock"), icon: "visibility", value: "behavior" },
            { displayName: Translation.tr("Modules"), icon: "widgets", value: "modules" }
        ]
    }

    SettingsTaskLoadingState {
        loading: root._taskLoadingCount > 0
        text: Translation.tr("Loading section…")
    }
    property bool m3ControlsReady: false
    property bool spectrumControlsReady: false
    Component.onCompleted: Qt.callLater(() => {
        root.m3ControlsReady = true
        root.spectrumControlsReady = true
    })

    function setM3Value(path, value): void {
        if (root.m3ControlsReady)
            Config.setNestedValue(path, value)
    }

    function setM3Values(values): void {
        if (root.m3ControlsReady)
            Config.setNestedValues(values)
    }

    // Conflict detection helpers
    readonly property bool isCardStyle: Config.options?.bar?.cornerStyle === 3
    readonly property bool isHugStyle: Config.options?.bar?.cornerStyle === 0
    readonly property bool isFloatStyle: Config.options?.bar?.cornerStyle === 1
    readonly property bool isRectStyle: Config.options?.bar?.cornerStyle === 2
    readonly property bool isGlobalCards: Config.options?.dock?.cardStyle && Config.options?.sidebar?.cardStyle && isCardStyle
    readonly property bool hasVignette: Config.options?.bar?.vignette?.enabled ?? false
    readonly property bool isAutoHide: Config.options?.bar?.autoHide?.enable ?? false
    readonly property bool isBorderless: Config.options?.bar?.borderless ?? false
    readonly property bool showBackground: Config.options?.bar?.showBackground ?? true
    readonly property string barAppearance: Config.options?.bar?.appearanceStyle ?? "classic"
    readonly property bool spectrumEnabled: root.barAppearance === "pill"
        ? (Config.options?.bar?.pill?.musicViz ?? true)
        : (Config.options?.bar?.visualizer?.enable ?? false)
    readonly property color workspaceThemeIndicatorColor: Appearance.zzzEverywhere ? Appearance.zzz.accentSoft
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary : Appearance.colors.colPrimary
    readonly property color workspaceIndicatorPreviewColor: {
        const saved = Config.options?.bar?.workspaces?.indicatorColor ?? ""
        if (saved.length === 0)
            return root.workspaceThemeIndicatorColor
        const parsed = Qt.color(saved)
        return parsed.valid ? parsed : root.workspaceThemeIndicatorColor
    }

    ColorDialog {
        id: workspaceIndicatorColorDialog
        selectedColor: root.workspaceIndicatorPreviewColor
        onAccepted: Config.setNestedValue("bar.workspaces.indicatorColor", selectedColor.toString())
    }

    SettingsNativeDialogGuard {
        dialog: workspaceIndicatorColorDialog
        dialogKey: "bar-workspace-indicator-color"
    }

    function setSpectrumEnabled(enabled): void {
        if (!root.spectrumControlsReady)
            return
        Config.setNestedValue(root.barAppearance === "pill"
            ? "bar.pill.musicViz" : "bar.visualizer.enable", enabled)
    }

    function setSpectrumValue(path, value): void {
        if (root.spectrumControlsReady)
            Config.setNestedValue(path, value)
    }

    function resetSpectrumDefaults(): void {
        if (!root.spectrumControlsReady)
            return
        Config.setNestedValues({
            "bar.visualizer.enable": false,
            "bar.visualizer.multiMonitorMode": "primary",
            "bar.visualizer.type": "bars",
            "bar.visualizer.height": 0.6,
            "bar.visualizer.opacity": 0.35,
            "bar.visualizer.barsOrigin": "bottom",
            "bar.visualizer.density": 12,
            "bar.visualizer.gap": 2,
            "bar.visualizer.smoothing": 2,
            "bar.visualizer.waveMode": "fill",
            "bar.visualizer.lineWidth": 2,
            "bar.visualizer.edgeInset": 0,
            "bar.visualizer.edgeSoftness": 28,
            "bar.visualizer.frequencyProfile": "flat",
            "bar.visualizer.accentStrength": 70,
            "bar.visualizer.pillWingMode": "bounded",
            "bar.visualizer.pillWingLength": 180,
            "bar.visualizer.pillWingGap": 12,
            "bar.visualizer.pillScreenPadding": 24,
            "bar.visualizer.pillUnderlap": 28,
            "bar.visualizer.pillEdgeFade": 92,
            "bar.pill.musicViz": true,
        })
    }

    // Global style detection
    readonly property string currentGlobalStyle: Config.options?.appearance?.globalStyle ?? "material"
    readonly property bool isAurora: currentGlobalStyle === "aurora"
    readonly property bool isInir: currentGlobalStyle === "inir"
    readonly property bool isCards: currentGlobalStyle === "cards"
    readonly property bool isMaterial: currentGlobalStyle === "material"
    readonly property bool isAngel: currentGlobalStyle === "angel"

    // Corner style only shapes the classic bar surface; the other appearances draw
    // their own (islands capsules, scenic scrim, frame outline, pill).
    readonly property bool cornerStyleApplies: (Config.options?.bar?.appearanceStyle ?? "classic") === "classic"

    function detectM3LayoutPreset(): string {
        const left = JSON.stringify(Config.options?.bar?.m3?.layouts?.leftLayout ?? [])
        const middle = JSON.stringify(Config.options?.bar?.m3?.layouts?.middleLayout ?? [])
        const right = JSON.stringify(Config.options?.bar?.m3?.layouts?.rightLayout ?? [])
        if (left === JSON.stringify(["media", "workspaces"])
                && middle === JSON.stringify(["docktoPanel"])
                && right === JSON.stringify(["utilButtons", "systemIcons", "weatherBar", "clockWidget"]))
            return "compact"
        if (left === JSON.stringify(["media", "workspaces"])
                && middle === JSON.stringify(["visualizer", "docktoPanel", "visualizer"])
                && right === JSON.stringify(["utilButtons", "systemIcons", "weatherBar", "clockWidget"]))
            return "showcase"
        if (left === JSON.stringify(["leftSidebarButton", "workspaces", "activeWindow"])
                && middle === JSON.stringify(["docktoPanel"])
                && right === JSON.stringify(["resources", "networkSpeed", "updatesCount", "clockWidget", "powerButton"]))
            return "information"
        return "custom"
    }

    readonly property string m3LayoutPreset: {
        const stored = Config.options?.bar?.m3?.layoutMode ?? "auto"
        return ["compact", "showcase", "information", "custom"].includes(stored)
            ? stored : root.detectM3LayoutPreset()
    }

    function currentM3Layouts(): var {
        return {
            left: Array.from(Config.options?.bar?.m3?.layouts?.leftLayout ?? []),
            middle: Array.from(Config.options?.bar?.m3?.layouts?.middleLayout ?? []),
            right: Array.from(Config.options?.bar?.m3?.layouts?.rightLayout ?? [])
        }
    }

    function updateM3CustomLayout(side, list): void {
        if (!root.m3ControlsReady) return
        const next = Array.from(list ?? [])
        const activePath = "bar.m3.layouts." + side + "Layout"
        const customPath = "bar.m3.customLayouts." + side + "Layout"
        root.setM3Values({
            "bar.m3.layoutMode": "custom",
            "bar.m3.customLayoutSaved": true,
            [activePath]: next,
            [customPath]: next
        })
    }

    function applyM3LayoutPreset(value): void {
        if (!root.m3ControlsReady) return

        if (value === "custom") {
            const saved = Config.options?.bar?.m3?.customLayoutSaved ?? false
            if (saved) {
                root.setM3Values({
                    "bar.m3.layoutMode": "custom",
                    "bar.m3.layouts.leftLayout": Array.from(Config.options?.bar?.m3?.customLayouts?.leftLayout ?? []),
                    "bar.m3.layouts.middleLayout": Array.from(Config.options?.bar?.m3?.customLayouts?.middleLayout ?? []),
                    "bar.m3.layouts.rightLayout": Array.from(Config.options?.bar?.m3?.customLayouts?.rightLayout ?? [])
                })
            } else {
                const current = root.currentM3Layouts()
                root.setM3Values({
                    "bar.m3.layoutMode": "custom",
                    "bar.m3.customLayoutSaved": true,
                    "bar.m3.customLayouts.leftLayout": current.left,
                    "bar.m3.customLayouts.middleLayout": current.middle,
                    "bar.m3.customLayouts.rightLayout": current.right
                })
            }
            return
        }

        const updates = ({ "bar.m3.layoutMode": value })
        if (root.m3LayoutPreset === "custom" || root.detectM3LayoutPreset() === "custom") {
            const current = root.currentM3Layouts()
            updates["bar.m3.customLayoutSaved"] = true
            updates["bar.m3.customLayouts.leftLayout"] = current.left
            updates["bar.m3.customLayouts.middleLayout"] = current.middle
            updates["bar.m3.customLayouts.rightLayout"] = current.right
        }

        if (value === "compact") {
            updates["bar.m3.layouts.leftLayout"] = ["media", "workspaces"]
            updates["bar.m3.layouts.middleLayout"] = ["docktoPanel"]
            updates["bar.m3.layouts.rightLayout"] = ["utilButtons", "systemIcons", "weatherBar", "clockWidget"]
        } else if (value === "showcase") {
            updates["bar.m3.layouts.leftLayout"] = ["media", "workspaces"]
            updates["bar.m3.layouts.middleLayout"] = ["visualizer", "docktoPanel", "visualizer"]
            updates["bar.m3.layouts.rightLayout"] = ["utilButtons", "systemIcons", "weatherBar", "clockWidget"]
        } else if (value === "information") {
            updates["bar.m3.layouts.leftLayout"] = ["leftSidebarButton", "workspaces", "activeWindow"]
            updates["bar.m3.layouts.middleLayout"] = ["docktoPanel"]
            updates["bar.m3.layouts.rightLayout"] = ["resources", "networkSpeed", "updatesCount", "clockWidget", "powerButton"]
        }
        root.setM3Values(updates)
    }

    readonly property var m3Widgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button"), icon: "left_panel_open" },
        { id: "workspaces", name: Translation.tr("Workspaces"), icon: "steppers" },
        { id: "weatherBar", name: Translation.tr("Weather"), icon: "flare" },
        { id: "media", name: Translation.tr("Media"), icon: "music_note" },
        { id: "resources", name: Translation.tr("Resources"), icon: "monitoring" },
        { id: "systemIcons", name: Translation.tr("System Icons"), icon: "info" },
        { id: "networkSpeed", name: Translation.tr("Network Speed"), icon: "network_check" },
        { id: "clockWidget", name: Translation.tr("Clock"), icon: "schedule" },
        { id: "utilButtons", name: Translation.tr("Utility Buttons"), icon: "toggle_on" },
        { id: "sysTray", name: Translation.tr("Tray"), icon: "inbox" },
        { id: "batteryIndicator", name: Translation.tr("Battery"), icon: "battery_android_frame_full" },
        { id: "activeWindow", name: Translation.tr("Active Window"), icon: "subtitles" },
        { id: "powerButton", name: Translation.tr("Power Button"), icon: "power_settings_new" },
        { id: "updatesCount", name: Translation.tr("Updates"), icon: "deployed_code_update" },
        { id: "docktoPanel", name: Translation.tr("Dock to Panel"), icon: "apps" },
        { id: "visualizer", name: Translation.tr("Visualizer"), icon: "graphic_eq" },
        { id: "hyprlandXkbIndicator", name: Translation.tr("Keyboard Layout"), icon: "keyboard" },
        { id: "divisor", name: Translation.tr("Divider"), icon: "horizontal_distribute" },
        { id: "notificationUnreadCount", name: Translation.tr("Unread Notifications"), icon: "notifications" }
    ]

    function m3WidgetName(id): string {
        return root.m3Widgets.find(widget => widget.id === id)?.name ?? id
    }

    function m3WidgetHint(id): string {
        return Translation.tr("Add %1 to the Left, Center or Right layout below to enable these controls.")
            .arg(root.m3WidgetName(id))
    }

    readonly property var activeM3Widgets: [
        ...(Config.options?.bar?.m3?.layouts?.leftLayout ?? []),
        ...(Config.options?.bar?.m3?.layouts?.middleLayout ?? []),
        ...(Config.options?.bar?.m3?.layouts?.rightLayout ?? [])
    ]

    function m3HasWidget(id): bool {
        return root.activeM3Widgets.includes(id)
    }

    function availableM3Widgets(): var {
        const multipleAllowed = ["visualizer", "divisor"]
        return root.m3Widgets.filter(widget =>
            !root.activeM3Widgets.includes(widget.id) || multipleAllowed.includes(widget.id))
    }

    // Corner style compatibility per global style
    readonly property bool hugNeedsBackground: isHugStyle && !showBackground
    readonly property bool hugOnAurora: isHugStyle && isAurora
    readonly property bool cardOnNonCards: isCardStyle && !isCards

    SettingsCardSection {
        visible: !root.isIiActive
        expanded: true
        icon: "info"
        title: Translation.tr("Not Active")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("These settings only apply when using the Material (ii) panel style. Go to Modules → Panel Style to switch.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // APPEARANCE & LAYOUT
    // ═══════════════════════════════════════════════════════════════════
    SettingsCardSection {
        settingsTaskSection: "appearance"
        visible: root.isIiActive && root.activeSection === "appearance"
        expanded: true
        icon: "dashboard"
        title: Translation.tr("Appearance & Layout")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Bar appearance")

                ConfigSelectionArray {
                    currentValue: Config.options?.bar?.appearanceStyle ?? "classic"
                    onSelected: newValue => {
                        Config.setNestedValue("bar.appearanceStyle", newValue);
                    }
                    options: [
                        { displayName: Translation.tr("Classic"), icon: "toolbar", value: "classic" },
                        { displayName: Translation.tr("Islands"), icon: "linear_scale", value: "islands" },
                        { displayName: Translation.tr("Scenic"), icon: "gradient", value: "scenic" },
                        { displayName: Translation.tr("Frame"), icon: "crop_free", value: "frame" },
                        { displayName: Translation.tr("M3"), icon: "category", value: "m3" },
                        { displayName: Translation.tr("Pill"), icon: "blur_on", value: "pill" }
                    ]
                }

                SettingsNote {
                    icon: "toolbar"
                    text: Translation.tr("Decides the bar surface style. Islands works in horizontal and vertical bars; the rest are horizontal only.")
                }

                RippleButton {
                    visible: (Config.options?.bar?.appearanceStyle ?? "classic") === "pill"
                    Layout.fillWidth: true
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer1
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: GlobalStates.openSettingsPage(21)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        MaterialSymbol {
                            text: "tune"
                            iconSize: 18
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Open Ricelin Pill settings")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                        }
                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            ConfigRow {
                uniform: true

                ContentSubsection {
                    title: Translation.tr("Position")

                    ConfigSelectionArray {
                        currentValue: ((Config.options?.bar?.bottom ?? false) ? 1 : 0) | ((Config.options?.bar?.vertical ?? false) ? 2 : 0)
                        onSelected: newValue => {
                            Config.setNestedValue("bar.bottom", (newValue & 1) !== 0);
                            Config.setNestedValue("bar.vertical", (newValue & 2) !== 0);
                        }
                        options: [
                            { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                            { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                            { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                            { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Corner style")

                    ConfigSelectionArray {
                        enabled: root.cornerStyleApplies
                        opacity: enabled ? 1 : 0.5
                        currentValue: Config.options?.bar?.cornerStyle ?? 0
                        onSelected: newValue => {
                            // HUG mode (0) is incompatible with Angel style — revert to Float
                            if (newValue === 0 && root.isAngel) {
                                Config.setNestedValue("bar.cornerStyle", 1);
                                return;
                            }
                            Config.setNestedValue("bar.cornerStyle", newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Hug"), icon: "line_curve", previewKind: "hug", value: 0 },
                            { displayName: Translation.tr("Float"), icon: "page_header", previewKind: "float", value: 1 },
                            { displayName: Translation.tr("Rect"), icon: "toolbar", previewKind: "rect", value: 2 },
                            { displayName: Translation.tr("Card"), icon: "branding_watermark", previewKind: "card", value: 3 }
                        ]
                    }

                    SettingsNote {
                        visible: !root.cornerStyleApplies
                        icon: "info"
                        text: Translation.tr("Only the Classic bar appearance uses corner style.")
                    }
                }
            }
        }
    }

    LazySection {
        requested: root.isIiActive && root.activeSection === "m3"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "m3"
                expanded: true
        icon: "category"
        title: Translation.tr("M3 Bar")

        SettingsGroup {

            SettingsNote {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") !== "m3"
                icon: "info"
                text: Translation.tr("These options configure the M3 bar and take effect when M3 is the active bar appearance.")
            }

            RippleButton {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") !== "m3"
                Layout.fillWidth: true
                implicitHeight: 40
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: Config.setNestedValue("bar.appearanceStyle", "m3")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    MaterialSymbol {
                        text: "category"
                        iconSize: 18
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Switch the bar to M3 appearance")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                }
            }

            ContentSubsection {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") === "m3"
                title: Translation.tr("M3 options")

                ContentSubsection {
                    title: Translation.tr("Layout and grouping")

                    ConfigSelectionArray {
                        currentValue: root.m3LayoutPreset
                        onSelected: newValue => root.applyM3LayoutPreset(newValue)
                    options: [
                        { displayName: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                        { displayName: Translation.tr("Showcase"), icon: "graphic_eq", value: "showcase" },
                        { displayName: Translation.tr("Information"), icon: "monitoring", value: "information" },
                        { displayName: Translation.tr("Custom layout"), icon: "tune", value: "custom" }
                    ]
                }

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.m3?.borderless ?? "separated"
                        onSelected: newValue => root.setM3Value("bar.m3.borderless", newValue)
                        options: [
                            { displayName: Translation.tr("Joined pills"), icon: "join", value: "pills" },
                            { displayName: Translation.tr("Separate pills"), icon: "space_bar", value: "separated" },
                            { displayName: Translation.tr("Transparent"), icon: "opacity", value: "transparent" }
                        ]
                    }

                    SettingsNote {
                        icon: "palette"
                        text: Translation.tr("Joined keeps one island per section with semantic accents. Separate gives each widget its own tonal capsule. Transparent removes every surface and uses on-surface content colors.")
                    }
                }

                M3LayoutSection {
                    sectionTitle: Translation.tr("Left")
                    layout: Config.options?.bar?.m3?.layouts?.leftLayout ?? []
                    availableWidgets: root.availableM3Widgets()
                    getWidgetName: root.m3WidgetName
                    onUpdate: list => root.updateM3CustomLayout("left", list)
                }

                M3LayoutSection {
                    sectionTitle: Translation.tr("Center")
                    layout: Config.options?.bar?.m3?.layouts?.middleLayout ?? []
                    availableWidgets: root.availableM3Widgets()
                    getWidgetName: root.m3WidgetName
                    onUpdate: list => root.updateM3CustomLayout("middle", list)
                }

                M3LayoutSection {
                    sectionTitle: Translation.tr("Right")
                    layout: Config.options?.bar?.m3?.layouts?.rightLayout ?? []
                    availableWidgets: root.availableM3Widgets()
                    getWidgetName: root.m3WidgetName
                    onUpdate: list => root.updateM3CustomLayout("right", list)
                }

                SettingsNote {
                    visible: root.m3LayoutPreset === "custom"
                    icon: "info"
                    text: Translation.tr("Custom layout active. Presets only replace the live bar; your last custom Left, Center and Right arrangement is saved and restored when you return to Custom layout.")
                }

                ContentSubsection {
                    title: Translation.tr("Visible content and behavior")

                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        buttonIcon: "branding_watermark"
                        text: Translation.tr("Show background")
                        checked: Config.options?.bar?.m3?.showBackground ?? true
                        onCheckedChanged: root.setM3Value("bar.m3.showBackground", checked)
                    }
                    SettingsSwitch {
                        enabled: root.m3HasWidget("weatherBar") || root.m3HasWidget("clockWidget")
                            || root.m3HasWidget("resources") || root.m3HasWidget("networkSpeed")
                            || root.m3HasWidget("batteryIndicator")
                        opacity: enabled ? 1 : 0.45
                        buttonIcon: "tooltip"
                        text: Translation.tr("Open details on click")
                        checked: Config.options?.bar?.m3?.tooltips?.clickToShow ?? false
                        onCheckedChanged: root.setM3Value("bar.m3.tooltips.clickToShow", checked)
                    }
                }

                SettingsNote {
                    visible: !(root.m3HasWidget("weatherBar") || root.m3HasWidget("clockWidget")
                        || root.m3HasWidget("resources") || root.m3HasWidget("networkSpeed")
                        || root.m3HasWidget("batteryIndicator"))
                    icon: "info"
                    text: Translation.tr("Open details on click needs a widget with a details popup in the layout: Weather, Clock, Resources, Network Speed or Battery.")
                }

                ConfigRow {
                    uniform: true
                    SettingsSwitch {
                        enabled: root.m3HasWidget("systemIcons") || root.m3HasWidget("notificationUnreadCount")
                        opacity: enabled ? 1 : 0.45
                        buttonIcon: "notifications"
                        text: Translation.tr("Unread count")
                        checked: Config.options?.bar?.m3?.indicators?.notifications?.showUnreadCount ?? false
                        onCheckedChanged: root.setM3Value("bar.m3.indicators.notifications.showUnreadCount", checked)
                    }
                    SettingsSwitch {
                        enabled: root.m3HasWidget("clockWidget") || root.m3HasWidget("systemIcons")
                            || root.m3HasWidget("media")
                        opacity: enabled ? 1 : 0.45
                        buttonIcon: "notes"
                        text: Translation.tr("Verbose labels")
                        checked: Config.options?.bar?.m3?.verbose ?? true
                        onCheckedChanged: root.setM3Value("bar.m3.verbose", checked)
                    }
                }

                SettingsNote {
                    visible: !(root.m3HasWidget("systemIcons") || root.m3HasWidget("notificationUnreadCount"))
                    icon: "info"
                    text: Translation.tr("Unread count needs System Icons or Unread Notifications in the layout.")
                }

                SettingsNote {
                    visible: !(root.m3HasWidget("clockWidget") || root.m3HasWidget("systemIcons")
                        || root.m3HasWidget("media"))
                    icon: "info"
                    text: Translation.tr("Verbose labels needs Clock, System Icons or Media in the layout.")
                }

                }

                ContentSubsection {
                    visible: root.m3HasWidget("clockWidget")
                    title: Translation.tr("Clock")

                    ConfigRow {
                        uniform: true

                        FontSelector {
                            id: m3TimeFontSelector
                            label: Translation.tr("Time font")
                            icon: "schedule"
                            selectedFont: Config.options?.bar?.m3?.clock?.timeFontFamily ?? ""
                            onSelectedFontChanged: {
                                root.setM3Value("bar.m3.clock.timeFontFamily", selectedFont)
                            }
                            Connections {
                                target: Config.options?.bar?.m3?.clock ?? null
                                function onTimeFontFamilyChanged() {
                                    m3TimeFontSelector.selectedFont = Config.options.bar.m3.clock.timeFontFamily
                                }
                            }
                        }

                        ConfigSpinBox {
                            icon: "format_size"
                            text: Translation.tr("Time size (px)")
                            description: Translation.tr("0 = inherit global size")
                            value: Config.options?.bar?.m3?.clock?.timePixelSize ?? 0
                            from: 0
                            to: 64
                            stepSize: 1
                            onValueChanged: root.setM3Value("bar.m3.clock.timePixelSize", value)
                            StyledToolTip {
                                text: Translation.tr("Pixel size of the time digits in the M3 bar clock. 0 inherits the global typography scale.")
                            }
                        }
                    }

                    ConfigRow {
                        uniform: true

                        FontSelector {
                            id: m3DateFontSelector
                            label: Translation.tr("Date font")
                            icon: "font_download"
                            selectedFont: Config.options?.bar?.m3?.clock?.dateFontFamily ?? ""
                            onSelectedFontChanged: {
                                root.setM3Value("bar.m3.clock.dateFontFamily", selectedFont)
                            }
                            Connections {
                                target: Config.options?.bar?.m3?.clock ?? null
                                function onDateFontFamilyChanged() {
                                    m3DateFontSelector.selectedFont = Config.options.bar.m3.clock.dateFontFamily
                                }
                            }
                        }

                        ConfigSpinBox {
                            icon: "format_size"
                            text: Translation.tr("Date size (px)")
                            description: Translation.tr("0 = inherit global size")
                            value: Config.options?.bar?.m3?.clock?.datePixelSize ?? 0
                            from: 0
                            to: 64
                            stepSize: 1
                            onValueChanged: root.setM3Value("bar.m3.clock.datePixelSize", value)
                            StyledToolTip {
                                text: Translation.tr("Pixel size of the date string in the M3 bar clock. 0 inherits the global typography scale.")
                            }
                        }
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        enabled: (Config.options?.bar?.m3?.clock?.timeFontFamily ?? "").length > 0
                            || (Config.options?.bar?.m3?.clock?.timePixelSize ?? 0) > 0
                            || (Config.options?.bar?.m3?.clock?.dateFontFamily ?? "").length > 0
                            || (Config.options?.bar?.m3?.clock?.datePixelSize ?? 0) > 0
                        opacity: enabled ? 1 : 0.5
                        onClicked: root.setM3Values({
                            "bar.m3.clock.timeFontFamily": "",
                            "bar.m3.clock.timePixelSize": 0,
                            "bar.m3.clock.dateFontFamily": "",
                            "bar.m3.clock.datePixelSize": 0
                        })

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            MaterialSymbol {
                                text: "restart_alt"
                                iconSize: 15
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                text: Translation.tr("Reset to default")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }

                    SettingsNote {
                        icon: "info"
                        text: Translation.tr("Override the font and pixel size of the time and date in the M3 bar clock. Leave at 0 / pick the same family as your main font to keep the default look.")
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Surface")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.m3?.cornerStyle ?? 3
                        onSelected: newValue => root.setM3Value("bar.m3.cornerStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                            { displayName: Translation.tr("Float"), icon: "page_header", value: 1 },
                            { displayName: Translation.tr("Rectangle"), icon: "toolbar", value: 2 },
                            { displayName: Translation.tr("Material islands"), icon: "category", value: 3 }
                        ]
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "space_dashboard"
                            text: Translation.tr("Outer gap (px)")
                            value: Config.options?.bar?.m3?.gapsOut ?? 5
                            from: 0
                            to: 24
                            stepSize: 1
                            enabled: (Config.options?.bar?.m3?.cornerStyle ?? 3) === 3
                                || (Config.options?.bar?.m3?.cornerStyle ?? 3) === 1
                            opacity: enabled ? 1 : 0.5
                            onValueChanged: root.setM3Value("bar.m3.gapsOut", value)
                        }
                    }

                    SettingsNote {
                        visible: !((Config.options?.bar?.m3?.cornerStyle ?? 3) === 3
                            || (Config.options?.bar?.m3?.cornerStyle ?? 3) === 1)
                        icon: "info"
                        text: Translation.tr("Outer gap only applies to the Float and Material islands surfaces — the others sit flush against the screen edge.")
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("divisor")
                    title: Translation.tr("Divider")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.m3?.divider?.style ?? "rect"
                        onSelected: newValue => root.setM3Value("bar.m3.divider.style", newValue)
                        options: [
                            { displayName: Translation.tr("Line"), icon: "remove", value: "rect" },
                            { displayName: Translation.tr("Dot"), icon: "fiber_manual_record", value: "dot" },
                            { displayName: Translation.tr("Space"), icon: "space_bar", value: "space" }
                        ]
                    }

                    ConfigSpinBox {
                        icon: "width"
                        text: Translation.tr("Space width (px)")
                        value: Config.options?.bar?.m3?.divider?.spacing ?? 20
                        from: 4
                        to: 100
                        stepSize: 2
                        enabled: (Config.options?.bar?.m3?.divider?.style ?? "rect") === "space"
                        opacity: enabled ? 1 : 0.45
                        onValueChanged: root.setM3Value("bar.m3.divider.spacing", value)
                    }

                }

                ContentSubsection {
                    visible: root.m3HasWidget("media")
                    title: Translation.tr("Media")

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "keep"
                            text: Translation.tr("Keep media visible")
                            checked: Config.options?.bar?.m3?.media?.alwaysVisible ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.media.alwaysVisible", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "title"
                            text: Translation.tr("Media title only")
                            checked: Config.options?.bar?.m3?.media?.onlyTitle ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.media.onlyTitle", checked)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Preferred player — blank for any")
                            text: Config.options?.bar?.m3?.media?.preferredPlayer ?? ""
                            onTextChanged: root.setM3Value("bar.m3.media.preferredPlayer", text)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "width_normal"
                            text: Translation.tr("Minimum width (px)")
                            value: Config.options?.bar?.m3?.media?.minWidth ?? 100
                            from: 60
                            to: 360
                            stepSize: 10
                            onValueChanged: {
                                if (!root.m3ControlsReady) return
                                const maximum = Config.options?.bar?.m3?.media?.maxWidth ?? 280
                                root.setM3Value("bar.m3.media.minWidth", Math.min(value, maximum))
                            }
                        }
                        ConfigSpinBox {
                            icon: "width_full"
                            text: Translation.tr("Maximum width (px)")
                            value: Config.options?.bar?.m3?.media?.maxWidth ?? 280
                            from: 100
                            to: 640
                            stepSize: 10
                            onValueChanged: {
                                if (!root.m3ControlsReady) return
                                const minimum = Config.options?.bar?.m3?.media?.minWidth ?? 100
                                root.setM3Value("bar.m3.media.maxWidth", Math.max(value, minimum))
                            }
                        }
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("resources")
                    title: Translation.tr("Resources")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.m3?.resources?.style ?? "filled"
                        onSelected: newValue => root.setM3Value("bar.m3.resources.style", newValue)
                        options: [
                            { displayName: Translation.tr("Filled rings"), icon: "donut_large", value: "filled" },
                            { displayName: Translation.tr("Outline rings"), icon: "radio_button_unchecked", value: "outline" }
                        ]
                    }

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "percent"
                            text: Translation.tr("Show values")
                            checked: Config.options?.bar?.m3?.resources?.showValue ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.resources.showValue", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "memory"
                            text: Translation.tr("RAM")
                            checked: Config.options?.bar?.m3?.resources?.alwaysShowRam ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.resources.alwaysShowRam", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "developer_board"
                            text: Translation.tr("CPU")
                            checked: Config.options?.bar?.m3?.resources?.alwaysShowCpu ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.resources.alwaysShowCpu", checked)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "thermostat"
                            text: Translation.tr("CPU temperature")
                            checked: Config.options?.bar?.m3?.resources?.alwaysShowCpuTemp ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.resources.alwaysShowCpuTemp", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "hard_drive"
                            text: Translation.tr("Disk usage")
                            checked: Config.options?.bar?.m3?.resources?.alwaysShowDisk ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.resources.alwaysShowDisk", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "swap_horiz"
                            text: Translation.tr("Swap usage")
                            checked: Config.options?.bar?.m3?.resources?.alwaysShowSwap ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.resources.alwaysShowSwap", checked)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "memory"
                            text: Translation.tr("RAM warning (%)")
                            value: Config.options?.bar?.m3?.resources?.memoryWarningThreshold ?? 95
                            from: 50
                            to: 100
                            stepSize: 5
                            onValueChanged: root.setM3Value("bar.m3.resources.memoryWarningThreshold", value)
                        }
                        ConfigSpinBox {
                            icon: "developer_board"
                            text: Translation.tr("CPU warning (%)")
                            value: Config.options?.bar?.m3?.resources?.cpuWarningThreshold ?? 90
                            from: 50
                            to: 100
                            stepSize: 5
                            onValueChanged: root.setM3Value("bar.m3.resources.cpuWarningThreshold", value)
                        }
                        ConfigSpinBox {
                            icon: "swap_horiz"
                            text: Translation.tr("Swap warning (%)")
                            value: Config.options?.bar?.m3?.resources?.swapWarningThreshold ?? 85
                            from: 50
                            to: 100
                            stepSize: 5
                            enabled: Config.options?.bar?.m3?.resources?.alwaysShowSwap ?? false
                            opacity: enabled ? 1 : 0.5
                            onValueChanged: root.setM3Value("bar.m3.resources.swapWarningThreshold", value)
                        }
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("workspaces")
                    title: Translation.tr("Workspaces")

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "apps"
                            text: Translation.tr("Show app icons")
                            checked: Config.options?.bar?.m3?.workspaces?.showAppIcons ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.workspaces.showAppIcons", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "filter_1"
                            text: Translation.tr("Always show numbers")
                            checked: Config.options?.bar?.m3?.workspaces?.alwaysShowNumbers ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.workspaces.alwaysShowNumbers", checked)
                        }
                    }

                    SettingsSwitch {
                        Layout.fillWidth: true
                        enabled: Config.options?.bar?.m3?.workspaces?.showAppIcons ?? true
                        opacity: enabled ? 1 : 0.45
                        buttonIcon: "monochrome_photos"
                        text: Translation.tr("Monochrome icons")
                        checked: Config.options?.bar?.m3?.workspaces?.monochromeIcons ?? true
                        onCheckedChanged: root.setM3Value("bar.m3.workspaces.monochromeIcons", checked)
                    }

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.m3?.workspaces?.indicatorStyle ?? "dot"
                        onSelected: newValue => root.setM3Value("bar.m3.workspaces.indicatorStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Dot indicator"), icon: "fiber_manual_record", value: "dot" },
                            { displayName: Translation.tr("App icon indicator"), icon: "apps", value: "icon" }
                        ]
                    }

                    SettingsSwitch {
                        buttonIcon: "font_download"
                        text: Translation.tr("Use Nerd Font workspace labels")
                        checked: Config.options?.bar?.m3?.workspaces?.useNerdFont ?? false
                        onCheckedChanged: root.setM3Value("bar.m3.workspaces.useNerdFont", checked)
                    }

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Workspace labels, comma separated")
                        text: (Config.options?.bar?.m3?.workspaces?.numberMap ?? ["1", "2"]).join(", ")
                        onEditingFinished: {
                            const labels = text.split(",").map(value => value.trim()).filter(value => value.length > 0)
                            if (labels.length > 0)
                                root.setM3Value("bar.m3.workspaces.numberMap", labels)
                        }
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("sysTray")
                    title: Translation.tr("System tray")

                    SettingsSwitch {
                        Layout.fillWidth: true
                        buttonIcon: "colors"
                        text: Translation.tr("Match M3 colors")
                        checked: Config.options?.bar?.m3?.tray?.monochromeIcons ?? true
                        onCheckedChanged: root.setM3Value("bar.m3.tray.monochromeIcons", checked)
                        StyledToolTip {
                            text: Translation.tr("Use the tray's semantic M3 foreground color instead of each app's original icon colors")
                        }
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("utilButtons")
                    title: Translation.tr("Utility buttons")

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "screenshot_region"
                            text: Translation.tr("Screen snip")
                            checked: Config.options?.bar?.m3?.utilButtons?.showScreenSnip ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showScreenSnip", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "colorize"
                            text: Translation.tr("Color picker")
                            checked: Config.options?.bar?.m3?.utilButtons?.showColorPicker ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showColorPicker", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "screen_record"
                            text: Translation.tr("Screen recording")
                            checked: Config.options?.bar?.m3?.utilButtons?.showScreenRecord ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showScreenRecord", checked)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "mic"
                            text: Translation.tr("Microphone")
                            checked: Config.options?.bar?.m3?.utilButtons?.showMicToggle ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showMicToggle", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "keyboard"
                            text: Translation.tr("Keyboard layout")
                            checked: Config.options?.bar?.m3?.utilButtons?.showKeyboardToggle ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showKeyboardToggle", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "wallpaper"
                            text: Translation.tr("Wallpaper")
                            checked: Config.options?.bar?.m3?.utilButtons?.showWallpaperToggle ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showWallpaperToggle", checked)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "dark_mode"
                            text: Translation.tr("Dark mode")
                            checked: Config.options?.bar?.m3?.utilButtons?.showDarkModeToggle ?? true
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showDarkModeToggle", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "speed"
                            text: Translation.tr("Performance profile")
                            checked: Config.options?.bar?.m3?.utilButtons?.showPerformanceProfileToggle ?? false
                            onCheckedChanged: root.setM3Value("bar.m3.utilButtons.showPerformanceProfileToggle", checked)
                        }
                    }
                }

                ContentSubsection {
                    visible: root.m3HasWidget("docktoPanel")
                    title: Translation.tr("Dock in bar")

                    SettingsNote {
                        icon: "info"
                        text: Translation.tr("Set icon or button size to zero to follow the current bar height automatically.")
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "apps"
                            text: Translation.tr("Icon size (px)")
                            value: Config.options?.bar?.m3?.dockToPanel?.iconSize ?? 0
                            from: 0
                            to: 48
                            stepSize: 1
                            onValueChanged: root.setM3Value("bar.m3.dockToPanel.iconSize", value)
                        }
                        ConfigSpinBox {
                            icon: "crop_square"
                            text: Translation.tr("Button size (px)")
                            value: Config.options?.bar?.m3?.dockToPanel?.buttonSize ?? 0
                            from: 0
                            to: 56
                            stepSize: 1
                            onValueChanged: root.setM3Value("bar.m3.dockToPanel.buttonSize", value)
                        }
                        ConfigSpinBox {
                            icon: "space_bar"
                            text: Translation.tr("Button spacing (px)")
                            value: Config.options?.bar?.m3?.dockToPanel?.buttonSpacing ?? 2
                            from: 0
                            to: 16
                            stepSize: 1
                            onValueChanged: root.setM3Value("bar.m3.dockToPanel.buttonSpacing", value)
                        }
                    }
                }
            }
        }
            }
        }
    }

    LazySection {
        requested: root.isIiActive && root.activeSection === "islands"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "islands"
                expanded: true
        icon: "linear_scale"
        title: Translation.tr("Islands options")

        SettingsGroup {

            SettingsNote {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") !== "islands"
                icon: "info"
                text: Translation.tr("Islands is not the active bar appearance. Switch to it to see these geometry changes live.")
            }

            RippleButton {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") !== "islands"
                Layout.fillWidth: true
                implicitHeight: 40
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer1
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: Config.setNestedValue("bar.appearanceStyle", "islands")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    MaterialSymbol {
                        text: "linear_scale"
                        iconSize: 18
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Switch the bar to Islands appearance")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                }
            }

            ContentSubsection {
                visible: (Config.options?.bar?.appearanceStyle ?? "classic") === "islands"
                title: Translation.tr("Islands options")

                ConfigRow {
                    uniform: true
                    ConfigSpinBox {
                        icon: "height"
                        text: Translation.tr("Inset (px)")
                        value: Config.options?.bar?.islands?.inset ?? 4
                        from: 0
                        to: 10
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("bar.islands.inset", value)
                        StyledToolTip {
                            text: Translation.tr("Vertical breathing room around each island. Smaller = taller capsules.")
                        }
                    }
                    ConfigSpinBox {
                        icon: "width"
                        text: Translation.tr("Capsule padding (px)")
                        value: Config.options?.bar?.islands?.padding ?? 12
                        from: 4
                        to: 24
                        stepSize: 2
                        onValueChanged: Config.setNestedValue("bar.islands.padding", value)
                        StyledToolTip {
                            text: Translation.tr("Horizontal air between an edge island's border and its content.")
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Island body opacity, glass, blur, radius, shadow and top edge are shared with every Ricelin surface: Settings › Ricelin › Island surfaces.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }
        }
            }
        }
    }

    SettingsCardSection {
        settingsTaskSection: "appearance"
        visible: root.isIiActive && root.activeSection === "appearance"
        expanded: true
        icon: "straighten"
        title: Translation.tr("Sizing & surface")

        SettingsGroup {

            // Corner style conflict notes
            SettingsNote {
                visible: root.hugNeedsBackground
                warning: true
                icon: "warning"
                text: Translation.tr("Hug style requires background enabled to show the corner decorations.")
            }

            SettingsNote {
                visible: root.isAngel && root.isHugStyle
                warning: true
                icon: "sync_problem"
                text: Translation.tr("Hug mode is not compatible with Angel global style. Switch to Float, Rect, or Card.")
            }

            SettingsNote {
                visible: root.isAngel
                warning: false
                icon: "raven"
                text: Translation.tr("Hug mode is disabled while Angel global style is active.")
            }

            SettingsNote {
                visible: root.isCardStyle && !root.isGlobalCards
                warning: true
                icon: "sync_problem"
                text: Translation.tr("Card style here doesn't match dock/sidebar. Go to Themes → Global Style for consistency.")
            }

            ConfigSpinBox {
                visible: root.barAppearance !== "islands"
                icon: "rounded_corner"
                text: Translation.tr("Custom bar rounding (px)")
                value: Config.options?.bar?.customRounding ?? -1
                from: -1
                to: 50
                stepSize: 1
                onValueChanged: {
                    Config.setNestedValue("bar.customRounding", value);
                }
                StyledToolTip {
                    text: Translation.tr("Override bar corner rounding independently from the global theme.\n-1 = use theme default, 0 = sharp corners, higher = rounder")
                }
            }

            SettingsDivider {}

            // ── Geometry: how big and how solid the bar should look ──
            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Bar height (px)")
                    value: Config.options?.bar?.height ?? 40
                    from: 24
                    to: 80
                    stepSize: 2
                    onValueChanged: Config.setNestedValue("bar.height", value)
                    StyledToolTip {
                        text: Translation.tr("Content height of the bar before font scaling. Default is 40.")
                    }
                }
                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Bar opacity (%)")
                    value: Math.round((Config.options?.bar?.opacity ?? 1) * 100)
                    from: 20
                    to: 100
                    stepSize: 5
                    onValueChanged: Config.setNestedValue("bar.opacity", value / 100)
                    enabled: Config.options?.bar?.showBackground ?? true
                    opacity: enabled ? 1 : 0.5
                    StyledToolTip {
                        text: Translation.tr("Background fill opacity. Widgets stay fully opaque.")
                    }
                }
            }

            SettingsNote {
                visible: !(Config.options?.bar?.showBackground ?? true)
                icon: "info"
                text: Translation.tr("Opacity has no effect while ‘Show background’ is off.")
            }

        }
    }

    LazySection {
        requested: root.isIiActive && root.activeSection === "spectrum"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "spectrum"
                expanded: false
        icon: "graphic_eq"
        title: Translation.tr("Audio spectrum")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Audio spectrum")

                ConfigSwitch {
                    buttonIcon: "graphic_eq"
                    text: Translation.tr("Show spectrum in the bar")
                    checked: root.spectrumEnabled
                    onCheckedChanged: root.setSpectrumEnabled(checked)
                    StyledToolTip {
                        text: root.barAppearance === "pill"
                            ? Translation.tr("Draws balanced spectrum wings outside the pill while audio plays.")
                            : Translation.tr("Paints the audio spectrum into the bar surface. Only runs while something is playing.")
                    }
                }

                ConfigSelectionArray {
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5
                    currentValue: Config.options?.bar?.visualizer?.multiMonitorMode ?? "primary"
                    onSelected: newValue => root.setSpectrumValue(
                        "bar.visualizer.multiMonitorMode", newValue)
                    options: [
                        { displayName: Translation.tr("Primary only"), icon: "filter_1", value: "primary" },
                        { displayName: Translation.tr("All monitors"), icon: "select_all", value: "all" },
                    ]
                }

                ConfigSelectionArray {
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5
                    currentValue: Config.options?.bar?.visualizer?.type ?? "bars"
                    onSelected: newValue => root.setSpectrumValue("bar.visualizer.type", newValue)
                    options: [
                        { displayName: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                        { displayName: Translation.tr("Wave"), icon: "waves", value: "wave" },
                    ]
                }

                ConfigSelectionArray {
                    visible: (Config.options?.bar?.visualizer?.type ?? "bars") === "bars"
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5
                    currentValue: Config.options?.bar?.visualizer?.barsOrigin ?? "bottom"
                    onSelected: newValue => root.setSpectrumValue("bar.visualizer.barsOrigin", newValue)
                    options: [
                        { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                        { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                        { displayName: Translation.tr("Center rise"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Mirrored"), icon: "unfold_more", value: "mirror" },
                    ]
                }

                ConfigSelectionArray {
                    visible: (Config.options?.bar?.visualizer?.type ?? "bars") === "wave"
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5
                    currentValue: Config.options?.bar?.visualizer?.waveMode ?? "fill"
                    onSelected: newValue => root.setSpectrumValue("bar.visualizer.waveMode", newValue)
                    options: [
                        { displayName: Translation.tr("Fill"), icon: "waves", value: "fill" },
                        { displayName: Translation.tr("Line"), icon: "line_weight", value: "line" },
                        { displayName: Translation.tr("Ribbon"), icon: "unfold_more", value: "ribbon" },
                    ]
                }

                ConfigSelectionArray {
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5
                    currentValue: Config.options?.bar?.visualizer?.frequencyProfile ?? "flat"
                    onSelected: newValue => root.setSpectrumValue("bar.visualizer.frequencyProfile", newValue)
                    options: [
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                        { displayName: Translation.tr("Bass"), icon: "graphic_eq", value: "bass" },
                        { displayName: Translation.tr("Warm"), icon: "local_fire_department", value: "warm" },
                        { displayName: Translation.tr("Vocal"), icon: "record_voice_over", value: "vocal" },
                        { displayName: Translation.tr("Treble"), icon: "trending_up", value: "treble" },
                        { displayName: Translation.tr("Smile"), icon: "waves", value: "smile" },
                    ]
                    StyledToolTip {
                        text: Translation.tr("Shapes the frequency balance after Cava. Sensitivity, sample count and framerate come from Advanced → Cava; the internal bar stays mono so it always fills the whole surface.")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    enabled: root.spectrumEnabled
                    opacity: enabled ? 1 : 0.5

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "view_column"
                            text: Translation.tr("Band density (px)")
                            value: Config.options?.bar?.visualizer?.density ?? 12
                            from: 4
                            to: 32
                            stepSize: 1
                            onValueChanged: root.setSpectrumValue("bar.visualizer.density", value)
                        }
                        ConfigSpinBox {
                            icon: "space_bar"
                            text: Translation.tr("Band gap (px)")
                            value: Config.options?.bar?.visualizer?.gap ?? 2
                            from: 0
                            to: 12
                            stepSize: 1
                            onValueChanged: root.setSpectrumValue("bar.visualizer.gap", value)
                        }
                        ConfigSpinBox {
                            icon: "blur_on"
                            text: Translation.tr("Smoothing")
                            value: Config.options?.bar?.visualizer?.smoothing ?? 2
                            from: 0
                            to: 8
                            stepSize: 1
                            onValueChanged: root.setSpectrumValue("bar.visualizer.smoothing", value)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "height"
                            text: Translation.tr("Spectrum height (%)")
                            value: Math.round((Config.options?.bar?.visualizer?.height ?? 0.6) * 100)
                            from: 10
                            to: 100
                            stepSize: 5
                            onValueChanged: root.setSpectrumValue("bar.visualizer.height", value / 100)
                        }
                        ConfigSpinBox {
                            icon: "opacity"
                            text: Translation.tr("Spectrum opacity (%)")
                            value: Math.round((Config.options?.bar?.visualizer?.opacity ?? 0.35) * 100)
                            from: 5
                            to: 100
                            stepSize: 5
                            onValueChanged: root.setSpectrumValue("bar.visualizer.opacity", value / 100)
                        }
                    }

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "line_weight"
                            text: Translation.tr("Wave edge (px)")
                            value: Config.options?.bar?.visualizer?.lineWidth ?? 2
                            from: 1
                            to: 8
                            stepSize: 1
                            enabled: (Config.options?.bar?.visualizer?.type ?? "bars") === "wave"
                            opacity: enabled ? 1 : 0.45
                            onValueChanged: root.setSpectrumValue("bar.visualizer.lineWidth", value)
                        }
                        ConfigSpinBox {
                            icon: "width_full"
                            text: Translation.tr("Edge inset (px)")
                            value: Config.options?.bar?.visualizer?.edgeInset ?? 0
                            from: 0
                            to: 32
                            stepSize: 1
                            onValueChanged: root.setSpectrumValue("bar.visualizer.edgeInset", value)
                        }
                        ConfigSpinBox {
                            icon: "rounded_corner"
                            text: Translation.tr("Curve headroom (%)")
                            value: Config.options?.bar?.visualizer?.edgeSoftness ?? 28
                            from: 0
                            to: 100
                            stepSize: 5
                            onValueChanged: root.setSpectrumValue("bar.visualizer.edgeSoftness", value)
                            StyledToolTip {
                                text: Translation.tr("Compresses peaks only near rounded corners. Square surfaces remain edge-to-edge.")
                            }
                        }
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "tune"
                        text: Translation.tr("Frequency accent strength (%)")
                        value: Config.options?.bar?.visualizer?.accentStrength ?? 70
                        from: 0
                        to: 100
                        stepSize: 5
                        enabled: (Config.options?.bar?.visualizer?.frequencyProfile ?? "flat") !== "flat"
                        opacity: enabled ? 1 : 0.45
                        onValueChanged: root.setSpectrumValue("bar.visualizer.accentStrength", value)
                    }

                    ConfigSelectionArray {
                        visible: root.barAppearance === "pill"
                        currentValue: Config.options?.bar?.visualizer?.pillWingMode ?? "bounded"
                        onSelected: newValue => root.setSpectrumValue("bar.visualizer.pillWingMode", newValue)
                        options: [
                            { displayName: Translation.tr("Bounded"), icon: "width_normal", value: "bounded" },
                            { displayName: Translation.tr("Full screen"), icon: "width_full", value: "screen" },
                            { displayName: Translation.tr("Behind pill"), icon: "layers", value: "bleed" },
                        ]
                    }

                    ConfigRow {
                        visible: root.barAppearance === "pill"
                            && (Config.options?.bar?.visualizer?.pillWingMode ?? "bounded") === "bounded"
                        uniform: true
                        ConfigSpinBox {
                            icon: "swap_horiz"
                            text: Translation.tr("Wing length (px)")
                            value: Config.options?.bar?.visualizer?.pillWingLength ?? 180
                            from: 60
                            to: 480
                            stepSize: 10
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillWingLength", value)
                        }
                        ConfigSpinBox {
                            icon: "space_bar"
                            text: Translation.tr("Wing gap (px)")
                            value: Config.options?.bar?.visualizer?.pillWingGap ?? 12
                            from: 0
                            to: 64
                            stepSize: 2
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillWingGap", value)
                        }
                    }

                    ConfigRow {
                        visible: root.barAppearance === "pill"
                            && (Config.options?.bar?.visualizer?.pillWingMode ?? "bounded") === "screen"
                        uniform: true
                        ConfigSpinBox {
                            icon: "width_full"
                            text: Translation.tr("Screen padding (px)")
                            value: Config.options?.bar?.visualizer?.pillScreenPadding ?? 24
                            from: 0
                            to: 240
                            stepSize: 4
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillScreenPadding", value)
                        }
                        ConfigSpinBox {
                            icon: "space_bar"
                            text: Translation.tr("Pill gap (px)")
                            value: Config.options?.bar?.visualizer?.pillWingGap ?? 12
                            from: 0
                            to: 64
                            stepSize: 2
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillWingGap", value)
                        }
                    }

                    ConfigRow {
                        visible: root.barAppearance === "pill"
                            && (Config.options?.bar?.visualizer?.pillWingMode ?? "bounded") === "bleed"
                        uniform: true
                        ConfigSpinBox {
                            icon: "width_full"
                            text: Translation.tr("Screen padding (px)")
                            value: Config.options?.bar?.visualizer?.pillScreenPadding ?? 24
                            from: 0
                            to: 240
                            stepSize: 4
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillScreenPadding", value)
                        }
                        ConfigSpinBox {
                            icon: "layers"
                            text: Translation.tr("Underlap (px)")
                            value: Config.options?.bar?.visualizer?.pillUnderlap ?? 28
                            from: 0
                            to: 160
                            stepSize: 4
                            onValueChanged: root.setSpectrumValue("bar.visualizer.pillUnderlap", value)
                        }
                    }

                    ConfigSpinBox {
                        visible: root.barAppearance === "pill"
                        Layout.fillWidth: true
                        icon: "gradient"
                        text: Translation.tr("Screen-edge fade (%)")
                        value: Config.options?.bar?.visualizer?.pillEdgeFade ?? 92
                        from: 0
                        to: 100
                        stepSize: 5
                        onValueChanged: root.setSpectrumValue("bar.visualizer.pillEdgeFade", value)
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    onClicked: root.resetSpectrumDefaults()

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: 15
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Translation.tr("Reset spectrum defaults")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                SettingsNote {
                    visible: root.barAppearance !== "pill" && root.barAppearance !== "islands"
                        && ((root.barAppearance === "m3"
                                && !(Config.options?.bar?.m3?.showBackground ?? true))
                            || (root.barAppearance !== "m3"
                                && !(Config.options?.bar?.showBackground ?? true)))
                        && root.spectrumEnabled
                    icon: "info"
                    text: Translation.tr("The spectrum needs a visible bar surface, so it is hidden while the background is off.")
                }
            }
        }
            }
        }
    }

    LazySection {
        requested: root.isIiActive && root.activeSection === "behavior"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "behavior"
                expanded: true
        icon: "visibility"
        title: Translation.tr("Behavior & clock")

        SettingsGroup {

            ConfigRow {
                uniform: true

                ContentSubsection {
                    title: Translation.tr("Group style")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.borderless ?? false
                        onSelected: newValue => {
                            Config.setNestedValue("bar.borderless", newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Pills"), icon: "location_chip", value: false },
                            { displayName: Translation.tr("Seamless"), icon: "split_scene", value: true }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Auto-hide")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.autoHide?.enable ?? false
                        onSelected: newValue => {
                            Config.setNestedValue("bar.autoHide.enable", newValue);
                        }
                        options: [
                            { displayName: Translation.tr("Off"), icon: "visibility", value: false },
                            { displayName: Translation.tr("On"), icon: "visibility_off", value: true }
                        ]
                    }
                }
            }

            SettingsNote {
                visible: root.isBorderless && root.isCardStyle
                warning: true
                icon: "warning"
                text: Translation.tr("Seamless group style may look odd with Card corner style.")
            }

            // Auto-hide details — only visible while auto-hide is on. Lets the
            // user tune the reveal trigger and Super-press peek without hunting
            // through Advanced.
            Item {
                visible: root.isAutoHide
                Layout.fillWidth: true
                implicitHeight: autoHideDetails.implicitHeight
                ColumnLayout {
                    id: autoHideDetails
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 8

                    SettingsDivider {}

                    ConfigRow {
                        uniform: true
                        ConfigSpinBox {
                            icon: "linear_scale"
                            text: Translation.tr("Hover trigger height (px)")
                            value: Config.options?.bar?.autoHide?.hoverRegionWidth ?? 2
                            from: 1
                            to: 12
                            stepSize: 1
                            onValueChanged: Config.setNestedValue("bar.autoHide.hoverRegionWidth", value)
                            StyledToolTip {
                                text: Translation.tr("How thick the screen-edge zone is that reveals the hidden bar.")
                            }
                        }
                        ConfigSpinBox {
                            icon: "timer"
                            text: Translation.tr("Super peek delay (ms)")
                            value: Config.options?.bar?.autoHide?.showWhenPressingSuper?.delay ?? 140
                            from: 0
                            to: 800
                            stepSize: 20
                            onValueChanged: Config.setNestedValue("bar.autoHide.showWhenPressingSuper.delay", value)
                            enabled: CompositorService.isHyprland
                                && (Config.options?.bar?.autoHide?.showWhenPressingSuper?.enable ?? true)
                            opacity: enabled ? 1 : 0.5
                        }
                    }

                    ConfigRow {
                        uniform: true
                        SettingsSwitch {
                            buttonIcon: "keyboard_command_key"
                            text: Translation.tr("Peek on Super press")
                            checked: Config.options?.bar?.autoHide?.showWhenPressingSuper?.enable ?? true
                            enabled: CompositorService.isHyprland
                            opacity: enabled ? 1 : 0.5
                            onCheckedChanged: Config.setNestedValue("bar.autoHide.showWhenPressingSuper.enable", checked)
                            StyledToolTip {
                                text: CompositorService.isHyprland
                                    ? Translation.tr("Reveal the bar while the Super key is held.")
                                    : Translation.tr("Super-only hold detection is not available on Niri.")
                            }
                        }
                        SettingsSwitch {
                            buttonIcon: "open_in_full"
                            text: Translation.tr("Push windows when shown")
                            checked: Config.options?.bar?.autoHide?.pushWindows ?? false
                            onCheckedChanged: Config.setNestedValue("bar.autoHide.pushWindows", checked)
                            StyledToolTip {
                                text: Translation.tr("Reserve screen space when revealed instead of overlaying windows.")
                            }
                        }
                    }
                }
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "layers"
                text: Translation.tr("Show background")
                checked: Config.options?.bar?.showBackground ?? true
                onCheckedChanged: Config.setNestedValue("bar.showBackground", checked)
                StyledToolTip {
                    text: Translation.tr("Display a background behind the bar")
                }
            }

            SettingsSwitch {
                buttonIcon: "touch_app"
                text: Translation.tr("Show scroll hints")
                checked: Config.options?.bar?.showScrollHints ?? true
                onCheckedChanged: Config.setNestedValue("bar.showScrollHints", checked)
                StyledToolTip {
                    text: Translation.tr("Show brightness/volume icons when hovering bar edges")
                }
            }

            SettingsSwitch {
                buttonIcon: "unfold_more"
                text: Translation.tr("Verbose mode")
                checked: Config.options?.bar?.verbose ?? true
                onCheckedChanged: Config.setNestedValue("bar.verbose", checked)
                StyledToolTip {
                    text: Translation.tr("Wider center groups, plus the date next to the clock, the media title and the utility buttons. Off = compact bar.")
                }
            }

            ContentSubsection {
                visible: root.barAppearance !== "m3" && root.barAppearance !== "pill"
                title: Translation.tr("Clock")

                ConfigRow {
                    uniform: true

                    FontSelector {
                        id: barTimeFontSelector
                        label: Translation.tr("Time font")
                        icon: "schedule"
                        selectedFont: Config.options?.bar?.clock?.timeFontFamily ?? ""
                        onSelectedFontChanged: {
                            Config.setNestedValue("bar.clock.timeFontFamily", selectedFont)
                        }
                        Connections {
                            target: Config.options?.bar?.clock ?? null
                            function onTimeFontFamilyChanged() {
                                barTimeFontSelector.selectedFont = Config.options.bar.clock.timeFontFamily
                            }
                        }
                    }

                    ConfigSpinBox {
                        icon: "format_size"
                        text: Translation.tr("Time size (px)")
                        description: Translation.tr("0 = inherit global size")
                        value: Config.options?.bar?.clock?.timePixelSize ?? 0
                        from: 0
                        to: 64
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("bar.clock.timePixelSize", value)
                        StyledToolTip {
                            text: Translation.tr("Pixel size of the time digits in the bar clock. 0 inherits the global typography scale.")
                        }
                    }
                }

                ConfigRow {
                    uniform: true

                    FontSelector {
                        id: barDateFontSelector
                        label: Translation.tr("Date font")
                        icon: "font_download"
                        selectedFont: Config.options?.bar?.clock?.dateFontFamily ?? ""
                        onSelectedFontChanged: {
                            Config.setNestedValue("bar.clock.dateFontFamily", selectedFont)
                        }
                        Connections {
                            target: Config.options?.bar?.clock ?? null
                            function onDateFontFamilyChanged() {
                                barDateFontSelector.selectedFont = Config.options.bar.clock.dateFontFamily
                            }
                        }
                    }

                    ConfigSpinBox {
                        icon: "format_size"
                        text: Translation.tr("Date size (px)")
                        description: Translation.tr("0 = inherit global size")
                        value: Config.options?.bar?.clock?.datePixelSize ?? 0
                        from: 0
                        to: 64
                        stepSize: 1
                        onValueChanged: Config.setNestedValue("bar.clock.datePixelSize", value)
                        StyledToolTip {
                            text: Translation.tr("Pixel size of the date string in the bar clock. 0 inherits the global typography scale.")
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    enabled: (Config.options?.bar?.clock?.timeFontFamily ?? "").length > 0
                        || (Config.options?.bar?.clock?.timePixelSize ?? 0) > 0
                        || (Config.options?.bar?.clock?.dateFontFamily ?? "").length > 0
                        || (Config.options?.bar?.clock?.datePixelSize ?? 0) > 0
                    opacity: enabled ? 1 : 0.5
                    onClicked: Config.setNestedValues({
                        "bar.clock.timeFontFamily": "",
                        "bar.clock.timePixelSize": 0,
                        "bar.clock.dateFontFamily": "",
                        "bar.clock.datePixelSize": 0
                    })

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: "restart_alt"
                            iconSize: 15
                            color: Appearance.colors.colOnLayer1
                        }
                        StyledText {
                            text: Translation.tr("Reset to default")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }

                SettingsNote {
                    icon: "info"
                    text: Translation.tr("Override the font and pixel size of the time and date in the bar clock. Leave at 0 / pick the same family as your main font to keep the default look.")
                }
            }

            SettingsSwitch {
                buttonIcon: "deployed_code"
                text: Translation.tr("Float style drop shadow")
                checked: Config.options?.bar?.floatStyleShadow ?? true
                onCheckedChanged: Config.setNestedValue("bar.floatStyleShadow", checked)
                enabled: root.isFloatStyle || root.isCardStyle
                opacity: enabled ? 1 : 0.5
                StyledToolTip {
                    text: Translation.tr("Render a soft shadow under the bar in Float / Card corner styles.")
                }
            }

            ConfigRow {
                uniform: true

                ContentSubsection {
                    title: Translation.tr("Left scroll action")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.leftScrollAction ?? "brightness"
                        onSelected: newValue => {
                            Config.setNestedValue("bar.leftScrollAction", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Brightness"), icon: "light_mode", value: "brightness" },
                            { displayName: Translation.tr("Volume"), icon: "volume_up", value: "volume" },
                            { displayName: Translation.tr("Workspaces"), icon: "workspaces", value: "workspace" },
                            { displayName: Translation.tr("None"), icon: "block", value: "none" }
                        ]
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Right scroll action")

                    ConfigSelectionArray {
                        currentValue: Config.options?.bar?.rightScrollAction ?? "volume"
                        onSelected: newValue => {
                            Config.setNestedValue("bar.rightScrollAction", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Brightness"), icon: "light_mode", value: "brightness" },
                            { displayName: Translation.tr("Volume"), icon: "volume_up", value: "volume" },
                            { displayName: Translation.tr("Workspaces"), icon: "workspaces", value: "workspace" },
                            { displayName: Translation.tr("None"), icon: "block", value: "none" }
                        ]
                    }
                }
            }

            SettingsNote {
                visible: !root.showBackground && root.isBorderless
                icon: "lightbulb"
                text: Translation.tr("No background + Seamless style = floating widgets look")
            }

            SettingsDivider {}

            SettingsSwitch {
                buttonIcon: "vignette"
                text: Translation.tr("Vignette effect")
                checked: root.hasVignette
                onCheckedChanged: {
                    Config.setNestedValue("bar.vignette.enabled", checked)
                }
                StyledToolTip {
                    text: Translation.tr("Gradient shadow from screen edge")
                }
            }

            ConfigSpinBox {
                visible: root.hasVignette
                icon: "opacity"
                text: Translation.tr("Intensity (%)")
                value: Math.round((Config.options?.bar?.vignette?.intensity ?? 0.6) * 100)
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.intensity", value / 100)
                }
            }

            ConfigSpinBox {
                visible: root.hasVignette
                icon: "blur_on"
                text: Translation.tr("Radius (%)")
                value: Math.round((Config.options?.bar?.vignette?.radius ?? 0.5) * 100)
                from: 10
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.setNestedValue("bar.vignette.radius", value / 100)
                }
            }

            SettingsNote {
                visible: root.hasVignette && root.isAutoHide
                icon: "info"
                text: Translation.tr("Vignette will hide along with the bar when auto-hide is active.")
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MODULES (what to show)
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "widgets"
        title: Translation.tr("Modules")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Toggle which widgets appear in the bar")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "side_navigation"
                    text: Translation.tr("Left sidebar button")
                    checked: Config.options?.bar?.modules?.leftSidebarButton ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.leftSidebarButton", checked)
                }
                SettingsSwitch {
                    buttonIcon: "call_to_action"
                    text: Translation.tr("Right sidebar button")
                    checked: Config.options?.bar?.modules?.rightSidebarButton ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.rightSidebarButton", checked)
                }
            }

            // Left sidebar button icon. "distro" auto-detects from /etc/os-release;
            // anything else looks up <name>-symbolic in the icon theme.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: Config.options?.bar?.modules?.leftSidebarButton ?? true
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Left sidebar icon")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
                MaterialTextField {
                    id: topLeftIconField
                    Layout.fillWidth: true
                    placeholderText: "distro"
                    text: Config.options?.bar?.topLeftIcon ?? "distro"
                    // Persisting per keystroke resolves every prefix as an icon name.
                    onTextChanged: topLeftIconCommit.restart()
                    onEditingFinished: {
                        topLeftIconCommit.stop();
                        Config.setNestedValue("bar.topLeftIcon", topLeftIconField.text);
                    }

                    Timer {
                        id: topLeftIconCommit
                        interval: 600
                        repeat: false
                        onTriggered: Config.setNestedValue("bar.topLeftIcon", topLeftIconField.text)
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("‘distro’ auto-detects your distribution. Otherwise enter any icon name (looked up as <name>-symbolic).")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "window"
                    text: Translation.tr("Active window title")
                    checked: Config.options?.bar?.modules?.activeWindow ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.activeWindow", checked)
                    enabled: !(Config.options?.bar?.modules?.taskbar ?? false)
                    opacity: enabled ? 1 : 0.5
                }
                SettingsSwitch {
                    buttonIcon: "dock_to_bottom"
                    text: Translation.tr("Taskbar (apps in bar)")
                    checked: Config.options?.bar?.modules?.taskbar ?? false
                    onCheckedChanged: Config.setNestedValue("bar.modules.taskbar", checked)
                }
            }

            SettingsNote {
                visible: (Config.options?.bar?.modules?.taskbar ?? false)
                icon: "info"
                text: Translation.tr("Taskbar replaces the active window title. Pinned apps and running windows appear in the bar, like a traditional taskbar. Uses the same pinned apps as the dock.")
            }

            // Sub-toggle for the active window indicator: hide the second line (window title)
            // and only show the app name. Hidden when activeWindow is off or taskbar is on.
            SettingsSwitch {
                visible: (Config.options?.bar?.modules?.activeWindow ?? true) && !(Config.options?.bar?.modules?.taskbar ?? false)
                buttonIcon: "subtitles"
                text: Translation.tr("Show window title under app name")
                checked: Config.options?.bar?.activeWindow?.showTitle ?? true
                onCheckedChanged: Config.setNestedValue("bar.activeWindow.showTitle", checked)
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "shelf_auto_hide"
                    text: Translation.tr("System tray")
                    checked: Config.options?.bar?.modules?.sysTray ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.sysTray", checked)
                }
                Item { Layout.fillWidth: true }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "memory"
                    text: Translation.tr("Resources")
                    checked: Config.options?.bar?.modules?.resources ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.resources", checked)
                }
                SettingsSwitch {
                    buttonIcon: "music_note"
                    text: Translation.tr("Media")
                    checked: Config.options?.bar?.modules?.media ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.media", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "workspaces"
                    text: Translation.tr("Workspaces")
                    checked: Config.options?.bar?.modules?.workspaces ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.workspaces", checked)
                }
                SettingsSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Clock")
                    checked: Config.options?.bar?.modules?.clock ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.clock", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "build"
                    text: Translation.tr("Utility buttons")
                    checked: Config.options?.bar?.modules?.utilButtons ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.utilButtons", checked)
                }
                SettingsSwitch {
                    buttonIcon: "battery_full"
                    text: Translation.tr("Battery")
                    checked: Config.options?.bar?.modules?.battery ?? true
                    onCheckedChanged: Config.setNestedValue("bar.modules.battery", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "cloud"
                    text: Translation.tr("Weather")
                    checked: Config.options?.bar?.modules?.weather ?? false
                    onCheckedChanged: Config.setNestedValue("bar.modules.weather", checked)
                    enabled: Config.options?.bar?.weather?.enable ?? false
                    opacity: enabled ? 1 : 0.5
                }
                Item { Layout.fillWidth: true }
            }

            SettingsDivider {}

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Weather configuration is in Services → Weather")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MODULE LAYOUT (reorder / relocate)
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "reorder"
        title: Translation.tr("Bar module layout")

        SettingsGroup {
            ConfigSpinBox {
                icon: "space_bar"
                text: Translation.tr("Flexible spacer width")
                value: Config.options?.bar?.layout?.spacerWidth ?? 0
                from: 0
                to: 480
                stepSize: 8
                onValueChanged: Config.setNestedValue("bar.layout.spacerWidth", value)
                StyledToolTip {
                    text: Translation.tr("Minimum width for each Flexible spacer module. 0 keeps it fully elastic.")
                }
            }

            ConfigSelectionArray {
                currentValue: Config.options?.bar?.layout?.spacerMode ?? "auto"
                onSelected: (newValue) => Config.setNestedValue("bar.layout.spacerMode", newValue)
                options: [
                    { displayName: Translation.tr("Smart"), icon: "auto_awesome", value: "auto" },
                    { displayName: Translation.tr("Always elastic"), icon: "width_full", value: "fill" },
                    { displayName: Translation.tr("Fixed width"), icon: "width_normal", value: "fixed" }
                ]
            }

            BarModuleOrderEditor {}
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // RESOURCES
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "browse_activity"
        title: Translation.tr("Resources")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose which indicators are shown in the resources module")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "memory"
                    text: Translation.tr("Show RAM indicator")
                    checked: Config.options?.bar?.resources?.showMemoryIndicator ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.showMemoryIndicator", checked)
                }
                SettingsSwitch {
                    buttonIcon: "thermostat"
                    text: Translation.tr("Show temp indicator")
                    checked: Config.options?.bar?.resources?.showTempIndicator ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.showTempIndicator", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "planner_review"
                    text: Translation.tr("Show CPU indicator")
                    checked: Config.options?.bar?.resources?.showCpuIndicator ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.showCpuIndicator", checked)
                }
                SettingsSwitch {
                    buttonIcon: "videocam"
                    text: Translation.tr("Show GPU indicator")
                    checked: Config.options?.bar?.resources?.showGpuIndicator ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.showGpuIndicator", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "swap_horiz"
                    text: Translation.tr("Show swap indicator")
                    checked: Config.options?.bar?.resources?.showSwapIndicator ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.showSwapIndicator", checked)
                }
                Item { Layout.fillWidth: true }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Always show CPU")
                    checked: Config.options?.bar?.resources?.alwaysShowCpu ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.alwaysShowCpu", checked)
                }
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Always show GPU")
                    checked: Config.options?.bar?.resources?.alwaysShowGpu ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.alwaysShowGpu", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Always show temp")
                    checked: Config.options?.bar?.resources?.alwaysShowTemp ?? true
                    onCheckedChanged: Config.setNestedValue("bar.resources.alwaysShowTemp", checked)
                }
                Item { Layout.fillWidth: true }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "memory"
                    text: Translation.tr("RAM warning (%)")
                    value: Config.options?.bar?.resources?.memoryWarningThreshold ?? 90
                    from: 50
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.memoryWarningThreshold", value)
                }
                ConfigSpinBox {
                    icon: "planner_review"
                    text: Translation.tr("CPU warning (%)")
                    value: Config.options?.bar?.resources?.cpuWarningThreshold ?? 90
                    from: 50
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.cpuWarningThreshold", value)
                }
            }

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "videocam"
                    text: Translation.tr("GPU warning (%)")
                    value: Config.options?.bar?.resources?.gpuWarningThreshold ?? 90
                    from: 50
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.gpuWarningThreshold", value)
                }
                ConfigSpinBox {
                    icon: "swap_horiz"
                    text: Translation.tr("Swap warning (%)")
                    value: Config.options?.bar?.resources?.swapWarningThreshold ?? 85
                    from: 50
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.swapWarningThreshold", value)
                }
            }

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "thermostat"
                    text: Translation.tr("Temp caution (°C)")
                    value: Config.options?.bar?.resources?.tempCautionThreshold ?? 65
                    from: 40
                    to: 100
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.tempCautionThreshold", value)
                }
                ConfigSpinBox {
                    icon: "device_thermostat"
                    text: Translation.tr("Temp warning (°C)")
                    value: Config.options?.bar?.resources?.tempWarningThreshold ?? 80
                    from: 50
                    to: 120
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.resources.tempWarningThreshold", value)
                }
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // MEDIA
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "music_note"
        title: Translation.tr("Media")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Popup mode")

                ConfigSelectionArray {
                    currentValue: Config.options?.media?.popupMode ?? "dock"
                    onSelected: newValue => {
                        Config.setNestedValue("media.popupMode", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Bottom overlay"), icon: "picture_in_picture", value: "dock" },
                        { displayName: Translation.tr("From bar"), icon: "open_in_new", value: "bar" }
                    ]
                }
            }

            SettingsNote {
                icon: "info"
                text: Config.options?.media?.popupMode === "bar"
                    ? Translation.tr("Classic style popup anchored to bar widget")
                    : Translation.tr("Modern overlay at screen bottom")
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // WORKSPACES
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && !(Config.options?.settingsUi?.easyMode ?? false) && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        SettingsGroup {
            ContentSubsection {
                title: Translation.tr("Scroll behavior")
                visible: CompositorService.isNiri

                ConfigSelectionArray {
                    currentValue: Config.options?.bar?.workspaces?.scrollBehavior ?? "workspace"
                    onSelected: newValue => {
                        Config.setNestedValue("bar.workspaces.scrollBehavior", newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Switch workspaces"), icon: "workspaces", value: "workspace" },
                        { displayName: Translation.tr("Cycle columns"), icon: "view_column", value: "column" }
                    ]
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "counter_1"
                    text: Translation.tr("Always show numbers")
                    checked: Config.options?.bar?.workspaces?.alwaysShowNumbers ?? false
                    onCheckedChanged: Config.setNestedValue("bar.workspaces.alwaysShowNumbers", checked)
                    StyledToolTip {
                        text: Translation.tr("Show numbers instead of only when Super is held")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "award_star"
                    text: Translation.tr("Show app icons")
                    checked: Config.options?.bar?.workspaces?.showAppIcons ?? true
                    onCheckedChanged: Config.setNestedValue("bar.workspaces.showAppIcons", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Tint app icons")
                    checked: Config.options?.bar?.workspaces?.monochromeIcons ?? true
                    onCheckedChanged: Config.setNestedValue("bar.workspaces.monochromeIcons", checked)
                    enabled: Config.options?.bar?.workspaces?.showAppIcons ?? true
                    opacity: enabled ? 1 : 0.5
                }
                SettingsSwitch {
                    buttonIcon: "dynamic_feed"
                    text: Translation.tr("Dynamic count")
                    checked: Config.options?.bar?.workspaces?.dynamicCount ?? true
                    onCheckedChanged: Config.setNestedValue("bar.workspaces.dynamicCount", checked)
                    StyledToolTip {
                        text: Translation.tr("Only show existing workspaces (Niri)")
                    }
                }
            }

            SettingsSwitch {
                buttonIcon: "all_inclusive"
                text: Translation.tr("Wrap around")
                checked: Config.options?.bar?.workspaces?.wrapAround ?? true
                onCheckedChanged: Config.setNestedValue("bar.workspaces.wrapAround", checked)
                StyledToolTip {
                    text: Translation.tr("Cycle from last to first and vice versa")
                }
            }

            SettingsSwitch {
                buttonIcon: "desktop_windows"
                text: Translation.tr("Per-monitor")
                checked: Config.options?.bar?.workspaces?.perMonitor ?? true
                onCheckedChanged: Config.setNestedValue("bar.workspaces.perMonitor", checked)
                visible: CompositorService.isNiri
                StyledToolTip {
                    text: Translation.tr("Each bar shows workspaces for its own monitor")
                }
            }

            SettingsSwitch {
                buttonIcon: "swap_vert"
                text: Translation.tr("Invert scroll")
                checked: Config.options?.bar?.workspaces?.invertScroll ?? false
                onCheckedChanged: Config.setNestedValue("bar.workspaces.invertScroll", checked)
                StyledToolTip {
                    text: Translation.tr("Reverse mouse wheel direction for switching workspaces")
                }
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Color")

                ConfigRow {
                    uniform: true

                    SettingsSwitch {
                        buttonIcon: "auto_awesome"
                        text: Translation.tr("Automatic")
                        checked: Config.options?.bar?.workspaces?.automaticIndicatorColor ?? true
                        onCheckedChanged: Config.setNestedValue("bar.workspaces.automaticIndicatorColor", checked)
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        enabled: !(Config.options?.bar?.workspaces?.automaticIndicatorColor ?? true)
                        opacity: enabled ? 1 : 0.5
                        colBackground: Appearance.colors.colLayer2
                        colBackgroundHover: Appearance.colors.colLayer2Hover
                        colRipple: Appearance.colors.colLayer2Active
                        downAction: () => workspaceIndicatorColorDialog.open()

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: root.workspaceIndicatorPreviewColor
                                border.width: 1
                                border.color: Appearance.colors.colOutline
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Color")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledText {
                                text: root.workspaceIndicatorPreviewColor.toString().toUpperCase().substring(0, 7)
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.family: Appearance.font.family.monospace
                                color: Appearance.colors.colSubtext
                            }

                            MaterialSymbol {
                                text: "edit"
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }
                        }
                    }
                }
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "view_column"
                    text: Translation.tr("Shown")
                    value: Config.options?.bar?.workspaces?.shown ?? 10
                    from: 1
                    to: 30
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.workspaces.shown", value)
                    enabled: !(Config.options?.bar?.workspaces?.dynamicCount ?? true)
                    opacity: enabled ? 1 : 0.5
                }
                ConfigSpinBox {
                    icon: "mouse"
                    text: Translation.tr("Scroll steps")
                    value: Config.options?.bar?.workspaces?.scrollSteps ?? 3
                    from: 1
                    to: 10
                    stepSize: 1
                    onValueChanged: Config.setNestedValue("bar.workspaces.scrollSteps", value)
                }
            }

            ConfigSpinBox {
                icon: "touch_long"
                text: Translation.tr("Number reveal delay (ms)")
                value: Config.options?.bar?.workspaces?.showNumberDelay ?? 300
                from: 0
                to: 1000
                stepSize: 50
                onValueChanged: Config.setNestedValue("bar.workspaces.showNumberDelay", value)
                enabled: !(Config.options?.bar?.workspaces?.alwaysShowNumbers ?? false)
                opacity: enabled ? 1 : 0.5
            }

            SettingsNote {
                visible: Config.options?.bar?.workspaces?.alwaysShowNumbers ?? false
                icon: "info"
                text: Translation.tr("Number reveal delay is ignored when 'Always show numbers' is enabled")
            }

            SettingsDivider {}

            ContentSubsection {
                title: Translation.tr("Number style")

                ConfigSelectionArray {
                    enabled: Config.options?.bar?.workspaces?.alwaysShowNumbers ?? false
                    opacity: enabled ? 1 : 0.5
                    currentValue: JSON.stringify(Config.options?.bar?.workspaces?.numberMap ?? ["1","2"])
                    onSelected: newValue => {
                        Config.setNestedValue("bar.workspaces.numberMap", JSON.parse(newValue))
                    }
                    options: [
                        { displayName: Translation.tr("Normal"), icon: "123", value: '["1","2","3","4","5","6","7","8","9","10"]' },
                        { displayName: Translation.tr("Japanese"), icon: "square_dot", value: '["一","二","三","四","五","六","七","八","九","十"]' },
                        { displayName: Translation.tr("Roman"), icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X"]' }
                    ]
                }
            }

            SettingsNote {
                visible: !Config.options?.bar?.workspaces?.alwaysShowNumbers
                icon: "lightbulb"
                text: Translation.tr("Enable 'Always show numbers' to use number styles")
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // SYSTEM TRAY
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "shelf_auto_hide"
        title: Translation.tr("System Tray")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Pin icons by default")
                checked: Config.options?.bar?.tray?.invertPinnedItems ?? true
                onCheckedChanged: Config.setNestedValue("bar.tray.invertPinnedItems", checked)
                StyledToolTip {
                    text: Translation.tr("New tray icons are visible by default instead of hidden")
                }
            }

            SettingsSwitch {
                buttonIcon: "colors"
                text: Translation.tr("Tint icons")
                checked: Config.options?.bar?.tray?.monochromeIcons ?? true
                onCheckedChanged: Config.setNestedValue("bar.tray.monochromeIcons", checked)
                StyledToolTip {
                    text: Translation.tr("Apply accent color tint to tray icons")
                }
            }

            SettingsSwitch {
                buttonIcon: "bug_report"
                text: Translation.tr("Show item ID in tooltip")
                checked: Config.options?.bar?.tray?.showItemId ?? false
                onCheckedChanged: Config.setNestedValue("bar.tray.showItemId", checked)
                StyledToolTip {
                    text: Translation.tr("Useful for debugging tray issues")
                }
            }

            SettingsNote {
                visible: !(Config.options?.bar?.modules?.sysTray ?? true)
                warning: true
                icon: "visibility_off"
                text: Translation.tr("System tray is disabled in Modules section above")
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // UTILITY BUTTONS
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "build"
        title: Translation.tr("Utility Buttons")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Quick action buttons in the bar")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "content_cut"
                    text: Translation.tr("Screen snip")
                    checked: Config.options?.bar?.utilButtons?.showScreenSnip ?? true
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showScreenSnip", checked)
                }
                SettingsSwitch {
                    buttonIcon: "videocam"
                    text: Translation.tr("Screen record")
                    checked: Config.options?.bar?.utilButtons?.showScreenRecord ?? true
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showScreenRecord", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "visibility"
                    text: Translation.tr("Screen cast")
                    checked: Config.options?.bar?.utilButtons?.showScreenCast ?? false
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showScreenCast", checked)
                    StyledToolTip {
                        text: Translation.tr("Toggle Niri dynamic screen casting (mirroring) to a target output")
                    }
                }
                SettingsSwitch {
                    buttonIcon: "colorize"
                    text: Translation.tr("Color picker")
                    checked: Config.options?.bar?.utilButtons?.showColorPicker ?? false
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showColorPicker", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "edit_note"
                    text: Translation.tr("Notepad")
                    checked: Config.options?.bar?.utilButtons?.showNotepad ?? true
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showNotepad", checked)
                }
                // Empty slot for future button
                Item { Layout.fillWidth: true }
            }

            StyledText {
                visible: Config.options?.bar?.utilButtons?.showScreenCast ?? false
                Layout.fillWidth: true
                text: Translation.tr("Toggle button to start/stop Niri dynamic casting (screen mirroring) to a target output.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            MaterialTextArea {
                visible: Config.options?.bar?.utilButtons?.showScreenCast ?? false
                Layout.fillWidth: true
                placeholderText: "HDMI-A-1"
                text: Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1"
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.setNestedValue("bar.utilButtons.screenCastOutput", text)
                }
            }

            StyledText {
                visible: Config.options?.bar?.utilButtons?.showScreenCast ?? false
                Layout.fillWidth: true
                text: Translation.tr("Run 'niri msg outputs' to find your output name")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsDivider {}

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "keyboard"
                    text: Translation.tr("Virtual keyboard")
                    checked: Config.options?.bar?.utilButtons?.showKeyboardToggle ?? true
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showKeyboardToggle", checked)
                }
                SettingsSwitch {
                    buttonIcon: "language"
                    text: Translation.tr("Keyboard layout switch")
                    checked: Config.options?.bar?.utilButtons?.showKeyboardLayoutSwitch ?? false
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showKeyboardLayoutSwitch", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "mic"
                    text: Translation.tr("Mic toggle")
                    checked: Config.options?.bar?.utilButtons?.showMicToggle ?? false
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showMicToggle", checked)
                }
                SettingsSwitch {
                    buttonIcon: "dark_mode"
                    text: Translation.tr("Dark/Light mode")
                    checked: Config.options?.bar?.utilButtons?.showDarkModeToggle ?? true
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showDarkModeToggle", checked)
                }
            }

            ConfigRow {
                uniform: true
                SettingsSwitch {
                    buttonIcon: "speed"
                    text: Translation.tr("Power profile")
                    checked: Config.options?.bar?.utilButtons?.showPerformanceProfileToggle ?? false
                    onCheckedChanged: Config.setNestedValue("bar.utilButtons.showPerformanceProfileToggle", checked)
                }
            }
        }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // NOTIFICATIONS
    // ═══════════════════════════════════════════════════════════════════
    LazySection {
        requested: root.isIiActive && root.activeSection === "modules"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "modules"
                expanded: false
        icon: "notifications"
        title: Translation.tr("Notifications")

        SettingsGroup {
            SettingsSwitch {
                buttonIcon: "counter_2"
                text: Translation.tr("Show unread count")
                checked: Config.options?.bar?.indicators?.notifications?.showUnreadCount ?? false
                onCheckedChanged: Config.setNestedValue("bar.indicators.notifications.showUnreadCount", checked)
                StyledToolTip {
                    text: Translation.tr("Show number instead of just a dot")
                }
            }
        }
            }
        }
    }
}
