pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtMultimedia
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Scope {
    id: root

    property bool _presentedOpen: false
    property string activePreset: "silvia"
    property string selectedStyle: GlobalStates.sddmPickerStyle
    onSelectedStyleChanged: {
        if (GlobalStates.sddmPickerStyle !== root.selectedStyle) {
            GlobalStates.sddmPickerStyle = root.selectedStyle;
        }
    }
    readonly property string hubScript: Quickshell.shellPath("scripts/sddm/sddm-theme-hub")
    readonly property string currentUsername: Quickshell.env("USER") || "user"
    readonly property string userAvatarPath: "file://" + (Quickshell.env("HOME") || "") + "/.face.icon"
    property string currentSource: "community" // "local" | "community" | "wallhaven" | "live"
    property string currentCategory: "all"
    property string searchQuery: ""
    property int focusedIndex: 0
    property int _savedIndex: -1
    property bool isLoading: false
    property string installingId: ""
    property string previewMode: GlobalStates.sddmPreviewMode
    onPreviewModeChanged: {
        if (GlobalStates.sddmPreviewMode !== root.previewMode) {
            GlobalStates.sddmPreviewMode = root.previewMode;
        }
    }

    FontLoader { id: fontCrackedCode; source: Quickshell.shellPath("assets/fonts/CrackedCode.ttf") }
    FontLoader { id: fontOrientalChicken; source: Quickshell.shellPath("assets/fonts/OrientalChicken.ttf") }

    // Dynamic Lists from Hub
    property var localPresets: []
    property var communityPresets: []
    property var wallhavenPresets: []
    property var livePresets: []

    // Fallback Presets
    readonly property var fallbackLocalPresets: [
        {
            id: "silvia",
            name: "Silvia S15",
            subtitle: "JDM Animated Video Background",
            category: "video",
            tags: ["Video Loop", "JDM", "Anime"],
            preview: "file:///usr/share/sddm/themes/silent/previews/silvia.png",
            is_video: true,
            installed: true,
            position: "center-left",
            clock_color: "#000000",
            date_color: "#000000"
        },
        {
            id: "rei",
            name: "Rei Ayanami",
            subtitle: "Evangelion Cyber Video Loop",
            category: "video",
            tags: ["Video Loop", "Evangelion", "Cyber"],
            preview: "file:///usr/share/sddm/themes/silent/previews/rei.png",
            is_video: true,
            installed: true,
            position: "left",
            clock_color: "#00F0FF",
            date_color: "#00F0FF"
        },
        {
            id: "ken",
            name: "Ken Kaneki",
            subtitle: "Tokyo Ghoul Dark Aesthetic",
            category: "anime",
            tags: ["Anime Still", "Tokyo Ghoul", "Dark"],
            preview: "file:///usr/share/sddm/themes/silent/previews/ken.png",
            is_video: false,
            installed: true,
            position: "center",
            clock_color: "#FFFFFF",
            date_color: "#E53935"
        },
        {
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            subtitle: "Mocha Dark Pastel Theme",
            category: "catppuccin",
            tags: ["Catppuccin", "Mocha", "Dark"],
            preview: "file:///usr/share/sddm/themes/silent/previews/catppuccin-mocha.png",
            is_video: false,
            installed: true,
            position: "center",
            clock_color: "#CDD6F4",
            date_color: "#CBA6F7"
        },
        {
            id: "default",
            name: "Default Center",
            subtitle: "Clean Centered Minimalist Layout",
            category: "minimal",
            tags: ["Minimal", "Centered", "Modern"],
            preview: "file:///usr/share/sddm/themes/silent/previews/default.png",
            is_video: false,
            installed: true,
            position: "center",
            clock_color: "#FFFFFF",
            date_color: "#FFFFFF"
        }
    ]

    readonly property var activeSourceList: {
        if (root.currentSource === "local") {
            return (root.localPresets && root.localPresets.length > 0) ? root.localPresets : root.fallbackLocalPresets;
        } else if (root.currentSource === "community") {
            return root.communityPresets || [];
        } else if (root.currentSource === "wallhaven") {
            return root.wallhavenPresets || [];
        } else if (root.currentSource === "live") {
            return root.livePresets || [];
        }
        return [];
    }

    readonly property var filteredPresets: {
        const list = root.activeSourceList;
        return list.filter(p => {
            const matchCategory = (root.currentCategory === "all") ||
                (root.currentCategory === p.category) ||
                (p.tags && p.tags.some(t => t.toLowerCase().includes(root.currentCategory.toLowerCase())));

            const q = root.searchQuery.trim().toLowerCase();
            const matchSearch = (q.length === 0) ||
                (p.name && p.name.toLowerCase().includes(q)) ||
                (p.subtitle && p.subtitle.toLowerCase().includes(q)) ||
                (p.tags && p.tags.some(t => t.toLowerCase().includes(q))) ||
                (p.id && p.id.toLowerCase().includes(q));

            return matchCategory && matchSearch;
        });
    }

    readonly property var focusedPreset: {
        const list = root.filteredPresets;
        if (!list || list.length === 0) return null;
        if (root.focusedIndex >= 0 && root.focusedIndex < list.length) {
            return list[root.focusedIndex];
        }
        return list[0];
    }

    // ─── Process Fetchers ───
    Process {
        id: localFetcher
        command: ["python3", root.hubScript, "list-local"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    if (res.active) root.activePreset = res.active;
                    if (res.presets && Array.isArray(res.presets)) {
                        root.localPresets = res.presets;
                    }
                } catch (e) {
                    console.error("Local presets fetch error:", e);
                }
                if (root._savedIndex >= 0) {
                    root.focusedIndex = Math.min(root._savedIndex, Math.max(0, root.filteredPresets.length - 1));
                    root._savedIndex = -1;
                }
                root.isLoading = false;
            }
        }
    }

    Process {
        id: communityFetcher
        command: ["python3", root.hubScript, "list-community"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    if (res.active) root.activePreset = res.active;
                    if (res.presets && Array.isArray(res.presets)) {
                        root.communityPresets = res.presets;
                    }
                } catch (e) {
                    console.error("Community fetch error:", e);
                }
                if (root._savedIndex >= 0) {
                    root.focusedIndex = Math.min(root._savedIndex, Math.max(0, root.filteredPresets.length - 1));
                    root._savedIndex = -1;
                }
                root.isLoading = false;
            }
        }
    }

    Process {
        id: wallhavenFetcher
        command: ["python3", root.hubScript, "search-wallhaven", root.searchQuery.trim() || "cyberpunk", "--page", "1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    if (res.presets && Array.isArray(res.presets)) {
                        root.wallhavenPresets = res.presets;
                    }
                } catch (e) {
                    console.error("Wallhaven search error:", e);
                }
                if (root._savedIndex >= 0) {
                    root.focusedIndex = Math.min(root._savedIndex, Math.max(0, root.filteredPresets.length - 1));
                    root._savedIndex = -1;
                }
                root.isLoading = false;
            }
        }
    }

    Process {
        id: liveFetcher
        command: ["python3", root.hubScript, "search-live", root.searchQuery.trim() || "anime", "--page", "1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const res = JSON.parse(text);
                    if (res.presets && Array.isArray(res.presets)) {
                        root.livePresets = res.presets;
                    }
                } catch (e) {
                    console.error("Live video search error:", e);
                }
                if (root._savedIndex >= 0) {
                    root.focusedIndex = Math.min(root._savedIndex, Math.max(0, root.filteredPresets.length - 1));
                    root._savedIndex = -1;
                }
                root.isLoading = false;
            }
        }
    }

    Process {
        id: installerProcess
        property string targetPresetId: ""
        property bool autoPreview: false
        onExited: exitCode => {
            root.installingId = "";
            if (exitCode === 0) {
                root.activePreset = installerProcess.targetPresetId;
                Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "software-installed", "SDDM Theme Installed", "Theme " + installerProcess.targetPresetId + " is installed and applied!"]);
                // Refresh list without resetting focusedIndex
                root.reloadCurrentSource(root.focusedIndex);
                localFetcher.running = true;
                if (installerProcess.autoPreview) {
                    installerProcess.autoPreview = false;
                    root.testGreeter(installerProcess.targetPresetId);
                }
            } else {
                installerProcess.autoPreview = false;
                Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "dialog-error", "Install Failed", "Could not install SDDM theme."]);
            }
        }
    }

    Process {
        id: applyBgProcess
        property string targetPresetId: ""
        onExited: exitCode => {
            root.installingId = "";
            if (exitCode === 0) {
                Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "preferences-desktop-wallpaper", "SDDM Wallpaper Updated", "Updated background for " + applyBgProcess.targetPresetId + "!"]);
                // Refresh list without resetting focusedIndex
                root.reloadCurrentSource(root.focusedIndex);
                localFetcher.running = true;
            } else {
                Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "dialog-error", "Wallpaper Update Failed", "Could not apply background to " + applyBgProcess.targetPresetId]);
            }
        }
    }

    function reloadCurrentSource(keepIndex = -1): void {
        root.isLoading = true;
        if (keepIndex >= 0) {
            root._savedIndex = keepIndex;
        }
        if (root.currentSource === "local") {
            localFetcher.running = true;
        } else if (root.currentSource === "community") {
            communityFetcher.running = true;
        } else if (root.currentSource === "wallhaven") {
            wallhavenFetcher.running = true;
        } else if (root.currentSource === "live") {
            liveFetcher.running = true;
        }
    }

    function switchSource(newSource: string): void {
        if (root.currentSource === newSource) return;
        root.currentSource = newSource;
        GlobalStates.sddmPickerSource = newSource;
        root.currentCategory = "all";
        root.focusedIndex = 0;
        root.reloadCurrentSource();
    }

    function applyPreset(presetId: string): void {
        if (!presetId || presetId.length === 0) return;
        root.activePreset = presetId;
        Quickshell.execDetached(["python3", root.hubScript, "apply", presetId]);
        Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "preferences-desktop-theme", "SDDM Theme Applied", "Switched SDDM login theme to: " + presetId]);
    }

    function applyBackgroundItem(item: var): void {
        if (!item || !item.bg_url) return;
        const target = (root.selectedStyle && root.selectedStyle !== "auto") ? root.selectedStyle : root.activePreset;
        const finalTarget = (target === "center" || target === "left" || target === "right") ? "default" : (target === "active" ? root.activePreset : target);
        root.installingId = item.id;
        applyBgProcess.targetPresetId = finalTarget;

        const cmd = [
            "python3", root.hubScript, "apply-bg",
            "--bg-url", item.bg_url,
            "--preview-url", item.preview || item.preview_url || "",
            "--target-preset", finalTarget
        ];
        if (item.is_video === true) cmd.push("--is-video");

        applyBgProcess.command = cmd;
        applyBgProcess.running = true;
        Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "network-receive", "Setting SDDM Background", "Applying background to " + finalTarget + "..."]);
    }

    function installThemeItem(item: var): void {
        if (!item || !item.id || !item.bg_url) return;
        root.installingId = item.id;
        installerProcess.targetPresetId = item.id;

        const cmd = [
            "python3", root.hubScript, "install",
            "--id", item.id,
            "--bg-url", item.bg_url,
            "--preview-url", item.preview || item.preview_url || ""
        ];
        if (item.is_video === true) cmd.push("--is-video");
        if (item.clock_color) { cmd.push("--clock-color"); cmd.push(item.clock_color); }
        if (item.date_color) { cmd.push("--date-color"); cmd.push(item.date_color); }
        if (item.accent_color) { cmd.push("--accent-color"); cmd.push(item.accent_color); }
        if (item.position) { cmd.push("--position"); cmd.push(item.position); }
        if (root.selectedStyle && root.selectedStyle !== "auto") {
            cmd.push("--style");
            cmd.push(root.selectedStyle === "active" ? root.activePreset : root.selectedStyle);
        }

        installerProcess.command = cmd;
        installerProcess.running = true;
        Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "network-receive", "Installing SDDM Theme", "Downloading and generating preset for " + item.name + "..."]);
    }

    function installAndTest(item: var): void {
        installerProcess.autoPreview = true;
        installThemeItem(item);
    }

    function testGreeter(presetId = ""): void {
        const item = root.focusedPreset;
        if (item && !item.installed) {
            root.installAndTest(item);
            return;
        }
        if (presetId && presetId.length > 0) {
            root.applyPreset(presetId);
        }
        GlobalStates.sddmPickerOpen = false;
        Quickshell.execDetached(["sddm-greeter-qt6", "--test-mode", "--theme", "/usr/share/sddm/themes/silent"]);
        Quickshell.execDetached(["notify-send", "-a", "iNiR SDDM", "-i", "system-run", "SDDM Live Preview", "Launched SDDM greeter. Close with Super+Q or Alt+F4 when done."]);
    }

    function pickRandom(): void {
        const list = root.filteredPresets;
        if (!list || list.length === 0) return;
        const randomIndex = Math.floor(Math.random() * list.length);
        root.focusedIndex = randomIndex;
        const chosen = list[randomIndex];
        if (chosen) {
            if (chosen.installed) {
                root.applyPreset(chosen.id);
            } else {
                root.installThemeItem(chosen);
            }
        }
    }

    Connections {
        target: GlobalStates
        function onSddmPickerOpenChanged() {
            if (GlobalStates.sddmPickerOpen) {
                root.reloadCurrentSource(root.focusedIndex);
                Qt.callLater(() => { root._presentedOpen = true; });
            } else {
                root._presentedOpen = false;
                pickerLoader._closing = true;
                _closeTimer.restart();
            }
        }
        function onSddmPickerSourceChanged() {
            if (GlobalStates.sddmPickerSource && GlobalStates.sddmPickerSource.length > 0) {
                root.switchSource(GlobalStates.sddmPickerSource);
            }
        }
        function onSddmPreviewModeChanged() {
            if (root.previewMode !== GlobalStates.sddmPreviewMode) {
                root.previewMode = GlobalStates.sddmPreviewMode;
            }
        }
    }

    Timer {
        id: _closeTimer
        interval: 220
        onTriggered: pickerLoader._closing = false
    }

    Loader {
        id: pickerLoader
        active: GlobalStates.sddmPickerOpen || _closing
        property bool _closing: false

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: GlobalStates.focusedScreen ?? GlobalStates.primaryScreen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            color: "transparent"
            WlrLayershell.namespace: "inir:sddmPicker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.sddmPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.sddmPickerOpen = false
            }

            Item {
                id: contentBox
                anchors.centerIn: parent
                width: 1160
                height: 780

                MouseArea {
                    anchors.fill: parent
                }

                opacity: root._presentedOpen ? 1 : 0
                scale: root._presentedOpen ? 1 : 0.96

                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: root._presentedOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: root._presentedOpen ? 250 : 180
                        easing.type: Easing.OutCubic
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.sddmPickerOpen = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Slash) {
                        filterFieldInput.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        root.focusedIndex = Math.max(0, root.focusedIndex - 1);
                        filmstripGrid.positionViewAtIndex(root.focusedIndex, GridView.Contain);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        root.focusedIndex = Math.min(root.filteredPresets.length - 1, root.focusedIndex + 1);
                        filmstripGrid.positionViewAtIndex(root.focusedIndex, GridView.Contain);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Space) {
                        if (!filterFieldInput.activeFocus && !stagePassInput.activeFocus) {
                            root.previewMode = (root.previewMode === "lock") ? "login" : "lock";
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        const item = root.focusedPreset;
                        if (item) {
                            if (item.installed) root.applyPreset(item.id);
                            else root.installThemeItem(item);
                        }
                        event.accepted = true;
                    }
                }

                StyledRectangularShadow {
                    target: gridBackground
                    visible: !Appearance.editorialEverywhere && !Appearance.inirEverywhere && !Appearance.zzzEverywhere
                }

                GlassBackground {
                    id: gridBackground
                    anchors {
                        fill: parent
                        margins: Appearance.sizes.elevationMargin
                    }
                    focus: true
                    border.width: 1
                    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
                    fallbackColor: Appearance.colors.colLayer0
                    inirColor: Appearance.inir.colLayer0
                    auroraTransparency: Appearance.aurora.overlayTransparentize
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingLarge : 24

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 12

                        // ─── TOP ROW: Breadcrumb Title + Segmented Source Switcher ───
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 8

                            // Breadcrumb Title on Left
                            RowLayout {
                                spacing: 6
                                MaterialSymbol {
                                    text: "palette"
                                    iconSize: 20
                                    color: Appearance.colors.colPrimary
                                }

                                StyledText {
                                    text: "SDDM Hub"
                                    font.pixelSize: Appearance.font.pixelSize.large
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnLayer1
                                }

                                MaterialSymbol {
                                    text: "chevron_right"
                                    iconSize: 16
                                    color: Appearance.colors.colSubtext
                                }

                                StyledText {
                                    text: {
                                        if (root.currentSource === "local") return "Installed Themes";
                                        if (root.currentSource === "community") return "Community Store";
                                        if (root.currentSource === "wallhaven") return "Wallhaven API";
                                        return "Live 60fps Loops";
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colPrimary
                                }

                                Rectangle {
                                    implicitWidth: countBadgeText.implicitWidth + 12
                                    implicitHeight: 20
                                    radius: 10
                                    color: Appearance.colors.colSecondaryContainer
                                    StyledText {
                                        id: countBadgeText
                                        anchors.centerIn: parent
                                        text: String(root.filteredPresets.length)
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Segmented Source Switcher on Right (matching Iris style)
                            Rectangle {
                                implicitHeight: 36
                                implicitWidth: srcRowLayout.implicitWidth + 8
                                radius: 18
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.08)

                                RowLayout {
                                    id: srcRowLayout
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Repeater {
                                        model: [
                                            { id: "local", label: "Installed", icon: "inventory_2" },
                                            { id: "community", label: "Community", icon: "storefront" },
                                            { id: "wallhaven", label: "Wallhaven", icon: "travel_explore" },
                                            { id: "live", label: "Live 60fps", icon: "motion_photos_on" }
                                        ]

                                        delegate: RippleButton {
                                            id: srcTabPill
                                            required property var modelData
                                            implicitHeight: 30
                                            implicitWidth: srcTabPillContent.implicitWidth + 20
                                            buttonRadius: 15
                                            toggled: root.currentSource === srcTabPill.modelData.id

                                            colBackgroundToggled: Appearance.colors.colPrimary
                                            colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                            colRippleToggled: Appearance.colors.colPrimaryActive

                                            onClicked: root.switchSource(srcTabPill.modelData.id)

                                            contentItem: RowLayout {
                                                id: srcTabPillContent
                                                anchors.centerIn: parent
                                                spacing: 5

                                                MaterialSymbol {
                                                    text: srcTabPill.modelData.icon
                                                    iconSize: 15
                                                    color: srcTabPill.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                                                }

                                                StyledText {
                                                    text: srcTabPill.modelData.label
                                                    font.pixelSize: 11
                                                    font.weight: srcTabPill.toggled ? Font.Bold : Font.Normal
                                                    color: srcTabPill.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ─── SECOND ROW: Pill Search Field + Discovery Tags ───
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            spacing: 8

                            // Pill Search Bar
                            Rectangle {
                                Layout.preferredWidth: 320
                                Layout.preferredHeight: 34
                                radius: 17
                                color: Qt.rgba(0, 0, 0, 0.25)
                                border.width: 1
                                border.color: filterFieldInput.activeFocus ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.08)
                                clip: true

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 6

                                    MaterialSymbol {
                                        text: "search"
                                        iconSize: 16
                                        color: filterFieldInput.text.length > 0 ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                    }

                                    TextInput {
                                        id: filterFieldInput
                                        Layout.fillWidth: true
                                        text: root.searchQuery
                                        color: "white"
                                        font.pixelSize: 12
                                        clip: true
                                        onTextChanged: {
                                            root.searchQuery = text;
                                            if (root.currentSource === "local") root.focusedIndex = 0;
                                        }
                                        onAccepted: {
                                            if (root.currentSource !== "local") root.reloadCurrentSource();
                                        }

                                        Text {
                                            visible: filterFieldInput.text.length === 0
                                            text: root.currentSource === "local" ? "Filter presets…" : "Search online… (Enter)"
                                            color: Appearance.colors.colSubtext
                                            font.pixelSize: 12
                                        }
                                    }
                                }
                            }

                            // Category Tags Filmstrip
                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                Layout.fillHeight: false
                                orientation: ListView.Horizontal
                                clip: true
                                spacing: 5
                                boundsBehavior: Flickable.StopAtBounds

                                model: {
                                    if (root.currentSource === "local") {
                                        return [
                                            { id: "all", label: "All Presets" },
                                            { id: "video", label: "Video Loops" },
                                            { id: "anime", label: "Anime & JDM" },
                                            { id: "catppuccin", label: "Catppuccin" },
                                            { id: "minimal", label: "Minimal" }
                                        ];
                                    } else if (root.currentSource === "community") {
                                        return [
                                            { id: "all", label: "All Store" },
                                            { id: "video", label: "Live 60fps" },
                                            { id: "aesthetic", label: "Cyberpunk & Neon" },
                                            { id: "anime", label: "Anime & Lofi" },
                                            { id: "minimal", label: "Minimal & Nord" }
                                        ];
                                    } else if (root.currentSource === "wallhaven") {
                                        return [
                                            { id: "all", label: "Top Rated" },
                                            { id: "cyberpunk", label: "Cyberpunk" },
                                            { id: "anime", label: "Anime Art" },
                                            { id: "cars", label: "JDM Cars" },
                                            { id: "space", label: "Cosmic Space" },
                                            { id: "pixel", label: "Pixel Art" }
                                        ];
                                    } else {
                                        return [
                                            { id: "all", label: "All 60fps" },
                                            { id: "anime", label: "Anime" },
                                            { id: "cyberpunk", label: "Cyberpunk" },
                                            { id: "galaxy", label: "Galaxy & Cosmic" },
                                            { id: "rain", label: "Rainy Streets" }
                                        ];
                                    }
                                }

                                delegate: RippleButton {
                                    id: catPill
                                    required property var modelData
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    implicitHeight: 28
                                    implicitWidth: catPillText.implicitWidth + 16
                                    buttonRadius: 14
                                    toggled: root.currentCategory === catPill.modelData.id

                                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                                    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover

                                    onClicked: {
                                        root.currentCategory = catPill.modelData.id;
                                        root.focusedIndex = 0;
                                        if (root.currentSource === "wallhaven" && catPill.modelData.id !== "all") {
                                            root.searchQuery = catPill.modelData.id;
                                            root.reloadCurrentSource();
                                        } else if (root.currentSource === "live" && catPill.modelData.id !== "all") {
                                            root.searchQuery = catPill.modelData.id;
                                            root.reloadCurrentSource();
                                        }
                                    }

                                    contentItem: StyledText {
                                        id: catPillText
                                        anchors.centerIn: parent
                                        text: catPill.modelData.label
                                        font.pixelSize: 11
                                        font.weight: catPill.toggled ? Font.Bold : Font.Normal
                                        color: catPill.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                    }
                                }
                            }
                        }

                        // ─── MIDDLE BIGGER PREVIEW SECTION (Showcase Hero) ───
                        Rectangle {
                            id: showcaseHero
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredHeight: 430
                            Layout.minimumHeight: 300
                            radius: 18
                            clip: true
                            color: Qt.rgba(0, 0, 0, 0.45)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            property string previewMode: root.previewMode
                            onPreviewModeChanged: if (root.previewMode !== previewMode) root.previewMode = previewMode
                            Connections {
                                target: root
                                function onPreviewModeChanged() {
                                    if (showcaseHero.previewMode !== root.previewMode) {
                                        showcaseHero.previewMode = root.previewMode;
                                    }
                                }
                            }
                            property bool isAuthenticating: false
                            property bool authSuccess: false
                            property string currentSession: "niri"
                            property string currentLayout: "US"
                            property bool showSessionMenu: false
                            property bool showPowerMenu: false
                            property bool showLayoutMenu: false
                            property bool showVirtualKeyboard: false

                            readonly property var effectiveConfig: {
                                const preset = root.focusedPreset;
                                let cfg = Object.assign({
                                    lock_blur: 0,
                                    lock_brightness: 0.0,
                                    lock_saturation: 0.0,
                                    clock_position: "top-center",
                                    clock_align: "center",
                                    clock_font: "Cracked Code",
                                    clock_size: 90,
                                    clock_weight: 900,
                                    clock_color: "#FFFFFF",
                                    date_font: "Oriental Chicken",
                                    date_size: 20,
                                    date_weight: 600,
                                    date_color: "#FFFFFF",
                                    date_margin_top: -10,
                                    message_display: true,
                                    message_text: "Press any key or click to sign in",
                                    message_color: "#FFFFFF",
                                    login_blur: 0,
                                    login_brightness: 0.0,
                                    login_saturation: 0.0,
                                    login_position: "center",
                                    login_margin: -1,
                                    avatar_shape: "circle",
                                    avatar_border_color: "#FFFFFF",
                                    avatar_border_size: 2,
                                    username_font: "Oriental Chicken",
                                    username_size: 16,
                                    username_color: "#FFFFFF",
                                    password_width: 160,
                                    password_height: 32,
                                    password_bg: "#11111B",
                                    password_color: "#FFFFFF",
                                    password_border_color: Qt.rgba(1, 1, 1, 0.2),
                                    password_radius_left: 10,
                                    password_radius_right: 0,
                                    button_bg: (preset?.accent_color || Appearance.colors.colPrimary),
                                    button_color: "#000000",
                                    button_radius_left: 0,
                                    button_radius_right: 10
                                }, (preset && preset.config) ? preset.config : {});

                                // Style override
                                const st = root.selectedStyle || "auto";
                                if (st === "active") {
                                    const act = root.localPresets ? root.localPresets.find(p => p.id === root.activePreset) : null;
                                    if (act && act.config) cfg = Object.assign({}, act.config);
                                } else if (st !== "auto") {
                                    let match = root.localPresets ? root.localPresets.find(p => p.id === st || p.id === (st + "-live") || p.id === ("catppuccin-" + st)) : null;
                                    if (!match && root.communityPresets) {
                                        match = root.communityPresets.find(p => p.id === st || p.id === (st + "-live") || p.id === ("catppuccin-" + st));
                                    }
                                    if (match && match.config) {
                                        cfg = Object.assign({}, match.config);
                                    } else if (st === "left" || st === "default-left") {
                                        cfg.clock_position = "center-left";
                                        cfg.login_position = "left";
                                    } else if (st === "right" || st === "default-right") {
                                        cfg.clock_position = "center-right";
                                        cfg.login_position = "right";
                                    } else if (st === "center" || st === "default") {
                                        cfg.clock_position = "top-center";
                                        cfg.login_position = "center";
                                    } else if (st === "cyberpunk" || st === "cyberpunk-edge") {
                                        cfg.clock_position = "center-left";
                                        cfg.clock_color = "#FCEE0A";
                                        cfg.date_color = "#00F0FF";
                                        cfg.login_position = "left";
                                        cfg.lock_blur = 0;
                                        cfg.login_blur = 0;
                                        cfg.password_border_color = "#FCEE0A";
                                        cfg.button_bg = "#FCEE0A";
                                        cfg.button_color = "#000000";
                                    } else if (st === "gruvbox" || st === "gruvbox-retro") {
                                        cfg.clock_position = "center-left";
                                        cfg.clock_color = "#FABD2F";
                                        cfg.date_color = "#EBDBB2";
                                        cfg.login_position = "left";
                                        cfg.lock_blur = 0;
                                        cfg.login_blur = 0;
                                    } else if (st === "nordic" || st === "nordic-frost") {
                                        cfg.clock_position = "top-center";
                                        cfg.clock_color = "#ECEFF4";
                                        cfg.date_color = "#88C0D0";
                                        cfg.login_position = "center";
                                        cfg.lock_blur = 20;
                                        cfg.button_bg = "#88C0D0";
                                        cfg.password_border_color = "#88C0D0";
                                    } else if (st === "dracula" || st === "dracula-gothic") {
                                        cfg.clock_position = "top-center";
                                        cfg.clock_color = "#F8F8F2";
                                        cfg.date_color = "#BD93F9";
                                        cfg.login_position = "center";
                                        cfg.lock_blur = 20;
                                        cfg.button_bg = "#FF79C6";
                                        cfg.password_border_color = "#BD93F9";
                                    }
                                }
                                return cfg;
                            }

                            function testAuth(): void {
                                if (showcaseHero.isAuthenticating) return;
                                showcaseHero.isAuthenticating = true;
                                simAuthTimer.restart();
                            }

                            Timer {
                                id: simAuthTimer
                                interval: 850
                                onTriggered: {
                                    showcaseHero.isAuthenticating = false;
                                    showcaseHero.authSuccess = true;
                                    simSuccessTimer.restart();
                                }
                            }

                            Timer {
                                id: simSuccessTimer
                                interval: 750
                                onTriggered: {
                                    showcaseHero.authSuccess = false;
                                    showcaseHero.previewMode = "lock";
                                    stagePassInput.text = "";
                                }
                            }

                            // Ambient blurred backdrop
                            Image {
                                id: ambientBg
                                anchors.fill: parent
                                source: root.focusedPreset ? (root.focusedPreset.preview || root.focusedPreset.preview_url || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                opacity: 0.22
                                asynchronous: true
                                smooth: true
                                cache: true
                            }

                            // Loading state inside hero
                            Rectangle {
                                anchors.centerIn: parent
                                z: 30
                                visible: root.isLoading
                                implicitWidth: 160
                                implicitHeight: 50
                                radius: 25
                                color: Qt.rgba(0, 0, 0, 0.8)
                                border.width: 1
                                border.color: Appearance.colors.colPrimary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    MaterialSymbol {
                                        text: "autorenew"
                                        iconSize: 20
                                        color: Appearance.colors.colPrimary
                                        RotationAnimation on rotation {
                                            loops: Animation.Infinite
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            running: root.isLoading
                                        }
                                    }
                                    StyledText {
                                        text: "Loading themes…"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: "white"
                                    }
                                }
                            }

                            // ─── CENTER 16:9 SCREEN STAGE (Mathematically Zero Cropping) ───
                            Item {
                                id: screenStage
                                anchors.centerIn: parent
                                width: Math.round(Math.min(parent.width - 24, (parent.height - 20) * (16 / 9)))
                                height: Math.round(Math.min(parent.height - 20, (parent.width - 24) * (9 / 16)))
                                clip: true

                                // Stage Bezel / Border
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: "#08080C"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.15)
                                    z: 1
                                }

                                // Full 16:9 Wallpaper
                                Image {
                                    id: stageWallpaper
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    source: root.focusedPreset ? (root.focusedPreset.preview || root.focusedPreset.preview_url || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    cache: true
                                    z: 2
                                }

                                // Live 60fps Video Loop
                                Loader {
                                    id: stageVideoLoader
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    z: 3
                                    active: (root.focusedPreset?.video_path && root.focusedPreset.video_path.length > 0)
                                    sourceComponent: Video {
                                        source: (root.focusedPreset?.video_path && root.focusedPreset.video_path.length > 0) ? ("file://" + root.focusedPreset.video_path) : ""
                                        fillMode: VideoOutput.PreserveAspectCrop
                                        loops: MediaPlayer.Infinite
                                        muted: true
                                        autoPlay: true
                                    }
                                }

                                // ─── AUTHENTIC SDDM BACKGROUND EFFECTS ───
                                MultiEffect {
                                    id: stageMultiEffect
                                    source: stageWallpaper
                                    anchors.fill: stageWallpaper
                                    z: 4
                                    visible: stageWallpaper.status === Image.Ready && !stageVideoLoader.active
                                    blurEnabled: blurMax > 0
                                    blur: blurMax > 0 ? 1.0 : 0.0
                                    blurMax: (root.previewMode === "login") ? (showcaseHero.effectiveConfig.login_blur || 0) :
                                             (showcaseHero.effectiveConfig.lock_blur || 0)
                                    brightness: (root.previewMode === "login") ? (showcaseHero.effectiveConfig.login_brightness || 0.0) :
                                                (showcaseHero.effectiveConfig.lock_brightness || 0.0)
                                    saturation: (root.previewMode === "login") ? (showcaseHero.effectiveConfig.login_saturation || 0.0) :
                                                (showcaseHero.effectiveConfig.lock_saturation || 0.0)
                                    autoPaddingEnabled: false

                                    Behavior on blurMax { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
                                    Behavior on brightness { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }
                                }

                                // Scrim / Dim overlay (applies over wallpaper or live video)
                                Rectangle {
                                    id: stageDimOverlay
                                    anchors.fill: parent
                                    z: 5
                                    color: Qt.rgba(0, 0, 0, (root.previewMode === "login") ? ((showcaseHero.effectiveConfig.login_blur > 0) ? 0.35 : 0.1) : ((showcaseHero.effectiveConfig.lock_blur > 0) ? 0.25 : 0.05))
                                    Behavior on color { ColorAnimation { duration: 350 } }
                                }

                                // ─── STATE 1: Authentic Lock Screen ───
                                MouseArea {
                                    id: stageLockArea
                                    anchors.fill: parent
                                    z: 7
                                    cursorShape: Qt.PointingHandCursor
                                    visible: root.previewMode === "lock"
                                    opacity: root.previewMode === "lock" ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }
                                    onClicked: root.previewMode = "login"

                                    ColumnLayout {
                                        id: lockTimeCol
                                        anchors {
                                            verticalCenter: (showcaseHero.effectiveConfig.clock_position === "center" || showcaseHero.effectiveConfig.clock_position === "center-left" || showcaseHero.effectiveConfig.clock_position === "center-right") ? parent.verticalCenter : undefined
                                            top: (showcaseHero.effectiveConfig.clock_position === "top-center" || showcaseHero.effectiveConfig.clock_position === "top-left" || showcaseHero.effectiveConfig.clock_position === "top-right") ? parent.top : undefined
                                            topMargin: Math.round(screenStage.height * 0.12)
                                            bottom: (showcaseHero.effectiveConfig.clock_position === "bottom-center" || showcaseHero.effectiveConfig.clock_position === "bottom-left" || showcaseHero.effectiveConfig.clock_position === "bottom-right") ? parent.bottom : undefined
                                            bottomMargin: Math.round(screenStage.height * 0.12)
                                            left: (showcaseHero.effectiveConfig.clock_position.includes("left") || showcaseHero.effectiveConfig.clock_position === "left") ? parent.left : undefined
                                            leftMargin: Math.round(screenStage.width * 0.08)
                                            right: (showcaseHero.effectiveConfig.clock_position.includes("right") || showcaseHero.effectiveConfig.clock_position === "right") ? parent.right : undefined
                                            rightMargin: Math.round(screenStage.width * 0.08)
                                            horizontalCenter: (showcaseHero.effectiveConfig.clock_position === "center" || showcaseHero.effectiveConfig.clock_position === "top-center" || showcaseHero.effectiveConfig.clock_position === "bottom-center") ? parent.horizontalCenter : undefined
                                        }
                                        spacing: Math.round((showcaseHero.effectiveConfig.date_margin_top !== undefined ? showcaseHero.effectiveConfig.date_margin_top : -12) * (screenStage.height / 1080.0))

                                        StyledText {
                                            Layout.alignment: (showcaseHero.effectiveConfig.clock_position.includes("left")) ? Qt.AlignLeft :
                                                              (showcaseHero.effectiveConfig.clock_position.includes("right")) ? Qt.AlignRight : Qt.AlignHCenter
                                            text: Qt.formatDateTime(new Date(), "hh:mm")
                                            font.family: (showcaseHero.effectiveConfig.clock_font === "Cracked Code" && fontCrackedCode.name.length > 0) ? fontCrackedCode.name :
                                                         (showcaseHero.effectiveConfig.clock_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name :
                                                         (showcaseHero.effectiveConfig.clock_font || "Cracked Code")
                                            font.pixelSize: Math.round(screenStage.height * ((showcaseHero.effectiveConfig.clock_size || 120) / 1080.0 * 1.45))
                                            font.weight: showcaseHero.effectiveConfig.clock_weight ? showcaseHero.effectiveConfig.clock_weight : Font.Black
                                            color: showcaseHero.effectiveConfig.clock_color || "#FFFFFF"
                                            style: Text.Outline
                                            styleColor: (showcaseHero.effectiveConfig.clock_color === "#000000" || showcaseHero.effectiveConfig.clock_color === "#000") ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.75)
                                        }

                                        StyledText {
                                            Layout.alignment: (showcaseHero.effectiveConfig.clock_position.includes("left")) ? Qt.AlignLeft :
                                                              (showcaseHero.effectiveConfig.clock_position.includes("right")) ? Qt.AlignRight : Qt.AlignHCenter
                                            text: Qt.formatDateTime(new Date(), "dddd, MMMM dd, yyyy")
                                            font.family: (showcaseHero.effectiveConfig.date_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name :
                                                         (showcaseHero.effectiveConfig.date_font === "Cracked Code" && fontCrackedCode.name.length > 0) ? fontCrackedCode.name :
                                                         (showcaseHero.effectiveConfig.date_font || "Oriental Chicken")
                                            font.pixelSize: Math.max(12, Math.round(screenStage.height * ((showcaseHero.effectiveConfig.date_size || 25) / 1080.0 * 1.55)))
                                            font.weight: showcaseHero.effectiveConfig.date_weight ? showcaseHero.effectiveConfig.date_weight : Font.DemiBold
                                            color: showcaseHero.effectiveConfig.date_color || "#FFFFFF"
                                            style: Text.Outline
                                            styleColor: (showcaseHero.effectiveConfig.date_color === "#000000" || showcaseHero.effectiveConfig.date_color === "#000") ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.75)
                                        }
                                    }

                                    // Authentic SDDM bottom lock message with enter.svg icon
                                    RowLayout {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 18
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        spacing: 6
                                        visible: showcaseHero.effectiveConfig.message_display !== false
                                        Image {
                                            source: "file:///usr/share/sddm/themes/silent/icons/enter.svg"
                                            sourceSize: Qt.size(15, 15)
                                            width: 15
                                            height: 15
                                        }
                                        StyledText {
                                            text: showcaseHero.effectiveConfig.message_text || "Press any key or click to sign in"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: showcaseHero.effectiveConfig.message_color || Qt.rgba(1, 1, 1, 0.9)
                                            style: Text.Outline
                                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                                        }
                                    }
                                }

                                // ─── STATE 2: Authentic SDDM Login Screen ───
                                Item {
                                    id: stageLoginArea
                                    anchors.fill: parent
                                    z: 8
                                    visible: root.previewMode === "login"
                                    opacity: root.previewMode === "login" ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }

                                    // Click background to dismiss open menus
                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: {
                                            showcaseHero.showSessionMenu = false;
                                            showcaseHero.showPowerMenu = false;
                                            showcaseHero.showLayoutMenu = false;
                                        }
                                    }

                                    // Back to Lock Screen Button (Top-Left)
                                    RippleButton {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.margins: 12
                                        implicitHeight: 24
                                        implicitWidth: backLockRow.implicitWidth + 14
                                        buttonRadius: 12
                                        colBackground: Qt.rgba(0, 0, 0, 0.65)
                                        colBackgroundHover: Qt.rgba(0, 0, 0, 0.85)
                                        onClicked: {
                                            showcaseHero.showSessionMenu = false;
                                            showcaseHero.showPowerMenu = false;
                                            showcaseHero.showLayoutMenu = false;
                                            showcaseHero.showVirtualKeyboard = false;
                                            root.previewMode = "lock";
                                        }
                                        contentItem: RowLayout {
                                            id: backLockRow
                                            anchors.centerIn: parent
                                            spacing: 4
                                            MaterialSymbol { text: "arrow_back"; iconSize: 13; color: "white" }
                                            StyledText { text: "Lock Screen"; font.pixelSize: 10; font.weight: Font.DemiBold; color: "white" }
                                        }
                                    }

                                    // ─── Reusable Password Box & Spinner Component ───
                                    Component {
                                        id: stagePasswordBoxComp
                                        ColumnLayout {
                                            spacing: 6

                                            Rectangle {
                                                id: passwordPillBar
                                                visible: !showcaseHero.isAuthenticating
                                                implicitWidth: Math.max(170, Math.round(screenStage.width * ((showcaseHero.effectiveConfig.password_width || 170) / 1100.0)))
                                                implicitHeight: 32
                                                radius: 16
                                                clip: true
                                                color: showcaseHero.effectiveConfig.password_bg || Qt.rgba(0, 0, 0, 0.6)
                                                border.width: 1
                                                border.color: showcaseHero.effectiveConfig.password_border_color || Qt.rgba(1, 1, 1, 0.25)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    spacing: 0

                                                    Item {
                                                        Layout.fillWidth: true
                                                        Layout.fillHeight: true

                                                        RowLayout {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 10
                                                            anchors.rightMargin: 6
                                                            spacing: 6

                                                            Image {
                                                                source: "file:///usr/share/sddm/themes/silent/icons/password.svg"
                                                                sourceSize: Qt.size(13, 13)
                                                                width: 13
                                                                height: 13
                                                            }

                                                            TextInput {
                                                                id: stagePassInput
                                                                Layout.fillWidth: true
                                                                verticalAlignment: TextInput.AlignVCenter
                                                                echoMode: TextInput.Password
                                                                color: showcaseHero.effectiveConfig.password_color || "white"
                                                                font.family: (showcaseHero.effectiveConfig.username_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name : "RedHatDisplay"
                                                                font.pixelSize: 11
                                                                clip: true
                                                                onAccepted: showcaseHero.testAuth()

                                                                Text {
                                                                    visible: stagePassInput.text.length === 0
                                                                    anchors.verticalCenter: parent.verticalCenter
                                                                    text: "Password"
                                                                    color: Qt.rgba(128/255, 128/255, 128/255, 0.75)
                                                                    font.pixelSize: 11
                                                                }
                                                            }
                                                        }
                                                    }

                                                    Rectangle {
                                                        implicitWidth: 32
                                                        Layout.fillHeight: true
                                                        color: arrowBtnArea.containsMouse ? (showcaseHero.effectiveConfig.button_bg || Appearance.colors.colPrimaryHover) : (showcaseHero.effectiveConfig.button_bg || Qt.rgba(1, 1, 1, 0.25))

                                                        MouseArea {
                                                            id: arrowBtnArea
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: showcaseHero.testAuth()
                                                        }

                                                        Image {
                                                            anchors.centerIn: parent
                                                            source: "file:///usr/share/sddm/themes/silent/icons/arrow-right.svg"
                                                            sourceSize: Qt.size(14, 14)
                                                            width: 14
                                                            height: 14
                                                        }
                                                    }
                                                }
                                            }

                                            // Authentic SDDM Spinner
                                            RowLayout {
                                                Layout.alignment: Qt.AlignHCenter
                                                spacing: 8
                                                visible: showcaseHero.isAuthenticating

                                                Image {
                                                    source: "file:///usr/share/sddm/themes/silent/icons/spinner.svg"
                                                    sourceSize: Qt.size(20, 20)
                                                    width: 20
                                                    height: 20
                                                    RotationAnimation on rotation {
                                                        running: showcaseHero.isAuthenticating
                                                        loops: Animation.Infinite
                                                        from: 0
                                                        to: 360
                                                        duration: 900
                                                    }
                                                }

                                                StyledText {
                                                    text: showcaseHero.authSuccess ? "✓ Authenticated" : "Logging in…"
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                    color: showcaseHero.authSuccess ? "#4CAF50" : "white"
                                                }
                                            }
                                        }
                                    }

                                    // ─── LOGIN CONTAINER (Scales 0.5 -> 1.0 on unlock) ───
                                    Item {
                                        id: stageLoginContainer
                                        width: (loginPos === "center") ? centerLoginCol.implicitWidth :
                                               (loginPos === "right" ? rightLoginRow.implicitWidth : leftLoginRow.implicitWidth)
                                        height: (loginPos === "center") ? centerLoginCol.implicitHeight :
                                                (loginPos === "right" ? rightLoginRow.implicitHeight : leftLoginRow.implicitHeight)
                                        scale: (root.previewMode === "login") ? 1.0 : 0.5
                                        Behavior on scale {
                                            NumberAnimation { duration: 220; easing.type: Easing.OutBack }
                                        }

                                        readonly property string loginPos: showcaseHero.effectiveConfig.login_position || "center"

                                        anchors {
                                            verticalCenter: parent.verticalCenter
                                            left: (loginPos.includes("left") || loginPos === "left") ? parent.left : undefined
                                            leftMargin: (loginPos.includes("left") || loginPos === "left") ? Math.round(screenStage.width * 0.08) : 0
                                            right: (loginPos.includes("right") || loginPos === "right") ? parent.right : undefined
                                            rightMargin: (loginPos.includes("right") || loginPos === "right") ? Math.round(screenStage.width * 0.08) : 0
                                            horizontalCenter: (loginPos === "center") ? parent.horizontalCenter : undefined
                                        }

                                        // Left layout: Horizontal (Avatar on Left, Credentials on Right)
                                        RowLayout {
                                            id: leftLoginRow
                                            spacing: 16
                                            visible: stageLoginContainer.loginPos !== "right" && stageLoginContainer.loginPos !== "center"

                                            Rectangle {
                                                width: 64
                                                height: 64
                                                radius: (showcaseHero.effectiveConfig.avatar_shape === "circle" || !showcaseHero.effectiveConfig.avatar_shape) ? 32 : 10
                                                color: "#181825"
                                                border.width: showcaseHero.effectiveConfig.avatar_border_size || 2
                                                border.color: showcaseHero.effectiveConfig.avatar_border_color || "#FFFFFF"
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: root.userAvatarPath
                                                    fillMode: Image.PreserveAspectCrop
                                                    smooth: true
                                                }
                                            }

                                            ColumnLayout {
                                                spacing: 6
                                                StyledText {
                                                    text: root.currentUsername
                                                    font.family: (showcaseHero.effectiveConfig.username_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name :
                                                                 (showcaseHero.effectiveConfig.username_font || "Oriental Chicken")
                                                    font.pixelSize: Math.max(12, Math.round(screenStage.height * ((showcaseHero.effectiveConfig.username_size || 18) / 1080.0 * 1.8)))
                                                    font.weight: Font.Bold
                                                    color: showcaseHero.effectiveConfig.username_color || "#FFFFFF"
                                                    style: Text.Outline
                                                    styleColor: (showcaseHero.effectiveConfig.username_color === "#000000" || showcaseHero.effectiveConfig.username_color === "#000") ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.7)
                                                }
                                                Loader {
                                                    sourceComponent: stagePasswordBoxComp
                                                }
                                            }
                                        }

                                        // Right layout: Horizontal (Credentials on Left, Avatar on Right)
                                        RowLayout {
                                            id: rightLoginRow
                                            spacing: 16
                                            visible: stageLoginContainer.loginPos === "right" || stageLoginContainer.loginPos.includes("right")

                                            ColumnLayout {
                                                spacing: 6
                                                Layout.alignment: Qt.AlignRight
                                                StyledText {
                                                    Layout.alignment: Qt.AlignRight
                                                    text: root.currentUsername
                                                    font.family: (showcaseHero.effectiveConfig.username_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name :
                                                                 (showcaseHero.effectiveConfig.username_font || "Oriental Chicken")
                                                    font.pixelSize: Math.max(12, Math.round(screenStage.height * ((showcaseHero.effectiveConfig.username_size || 18) / 1080.0 * 1.8)))
                                                    font.weight: Font.Bold
                                                    color: showcaseHero.effectiveConfig.username_color || "#FFFFFF"
                                                    style: Text.Outline
                                                    styleColor: (showcaseHero.effectiveConfig.username_color === "#000000" || showcaseHero.effectiveConfig.username_color === "#000") ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.7)
                                                }
                                                Loader {
                                                    sourceComponent: stagePasswordBoxComp
                                                }
                                            }

                                            Rectangle {
                                                width: 64
                                                height: 64
                                                radius: (showcaseHero.effectiveConfig.avatar_shape === "circle" || !showcaseHero.effectiveConfig.avatar_shape) ? 32 : 10
                                                color: "#181825"
                                                border.width: showcaseHero.effectiveConfig.avatar_border_size || 2
                                                border.color: showcaseHero.effectiveConfig.avatar_border_color || "#FFFFFF"
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: root.userAvatarPath
                                                    fillMode: Image.PreserveAspectCrop
                                                    smooth: true
                                                }
                                            }
                                        }

                                        // Center layout: Vertical Stack (Avatar on Top, Credentials Below)
                                        ColumnLayout {
                                            id: centerLoginCol
                                            spacing: 8
                                            visible: stageLoginContainer.loginPos === "center"

                                            Rectangle {
                                                Layout.alignment: Qt.AlignHCenter
                                                width: 64
                                                height: 64
                                                radius: (showcaseHero.effectiveConfig.avatar_shape === "circle" || !showcaseHero.effectiveConfig.avatar_shape) ? 32 : 10
                                                color: "#181825"
                                                border.width: showcaseHero.effectiveConfig.avatar_border_size || 2
                                                border.color: showcaseHero.effectiveConfig.avatar_border_color || "#FFFFFF"
                                                clip: true
                                                Image {
                                                    anchors.fill: parent
                                                    source: root.userAvatarPath
                                                    fillMode: Image.PreserveAspectCrop
                                                    smooth: true
                                                }
                                            }

                                            StyledText {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: root.currentUsername
                                                font.family: (showcaseHero.effectiveConfig.username_font === "Oriental Chicken" && fontOrientalChicken.name.length > 0) ? fontOrientalChicken.name :
                                                             (showcaseHero.effectiveConfig.username_font || "Oriental Chicken")
                                                font.pixelSize: Math.max(12, Math.round(screenStage.height * ((showcaseHero.effectiveConfig.username_size || 18) / 1080.0 * 1.8)))
                                                font.weight: Font.Bold
                                                color: showcaseHero.effectiveConfig.username_color || "#FFFFFF"
                                                style: Text.Outline
                                                styleColor: (showcaseHero.effectiveConfig.username_color === "#000000" || showcaseHero.effectiveConfig.username_color === "#000") ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(0, 0, 0, 0.7)
                                            }

                                            Loader {
                                                Layout.alignment: Qt.AlignHCenter
                                                sourceComponent: stagePasswordBoxComp
                                            }
                                        }
                                    }

                                    // ─── AUTHENTIC SDDM MENU AREA BUTTONS ───

                                    // 1. BOTTOM-LEFT: Session Selector (Niri, Hyprland, Plasma, GNOME)
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 12
                                        implicitHeight: 28
                                        implicitWidth: sessionRow.implicitWidth + 16
                                        radius: 6
                                        color: showcaseHero.showSessionMenu ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.2)

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                showcaseHero.showSessionMenu = !showcaseHero.showSessionMenu;
                                                showcaseHero.showPowerMenu = false;
                                                showcaseHero.showLayoutMenu = false;
                                            }
                                        }

                                        RowLayout {
                                            id: sessionRow
                                            anchors.centerIn: parent
                                            spacing: 6
                                            Image {
                                                source: "file:///usr/share/sddm/themes/silent/icons/sessions/" + showcaseHero.currentSession + ".svg"
                                                sourceSize: Qt.size(14, 14)
                                                width: 14
                                                height: 14
                                            }
                                            StyledText {
                                                text: showcaseHero.currentSession
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: "white"
                                            }
                                            MaterialSymbol {
                                                text: showcaseHero.showSessionMenu ? "arrow_drop_up" : "arrow_drop_down"
                                                iconSize: 14
                                                color: "white"
                                            }
                                        }
                                    }

                                    // Session Dropdown
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 12
                                        anchors.bottomMargin: 44
                                        implicitWidth: 140
                                        implicitHeight: sessionListCol.implicitHeight + 8
                                        radius: 8
                                        color: "#181825"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.25)
                                        visible: showcaseHero.showSessionMenu
                                        z: 30

                                        ColumnLayout {
                                            id: sessionListCol
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 2

                                            Repeater {
                                                model: [
                                                    { id: "niri", name: "niri (Wayland)" },
                                                    { id: "hyprland", name: "Hyprland" },
                                                    { id: "plasma", name: "Plasma" },
                                                    { id: "gnome", name: "GNOME" }
                                                ]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 26
                                                    radius: 5
                                                    color: sessItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : (showcaseHero.currentSession === modelData.id ? Qt.rgba(1, 1, 1, 0.12) : "transparent")

                                                    MouseArea {
                                                        id: sessItemArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            showcaseHero.currentSession = modelData.id;
                                                            showcaseHero.showSessionMenu = false;
                                                        }
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 6
                                                        spacing: 6
                                                        Image {
                                                            source: "file:///usr/share/sddm/themes/silent/icons/sessions/" + modelData.id + ".svg"
                                                            sourceSize: Qt.size(14, 14)
                                                            width: 14; height: 14
                                                        }
                                                        StyledText {
                                                            text: modelData.name
                                                            font.pixelSize: 10
                                                            color: "white"
                                                            font.weight: showcaseHero.currentSession === modelData.id ? Font.Bold : Font.Normal
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // 2. BOTTOM-RIGHT: Keyboard Layout, Virtual Keyboard, Power Button
                                    RowLayout {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 12
                                        spacing: 6

                                        // Keyboard Layout
                                        Rectangle {
                                            implicitHeight: 28
                                            implicitWidth: layoutRow.implicitWidth + 14
                                            radius: 6
                                            color: showcaseHero.showLayoutMenu ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.2)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    showcaseHero.showLayoutMenu = !showcaseHero.showLayoutMenu;
                                                    showcaseHero.showPowerMenu = false;
                                                    showcaseHero.showSessionMenu = false;
                                                }
                                            }

                                            RowLayout {
                                                id: layoutRow
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Image {
                                                    source: "file:///usr/share/sddm/themes/silent/icons/language.svg"
                                                    sourceSize: Qt.size(13, 13)
                                                    width: 13; height: 13
                                                }
                                                StyledText {
                                                    text: showcaseHero.currentLayout
                                                    font.pixelSize: 10
                                                    font.weight: Font.Bold
                                                    color: "white"
                                                }
                                            }
                                        }

                                        // Virtual Keyboard Button
                                        Rectangle {
                                            implicitHeight: 28
                                            implicitWidth: 28
                                            radius: 6
                                            color: showcaseHero.showVirtualKeyboard ? (root.focusedPreset?.accent_color || Appearance.colors.colPrimary) : Qt.rgba(1, 1, 1, 0.16)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.2)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: showcaseHero.showVirtualKeyboard = !showcaseHero.showVirtualKeyboard
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                source: "file:///usr/share/sddm/themes/silent/icons/keyboard.svg"
                                                sourceSize: Qt.size(14, 14)
                                                width: 14; height: 14
                                            }
                                        }

                                        // Power Button
                                        Rectangle {
                                            implicitHeight: 28
                                            implicitWidth: 28
                                            radius: 6
                                            color: showcaseHero.showPowerMenu ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.16)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.2)

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    showcaseHero.showPowerMenu = !showcaseHero.showPowerMenu;
                                                    showcaseHero.showSessionMenu = false;
                                                    showcaseHero.showLayoutMenu = false;
                                                }
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                source: "file:///usr/share/sddm/themes/silent/icons/power.svg"
                                                sourceSize: Qt.size(14, 14)
                                                width: 14; height: 14
                                            }
                                        }
                                    }

                                    // Power Dropdown
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.rightMargin: 12
                                        anchors.bottomMargin: 44
                                        implicitWidth: 120
                                        implicitHeight: powerListCol.implicitHeight + 8
                                        radius: 8
                                        color: "#181825"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.25)
                                        visible: showcaseHero.showPowerMenu
                                        z: 30

                                        ColumnLayout {
                                            id: powerListCol
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 2

                                            Repeater {
                                                model: [
                                                    { id: "suspend", name: "Suspend", icon: "power-suspend.svg" },
                                                    { id: "reboot", name: "Restart", icon: "power-reboot.svg" },
                                                    { id: "shutdown", name: "Shut Down", icon: "power.svg" }
                                                ]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 26
                                                    radius: 5
                                                    color: pItemArea.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : "transparent"

                                                    MouseArea {
                                                        id: pItemArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: showcaseHero.showPowerMenu = false
                                                    }

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 6
                                                        spacing: 6
                                                        Image {
                                                            source: "file:///usr/share/sddm/themes/silent/icons/" + modelData.icon
                                                            sourceSize: Qt.size(13, 13)
                                                            width: 13; height: 13
                                                        }
                                                        StyledText {
                                                            text: modelData.name
                                                            font.pixelSize: 10
                                                            color: "white"
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Virtual Keyboard Drawer
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 16
                                        anchors.bottomMargin: 46
                                        height: 54
                                        radius: 8
                                        color: Qt.rgba(18/255, 18/255, 28/255, 0.95)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.22)
                                        visible: showcaseHero.showVirtualKeyboard
                                        z: 35

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Repeater {
                                                model: ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "⌫"]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    implicitWidth: modelData === "⌫" ? 34 : 22
                                                    implicitHeight: 26
                                                    radius: 4
                                                    color: vkArea.containsMouse ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.16)
                                                    MouseArea {
                                                        id: vkArea
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (modelData === "⌫") stagePassInput.text = stagePassInput.text.slice(0, -1);
                                                            else stagePassInput.text += modelData.toLowerCase();
                                                        }
                                                    }
                                                    StyledText {
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        font.pixelSize: 10
                                                        font.weight: Font.Bold
                                                        color: "white"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ─── SHOWCASE TOP-RIGHT CONTROLS ───
                            RowLayout {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 14
                                spacing: 8
                                z: 20

                                // In Use Badge
                                Rectangle {
                                    visible: root.focusedPreset?.is_active || (root.focusedPreset?.id === root.activePreset)
                                    implicitWidth: inUseRowText.implicitWidth + 14
                                    implicitHeight: 26
                                    radius: 13
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.width: 1
                                    border.color: "#4CAF50"
                                    RowLayout {
                                        id: inUseRowText
                                        anchors.centerIn: parent
                                        spacing: 4
                                        MaterialSymbol { text: "check"; iconSize: 14; color: "#4CAF50" }
                                        StyledText { text: "In use"; font.pixelSize: 11; font.weight: Font.Bold; color: "white" }
                                    }
                                }

                                // Mode Toggle Pills
                                Rectangle {
                                    implicitHeight: 26
                                    implicitWidth: modePillsRow.implicitWidth + 6
                                    radius: 13
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    RowLayout {
                                        id: modePillsRow
                                        anchors.centerIn: parent
                                        spacing: 2
                                        RippleButton {
                                            implicitHeight: 22
                                            implicitWidth: lockPillTxt.implicitWidth + 12
                                            buttonRadius: 11
                                            toggled: showcaseHero.previewMode === "lock"
                                            colBackgroundToggled: Appearance.colors.colPrimary
                                            onClicked: showcaseHero.previewMode = "lock"
                                            contentItem: StyledText {
                                                id: lockPillTxt
                                                anchors.centerIn: parent
                                                text: "Lock"
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: parent.toggled ? Appearance.colors.colOnPrimary : "white"
                                            }
                                        }
                                        RippleButton {
                                            implicitHeight: 22
                                            implicitWidth: loginPillTxt.implicitWidth + 12
                                            buttonRadius: 11
                                            toggled: showcaseHero.previewMode === "login"
                                            colBackgroundToggled: Appearance.colors.colPrimary
                                            onClicked: showcaseHero.previewMode = "login"
                                            contentItem: StyledText {
                                                id: loginPillTxt
                                                anchors.centerIn: parent
                                                text: "Login"
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: parent.toggled ? Appearance.colors.colOnPrimary : "white"
                                            }
                                        }
                                    }
                                }

                                // Full Greeter (Super+Q to exit) Button
                                RippleButton {
                                    implicitHeight: 26
                                    implicitWidth: fullGreeterRow.implicitWidth + 16
                                    buttonRadius: 13
                                    colBackground: Qt.rgba(0, 0, 0, 0.65)
                                    colBackgroundHover: Qt.rgba(0, 0, 0, 0.85)
                                    onClicked: root.testGreeter(root.focusedPreset?.id)

                                    contentItem: RowLayout {
                                        id: fullGreeterRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        MaterialSymbol { text: "fullscreen"; iconSize: 14; color: Appearance.colors.colPrimary }
                                        StyledText {
                                            text: "Full Greeter (Super+Q)"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: "white"
                                        }
                                    }
                                    StyledToolTip { text: "Launch live full-screen SDDM test greeter. Close with Super+Q or Alt+F4." }
                                }
                            }

                            // ─── SHOWCASE BOTTOM-LEFT INFO OVERLAY (Matching user screenshot) ───
                            RowLayout {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 14
                                spacing: 6
                                z: 20

                                // Live / Still pill
                                Rectangle {
                                    implicitWidth: pillLiveTxt.implicitWidth + 14
                                    implicitHeight: 24
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    RowLayout {
                                        id: pillLiveTxt
                                        anchors.centerIn: parent
                                        spacing: 4
                                        MaterialSymbol {
                                            text: root.focusedPreset?.is_video ? "motion_photos_on" : "image"
                                            iconSize: 12
                                            color: root.focusedPreset?.is_video ? Appearance.colors.colPrimary : "white"
                                        }
                                        StyledText {
                                            text: root.focusedPreset?.is_video ? "Live" : "Still"
                                            font.pixelSize: 10
                                            font.weight: Font.Bold
                                            color: "white"
                                        }
                                    }
                                }

                                // Format pill
                                Rectangle {
                                    implicitWidth: pillFmtTxt.implicitWidth + 12
                                    implicitHeight: 24
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    StyledText {
                                        id: pillFmtTxt
                                        anchors.centerIn: parent
                                        text: root.focusedPreset?.is_video ? "MP4" : "JPG"
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: "white"
                                    }
                                }

                                // Title pill
                                Rectangle {
                                    implicitWidth: pillNameTxt.implicitWidth + 14
                                    implicitHeight: 24
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.65)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.12)
                                    StyledText {
                                        id: pillNameTxt
                                        anchors.centerIn: parent
                                        text: root.focusedPreset?.name || "Theme"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: "white"
                                    }
                                }
                            }
                        }

                        // ─── HORIZONTAL THUMBNAIL FILMSTRIP CAROUSEL ───
                        GridView {
                            id: filmstripGrid
                            Layout.fillWidth: true
                            Layout.preferredHeight: 104
                            Layout.fillHeight: false
                            flow: GridView.FlowTopToBottom
                            cellWidth: 156
                            cellHeight: 98
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            flickableDirection: Flickable.HorizontalFlick
                            model: root.filteredPresets
                            currentIndex: root.focusedIndex

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: event => {
                                    const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 120 * filmstripGrid.cellWidth;
                                    filmstripGrid.contentX = Math.max(0, Math.min(Math.max(0, filmstripGrid.contentWidth - filmstripGrid.width), filmstripGrid.contentX - delta));
                                }
                            }

                            delegate: Item {
                                id: thumbSlot
                                required property var modelData
                                required property int index
                                width: filmstripGrid.cellWidth
                                height: filmstripGrid.cellHeight

                                readonly property bool isSelected: root.focusedIndex === index
                                readonly property bool isCurrent: modelData.id === root.activePreset

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.focusedIndex = thumbSlot.index
                                    onDoubleClicked: {
                                        if (modelData.installed) root.applyPreset(modelData.id);
                                        else root.installThemeItem(modelData);
                                    }

                                    // Selection highlight ring
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 14
                                        color: "transparent"
                                        border.width: thumbSlot.isSelected ? 2 : (thumbSlot.isCurrent ? 1 : 0)
                                        border.color: thumbSlot.isSelected ? Appearance.colors.colPrimary : Qt.rgba(1, 1, 1, 0.4)
                                        opacity: (thumbSlot.isSelected || thumbSlot.isCurrent) ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 150 } }
                                    }

                                    // Thumbnail Container
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        radius: 11
                                        clip: true
                                        color: Qt.rgba(0, 0, 0, 0.5)

                                        Image {
                                            anchors.fill: parent
                                            source: modelData.preview || modelData.preview_url || ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                        }

                                        // Video Badge Icon
                                        Rectangle {
                                            visible: modelData.is_video === true
                                            anchors.left: parent.left
                                            anchors.top: parent.top
                                            anchors.margins: 5
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Qt.rgba(0, 0, 0, 0.7)
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "motion_photos_on"
                                                iconSize: 12
                                                color: "white"
                                            }
                                        }

                                        // Active Preset Checkmark Badge
                                        Rectangle {
                                            visible: thumbSlot.isCurrent
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.margins: 5
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Appearance.colors.colPrimary
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: "check"
                                                iconSize: 12
                                                color: Appearance.colors.colOnPrimary
                                            }
                                        }

                                        // Bottom Mini Title
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: 22
                                            color: Qt.rgba(0, 0, 0, 0.75)
                                            StyledText {
                                                anchors.centerIn: parent
                                                width: parent.width - 8
                                                text: modelData.name
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                                color: "white"
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ─── BOTTOM CONTROL & ACTION BAR ───
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 10

                            // Left: Current Active Indicator
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Appearance.colors.colPrimary
                                }
                                StyledText {
                                    text: "SDDM: " + root.activePreset
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colPrimary
                                }
                            }

                            // Center: Target Style Pills (Scrollable with rich community and preset styles)
                            RowLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                Layout.maximumWidth: root.width * 0.46

                                StyledText {
                                    text: "Style:"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colSubtext
                                }

                                Flickable {
                                    id: styleFlickable
                                    Layout.fillWidth: true
                                    implicitHeight: 28
                                    contentWidth: stylePillRow.implicitWidth
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickableDirection: Flickable.HorizontalFlick
                                    clip: true

                                    RowLayout {
                                        id: stylePillRow
                                        spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        Repeater {
                                            model: [
                                                { id: "auto", name: "Preset" },
                                                { id: "active", name: "Active" },
                                                { id: "center", name: "Center" },
                                                { id: "left", name: "Left" },
                                                { id: "right", name: "Right" },
                                                { id: "silvia", name: "Silvia" },
                                                { id: "rei", name: "Rei" },
                                                { id: "blue-blade-live", name: "Blue Blade" },
                                                { id: "galaxy-within-live", name: "Galaxy Within" },
                                                { id: "catppuccin-mocha", name: "Catppuccin" },
                                                { id: "cyberpunk-edge", name: "Cyberpunk" },
                                                { id: "gruvbox-retro", name: "Gruvbox" },
                                                { id: "nordic-frost", name: "Nordic Frost" },
                                                { id: "tokyo-rain", name: "Tokyo Rain" },
                                                { id: "lone-ronin-live", name: "Lone Ronin" },
                                                { id: "midnight-tram-live", name: "Midnight Tram" }
                                            ]
                                            delegate: RippleButton {
                                                id: stylePill
                                                required property var modelData
                                                implicitHeight: 24
                                                implicitWidth: stylePillText.implicitWidth + 14
                                                buttonRadius: 12
                                                toggled: root.selectedStyle === stylePill.modelData.id

                                                colBackgroundToggled: Appearance.colors.colPrimary
                                                colBackgroundToggledHover: Appearance.colors.colPrimaryHover
                                                onClicked: root.selectedStyle = stylePill.modelData.id

                                                contentItem: StyledText {
                                                    id: stylePillText
                                                    anchors.centerIn: parent
                                                    text: stylePill.modelData.name
                                                    font.pixelSize: 10
                                                    font.weight: stylePill.toggled ? Font.Bold : Font.Normal
                                                    color: stylePill.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Right: Action & Utility Buttons
                            RowLayout {
                                spacing: 6

                                // Live Test Greeter Button
                                RippleButton {
                                    implicitHeight: 32
                                    implicitWidth: previewBtnRow.implicitWidth + 18
                                    buttonRadius: 16
                                    colBackground: Appearance.colors.colLayer2
                                    colBackgroundHover: Appearance.colors.colLayer2Hover
                                    onClicked: root.testGreeter(root.focusedPreset?.id)

                                    contentItem: RowLayout {
                                        id: previewBtnRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        MaterialSymbol {
                                            text: "visibility"
                                            iconSize: 15
                                            color: Appearance.colors.colOnLayer2
                                        }
                                        StyledText {
                                            text: "Preview"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer2
                                        }
                                    }
                                }

                                // Set BG Button (Quick apply background to selected style)
                                RippleButton {
                                    visible: root.focusedPreset && (root.focusedPreset.bg_url || root.focusedPreset.preview)
                                    implicitHeight: 32
                                    implicitWidth: setBgBtnRow.implicitWidth + 18
                                    buttonRadius: 16
                                    colBackground: Appearance.colors.colLayer2
                                    colBackgroundHover: Appearance.colors.colLayer2Hover
                                    onClicked: root.applyBackgroundItem(root.focusedPreset)

                                    contentItem: RowLayout {
                                        id: setBgBtnRow
                                        anchors.centerIn: parent
                                        spacing: 5
                                        MaterialSymbol {
                                            text: "wallpaper"
                                            iconSize: 15
                                            color: Appearance.colors.colOnLayer2
                                        }
                                        StyledText {
                                            text: "Set BG"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            color: Appearance.colors.colOnLayer2
                                        }
                                    }
                                }

                                // Primary Action: Apply SDDM / Install Theme
                                RippleButton {
                                    id: mainActionBtn
                                    implicitHeight: 34
                                    implicitWidth: Math.max(104, mainActionRow.implicitWidth + 24)
                                    buttonRadius: 17
                                    colBackground: Appearance.colors.colPrimary
                                    colBackgroundHover: Appearance.colors.colPrimaryHover
                                    enabled: root.focusedPreset !== null && (root.installingId !== root.focusedPreset?.id)
                                    onClicked: {
                                        if (!root.focusedPreset) return;
                                        if (root.focusedPreset.installed) {
                                            root.applyPreset(root.focusedPreset.id);
                                        } else {
                                            root.installThemeItem(root.focusedPreset);
                                        }
                                    }

                                    contentItem: RowLayout {
                                        id: mainActionRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        MaterialSymbol {
                                            text: (root.installingId === root.focusedPreset?.id) ? "autorenew" :
                                                  (root.focusedPreset?.is_active ? "check" :
                                                  (root.focusedPreset?.installed ? "done_all" : "download"))
                                            iconSize: 16
                                            color: Appearance.colors.colOnPrimary
                                            RotationAnimation on rotation {
                                                running: root.installingId === root.focusedPreset?.id
                                                loops: Animation.Infinite
                                                from: 0
                                                to: 360
                                                duration: 800
                                            }
                                        }
                                        StyledText {
                                            text: (root.installingId === root.focusedPreset?.id) ? "Installing…" :
                                                  (root.focusedPreset?.is_active ? "In Use" :
                                                  (root.focusedPreset?.installed ? "Apply SDDM" : "Install Theme"))
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: Appearance.colors.colOnPrimary
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 1
                                    height: 20
                                    color: Qt.rgba(1, 1, 1, 0.15)
                                }

                                IconToolbarButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: root.pickRandom()
                                    text: "casino"
                                    StyledToolTip { text: "Pick random SDDM theme" }
                                }

                                IconToolbarButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: root.reloadCurrentSource()
                                    text: "refresh"
                                    StyledToolTip { text: "Refresh list" }
                                }

                                IconToolbarButton {
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    onClicked: GlobalStates.sddmPickerOpen = false
                                    text: "close"
                                    StyledToolTip { text: "Close SDDM Hub (Esc)" }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
