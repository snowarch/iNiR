pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    required property string outputName
    required property real availableWidth
    property int contextWorkspaceId: -1
    property var runtimeOrbitOptions: null
    property bool studioOpen: false
    property string filterText: ""
    readonly property bool pointerActive: shelfHover.hovered

    HoverHandler {
        id: shelfHover
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
    }

    // Shelf owns its pointer territory. Wheel gestures over controls or empty
    // shelf gaps must never leak into the spatial-stage workspace navigator.
    WheelHandler {
        target: null
        blocking: true
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => event.accepted = true
    }

    signal pocketRequested()
    signal studioRequested()

    readonly property var orbitOptions: runtimeOrbitOptions ?? Config.options?.orbit ?? {}
    readonly property var shelfOptions: orbitOptions.shelf ?? {}
    readonly property string layoutMode: ["bar", "islands", "minimal"].includes(shelfOptions.layout)
        ? shelfOptions.layout : "islands"
    readonly property string densityMode: ["comfortable", "compact", "huge"].includes(shelfOptions.density)
        ? shelfOptions.density : "comfortable"
    readonly property string labelMode: ["auto", "always", "icons"].includes(shelfOptions.labels)
        ? shelfOptions.labels : "auto"
    readonly property string islandStyle: ["material", "ricelin"].includes(shelfOptions.islandStyle)
        ? shelfOptions.islandStyle : "material"
    readonly property int moduleSpacing: Math.max(0, Math.min(16, shelfOptions.moduleSpacing ?? 7))
    readonly property int islandPadding: Math.max(6, Math.min(16, shelfOptions.islandPadding ?? 8))
    readonly property string hostBackdropBlurMode: {
        const configured = String(orbitOptions.backdropBlurMode ?? "")
        if (configured === "off") return "off"
        if (["shell", "inherit", "niri"].includes(configured)) return "shell"
        return (orbitOptions.backdropBlurEnable ?? true) ? "shell" : "off"
    }
    readonly property bool hostBackdropBlurActive: hostBackdropBlurMode === "shell"
        && Appearance.effectsEnabled
        && !GameMode.active
        && Math.max(0, Math.min(100, orbitOptions.backdropBlurStrength ?? 72)) > 0
    readonly property bool ricelinGlassEnabled: Config.options?.appearance?.island?.glass ?? true
    readonly property string trailScope: ["output", "workspace"].includes(shelfOptions.trailScope)
        ? shelfOptions.trailScope : "output"
    readonly property string locatorLabel: ["auto", "index", "name"].includes(shelfOptions.locatorLabel)
        ? shelfOptions.locatorLabel : "auto"
    readonly property string stageMode: GlobalStates.orbitStageOverride.length > 0
        ? GlobalStates.orbitStageOverride
        : orbitOptions.stageMode === "orbital" ? "orbital" : "stage"
    readonly property int itemLimit: Math.max(2, Math.min(8, orbitOptions.trailItems ?? 5))
    readonly property bool compact: availableWidth < 760
    readonly property bool labelsVisible: layoutMode !== "minimal" && labelMode !== "icons"
        && (labelMode === "always" || !compact)
    readonly property bool trailTitlesPersistent: layoutMode !== "minimal" && labelMode === "always"
    readonly property bool huge: densityMode === "huge"
    readonly property bool dense: !huge && (densityMode === "compact" || layoutMode === "minimal")
    readonly property int shelfHeight: huge ? 66 : layoutMode === "minimal" ? 40 : dense ? 44 : 50
    readonly property int groupHeight: huge ? 54 : layoutMode === "minimal" ? 34 : dense ? 36 : 40
    readonly property int toolSize: huge ? 44 : dense ? 30 : 32
    readonly property int toolbarIconSize: huge ? 28 : Appearance.regaliaEverywhere ? 18 : 22
    readonly property real groupRadius: groupHeight / 2
    readonly property bool ricelinSurface: islandStyle === "ricelin"
    readonly property int outerPadding: layoutMode === "bar" ? 6
        : layoutMode === "minimal" && ricelinSurface ? 4 : 0
    readonly property color foreground: Appearance.colors.colOnLayer1
    readonly property color mutedForeground: Appearance.colors.colSubtext
    readonly property var stashedIds: MinimizedWindows.getMinimizedForOutput(outputName)
    readonly property var outputWorkspaces: (NiriService.allWorkspaces ?? [])
        .filter(workspace => workspace.output === outputName && !root.isStashWorkspace(workspace.id))
        .sort((a, b) => a.idx - b.idx)
    readonly property var activeWorkspace: (contextWorkspaceId > 0
        ? outputWorkspaces.find(workspace => workspace.id === contextWorkspaceId)
        : null) ?? outputWorkspaces.find(workspace => workspace.is_active) ?? null
    readonly property int activeWindowCount: activeWorkspace
        ? (NiriService.windows ?? []).filter(window => window.workspace_id === activeWorkspace.id
            && !MinimizedWindows.isMinimized(window.id) && root.windowMatchesFilter(window)).length : 0
    readonly property var trailWindows: {
        const workspaceIds = root.trailScope === "workspace" && root.activeWorkspace
            ? new Set([root.activeWorkspace.id])
            : new Set(root.outputWorkspaces.map(workspace => workspace.id))
        const byId = {}
        for (const window of NiriService.windows ?? []) byId[window.id] = window
        const result = []
        for (const id of NiriService.mruWindowIds ?? []) {
            const window = byId[id]
            if (!window || !workspaceIds.has(window.workspace_id) || MinimizedWindows.isMinimized(id)
                    || !root.windowMatchesFilter(window)) continue
            result.push(window)
            if (result.length >= root.itemLimit) break
        }
        return result
    }
    readonly property string activeWorkspaceLabel: {
        if (!root.activeWorkspace)
            return Translation.tr("Workspace –")
        const name = (root.activeWorkspace.name ?? "").trim()
        if (root.locatorLabel === "name" && name.length > 0)
            return name
        if (root.locatorLabel === "auto" && name.length > 0)
            return `${root.activeWorkspace.idx} · ${name}`
        return Translation.tr("Workspace %1").arg(root.activeWorkspace.idx)
    }
    readonly property var pinnedActions: {
        const ids = Array.isArray(root.shelfOptions.pinnedActions)
            ? root.shelfOptions.pinnedActions : ["open-clipboard", "toggle-tiling", "toggle-dashboard"]
        const byId = {}
        for (const action of GlobalActions.allActions ?? []) byId[action.id] = action
        return ids.map(id => byId[id]).filter(action => action !== undefined).slice(0, 3)
    }
    readonly property var niriActions: {
        const allowed = ["focusLeft", "focusRight", "moveFirst", "moveLast", "maximize", "consume", "expel"]
        const source = Array.isArray(root.shelfOptions.niriActions)
            ? root.shelfOptions.niriActions : ["maximize", "consume", "expel"]
        const result = []
        for (const id of source) {
            if (allowed.includes(id) && !result.includes(id)) result.push(id)
        }
        return result
    }
    readonly property var moduleIds: {
        const defaults = ["locator", "trail", "niri", "actions", "stash"]
        const source = Array.isArray(root.shelfOptions.modules) ? root.shelfOptions.modules : defaults
        const result = []
        for (const id of source) {
            if (!defaults.includes(id) || result.includes(id)) continue
            if (id === "trail" && (!(root.orbitOptions.showTrail ?? true) || root.trailWindows.length === 0)) continue
            if (id === "stash" && (!(root.orbitOptions.showStash ?? true) || root.stashedIds.length === 0)) continue
            result.push(id)
        }
        return result
    }
    readonly property var keyboardEntries: {
        const result = []
        for (const moduleId of root.moduleIds) {
            if (moduleId === "trail") {
                for (const window of root.trailWindows)
                    result.push({ key: `trail:${window.id}`, kind: "trail", id: window.id })
            } else if (moduleId === "niri" && NiriService.actionReady) {
                for (const actionId of root.niriActions)
                    result.push({ key: `niri:${actionId}`, kind: "niri", id: actionId })
            } else if (moduleId === "actions") {
                for (const action of root.pinnedActions)
                    result.push({ key: `action:${action.id}`, kind: "action", id: action.id })
                result.push({ key: "action:palette", kind: "palette", id: "" })
            } else if (moduleId === "stash" && root.stashedIds.length > 0 && MinimizedWindows.actionReady) {
                const id = root.stashedIds[root.stashedIds.length - 1]
                result.push({ key: `stash:${id}`, kind: "stash", id })
            }
        }
        return result
    }

    property int keyboardIndex: -1
    readonly property bool hasKeyboardEntries: keyboardEntries.length > 0
    readonly property string keyboardKey: keyboardIndex >= 0 && keyboardIndex < keyboardEntries.length
        ? keyboardEntries[keyboardIndex].key : ""

    function isStashWorkspace(workspaceId): bool {
        const windows = (NiriService.windows ?? []).filter(window => window.workspace_id === workspaceId)
        return windows.length > 0 && windows.every(window => MinimizedWindows.isMinimized(window.id))
    }

    function windowMatchesFilter(windowData): bool {
        const query = root.filterText.trim().toLowerCase()
        if (query.length === 0)
            return true
        const title = String(windowData?.title ?? "").toLowerCase()
        const appId = String(windowData?.app_id ?? windowData?.appId ?? "").toLowerCase()
        return title.includes(query) || appId.includes(query)
    }

    function runNiriAction(actionId: string): void {
        if (actionId === "focusLeft") NiriService.focusColumnLeft()
        else if (actionId === "focusRight") NiriService.focusColumnRight()
        else if (actionId === "moveFirst") NiriService.moveColumnToFirst()
        else if (actionId === "moveLast") NiriService.moveColumnToLast()
        else if (actionId === "maximize") NiriService.maximizeColumn()
        else if (actionId === "consume") NiriService.consumeWindowIntoColumn()
        else if (actionId === "expel") NiriService.expelWindowFromColumn()
    }

    function niriActionMeta(actionId: string): var {
        switch (actionId) {
        case "focusLeft": return { icon: "arrow_back", label: Translation.tr("Focus column left") }
        case "focusRight": return { icon: "arrow_forward", label: Translation.tr("Focus column right") }
        case "moveFirst": return { icon: "first_page", label: Translation.tr("Move column to first") }
        case "moveLast": return { icon: "last_page", label: Translation.tr("Move column to last") }
        case "consume": return { icon: "merge_type", label: Translation.tr("Consume window into column") }
        case "expel": return { icon: "call_split", label: Translation.tr("Expel window from column") }
        default: return { icon: "open_in_full", label: Translation.tr("Maximize column") }
        }
    }

    function runPinnedAction(actionId: string): void {
        if (root.shelfOptions.closeOnAction ?? true) GlobalStates.closeOverview()
        GlobalActions.runById(actionId, "")
    }

    function openActionPalette(): void {
        GlobalStates.closeOverview()
        GlobalActions.runLauncher(["overview", "actionOpen"])
    }

    function focusFirstKeyboard(): void {
        keyboardIndex = root.hasKeyboardEntries ? 0 : -1
    }

    function focusLastKeyboard(): void {
        keyboardIndex = root.hasKeyboardEntries ? keyboardEntries.length - 1 : -1
    }

    function focusNextKeyboard(): void {
        if (!root.hasKeyboardEntries) return
        keyboardIndex = keyboardIndex < 0 ? 0 : (keyboardIndex + 1) % keyboardEntries.length
    }

    function focusPreviousKeyboard(): void {
        if (!root.hasKeyboardEntries) return
        keyboardIndex = keyboardIndex < 0 ? keyboardEntries.length - 1
            : (keyboardIndex - 1 + keyboardEntries.length) % keyboardEntries.length
    }

    function clearKeyboardSelection(): void {
        keyboardIndex = -1
    }

    function activateKeyboard(): void {
        if (!root.hasKeyboardEntries) return
        if (keyboardIndex < 0 || keyboardIndex >= keyboardEntries.length) keyboardIndex = 0
        const entry = keyboardEntries[keyboardIndex]
        if (entry.kind === "trail") {
            NiriService.focusWindow(entry.id)
            if (root.orbitOptions.closeOnSelect ?? true) GlobalStates.closeOverview()
        } else if (entry.kind === "niri") {
            root.runNiriAction(entry.id)
        } else if (entry.kind === "action") {
            root.runPinnedAction(entry.id)
        } else if (entry.kind === "palette") {
            root.openActionPalette()
        } else if (entry.kind === "stash") {
            root.pocketRequested()
        }
    }

    width: Math.max(0, Math.floor(Math.min(availableWidth,
        shelfRow.implicitWidth + outerPadding * 2) / 2) * 2)
    implicitWidth: width
    implicitHeight: shelfHeight

    PanelSurface {
        anchors.fill: parent
        visible: root.layoutMode === "bar" || (root.layoutMode === "minimal" && root.ricelinSurface)
        elevation: 1
        cardStyle: !root.ricelinSurface
        outlined: true
        islandSkin: root.ricelinSurface
        surfaceDialect: root.ricelinSurface ? "island" : ""
        radiusOverride: root.ricelinSurface
            ? Math.min(height / 2, Config.options?.appearance?.island?.radius ?? height / 2)
            : height / 2
        wallpaperBackdrop: root.ricelinSurface && !root.hostBackdropBlurActive && root.ricelinGlassEnabled
    }

    RowLayout {
        id: shelfRow
        anchors.centerIn: parent
        width: Math.min(Math.max(0, root.width - root.outerPadding * 2),
            Math.ceil(implicitWidth / 2) * 2)
        height: root.groupHeight
        spacing: root.layoutMode === "islands" ? root.moduleSpacing
            : root.layoutMode === "minimal" ? Math.min(root.moduleSpacing, 4)
            : Math.min(root.moduleSpacing, 6)

        Repeater {
            model: root.moduleIds

            delegate: RowLayout {
                id: moduleDelegate
                required property string modelData
                readonly property int horizontalInset: root.layoutMode === "islands"
                    ? root.islandPadding + (modelData === "locator" ? 4 : 0)
                    : root.layoutMode === "bar" ? 4 : 0
                Layout.fillWidth: false
                Layout.preferredWidth: Math.ceil(moduleSurface.implicitWidth / 2) * 2
                Layout.preferredHeight: root.groupHeight
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                PanelSurface {
                    id: moduleSurface
                    Layout.fillWidth: false
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: root.groupHeight
                    implicitWidth: Math.ceil((moduleLoader.implicitWidth
                        + moduleDelegate.horizontalInset * 2) / 2) * 2
                    implicitHeight: root.groupHeight
                    borderless: root.layoutMode !== "islands"
                    islandSkin: root.layoutMode === "islands" && root.ricelinSurface
                    surfaceDialect: root.layoutMode === "islands" && root.ricelinSurface
                        ? "island" : ""
                    cardStyle: root.layoutMode === "islands" && !root.ricelinSurface
                    radiusOverride: root.layoutMode === "islands" && root.ricelinSurface
                        ? Math.min(root.groupRadius,
                            Config.options?.appearance?.island?.radius ?? root.groupRadius)
                        : -1
                    elevation: 1
                    outlined: root.layoutMode === "islands"
                    wallpaperBackdrop: root.layoutMode === "islands" && !root.hostBackdropBlurActive
                        && (root.ricelinSurface
                            ? root.ricelinGlassEnabled : Appearance.auroraEverywhere)

                    Loader {
                        id: moduleLoader
                        width: Math.ceil(implicitWidth)
                        height: Math.ceil(implicitHeight)
                        x: Math.round((parent.width - width) / 2)
                        y: Math.round((parent.height - height) / 2)
                        sourceComponent: moduleDelegate.modelData === "locator" ? locatorComponent
                            : moduleDelegate.modelData === "trail" ? trailComponent
                            : moduleDelegate.modelData === "niri" ? niriComponent
                            : moduleDelegate.modelData === "actions" ? actionsComponent
                            : moduleDelegate.modelData === "stash" ? stashComponent : null
                    }
                }
            }
        }
    }

    Component {
        id: locatorComponent

        RowLayout {
            spacing: 8

            RippleButton {
                id: stageModeButton
                Layout.preferredWidth: root.huge ? 44 : root.dense ? 30 : 32
                Layout.preferredHeight: width
                buttonRadius: width / 2
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                rippleEnabled: false
                stateTransitionsEnabled: false
                pressScaleEnabled: false
                onClicked: GlobalStates.toggleOrbitStageView()

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "orbit"
                    iconSize: root.huge ? 26 : root.dense ? 17 : 18
                    textRenderType: Text.QtRendering
                    color: Appearance.colors.colOnPrimaryContainer
                }

                M3ToolTip {
                    text: root.stageMode === "orbital"
                        ? Translation.tr("Switch to Stage") : Translation.tr("Switch to Orbital")
                    extraVisibleCondition: stageModeButton.buttonHovered
                    alternativeVisibleCondition: extraVisibleCondition
                }
            }

            ColumnLayout {
                visible: root.labelsVisible
                spacing: -1

                StyledText {
                    text: root.activeWorkspaceLabel
                    renderType: Text.QtRendering
                    font.pixelSize: root.huge
                        ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
                    font.hintingPreference: Font.PreferNoHinting
                    font.weight: Font.DemiBold
                    color: root.foreground
                }
                StyledText {
                    text: {
                        const countText = root.activeWindowCount === 1
                            ? Translation.tr("1 window")
                            : Translation.tr("%1 windows").arg(root.activeWindowCount)
                        return root.stageMode === "orbital"
                            ? Translation.tr("Core · %1").arg(countText) : countText
                    }
                    renderType: Text.QtRendering
                    font.pixelSize: root.huge
                        ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                    font.hintingPreference: Font.PreferNoHinting
                    color: root.mutedForeground
                }
            }

            IconToolbarButton {
                id: studioButton
                visible: root.shelfOptions.showStudioButton ?? true
                implicitWidth: root.toolSize
                implicitHeight: root.toolSize
                iconSize: root.toolbarIconSize
                iconRenderType: Text.QtRendering
                text: "tune"
                toggled: root.studioOpen
                colText: toggled ? Appearance.colors.colOnPrimaryContainer : root.mutedForeground
                rippleEnabled: false
                stateTransitionsEnabled: false
                pressScaleEnabled: false
                onClicked: root.studioRequested()

                M3ToolTip {
                    text: Translation.tr("Orbit Studio")
                    extraVisibleCondition: studioButton.buttonHovered
                    alternativeVisibleCondition: extraVisibleCondition
                }
            }
        }
    }

    Component {
        id: trailComponent

        Item {
            implicitWidth: trailRow.implicitWidth
            implicitHeight: root.groupHeight - (root.layoutMode === "islands" ? 10 : 4)
            clip: true

            RowLayout {
                id: trailRow
                anchors.fill: parent
                spacing: 4

                MaterialSymbol {
                    Layout.leftMargin: 2
                    visible: root.layoutMode !== "minimal"
                    text: "history"
                    iconSize: root.huge ? 24 : 17
                    textRenderType: Text.QtRendering
                    color: root.mutedForeground
                }

                Repeater {
                    model: root.trailWindows

                    RippleButton {
                        id: trailButton
                        required property var modelData
                        readonly property string keyboardId: `trail:${modelData.id}`
                        readonly property bool showTitle: root.trailTitlesPersistent
                        implicitWidth: showTitle
                            ? Math.min(126, Math.max(76, trailContent.implicitWidth + 16)) : 34
                        Layout.minimumWidth: 34
                        Layout.preferredWidth: implicitWidth
                        Layout.fillHeight: true
                        buttonRadius: height / 2
                        toggled: modelData.is_focused || root.keyboardKey === keyboardId
                        colBackground: modelData.is_focused
                            ? Appearance.colors.colPrimaryContainer : "transparent"
                        colBackgroundHover: modelData.is_focused
                            ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colSecondaryContainerHover
                        colBackgroundToggled: Appearance.colors.colPrimaryContainer
                        colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colSecondaryContainerActive
                        colRippleToggled: Appearance.colors.colPrimaryContainerActive
                        rippleEnabled: false
                        stateTransitionsEnabled: false
                        pressScaleEnabled: false
                        onClicked: {
                            NiriService.focusWindow(modelData.id)
                            if (root.orbitOptions.closeOnSelect ?? true) GlobalStates.closeOverview()
                        }

                        contentItem: RowLayout {
                            id: trailContent
                            anchors.fill: parent
                            anchors.leftMargin: root.labelsVisible ? 7 : 8
                            anchors.rightMargin: root.labelsVisible ? 7 : 8
                            spacing: 6

                            IconImage {
                                implicitSize: root.huge ? 28 : 20
                                source: AppSearch.getIconSource(trailButton.modelData.app_id || "")
                            }

                            StyledText {
                                visible: trailButton.showTitle
                                Layout.fillWidth: true
                                text: trailButton.modelData.title || trailButton.modelData.app_id || Translation.tr("Window")
                                renderType: Text.QtRendering
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.pixelSize: root.huge
                                    ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                                font.hintingPreference: Font.PreferNoHinting
                                color: trailButton.toggled
                                    ? Appearance.colors.colOnPrimaryContainer : root.foreground
                            }
                        }
                        M3ToolTip {
                            text: trailButton.modelData.title || trailButton.modelData.app_id || Translation.tr("Window")
                            extraVisibleCondition: trailButton.buttonHovered
                            alternativeVisibleCondition: extraVisibleCondition
                        }
                    }
                }
            }
        }
    }

    Component {
        id: niriComponent

        RowLayout {
            spacing: 2

            Repeater {
                model: root.niriActions

                IconToolbarButton {
                    id: niriButton
                    required property string modelData
                    readonly property var actionMeta: root.niriActionMeta(modelData)
                    implicitWidth: root.toolSize
                    implicitHeight: root.toolSize
                    iconSize: root.toolbarIconSize
                    iconRenderType: Text.QtRendering
                    text: actionMeta.icon
                    enabled: NiriService.actionReady
                    toggled: root.keyboardKey === `niri:${modelData}`
                    colText: toggled ? Appearance.colors.colOnPrimaryContainer : root.mutedForeground
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colBackgroundToggled: Appearance.colors.colPrimaryContainer
                    colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    rippleEnabled: false
                    stateTransitionsEnabled: false
                    pressScaleEnabled: false
                    onClicked: root.runNiriAction(modelData)
                    M3ToolTip {
                        text: niriButton.actionMeta.label
                        extraVisibleCondition: niriButton.buttonHovered
                        alternativeVisibleCondition: extraVisibleCondition
                    }
                }
            }
        }
    }

    Component {
        id: actionsComponent

        RowLayout {
            spacing: 2

            Repeater {
                model: root.pinnedActions

                IconToolbarButton {
                    id: pinnedActionButton
                    required property var modelData
                    implicitWidth: root.toolSize
                    implicitHeight: root.toolSize
                    iconSize: root.toolbarIconSize
                    iconRenderType: Text.QtRendering
                    text: modelData.icon || "bolt"
                    toggled: root.keyboardKey === `action:${modelData.id}`
                    colText: toggled ? Appearance.colors.colOnPrimaryContainer : root.mutedForeground
                    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                    colBackgroundToggled: Appearance.colors.colPrimaryContainer
                    colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colSecondaryContainerActive
                    rippleEnabled: false
                    stateTransitionsEnabled: false
                    pressScaleEnabled: false
                    onClicked: root.runPinnedAction(modelData.id)
                    M3ToolTip {
                        text: pinnedActionButton.modelData.name || pinnedActionButton.modelData.id
                        extraVisibleCondition: pinnedActionButton.buttonHovered
                        alternativeVisibleCondition: extraVisibleCondition
                    }
                }
            }

            IconToolbarButton {
                id: paletteButton
                implicitWidth: root.toolSize
                implicitHeight: root.toolSize
                iconSize: root.toolbarIconSize
                iconRenderType: Text.QtRendering
                text: "more_horiz"
                toggled: root.keyboardKey === "action:palette"
                colText: toggled ? Appearance.colors.colOnPrimaryContainer : root.mutedForeground
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colBackgroundToggled: Appearance.colors.colPrimaryContainer
                colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                rippleEnabled: false
                stateTransitionsEnabled: false
                pressScaleEnabled: false
                onClicked: root.openActionPalette()
                M3ToolTip {
                    text: Translation.tr("All actions")
                    extraVisibleCondition: paletteButton.buttonHovered
                    alternativeVisibleCondition: extraVisibleCondition
                }
            }
        }
    }

    Component {
        id: stashComponent

        RippleButton {
            id: stashButton
            readonly property int latestId: root.stashedIds.length > 0
                ? root.stashedIds[root.stashedIds.length - 1] : -1
            implicitWidth: root.huge ? (root.labelsVisible ? 76 : 44)
                : root.labelsVisible ? 64 : 40
            implicitHeight: root.huge ? root.toolSize
                : root.layoutMode === "minimal" ? 32 : 34
            enabled: MinimizedWindows.actionReady
            buttonRadius: height / 2
            toggled: latestId >= 0 && root.keyboardKey === `stash:${latestId}`
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colBackgroundToggled: Appearance.colors.colPrimaryContainer
            colBackgroundToggledHover: Appearance.colors.colPrimaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            colRippleToggled: Appearance.colors.colPrimaryContainerActive
            rippleEnabled: false
            stateTransitionsEnabled: false
            pressScaleEnabled: false
            onClicked: if (latestId >= 0) root.pocketRequested()

            contentItem: RowLayout {
                anchors.centerIn: parent
                spacing: 4
                MaterialSymbol {
                    text: "inventory_2"
                    iconSize: root.huge ? 24 : 18
                    textRenderType: Text.QtRendering
                    color: stashButton.toggled
                        ? Appearance.colors.colOnPrimaryContainer : root.mutedForeground
                }
                StyledText {
                    visible: root.labelsVisible
                    text: root.stashedIds.length.toString()
                    renderType: Text.QtRendering
                    font.pixelSize: root.huge
                        ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                    font.hintingPreference: Font.PreferNoHinting
                    font.weight: Font.DemiBold
                    color: stashButton.toggled
                        ? Appearance.colors.colOnPrimaryContainer : root.foreground
                }
            }
            M3ToolTip {
                text: latestId >= 0
                    ? Translation.tr("Open Pocket")
                    : Translation.tr("Stash")
                extraVisibleCondition: stashButton.buttonHovered
                alternativeVisibleCondition: extraVisibleCondition
            }
        }
    }
}
