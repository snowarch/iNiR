//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
// Launcher keeps QT_SCALE_FACTOR=1; shell scaling lives in appearance.typography.sizeScale

import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.settings
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    // Pages come from the shared registry; resolve component paths to absolute
    // shell URLs so the Loaders work regardless of this file's location.
    readonly property var pages: SettingsPageRegistry.pages.map(p => {
        var entry = Object.assign({}, p);
        entry.component = Quickshell.shellPath(p.component);
        return entry;
    })
    property int currentPage: 0
    property int _requestedStartPage: -1
    property string _requestedStartSection: ""
    property bool _navigationInitialized: false

    function _persistCurrentPage(): void {
        if (root._navigationInitialized && Persistent.ready && Persistent.states?.settings)
            Persistent.states.settings.iiPage = Math.max(0, Math.min(root.currentPage, root.pages.length - 1))
    }

    function initializeNavigation(): void {
        if (root._navigationInitialized || !Persistent.ready)
            return
        const persisted = Persistent.states?.settings?.iiPage ?? 0
        const requested = root._requestedStartPage >= 0 ? root._requestedStartPage : persisted
        root.currentPage = Math.max(0, Math.min(requested, root.pages.length - 1))
        root._navigationInitialized = true
        root._persistCurrentPage()
        if (root._requestedStartSection.length > 0) {
            root.pendingSpotlightSection = root._requestedStartSection
            root.pendingSpotlightPageIndex = root.currentPage
            root.trySpotlight()
        }
    }

    onCurrentPageChanged: root._persistCurrentPage()
    property bool uiReady: Config.ready

    // Easy mode helpers — derived list filtered to essentials when on
    readonly property bool easyMode: Config.options?.settingsUi?.easyMode ?? false
    // Nav model: category headers + page entries, filtered by easy mode (same as overlay)
    readonly property var visibleNavItems: {
        var items = [];
        var cats = SettingsPageRegistry.categories;
        for (var c = 0; c < cats.length; c++) {
            var cat = cats[c];
            var catPages = [];
            for (var p = 0; p < cat.pages.length; p++) {
                var pageIdx = cat.pages[p];
                if (pageIdx >= pages.length) continue;
                if (easyMode && pages[pageIdx].essential !== true) continue;
                catPages.push(pageIdx);
            }
            if (catPages.length === 0) continue;
            items.push({ type: "header", label: cat.label });
            for (var j = 0; j < catPages.length; j++) {
                var entry = Object.assign({}, pages[catPages[j]]);
                entry.type = "page";
                entry.realIndex = catPages[j];
                items.push(entry);
            }
        }
        return items;
    }

    // Ordered page indices matching nav rail order (for keyboard nav)
    readonly property var navPageOrder: visibleNavItems.filter(i => i.type === "page").map(i => i.realIndex)

    function nextNavPage(current) {
        var idx = navPageOrder.indexOf(current);
        if (idx < 0) return navPageOrder.length > 0 ? navPageOrder[0] : 0;
        return navPageOrder[(idx + 1) % navPageOrder.length];
    }
    function prevNavPage(current) {
        var idx = navPageOrder.indexOf(current);
        if (idx < 0) return navPageOrder.length > 0 ? navPageOrder[navPageOrder.length - 1] : 0;
        return navPageOrder[(idx - 1 + navPageOrder.length) % navPageOrder.length];
    }

    function setEasyMode(enabled) {
        Config.setNestedValue("settingsUi.easyMode", enabled === true);
    }

    // Auto-bounce off non-essential pages when easy mode is enabled
    onEasyModeChanged: {
        if (easyMode) {
            var current = pages[currentPage];
            if (current && current.essential !== true) currentPage = 0;
        }
        if (settingsSearchText.length > 0) recomputeSettingsSearchResults();
    }

    // Global settings search
    property string settingsSearchText: ""
    property var settingsSearchResults: []

    // Search navigation focus state
    property var searchTargetControl: null

    // Static section/option index — shared with the overlay via SettingsPageRegistry.
    readonly property var settingsSearchIndex: SettingsPageRegistry.staticSearchIndex

    function getWaffleSettingsPageIndex() {
        for (var i = 0; i < pages.length; i++) {
            if ((pages[i].component || "").indexOf("modules/settings/WaffleConfig.qml") >= 0)
                return i;
        }
        return -1;
    }

    function recomputeSettingsSearchResults() {
        var q = String(settingsSearchText || "").toLowerCase().trim();
        if (!q.length) {
            settingsSearchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];

        // Check if waffle family is active
        var isWaffleActive = Config.options?.panelFamily === "waffle";
        var wafflePageIndex = getWaffleSettingsPageIndex();
        var easyOn = root.easyMode;

        // 1. Buscar en el índice estático de secciones (para navegación rápida a secciones)
        for (var i = 0; i < settingsSearchIndex.length; i++) {
            var entry = settingsSearchIndex[i];

            // Skip Waffle Style page if waffle family is not active
            if (wafflePageIndex >= 0 && entry.pageIndex === wafflePageIndex && !isWaffleActive) {
                continue;
            }

            // Skip non-essential pages in easy mode
            if (easyOn && entry.pageIndex >= 0 && entry.pageIndex < pages.length
                && pages[entry.pageIndex].essential !== true) {
                continue;
            }

            var label = (entry.label || "").toLowerCase();
            var desc = (entry.description || "").toLowerCase();
            var page = (entry.pageName || "").toLowerCase();
            var sect = (entry.section || "").toLowerCase();
            var kw = (entry.keywords || []).join(" ").toLowerCase();

            var matchCount = 0;
            var score = 0;

            for (var j = 0; j < terms.length; j++) {
                var term = terms[j];
                if (label.indexOf(term) >= 0 || desc.indexOf(term) >= 0 ||
                    page.indexOf(term) >= 0 || sect.indexOf(term) >= 0 || kw.indexOf(term) >= 0) {
                    matchCount++;
                    if (label.indexOf(term) === 0) score += 800;
                    else if (label.indexOf(term) > 0) score += 400;
                    if (kw.indexOf(term) >= 0) score += 300;
                    if (sect.indexOf(term) >= 0) score += 200;
                }
            }

            if (matchCount === terms.length) {
                results.push({
                    pageIndex: entry.pageIndex,
                    pageName: entry.pageName,
                    section: entry.section,
                    label: entry.label,
                    labelHighlighted: SettingsSearchRegistry.highlightTerms(entry.label, terms),
                    description: entry.description,
                    descriptionHighlighted: SettingsSearchRegistry.highlightTerms(entry.description, terms),
                    score: score + 500, // Bonus para secciones principales
                    isSection: true
                });
            }
        }

        // 2. Buscar en el registro dinámico de widgets
        if (typeof SettingsSearchRegistry !== "undefined") {
            var widgetResults = SettingsSearchRegistry.buildResults(settingsSearchText);
            // Filter out Waffle Style widgets if waffle family is not active
            if (!isWaffleActive) {
                widgetResults = widgetResults.filter(r => r.pageIndex !== wafflePageIndex);
            }
            if (easyOn) {
                widgetResults = widgetResults.filter(r =>
                    r.pageIndex >= 0 && r.pageIndex < pages.length
                    && pages[r.pageIndex].essential === true);
            }
            // Prefer real controls (dynamic registry entries with optionId)
            for (var wr = 0; wr < widgetResults.length; wr++) {
                widgetResults[wr].score = (widgetResults[wr].score || 0) + 2000;
            }
            results = results.concat(widgetResults);
        }

        // 3. Ordenar por score y eliminar duplicados
        results.sort((a, b) => b.score - a.score);

        // Eliminar duplicados por pageIndex+label, preferring entries with optionId
        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var r = results[k];
            var key = String(r.pageIndex) + "|" + String(r.label || "").toLowerCase();
            if (!seen[key]) {
                seen[key] = { index: unique.length, hasOptionId: r.optionId !== undefined };
                unique.push(r);
            } else if (r.optionId !== undefined && !seen[key].hasOptionId) {
                unique[seen[key].index] = r;
                seen[key].hasOptionId = true;
            }
        }

        settingsSearchResults = unique.slice(0, 50);
    }

    // Pending search navigation target data
    property int pendingSpotlightOptionId: -1
    property string pendingSpotlightLabel: ""
    property string pendingSpotlightSection: ""
    property int pendingSpotlightPageIndex: -1
    property bool pendingSpotlightIsSection: false
    property var searchTargetFlickable: null

    function openSearchResult(entry) {
        // Clear search immediately
        settingsSearchText = "";
        if (settingsSearchField) {
            settingsSearchField.text = "";
        }

        // Reset existing search target state
        resetSearchTarget();

        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) {
            return;
        }

        // Store navigation target info
        pendingSpotlightOptionId = (entry.optionId !== undefined) ? entry.optionId : -1;
        pendingSpotlightLabel = entry.label || "";
        pendingSpotlightSection = entry.section || "";
        pendingSpotlightPageIndex = entry.pageIndex;
        pendingSpotlightIsSection = (entry.optionId === undefined) && (entry.isSection === true);

        // Navigate to page (this triggers page load if needed)
        if (currentPage !== entry.pageIndex) {
            currentPage = entry.pageIndex;
        }

        // Always try to resolve and navigate target (with retry for lazy-loaded widgets)
        if (pendingSpotlightOptionId >= 0 || pendingSpotlightLabel.length > 0) {
            spotlightRetryCount = 0;
            spotlightPageLoadTimer.restart();
        }
    }

    property int spotlightRetryCount: 0
    property int spotlightMaxRetries: 15

    // Timer to wait for page load and widget registration
    Timer {
        id: spotlightPageLoadTimer
        interval: 150
        onTriggered: root.trySpotlight()
    }

    function trySpotlight() {
        var control = null;

        // Try by optionId first
        if (pendingSpotlightOptionId >= 0) {
            control = SettingsSearchRegistry.getControlById(pendingSpotlightOptionId);
        }

        // Fallback: search in registry by various criteria
        // IMPORTANT: for static index entries (no optionId), treat as section navigation.
        // Don't guess a specific control by fuzzy label matching.
        if (!control && (pendingSpotlightLabel.length > 0 || pendingSpotlightSection.length > 0)) {
            var labelLower = pendingSpotlightLabel.toLowerCase();
            var sectionLower = pendingSpotlightSection.toLowerCase();
            // Remove page name prefix from section if present (supports both delimiters)
            // e.g., "Themes › Global Style" or "Themes · Global Style" -> "Global Style"
            var sectionParts = sectionLower.split(/[·›]/).map(p => p.trim()).filter(p => p.length > 0);
            var sectionOnly = sectionParts.length > 1 ? sectionParts[sectionParts.length - 1] : sectionLower;

            for (var i = 0; i < SettingsSearchRegistry.entries.length; i++) {
                var e = SettingsSearchRegistry.entries[i];
                if (e.pageIndex === pendingSpotlightPageIndex) {
                    var eLabelLower = (e.label || "").toLowerCase();
                    var eSectionLower = (e.section || "").toLowerCase();

                    if (pendingSpotlightIsSection) {
                        // Prefer matching the section title control.
                        if (eLabelLower === labelLower || eLabelLower === sectionOnly) {
                            control = e.control;
                            break;
                        }
                        if (eSectionLower === sectionOnly || eSectionLower === labelLower) {
                            control = e.control;
                            break;
                        }
                    } else {
                        // Exact label match
                        if (eLabelLower === labelLower) {
                            control = e.control;
                            break;
                        }
                        // Section title match (for SettingsCardSection)
                        if (eSectionLower === sectionOnly || eSectionLower === labelLower) {
                            control = e.control;
                            break;
                        }
                        // Label contains search term
                        if (labelLower.length > 2 && eLabelLower.indexOf(labelLower) >= 0) {
                            control = e.control;
                            break;
                        }
                        // Keywords contain search term
                        if (e.keywords && e.keywords.some(k => k.toLowerCase() === labelLower)) {
                            control = e.control;
                            break;
                        }
                    }
                }
            }
        }

        if (control) {
            navigateToSearchControl(control);
        } else if (spotlightRetryCount < spotlightMaxRetries) {
            spotlightRetryCount++;
            spotlightPageLoadTimer.restart();
        } else {
            // Give up after max retries - clear pending data
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightSection = "";
            pendingSpotlightPageIndex = -1;
            pendingSpotlightIsSection = false;
        }
    }

    function navigateToSearchControl(control) {
        if (!control) return;

        // Expand the section containing the control and collapse others
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.expandSectionForControl(control);
        }

        // Find the parent Flickable (ContentPage/StyledFlickable)
        var flick = findParentFlickable(control);
        if (!flick) {
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightPageIndex = -1;
            return;
        }

        // Use mapToItem to get the control's position relative to the Flickable's contentItem
        // This accounts for all intermediate containers (ColumnLayout margins, etc.)
        var posInContent = control.mapToItem(flick.contentItem, 0, 0);
        var controlYInContent = posInContent.y;

        // Calculate target scroll position to center the control in viewport
        var viewportHeight = flick.height;
        var controlHeight = control.height;
        var targetScrollY = controlYInContent - (viewportHeight / 2) + (controlHeight / 2);

        // Clamp to valid scroll range
        var maxScroll = Math.max(0, flick.contentHeight - flick.height);
        targetScrollY = Math.max(0, Math.min(targetScrollY, maxScroll));

        // Store the target scroll position for later verification
        spotlightTargetScrollY = targetScrollY;

        // Scroll to position - set directly to bypass animation
        flick.contentY = targetScrollY;

        // Store references for optional focus retries
        searchTargetControl = control;
        searchTargetFlickable = flick;

        // Clear pending data after successful navigation
        pendingSpotlightOptionId = -1;
        pendingSpotlightLabel = "";
        pendingSpotlightSection = "";
        pendingSpotlightPageIndex = -1;
        pendingSpotlightIsSection = false;
    }

    property real spotlightTargetScrollY: 0

    function findParentFlickable(item) {
        var p = item ? item.parent : null;
        while (p) {
            // Check for Flickable properties (contentY, contentHeight, contentItem)
            if (p.hasOwnProperty("contentY") &&
                p.hasOwnProperty("contentHeight") &&
                p.hasOwnProperty("contentItem")) {
                return p;
            }
            p = p.parent;
        }
        return null;
    }

    function resetSearchTarget() {
        searchTargetControl = null;
        searchTargetFlickable = null;
        spotlightTargetScrollY = 0;
        pendingSpotlightOptionId = -1;
        pendingSpotlightLabel = "";
        pendingSpotlightSection = "";
        pendingSpotlightPageIndex = -1;
        pendingSpotlightIsSection = false;
    }

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Component.onCompleted: {
        Quickshell.watchFiles = false
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed

        const startPage = parseInt(Quickshell.env("QS_SETTINGS_PAGE"));
        if (!isNaN(startPage)) root._requestedStartPage = startPage;

        root._requestedStartSection = Quickshell.env("QS_SETTINGS_SECTION") || ""
        root.initializeNavigation()
    }

    Connections {
        target: Persistent
        function onReadyChanged() { root.initializeNavigation() }
    }

    // Apply theme when Config is ready
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) ThemeService.applyCurrentTheme()
        }
    }

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: root.uiReady
        ? (Appearance.inirEverywhere ? Appearance.inir.colLayer0
          : Appearance.zzzEverywhere ? Appearance.colors.colLayer0
          : Appearance.m3colors.m3background)
        : "transparent"

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: settingsSearchField.forceActiveFocus()
    }

    ZzzDiagonalPattern {
        stripeSpacing: 28
        stripeThickness: 1
    }

    ZzzSurfaceAccent {
        // No top registration tape on this large utility window — it reads as an
        // ugly hard border along the top edge. Keep only the diagonal backdrop.
        showTape: false
        stripeCount: 34
        edgeMargin: root.contentPadding
        z: 1
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }
        z: 2
        visible: root.uiReady
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                    root.currentPage = root.nextNavPage(root.currentPage)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                    root.currentPage = root.prevNavPage(root.currentPage)
                    event.accepted = true;
                }
            }
        }

        RowLayout { // Titlebar with integrated search
            visible: Config.options?.windows?.showTitlebar ?? true
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.leftMargin: 12
            Layout.rightMargin: 6
            spacing: 12

                Item {
                    implicitWidth: 36
                    implicitHeight: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                    }

                    Rectangle {
                        id: settingsAvatarMask
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: width / 2
                        visible: false
                    }

                    Image {
                        id: settingsAvatarImage
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        source: settingsAvatarResolver.resolvedSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        smooth: true
                        mipmap: true
                        sourceSize.width: 64
                        sourceSize.height: 64
                        visible: status === Image.Ready
                        layer.enabled: visible
                        layer.effect: OpacityMask {
                            maskSource: settingsAvatarMask
                        }

                        // Walk the fallback chain from the signal, not from a bound
                        // property: binding status back into the index that feeds
                        // source is a loop.
                        onStatusChanged: {
                            if (settingsAvatarImage.status !== Image.Error)
                                return
                            const next = settingsAvatarResolver.avatarIndex + 1
                            if (next < Directories.userAvatarPaths.length)
                                settingsAvatarResolver.avatarIndex = next
                        }
                    }

                    // Reactive avatar resolver — retries fallback paths without breaking bindings
                    QtObject {
                        id: settingsAvatarResolver
                        property int avatarIndex: 0
                        readonly property string resolvedSource: Directories.avatarSourceAt(avatarIndex)

                        // Reset to primary whenever Directories re-resolves (e.g. username changes)
                        readonly property string primaryWatch: Directories.userAvatarSourcePrimary
                        onPrimaryWatchChanged: avatarIndex = 0
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: settingsAvatarImage.status !== Image.Ready
                        text: "person"
                        iconSize: 18
                        color: Appearance.colors.colPrimary
                    }
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        text: Translation.tr("Settings")
                        font {
                            family: Appearance.font.family.title
                            pixelSize: Appearance.font.pixelSize.title
                            variableAxes: Appearance.font.variableAxes.title
                        }
                    }

                    StyledText {
                        text: SystemInfo.displayName || SystemInfo.username
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillWidth: true; Layout.minimumWidth: 8 }

                // Search container with visual feedback
            Rectangle {
                id: searchContainer
                Layout.fillWidth: true
                Layout.maximumWidth: 480
                Layout.minimumWidth: 200
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.full
                color: settingsSearchField.activeFocus
                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                      : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                      : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                      : Appearance.colors.colLayer1)
                    : (Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                      : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                      : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                      : Appearance.colors.colLayer0)
                border.width: settingsSearchField.activeFocus ? 2
                    : (Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth : 1)
                border.color: settingsSearchField.activeFocus
                    ? Appearance.colors.colPrimary
                    : (Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                      : Appearance.inirEverywhere ? Appearance.inir.colBorderMuted
                      : Appearance.m3colors.m3outlineVariant)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    // Icono animado
                    MaterialShapeWrappedMaterialSymbol {
                        id: settingsSearchIcon
                        Layout.alignment: Qt.AlignVCenter
                        iconSize: Appearance.font.pixelSize.huge
                        shape: root.settingsSearchText.length > 0
                            ? MaterialShape.Shape.SoftBurst
                            : MaterialShape.Shape.Cookie7Sided
                        text: root.settingsSearchResults.length > 0 ? "manage_search" : "search"
                    }

                    // Campo de texto
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Placeholder text (behind TextField, separate element)
                        StyledText {
                            id: searchPlaceholder
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: Translation.tr("Search settings... (Ctrl+F)")
                            color: Appearance.colors.colSubtext
                            font {
                                family: Appearance.font.family.main
                                pixelSize: Appearance.font.pixelSize.normal
                            }
                            visible: settingsSearchField.text.length === 0 && !settingsSearchField.activeFocus
                        }

                        TextInput {
                            id: settingsSearchField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            verticalAlignment: Text.AlignVCenter

                            color: Appearance.colors.colOnLayer1
                            selectionColor: Appearance.colors.colPrimaryContainer
                            selectedTextColor: Appearance.colors.colOnPrimaryContainer
                            font {
                                family: Appearance.font.family.main
                                pixelSize: Appearance.font.pixelSize.normal
                            }

                            // Custom cursor color
                            cursorVisible: activeFocus
                            cursorDelegate: Rectangle {
                                visible: settingsSearchField.cursorVisible
                                width: 2
                                color: Appearance.colors.colPrimary

                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: settingsSearchField.cursorVisible
                                    NumberAnimation { to: 0; duration: 530 }
                                    NumberAnimation { to: 1; duration: 530 }
                                }
                            }

                            text: root.settingsSearchText
                            onTextChanged: {
                                root.settingsSearchText = text;
                                root.recomputeSettingsSearchResults();
                            }

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Down && root.settingsSearchResults.length > 0) {
                                    resultsListView.forceActiveFocus();
                                    if ((resultsListView.currentIndex < 0 || resultsListView.currentIndex >= resultsListView.count) && resultsListView.count > 0) {
                                        resultsListView.currentIndex = 0;
                                    }
                                    event.accepted = true;
                                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.settingsSearchResults.length > 0) {
                                    var idx = (resultsListView.currentIndex >= 0 && resultsListView.currentIndex < root.settingsSearchResults.length)
                                        ? resultsListView.currentIndex
                                        : 0;
                                    root.openSearchResult(root.settingsSearchResults[idx]);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openSearchResult({});
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Botón de limpiar
                    RippleButton {
                        id: clearButton
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: Appearance.rounding.full
                        visible: root.settingsSearchText.length > 0
                        opacity: visible ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 100 } }

                        onClicked: {
                            settingsSearchField.text = "";
                            settingsSearchField.forceActiveFocus();
                        }

                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 18
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    // Badge de resultados
                    Rectangle {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: resultsCountText.implicitWidth + 16
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: 4
                        visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length > 0
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimaryContainer

                        StyledText {
                            id: resultsCountText
                            anchors.centerIn: parent
                            text: root.settingsSearchResults.length.toString()
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }

                Item { Layout.fillWidth: true; Layout.minimumWidth: 8 }

                // Easy / Advanced mode toggle
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.setEasyMode(!root.easyMode)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: root.easyMode ? "school" : "tune"
                        iconSize: 20
                        color: root.easyMode ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                    StyledToolTip {
                        text: root.easyMode
                            ? Translation.tr("Easy mode — click to show all settings")
                            : Translation.tr("Advanced mode — click to switch to Easy mode (essentials only)")
                    }
                }

                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "lock"
                        iconSize: 20
                    }
                }
                RippleButton {
                    buttonRadius: Appearance.rounding.full
                    implicitWidth: 35
                    implicitHeight: 35
                    onClicked: root.close()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "close"
                        iconSize: 20
                    }
                }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: contentPadding
            Item {
                id: navRailWrapper
                Layout.fillHeight: true
                Layout.margins: 5
                implicitWidth: 168

                Flickable {
                    id: navRailFlickable
                    anchors.fill: parent
                    anchors.bottomMargin: navBottomActions.height + 8
                    contentHeight: navCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    ScrollBar.vertical: StyledScrollBar {
                        policy: ScrollBar.AlwaysOff
                    }

                    ColumnLayout {
                        id: navCol
                        width: parent.width
                        spacing: 0

                        Repeater {
                            id: navRepeater
                            model: root.visibleNavItems
                            delegate: Column {
                                id: navItem
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                readonly property color headerAccentColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colAccent
                                    : Appearance.colors.colPrimary

                                // ── Category header ──
                                Item {
                                    width: parent.width
                                    height: visible ? (navItem.index > 0 ? 32 : 20) : 0
                                    visible: navItem.modelData.type === "header"

                                    Behavior on height {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                    }

                                    StyledText {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        text: navItem.modelData.label || ""
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.smaller
                                            weight: Font.DemiBold
                                            capitalization: Font.AllUppercase
                                            letterSpacing: 1.1
                                        }
                                        color: navItem.headerAccentColor
                                        opacity: 0.85

                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                }

                                // ── Nav button ──
                                RippleButton {
                                    id: navBtn
                                    visible: navItem.modelData.type === "page"
                                    width: parent.width
                                    implicitHeight: visible ? 34 : 0
                                    z: 1

                                    readonly property int pageRealIndex: navItem.modelData.realIndex !== undefined ? navItem.modelData.realIndex : navItem.index

                                    buttonRadius: Appearance.zzzEverywhere
                                        ? Appearance.zzz.controlRadius
                                        : Math.min(width, height) / 2
                                    toggled: root.currentPage === pageRealIndex
                                    // Bgless doctrine: zzz selection reads through the sticker pill
                                    // below, not a Material ripple / opaque hover fill on this
                                    // Control's own background (which renders above the pill).
                                    rippleEnabled: !Appearance.zzzEverywhere
                                    colBackground: "transparent"
                                    colBackgroundToggled: "transparent"
                                    colBackgroundToggledHover: Appearance.zzzEverywhere
                                        ? "transparent"
                                        : Appearance.angelEverywhere
                                        ? Appearance.angel.colGlassCardHover
                                        : Appearance.inirEverywhere
                                            ? Appearance.inir.colLayer1Hover
                                            : Appearance.auroraEverywhere
                                                ? Appearance.aurora.colElevatedSurface
                                                : CF.ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 0.5)
                                    colBackgroundHover: Appearance.zzzEverywhere
                                        ? Appearance.zzz.paperAlt
                                        : Appearance.colors.colLayer1Hover

                                    onClicked: root.currentPage = pageRealIndex

                                    contentItem: Item {
                                        anchors.fill: parent

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            MaterialSymbol {
                                                text: navItem.modelData.icon || ""
                                                iconSize: 18
                                                color: navBtn.toggled
                                                    ? (Appearance.zzzEverywhere
                                                        ? Appearance.zzz.ink
                                                        : Appearance.inirEverywhere
                                                        ? Appearance.inir.colAccent
                                                        : Appearance.colors.colPrimary)
                                                    : Appearance.colors.colOnSurfaceVariant
                                                rotation: navItem.modelData.iconRotation || 0

                                                Behavior on color {
                                                    enabled: Appearance.animationsEnabled
                                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                }
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: navItem.modelData.name || ""
                                                font {
                                                    family: Appearance.font.family.main
                                                    pixelSize: Appearance.font.pixelSize.small
                                                    weight: navBtn.toggled ? Font.Medium : Font.Normal
                                                }
                                                color: navBtn.toggled
                                                    ? Appearance.colors.colOnLayer1
                                                    : Appearance.colors.colOnSurfaceVariant
                                                elide: Text.ElideRight

                                                Behavior on color {
                                                    enabled: Appearance.animationsEnabled
                                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Active indicator: pill travelling behind the active item
                        ZzzPlate {
                            id: sharedNavIndicator
                            z: -1
                            parent: navCol
                            x: 0
                            width: navCol.width
                            radius: Appearance.zzzEverywhere
                                ? (Appearance.zzz.round ? Appearance.zzz.controlRadius : 0)
                                : Appearance.rounding.small
                            chamfer: Appearance.zzzEverywhere && !Appearance.zzz.round ? Appearance.zzz.cutCorner : 0
                            fillColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                                 : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                                 : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                 : Appearance.zzzEverywhere ? Appearance.zzz.sticker
                                 : Appearance.colors.colPrimaryContainer
                            // No hairline in zzz: the stroke next to the accent bar read
                            // as two stacked vertical lines (matches SettingsOverlay.qml —
                            // zzz doctrine: separate by fill, not outline).
                            strokeColor: "transparent"
                            strokeWidth: 0

                            // ZZZ: solid vertical accent edge — the sticker fill alone
                            // reads as a hairline; the active item needs a real marker.
                            Rectangle {
                                visible: Appearance.zzzEverywhere
                                anchors.left: parent.left
                                anchors.leftMargin: Appearance.zzz.borderThick
                                anchors.verticalCenter: parent.verticalCenter
                                height: Math.max(0, parent.height * 0.62)
                                width: Appearance.zzz.borderThick * 3
                                color: Appearance.zzz.accent
                            }

                            Behavior on radius {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot }
                            }

                            property real targetY: 0
                            property real targetH: 0
                            property bool hasTarget: false

                            // Leading/trailing edges travel at different speeds, so the
                            // pill stretches toward the target and contracts on arrival.
                            property real edgeTop: targetY
                            property real edgeBottom: targetY + targetH
                            Behavior on edgeTop {
                                enabled: Appearance.animationsEnabled
                                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                            }
                            Behavior on edgeBottom {
                                enabled: Appearance.animationsEnabled
                                animation: NumberAnimation { duration: Math.round(Appearance.animation.elementResize.duration * 1.18); easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                            }

                            function updatePosition() {
                                for (var i = 0; i < navRepeater.count; i++) {
                                    var item = navRepeater.itemAt(i);
                                    if (item && item.modelData && item.modelData.type === "page" && item.modelData.realIndex === root.currentPage) {
                                        var btn = item.children[1];
                                        if (btn && btn.visible) {
                                            targetY = item.y + btn.y;
                                            targetH = btn.height;
                                            hasTarget = true;
                                            return;
                                        }
                                    }
                                }
                                hasTarget = false;
                            }

                            y: Math.min(edgeTop, edgeBottom)
                            height: hasTarget ? Math.abs(edgeBottom - edgeTop) : 0
                            opacity: hasTarget ? 1 : 0

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 4
                                width: 3
                                radius: 1.5
                                // ZZZ separates by fill, not outlines — the sticker plate above
                                // already carries the selection signal (matches SettingsOverlay.qml).
                                visible: !Appearance.zzzEverywhere
                                height: (parent.hasTarget && visible) ? parent.height * 0.5 : 0
                                color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                     : Appearance.inirEverywhere ? Appearance.inir.colAccent
                                     : Appearance.colors.colPrimary
                                Behavior on height {
                                    enabled: Appearance.animationsEnabled
                                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }

                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }

                            Connections {
                                target: root
                                function onCurrentPageChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                                function onVisibleNavItemsChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                            }
                            Connections {
                                target: navRepeater
                                function onCountChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                            }
                            Component.onCompleted: Qt.callLater(updatePosition)
                        }
                    }
                }

                // Bottom actions: config file + overlay mode
                ColumnLayout {
                    id: navBottomActions
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 2

                    RippleButton {
                        id: configFileBtn
                        property bool justCopied: false
                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover

                        onClicked: Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`)
                        altAction: () => {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                            configFileBtn.justCopied = true;
                            revertTextTimer.restart();
                        }

                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: configFileBtn.justCopied = false
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            MaterialSymbol {
                                text: configFileBtn.justCopied ? "check" : "edit"
                                iconSize: 18
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: configFileBtn.justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: Appearance.font.pixelSize.small
                                }
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        StyledToolTip {
                            position: "top"
                            text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                        }
                    }

                    RippleButton {
                        id: overlayToggleBtn
                        Layout.fillWidth: true
                        implicitHeight: 36
                        buttonRadius: Appearance.rounding.small
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover

                        onClicked: {
                            Config.setNestedValue("settingsUi.overlayMode", true)
                            settingsRestartTimer.restart()
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 10

                            MaterialSymbol {
                                text: "layers"
                                iconSize: 18
                                color: Appearance.colors.colOnSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Overlay")
                                font {
                                    family: Appearance.font.family.main
                                    pixelSize: Appearance.font.pixelSize.small
                                }
                                color: Appearance.colors.colOnSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }

                        StyledToolTip {
                            position: "top"
                            text: Translation.tr("Switch to overlay mode")
                        }
                    }
                }

                Timer {
                    id: settingsRestartTimer
                    interval: 500
                    onTriggered: {
                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings"])
                        Qt.quit()
                    }
                }
            }

            Rectangle { // Content container
                id: contentContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                // ZZZ: same bg2 plate + hairline as the overlay-mode content
                // field, so both settings modes read as the same surface.
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                     : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                     : Appearance.zzzEverywhere ? Appearance.zzz.bg2
                     : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                     : Appearance.colors.colSurfaceContainerLow
                radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                      : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                      : Appearance.rounding.windowRounding - root.contentPadding
                border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                            : Appearance.zzzEverywhere ? Appearance.zzz.borderThick
                            : Appearance.inirEverywhere ? 1 : 0
                border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.zzzEverywhere ? Appearance.zzz.hairline
                            : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                            : "transparent"

                // ── Page header: icon + name + description ──
                Item {
                    id: windowPageHeader
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 48
                    readonly property var meta: root.pages[root.currentPage] ?? {}

                    RowLayout {
                        id: windowPageHeaderRow
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 10

                        MaterialSymbol {
                            text: windowPageHeader.meta.icon ?? ""
                            rotation: windowPageHeader.meta.iconRotation ?? 0
                            iconSize: 20
                            color: Appearance.inirEverywhere ? Appearance.inir.colAccent : Appearance.colors.colPrimary
                        }

                        StyledText {
                            text: windowPageHeader.meta.name ?? ""
                            font {
                                family: Appearance.font.family.title
                                pixelSize: Appearance.font.pixelSize.normal
                                weight: Font.DemiBold
                            }
                            color: Appearance.colors.colOnLayer1
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: windowPageHeader.meta.desc ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            opacity: 0.85
                        }
                    }

                    Connections {
                        target: root
                        function onCurrentPageChanged() { if (Appearance.animationsEnabled) windowPageHeaderSwap.restart() }
                    }
                    SequentialAnimation {
                        id: windowPageHeaderSwap
                        NumberAnimation { target: windowPageHeaderRow; property: "opacity"; to: 0; duration: Appearance.animation.elementMoveFast.duration / 2; easing.type: Appearance.animation.elementMoveFast.type }
                        NumberAnimation { target: windowPageHeaderRow; property: "opacity"; to: 1; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
                    }

                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
                        height: 1
                        color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle : Appearance.m3colors.m3outlineVariant
                        opacity: 0.5
                    }
                }

                SettingsPageHost {
                    id: pagesStack
                    anchors { top: windowPageHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }

                    pages: root.pages
                    requestedIndex: root.currentPage
                    loadEnabled: Config.ready

                    // Loading indicator while the target page incubates
                    CircularProgress {
                        id: windowPageLoading
                        anchors.centerIn: parent
                        z: 10
                        readonly property bool isLoading: pagesStack.loading
                        opacity: isLoading ? 1 : 0
                        scale: isLoading ? 1 : 0.7
                        visible: opacity > 0
                        Behavior on opacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on scale {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                }

                // Search results overlay - Simple dropdown style
                Rectangle {
                    id: settingsSearchOverlay
                    anchors.fill: parent
                    visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length > 0
                    color: "transparent"
                    z: 100

                    // Click outside to close
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openSearchResult({})
                    }

                    // Results card
                    StyledRectangularShadow {
                        target: searchResultsCard
                    }
                    Rectangle {
                        id: searchResultsCard
                        width: Math.max(searchContainer.width, Math.min(parent.width - 40, 480))
                        height: Math.min(resultsListView.contentHeight + 16, 400)
                        // Centered under the search box, not the content pane
                        x: {
                            var dep = searchContainer.x + searchContainer.width + root.width;
                            var p = searchContainer.mapToItem(settingsSearchOverlay, 0, 0);
                            return Math.max(8, Math.min(p.x + (searchContainer.width - width) / 2, parent.width - width - 8));
                        }
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                             : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                             : Appearance.rounding.normal
                        color: "transparent"
                        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                                    : Appearance.inirEverywhere ? 1 : 1
                        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
                            : Appearance.m3colors.m3outlineVariant

                        GlassBackground {
                            anchors.fill: parent
                            radius: searchResultsCard.radius
                            screenX: searchResultsCard.mapToGlobal(0, 0).x
                            screenY: searchResultsCard.mapToGlobal(0, 0).y
                            screenWidth: Quickshell.screens[0]?.width ?? root.width
                            screenHeight: Quickshell.screens[0]?.height ?? root.height
                            hovered: false
                            fallbackColor: Appearance.colors.colLayer1
                            inirColor: Appearance.inir.colLayer2
                            auroraTransparency: Math.max(0.22, Appearance.aurora.popupTransparentize - 0.12)
                        }

                        layer.enabled: Appearance.effectsEnabled && !Appearance.auroraEverywhere
                        layer.effect: DropShadow {
                            color: Qt.rgba(0, 0, 0, 0.3)
                            radius: 12
                            samples: 13
                            verticalOffset: 4
                        }

                        ListView {
                            id: resultsListView
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            model: root.settingsSearchResults
                            clip: true
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up) {
                                    if (resultsListView.currentIndex > 0) {
                                        resultsListView.currentIndex--;
                                    } else {
                                        settingsSearchField.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (resultsListView.currentIndex < resultsListView.count - 1) {
                                        resultsListView.currentIndex++;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (resultsListView.currentIndex >= 0) {
                                        root.openSearchResult(root.settingsSearchResults[resultsListView.currentIndex]);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openSearchResult({});
                                    settingsSearchField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            delegate: RippleButton {
                                id: resultItem
                                required property var modelData
                                required property int index

                                width: resultsListView.width
                                implicitHeight: 52
                                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                                            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                                            : Appearance.rounding.small

                                colBackground: ListView.isCurrentItem
                                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                      : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                                      : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                                      : Appearance.colors.colPrimaryContainer)
                                    : "transparent"
                                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                                  : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                                  : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                                                  : Appearance.colors.colLayer2

                                Keys.forwardTo: [resultsListView]
                                onClicked: root.openSearchResult(modelData)

                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Page icon
                                    MaterialSymbol {
                                        text: SettingsPageRegistry.iconForPage(resultItem.modelData.pageIndex)
                                        iconSize: 20
                                        color: resultItem.ListView.isCurrentItem
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colPrimary
                                    }

                                    // Text content
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: resultItem.modelData.labelHighlighted || resultItem.modelData.label || ""
                                            textFormat: Text.StyledText
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: Appearance.font.pixelSize.small
                                                weight: Font.Medium
                                            }
                                            color: resultItem.ListView.isCurrentItem
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colOnLayer1
                                            elide: Text.ElideRight
                                        }

                                        // Breadcrumb path with arrows
                                        Row {
                                            Layout.fillWidth: true
                                            spacing: 4

                                            readonly property string sectionDisplay: {
                                                var sect = resultItem.modelData.section || "";
                                                var page = resultItem.modelData.pageName || "";
                                                var parts = sect.split(/\s*[·›]\s*/).filter(t => t.length > 0);
                                                if (parts.length > 1 && parts[0] === page) parts.shift();
                                                return parts.join(" › ");
                                            }
                                            StyledText {
                                                text: resultItem.modelData.pageName || ""
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                            MaterialSymbol {
                                                visible: parent.sectionDisplay.length > 0 && parent.sectionDisplay !== resultItem.modelData.pageName
                                                text: "chevron_right"
                                                iconSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.6
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            StyledText {
                                                visible: parent.sectionDisplay.length > 0 && parent.sectionDisplay !== resultItem.modelData.pageName
                                                text: parent.sectionDisplay
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: resultItem.ListView.isCurrentItem
                                                    ? Appearance.colors.colOnPrimaryContainer
                                                    : Appearance.colors.colSubtext
                                                opacity: 0.9
                                            }
                                        }
                                    }

                                    // Arrow
                                    MaterialSymbol {
                                        text: "arrow_forward"
                                        iconSize: 16
                                        color: resultItem.ListView.isCurrentItem
                                            ? Appearance.colors.colOnPrimaryContainer
                                            : Appearance.colors.colSubtext
                                        opacity: resultItem.hovered || resultItem.ListView.isCurrentItem ? 1 : 0
                                    }
                                }
                            }
                        }
                    }
                }

                // No results indicator (inline, not overlay)
                Rectangle {
                    id: noResultsCard
                    visible: root.settingsSearchText.length > 0 && root.settingsSearchResults.length === 0
                    x: {
                        var dep = searchContainer.x + searchContainer.width + root.width;
                        var p = searchContainer.mapToItem(parent, 0, 0);
                        return p.x + (searchContainer.width - width) / 2;
                    }
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    width: noResultsRow.implicitWidth + 24
                    height: 36
                    radius: Appearance.rounding.full
                    color: "transparent"
                    z: 100

                    GlassBackground {
                        anchors.fill: parent
                        radius: noResultsCard.radius
                        screenX: noResultsCard.mapToGlobal(0, 0).x
                        screenY: noResultsCard.mapToGlobal(0, 0).y
                        screenWidth: Quickshell.screens[0]?.width ?? root.width
                        screenHeight: Quickshell.screens[0]?.height ?? root.height
                        hovered: false
                        fallbackColor: Appearance.colors.colLayer1
                        inirColor: Appearance.inir.colLayer2
                        auroraTransparency: Math.max(0.22, Appearance.aurora.popupTransparentize - 0.12)
                    }

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
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

            }
        }
    }
}
