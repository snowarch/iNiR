//@ pragma UseQApplication
//@ pragma AppId inir
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
import qs.modules.common.welcome

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
    property real cardWidth: 0
    readonly property real stepWidth: Math.max(0, root.cardWidth - 2 * (root.compact ? 22 : 28) - 2 * root.welcomeFrameInset)
    readonly property int totalSteps: 5
    property var focusedScreen: GlobalStates.primaryScreen
    readonly property real screenAspect: root.screenWidth / Math.max(1, root.screenHeight)

    property string requestedFamily: ""
    readonly property string family: root.requestedFamily.length > 0
        ? root.requestedFamily : (Config.options?.panelFamily ?? "ii")
    readonly property string familyTitle: String(Plugins.manifests[root.family]?.name ?? root.family)
    // The chosen family's part `welcome`: its look tokens, and its own steps when it ships pages.
    readonly property var familyWelcome: familyWelcomeLoader.item
    readonly property var familyLook: root.familyWelcome
    // the stack holds three middle steps: a family brings all three (pages and their texts) or none
    readonly property bool customSteps: (root.familyWelcome?.pages?.length ?? 0) === 3
        && (root.familyWelcome?.steps?.length ?? 0) === 3
    property var _familyEntered: ({})

    // Onboarding follows the selected family, independently of ii's Global Style.
    readonly property color welcomeSurfaceRaised: root.familyLook?.welcomeSurfaceRaised ?? Appearance.m3colors.m3surfaceContainer
    readonly property color welcomeSurfaceHigh: root.familyLook?.welcomeSurfaceHigh ?? Appearance.m3colors.m3surfaceContainerHigh
    readonly property color welcomeSurfaceHighest: root.familyLook?.welcomeSurfaceHighest ?? Appearance.m3colors.m3surfaceContainerHighest
    readonly property color welcomeSurfaceRaisedHover: root.familyLook?.welcomeSurfaceRaisedHover ?? ColorUtils.mix(welcomeSurfaceRaised, welcomeOnSurface, 0.94)
    readonly property color welcomeOnSurface: root.familyLook?.welcomeOnSurface ?? Appearance.m3colors.m3onSurface
    readonly property color welcomeOnSurfaceVariant: root.familyLook?.welcomeOnSurfaceVariant ?? Appearance.m3colors.m3onSurfaceVariant
    readonly property color welcomeOutline: root.familyLook?.welcomeOutline ?? Appearance.m3colors.m3outlineVariant
    readonly property color welcomeScrim: Appearance.m3colors.m3scrim
    readonly property color welcomePrimary: root.familyLook?.welcomePrimary ?? Appearance.m3colors.m3primary
    readonly property color welcomeOnPrimary: root.familyLook?.welcomeOnPrimary ?? Appearance.m3colors.m3onPrimary
    readonly property color welcomePrimaryContainer: root.familyLook?.welcomePrimaryContainer ?? ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHigh, Appearance.m3colors.m3primaryContainer, 0.72)
    readonly property color welcomeOnPrimaryContainer: root.familyLook?.welcomeOnPrimaryContainer ?? Appearance.m3colors.m3onSurface
    readonly property color welcomeSecondary: root.familyLook?.welcomeSecondary ?? Appearance.m3colors.m3secondary
    readonly property color welcomeSecondaryContainer: root.familyLook?.welcomeSecondaryContainer ?? Appearance.m3colors.m3surfaceContainer
    readonly property color welcomeOnSecondaryContainer: root.familyLook?.welcomeOnSecondaryContainer ?? Appearance.m3colors.m3onSurface
    readonly property color welcomeTertiary: root.familyLook?.welcomeTertiary ?? Appearance.m3colors.m3tertiary
    readonly property color welcomeTertiaryContainer: root.familyLook?.welcomeTertiaryContainer ?? ColorUtils.mix(Appearance.m3colors.m3surfaceContainer, Appearance.m3colors.m3tertiaryContainer, 0.84)
    readonly property color welcomeOnTertiaryContainer: root.familyLook?.welcomeOnTertiaryContainer ?? Appearance.m3colors.m3onSurfaceVariant
    // Wallpaper colour provides feedback without switching ii's wizard dialect.
    readonly property color welcomeAccent: welcomePrimary
    readonly property color welcomeAccentAlt: welcomeTertiary
    readonly property color welcomeAccentContainer: welcomePrimaryContainer
    readonly property color welcomeAccentHover: root.familyLook?.welcomeAccentHover ?? ColorUtils.mix(Appearance.m3colors.m3surfaceContainerHighest, Appearance.m3colors.m3primaryContainer, 0.68)
    readonly property color welcomeOnAccent: welcomeOnPrimary
    readonly property color welcomeOnAccentContainer: welcomeOnPrimaryContainer
    readonly property color welcomeGuideContainer: welcomeTertiaryContainer
    readonly property color welcomeGuideText: welcomeOnTertiaryContainer
    readonly property string welcomeFontMain: root.familyLook?.welcomeFontMain ?? (Config.options?.appearance?.typography?.mainFont ?? "Roboto Flex")
    readonly property string welcomeFontTitle: root.familyLook?.welcomeFontTitle ?? (Config.options?.appearance?.typography?.titleFont ?? "Gabarito")
    readonly property string welcomeFontNumbers: root.familyLook?.welcomeFontNumbers ?? "Rubik"
    readonly property string welcomeFontExpressive: "Space Grotesk"
    readonly property int welcomeFontMeta: Math.max(13, Appearance.font.pixelSize.smallest)
    readonly property int welcomeFontCaption: Math.max(14, Appearance.font.pixelSize.smaller)
    readonly property int welcomeFontBody: Math.max(15, Appearance.font.pixelSize.small)
    readonly property int welcomeFontSection: Math.max(17, Appearance.font.pixelSize.normal)
    readonly property color welcomeSecondaryText: ColorUtils.ensureReadable(
        welcomeOnSurfaceVariant, welcomeSurfaceRaised, 4.5)
    readonly property color welcomeTertiaryText: ColorUtils.ensureReadable(
        ColorUtils.applyAlpha(welcomeOnSurfaceVariant, 0.86), welcomeSurfaceRaised, 4.0)
    readonly property real welcomePanelRadius: root.familyLook?.welcomePanelRadius ?? 24
    readonly property real welcomeControlRadius: root.familyLook?.welcomeControlRadius ?? 12
    readonly property real welcomeChoiceRadius: root.familyLook?.welcomeChoiceRadius ?? 14
    readonly property real welcomeCardRadius: root.familyLook?.welcomeCardRadius ?? 16
    readonly property real welcomeFrameInset: root.familyLook?.welcomeFrameInset ?? 0
    readonly property real welcomeHeadlineSize: root.familyLook?.welcomeHeadlineSize ?? 0
    readonly property color welcomeSegmentFill: root.familyLook?.welcomeSegmentFill ?? root.welcomeSurfaceRaised
    readonly property real welcomeKeyRadius: root.familyLook?.welcomeKeyRadius ?? 7
    readonly property bool welcomeBorderless: root.familyLook?.welcomeBorderless ?? false
    readonly property real welcomePlateRadius: root.familyLook?.welcomePlateRadius ?? 16
    readonly property color welcomeQuietFill: root.familyLook?.welcomeQuietFill ?? "transparent"
    readonly property bool welcomeChoiceMark: root.familyLook?.welcomeChoiceMark ?? true
    readonly property real welcomeIntroShare: root.familyLook?.welcomeIntroShare ?? 0.43
    // What the active family offers on the base steps (its welcome part): starting profiles and style presets, each
    // answering the config values it writes (`profileValues(id)`, `styleValues(id, profile)`). A family with neither
    // keeps only Effects and the wallpaper on those steps; one with its own pages sums them up (`startSummary`).
    readonly property var profileChoices: Array.from(root.familyWelcome?.profileChoices ?? [])
    readonly property var stylePresets: Array.from(root.familyWelcome?.stylePresets ?? [])
    readonly property bool welcomeProfiles: root.profileChoices.length > 0 || root.familyWelcome?.startSummary !== undefined
    readonly property bool welcomeStyles: root.stylePresets.length > 0 || root.familyWelcome?.styleSummary !== undefined

    readonly property string selectedProfile: Config.options?.welcomeWizard?.profile ?? "balanced"
    readonly property string selectedStylePreset: Config.options?.welcomeWizard?.stylePreset ?? (root.stylePresets[0]?.id ?? "")
    readonly property string selectedPerformancePreset: Config.options?.welcomeWizard?.performancePreset ?? "balanced"
    property bool profileCustomized: false
    property bool initialProfileApplied: false
    property bool initialPerformanceApplied: false
    readonly property bool firstRunSetup: !(Config.options?.welcomeWizard?.completed ?? false)
        && !(Config.options?.welcomeWizard?.skipped ?? false)

    readonly property var selectedProfileChoice: root.profileChoices.find(choice => choice.id === root.selectedProfile)
        ?? root.profileChoices[0] ?? ({})
    readonly property string selectedProfileTitle: String(root.selectedProfileChoice.name ?? "")
    readonly property string selectedProfileDescription: String(root.selectedProfileChoice.description ?? "")

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

    function stylePresetMatches(id: string): bool {
        const preset = root.stylePresets.find(entry => entry.id === id)
        return !!preset && Appearance.globalStyle === (preset.globalStyle ?? Appearance.globalStyle)
            && root.valuesMatch(root.familyWelcome.styleValues(id, root.selectedProfile))
    }

    function performancePresetMatches(id: string): bool {
        return root.valuesMatch(root.presetById(root.performancePresets, id).values)
    }

    readonly property string effectiveStylePreset: root.welcomeStyles && root.stylePresetMatches(root.selectedStylePreset)
        ? root.selectedStylePreset : "custom"
    readonly property string effectivePerformancePreset: root.performancePresetMatches(root.selectedPerformancePreset)
        ? root.selectedPerformancePreset : "custom"
    readonly property var currentStylePreset: root.presetById(root.stylePresets, root.selectedStylePreset) ?? ({})
    readonly property var currentPerformancePreset: root.presetById(root.performancePresets, root.selectedPerformancePreset)
    readonly property string currentStylePresetDescription: root.effectiveStylePreset === "custom"
        ? Translation.tr("Your current settings mix styles. Pick a preset to bring the shell back into sync.")
        : root.currentStylePreset.description
    readonly property string currentPerformancePresetDescription: root.effectivePerformancePreset === "custom"
        ? Translation.tr("Your effects settings are custom. Pick a mode to restore a matched setup.")
        : root.currentPerformancePreset.description

    function applyProfile(profile: string): void {
        if (root.profileChoices.length === 0)
            return
        Config.setNestedValues(Object.assign({}, root.familyWelcome.profileValues(profile), {
            "welcomeWizard.profile": profile
        }))
        root.profileCustomized = false
    }

    function applyStylePreset(id: string): void {
        const preset = root.stylePresets.find(entry => entry.id === id)
        if (!preset)
            return
        if (preset.globalStyle)
            ThemeService.setGlobalStyle(preset.globalStyle)
        Config.setNestedValues(Object.assign({}, root.familyWelcome.styleValues(id, root.selectedProfile), {
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

    onCurrentStepChanged: if (root.firstRunSetup) root._enterStep(root.currentStep)
    // a family picked mid-run enters the step on screen too
    onFamilyWelcomeChanged: if (root.firstRunSetup) root._enterStep(root.currentStep)

    // What arriving at a step sets (its recommended pick), once per family and step in a run: switching
    // families and back must not reapply its defaults.
    function _enterStep(step: int): void {
        if (step === 1) {
            if (!root.customSteps && root.welcomeProfiles && !root.initialProfileApplied) {
                root.initialProfileApplied = true
                root.applyProfile(root.selectedProfile)
            }
            if (!root.initialPerformanceApplied) {
                root.initialPerformanceApplied = true
                root.applyPerformancePreset(root.selectedPerformancePreset)
            }
        }
        const entry = `${root.family}:${step}`
        if (typeof root.familyWelcome?.entered === "function" && !root._familyEntered[entry]) {
            root._familyEntered[entry] = true
            root.familyWelcome.entered(step)
        }
    }

    // Skip lands where Continue would: every step not reached yet sets its recommended pick.
    function skipRest(): void {
        for (let step = root.currentStep + 1; step < root.totalSteps - 1; step++)
            root._enterStep(step)
        root.finish(true)
    }

    // ─── Entry/exit animation state (gate pattern) ───
    property bool _entryReady: false
    property bool _contentReady: false
    property bool _closing: false

    // The base steps when the family brings no words of its own; its placement rows fill the Layout step.
    readonly property var baseSteps: [
        {
            icon: "tune", title: Translation.tr("Starting point"),
            headline: Translation.tr("Choose your effects"),
            subtitle: Translation.tr("How much motion and blur the desktop uses.")
        },
        {
            icon: "palette", title: Translation.tr("Appearance"),
            headline: Translation.tr("Make it yours"),
            subtitle: Translation.tr("Wallpaper sets the colors across the shell and your apps.")
        },
        {
            icon: "dashboard", title: Translation.tr("Layout"),
            headline: Translation.tr("Arrange the desktop"),
            subtitle: Translation.tr("Choose the shell family that matches how you want the desktop to work.")
        }
    ]
    readonly property var placementRows: root.familyWelcome?.placementRows ?? []

    readonly property var steps: [
        {
            icon: "waving_hand", title: Translation.tr("Welcome"),
            headline: Translation.tr("Welcome to iNiR"),
            subtitle: Translation.tr("Pick the desktop you want to start with. The next steps adapt to it.")
        },
        ...((root.familyWelcome?.steps?.length ?? 0) === 3 ? root.familyWelcome.steps : root.baseSteps),
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
            Quickshell.execDetached(["notify-send", Translation.tr("Welcome to inir"), Translation.tr("Press Super+/ for all keyboard shortcuts."), "-a", "Shell"])
            Qt.quit()
        }
    }

    Loader {
        id: familyWelcomeLoader
        active: WelcomeHost.wizard === root
        source: Plugins.ready ? Plugins.part(root.family, "welcome") : ""
    }

    Component.onCompleted: {
        WelcomeHost.wizard = root
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

    LazyLoader {
        active: WelcomeHost.wizard === root
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
                    onWidthChanged: root.cardWidth = width
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
                    visible: !frameLoader.active
                    anchors.fill: parent
                    surfaceDialect: "material"
                    elevation: 1
                    borderless: false
                    opaqueSurface: true
                    cardStyle: true
                    outlined: true
                    radiusOverride: root.welcomePanelRadius
                    clipContent: true

                }

                Loader {
                    id: frameLoader
                    anchors.fill: parent
                    active: !!root.familyWelcome?.frame
                    sourceComponent: root.familyWelcome?.frame ?? null
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.welcomeFrameInset
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
                                Loader {
                                    active: !!root.familyWelcome?.mark
                                    visible: active
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    sourceComponent: root.familyWelcome?.mark ?? null
                                }
                                MaterialSymbol {
                                    visible: !root.familyWelcome?.mark
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
                                        text: Translation.tr("Step %1 of %2").arg(root.currentStep + 1).arg(root.totalSteps)
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
                                onClicked: root.skipRest()

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
                                    font.pixelSize: root.welcomeHeadlineSize > 0 ? root.welcomeHeadlineSize
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

                                Item { WelcomeIntroPage { id: welcomePage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } ScrollEdgeFade { target: welcomePage; visible: welcomePage.contentHeight > welcomePage.height } }
                                Item {
                                    WelcomeFeaturesPage { id: featuresPage; visible: !root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                    Loader { id: familyPage0; active: root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; sourceComponent: root.familyWelcome?.pages?.[0] ?? null }
                                    ScrollEdgeFade { target: featuresPage; visible: !root.customSteps && target.contentHeight > target.height }
                                }
                                Item {
                                    WelcomeThemePage { id: themePage; visible: !root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                    Loader { id: familyPage1; active: root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; sourceComponent: root.familyWelcome?.pages?.[1] ?? null }
                                    ScrollEdgeFade { target: themePage; visible: !root.customSteps && target.contentHeight > target.height }
                                }
                                Item {
                                    WelcomeLayoutPage { id: layoutPage; visible: !root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom }
                                    Loader { id: familyPage2; active: root.customSteps; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; sourceComponent: root.familyWelcome?.pages?.[2] ?? null }
                                    ScrollEdgeFade { target: layoutPage; visible: !root.customSteps && target.contentHeight > target.height }
                                }
                                Item { WelcomeReadyPage { id: readyPage; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom } }
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
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STEP CONTENT COMPONENTS
    // ═══════════════════════════════════════════════════════════════════════

    // First-run choices use tonal selection like the established Material selectors:
    // the whole option changes mass/outline instead of repeating a decorative side rail.

}
