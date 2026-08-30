pragma ComponentBehavior: Bound

import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.services
import qs.modules.settings
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

/**
 * Settings UI as a drill-down layer shell overlay.
 *
 * Third presentation of the shared settings tree, alongside the nav-rail
 * window (settings.qml) and the nav-rail overlay (SettingsOverlay.qml). Both
 * of those keep a persistent rail beside a narrowed content pane; this one
 * shows one thing at a time — a home grid of every page, then the selected
 * page full-bleed with a back affordance. Pages, categories and the search
 * index all come from SettingsPageRegistry, so no page is duplicated here.
 *
 * Loaded by the main shell when settingsUi.overlayMode is true and
 * settingsUi.overlayStyle is "focus".
 */
Scope {
    id: root

    property bool settingsOpen: GlobalStates.settingsOverlayOpen ?? false

    // Keep the PanelWindow alive briefly after close so the scrim can fade
    // out. Mirrors SettingsOverlay: without it the Loader tears down the
    // instant settingsOpen flips and the backdrop cuts to black.
    property bool _panelLoaded: settingsOpen || _closeAnimRunning
    property bool _closeAnimRunning: false

    // 0 = home grid, 1 = single page
    property int level: 0
    property int currentPage: -1

    readonly property bool easyMode: Config.options?.settingsUi?.easyMode ?? false

    // Component paths are registry-relative; resolve to absolute shell URLs
    // so the host's Loaders work regardless of where this file lives.
    readonly property var pages: SettingsPageRegistry.pages.map(p => {
        var entry = Object.assign({}, p);
        entry.component = Quickshell.shellPath(p.component);
        return entry;
    })

    readonly property var currentMeta: (currentPage >= 0 && currentPage < pages.length)
        ? pages[currentPage] : ({})

    onSettingsOpenChanged: {
        if (settingsOpen) {
            _closeAnimRunning = false;
            closeAnimTimer.stop();
            root.clearSearch();
            const requested = GlobalStates.settingsOverlayRequestedPage ?? -1;
            if (requested >= 0 && requested < root.pages.length) {
                root.openPage(requested);
                GlobalStates.settingsOverlayRequestedPage = -1;
            } else {
                root.level = 0;
            }
        } else {
            _closeAnimRunning = true;
            closeAnimTimer.restart();
        }
    }

    Timer {
        id: closeAnimTimer
        interval: Appearance.animation.elementMoveFast.duration + 40
        repeat: false
        onTriggered: root._closeAnimRunning = false
    }

    function openPage(index: int): void {
        if (index < 0 || index >= root.pages.length)
            return;
        root.currentPage = index;
        root.level = 1;
    }

    function goHome(): void {
        root.level = 0;
    }

    function setEasyMode(enabled: bool): void {
        Config.setNestedValue("settingsUi.easyMode", enabled === true);
    }

    // Switch chrome without going hunting for the option that controls it.
    // "focus" and "rail" swap the two overlay loaders in shell.qml, which are
    // bound to these keys; "window" retires the overlay and hands off to the
    // standalone process, so the panel must close before the window appears.
    function setLayout(mode: string): void {
        if (mode === "window") {
            Config.setNestedValue("settingsUi.overlayMode", false);
            GlobalStates.settingsOverlayOpen = false;
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings-window"]);
            return;
        }
        Config.setNestedValues({
            "settingsUi.overlayMode": true,
            "settingsUi.overlayStyle": mode
        });
    }

    // ── Home grid model: categories that still have visible pages ──
    readonly property var visibleGroups: {
        var groups = [];
        var cats = SettingsPageRegistry.categories;
        for (var c = 0; c < cats.length; c++) {
            var cat = cats[c];
            var entries = [];
            for (var p = 0; p < cat.pages.length; p++) {
                var idx = cat.pages[p];
                if (idx < 0 || idx >= pages.length)
                    continue;
                if (easyMode && pages[idx].essential !== true)
                    continue;
                var entry = Object.assign({}, pages[idx]);
                entry.realIndex = idx;
                // Carried on the model on purpose: a nested Repeater delegate
                // reading the outer delegate's required `index` crosses a
                // Component boundary and can fail to construct silently.
                entry.groupIndex = groups.length;
                entries.push(entry);
            }
            if (entries.length === 0)
                continue;
            groups.push({ label: cat.label, entries: entries });
        }
        return groups;
    }

    // The category the open page belongs to. Drilling into a page otherwise cut
    // every sibling loose: the only way to reach the next page in the same
    // category was to walk back out to the grid and in again.
    readonly property var currentGroup: {
        if (root.currentPage < 0)
            return null;
        const groups = root.visibleGroups;
        for (let g = 0; g < groups.length; g++) {
            const entries = groups[g].entries;
            for (let e = 0; e < entries.length; e++) {
                if (entries[e].realIndex === root.currentPage)
                    return groups[g];
            }
        }
        return null;
    }

    // Each category gets its own medallion silhouette so groups are told apart
    // by shape, not just by a small uppercase label. Cycles rather than mapping
    // by name because categories are user-rearrangeable via settingsUi.categories.
    // zzz keeps Square: its doctrine has no organic shapes, and
    // MaterialShapeWrappedMaterialSymbol already squares itself for that style.
    readonly property var _groupShapes: [
        MaterialShape.Shape.Clover4Leaf,
        MaterialShape.Shape.Cookie7Sided,
        MaterialShape.Shape.SoftBurst,
        MaterialShape.Shape.Gem,
        MaterialShape.Shape.Flower,
        MaterialShape.Shape.Cookie6Sided
    ]

    // Return type is required: without it Qt treats the return as void and logs
    // "should be coerced to void" for every shape value on every tile repaint.
    function _shapeForGroup(index: int): int {
        if (Appearance.zzzEverywhere)
            return MaterialShape.Shape.Square;
        return root._groupShapes[index % root._groupShapes.length];
    }

    // Bounce off a page that easy mode just hid
    onEasyModeChanged: {
        if (easyMode && currentPage >= 0 && pages[currentPage]?.essential !== true)
            goHome();
        if (searchText.length > 0)
            recomputeSearch();
    }

    // ── Search ──
    property string searchText: ""
    property var searchResults: []

    function clearSearch(): void {
        root.searchText = "";
        root.searchResults = [];
        root._pendingOptionId = -1;
        root._pendingPageIndex = -1;
        root._pendingSection = "";
        root._spotlightRetries = 0;
        spotlightTimer.stop();
    }

    function recomputeSearch(): void {
        var q = String(root.searchText || "").toLowerCase().trim();
        if (!q.length) {
            root.searchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var isWaffle = Config.options?.panelFamily === "waffle";
        var wafflePage = SettingsPageRegistry.pages.findIndex(
            p => String(p.component || "").indexOf("WaffleConfig.qml") >= 0);
        var results = [];

        function allowed(pageIndex) {
            if (pageIndex < 0 || pageIndex >= root.pages.length)
                return false;
            if (wafflePage >= 0 && pageIndex === wafflePage && !isWaffle)
                return false;
            if (root.easyMode && root.pages[pageIndex].essential !== true)
                return false;
            return true;
        }

        // Static section index — coarse targets, ranked below real controls.
        var index = SettingsPageRegistry.searchIndex();
        for (var i = 0; i < index.length; i++) {
            var e = index[i];
            if (!allowed(e.pageIndex))
                continue;

            var haystack = [e.label, e.description, e.pageName, e.section,
                (e.keywords || []).join(" ")].join(" ").toLowerCase();
            var matched = terms.every(t => haystack.indexOf(t) >= 0);
            if (!matched)
                continue;

            var label = String(e.label || "").toLowerCase();
            var score = 500;
            for (var t = 0; t < terms.length; t++) {
                if (label.indexOf(terms[t]) === 0)
                    score += 800;
                else if (label.indexOf(terms[t]) > 0)
                    score += 400;
            }

            results.push({
                pageIndex: e.pageIndex,
                pageName: e.pageName,
                section: e.section,
                label: e.label,
                labelHighlighted: SettingsSearchRegistry.highlightTerms(e.label, terms),
                description: e.description,
                score: score,
                isSection: true
            });
        }

        // Live control registry — the precise targets, so they outrank sections.
        if (typeof SettingsSearchRegistry !== "undefined") {
            var live = SettingsSearchRegistry.buildResults(root.searchText)
                .filter(r => allowed(r.pageIndex));
            for (var w = 0; w < live.length; w++)
                live[w].score = (live[w].score || 0) + 2000;
            results = results.concat(live);
        }

        results.sort((a, b) => b.score - a.score);

        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var r = results[k];
            var key = String(r.pageIndex) + "|" + String(r.label || "").toLowerCase();
            if (seen[key] === undefined) {
                seen[key] = unique.length;
                unique.push(r);
            } else if (r.optionId !== undefined && unique[seen[key]].optionId === undefined) {
                unique[seen[key]] = r;
            }
        }

        root.searchResults = unique.slice(0, 40);
    }

    // ── Spotlight: land on the page, then scroll the matched control in ──
    property int _pendingOptionId: -1
    property int _pendingPageIndex: -1
    property string _pendingSection: ""
    property int _spotlightRetries: 0
    readonly property int _spotlightMaxRetries: 15

    function openSearchResult(entry): void {
        root.searchText = "";
        root.searchResults = [];
        root._spotlightRetries = 0;

        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) {
            root._pendingOptionId = -1;
            root._pendingPageIndex = -1;
            root._pendingSection = "";
            return;
        }

        root._pendingOptionId = (entry.optionId !== undefined) ? entry.optionId : -1;
        root._pendingPageIndex = entry.pageIndex;
        root._pendingSection = (root._pendingOptionId < 0 && entry.section)
            ? String(entry.section) : "";
        root.openPage(entry.pageIndex);

        if (root._pendingOptionId >= 0 || root._pendingSection.length > 0)
            spotlightTimer.restart();
        else
            root._pendingPageIndex = -1;
    }

    Timer {
        id: spotlightTimer
        interval: 150
        onTriggered: root._trySpotlight()
    }

    function _trySpotlight(): void {
        if (root._pendingOptionId < 0 && root._pendingSection.length === 0)
            return;

        const pageItem = pageHost.currentItem
        if (pageItem && pageHost.currentIndex === root._pendingPageIndex
                && root._pendingSection.length > 0
                && typeof pageItem.activateSettingsSearchSection === "function")
            pageItem.activateSettingsSearchSection(root._pendingSection)

        var control = root._pendingOptionId >= 0
            ? SettingsSearchRegistry.getControlById(root._pendingOptionId)
            : SettingsSearchRegistry.findSectionControl(root._pendingPageIndex, root._pendingSection);
        if (!control) {
            if (root._spotlightRetries < root._spotlightMaxRetries) {
                root._spotlightRetries++;
                spotlightTimer.restart();
            } else {
                root._pendingOptionId = -1;
                root._pendingPageIndex = -1;
                root._pendingSection = "";
            }
            return;
        }

        SettingsSearchRegistry.activateTaskSectionForControl(control);
        SettingsSearchRegistry.expandSectionForControl(control);

        var flick = root._findParentFlickable(control);
        if (flick) {
            var posInContent = control.mapToItem(flick.contentItem, 0, 0);
            var target = posInContent.y - (flick.height / 2) + (control.height / 2);
            flick.contentY = Math.max(0, Math.min(target,
                Math.max(0, flick.contentHeight - flick.height)));
        }

        root._pendingOptionId = -1;
        root._pendingPageIndex = -1;
        root._pendingSection = "";
    }

    function _findParentFlickable(item): var {
        var p = item ? item.parent : null;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentHeight")
                    && p.hasOwnProperty("contentItem"))
                return p;
            p = p.parent;
        }
        return null;
    }

    // settingsNav is owned by shell.qml — see the comment there. This host only
    // publishes where it is and honours a requested page, so the target stays
    // valid whichever chrome is loaded.
    onLevelChanged: GlobalStates.settingsOverlayCurrentPage =
        root.level === 1 ? root.currentPage : -1
    onCurrentPageChanged: {
        if (root.level === 1)
            GlobalStates.settingsOverlayCurrentPage = root.currentPage;
    }

    Connections {
        target: GlobalStates
        // Also fires while the panel is already open, which is how
        // `settingsNav page` navigates instead of only picking the landing page.
        function onSettingsOverlayRequestedPageChanged() {
            const requested = GlobalStates.settingsOverlayRequestedPage ?? -1;
            if (requested < 0 || !root.settingsOpen)
                return;
            root.openPage(requested);
            GlobalStates.settingsOverlayRequestedPage = -1;
        }
    }

    Loader {
        active: root._panelLoaded

        sourceComponent: PanelWindow {
            id: settingsPanel

            visible: root.settingsOpen || root._closeAnimRunning
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:settingsFocus"
            WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen
                ? WlrLayer.Bottom : WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.settingsOpen
                && !GlobalStates.regionSelectorOpen
                && !GlobalStates.settingsNativeDialogOpen
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Blurred backdrop, using the same GlassBackground every other panel
            // in the shell already paints — one shared wallpaper decode, layer
            // released while hidden. Strength drives its blur radius, 0 keeps the
            // surface out of the tree entirely.
            readonly property int backdropBlur:
                Config.options?.settingsUi?.overlayAppearance?.backdropBlur ?? 0

            Loader {
                anchors.fill: parent
                z: -1
                active: settingsPanel.backdropBlur > 0 && Appearance.effectsEnabled
                visible: active && (GlobalStates.settingsOverlayOpen ?? false)

                sourceComponent: GlassBackground {
                    anchors.fill: parent
                    radius: 0
                    // The style gate lives in blurBackendFor and answers "should
                    // this panel's material be glass". This is a backdrop the user
                    // asked for explicitly, so it must paint under every style.
                    forceBackdrop: true
                    blurStrength: settingsPanel.backdropBlur / 100
                    screenX: 0
                    screenY: 0
                    screenWidth: settingsPanel.width
                    screenHeight: settingsPanel.height
                    fallbackColor: "transparent"
                    auroraTransparency: 0.35

                    opacity: (GlobalStates.settingsOverlayOpen ?? false) ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }

            // Escape unwinds one layer at a time: search, then page, then close.
            Shortcut {
                sequences: ["Escape"]
                onActivated: {
                    if (root.searchText.length > 0)
                        root.clearSearch();
                    else if (root.level === 1)
                        root.goHome();
                    else
                        GlobalStates.settingsOverlayOpen = false;
                }
            }

            Shortcut {
                sequences: ["Ctrl+F"]
                context: Qt.WindowShortcut
                onActivated: focusSearchField.forceActiveFocus()
            }

            // Alt+Left only. Backspace was bound here too, but a Shortcut is
            // resolved at window level before the focused item sees the key, so
            // one press inside any page text field — an API key, a city, a
            // wallpaper path — navigated home and threw the entry away instead
            // of deleting a character. Guarding on the search field alone did
            // not cover the pages. Escape already steps back a level.
            Shortcut {
                sequences: ["Alt+Left"]
                context: Qt.WindowShortcut
                onActivated: if (root.level === 1) root.goHome()
            }

            // Type-to-search. The home grid has no other keyboard entry point,
            // so the field takes focus on the open edge — and hands it back when
            // a page opens, or the page's own controls would never see a key.
            function focusSearchOnHome(): void {
                if (root.settingsOpen && root.level === 0)
                    focusSearchField.forceActiveFocus();
            }

            Component.onCompleted: Qt.callLater(settingsPanel.focusSearchOnHome)

            Connections {
                target: root

                function onSettingsOpenChanged() {
                    Qt.callLater(settingsPanel.focusSearchOnHome);
                }

                function onLevelChanged() {
                    if (root.level === 0)
                        Qt.callLater(settingsPanel.focusSearchOnHome);
                    else
                        focusSearchField.focus = false;
                }

                // Typing into a TextInput replaces its `text` binding, so once the
                // user has touched the field a query set from outside — the IPC,
                // or clearSearch on reopen — would never reach it again.
                function onSearchTextChanged() {
                    if (focusSearchField.text !== root.searchText)
                        focusSearchField.text = root.searchText;
                }
            }

            CompositorFocusGrab {
                id: grab
                windows: [settingsPanel]
                active: false
                onCleared: () => {
                    if (!active && !GlobalStates.settingsNativeDialogOpen)
                        GlobalStates.settingsOverlayOpen = false;
                }
            }

            Connections {
                target: GlobalStates
                function onSettingsOverlayOpenChanged() { grabTimer.restart() }
                function onSettingsNativeDialogOpenChanged() { grabTimer.restart() }
            }

            Timer {
                id: grabTimer
                interval: 100
                onTriggered: grab.active = (GlobalStates.settingsOverlayOpen ?? false)
                    && !GlobalStates.settingsNativeDialogOpen
            }

            // ── Scrim ──
            Rectangle {
                id: scrimBg
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: (GlobalStates.settingsOverlayOpen ?? false)
                    ? (Config.options?.settingsUi?.overlayAppearance?.scrimDim ?? 35) / 100 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }

            // Sibling of the scrim on purpose: scrimBg goes invisible at
            // scrimDim 0, and QtQuick excludes invisible subtrees from hit
            // testing — nesting this would silently kill click-outside.
            MouseArea {
                anchors.fill: parent
                visible: GlobalStates.settingsOverlayOpen ?? false
                enabled: !GlobalStates.settingsNativeDialogOpen
                onClicked: GlobalStates.settingsOverlayOpen = false
            }

            // ── Card ──
            Rectangle {
                id: card

                // Same legibility clamp as the rail host — see SettingsOverlay.
                readonly property real panelBgOpacity: Math.max(0.6,
                    Config.options?.settingsUi?.overlayAppearance?.backgroundOpacity ?? 1.0)

                anchors.centerIn: parent
                width: Math.min(1040, Math.max(780, settingsPanel.width * 0.66))
                height: Math.min(840, Math.max(600, settingsPanel.height * 0.82))
                radius: Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
                      : Appearance.regaliaEverywhere ? Appearance.regalia.panelRadius
                      : Appearance.angelEverywhere ? Appearance.angel.roundingLarge
                      : Appearance.inirEverywhere ? Appearance.inir.roundingLarge
                      : Appearance.rounding.windowRounding
                // Same contract as the rail overlay: backgroundOpacity lands on
                // the fill alpha (solid) or the blur transparentize (glass),
                // never on Item opacity, which children inherit.
                color: Appearance.auroraEverywhere || Appearance.regaliaEverywhere ? "transparent"
                     : CF.ColorUtils.applyAlpha(
                         Appearance.inirEverywhere ? Appearance.inir.colLayer0
                       : Appearance.zzzEverywhere ? Appearance.zzz.chrome
                       : Appearance.colors.colLayer0Base,
                         card.panelBgOpacity)
                // angel's panel tokens, not its card tokens: this rectangle is
                // the panel now that the body carries its own plate, and the
                // rail host draws the equivalent surface the same way.
                border.width: Appearance.angelEverywhere ? Appearance.angel.panelBorderWidth
                            : Appearance.zzzEverywhere ? Appearance.zzz.borderThick
                            : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colPanelBorder
                            : Appearance.zzzEverywhere ? Appearance.zzz.hairline
                            : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                            : "transparent"
                clip: true

                // Switching global style while the panel is open otherwise
                // repaints the whole chrome in one frame. Same transitions the
                // rail host uses, so both settings surfaces morph identically.
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on border.width {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                Behavior on border.color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                // Opacity-only show/hide, matching the rail overlay: a scale fade
                // was tried there and rejected as heavy. This binding is the
                // open/close transition, not the background setting.
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? 1 : 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                RegaliaPlate {
                    anchors.fill: parent
                    z: -1
                    visible: Appearance.regaliaEverywhere
                    fillColor: CF.ColorUtils.applyAlpha(Appearance.regalia.bg0,
                        card.panelBgOpacity)
                    radius: card.radius
                    inset: Appearance.regalia.panelInset
                    elevated: true
                    glassEnabled: true
                }

                GlassBackground {
                    anchors.fill: parent
                    z: -1
                    radius: card.radius
                    visible: Appearance.auroraEverywhere && !Appearance.inirEverywhere
                    screenX: card.x
                    screenY: card.y
                    screenWidth: settingsPanel.width
                    screenHeight: settingsPanel.height
                    hovered: false
                    // GameMode suspends the wallpaper blur backend, and aurora's
                    // own fill is transparent — a transparent fallback would make
                    // the whole panel vanish over a fullscreen window.
                    fallbackColor: Appearance.effectsEnabled
                        ? "transparent" : Appearance.colors.colLayer0Base
                    inirColor: Appearance.inir.colLayer0
                    auroraTransparency: {
                        const base = Appearance.angelEverywhere
                            ? Appearance.angel.panelTransparentize
                            : Appearance.aurora.overlayTransparentize
                        return base + (1 - base) * (1 - card.panelBgOpacity)
                    }
                }

                // zzz owns its panel identity through the backdrop, not through
                // the fill alone. Without it the focus host was the one surface
                // where the style lost its console framing — the rail host has
                // carried this since it shipped.
                ZzzPanelBackdrop {
                    anchors.fill: parent
                    z: -1
                    visible: Appearance.zzzEverywhere
                    label: Translation.tr("User manual")
                    index: "UI"
                    ghostText: "CONFIG"
                    accentColor: Appearance.zzz.accent
                    showTicks: false
                    showBurst: false
                    showGrid: false
                    horizontalBias: 0.12
                    verticalBias: 0.03
                    ghostWidthFactor: 0.88
                    ghostStrength: 0.5
                }

                // ── Header ──
                // A card like every other surface on this panel, not a bare strip
                // over the panel background. Left as a strip it read as text
                // floating on the wallpaper, visually detached from the content
                // below — the panel is translucent, and the header was the only
                // region with nothing sitting on it.
                Rectangle {
                    id: header

                    // The banner and the identity belong to the home screen. On a
                    // page the header collapses to a plain toolbar so the page
                    // keeps the height, and the same row simply slides up.
                    readonly property bool identityShown: root.level === 0
                    readonly property real bannerHeight: identityShown ? 58 : 0
                    readonly property real avatarSize: 44
                    readonly property real toolbarHeight: 56

                    readonly property string accountLine: {
                        const user = SystemInfo.username || "user";
                        const distro = (SystemInfo.distroId ?? "").trim();
                        const account = (distro.length > 0 && distro !== "unknown")
                            ? `${user}@${distro}` : user;
                        return `${account} · ${Translation.tr("Up %1").arg(DateTime.uptime)}`;
                    }

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        topMargin: 12
                        leftMargin: 16
                        rightMargin: 16
                    }
                    height: bannerHeight + toolbarHeight
                    radius: SettingsMaterialPreset.cardRadius
                    color: Appearance.zzzEverywhere
                        ? "transparent" : SettingsMaterialPreset.cardColor
                    border.width: Appearance.regaliaEverywhere || Appearance.angelEverywhere || Appearance.zzzEverywhere ? 0 : 1
                    border.color: SettingsMaterialPreset.cardBorderColor
                    clip: true

                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }

                    ZzzPlate {
                        anchors.fill: parent
                        visible: Appearance.zzzEverywhere
                        fillColor: Appearance.zzz.bg1
                        strokeColor: Appearance.zzz.hairline
                        strokeWidth: Appearance.zzz.hairlineThick
                        chamfer: Appearance.zzz.cutCorner
                        z: -1
                    }

                    // ── Banner ──
                    // Static wallpaper only. The sidebar's header can also play a
                    // GIF or video banner, but it gates that on the panel being
                    // visible and on battery/game state; a settings surface is not
                    // worth a second decoder, so this reads the still frame the
                    // wallpaper service already publishes for this screen.
                    ClippingRectangle {
                        id: banner
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: header.bannerHeight
                        visible: height > 0
                        radius: header.radius
                        color: Appearance.zzzEverywhere ? Appearance.zzz.tile
                             : Appearance.inirEverywhere ? Qt.alpha(Appearance.inir.colLayer1, 1)
                             : Qt.alpha(Appearance.colors.colLayer0Base, 1)

                        Image {
                            anchors.fill: parent
                            source: WallpaperListener.wallpaperUrlForScreen(settingsPanel.screen)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                            sourceSize.width: Math.max(640, Math.round(width * 2))
                            sourceSize.height: Math.max(160, Math.round(height * 2))
                            opacity: status === Image.Ready ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }

                        // The avatar and the title sit against the banner's lower
                        // edge, and a wallpaper can be anything — this keeps both
                        // legible without dimming the whole image.
                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: Math.min(parent.height * 0.6, 40)
                            gradient: Gradient {
                                GradientStop { position: 0; color: Qt.alpha(banner.color, 0) }
                                GradientStop { position: 1; color: Qt.alpha(banner.color, 0.55) }
                            }
                        }
                    }

                    // ── Avatar ──
                    // Overlaps the banner's lower edge, the same relationship the
                    // sidebar card uses, so the identity reads as one unit.
                    Item {
                        id: avatar
                        width: header.avatarSize
                        height: header.avatarSize
                        visible: header.identityShown && header.height > header.toolbarHeight
                        x: 14
                        y: header.bannerHeight - header.avatarSize * 0.45

                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.zzzEverywhere
                                ? Appearance.zzz.controlRadius : width / 2
                            color: Appearance.zzzEverywhere ? Appearance.zzz.chrome
                                 : Appearance.inirEverywhere ? Qt.alpha(Appearance.inir.colLayer1, 1)
                                 : Qt.alpha(Appearance.colors.colLayer1, 1)
                            border.width: 2
                            border.color: SettingsMaterialPreset.accentColor
                        }

                        ClippingRectangle {
                            anchors.centerIn: parent
                            width: header.avatarSize - 6
                            height: header.avatarSize - 6
                            radius: Appearance.zzzEverywhere
                                ? Appearance.zzz.controlRadius : width / 2
                            color: "transparent"

                            Image {
                                id: avatarImage
                                anchors.fill: parent
                                source: avatarResolver.resolvedSource
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                sourceSize.width: 96
                                sourceSize.height: 96
                                opacity: status === Image.Ready ? 1 : 0
                                visible: opacity > 0
                            }

                            // Directories publishes an ordered candidate list; walk
                            // it on error so a missing first entry still resolves.
                            QtObject {
                                id: avatarResolver
                                property int avatarIndex: 0
                                readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)
                                readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                                onPrimaryWatchChanged: avatarIndex = 0
                                readonly property int imgStatus: avatarImage.status
                                onImgStatusChanged: {
                                    if (imgStatus !== Image.Error)
                                        return;
                                    const next = avatarIndex + 1;
                                    if (next < Directories.userAvatarPaths.length)
                                        avatarIndex = next;
                                }
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                visible: avatarImage.status !== Image.Ready
                                text: "person"
                                iconSize: 20
                                color: SettingsMaterialPreset.accentColor
                            }
                        }
                    }

                    RowLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            bottom: parent.bottom
                        }
                        height: header.toolbarHeight
                        // Clears the avatar when the identity is showing.
                        anchors.leftMargin: header.identityShown
                            ? 14 + header.avatarSize + 10 : 14
                        anchors.rightMargin: 10
                        spacing: 10

                        // Back / identity slot — morphs between levels
                        RippleButton {
                            implicitWidth: 36
                            implicitHeight: 36
                            buttonRadius: Appearance.rounding.full
                            visible: root.level === 1
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: root.goHome()

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "arrow_back"
                                iconSize: 20
                                color: Appearance.colors.colOnLayer1
                            }

                            StyledToolTip { text: Translation.tr("Back to all settings") }
                        }

                        MaterialSymbol {
                            visible: root.level === 1
                            text: root.currentMeta.icon ?? ""
                            rotation: root.currentMeta.iconRotation ?? 0
                            iconSize: 20
                            color: Appearance.inirEverywhere ? Appearance.inir.colAccent
                                 : Appearance.colors.colPrimary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            // Home reads as the account card the sidebar already
                            // established: who you are, then the account line.
                            // A page swaps both for its own identity.
                            StyledText {
                                Layout.fillWidth: true
                                text: root.level === 1
                                    ? (root.currentMeta.name ?? "")
                                    : (SystemInfo.displayName || SystemInfo.username)
                                color: Appearance.colors.colOnLayer0
                                elide: Text.ElideRight
                                wrapMode: Text.NoWrap
                                font {
                                    family: Appearance.font.family.title
                                    pixelSize: Appearance.font.pixelSize.normal
                                    weight: Font.DemiBold
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                CustomIcon {
                                    Layout.preferredWidth: 13
                                    Layout.preferredHeight: 13
                                    visible: root.level === 0
                                    source: SystemInfo.distroIcon
                                    colorize: true
                                    color: Appearance.colors.colSubtext
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: root.level === 1
                                        ? (root.currentMeta.desc ?? "")
                                        : header.accountLine
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    elide: Text.ElideRight
                                    wrapMode: Text.NoWrap
                                    opacity: 0.85
                                }
                            }
                        }

                        // ── Search ──
                        Rectangle {
                            id: searchBox
                            Layout.preferredWidth: 300
                            Layout.maximumWidth: 300
                            Layout.minimumWidth: 160
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter
                            radius: Appearance.rounding.full
                            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                 : Appearance.inirEverywhere
                                    ? (focusSearchField.activeFocus ? Appearance.inir.colLayer1 : Appearance.inir.colLayer0)
                                    : (focusSearchField.activeFocus ? Appearance.colors.colLayer1 : Appearance.colors.colLayer0)
                            border.width: focusSearchField.activeFocus ? 2
                                : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1)
                            border.color: focusSearchField.activeFocus
                                ? Appearance.colors.colPrimary
                                : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                                  : Appearance.inirEverywhere ? Appearance.inir.colBorderMuted
                                  : Appearance.m3colors.m3outlineVariant)

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on border.color {
                                enabled: Appearance.animationsEnabled
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 6

                                MaterialSymbol {
                                    text: root.searchResults.length > 0 ? "manage_search" : "search"
                                    iconSize: 18
                                    color: Appearance.colors.colSubtext
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    StyledText {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: Translation.tr("Search settings…")
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        visible: focusSearchField.text.length === 0
                                    }

                                    TextInput {
                                        id: focusSearchField
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        color: Appearance.colors.colOnLayer1
                                        selectionColor: Appearance.colors.colPrimaryContainer
                                        selectedTextColor: Appearance.colors.colOnPrimaryContainer
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        clip: true

                                        cursorVisible: activeFocus
                                        cursorDelegate: Rectangle {
                                            visible: focusSearchField.cursorVisible
                                            width: 2
                                            color: Appearance.colors.colPrimary
                                        }

                                        text: root.searchText
                                        onTextChanged: {
                                            root.searchText = text;
                                            root.recomputeSearch();
                                        }

                                        Keys.onPressed: event => {
                                            if (event.key === Qt.Key_Down && root.searchResults.length > 0) {
                                                resultsList.forceActiveFocus();
                                                if (resultsList.currentIndex < 0)
                                                    resultsList.currentIndex = 0;
                                                event.accepted = true;
                                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                                    && root.searchResults.length > 0) {
                                                var i = Math.max(0, resultsList.currentIndex);
                                                root.openSearchResult(root.searchResults[i]);
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }

                                RippleButton {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    buttonRadius: Appearance.rounding.full
                                    visible: root.searchText.length > 0
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    onClicked: {
                                        root.clearSearch();
                                        focusSearchField.forceActiveFocus();
                                    }
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: 16
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }
                        }

                        // Layout switcher. Home only: the toolbar is tight on a
                        // page, and this is a decision you make about the whole
                        // surface, not about the page you happen to be editing.
                        Row {
                            visible: root.level === 0
                            spacing: 0

                            Repeater {
                                model: [
                                    { mode: "focus", icon: "grid_view", label: Translation.tr("Focus layout") },
                                    { mode: "rail", icon: "view_sidebar", label: Translation.tr("Nav rail layout") },
                                    { mode: "window", icon: "web_asset", label: Translation.tr("Separate window") }
                                ]

                                delegate: RippleButton {
                                    id: layoutButton
                                    required property var modelData

                                    readonly property bool current:
                                        layoutButton.modelData.mode === "window"
                                            ? false
                                            : (Config.options?.settingsUi?.overlayStyle ?? "rail")
                                                === layoutButton.modelData.mode

                                    implicitWidth: 30
                                    implicitHeight: 30
                                    buttonRadius: Appearance.rounding.full
                                    colBackground: layoutButton.current
                                        ? CF.ColorUtils.applyAlpha(
                                            SettingsMaterialPreset.accentColor, 0.16)
                                        : "transparent"
                                    colBackgroundHover: SettingsMaterialPreset.headerHoverColor
                                    onClicked: root.setLayout(layoutButton.modelData.mode)

                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: layoutButton.modelData.icon
                                        iconSize: 17
                                        color: layoutButton.current
                                            ? SettingsMaterialPreset.accentColor
                                            : Appearance.colors.colOnSurfaceVariant
                                    }

                                    StyledToolTip { text: layoutButton.modelData.label }
                                }
                            }
                        }

                        RippleButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: root.setEasyMode(!root.easyMode)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.easyMode ? "school" : "tune"
                                iconSize: 19
                                color: root.easyMode ? Appearance.colors.colPrimary
                                     : Appearance.colors.colOnSurfaceVariant
                            }
                            StyledToolTip {
                                text: root.easyMode
                                    ? Translation.tr("Easy mode — click to show all settings")
                                    : Translation.tr("Advanced mode — click to switch to Easy mode (essentials only)")
                            }
                        }

                        RippleButton {
                            implicitWidth: 34
                            implicitHeight: 34
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer1Hover
                            onClicked: GlobalStates.settingsOverlayOpen = false
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 19
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                }

                // ── Body: home grid and page, swapped horizontally ──
                Item {
                    id: body
                    anchors {
                        top: header.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        topMargin: 10
                    }
                    clip: true

                    readonly property real slide: width * 0.18

                    // No separate content plate here. An earlier attempt gave the
                    // body its own full-bleed surface so a very translucent panel
                    // would stay readable, but it split the panel into two visibly
                    // different materials and the header read as a detached
                    // floating strip. The panel is one surface; legibility comes
                    // from the content cards that sit on it, which is also what
                    // makes the hierarchy readable.

                    // Home
                    Item {
                        id: homeView
                        anchors.fill: parent
                        x: root.level === 0 ? 0 : -body.slide
                        opacity: root.level === 0 ? 1 : 0
                        visible: opacity > 0
                        enabled: root.level === 0

                        Behavior on x {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        StyledFlickable {
                            id: homeFlick
                            anchors.fill: parent
                            contentHeight: homeCol.implicitHeight + 28
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: StyledScrollBar {}

                            // Cards used to be sliced off mid-row at the scroll
                            // edges. An alpha mask, not a gradient painted in the
                            // panel colour: under aurora the panel is blurred
                            // wallpaper, so there is no flat colour to fade into.
                            // Only enabled while the view actually overflows, so a
                            // short home screen pays for no extra FBO.
                            readonly property bool overflowing: contentHeight > height + 1
                            readonly property real fadeSpan: 0.05

                            layer.enabled: overflowing
                            layer.effect: GE.OpacityMask {
                                maskSource: Rectangle {
                                    width: homeFlick.width
                                    height: homeFlick.height
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: homeFlick.contentY > 2
                                                ? "transparent" : "black"
                                        }
                                        GradientStop { position: homeFlick.fadeSpan; color: "black" }
                                        GradientStop { position: 1 - homeFlick.fadeSpan; color: "black" }
                                        GradientStop {
                                            position: 1
                                            color: homeFlick.contentY
                                                < homeFlick.contentHeight - homeFlick.height - 2
                                                ? "transparent" : "black"
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                id: homeCol
                                width: homeFlick.width
                                y: 0
                                spacing: 6

                                // Card margins plus the card's own inner padding:
                                // what the tiles actually get to share.
                                readonly property int groupMargins: 32
                                    + SettingsMaterialPreset.cardPadding * 2
                                readonly property int tileSpacing: 8
                                // Column count is derived from a minimum readable
                                // tile, not from screen breakpoints. The previous
                                // "width >= 900 → 4 columns" rule produced 245 px
                                // tiles on the 1040 px card, which left ~180 px for
                                // the description and elided most of them.
                                readonly property int minTileWidth: 268
                                readonly property int gridColumns: Math.max(1, Math.min(4,
                                    Math.floor((homeCol.width - homeCol.groupMargins + homeCol.tileSpacing)
                                        / (homeCol.minTileWidth + homeCol.tileSpacing))))

                                Repeater {
                                    model: root.visibleGroups

                                    // Each category is a card, not a bare label over
                                    // loose tiles. It borrows SettingsMaterialPreset
                                    // — the same tokens SettingsCardSection uses — so
                                    // the home screen and the section cards inside a
                                    // page read as one material, and the panel keeps a
                                    // single background instead of a second plate.
                                    delegate: Rectangle {
                                        id: group
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        Layout.leftMargin: 16
                                        Layout.rightMargin: 16
                                        Layout.topMargin: group.index > 0 ? 10 : 0
                                        implicitHeight: groupCol.implicitHeight
                                            + SettingsMaterialPreset.cardPadding * 2
                                        radius: SettingsMaterialPreset.cardRadius
                                        color: Appearance.zzzEverywhere
                                            ? "transparent" : SettingsMaterialPreset.cardColor
                                        border.width: Appearance.angelEverywhere
                                            || Appearance.zzzEverywhere ? 0 : 1
                                        border.color: SettingsMaterialPreset.cardBorderColor

                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }

                                        // zzz draws definition with its plate, not a
                                        // filled rectangle — same rule as the section
                                        // cards, so both surfaces stay in doctrine.
                                        ZzzPlate {
                                            anchors.fill: parent
                                            visible: Appearance.zzzEverywhere
                                            fillColor: Appearance.zzz.bg1
                                            strokeColor: Appearance.zzz.hairline
                                            strokeWidth: Appearance.zzz.hairlineThick
                                            chamfer: Appearance.zzz.cutCorner
                                            z: -1
                                        }

                                        ColumnLayout {
                                            id: groupCol
                                            anchors {
                                                fill: parent
                                                margins: SettingsMaterialPreset.cardPadding
                                            }
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Layout.leftMargin: 2
                                                spacing: 8

                                                Rectangle {
                                                    Layout.preferredWidth: 3
                                                    Layout.preferredHeight: 13
                                                    radius: 1.5
                                                    color: SettingsMaterialPreset.accentColor
                                                    opacity: 0.75
                                                    visible: !Appearance.zzzEverywhere
                                                }

                                                StyledText {
                                                    Layout.fillWidth: true
                                                    text: group.modelData.label || ""
                                                    color: SettingsMaterialPreset.accentColor
                                                    opacity: 0.9
                                                    elide: Text.ElideRight
                                                    wrapMode: Text.NoWrap
                                                    font {
                                                        family: Appearance.font.family.main
                                                        pixelSize: Appearance.font.pixelSize.smaller
                                                        weight: Font.DemiBold
                                                        capitalization: Font.AllUppercase
                                                        letterSpacing: 1.1
                                                    }
                                                }

                                                StyledText {
                                                    text: String(group.modelData.entries.length)
                                                    color: Appearance.colors.colSubtext
                                                    opacity: 0.55
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                }
                                            }

                                            // A real grid, not a Flow: fixed-width tiles
                                            // left a dead column against the card edge and
                                            // elided almost every description. Columns share
                                            // the full width, so a partial last row simply
                                            // stays left-aligned instead of looking ragged.
                                            GridLayout {
                                                Layout.fillWidth: true
                                                columns: homeCol.gridColumns
                                                columnSpacing: homeCol.tileSpacing
                                                rowSpacing: homeCol.tileSpacing

                                                Repeater {
                                                    model: group.modelData.entries

                                                    delegate: RippleButton {
                                                        id: tile
                                                        required property var modelData

                                                        // preferredWidth 1 + fillWidth is what
                                                        // makes GridLayout share columns evenly
                                                        // regardless of each tile's content.
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        Layout.minimumWidth: 150
                                                        implicitHeight: 74
                                                        buttonRadius: Appearance.zzzEverywhere
                                                            ? Appearance.zzz.controlRadius
                                                            : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                                            : Appearance.rounding.small

                                                        // Rows inside a card, not cards
                                                        // themselves. A filled tile on a
                                                        // filled group card stacks two
                                                        // near-identical surfaces and both
                                                        // stop reading; the medallion and
                                                        // the hover state carry the affordance.
                                                        colBackground: "transparent"
                                                        colBackgroundHover: SettingsMaterialPreset.headerHoverColor

                                                        onClicked: root.openPage(tile.modelData.realIndex)

                                                        contentItem: RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 12
                                                            anchors.rightMargin: 10
                                                            spacing: 10

                                                            MaterialShapeWrappedMaterialSymbol {
                                                                Layout.alignment: Qt.AlignVCenter
                                                                text: tile.modelData.icon || ""
                                                                iconSize: 19
                                                                padding: 8
                                                                shape: root._shapeForGroup(tile.modelData.groupIndex ?? 0)
                                                                // The widget's own default is tuned for opaque cards.
                                                                // aurora's colElevatedSurface is already transparentized,
                                                                // so on this translucent panel the medallion vanished.
                                                                // Styles with a solid surface token keep it; the rest
                                                                // get a primary tint that survives any panel opacity.
                                                                color: Appearance.zzzEverywhere
                                                                        ? CF.ColorUtils.transparentize(Appearance.zzz.paperAlt, 0.10)
                                                                    : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                                                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                                                    : CF.ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                                                                colSymbol: Appearance.zzzEverywhere ? Appearance.zzz.accent
                                                                    : Appearance.inirEverywhere ? Appearance.inir.colAccent
                                                                    : Appearance.angelEverywhere ? Appearance.angel.colText
                                                                    : Appearance.colors.colPrimary
                                                                // Rotation rides the whole medallion: the wrapper
                                                                // exposes no handle on the inner symbol. Every shape
                                                                // used here reads the same at 180°, so only the
                                                                // glyph visibly flips.
                                                                rotation: tile.modelData.iconRotation || 0
                                                                // MaterialShape does not interpolate between shapes,
                                                                // so hover lifts scale rather than switching
                                                                // silhouette, which would pop.
                                                                scale: tile.hovered ? 1.09 : 1
                                                                Behavior on scale {
                                                                    enabled: Appearance.animationsEnabled
                                                                    animation: NumberAnimation {
                                                                        duration: Appearance.animation.elementMoveFast.duration
                                                                        easing.type: Appearance.animation.elementMoveFast.type
                                                                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                                                                    }
                                                                }
                                                            }

                                                            ColumnLayout {
                                                                Layout.fillWidth: true
                                                                Layout.minimumWidth: 0
                                                                spacing: 1

                                                                StyledText {
                                                                    Layout.fillWidth: true
                                                                    Layout.minimumWidth: 0
                                                                    text: tile.modelData.name || ""
                                                                    color: Appearance.colors.colOnLayer1
                                                                    elide: Text.ElideRight
                                                                    wrapMode: Text.NoWrap
                                                                    font {
                                                                        family: Appearance.font.family.main
                                                                        pixelSize: Appearance.font.pixelSize.small
                                                                        weight: Font.Medium
                                                                    }
                                                                }

                                                                StyledText {
                                                                    Layout.fillWidth: true
                                                                    Layout.minimumWidth: 0
                                                                    text: tile.modelData.desc || ""
                                                                    color: Appearance.colors.colSubtext
                                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                                    elide: Text.ElideRight
                                                                    wrapMode: Text.NoWrap
                                                                    opacity: 0.9
                                                                }
                                                            }
                                                        }
                                                    }
                                                }

                                                // A GridLayout column only has width
                                                // where some row occupies it, so a group
                                                // holding fewer pages than there are
                                                // columns stretched its tiles across the
                                                // whole card — Essentials' single Quick
                                                // tile spanned the full width. These
                                                // reserve the columns the group leaves
                                                // empty, and must stay declared after
                                                // the tiles: the grid fills row-major in
                                                // declaration order.
                                                Repeater {
                                                    model: Math.max(0, homeCol.gridColumns
                                                        - group.modelData.entries.length)

                                                    delegate: Item {
                                                        Layout.fillWidth: true
                                                        Layout.preferredWidth: 1
                                                        Layout.preferredHeight: 1
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Page
                    Item {
                        id: pageView
                        anchors.fill: parent
                        x: root.level === 1 ? 0 : body.slide
                        opacity: root.level === 1 ? 1 : 0
                        visible: opacity > 0
                        enabled: root.level === 1

                        Behavior on x {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation {
                                duration: Appearance.animation.elementMoveFast.duration
                                easing.type: Appearance.animation.elementMoveFast.type
                                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                            }
                        }

                        // ── On this page: the page's own section index ──
                        // Every settings page is a stack of collapsible
                        // SettingsCardSections, which in the other hosts means you
                        // scroll an accordion blind. They already register
                        // themselves with SettingsSearchRegistry, so the structure
                        // can be surfaced without touching a single page file.
                        Rectangle {
                            id: sectionRail

                            // Present for the whole time a page is open, never
                            // conditional on how many sections it found. Gating it
                            // on the section count meant the column appeared a
                            // debounce after the page did and shoved the content
                            // sideways — that reflow is what read as the index
                            // jamming, and it varied by style only because heavier
                            // styles take longer to lay a page out.
                            readonly property bool shown: root.level === 1

                            anchors {
                                top: parent.top
                                left: parent.left
                                leftMargin: 16
                            }
                            // Width is constant while a page is open — that is what
                            // keeps the content from reflowing. Height follows the
                            // list, so the column still ends where its content
                            // does instead of running to the panel floor.
                            width: shown ? 190 : 0
                            height: Math.min(railHeader.height + railCol.implicitHeight + 28,
                                             pageView.height - 4)
                            visible: shown
                            radius: SettingsMaterialPreset.cardRadius
                            color: Appearance.zzzEverywhere
                                ? "transparent" : SettingsMaterialPreset.cardColor
                            border.width: Appearance.angelEverywhere
                                || Appearance.zzzEverywhere ? 0 : 1
                            border.color: SettingsMaterialPreset.cardBorderColor
                            clip: true

                            ZzzPlate {
                                anchors.fill: parent
                                visible: Appearance.zzzEverywhere
                                fillColor: Appearance.zzz.bg1
                                strokeColor: Appearance.zzz.hairline
                                strokeWidth: Appearance.zzz.hairlineThick
                                chamfer: Appearance.zzz.cutCorner
                                z: -1
                            }

                            ListModel { id: sectionModel }

                            // Rebuilt off a debounce: page loads and section
                            // registration are dense bursts, and both fire this.
                            Timer {
                                id: sectionRebuild
                                interval: 90
                                onTriggered: sectionRail.rebuild()
                            }

                            // A rebuild can land while the host is mid-swap and
                            // currentItem is still null, or before the page's
                            // sections have registered. Nothing fires again after
                            // that, which is why the index sometimes never showed
                            // up at all. Retry a bounded number of times while the
                            // page is real but has produced nothing yet.
                            property int retries: 0
                            readonly property int maxRetries: 12

                            Connections {
                                target: SettingsSearchRegistry
                                function onCollapsibleSectionsChanged() { sectionRail.scheduleRebuild() }
                            }

                            // Deliberately does not clear the model first: rebuild
                            // replaces it in one pass, and clearing here collapsed
                            // the index to zero width and re-expanded it on every
                            // page change, which is what made it open oddly.
                            Connections {
                                target: pageHost
                                function onCurrentItemChanged() { sectionRail.scheduleRebuild() }
                                // The host reports Ready separately from the item
                                // binding, and a page served from its LRU cache
                                // re-registers nothing — without this the index
                                // could stay empty on a revisit.
                                function onLoadingChanged() {
                                    if (!pageHost.loading)
                                        sectionRail.scheduleRebuild();
                                }
                            }

                            // Sections live on the page item, but the registry is
                            // flat across every retained page, so ancestry decides
                            // membership. Stored on the model as plain values —
                            // ListModel cannot hold QML object references safely.
                            property var sectionItems: []

                            function scheduleRebuild(): void {
                                sectionRail.retries = 0;
                                sectionRebuild.restart();
                            }

                            function rebuild(): void {
                                const page = pageHost.currentItem;
                                if (!page) {
                                    if (sectionRail.retries < sectionRail.maxRetries) {
                                        sectionRail.retries++;
                                        sectionRebuild.restart();
                                    }
                                    return;
                                }

                                const all = SettingsSearchRegistry.collapsibleSections ?? [];
                                const mine = [];
                                for (let i = 0; i < all.length; i++) {
                                    const s = all[i];
                                    if (!s || !s.title || !s.visible)
                                        continue;
                                    let p = s.parent;
                                    while (p && p !== page)
                                        p = p.parent;
                                    if (p === page)
                                        mine.push(s);
                                }

                                mine.sort((a, b) => a.mapToItem(page.contentItem, 0, 0).y
                                                  - b.mapToItem(page.contentItem, 0, 0).y);

                                // Nothing found yet is not the same as nothing to
                                // find: a page's sections register during its own
                                // construction, and some are gated on config that
                                // settles a frame later. Retrying here is what
                                // stops the index from staying empty for a page
                                // that genuinely has sections.
                                if (mine.length === 0
                                        && sectionRail.retries < sectionRail.maxRetries) {
                                    sectionRail.retries++;
                                    sectionRebuild.restart();
                                    return;
                                }

                                sectionModel.clear();
                                sectionRail.sectionItems = mine;
                                // Roles are prefixed: RippleButton derives from
                                // Controls.Button, where `icon` is a grouped
                                // property — a required `icon` role on the
                                // delegate collides with it.
                                for (let j = 0; j < mine.length; j++)
                                    sectionModel.append({
                                        sectionTitle: String(mine[j].title),
                                        sectionIcon: String(mine[j].icon || "chevron_right")
                                    });

                                sectionRail.refreshActive();
                            }

                            // One section open at a time. With several expanded the
                            // page is tall enough that the entry sitting at the
                            // scroll top is rarely the one you asked for, so the
                            // index kept marking somewhere else. Collapsing the
                            // rest makes the mark and the view agree.
                            property int pendingJump: -1

                            function jumpTo(index: int): void {
                                const items = sectionRail.sectionItems;
                                const section = items[index];
                                if (!pageHost.currentItem || !section)
                                    return;

                                for (let i = 0; i < items.length; i++) {
                                    if (items[i] && items[i].collapsible)
                                        items[i].expanded = i === index;
                                }
                                section.expanded = true;
                                sectionRail.allExpanded = false;
                                sectionRail.activeIndex = index;

                                // Collapsing everything above the target moves it,
                                // and the collapse animates, so its final offset is
                                // only knowable once that settles. Real
                                // milliseconds: the duration is 0 with motion off.
                                sectionRail.pendingJump = index;
                                jumpSettle.restart();
                            }

                            Timer {
                                id: jumpSettle
                                interval: Math.max(60, Appearance.animation.elementMove.duration + 40)
                                onTriggered: {
                                    const page = pageHost.currentItem;
                                    const section =
                                        sectionRail.sectionItems[sectionRail.pendingJump];
                                    sectionRail.pendingJump = -1;
                                    if (!page || !section)
                                        return;
                                    const y = section.mapToItem(page.contentItem, 0, 0).y;
                                    // With everything else collapsed the page is
                                    // usually short enough that the target is
                                    // already on screen. Scrolling anyway added a
                                    // second lurch after the collapse animation for
                                    // no gain, so only move when it is really off.
                                    if (y >= page.contentY && y <= page.contentY + page.height - 60)
                                        return;
                                    page.contentY = Math.max(0, Math.min(y - 12,
                                        Math.max(0, page.contentHeight - page.height)));
                                }
                            }

                            function setAllExpanded(value: bool): void {
                                const items = sectionRail.sectionItems;
                                for (let i = 0; i < items.length; i++) {
                                    if (items[i] && items[i].collapsible)
                                        items[i].expanded = value;
                                }
                                sectionRail.allExpanded = value;
                            }

                            property bool allExpanded: true
                            property int activeIndex: -1

                            // The mark is the open section, full stop. It used to
                            // be guessed from the scroll offset — the last section
                            // whose top had passed the probe line — which marked
                            // whatever happened to sit at the top edge rather than
                            // the card you were reading, and drifted on its own as
                            // the page scrolled. One section is open at a time, so
                            // there is nothing to infer.
                            function refreshActive(): void {
                                const items = sectionRail.sectionItems;
                                for (let i = 0; i < items.length; i++) {
                                    if (items[i] && items[i].expanded) {
                                        sectionRail.activeIndex = i;
                                        return;
                                    }
                                }
                                sectionRail.activeIndex = -1;
                            }

                            Timer {
                                id: activeTracker
                                interval: 60
                                onTriggered: sectionRail.refreshActive()
                            }

                            // The page's height is what changes when a section is
                            // expanded or collapsed from the card itself, which is
                            // the only way the open section changes without going
                            // through jumpTo. Scroll position no longer matters.
                            Connections {
                                target: pageHost.currentItem ?? null
                                ignoreUnknownSignals: true
                                function onContentHeightChanged() { activeTracker.restart() }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                RowLayout {
                                    id: railHeader
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 2
                                    spacing: 6

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("On this page")
                                        color: SettingsMaterialPreset.accentColor
                                        opacity: 0.9
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.smaller
                                            weight: Font.DemiBold
                                            capitalization: Font.AllUppercase
                                            letterSpacing: 1.1
                                        }
                                    }

                                    RippleButton {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        buttonRadius: Appearance.rounding.full
                                        colBackground: "transparent"
                                        colBackgroundHover: SettingsMaterialPreset.headerHoverColor
                                        onClicked: sectionRail.setAllExpanded(!sectionRail.allExpanded)
                                        contentItem: MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: sectionRail.allExpanded ? "unfold_less" : "unfold_more"
                                            iconSize: 15
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }
                                        StyledToolTip {
                                            text: sectionRail.allExpanded
                                                ? Translation.tr("Collapse every section")
                                                : Translation.tr("Expand every section")
                                        }
                                    }
                                }

                                StyledFlickable {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    contentHeight: railCol.implicitHeight
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds

                                    ColumnLayout {
                                        id: railCol
                                        width: parent.width
                                        spacing: 1

                                        Repeater {
                                            model: sectionModel

                                            delegate: RippleButton {
                                                id: railItem
                                                required property int index
                                                required property string sectionTitle
                                                required property string sectionIcon

                                                readonly property bool active:
                                                    railItem.index === sectionRail.activeIndex

                                                Layout.fillWidth: true
                                                implicitHeight: 30
                                                buttonRadius: Appearance.zzzEverywhere
                                                    ? Appearance.zzz.controlRadius
                                                    : Appearance.rounding.small
                                                // The active entry takes an accent
                                                // wash and hover takes the neutral
                                                // one. Sharing headerHoverColor for
                                                // both made a hovered row look
                                                // exactly like the one you are
                                                // actually reading.
                                                colBackground: railItem.active
                                                    ? CF.ColorUtils.applyAlpha(
                                                        SettingsMaterialPreset.accentColor, 0.16)
                                                    : "transparent"
                                                colBackgroundHover: SettingsMaterialPreset.headerHoverColor
                                                onClicked: sectionRail.jumpTo(railItem.index)

                                                contentItem: RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 6
                                                    spacing: 7

                                                    // Not SettingsMaterialPreset's
                                                    // icon/title colours: under zzz
                                                    // those are on-plate inks meant
                                                    // to ride a ZzzGlyphBadge, and
                                                    // on this plain row they render
                                                    // near-black. These rows have no
                                                    // plate, so they take surface ink.
                                                    MaterialSymbol {
                                                        text: railItem.sectionIcon
                                                        iconSize: 15
                                                        color: railItem.active
                                                            ? (Appearance.zzzEverywhere ? Appearance.zzz.accent
                                                              : SettingsMaterialPreset.accentColor)
                                                            : (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                                              : Appearance.colors.colOnSurfaceVariant)
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: railItem.sectionTitle
                                                        color: railItem.active
                                                            ? (Appearance.zzzEverywhere ? Appearance.zzz.ink
                                                              : Appearance.colors.colOnLayer1)
                                                            : (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                                              : Appearance.colors.colSubtext)
                                                        elide: Text.ElideRight
                                                        wrapMode: Text.NoWrap
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        font.weight: railItem.active ? Font.DemiBold : Font.Normal
                                                    }
                                                }
                                            }
                                        }

                                        // ── Rest of the category ──
                                        // The space under a short index was dead,
                                        // and drilling into a page cut every
                                        // sibling loose — reaching the next page in
                                        // the same category meant walking back out
                                        // to the grid. Both problems answer to the
                                        // same list, and it sizes to the category,
                                        // so the column still ends where its
                                        // content does.
                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 14
                                            visible: siblingRepeater.count > 0

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: parent.width - 4
                                                height: 1
                                                color: SettingsMaterialPreset.cardBorderColor
                                                opacity: 0.7
                                            }
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 2
                                            Layout.bottomMargin: 2
                                            visible: siblingRepeater.count > 0
                                            text: root.currentGroup?.label ?? ""
                                            color: SettingsMaterialPreset.accentColor
                                            opacity: 0.9
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: Appearance.font.pixelSize.smaller
                                                weight: Font.DemiBold
                                                capitalization: Font.AllUppercase
                                                letterSpacing: 1.1
                                            }
                                        }

                                        Repeater {
                                            id: siblingRepeater
                                            model: root.currentGroup?.entries ?? []

                                            delegate: RippleButton {
                                                id: siblingItem
                                                required property var modelData

                                                readonly property bool isCurrent:
                                                    siblingItem.modelData.realIndex === root.currentPage

                                                Layout.fillWidth: true
                                                implicitHeight: 30
                                                buttonRadius: Appearance.zzzEverywhere
                                                    ? Appearance.zzz.controlRadius
                                                    : Appearance.rounding.small
                                                colBackground: siblingItem.isCurrent
                                                    ? CF.ColorUtils.applyAlpha(
                                                        SettingsMaterialPreset.accentColor, 0.16)
                                                    : "transparent"
                                                colBackgroundHover: SettingsMaterialPreset.headerHoverColor
                                                onClicked: root.openPage(siblingItem.modelData.realIndex)

                                                contentItem: RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 6
                                                    spacing: 7

                                                    MaterialSymbol {
                                                        text: siblingItem.modelData.icon || ""
                                                        rotation: siblingItem.modelData.iconRotation || 0
                                                        iconSize: 15
                                                        color: siblingItem.isCurrent
                                                            ? (Appearance.zzzEverywhere ? Appearance.zzz.accent
                                                              : SettingsMaterialPreset.accentColor)
                                                            : (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                                              : Appearance.colors.colOnSurfaceVariant)
                                                    }

                                                    StyledText {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        text: siblingItem.modelData.name || ""
                                                        color: siblingItem.isCurrent
                                                            ? (Appearance.zzzEverywhere ? Appearance.zzz.ink
                                                              : Appearance.colors.colOnLayer1)
                                                            : (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                                              : Appearance.colors.colSubtext)
                                                        elide: Text.ElideRight
                                                        wrapMode: Text.NoWrap
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        font.weight: siblingItem.isCurrent ? Font.DemiBold : Font.Normal
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SettingsPageHost {
                            id: pageHost
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                left: sectionRail.right
                                right: parent.right
                                leftMargin: sectionRail.shown ? 10 : 0
                            }

                            pages: root.pages
                            requestedIndex: root.currentPage
                            // Keep recently visited pages warm while Settings is open,
                            // including home ↔ page navigation, but release them when
                            // the Settings surface itself closes.
                            loadEnabled: Config.ready && root.settingsOpen

                            // Same soft scroll edge as the home grid. Read through
                            // `var`, not the host's Item-typed currentItem, because
                            // contentY/contentHeight belong to the Flickable a
                            // ContentPage happens to be, not to Item.
                            readonly property var pageFlick: pageHost.currentItem
                            readonly property bool pageOverflowing: {
                                const f = pageHost.pageFlick
                                return !!f && f.contentHeight > f.height + 1
                            }
                            readonly property bool pageAtTop: {
                                const f = pageHost.pageFlick
                                return !f || f.contentY <= 2
                            }
                            readonly property bool pageAtBottom: {
                                const f = pageHost.pageFlick
                                return !f || f.contentY >= f.contentHeight - f.height - 2
                            }

                            layer.enabled: pageOverflowing
                            layer.effect: GE.OpacityMask {
                                maskSource: Rectangle {
                                    width: pageHost.width
                                    height: pageHost.height
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0
                                            color: pageHost.pageAtTop ? "black" : "transparent"
                                        }
                                        GradientStop { position: 0.045; color: "black" }
                                        GradientStop { position: 0.955; color: "black" }
                                        GradientStop {
                                            position: 1
                                            color: pageHost.pageAtBottom ? "black" : "transparent"
                                        }
                                    }
                                }
                            }

                            SettingsPageLoadingOverlay {
                                anchors.fill: parent
                                loading: pageHost.loading
                                text: Translation.tr("Loading page…")
                                z: 15
                            }
                        }
                    }
                }

                // ── Search results ──
                MouseArea {
                    anchors.fill: parent
                    visible: root.searchResults.length > 0
                    onClicked: root.clearSearch()
                    z: 90
                }

                // Without this a query that matches nothing just showed an empty
                // grid, which reads as the search being broken.
                Rectangle {
                    id: noResultsPill
                    visible: root.searchText.length > 0 && root.searchResults.length === 0
                    z: 100
                    anchors.top: header.bottom
                    anchors.topMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    width: noResultsRow.implicitWidth + 26
                    height: 36
                    radius: Appearance.rounding.full
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.zzzEverywhere ? Appearance.zzz.bg2
                         : Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.m3colors.m3outlineVariant

                    RowLayout {
                        id: noResultsRow
                        anchors.centerIn: parent
                        spacing: 8

                        MaterialSymbol {
                            text: "search_off"
                            iconSize: 18
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            text: Translation.tr("No results found")
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.small
                        }
                    }
                }

                Rectangle {
                    id: resultsCard
                    visible: root.searchText.length > 0 && root.searchResults.length > 0
                    z: 100
                    width: Math.min(420, card.width - 28)
                    height: Math.min(resultsList.contentHeight + 12, 360)
                    anchors.top: header.bottom
                    anchors.topMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                          : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                          : Appearance.rounding.normal
                    color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                         : Appearance.zzzEverywhere ? Appearance.zzz.bg2
                         : Appearance.colors.colLayer1
                    border.width: 1
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.m3colors.m3outlineVariant

                    ListView {
                        id: resultsList
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 2
                        model: root.searchResults
                        clip: true
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Up) {
                                if (resultsList.currentIndex > 0)
                                    resultsList.currentIndex--;
                                else
                                    focusSearchField.forceActiveFocus();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                if (resultsList.currentIndex < resultsList.count - 1)
                                    resultsList.currentIndex++;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (resultsList.currentIndex >= 0)
                                    root.openSearchResult(root.searchResults[resultsList.currentIndex]);
                                event.accepted = true;
                            }
                        }

                        delegate: RippleButton {
                            id: resultRow
                            required property var modelData
                            required property int index

                            width: resultsList.width
                            implicitHeight: 46
                            buttonRadius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                        : Appearance.rounding.small
                            // A wash of the accent, not the accent container. The
                            // container pairs with an on-container ink this row
                            // does not use, so under zzz the selected result came
                            // out light-on-orange. A low alpha keeps the row's own
                            // ink readable in every style. headerHoverColor is not
                            // an option here either — under zzz it resolves to the
                            // same bg2 this results card is painted with.
                            colBackground: resultRow.index === resultsList.currentIndex
                                ? CF.ColorUtils.applyAlpha(SettingsMaterialPreset.accentColor, 0.16)
                                : "transparent"
                            colBackgroundHover: CF.ColorUtils.applyAlpha(
                                SettingsMaterialPreset.accentColor, 0.09)

                            Keys.forwardTo: [resultsList]
                            onClicked: root.openSearchResult(resultRow.modelData)

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                MaterialSymbol {
                                    text: SettingsPageRegistry.iconForPage(resultRow.modelData.pageIndex)
                                    iconSize: 18
                                    color: resultRow.index === resultsList.currentIndex
                                        ? SettingsMaterialPreset.accentColor
                                        : (Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
                                          : Appearance.colors.colOnSurfaceVariant)
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: resultRow.modelData.labelHighlighted || resultRow.modelData.label || ""
                                        textFormat: Text.StyledText
                                        color: Appearance.zzzEverywhere ? Appearance.zzz.ink
                                             : Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                            weight: Font.Medium
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: resultRow.modelData.pageName || ""
                                        color: Appearance.colors.colSubtext
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                        wrapMode: Text.NoWrap
                                        opacity: 0.9
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
