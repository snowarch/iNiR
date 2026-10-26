pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.modules.common

// iRiS's own shell state: what its surfaces publish to each other and what its IPC asks of them. It travels with
// iRiS; the base never reads it.
Singleton {
    id: root

    property real levelQuietUntil: 0
    function quietLevels(): void { root.levelQuietUntil = Date.now() + 700 }

    // Screen-local geometry ({x, y, width, height, radius, screen}) of the
    // Island part that last opened a surface, so it can morph out of and back
    // into that exact shape. Transient coordination only; null means "no origin".
    property var morphOrigin: null
    // Who published that origin when it is not the Island (e.g. "left" for a
    // side panel's button). The Island leaves a foreign origin alone on open and
    // close; the morph surface clears it once it has fully collapsed.
    property string morphOwner: ""
    // Asks the focused Island to open a page ("media", "desktop", "activity",
    // "tray", "tools") from a surface that is not the Island (card, floating bubble).
    property string islandPageRequest: ""
    // A bubble's own card: { kind, x, y, width, height, radius, screen, source }
    // with the screen-local rect of the bubble it grows out of; `source` names
    // that bubble ("island-<slot>" or "float-<slot>") so it can hide meanwhile.
    property var bubbleCard: null
    // The Island's desktop page is being arranged in place (iRiS Studio).
    property bool arrange: false
    // The Dock's body per output, so the chassis field draws it in the same pass
    // as the frame and the Island instead of the Dock carrying a second surface.
    property var dockBody: ({})
    // Arranging the Control Center in place; closing the panel ends it.
    property bool controlEdit: false
    property string controlTab: "controls"
    // The lock screen rehearsal: the same surface, editable, with no PAM behind it.
    property bool lockEdit: false
    property string lockSelection: ""
    // The quick-controls tab `inir iris lock select:<key>/<tab>` asks the selected lock widget to show.
    property string lockWidgetTab: ""
    property string lockPage: "scene"
    // The lock rehearsal shown without its handles, asked for by `inir iris lock peek` (the eye is held instead).
    property bool lockPeek: false
    // iRiS is being edited in place: every piece is grabbable, the edit bar
    // holds the pieces, the look and the sizes, and Done ends it.
    property bool edit: false
    // What the edit bar is inspecting: a piece slot ("extra:vitals", "left",
    // "app:kitty"), a surface ("island", "dock", "cards"…) or "" for the family.
    property string editSelection: ""
    // A Studio target the edit bar should inspect ("" = keep what it shows).
    property string editTarget: ""
    property int chassisEpoch: 0
    onEditChanged: {
        if (!edit) { editSelection = ""; editTarget = "" }
        else if (GlobalStates.widgetEditMode) GlobalStates.setWidgetEditMode(false)
        if (edit && studioOpen) studioOpen = false
    }
    onEditSelectionChanged: if (editSelection.length > 0) editTarget = ""
    onEditTargetChanged: if (editTarget.length > 0) editSelection = ""
    // The in-place editors: leaving the family ends them, or they are destroyed open and come back open when it returns.
    function endEditing(): void {
        lockEdit = false
        edit = false
        controlEdit = false
    }
    onControlEditChanged: if (!controlEdit) controlTab = "controls"
    // iRiS Studio, the panel form of Customize, is open. It and Customize on the shell never show together.
    property bool studioOpen: false
    onStudioOpenChanged: if (studioOpen && edit) edit = false
    // Customize, in the form the person chose (iris.appearance.customize), on a target ("" = where it was).
    function openCustomize(target): void {
        const wanted = String(target ?? "")
        if (String(Config.options?.iris?.appearance?.customize ?? "shell") === "studio") {
            studioTarget = wanted
            studioOpen = true
        } else {
            editTarget = wanted
            edit = true
        }
    }
    // A target Studio should show when it opens or is already open ("" = keep).
    property string studioTarget: ""
    // Asks whichever bubble shows this kind (floating first, then the Island)
    // to open its card; IPC and keyboard paths use it.
    property string bubbleCardRequest: ""
    // A floating piece asked to open its own menu, by kind (IPC).
    property string bubbleMenuRequest: ""
    // A bubble being carried: { slot, kind, screen, x, y (screen-local centre),
    // size, released }. The bubble layer draws it and resolves the drop.
    property var bubbleDrag: null
    // Per output name: what each bubble slot shows ({ left, right, utility }) and
    // the resting Island's screen-local geometry, published by each Island.
    property var bubbleKinds: ({})
    property var islandGeometry: ({})
    // The open Island's width per output (0 at rest): the geometry above is only written at rest.
    property var islandOpenWidth: ({})
    // Per output: pieces an edge owner carries instead of floating over it ({ island: [...], dock: [...] }).
    property var absorbed: ({})
    // The last place iRiS Settings was asked for: an instance built after another one took the request lands there too.
    property var settingsLastRequest: null
    // iRiS side panel ("left"/"right") that was revealed by resting at its screen
    // edge: it closes when the pointer leaves until a press inside commits it.
    property string sidebarPeek: ""
    // iRiS Dock held on screen by IPC (`inir iris dock show`) until hidden again
    // or an app is chosen from it.
    property bool dockShown: false
    // Opens an app's windows or menu on the focused Dock: { appId, mode: "windows" | "menu" }.
    property var dockMenuRequest: null
    property var dockSlide: null
    property var dockHome: null
    // A query for Spotlight to type as it opens (IPC); taken and cleared by the palette.
    property string spotlightQuery: ""
    // Orbit: Niri's workspaces and windows as a place to find and go. `orbitQuery` is what it types as it opens.
    property bool orbitOpen: false
    property string orbitQuery: ""
    // The output Orbit opened on when a hot corner asked for one; empty means the focused output. It stays put until the
    // next open, so a leaving Orbit is not pulled to another output.
    property string orbitOutput: ""
    property bool _orbitOutputAsked: false
    // The corner each output's Orbit hot corner is on right now ("" = none), published by the corner itself.
    property var orbitCorners: ({})
    function openOrbit(outputName: string): void {
        orbitOutput = outputName
        _orbitOutputAsked = true
        orbitOpen = true
    }
    onOrbitOpenChanged: {
        if (!orbitOpen) return
        if (!_orbitOutputAsked) orbitOutput = ""
        _orbitOutputAsked = false
        GlobalStates.searchOpen = false
        GlobalStates.wallpaperSelectorOpen = false
        GlobalStates.wallpaperLauncherOpen = false
    }
    // Whether any output's Island is expanded, published for `inir iris status`.
    property bool islandExpanded: false
    property string islandShape: ""
    property string controlPickerRequest: ""
    property string islandPage: ""

    // What the base opens closes iRiS's own: Orbit gives way to the search and the wallpaper pickers, the Control
    // Center's arranging ends with the panel, Customize with the desktop widget editor.
    Connections {
        target: GlobalStates
        function onSearchOpenChanged(): void { if (GlobalStates.searchOpen) root.orbitOpen = false }
        function onWallpaperSelectorOpenChanged(): void { if (GlobalStates.wallpaperSelectorOpen) root.orbitOpen = false }
        function onWallpaperLauncherOpenChanged(): void { if (GlobalStates.wallpaperLauncherOpen) root.orbitOpen = false }
        function onControlPanelOpenChanged(): void { if (!GlobalStates.controlPanelOpen) root.controlEdit = false }
        function onWidgetEditModeChanged(): void { if (GlobalStates.widgetEditMode) root.edit = false }
    }

    // The lock shows seconds while it is rehearsed unlocked, so the clock ticks each second meanwhile.
    Binding {
        target: GlobalStates
        property: "clockShowsSeconds"
        value: root.lockEdit && (Config.options?.iris?.lock?.type?.seconds ?? false)
    }
}
