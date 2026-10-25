import qs
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.japaneseTypography
import "root:modules/shared/background/widgets/japaneseTypography/JapaneseTypographyPresets.js" as JapanesePresets

ContentPage {
    id: root
    settingsPageIndex: 14
    settingsPageName: Translation.tr("Widgets")

    property bool isIiActive: ["ii", "iris"].includes(Config.options?.panelFamily ?? "ii")
    readonly property bool irisActive: (Config.options?.panelFamily ?? "ii") === "iris"
    function openIrisWidgets(): void {
        GlobalStates.openSettingsAt("iris", "desktop/widgets")
    }
    property int _customMediaFolderCount: 0
    property int _customMediaFolderImageCount: 0
    property int _customMediaFolderGifCount: 0
    property int _customMediaFolderVideoCount: 0
    property int _taskLoadingCount: 0

    function activateSettingsSearchSection(section: string): bool {
        const parts = String(section || "").toLowerCase().split(/[·›]/)
        const label = parts[parts.length - 1].trim()
        const sections = {
            "clock": "time",
            "world clock": "time",
            "month calendar": "time",
            "upcoming events": "time",
            "date badge": "time",
            "day progress widget": "time",
            "timers": "time",
            "system uptime": "time",
            "media controls": "media",
            "visualizer": "media",
            "system monitor": "system",
            "battery": "system",
            "weather": "system",
            "news ticker": "system",
            "notes": "personal",
            "todo": "personal",
            "user card": "personal",
            "custom image": "personal",
            "image converter": "personal",
            "custom widgets": "personal",
            "decorative shape": "art",
            "japanese typography": "art",
            "editorial": "art",
            "mascot": "art",
            "organic edge": "edges",
            "screen edges": "edges",
            "screen composition": "edges",
            "material and palette": "edges",
            "motion and sound": "edges"
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

    readonly property var _customImageShapes: [
        { value: "Circle", shape: MaterialShape.Shape.Circle },
        { value: "Square", shape: MaterialShape.Shape.Square },
        { value: "Slanted", shape: MaterialShape.Shape.Slanted },
        { value: "Arch", shape: MaterialShape.Shape.Arch },
        { value: "Fan", shape: MaterialShape.Shape.Fan },
        { value: "Arrow", shape: MaterialShape.Shape.Arrow },
        { value: "SemiCircle", shape: MaterialShape.Shape.SemiCircle },
        { value: "Oval", shape: MaterialShape.Shape.Oval },
        { value: "Pill", shape: MaterialShape.Shape.Pill },
        { value: "Triangle", shape: MaterialShape.Shape.Triangle },
        { value: "Diamond", shape: MaterialShape.Shape.Diamond },
        { value: "ClamShell", shape: MaterialShape.Shape.ClamShell },
        { value: "Pentagon", shape: MaterialShape.Shape.Pentagon },
        { value: "Gem", shape: MaterialShape.Shape.Gem },
        { value: "Sunny", shape: MaterialShape.Shape.Sunny },
        { value: "VerySunny", shape: MaterialShape.Shape.VerySunny },
        { value: "Cookie4Sided", shape: MaterialShape.Shape.Cookie4Sided },
        { value: "Cookie6Sided", shape: MaterialShape.Shape.Cookie6Sided },
        { value: "Cookie7Sided", shape: MaterialShape.Shape.Cookie7Sided },
        { value: "Cookie9Sided", shape: MaterialShape.Shape.Cookie9Sided },
        { value: "Cookie12Sided", shape: MaterialShape.Shape.Cookie12Sided },
        { value: "Ghostish", shape: MaterialShape.Shape.Ghostish },
        { value: "Clover4Leaf", shape: MaterialShape.Shape.Clover4Leaf },
        { value: "Clover8Leaf", shape: MaterialShape.Shape.Clover8Leaf },
        { value: "Burst", shape: MaterialShape.Shape.Burst },
        { value: "SoftBurst", shape: MaterialShape.Shape.SoftBurst },
        { value: "Boom", shape: MaterialShape.Shape.Boom },
        { value: "SoftBoom", shape: MaterialShape.Shape.SoftBoom },
        { value: "Flower", shape: MaterialShape.Shape.Flower },
        { value: "Puffy", shape: MaterialShape.Shape.Puffy },
        { value: "PuffyDiamond", shape: MaterialShape.Shape.PuffyDiamond },
        { value: "PixelCircle", shape: MaterialShape.Shape.PixelCircle },
        { value: "PixelTriangle", shape: MaterialShape.Shape.PixelTriangle },
        { value: "Bun", shape: MaterialShape.Shape.Bun },
        { value: "Heart", shape: MaterialShape.Shape.Heart }
    ]

    // A widget's option reads what the screen in front shows and writes every screen: a plain base write lost to the
    // screen's own copy of the key (set once from edit mode) and the row did nothing.
    function _widgetPath(path: string): var {
        const match = /^background\.widgets\.([A-Za-z]+)\.(.+)$/.exec(String(path ?? ""))
        return match && DesktopWidgetRegistry.entry(match[1]) ? { widget: match[1], key: match[2] } : null
    }
    function readPath(path: string, fallback: var): var {
        const at = root._widgetPath(path)
        return at ? DesktopWidgetOptions.value(at.widget, at.key, fallback) : Config.getNestedValue(path, fallback)
    }
    // Material's S/M/L cards: their size, never a width and height
    function sizedWidget(widget: string): bool {
        return DesktopWidgetOptions.sized(widget)
    }
    // one size for every family: the iRiS face takes it too
    function setWidgetSize(widget: string, size: string): void {
        const values = { materialSize: size }
        if (DesktopWidgetOptions.faced.includes(widget))
            values["iris.size"] = size
        DesktopWidgetLayout.setEverywhere(widget, values)
    }
    function writePath(path: string, value: var): void {
        root.writePaths({ [path]: value })
    }
    function writePaths(updates: var): void {
        const plain = ({})
        const byWidget = ({})
        for (const path of Object.keys(updates ?? {})) {
            const at = root._widgetPath(path)
            if (!at) {
                plain[path] = updates[path]
                continue
            }
            byWidget[at.widget] = Object.assign(byWidget[at.widget] ?? {}, { [at.key]: updates[path] })
        }
        if (Object.keys(plain).length > 0)
            Config.setNestedValues(plain)
        for (const widget of Object.keys(byWidget))
            DesktopWidgetLayout.setEverywhere(widget, byWidget[widget])
    }

    readonly property string _japanesePath: "background.widgets.japaneseTypography"
    readonly property bool _widgetBlurAvailable: Appearance.effectsEnabled
        && (Appearance.angelEverywhere
            || (Appearance.auroraEverywhere && !Appearance.inirEverywhere)
            || (!Appearance.zzzEverywhere && !Appearance.cookieEverywhere
                && !Appearance.angelEverywhere && !Appearance.auroraEverywhere
                && !Appearance.inirEverywhere
                && (Config.options?.background?.widgets?.style ?? "panel") === "island"
                && (Config.options?.appearance?.island?.glass ?? true)
                && (Config.options?.appearance?.island?.opacity ?? 1) < 0.999))

    function _setJapaneseValue(key: string, value: var, group: string): void {
        root.writePaths(JapanesePresets.setValue(root._japanesePath, key, value, group));
    }

    function _applyJapaneseCompositionPreset(preset: string): void {
        root.writePaths(JapanesePresets.composition(root._japanesePath, preset));
    }

    function _customMediaChoiceActive(choice: string): bool {
        const base = "background.widgets.customImage"
        const mode = root.readPath(base + ".sourceMode", "file")
        const filter = root.readPath(base + ".mediaFilter", "all")
        return mode === "file" ? choice === "file" : choice === filter
    }

    function _customMediaFolderUrl(path: string): string {
        const value = String(path ?? "")
        if (!value) return ""
        return value.startsWith("file:") ? value : "file://" + value
    }

    function _refreshCustomMediaFolderInventory(): void {
        let mediaCount = 0
        let imageCount = 0
        let gifCount = 0
        let videoCount = 0
        if (customMediaFolderInventory.status === FolderListModel.Ready) {
            for (let i = 0; i < customMediaFolderInventory.count; ++i) {
                const path = String(customMediaFolderInventory.get(i, "filePath")
                    || FileUtils.trimFileProtocol(customMediaFolderInventory.get(i, "fileURL")) || "")
                if (!Images.isValidMediaByName(path)) continue
                mediaCount++
                if (Images.isValidVideoByName(path)) videoCount++
                else if (path.toLowerCase().endsWith(".gif")) gifCount++
                else if (Images.isValidImageByName(path)) imageCount++
            }
        }
        root._customMediaFolderCount = mediaCount
        root._customMediaFolderImageCount = imageCount
        root._customMediaFolderGifCount = gifCount
        root._customMediaFolderVideoCount = videoCount

        const base = "background.widgets.customImage"
        const mode = root.readPath(base + ".sourceMode", "file")
        const filter = root.readPath(base + ".mediaFilter", "all")
        const selectedCount = filter === "images" ? imageCount
            : filter === "gifs" ? gifCount
            : filter === "videos" ? videoCount
            : mediaCount
        if (mode === "folder" && mediaCount > 0 && selectedCount === 0
                && filter !== "all")
            Qt.callLater(() => root.writePath(base + ".mediaFilter", "all"))
    }

    function _activateCustomMediaChoice(choice: string): void {
        const base = "background.widgets.customImage"
        const path = root.readPath(base + ".path", "")
        const updates = {}
        if (choice === "file") {
            if (!Images.isValidMediaByName(path)) return
            updates[base + ".sourceMode"] = "file"
        } else {
            const count = choice === "images" ? root._customMediaFolderImageCount
                : choice === "gifs" ? root._customMediaFolderGifCount
                : choice === "videos" ? root._customMediaFolderVideoCount
                : root._customMediaFolderCount
            if (count === 0) return
            updates[base + ".sourceMode"] = "folder"
            updates[base + ".mediaFilter"] = choice
        }
        root.writePaths(updates)
    }

    FolderListModel {
        id: customMediaFolderInventory
        folder: root._customMediaFolderUrl(
            root.readPath("background.widgets.customImage.folder", ""))
        nameFilters: Images.validImageExtensions.concat(Images.validVideoExtensions)
            .map(ext => "*." + ext)
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        onCountChanged: root._refreshCustomMediaFolderInventory()
        onStatusChanged: if (status === FolderListModel.Ready)
            root._refreshCustomMediaFolderInventory()
        onFolderChanged: Qt.callLater(root._refreshCustomMediaFolderInventory)
    }

    FileDialog {
        id: customImageFileDialog
        title: Translation.tr("Choose media file")
        fileMode: FileDialog.OpenFile
        nameFilters: [
            Translation.tr("Media") + " (*.jpg *.jpeg *.png *.webp *.tif *.tiff *.svg *.gif *.mp4 *.webm *.mkv *.avi *.mov)",
            Translation.tr("Images") + " (*.jpg *.jpeg *.png *.webp *.tif *.tiff *.svg *.gif)",
            Translation.tr("Videos") + " (*.mp4 *.webm *.mkv *.avi *.mov)",
            Translation.tr("All files") + " (*)"
        ]
        onAccepted: {
            const path = FileUtils.trimFileProtocol(String(selectedFile));
            if (Images.isValidMediaByName(path)) {
                root.writePaths({
                    "background.widgets.customImage.path": path,
                    "background.widgets.customImage.sourceMode": "file"
                });
            }
        }
    }

    FolderDialog {
        id: customImageFolderDialog
        title: Translation.tr("Choose media folder")
        onAccepted: {
            const path = FileUtils.trimFileProtocol(String(selectedFolder));
            if (path.length > 0) {
                root.writePaths({
                    "background.widgets.customImage.folder": path,
                    "background.widgets.customImage.sourceMode": "folder"
                });
            }
        }
    }

    SettingsNativeDialogGuard {
        dialog: customImageFileDialog
        dialogKey: "desktop-widgets-custom-media-file"
    }

    SettingsNativeDialogGuard {
        dialog: customImageFolderDialog
        dialogKey: "desktop-widgets-custom-media-folder"
    }

    function _applyJapanesePalettePreset(preset: string): void {
        root.writePaths(JapanesePresets.palette(root._japanesePath, preset));
    }

    function _applyJapaneseFontPreset(preset: string): void {
        root.writePaths(JapanesePresets.font(root._japanesePath, preset));
    }

    // Zone names for placement strategy resolution
    readonly property var _zoneNames: ["topLeft", "topCenter", "topRight", "centerLeft", "center", "centerRight", "bottomLeft", "bottomCenter", "bottomRight"]

    // Resolve any zone name to the display mode "zone"
    function _resolvedMode(strategy: string): string {
        if (root._zoneNames.indexOf(strategy) >= 0) return "zone";
        return strategy;
    }

    // Handle mode selection — when "zone" selected, default to center
    function _applyMode(configPath: string, mode: string, currentStrategy: string): void {
        if (mode === "zone") {
            // If already on a zone, keep it; otherwise default to center
            if (root._zoneNames.indexOf(currentStrategy) < 0)
                root.writePath(configPath + ".placementStrategy", "center");
        } else {
            root.writePath(configPath + ".placementStrategy", mode);
        }
    }

    function _placementOptions(): var {
        return [
            { displayName: Translation.tr("Draggable"), icon: "drag_pan", value: "free" },
            { displayName: Translation.tr("Least busy"), icon: "category", value: "leastBusy" },
            { displayName: Translation.tr("Most busy"), icon: "shapes", value: "mostBusy" },
            { displayName: Translation.tr("Zone"), icon: "grid_view", value: "zone" },
        ]
    }

    function _colorModeOptions(): var {
        return [
            { displayName: Translation.tr("Auto"), icon: "auto_awesome", value: "auto" },
            { displayName: Translation.tr("Light ink"), icon: "light_mode", value: "light" },
            { displayName: Translation.tr("Dark ink"), icon: "dark_mode", value: "dark" },
        ]
    }

    readonly property var _paletteWidgetKeys: DesktopWidgetRegistry.paletteKeys

    function _semanticRoleOptions(): var {
        return [
            { displayName: Translation.tr("Primary"), icon: "palette", value: "primary" },
            { displayName: Translation.tr("Secondary"), icon: "filter_2", value: "secondary" },
            { displayName: Translation.tr("Tertiary"), icon: "filter_3", value: "tertiary" },
            { displayName: Translation.tr("Warning"), icon: "warning", value: "warning" },
            { displayName: Translation.tr("Signal"), icon: "error", value: "signal" },
            { displayName: Translation.tr("Surface"), icon: "layers", value: "surface" }
        ]
    }

    function _palettePresetOptions(): var {
        return [
            { value: "balanced", label: Translation.tr("Default"), roles: ["primary", "secondary", "tertiary"] },
            { value: "primary", label: Translation.tr("Primary"), roles: ["primary", "primary", "primary"] },
            { value: "secondary", label: Translation.tr("Secondary"), roles: ["secondary", "secondary", "secondary"] },
            { value: "tertiary", label: Translation.tr("Tertiary"), roles: ["tertiary", "tertiary", "tertiary"] }
        ]
    }

    function _palettePresetSpec(preset: string): var {
        switch (preset) {
        case "primary":
            return { primary: "primary", secondary: "primary", tertiary: "primary", signal: "signal", surface: "surface" };
        case "secondary":
            return { primary: "secondary", secondary: "secondary", tertiary: "secondary", signal: "signal", surface: "surface" };
        case "tertiary":
            return { primary: "tertiary", secondary: "tertiary", tertiary: "tertiary", signal: "signal", surface: "surface" };
        default:
            return { primary: "primary", secondary: "secondary", tertiary: "tertiary", signal: "signal", surface: "surface" };
        }
    }

    function _palettePresetForPath(configPath: string): string {
        const roles = {
            primary: String(root.readPath(configPath + ".palette.primary", "primary")),
            secondary: String(root.readPath(configPath + ".palette.secondary", "secondary")),
            tertiary: String(root.readPath(configPath + ".palette.tertiary", "tertiary")),
            signal: String(root.readPath(configPath + ".palette.signal", "signal")),
            surface: String(root.readPath(configPath + ".palette.surface", "surface"))
        }
        for (const preset of root._palettePresetOptions()) {
            const spec = root._palettePresetSpec(preset.value)
            if (roles.primary === spec.primary && roles.secondary === spec.secondary
                    && roles.tertiary === spec.tertiary && roles.signal === spec.signal
                    && roles.surface === spec.surface)
                return preset.value
        }
        return "custom"
    }

    function _applyPalettePreset(configPath: string, preset: string): void {
        const spec = root._palettePresetSpec(preset)
        const prefix = configPath + ".palette."
        const updates = {}
        updates[prefix + "primary"] = spec.primary
        updates[prefix + "secondary"] = spec.secondary
        updates[prefix + "tertiary"] = spec.tertiary
        updates[prefix + "signal"] = spec.signal
        updates[prefix + "surface"] = spec.surface
        root.writePaths(updates)
    }

    function _commonPalettePreset(): string {
        let common = ""
        for (const widgetKey of root._paletteWidgetKeys) {
            const preset = root._palettePresetForPath("background.widgets." + widgetKey)
            if (preset === "custom") return "mixed"
            if (common.length === 0) common = preset
            else if (common !== preset) return "mixed"
        }
        return common.length > 0 ? common : "balanced"
    }

    function _applyPalettePresetAll(preset: string): void {
        const spec = root._palettePresetSpec(preset)
        const updates = {}
        for (const widgetKey of root._paletteWidgetKeys) {
            const prefix = "background.widgets." + widgetKey + ".palette."
            updates[prefix + "primary"] = spec.primary
            updates[prefix + "secondary"] = spec.secondary
            updates[prefix + "tertiary"] = spec.tertiary
            updates[prefix + "signal"] = spec.signal
            updates[prefix + "surface"] = spec.surface
        }
        root.writePaths(updates)
    }

    function _semanticPreviewColor(role: string): color {
        switch (role) {
        case "secondary": return Appearance.colors.colSecondary
        case "tertiary": return Appearance.colors.colTertiary
        default: return Appearance.colors.colPrimary
        }
    }

    function _manifestSupportsSurface(configKeys: var): bool {
        const keys = configKeys ?? {};
        return ["showBackground", "backgroundOpacity", "useBlur", "showBorder",
            "borderWidth", "borderOpacity", "cornerRadius"].some(key => keys[key] !== undefined);
    }

    function _manifestOptions(options: var): var {
        if (!options || !Array.isArray(options)) return [];
        return options.map(o => {
            if (o && typeof o === "object")
                return { displayName: o.label ?? o.displayName ?? o.value ?? "", value: o.value ?? o.label ?? o.displayName ?? "" };
            return { displayName: String(o), value: o };
        });
    }

    function _customWidgetInstalled(widgetId: string): bool {
        if (!CustomWidgets.ready) return false;
        for (let i = 0; i < CustomWidgets.widgets.length; i++) {
            if (CustomWidgets.widgets[i].id === widgetId)
                return true;
        }
        return false;
    }

    function _zoneDisplayName(zone: string): string {
        const labels = {
            topLeft: Translation.tr("Top left"),
            topCenter: Translation.tr("Top center"),
            topRight: Translation.tr("Top right"),
            centerLeft: Translation.tr("Center left"),
            center: Translation.tr("Center"),
            centerRight: Translation.tr("Center right"),
            bottomLeft: Translation.tr("Bottom left"),
            bottomCenter: Translation.tr("Bottom center"),
            bottomRight: Translation.tr("Bottom right")
        };
        return labels[zone] ?? Translation.tr("Zone");
    }

    // ── Reusable zone picker (3x3 grid) ────────────────────────
    component WidgetZonePicker: ColumnLayout {
        id: wzp
        required property string configPath
        required property var configEntry
        Layout.fillWidth: true

        readonly property string currentStrategy: root.readPath(wzp.configPath + ".placementStrategy", configEntry?.placementStrategy ?? "free")
        readonly property bool isZone: root._zoneNames.indexOf(currentStrategy) >= 0
        visible: isZone

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            MaterialSymbol {
                text: "grid_view"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Selected zone: %1").arg(root._zoneDisplayName(wzp.currentStrategy))
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Choose the screen region this widget should occupy. The widget stays attached to that zone when its size or the screen geometry changes.")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: zonePlate.implicitHeight

            Rectangle {
                id: zonePlate
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: zoneGrid.implicitWidth + 16
                implicitHeight: zoneGrid.implicitHeight + 16
                radius: Appearance.rounding.small
                color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.05)
                border.width: 1
                border.color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)

                Grid {
                    id: zoneGrid
                    anchors.centerIn: parent
                    columns: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { zone: "topLeft", icon: "north_west" },
                            { zone: "topCenter", icon: "north" },
                            { zone: "topRight", icon: "north_east" },
                            { zone: "centerLeft", icon: "west" },
                            { zone: "center", icon: "filter_center_focus" },
                            { zone: "centerRight", icon: "east" },
                            { zone: "bottomLeft", icon: "south_west" },
                            { zone: "bottomCenter", icon: "south" },
                            { zone: "bottomRight", icon: "south_east" }
                        ]
                        delegate: RippleButton {
                            required property var modelData
                            width: 36; height: 36
                            buttonRadius: Appearance.rounding.small
                            toggled: wzp.currentStrategy === modelData.zone
                            colBackground: "transparent"
                            colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.06)
                            colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.16)
                            colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.24)
                            colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                            downAction: () => root.writePath(wzp.configPath + ".placementStrategy", modelData.zone)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData.icon
                                iconSize: 18
                                color: parent.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }
                            StyledToolTip { text: root._zoneDisplayName(modelData.zone) }
                        }
                    }
                }
            }
        }
    }

    // ── Reusable placement selector (resolves zone names) ──────
    component WidgetPlacementSelector: ConfigSelectionArray {
        id: wps
        required property string configPath
        required property var configEntry
        required property string defaultStrategy
        Layout.fillWidth: true
        Layout.preferredWidth: 360
        Layout.minimumWidth: 180

        readonly property string currentStrategy: root.readPath(wps.configPath + ".placementStrategy", configEntry?.placementStrategy ?? defaultStrategy)

        currentValue: root._resolvedMode(wps.currentStrategy)
        onSelected: newValue => root._applyMode(wps.configPath, newValue, wps.currentStrategy)
        options: root._placementOptions()
    }

    component WidgetSettingRow: RowLayout {
        id: wsr
        property string label: ""
        property string icon: ""
        property bool trailing: true
        default property alias controlData: controlRow.data

        Layout.fillWidth: true
        spacing: 10

        MaterialSymbol {
            visible: wsr.icon.length > 0
            text: wsr.icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            Layout.alignment: Qt.AlignVCenter
        }

        // Label fills the row so a right-aligned control hugs the edge with no
        // dead gap (mascot-page density). When the control itself should stretch
        // (trailing:false, e.g. a selection array), the label hugs instead.
        StyledText {
            text: wsr.label
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
            wrapMode: Text.WordWrap
            Layout.fillWidth: wsr.trailing
            Layout.alignment: Qt.AlignVCenter
        }

        RowLayout {
            id: controlRow
            Layout.fillWidth: !wsr.trailing
            Layout.alignment: Qt.AlignVCenter
            spacing: 8
        }
    }

    component WidgetToggleChip: SelectionGroupButton {
        id: wtc
        required property string configPath
        property bool defaultValue: false

        Layout.fillWidth: false
        leftmost: true; rightmost: true
        toggled: Boolean(root.readPath(wtc.configPath, wtc.defaultValue))
        onClicked: root.writePath(wtc.configPath, !wtc.toggled)
    }

    // Widget enable toggles must agree with the desktop editor, which stores
    // per-output overrides. Show the effective state and clear overrides on change
    // so the base enable value is the single source of truth for settings.
    component WidgetEnableChip: SelectionGroupButton {
        id: wec
        required property string widgetKey
        property bool defaultValue: false

        Layout.fillWidth: false
        leftmost: true; rightmost: true
        toggled: DesktopWidgetLayout.effectiveEnabled(wec.widgetKey, wec.defaultValue)
        onClicked: DesktopWidgetLayout.setGloballyEnabled(wec.widgetKey, !wec.toggled)
    }

    component WidgetStateChip: SelectionGroupButton {
        id: wsc
        property bool active: false
        property var toggleAction

        Layout.fillWidth: false
        leftmost: true; rightmost: true
        toggled: wsc.active
        onClicked: if (wsc.toggleAction) wsc.toggleAction(!wsc.active)
    }

    component WidgetStateControls: ColumnLayout {
        id: stateControls
        required property string configPath
        required property var configEntry
        required property string defaultStrategy
        property bool defaultEnabled: false
        property string widgetTitle: Translation.tr("Widget")
        property string enableTooltip: ""
        readonly property string widgetKey: stateControls.configPath.startsWith("background.widgets.")
            ? stateControls.configPath.substring("background.widgets.".length) : stateControls.configPath
        readonly property var sizes: ["small", "medium", "large"]
            .filter(size => DesktopWidgetDesign.materialSizesOf(stateControls.widgetKey).includes(size))
        readonly property string size: {
            const drawn = DesktopWidgetDesign.materialSizesOf(stateControls.widgetKey)
            const own = String(root.readPath(stateControls.configPath + ".materialSize", ""))
            const other = String(root.readPath(stateControls.configPath + ".iris.size", ""))
            return drawn.includes(own) ? own : drawn.includes(other) ? other : (drawn[0] ?? "")
        }
        readonly property string design: {
            const own = String(root.readPath(stateControls.configPath + ".design", "auto"))
            return ["individual", "instrument", "readout"].includes(own) ? own : "auto"
        }

        Layout.fillWidth: true
        spacing: 0

        ContentSubsection {
            title: stateControls.widgetTitle

            SettingsSwitch {
                Layout.fillWidth: true
                buttonIcon: "visibility"
                text: Translation.tr("On the desktop")
                autoToggle: false
                checked: DesktopWidgetLayout.effectiveEnabled(stateControls.widgetKey, stateControls.defaultEnabled)
                onToggledByUser: checked => DesktopWidgetLayout.setGloballyEnabled(stateControls.widgetKey, checked)
                StyledToolTip {
                    visible: stateControls.enableTooltip.length > 0
                    text: stateControls.enableTooltip
                }
            }

            WidgetSettingRow {
                visible: root.sizedWidget(stateControls.widgetKey) && stateControls.sizes.length > 1
                label: Translation.tr("Size")
                icon: "aspect_ratio"
                trailing: false
                ConfigSelectionArray {
                    currentValue: stateControls.size
                    options: stateControls.sizes.map(size => ({
                        displayName: size === "small" ? Translation.tr("Small") : size === "medium" ? Translation.tr("Medium") : Translation.tr("Large"),
                        value: size
                    }))
                    onSelected: newValue => root.setWidgetSize(stateControls.widgetKey, newValue)
                }
            }

            // the look this widget wears over the one every widget shares (Widget Colors)
            WidgetSettingRow {
                visible: !root.irisActive && DesktopWidgetDesign.supports(stateControls.widgetKey)
                label: Translation.tr("Design")
                icon: "style"
                trailing: false
                ConfigSelectionArray {
                    currentValue: stateControls.design
                    options: [
                        { displayName: Translation.tr("Same as every widget"), icon: "select_all", value: "auto" },
                        { displayName: Translation.tr("Material"), icon: "widgets", value: "individual" },
                        { displayName: Translation.tr("iNstrument"), icon: "avg_pace", value: "instrument" },
                        { displayName: Translation.tr("Readout"), icon: "view_agenda", value: "readout" }
                    ]
                    onSelected: newValue => root.writePath(stateControls.configPath + ".design", newValue)
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Placement")

            WidgetSettingRow {
                label: Translation.tr("Mode")
                icon: "open_with"
                trailing: false
                WidgetPlacementSelector {
                    configPath: stateControls.configPath
                    configEntry: stateControls.configEntry
                    defaultStrategy: stateControls.defaultStrategy
                }
            }

            WidgetZonePicker {
                configPath: stateControls.configPath
                configEntry: stateControls.configEntry
            }
        }
    }

    component WidgetResetButton: RippleButton {
        id: wrb
        required property string configPath
        required property var defaults
        property bool resetSemanticPalette: wrb.configPath.startsWith("background.widgets.")
            && !wrb.configPath.startsWith("background.widgets.custom.")
        property bool armed: false
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignRight
        implicitHeight: 32
        implicitWidth: wrbRow.implicitWidth + 24
        buttonRadius: Appearance.rounding.full
        toggled: wrb.armed
        colBackground: "transparent"
        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
        colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colError, 0.14)
        colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.22)
        onClicked: {
            if (!wrb.armed) {
                wrb.armed = true
                wrbResetTimer.restart()
                return
            }
            wrb.armed = false
            wrbResetTimer.stop()
            const updates = {}
            for (const key in wrb.defaults) {
                // A settings reset restores configuration without removing the
                // widget from the desktop. Enable/disable remains an explicit action.
                if (key === "enable")
                    continue
                updates[wrb.configPath + "." + key] = wrb.defaults[key]
            }
            if (wrb.resetSemanticPalette) {
                const spec = root._palettePresetSpec("balanced")
                const prefix = wrb.configPath + ".palette."
                updates[prefix + "primary"] = spec.primary
                updates[prefix + "secondary"] = spec.secondary
                updates[prefix + "tertiary"] = spec.tertiary
                updates[prefix + "signal"] = spec.signal
                updates[prefix + "surface"] = spec.surface
            }
            root.writePaths(updates)
        }
        Timer {
            id: wrbResetTimer
            interval: 3000
            onTriggered: wrb.armed = false
        }
        contentItem: Item {
            implicitWidth: wrbRow.implicitWidth
            implicitHeight: wrbRow.implicitHeight
            RowLayout {
                id: wrbRow
                width: Math.min(implicitWidth, parent.width)
                anchors.centerIn: parent
                spacing: 6
                MaterialSymbol {
                    text: wrb.armed ? "warning" : "restart_alt"
                    iconSize: 18
                    color: wrb.armed ? Appearance.colors.colError : Appearance.colors.colSubtext
                }
                StyledText {
                    text: wrb.armed ? Translation.tr("Confirm reset") : Translation.tr("Reset to defaults")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: wrb.armed ? Appearance.colors.colError : Appearance.colors.colSubtext
                }
            }
        }
        StyledToolTip {
            text: wrb.armed
                ? Translation.tr("Click again to restore this widget's defaults")
                : Translation.tr("Restore this widget's default settings")
        }
    }

    component PowerSavingSwitchRow: WidgetSettingRow {
        id: psRow
        required property string psKey
        property bool psDefault: true
        readonly property string _psPath: "background.widgets.powerSaving." + psKey
        StyledSwitch {
            checked: Boolean(root.readPath(psRow._psPath, psRow.psDefault))
            onCheckedChanged: {
                if (checked !== Boolean(root.readPath(psRow._psPath, psRow.psDefault)))
                    root.writePath(psRow._psPath, checked)
            }
        }
    }

    // ── Reusable percentage row ──────────────────────────────
    component SliderRow: WidgetSettingRow {
        id: sliderRow
        property string configPath: ""
        property string tooltipText: ""
        property real sliderFrom: 0
        property real sliderTo: 100
        property real sliderStep: 5
        property real sliderValue: 0
        // Normalized config values are stored as 0..1. Older or malformed
        // 0..100 values are accepted and clamped instead of displaying 10000%.
        property bool isNormalized: false

        trailing: false

        function _clamp(value: real): real {
            return Math.max(sliderRow.sliderFrom, Math.min(sliderRow.sliderTo, value));
        }

        function _displayValue(value: var): real {
            const numeric = Number(value);
            if (!Number.isFinite(numeric))
                return sliderRow.sliderFrom;
            if (!sliderRow.isNormalized)
                return sliderRow._clamp(numeric);
            return sliderRow._clamp(numeric <= 1 ? numeric * 100 : numeric);
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledSlider {
                id: _slider
                Layout.fillWidth: true
                configuration: StyledSlider.Configuration.S
                stopIndicatorValues: []
                from: sliderRow.sliderFrom
                to: sliderRow.sliderTo
                stepSize: sliderRow.sliderStep
                value: sliderRow._displayValue(sliderRow.sliderValue)
                onMoved: {
                    const displayValue = sliderRow._clamp(_slider.value);
                    root.writePath(sliderRow.configPath,
                        sliderRow.isNormalized ? Math.round(displayValue) / 100 : Math.round(displayValue));
                }
                StyledToolTip {
                    visible: sliderRow.tooltipText.length > 0
                    text: sliderRow.tooltipText
                }
            }

            StyledText {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round(sliderRow._clamp(_slider.value)) + "%"
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.family: Appearance.font.family.numbers
            }
        }
    }

    component WidgetPalettePresetPicker: ColumnLayout {
        id: palettePicker
        required property string configPath
        property bool applyGlobally: false

        Layout.fillWidth: true
        spacing: 7

        readonly property string currentPreset: {
            void Config.revision
            return palettePicker.applyGlobally
                ? root._commonPalettePreset()
                : root._palettePresetForPath(palettePicker.configPath)
        }

        GridLayout {
            id: palettePresetGrid
            Layout.fillWidth: true
            columns: palettePicker.width >= 520 ? 4 : 2
            columnSpacing: 6
            rowSpacing: 6

            Repeater {
                model: root._palettePresetOptions()

                delegate: RippleButton {
                    id: presetButton
                    required property var modelData
                    readonly property color presetAccent: root._semanticPreviewColor(modelData.roles[0])
                    Layout.fillWidth: true
                    Layout.minimumWidth: 112
                    Layout.preferredHeight: 38
                    buttonRadius: Appearance.rounding.small
                    toggled: palettePicker.currentPreset === modelData.value
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    colBackgroundToggled: ColorUtils.mix(
                        Appearance.colors.colLayer2, presetButton.presetAccent, 0.93)
                    colBackgroundToggledHover: ColorUtils.mix(
                        Appearance.colors.colLayer2Hover, presetButton.presetAccent, 0.90)
                    colRipple: ColorUtils.applyAlpha(presetButton.presetAccent, 0.10)
                    colRippleToggled: ColorUtils.applyAlpha(presetButton.presetAccent, 0.14)
                    downAction: () => {
                        if (palettePicker.applyGlobally)
                            root._applyPalettePresetAll(modelData.value)
                        else
                            root._applyPalettePreset(palettePicker.configPath, modelData.value)
                    }

                    contentItem: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: presetButton.buttonRadius
                            color: "transparent"
                            border.width: presetButton.toggled ? 1.5 : 0
                            border.color: presetButton.presetAccent
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Row {
                                spacing: -4
                                Repeater {
                                    model: presetButton.modelData.roles
                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: 14
                                        height: 14
                                        radius: 7
                                        color: root._semanticPreviewColor(modelData)
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.25)
                                        z: 3 - index
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: presetButton.modelData.label
                                color: presetButton.toggled
                                    ? presetButton.presetAccent : Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: presetButton.toggled ? Font.DemiBold : Font.Normal
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        StyledText {
            visible: palettePicker.currentPreset === "custom"
                || palettePicker.currentPreset === "mixed"
            text: palettePicker.currentPreset === "mixed"
                ? Translation.tr("Widgets currently use different palettes")
                : Translation.tr("Custom role mapping")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    // ── Reusable appearance controls for any widget ──────────
    component WidgetAppearanceControls: ColumnLayout {
        id: wac
        required property string configPath
        required property var configEntry
        property bool hasDim: true
        property bool hasColorMode: true
        property bool hasCardControls: false
        property bool hasSemanticPalette: !wac.configPath.startsWith("background.widgets.custom.")
        property bool paletteDetailsOpen: false
        property int dimDefault: 0

        Layout.fillWidth: true
        spacing: 0

        // ── Position & interaction ──
        ContentSubsection {
            title: Translation.tr("Position and interaction")

            WidgetSettingRow {
                label: Translation.tr("Lock position")
                icon: "lock"
                WidgetToggleChip {
                    configPath: wac.configPath + ".locked"
                    defaultValue: false
                    buttonIcon: Boolean(root.readPath(wac.configPath + ".locked", false)) ? "lock" : "lock_open"
                    buttonText: Boolean(root.readPath(wac.configPath + ".locked", false)) ? Translation.tr("Locked") : Translation.tr("Unlocked")
                }
            }
        }

        // ── Appearance ──
        ContentSubsection {
            title: Translation.tr("Appearance")

            WidgetSettingRow {
                visible: wac.hasColorMode
                label: Translation.tr("Color mode")
                icon: "palette"
                trailing: false
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath(wac.configPath + ".colorMode", wac.configEntry?.colorMode ?? "auto")
                    onSelected: newValue => root.writePath(wac.configPath + ".colorMode", newValue)
                    options: root._colorModeOptions()
                    StyledToolTip {
                        text: Translation.tr("Auto follows the wallpaper or surface. Light ink and Dark ink force the text polarity.")
                    }
                }
            }

            WidgetSettingRow {
                label: Translation.tr("Scale")
                icon: "zoom_in"
                StyledSpinBox {
                    from: 50; to: 200; stepSize: 10
                    value: root.readPath(wac.configPath + ".widgetScale", wac.configEntry?.widgetScale ?? 100)
                    onValueModified: root.writePath(wac.configPath + ".widgetScale", value)
                    StyledToolTip { text: Translation.tr("Widget size percentage") }
                }
            }

            SliderRow {
                icon: "opacity"
                label: Translation.tr("Opacity")
                configPath: wac.configPath + ".widgetOpacity"
                sliderFrom: 10; sliderTo: 100; sliderStep: 5
                sliderValue: root.readPath(wac.configPath + ".widgetOpacity", wac.configEntry?.widgetOpacity ?? 100)
            }

            SliderRow {
                visible: wac.hasDim
                icon: "contrast"
                label: Translation.tr("Dimming")
                configPath: wac.configPath + ".dim"
                sliderFrom: 0; sliderTo: 100; sliderStep: 5
                sliderValue: root.readPath(wac.configPath + ".dim", wac.configEntry?.dim ?? wac.dimDefault)
            }
        }

        // ── Colors ──
        ContentSubsection {
            visible: wac.hasSemanticPalette
            title: Translation.tr("Colors")

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Choose a palette preset. Fine tuning is optional and stays out of the way until you open it.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            WidgetPalettePresetPicker {
                configPath: wac.configPath
            }

            RippleButton {
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignLeft
                implicitWidth: paletteDetailsRow.implicitWidth + 20
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                toggled: wac.paletteDetailsOpen
                colBackground: "transparent"
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.07)
                colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.12)
                colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.18)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
                downAction: () => wac.paletteDetailsOpen = !wac.paletteDetailsOpen

                contentItem: Item {
                    implicitWidth: paletteDetailsRow.implicitWidth
                    implicitHeight: paletteDetailsRow.implicitHeight
                    RowLayout {
                        id: paletteDetailsRow
                        width: Math.min(implicitWidth, parent.width)
                        anchors.centerIn: parent
                        spacing: 5
                        MaterialSymbol {
                            text: wac.paletteDetailsOpen ? "expand_less" : "tune"
                            iconSize: 16
                            color: wac.paletteDetailsOpen
                                ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: Translation.tr("Customize roles")
                            color: wac.paletteDetailsOpen
                                ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                }
            }

            ColumnLayout {
                visible: wac.paletteDetailsOpen
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: [
                        { key: "primary", label: Translation.tr("Main accent"), icon: "palette", fallback: "primary" },
                        { key: "secondary", label: Translation.tr("Secondary accent"), icon: "filter_2", fallback: "secondary" },
                        { key: "tertiary", label: Translation.tr("Tertiary accent"), icon: "filter_3", fallback: "tertiary" },
                        { key: "signal", label: Translation.tr("Alerts"), icon: "error", fallback: "signal" },
                        { key: "surface", label: Translation.tr("Surface"), icon: "layers", fallback: "surface" }
                    ]

                    delegate: WidgetSettingRow {
                        required property var modelData
                        label: modelData.label
                        icon: modelData.icon
                        trailing: false

                        ConfigSelectionArray {
                            Layout.fillWidth: true
                            currentValue: String(root.readPath(
                                wac.configPath + ".palette." + modelData.key, modelData.fallback))
                            onSelected: newValue => root.writePath(
                                wac.configPath + ".palette." + modelData.key, newValue)
                            options: root._semanticRoleOptions()
                        }
                    }
                }
            }
        }

        // ── Surface ──
        ContentSubsection {
            visible: wac.hasCardControls
            title: Translation.tr("Surface")

            SettingsSwitch {
                buttonIcon: "format_color_fill"
                text: Translation.tr("Show background")
                autoToggle: false
                checked: root.readPath(wac.configPath + ".showBackground", wac.configEntry?.showBackground ?? true)
                onToggledByUser: checked => root.writePath(wac.configPath + ".showBackground", checked)
            }

            SettingsSwitch {
                visible: root._widgetBlurAvailable
                    && root.readPath(wac.configPath + ".showBackground", wac.configEntry?.showBackground ?? true)
                buttonIcon: "blur_on"
                text: Translation.tr("Blur background")
                autoToggle: false
                checked: root.readPath(wac.configPath + ".useBlur", wac.configEntry?.useBlur ?? false)
                onToggledByUser: checked => root.writePath(wac.configPath + ".useBlur", checked)
            }

            SettingsSwitch {
                buttonIcon: "border_style"
                text: Translation.tr("Show border")
                autoToggle: false
                checked: root.readPath(wac.configPath + ".showBorder", wac.configEntry?.showBorder ?? true)
                onToggledByUser: checked => root.writePath(wac.configPath + ".showBorder", checked)
            }

            SliderRow {
                visible: root.readPath(wac.configPath + ".showBackground", wac.configEntry?.showBackground ?? true)
                icon: "gradient"
                label: Translation.tr("Background")
                configPath: wac.configPath + ".backgroundOpacity"
                sliderFrom: 0; sliderTo: 100; sliderStep: 1
                sliderValue: root.readPath(wac.configPath + ".backgroundOpacity", wac.configEntry?.backgroundOpacity ?? 0.06)
                isNormalized: true
            }

            WidgetSettingRow {
                visible: root.readPath(wac.configPath + ".showBorder", wac.configEntry?.showBorder ?? true) && !Appearance.zzzEverywhere
                label: Translation.tr("Border")
                icon: "border_style"
                StyledSpinBox {
                    from: 0; to: 8; stepSize: 1
                    value: root.readPath(wac.configPath + ".borderWidth", wac.configEntry?.borderWidth ?? 1)
                    onValueModified: root.writePath(wac.configPath + ".borderWidth", value)
                    StyledToolTip { text: Translation.tr("Border width (px)") }
                }
            }

            SliderRow {
                visible: root.readPath(wac.configPath + ".showBorder", wac.configEntry?.showBorder ?? true)
                icon: "tonality"
                label: Translation.tr("Border opacity")
                configPath: wac.configPath + ".borderOpacity"
                sliderFrom: 0; sliderTo: 100; sliderStep: 1
                sliderValue: root.readPath(wac.configPath + ".borderOpacity", wac.configEntry?.borderOpacity ?? 0.08)
                isNormalized: true
            }

            WidgetSettingRow {
                label: Translation.tr("Corner radius")
                icon: "rounded_corner"
                StyledSpinBox {
                    from: -1; to: 50; stepSize: 1
                    value: root.readPath(wac.configPath + ".cornerRadius", wac.configEntry?.cornerRadius ?? -1)
                    onValueModified: root.writePath(wac.configPath + ".cornerRadius", value)
                    StyledToolTip { text: Translation.tr("-1 = use theme default") }
                }
            }
        }
    }

    component JapaneseCompositionPicker: ColumnLayout {
        id: compositionPicker
        Layout.fillWidth: true
        spacing: 8

        readonly property string currentPreset: root.readPath(root._japanesePath + ".preset", "exhibition")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { value: "exhibition", label: Translation.tr("Exhibition"), mirror: false, secondary: true, seal: true, footer: true },
                    { value: "magazine", label: Translation.tr("Magazine"), mirror: true, secondary: true, seal: true, footer: true },
                    { value: "minimal", label: Translation.tr("Minimal"), mirror: false, secondary: false, seal: false, footer: false },
                    { value: "traditional", label: Translation.tr("Traditional"), mirror: true, secondary: true, seal: true, footer: false }
                ]

                delegate: RippleButton {
                    id: compositionCard
                    required property var modelData
                    width: 136
                    height: 112
                    buttonRadius: Appearance.rounding.small
                    toggled: compositionPicker.currentPreset === modelData.value
                    colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.035)
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.075)
                    colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                    colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
                    downAction: () => root._applyJapaneseCompositionPreset(modelData.value)

                    contentItem: ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            VerticalJapaneseText {
                                x: compositionCard.modelData.mirror ? parent.width - width - 2 : 2
                                y: 2
                                width: 48
                                height: parent.height - 8
                                text: "夏の記憶"
                                fontFamily: "serif"
                                fontPixelSize: compositionCard.modelData.value === "minimal" ? 20 : 16
                                fontWeight: Font.DemiBold
                                letterSpacing: 0
                                columnGap: 3
                                maxColumns: compositionCard.modelData.value === "minimal" ? 1 : 2
                                color: compositionCard.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            }

                            VerticalJapaneseText {
                                visible: compositionCard.modelData.secondary
                                x: compositionCard.modelData.mirror ? 38 : 54
                                y: 6
                                width: 30
                                height: parent.height - 16
                                text: "潮風と夏"
                                fontFamily: "serif"
                                fontPixelSize: 9
                                letterSpacing: 0
                                columnGap: 2
                                maxColumns: 2
                                color: Appearance.colors.colSubtext
                            }

                            Rectangle {
                                visible: compositionCard.modelData.seal
                                x: compositionCard.modelData.mirror ? 2 : parent.width - width - 2
                                y: 2
                                width: 17
                                height: 34
                                color: "transparent"
                                border.width: 1
                                border.color: Appearance.colors.colTertiary
                                StyledText {
                                    anchors.centerIn: parent
                                    text: "展"
                                    color: Appearance.colors.colTertiary
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                }
                            }

                            Rectangle {
                                visible: compositionCard.modelData.footer
                                x: compositionCard.modelData.mirror ? parent.width - width - 2 : 2
                                anchors.bottom: parent.bottom
                                width: parent.width * 0.68
                                height: 1
                                color: Appearance.colors.colPrimary
                                opacity: 0.65
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: compositionCard.modelData.label
                            horizontalAlignment: Text.AlignHCenter
                            color: compositionCard.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: compositionCard.toggled ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    component JapanesePalettePicker: ColumnLayout {
        id: palettePicker
        Layout.fillWidth: true
        spacing: 8

        readonly property string currentPreset: root.readPath(root._japanesePath + ".palettePreset", "adaptive")

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { value: "adaptive", label: Translation.tr("Adaptive"), colors: [] },
                    { value: "sumi", label: Translation.tr("Sumi ink"), colors: ["#17130F", "#493D31", "#9D382B"] },
                    { value: "ivory", label: Translation.tr("Ivory"), colors: ["#F3E8D3", "#D8C3A2", "#C76049"] },
                    { value: "sunset", label: Translation.tr("Sunset"), colors: ["#E6C49A", "#C39D73", "#A94B37"] },
                    { value: "cinema", label: Translation.tr("Cinema"), colors: ["#F1EEE7", "#AAA299", "#D9684B"] }
                ]

                delegate: RippleButton {
                    id: paletteCard
                    required property var modelData
                    readonly property var swatches: modelData.value === "adaptive"
                        ? [Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, Appearance.colors.colTertiary]
                        : modelData.colors
                    width: 136
                    height: 54
                    buttonRadius: Appearance.rounding.small
                    toggled: palettePicker.currentPreset === modelData.value
                    colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.035)
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.075)
                    colBackgroundToggled: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                    colBackgroundToggledHover: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.20)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
                    downAction: () => root._applyJapanesePalettePreset(modelData.value)

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Row {
                            spacing: -4
                            Repeater {
                                model: paletteCard.swatches
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: modelData
                                    border.width: 1
                                    border.color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.22)
                                    z: 3 - index
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: paletteCard.modelData.label
                            color: paletteCard.toggled ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: paletteCard.toggled ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    component JapaneseColorPickerRow: Item {
        id: colorRow
        required property string label
        required property string configKey
        required property string fallbackColor

        Layout.fillWidth: true
        implicitHeight: 40
        readonly property color currentColor: {
            const parsed = Qt.color(String(root.readPath(root._japanesePath + "." + colorRow.configKey, colorRow.fallbackColor)));
            return parsed.valid ? parsed : Qt.color(colorRow.fallbackColor);
        }

        RowLayout {
            anchors.fill: parent
            spacing: 10

            StyledText {
                Layout.fillWidth: true
                text: colorRow.label
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            RippleButton {
                implicitWidth: 132
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                colBackground: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.055)
                colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.10)
                colRipple: ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.10)
                downAction: () => colorDialog.open()

                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 7

                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: colorRow.currentColor
                        border.width: 1
                        border.color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.25)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: colorRow.currentColor.toString().toUpperCase().substring(0, 7)
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }

                    MaterialSymbol {
                        text: "edit"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }

        ColorDialog {
            id: colorDialog
            selectedColor: colorRow.currentColor
            onAccepted: root._setJapaneseValue(colorRow.configKey, selectedColor.toString(), "palette")
        }

        SettingsNativeDialogGuard {
            dialog: colorDialog
            dialogKey: "desktop-widgets-japanese-color"
        }
    }

    // ── Overview: every widget toggleable at a glance ─────────
    property string activeSection: "manage"

    SettingsTaskNavigator {
        icon: "dashboard_customize"
        title: Translation.tr("Desktop Widgets")
        description: Translation.tr("Configure your desktop widgets in focused views: layout management, clocks, weather, media, screen edges and personal widgets.")
        summary: options.map(option => option.displayName).join(" \u00b7 ")
        currentValue: root.activeSection
        onSelected: value => root.activeSection = value
        // the clusters iRiS Settings › Widgets uses, so a widget sits in the same place in every family
        options: [
            { displayName: Translation.tr("Manage"), icon: "dashboard_customize", value: "manage" },
            { displayName: Translation.tr("Time"), icon: "schedule", value: "time" },
            { displayName: Translation.tr("Music"), icon: "album", value: "media" },
            { displayName: Translation.tr("System"), icon: "monitor_heart", value: "system" },
            { displayName: Translation.tr("Yours"), icon: "person", value: "personal" },
            { displayName: Translation.tr("Art"), icon: "brush", value: "art" },
            { displayName: Translation.tr("Screen edges"), icon: "border_outer", value: "edges" }
        ]
    }

    SettingsTaskLoadingState {
        loading: root._taskLoadingCount > 0
        text: Translation.tr("Loading section…")
    }

    // ── Widgets at a glance ─────────────────────────────────
    SettingsTaskLoader {
        requested: root.isIiActive && root.activeSection === "manage"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "manage"
        expanded: true
        icon: "dashboard_customize"
        title: Translation.tr("Widgets at a glance")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Toggle any widget here; fine-tune it in its section below")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: [
                        { key: "clock", icon: "schedule", label: Translation.tr("Clock"), def: true },
                        { key: "weather", icon: "cloud", label: Translation.tr("Weather"), def: false },
                        { key: "customImage", icon: "add_photo_alternate", label: Translation.tr("Custom image"), def: false },
                        { key: "imageConverter", icon: "transform", label: Translation.tr("Image converter"), def: false },
                        { key: "mediaControls", icon: "album", label: Translation.tr("Media"), def: false },
                        { key: "visualizer", icon: "graphic_eq", label: Translation.tr("Visualizer"), def: false },
                        { key: "systemMonitor", icon: "monitor_heart", label: Translation.tr("System"), def: false },
                        { key: "battery", icon: "battery_full", label: Translation.tr("Battery"), def: false },
                        { key: "notes", icon: "sticky_note_2", label: Translation.tr("Notes"), def: false },
                        { key: "calendarUpcoming", icon: "event", label: Translation.tr("Events"), def: false },
                        { key: "monthCalendar", icon: "calendar_month", label: Translation.tr("Calendar"), def: false },
                        { key: "todo", icon: "checklist", label: Translation.tr("Todo"), def: false },
                        { key: "timers", icon: "timer", label: Translation.tr("Timers"), def: false },
                        { key: "dayProgress", icon: "av_timer", label: Translation.tr("Day progress"), def: false },
                        { key: "uptime", icon: "avg_pace", label: Translation.tr("Uptime"), def: false },
                        { key: "shape", icon: "category", label: Translation.tr("Decorative shape"), def: false },
                        { key: "dateBadge", icon: "today", label: Translation.tr("Date badge"), def: false },
                        { key: "editorial", icon: "text_fields", label: Translation.tr("Editorial"), def: false },
                        { key: "newsTicker", icon: "newspaper", label: Translation.tr("News"), def: false },
                        { key: "mascot", icon: "pets", label: Translation.tr("Mascot"), def: false },
                        { key: "japaneseTypography", icon: "translate", label: Translation.tr("Japanese Typography"), def: false },
                        { key: "worldClock", icon: "public", label: Translation.tr("World Clock"), def: false },
                        { key: "userCard", icon: "account_circle", label: Translation.tr("User Card"), def: false }
                    ]
                    delegate: WidgetEnableChip {
                        required property var modelData
                        widgetKey: modelData.key
                        defaultValue: modelData.def
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                    }
                }
            }
        }
    }
        }
    }

    // ── Edit Mode ───────────────────────────────────────────
    SettingsTaskLoader {
        requested: root.isIiActive && root.activeSection === "manage"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "manage"
        expanded: false
        icon: "grid_on"
        title: Translation.tr("Edit Mode")

        SettingsGroup {
            WidgetSettingRow {
                label: Translation.tr("Desktop editing")
                icon: "edit"
                trailing: false
                WidgetStateChip {
                    buttonIcon: "edit"
                    buttonText: Translation.tr("Edit mode")
                    active: GlobalStates.widgetEditMode
                    toggleAction: checked => GlobalStates.setWidgetEditMode(checked)
                    StyledToolTip { text: Translation.tr("Show widget handles and desktop placement controls") }
                }
            }
            WidgetSettingRow {
                label: Translation.tr("Grid")
                icon: "grid_3x3"
                WidgetToggleChip {
                    configPath: "background.widgets.editGrid.snap"
                    defaultValue: true
                    buttonIcon: "grid_3x3"
                    buttonText: Translation.tr("Snap")
                }
                StyledSpinBox {
                    from: 8; to: 128; stepSize: 8
                    value: root.readPath("background.widgets.editGrid.size", 32)
                    onValueModified: root.writePath("background.widgets.editGrid.size", value)
                    StyledToolTip {
                        text: Translation.tr("Grid cell size in pixels")
                    }
                }
            }
            SliderRow {
                label: Translation.tr("Fade with windows")
                icon: "visibility_off"
                configPath: "background.widgets.dynamicOpacity"
                sliderValue: root.readPath("background.widgets.dynamicOpacity", 0)
                sliderStep: 10
                tooltipText: Translation.tr("Reduce widget opacity when windows are on the current workspace (0 = off)")
            }
        }
    }
        }
    }

    // ── Widget Colors ───────────────────────────────────────
    SettingsTaskLoader {
        requested: root.isIiActive && root.activeSection === "manage"
        sourceComponent: Component {
    SettingsCardSection {
        settingsTaskSection: "manage"
        expanded: false
        icon: "palette"
        title: Translation.tr("Widget Colors")

        SettingsGroup {
            StyledText {
                visible: root.irisActive
                Layout.fillWidth: true
                text: Translation.tr("iRiS sets the design, material and colours of every widget in its own Settings. The options on each widget below apply while it wears the Material, iNstrument or Readout design.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
            SelectionGroupButton {
                visible: root.irisActive
                Layout.fillWidth: false
                leftmost: true; rightmost: true
                buttonIcon: "widgets"
                buttonText: Translation.tr("Open iRiS widget settings")
                onClicked: root.openIrisWidgets()
            }
            WidgetSettingRow {
                visible: !root.irisActive
                label: Translation.tr("Global widget design")
                icon: "widgets"
                trailing: false
                ConfigSelectionArray {
                    currentValue: DesktopWidgetDesign.shared
                    options: DesktopWidgetDesign.choices.map(choice => ({
                        displayName: Translation.tr(choice.label), icon: choice.icon, value: choice.value
                    }))
                    onSelected: newValue => DesktopWidgetDesign.apply(newValue)
                }
            }
            StyledText {
                visible: !root.irisActive
                Layout.fillWidth: true
                text: Translation.tr("One look on every widget. Individual keeps each widget's own style.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
            RowLayout {
                visible: !root.irisActive && (DesktopWidgetDesign.exceptionCount > 0 || DesktopWidgetDesign.canUndo)
                spacing: 6
                SelectionGroupButton {
                    visible: DesktopWidgetDesign.exceptionCount > 0
                    Layout.fillWidth: false
                    leftmost: true; rightmost: true
                    buttonIcon: "select_all"
                    buttonText: Translation.tr("Match every widget")
                    onClicked: DesktopWidgetDesign.apply(DesktopWidgetDesign.shared)
                }
                SelectionGroupButton {
                    visible: DesktopWidgetDesign.canUndo
                    Layout.fillWidth: false
                    leftmost: true; rightmost: true
                    buttonIcon: "undo"
                    buttonText: Translation.tr("Undo design change")
                    onClicked: DesktopWidgetDesign.undo()
                }
            }
            StyledText {
                visible: !root.irisActive
                Layout.fillWidth: true
                text: Translation.tr("Apply one wallpaper-generated color preset to every built-in desktop widget. You can still tune any widget individually below.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }

            SettingsSwitch {
                visible: !root.irisActive
                Layout.fillWidth: true
                buttonIcon: "wallpaper"
                text: Translation.tr("Ink follows the wallpaper")
                autoToggle: false
                checked: root.readPath(
                    "background.widgets.adaptColorsToWallpaperPosition", true)
                onToggledByUser: checked => root.writePath(
                    "background.widgets.adaptColorsToWallpaperPosition", checked)
                StyledToolTip {
                    text: Translation.tr("Each widget reads the wallpaper under it: dark ink and deeper accents where it is light, light ink where it is dark. Off keeps the theme's ink everywhere.")
                }
            }

            WidgetPalettePresetPicker {
                visible: !root.irisActive
                configPath: ""
                applyGlobally: true
            }
        }
    }
        }
    }

    // ── Power Saving ────────────────────────────────────────
    SettingsTaskLoader {
        requested: root.isIiActive && root.activeSection === "manage"
        sourceComponent: Component {
    SettingsCardSection {
        id: powerSavingSection
        settingsTaskSection: "manage"
        expanded: false
        icon: "battery_saver"
        title: Translation.tr("Power Saving")

        // Helper to read powerSaving config with defaults
        function _ps(key: string, defaultVal: bool): bool {
            return Boolean(root.readPath("background.widgets.powerSaving." + key, defaultVal))
        }
        function _setPs(key: string, val: bool): void {
            root.writePath("background.widgets.powerSaving." + key, val)
        }

        SettingsGroup {
            PowerSavingSwitchRow {
                label: Translation.tr("Enable power saving")
                icon: "power_settings_new"
                psKey: "enable"
            }
            PowerSavingSwitchRow {
                label: Translation.tr("Pause on GameMode")
                icon: "sports_esports"
                psKey: "pauseOnGameMode"
            }
            PowerSavingSwitchRow {
                label: Translation.tr("Pause on fullscreen")
                icon: "fullscreen"
                psKey: "pauseOnFullscreen"
            }
            PowerSavingSwitchRow {
                label: Translation.tr("Pause when windows present")
                icon: "web_asset"
                psKey: "pauseWhenWindowsPresent"
                psDefault: false
            }
            PowerSavingSwitchRow {
                label: Translation.tr("Show paused effect")
                icon: "filter_b_and_w"
                psKey: "showPausedEffect"
                psDefault: false
            }

            // Status indicator
            WidgetSettingRow {
                label: Translation.tr("Current status")
                icon: "info"
                trailing: false
                Rectangle {
                    width: powerStatusRow.implicitWidth + 16
                    height: 28
                    radius: Appearance.rounding.small
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    
                    Row {
                        id: powerStatusRow
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: WidgetPowerManager.widgetsActive ? "play_circle" : "pause_circle"
                            iconSize: 16
                            color: WidgetPowerManager.widgetsActive 
                                ? Appearance.colors.colPrimary 
                                : Appearance.colors.colSubtext
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (WidgetPowerManager.widgetsActive)
                                    return Translation.tr("Active")
                                switch (WidgetPowerManager.pauseReason) {
                                case "gameMode": return Translation.tr("Paused - GameMode")
                                case "fullscreen": return Translation.tr("Paused - fullscreen")
                                case "windowsPresent": return Translation.tr("Paused - windows present")
                                case "outputDisabled": return Translation.tr("Paused - output disabled")
                                default: return Translation.tr("Paused")
                                }
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: WidgetPowerManager.widgetsActive 
                                ? Appearance.colors.colPrimary 
                                : Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }
        }
    }

    // ── Clock ───────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                id: clockSection
                settingsTaskSection: "time"
                expanded: true
        icon: "schedule"
        title: Translation.tr("Clock")

        readonly property string _clockStyle: root.readPath("background.widgets.clock.style", "digital")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.clock"
                configEntry: root.readPath("background.widgets.clock", ({}))
                defaultStrategy: "leastBusy"
                defaultEnabled: true
            }

            ContentSubsection {
                title: Translation.tr("Style")

                WidgetSettingRow {
                    label: Translation.tr("Clock style")
                trailing: false

                ConfigSelectionArray {
                    currentValue: root.readPath("background.widgets.clock.style", "digital")
                    onSelected: newValue => root.writePath("background.widgets.clock.style", newValue)
                    options: [
                        { displayName: Translation.tr("Digital"), icon: "timer", value: "digital" },
                        { displayName: Translation.tr("Android stacked"), icon: "android", value: "androidStacked" },
                        { displayName: Translation.tr("Cookie"), icon: "cookie", value: "cookie" },
                        { displayName: Translation.tr("Pixel"), icon: "view_comfy_alt", value: "pixel" },
                        { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" },
                    ]
                }
            }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "pixel"
                title: Translation.tr("Pixel clock")

                WidgetSettingRow {
                    label: Translation.tr("Orientation")
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.clock.pixel.orientation", "horizontal")
                        onSelected: newValue => root.writePath("background.widgets.clock.pixel.orientation", newValue)
                        options: [
                            { displayName: Translation.tr("Horizontal"), icon: "view_week", value: "horizontal" },
                            { displayName: Translation.tr("Vertical"), icon: "view_agenda", value: "vertical" }
                        ]
                    }
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "digital" || clockSection._clockStyle === "androidStacked"
                title: Translation.tr("Time format")

                WidgetSettingRow {
                visible: clockSection._clockStyle === "digital" || clockSection._clockStyle === "androidStacked"
                label: Translation.tr("Time format")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.clock.timeFormat", "system")
                    onSelected: newValue => root.writePath("background.widgets.clock.timeFormat", newValue)
                    options: [
                        { displayName: Translation.tr("System"), icon: "settings", value: "system" },
                        { displayName: Translation.tr("24h"), icon: "schedule", value: "24h" },
                        { displayName: Translation.tr("12h"), icon: "nest_clock_farsight_analog", value: "12h" },
                    ]
                }
            }

            WidgetSettingRow {
                visible: clockSection._clockStyle === "digital"
                label: Translation.tr("Date style")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.clock.dateStyle", "long")
                    onSelected: newValue => root.writePath("background.widgets.clock.dateStyle", newValue)
                    options: [
                        { displayName: Translation.tr("Long"), icon: "calendar_month", value: "long" },
                        { displayName: Translation.tr("Minimal"), icon: "event_note", value: "minimal" },
                        { displayName: Translation.tr("Weekday"), icon: "today", value: "weekday" },
                        { displayName: Translation.tr("Numeric"), icon: "pin", value: "numeric" },
                    ]
                }
            }

            WidgetSettingRow {
                visible: clockSection._clockStyle === "digital"
                label: Translation.tr("Digital preset")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.clock.digital.preset", "default")
                    onSelected: newValue => {
                        root.writePath("background.widgets.clock.digital.preset", newValue);
                        if (newValue === "default") {
                            root.writePath("background.widgets.clock.digital.fontWeight", 600);
                            root.writePath("background.widgets.clock.digital.spacing", 6);
                        } else if (newValue === "light") {
                            root.writePath("background.widgets.clock.digital.fontWeight", 300);
                            root.writePath("background.widgets.clock.digital.spacing", 8);
                        } else if (newValue === "bold") {
                            root.writePath("background.widgets.clock.digital.fontWeight", 800);
                            root.writePath("background.widgets.clock.digital.spacing", 4);
                        } else if (newValue === "mono") {
                            root.writePath("background.widgets.clock.digital.fontWeight", 500);
                            root.writePath("background.widgets.clock.digital.spacing", 2);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "timer", value: "default" },
                        { displayName: Translation.tr("Light"), icon: "format_size", value: "light" },
                        { displayName: Translation.tr("Bold"), icon: "format_bold", value: "bold" },
                        { displayName: Translation.tr("Mono"), icon: "terminal", value: "mono" },
                    ]
                }
            }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "digital" || clockSection._clockStyle === "androidStacked"
                title: Translation.tr("Display options")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "timer"
                        text: Translation.tr("Seconds")
                        autoToggle: false

                        checked: root.readPath("background.widgets.clock.showSeconds", false)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.showSeconds", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "calendar_today"
                        text: Translation.tr("Date")
                        autoToggle: false

                        checked: root.readPath("background.widgets.clock.showDate", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.showDate", checked)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "shadow"
                        text: Translation.tr("Shadow")
                        autoToggle: false

                        checked: root.readPath("background.widgets.clock.showShadow", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.showShadow", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "animation"
                        text: Translation.tr("Animate")
                        autoToggle: false

                        checked: root.readPath("background.widgets.clock.digital.animateChange", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.digital.animateChange", checked)
                    }
                }
                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "wallpaper"
                        text: Translation.tr("Adapt digital clock locally")
                        autoToggle: false
                        enabled: root.readPath(
                            "background.widgets.adaptColorsToWallpaperPosition", true)
                        opacity: enabled ? 1 : 0.45
                        checked: root.readPath("background.widgets.clock.digital.adaptToWallpaper", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.digital.adaptToWallpaper", checked)
                        StyledToolTip {
                            text: enabled
                                ? Translation.tr("Let the digital clock use the wallpaper sample behind it.")
                                : Translation.tr("Turn on Ink follows the wallpaper in Widget Colors first.")
                        }
                    }
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        visible: clockSection._clockStyle === "digital"
                        label: Translation.tr("Font weight")
                        StyledSpinBox {
                            from: 100; to: 900; stepSize: 100
                            value: root.readPath("background.widgets.clock.digital.fontWeight", 600)
                            onValueModified: root.writePath("background.widgets.clock.digital.fontWeight", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: clockSection._clockStyle === "digital"
                        label: Translation.tr("Spacing")
                        StyledSpinBox {
                            from: 0; to: 20; stepSize: 1
                            value: root.readPath("background.widgets.clock.digital.spacing", 6)
                            onValueModified: root.writePath("background.widgets.clock.digital.spacing", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Time scale")
                        StyledSpinBox {
                            from: 50; to: 200; stepSize: 5
                            value: root.readPath("background.widgets.clock.timeScale", 100)
                            onValueModified: root.writePath("background.widgets.clock.timeScale", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Date scale")
                        StyledSpinBox {
                            from: 50; to: 200; stepSize: 5
                            value: root.readPath("background.widgets.clock.dateScale", 100)
                            onValueModified: root.writePath("background.widgets.clock.dateScale", value)
                        }
                    }
                }

                FontSelector {
                    id: clockFontSelector
                    label: Translation.tr("Clock font")
                    icon: "font_download"
                    selectedFont: root.readPath("background.widgets.clock.fontFamily", "Space Grotesk")
                    onSelectedFontChanged: {
                        if (selectedFont !== root.readPath("background.widgets.clock.fontFamily", "Space Grotesk"))
                            root.writePath("background.widgets.clock.fontFamily", selectedFont)
                    }
                    Connections {
                        target: Config.options?.background?.widgets?.clock ?? null
                        function onFontFamilyChanged() { clockFontSelector.selectedFont = root.readPath("background.widgets.clock.fontFamily", "Space Grotesk") }
                    }
                }
            }

            // ── Cookie clock settings ──
            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Cookie clock shape")

                WidgetSettingRow {
                    label: Translation.tr("Preset")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.clock.cookie.preset", "default")
                        onSelected: newValue => {
                            root.writePath("background.widgets.clock.cookie.preset", newValue);
                            if (newValue === "default") {
                                root.writePath("background.widgets.clock.cookie.size", 230);
                                root.writePath("background.widgets.clock.cookie.sides", 15);
                                root.writePath("background.widgets.clock.cookie.dialNumberStyle", "full");
                                root.writePath("background.widgets.clock.cookie.hourHandStyle", "hollow");
                            } else if (newValue === "compact") {
                                root.writePath("background.widgets.clock.cookie.size", 160);
                                root.writePath("background.widgets.clock.cookie.sides", 12);
                                root.writePath("background.widgets.clock.cookie.dialNumberStyle", "dots");
                                root.writePath("background.widgets.clock.cookie.hourHandStyle", "fill");
                            } else if (newValue === "large") {
                                root.writePath("background.widgets.clock.cookie.size", 300);
                                root.writePath("background.widgets.clock.cookie.sides", 18);
                                root.writePath("background.widgets.clock.cookie.dialNumberStyle", "numbers");
                                root.writePath("background.widgets.clock.cookie.hourHandStyle", "classic");
                            } else if (newValue === "minimal") {
                                root.writePath("background.widgets.clock.cookie.size", 200);
                                root.writePath("background.widgets.clock.cookie.sides", 6);
                                root.writePath("background.widgets.clock.cookie.dialNumberStyle", "none");
                                root.writePath("background.widgets.clock.cookie.hourHandStyle", "fill");
                            }
                        }
                        options: [
                            { displayName: Translation.tr("Default"), icon: "cookie", value: "default" },
                            { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                            { displayName: Translation.tr("Large"), icon: "open_in_full", value: "large" },
                            { displayName: Translation.tr("Minimal"), icon: "circle", value: "minimal" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Size")
                    StyledSpinBox {
                        from: 100; to: 400; stepSize: 10
                        value: root.readPath("background.widgets.clock.cookie.size", 230)
                        onValueModified: root.writePath("background.widgets.clock.cookie.size", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "waves"
                    text: Translation.tr("Sine wave shape")
                    autoToggle: false

                    checked: root.readPath("background.widgets.clock.cookie.useSineCookie", false)
                    onToggledByUser: checked => root.writePath("background.widgets.clock.cookie.useSineCookie", checked)
                    StyledToolTip { text: Translation.tr("Use smooth sine-wave edges instead of rounded polygon") }
                }

                WidgetSettingRow {
                    label: Translation.tr("Sides")
                    StyledSpinBox {
                        from: 3; to: 30; stepSize: 1
                        value: root.readPath("background.widgets.clock.cookie.sides", 15)
                        onValueModified: root.writePath("background.widgets.clock.cookie.sides", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "rotate_right"
                    text: Translation.tr("Constant rotation")
                    autoToggle: false

                    checked: root.readPath("background.widgets.clock.cookie.constantlyRotate", false)
                    onToggledByUser: checked => root.writePath("background.widgets.clock.cookie.constantlyRotate", checked)
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "instrument"
                title: Translation.tr("Instrument")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "timelapse"
                        text: Translation.tr("Seconds")
                        autoToggle: false
                        checked: root.readPath("background.widgets.clock.showSeconds", false)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.showSeconds", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "calendar_today"
                        text: Translation.tr("Date")
                        autoToggle: false
                        checked: root.readPath("background.widgets.clock.showDate", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.showDate", checked)
                    }
                }

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "blur_on"
                        text: Translation.tr("Minute trail")
                        autoToggle: false
                        checked: root.readPath("background.widgets.clock.instrumentTrail", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.instrumentTrail", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "pin"
                        text: Translation.tr("Numerals")
                        autoToggle: false
                        checked: root.readPath("background.widgets.clock.instrumentNumerals", true)
                        onToggledByUser: checked => root.writePath("background.widgets.clock.instrumentNumerals", checked)
                    }
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.clock.instrumentTrail", true)
                    label: Translation.tr("Trail length")
                    icon: "history"
                    StyledSpinBox {
                        from: 2; to: 15; stepSize: 1
                        value: root.readPath("background.widgets.clock.instrumentTrailLength", 6)
                        onValueModified: root.writePath("background.widgets.clock.instrumentTrailLength", value)
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Instrument size")
                    icon: "open_in_full"
                    StyledSpinBox {
                        from: 60; to: 180; stepSize: 5
                        value: root.readPath("background.widgets.clock.timeScale", 100)
                        onValueModified: root.writePath("background.widgets.clock.timeScale", value)
                    }
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("Dial and hands")

                WidgetSettingRow {
                    label: Translation.tr("Dial style")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.clock.cookie.dialNumberStyle", "full")
                        onSelected: newValue => root.writePath("background.widgets.clock.cookie.dialNumberStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Lines"), icon: "linear_scale", value: "full" },
                            { displayName: Translation.tr("Dots"), icon: "more_horiz", value: "dots" },
                            { displayName: Translation.tr("Numbers"), icon: "123", value: "numbers" },
                            { displayName: Translation.tr("None"), icon: "block", value: "none" },
                        ]
                    }

                    ConfigRow {
                        Layout.fillWidth: true
                        SettingsSwitch {
                            Layout.fillWidth: false
                            buttonIcon: "radio_button_checked"
                            text: Translation.tr("Hour marks")
                            autoToggle: false

                            checked: root.readPath("background.widgets.clock.cookie.hourMarks", false)
                            onToggledByUser: checked => root.writePath("background.widgets.clock.cookie.hourMarks", checked)
                        }
                        SettingsSwitch {
                            Layout.fillWidth: false
                            buttonIcon: "pin"
                            text: Translation.tr("Time column")
                            autoToggle: false

                            checked: root.readPath("background.widgets.clock.cookie.timeIndicators", false)
                            onToggledByUser: checked => root.writePath("background.widgets.clock.cookie.timeIndicators", checked)
                        }
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Hour hand")
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: root.readPath("background.widgets.clock.cookie.hourHandStyle", "hollow")
                        onSelected: newValue => root.writePath("background.widgets.clock.cookie.hourHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Fill"), icon: "rectangle", value: "fill" },
                            { displayName: Translation.tr("Hollow"), icon: "crop_square", value: "hollow" },
                            { displayName: Translation.tr("Classic"), icon: "straighten", value: "classic" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Minute hand")
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: root.readPath("background.widgets.clock.cookie.minuteHandStyle", "hide")
                        onSelected: newValue => root.writePath("background.widgets.clock.cookie.minuteHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Bold"), icon: "rectangle", value: "bold" },
                            { displayName: Translation.tr("Medium"), icon: "horizontal_rule", value: "medium" },
                            { displayName: Translation.tr("Thin"), icon: "remove", value: "thin" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Second hand")
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: false
                        currentValue: root.readPath("background.widgets.clock.cookie.secondHandStyle", "hide")
                        onSelected: newValue => root.writePath("background.widgets.clock.cookie.secondHandStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Classic"), icon: "straighten", value: "classic" },
                            { displayName: Translation.tr("Dot"), icon: "circle", value: "dot" },
                            { displayName: Translation.tr("Line"), icon: "remove", value: "line" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Date indicator")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.clock.cookie.dateStyle", "bubble")
                        onSelected: newValue => root.writePath("background.widgets.clock.cookie.dateStyle", newValue)
                        options: [
                            { displayName: Translation.tr("Bubble"), icon: "chat_bubble", value: "bubble" },
                            { displayName: Translation.tr("Rectangle"), icon: "crop_square", value: "rect" },
                            { displayName: Translation.tr("Border"), icon: "rotate_right", value: "border" },
                            { displayName: Translation.tr("Hide"), icon: "visibility_off", value: "hide" },
                        ]
                    }
                }
            }

            ContentSubsection {
                visible: clockSection._clockStyle === "cookie"
                title: Translation.tr("AI styling")

                SettingsSwitch {
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("Auto-style from wallpaper")
                    autoToggle: false

                    checked: root.readPath("background.widgets.clock.cookie.aiStyling", false)
                    onToggledByUser: checked => root.writePath("background.widgets.clock.cookie.aiStyling", checked)
                    StyledToolTip { text: Translation.tr("Automatically adjust cookie clock style based on wallpaper category") }
                }
            }

            // ── Quote (digital + cookie) ──
            ContentSubsection {
                visible: clockSection._clockStyle === "digital" || clockSection._clockStyle === "cookie"
                title: Translation.tr("Quote")

                SettingsSwitch {
                    buttonIcon: "format_quote"
                    text: Translation.tr("Show quote")
                    autoToggle: false

                    checked: root.readPath("background.widgets.clock.quote.enable", false)
                    onToggledByUser: checked => root.writePath("background.widgets.clock.quote.enable", checked)
                }

                MaterialTextField {
                    visible: root.readPath("background.widgets.clock.quote.enable", false)
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Enter a quote or message...")
                    text: root.readPath("background.widgets.clock.quote.text", "")
                    onAccepted: root.writePath("background.widgets.clock.quote.text", text)
                    onEditingFinished: root.writePath("background.widgets.clock.quote.text", text)
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.clock"
                configEntry: root.readPath("background.widgets.clock", ({}))
                dimDefault: 70
                hasColorMode: clockSection._clockStyle === "digital" || clockSection._clockStyle === "androidStacked"
                hasCardControls: clockSection._clockStyle === "digital" || clockSection._clockStyle === "androidStacked"
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.clock"
                defaults: ({
                    "cookie": {
                                        "aiStyling": false,
                                        "constantlyRotate": false,
                                        "dateInClock": true,
                                        "dateStyle": "bubble",
                                        "dialNumberStyle": "full",
                                        "hourHandStyle": "hollow",
                                        "hourMarks": false,
                                        "minuteHandStyle": "hide",
                                        "secondHandStyle": "hide",
                                        "sides": 15,
                                        "timeIndicators": false,
                                        "useSineCookie": false,
                                        "size": 230,
                                        "preset": "default"
                    },
                    "dateStyle": "long",
                    "digital": {
                                        "adaptToWallpaper": true,
                                        "animateChange": true,
                                        "fontWeight": 600,
                                        "spacing": 6,
                                        "preset": "default"
                    },
                    "pixel": {
                                        "orientation": "horizontal"
                    },
                    "dim": 0,
                    "fontFamily": "Space Grotesk",
                    "placementStrategy": "free",
                    "quote": {
                                        "enable": false,
                                        "text": ""
                    },
                    "showDate": true,
                    "showSeconds": false,
                    "instrumentTrail": true,
                    "instrumentTrailLength": 6,
                    "instrumentNumerals": true,
                    "showShadow": true,
                    "style": "digital",
                    "timeFormat": "system",
                    "timeScale": 100,
                    "dateScale": 100,
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "showBackground": false,
                    "useBlur": false,
                    "showBorder": false,
                    "backgroundOpacity": 0,
                    "borderWidth": 0,
                    "borderOpacity": 0.08,
                    "cornerRadius": -1,
                    "colorMode": "auto",
                    "x": 100,
                    "y": 100,
                    "locked": false
})
            }
            }
            }
        }
    }

    // ── World clock ─────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
        icon: "public"
        title: Translation.tr("World clock")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.worldClock"
                configEntry: root.readPath("background.widgets.worldClock", ({}))
                defaultStrategy: "free"
            }

            WidgetSettingRow {
                label: Translation.tr("Style")
                trailing: false
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.worldClock.style", "cards")
                    onSelected: newValue => root.writePath("background.widgets.worldClock.style", newValue)
                    options: [
                        { displayName: Translation.tr("List"), icon: "view_list", value: "cards" },
                        { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                }
            }


            WidgetSettingRow {
                visible: root.readPath("background.widgets.worldClock.style", "cards") === "instrument"
                label: Translation.tr("Instrument layout")
                icon: "grid_view"
                trailing: false
                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.worldClock.instrumentLayout", "grid")
                    onSelected: newValue => root.writePath("background.widgets.worldClock.instrumentLayout", newValue)
                    options: [
                        { displayName: Translation.tr("Atlas"), icon: "travel_explore", value: "grid" },
                        { displayName: Translation.tr("Strip"), icon: "view_agenda", value: "rows" }
                    ]
                }
            }

            WidgetSettingRow {
                visible: root.readPath("background.widgets.worldClock.style", "cards") === "instrument"
                label: Translation.tr("Instrument detail")
                icon: "tune"
                trailing: false
                GridLayout {
                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 6
                    WidgetToggleChip {
                        configPath: "background.widgets.worldClock.showOffsets"
                        defaultValue: true
                        buttonIcon: "schedule"
                        buttonText: Translation.tr("Offsets")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.worldClock.showDate"
                        defaultValue: true
                        buttonIcon: "calendar_today"
                        buttonText: Translation.tr("Date")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.worldClock.showDayState"
                        defaultValue: true
                        buttonIcon: "routine"
                        buttonText: Translation.tr("Day/Night")
                    }
                }
            }

            ContentSubsection {
                id: worldClockZones
                property var availableTimezones: WorldClock.comboModel.filter(
                    entry => !WorldClock.timezones.includes(entry.tz))
                title: Translation.tr("Time zones")

                Repeater {
                    model: WorldClock.timezones.length
                    delegate: WidgetSettingRow {
                        id: tzRow
                        required property int index
                        label: Translation.tr("City %1").arg(tzRow.index + 1)
                        icon: "schedule"
                        trailing: false

                        StyledComboBox {
                            Layout.fillWidth: true
                            model: WorldClock.comboModel
                            textRole: "label"
                            currentIndex: Math.max(0, WorldClock.comboModel.findIndex(o => o.tz === WorldClock.timezones[tzRow.index]))
                            onActivated: idx => WorldClock.setTimezone(tzRow.index, WorldClock.comboModel[idx].tz)
                        }

                        RippleButton {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            enabled: WorldClock.timezones.length > 1
                            opacity: enabled ? 1 : 0.32
                            buttonRadius: Appearance.rounding.small
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colLayer2Hover
                            colRipple: Appearance.colors.colLayer2Active
                            releaseAction: () => WorldClock.removeTimezone(tzRow.index)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                color: Appearance.colors.colOnLayer1
                                iconSize: 17
                            }
                            StyledToolTip { text: Translation.tr("Remove city") }
                        }
                    }
                }

                WidgetSettingRow {
                    visible: WorldClock.timezones.length < WorldClock.maxTimezones
                        && worldClockZones.availableTimezones.length > 0
                    label: Translation.tr("Add city")
                    icon: "add_location_alt"
                    trailing: false

                    StyledComboBox {
                        id: worldClockAddZone
                        Layout.fillWidth: true
                        model: worldClockZones.availableTimezones
                        textRole: "label"
                    }
                    RippleButton {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 34
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colPrimaryContainer
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        releaseAction: () => {
                            const entry = worldClockZones.availableTimezones[worldClockAddZone.currentIndex]
                            if (entry)
                                WorldClock.addTimezone(entry.tz)
                        }
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "add"
                            color: Appearance.colors.colOnPrimaryContainer
                            iconSize: 18
                        }
                        StyledToolTip { text: Translation.tr("Add city") }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("worldClock")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 240; to: 700; stepSize: 10
                        value: root.readPath("background.widgets.worldClock.contentWidth", 300)
                        onValueModified: root.writePath("background.widgets.worldClock.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 190; to: 480; stepSize: 4
                        value: root.readPath("background.widgets.worldClock.contentHeight", 210)
                        onValueModified: root.writePath("background.widgets.worldClock.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.worldClock"
                configEntry: root.readPath("background.widgets.worldClock", ({}))
                hasCardControls: root.readPath("background.widgets.worldClock.style", "cards") !== "instrument"
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.worldClock"
                defaults: ({
                    placementStrategy: "free", contentWidth: 300, contentHeight: 210,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 200,
                    timezones: ["Asia/Tokyo", "Europe/London", "America/New_York"],
                    style: "cards", instrumentLayout: "grid", showNames: true,
                    showOffsets: true, showDate: true, showDayState: true, pulseSeparator: false
                })
            }
        }
            }
        }
    }

    // ── Month Calendar ──────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
                icon: "calendar_month"
                title: Translation.tr("Month Calendar")

                SettingsGroup {
                    WidgetStateControls {
                        configPath: "background.widgets.monthCalendar"
                        configEntry: root.readPath("background.widgets.monthCalendar", ({}))
                        defaultStrategy: "free"
                    }
                    ContentSubsection {
                        title: Translation.tr("Calendar")
                        WidgetSettingRow {
                            label: Translation.tr("Style")
                            trailing: false
                            ConfigSelectionArray {
                                Layout.fillWidth: true
                                currentValue: root.readPath("background.widgets.monthCalendar.style", "card")
                                onSelected: newValue => root.writePath("background.widgets.monthCalendar.style", newValue)
                                options: [
                                    { displayName: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                                    { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                                ]
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Week starts on")
                            trailing: false
                            ConfigSelectionArray {
                                Layout.fillWidth: true
                                currentValue: root.readPath("background.widgets.monthCalendar.weekStart", 1)
                                onSelected: newValue => root.writePath("background.widgets.monthCalendar.weekStart", newValue)
                                options: [
                                    { displayName: Translation.tr("Monday"), icon: "calendar_view_week", value: 1 },
                                    { displayName: Translation.tr("Sunday"), icon: "calendar_view_week", value: 0 }
                                ]
                            }
                        }
                        SettingsSwitch {
                            buttonIcon: "date_range"
                            text: Translation.tr("Show adjacent month days")
                            autoToggle: false
                            checked: root.readPath("background.widgets.monthCalendar.showAdjacentDays", true)
                            onToggledByUser: checked => root.writePath("background.widgets.monthCalendar.showAdjacentDays", checked)
                        }
                        SettingsSwitch {
                            visible: root.readPath("background.widgets.monthCalendar.style", "card") === "instrument"
                            buttonIcon: "horizontal_rule"
                            text: Translation.tr("Header rule")
                            autoToggle: false
                            checked: root.readPath("background.widgets.monthCalendar.instrumentRule", true)
                            onToggledByUser: checked => root.writePath("background.widgets.monthCalendar.instrumentRule", checked)
                        }
                    }
                    ContentSubsection {
                        title: Translation.tr("Dimensions")
                        // a sized card takes its width and height from its size
                        visible: !root.sizedWidget("monthCalendar")
                        WidgetSettingRow {
                            label: Translation.tr("Width")
                            icon: "swap_horiz"
                            StyledSpinBox {
                                from: 252; to: 520; stepSize: 4
                                value: root.readPath("background.widgets.monthCalendar.contentWidth", 300)
                                onValueModified: root.writePath("background.widgets.monthCalendar.contentWidth", value)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Height")
                            icon: "swap_vert"
                            StyledSpinBox {
                                from: 290; to: 620; stepSize: 4
                                value: root.readPath("background.widgets.monthCalendar.contentHeight", 340)
                                onValueModified: root.writePath("background.widgets.monthCalendar.contentHeight", value)
                            }
                        }
                    }
                    WidgetAppearanceControls {
                        configPath: "background.widgets.monthCalendar"
                        configEntry: root.readPath("background.widgets.monthCalendar", ({}))
                        hasCardControls: true
                    }
                }

                SettingsGroup {
                    WidgetResetButton {
                        configPath: "background.widgets.monthCalendar"
                        defaults: ({
                            placementStrategy: "free", contentWidth: 300, contentHeight: 340,
                            weekStart: 1, showAdjacentDays: true, style: "card", instrumentRule: true,
                            widgetScale: 100,
                            widgetOpacity: 100, showBackground: true, useBlur: false,
                            showBorder: true, backgroundOpacity: 0.14, borderWidth: 1,
                            borderOpacity: 0.16, cornerRadius: -1, colorMode: "auto",
                            dim: 0, locked: false, x: 420, y: 120
                        })
                    }
                }
            }
        }
    }

    // ── Upcoming Events ─────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
        icon: "event"
        title: Translation.tr("Upcoming Events")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.calendarUpcoming"
                configEntry: root.readPath("background.widgets.calendarUpcoming", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Content")
                WidgetSettingRow {
                    label: Translation.tr("Presentation")
                    icon: "view_quilt"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.calendarUpcoming.style", "card")
                        onSelected: newValue => root.writePath("background.widgets.calendarUpcoming.style", newValue)
                        options: [
                            { displayName: Translation.tr("Card"), value: "card" },
                            { displayName: Translation.tr("Instrument"), value: "instrument" }
                        ]
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Maximum events")
                    icon: "format_list_numbered"
                    StyledSpinBox {
                        from: 1; to: 12; stepSize: 1
                        value: root.readPath("background.widgets.calendarUpcoming.maxEvents", 5)
                        onValueModified: root.writePath("background.widgets.calendarUpcoming.maxEvents", value)
                    }
                }
                ConfigRow {
                    SettingsSwitch {
                        buttonIcon: "today"
                        text: Translation.tr("Show date")
                        autoToggle: false
                        checked: root.readPath("background.widgets.calendarUpcoming.showDate", true)
                        onToggledByUser: checked => root.writePath("background.widgets.calendarUpcoming.showDate", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "schedule"
                        text: Translation.tr("Show time")
                        autoToggle: false
                        checked: root.readPath("background.widgets.calendarUpcoming.showTime", true)
                        onToggledByUser: checked => root.writePath("background.widgets.calendarUpcoming.showTime", checked)
                    }
                }
                ConfigRow {
                    SettingsSwitch {
                        buttonIcon: "place"
                        text: Translation.tr("Show location")
                        autoToggle: false
                        checked: root.readPath("background.widgets.calendarUpcoming.showLocation", false)
                        onToggledByUser: checked => root.writePath("background.widgets.calendarUpcoming.showLocation", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "view_day"
                        text: Translation.tr("Group by day")
                        autoToggle: false
                        checked: root.readPath("background.widgets.calendarUpcoming.groupByDay", true)
                        onToggledByUser: checked => root.writePath("background.widgets.calendarUpcoming.groupByDay", checked)
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("calendarUpcoming")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 200; to: 720; stepSize: 10
                        value: root.readPath("background.widgets.calendarUpcoming.contentWidth", 280)
                        onValueModified: root.writePath("background.widgets.calendarUpcoming.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 140; to: 720; stepSize: 10
                        value: root.readPath("background.widgets.calendarUpcoming.contentHeight", 220)
                        onValueModified: root.writePath("background.widgets.calendarUpcoming.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.calendarUpcoming"
                configEntry: root.readPath("background.widgets.calendarUpcoming", ({}))
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.calendarUpcoming"
                defaults: ({
                    placementStrategy: "free", maxEvents: 5, showDate: true, showTime: true,
                    showLocation: false, groupByDay: true, style: "card",
                    contentWidth: 280, contentHeight: 240,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.10,
                    borderWidth: 1, borderOpacity: 0.12, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 80
                })
            }
        }
            }
        }
    }

    // ── Date badge ──────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
        icon: "today"
        title: Translation.tr("Date badge")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.dateBadge"
                configEntry: root.readPath("background.widgets.dateBadge", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("dateBadge")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 140; to: 600; stepSize: 10
                        value: root.readPath("background.widgets.dateBadge.contentWidth", 220)
                        onValueModified: root.writePath("background.widgets.dateBadge.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 120; to: 240; stepSize: 4
                        value: root.readPath("background.widgets.dateBadge.contentHeight", 140)
                        onValueModified: root.writePath("background.widgets.dateBadge.contentHeight", value)
                    }
                }
            }

            ConfigSelectionArray {
                currentValue: root.readPath("background.widgets.dateBadge.style", "ticket")
                onSelected: newValue => root.writePath("background.widgets.dateBadge.style", newValue)
                options: [
                    { displayName: Translation.tr("Ticket"), value: "ticket" },
                    { displayName: Translation.tr("Stacked"), value: "stacked" },
                    { displayName: Translation.tr("Seal"), value: "seal" },
                    { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                ]
            }
            ConfigSelectionArray {
                currentValue: root.readPath("background.widgets.dateBadge.showYear", true)
                onSelected: newValue => root.writePath("background.widgets.dateBadge.showYear", newValue)
                options: [{ displayName: Translation.tr("Show year"), value: true }, { displayName: Translation.tr("Hide year"), value: false }]
            }
            WidgetSettingRow {
                visible: root.readPath("background.widgets.dateBadge.style", "ticket") === "instrument"
                label: Translation.tr("Instrument details")
                icon: "tune"
                trailing: false
                RowLayout {
                    spacing: 6
                    WidgetToggleChip {
                        configPath: "background.widgets.dateBadge.showWeekday"
                        defaultValue: true
                        buttonIcon: "calendar_view_week"
                        buttonText: Translation.tr("Weekday")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.dateBadge.showOrdinal"
                        defaultValue: true
                        buttonIcon: "tag"
                        buttonText: Translation.tr("Ordinal")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.dateBadge.instrumentMarks"
                        defaultValue: true
                        buttonIcon: "crop_free"
                        buttonText: Translation.tr("Marks")
                    }
                }
            }
            WidgetAppearanceControls {
                configPath: "background.widgets.dateBadge"
                configEntry: root.readPath("background.widgets.dateBadge", ({}))
                hasCardControls: root.readPath("background.widgets.dateBadge.style", "ticket") !== "instrument"
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.dateBadge"
                defaults: ({
                    placementStrategy: "free", contentWidth: 220, contentHeight: 140,
                    style: "ticket", showYear: true, showWeekday: true, showOrdinal: true,
                    instrumentMarks: true, dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 260, y: 80
                })
            }
        }
            }
        }
    }

    // ── Day progress ────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
                icon: "av_timer"
                title: Translation.tr("Day progress widget")

                SettingsGroup {
                    WidgetStateControls {
                        configPath: "background.widgets.dayProgress"
                        configEntry: root.readPath("background.widgets.dayProgress", ({}))
                        defaultStrategy: "free"
                    }
                    ContentSubsection {
                        title: Translation.tr("Dimensions")
                        // a sized card takes its width and height from its size
                        visible: !root.sizedWidget("dayProgress")

                        WidgetSettingRow {
                            label: Translation.tr("Width")
                            icon: "swap_horiz"
                            StyledSpinBox {
                                from: 190; to: 500; stepSize: 10
                                value: root.readPath("background.widgets.dayProgress.contentWidth", 240)
                                onValueModified: root.writePath("background.widgets.dayProgress.contentWidth", value)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Height")
                            icon: "swap_vert"
                            StyledSpinBox {
                                from: 190; to: 500; stepSize: 10
                                value: root.readPath("background.widgets.dayProgress.contentHeight", 240)
                                onValueModified: root.writePath("background.widgets.dayProgress.contentHeight", value)
                            }
                        }
                    }

                    ContentSubsection {
                        title: Translation.tr("Style")

                        ConfigSelectionArray {
                            currentValue: root.readPath("background.widgets.dayProgress.style", "ring")
                            onSelected: newValue => root.writePath("background.widgets.dayProgress.style", newValue)
                            options: [
                                { displayName: Translation.tr("Ring"), value: "ring" },
                                { displayName: Translation.tr("Arc"), value: "arc" },
                                { displayName: Translation.tr("Ticks"), value: "ticks" }
                            ]
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Comet tail")
                            icon: "flare"
                            StyledSwitch {
                                checked: root.readPath("background.widgets.dayProgress.comet", true)
                                onToggled: root.writePath("background.widgets.dayProgress.comet", checked)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Sun icon")
                            icon: "light_mode"
                            StyledSwitch {
                                checked: root.readPath("background.widgets.dayProgress.showIcon", true)
                                onToggled: root.writePath("background.widgets.dayProgress.showIcon", checked)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Show date")
                            icon: "event"
                            StyledSwitch {
                                checked: root.readPath("background.widgets.dayProgress.showDate", true)
                                onToggled: root.writePath("background.widgets.dayProgress.showDate", checked)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Hour labels")
                            icon: "pin_drop"
                            StyledSwitch {
                                checked: root.readPath("background.widgets.dayProgress.hourLabels", true)
                                onToggled: root.writePath("background.widgets.dayProgress.hourLabels", checked)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Text size")
                            icon: "format_size"
                            StyledSpinBox {
                                from: 60; to: 180; stepSize: 10
                                value: root.readPath("background.widgets.dayProgress.fontScale", 100)
                                onValueModified: root.writePath("background.widgets.dayProgress.fontScale", value)
                            }
                        }
                    }

                    WidgetAppearanceControls {
                        configPath: "background.widgets.dayProgress"
                        configEntry: root.readPath("background.widgets.dayProgress", ({}))
                        hasCardControls: false
                    }
                }

                SettingsGroup {
                    WidgetResetButton {
                        configPath: "background.widgets.dayProgress"
                        defaults: ({
                            placementStrategy: "free", contentWidth: 240, contentHeight: 240,
                            dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: false,
                            style: "ring", comet: true, showIcon: true, showDate: true, hourLabels: true, fontScale: 100,
                            useBlur: false, showBorder: false, backgroundOpacity: 0,
                            borderWidth: 0, borderOpacity: 0.20, cornerRadius: -1,
                            colorMode: "auto", locked: false, x: 80, y: 260
                        })
                    }
                }
            }
        }
    }

    // ── Timers ──────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
                icon: "timer"
                title: Translation.tr("Timers")

                SettingsGroup {
                    WidgetStateControls {
                        configPath: "background.widgets.timers"
                        configEntry: root.readPath("background.widgets.timers", ({}))
                        defaultStrategy: "free"
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Style")
                        trailing: false
                        ConfigSelectionArray {
                            Layout.fillWidth: true
                            currentValue: root.readPath("background.widgets.timers.style", "cards")
                            onSelected: newValue => root.writePath("background.widgets.timers.style", newValue)
                            options: [
                                { displayName: Translation.tr("Cards"), icon: "dashboard_2", value: "cards" },
                                { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                            ]
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Orientation")
                        trailing: false
                        ConfigSelectionArray {
                            Layout.fillWidth: true
                            currentValue: root.readPath("background.widgets.timers.vertical", false)
                            onSelected: newValue => root.writePath("background.widgets.timers.vertical", newValue)
                            options: [
                                { displayName: Translation.tr("Horizontal"), icon: "view_week", value: false },
                                { displayName: Translation.tr("Vertical"), icon: "view_agenda", value: true }
                            ]
                        }
                    }
                    WidgetSettingRow {
                        visible: root.readPath("background.widgets.timers.style", "cards") === "instrument"
                        label: Translation.tr("Instrument details")
                        icon: "tune"
                        trailing: false
                        GridLayout {
                            columns: 2
                            columnSpacing: 6
                            rowSpacing: 6
                            WidgetToggleChip {
                                configPath: "background.widgets.timers.glow"
                                defaultValue: true
                                buttonIcon: "bolt"
                                buttonText: Translation.tr("Active pulse")
                            }
                            WidgetToggleChip {
                                configPath: "background.widgets.timers.showProgress"
                                defaultValue: true
                                buttonIcon: "linear_scale"
                                buttonText: Translation.tr("Progress")
                            }
                            WidgetToggleChip {
                                configPath: "background.widgets.timers.showState"
                                defaultValue: true
                                buttonIcon: "label"
                                buttonText: Translation.tr("Details")
                            }
                            WidgetToggleChip {
                                configPath: "background.widgets.timers.showHundredths"
                                defaultValue: true
                                buttonIcon: "timer_10_alt_1"
                                buttonText: Translation.tr("Hundredths")
                            }
                        }
                    }
                    WidgetAppearanceControls {
                        configPath: "background.widgets.timers"
                        configEntry: root.readPath("background.widgets.timers", ({}))
                        hasCardControls: false
                    }
                }

                SettingsGroup {
                    WidgetResetButton {
                        configPath: "background.widgets.timers"
                        defaults: ({
                            placementStrategy: "free", vertical: false, style: "cards", glow: true,
                            showProgress: true, showState: true, showHundredths: true, widgetScale: 100,
                            widgetOpacity: 100, showBackground: false, useBlur: false,
                            showBorder: false, backgroundOpacity: 0, borderWidth: 0,
                            borderOpacity: 0.16, cornerRadius: -1, colorMode: "auto",
                            dim: 0, locked: false, x: 360, y: 420
                        })
                    }
                }
            }
        }
    }

    // ── System uptime ───────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "time"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "time"
                expanded: false
        icon: "avg_pace"
        title: Translation.tr("System uptime")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.uptime"
                configEntry: root.readPath("background.widgets.uptime", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("uptime")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 180; to: 600; stepSize: 10
                        value: root.readPath("background.widgets.uptime.contentWidth", 250)
                        onValueModified: root.writePath("background.widgets.uptime.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 72; to: 240; stepSize: 4
                        value: root.readPath("background.widgets.uptime.contentHeight", 96)
                        onValueModified: root.writePath("background.widgets.uptime.contentHeight", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style")

                ConfigSelectionArray {
                    currentValue: root.readPath("background.widgets.uptime.style", "row")
                    onSelected: newValue => root.writePath("background.widgets.uptime.style", newValue)
                    options: [
                        { displayName: Translation.tr("Row"), value: "row" },
                        { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.uptime.style", "row") === "instrument"
                    label: Translation.tr("Instrument details")
                    icon: "tune"
                    trailing: false
                    RowLayout {
                        spacing: 6
                        WidgetToggleChip {
                            configPath: "background.widgets.uptime.showSince"
                            defaultValue: true
                            buttonIcon: "schedule"
                            buttonText: Translation.tr("Since")
                        }
                        WidgetToggleChip {
                            configPath: "background.widgets.uptime.showBreakdown"
                            defaultValue: true
                            buttonIcon: "view_agenda"
                            buttonText: Translation.tr("Breakdown")
                        }
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.uptime"
                configEntry: root.readPath("background.widgets.uptime", ({}))
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.uptime"
                defaults: ({
                    style: "row",
                    showSince: true,
                    showBreakdown: true,
                    placementStrategy: "free", contentWidth: 250, contentHeight: 96,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 80
                })
            }
        }
            }
        }
    }

    // ── Media Controls ──────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "media"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "media"
                expanded: true
        icon: "album"
        title: Translation.tr("Media Controls")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.mediaControls"
                configEntry: root.readPath("background.widgets.mediaControls", ({}))
                defaultStrategy: "free"
                defaultEnabled: false
            }

            ContentSubsection {
                title: Translation.tr("Player")

                WidgetSettingRow {
                    label: Translation.tr("Player style")
                    trailing: false

                    ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.mediaControls.playerPreset", "full")
                    onSelected: newValue => root.writePath("background.widgets.mediaControls.playerPreset", newValue)
                    options: [
                        { displayName: Translation.tr("Full"), icon: "featured_video", value: "full" },
                        { displayName: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                        { displayName: Translation.tr("Minimal"), icon: "view_headline", value: "minimal" },
                        { displayName: Translation.tr("Album Art"), icon: "image", value: "albumart" },
                        { displayName: Translation.tr("Visualizer"), icon: "equalizer", value: "visualizer" },
                        { displayName: Translation.tr("Classic"), icon: "radio", value: "classic" },
                        { displayName: Translation.tr("Lyrics"), icon: "lyrics", value: "lyrics" },
                        { displayName: Translation.tr("Lyrics wide"), icon: "subtitles", value: "lyricsSplit" },
                        { displayName: Translation.tr("Cover"), icon: "art_track", value: "expandingLyrics" },
                    ]
                }
            }
            }

            ContentSubsection {
                title: Translation.tr("Visualizer")

                SettingsNote {
                    icon: "tune"
                    text: Translation.tr("Advanced → Cava controls the shared audio capture, stereo mode and global Cava palette. These options only shape how this Media Player draws that signal.")
                }

                WidgetSettingRow {
                    label: Translation.tr("Type")
                    icon: "graphic_eq"
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.mediaControls.visualizerType", "wave")
                        onSelected: newValue => {
                            root.writePath("background.widgets.mediaControls.visualizerType", newValue)
                            if (newValue === "organic"
                                    && root.readPath("background.widgets.mediaControls.visualizerPosition", "bottom") === "none")
                                root.writePath("background.widgets.mediaControls.visualizerPosition", "fill")
                        }
                        options: [
                            { displayName: Translation.tr("Wave"), icon: "waves", value: "wave" },
                            { displayName: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                            { displayName: Translation.tr("Organic"), icon: "bubble_chart", value: "organic" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Placement")
                    icon: "swap_vert"
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath(
                            "background.widgets.mediaControls.visualizerPosition", "bottom")
                        onSelected: newValue => root.writePath(
                            "background.widgets.mediaControls.visualizerPosition", newValue)
                        options: root.readPath("background.widgets.mediaControls.visualizerType", "wave") === "organic" ? [
                            { displayName: Translation.tr("On"), icon: "visibility", value: "fill" },
                            { displayName: Translation.tr("Off"), icon: "visibility_off", value: "none" },
                        ] : [
                            { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                            { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                            { displayName: Translation.tr("Fill"), icon: "fullscreen", value: "fill" },
                            { displayName: Translation.tr("Off"), icon: "visibility_off", value: "none" },
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Colors")
                    icon: "palette"
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath(
                            "background.widgets.mediaControls.visualizerPaletteMode", "cava")
                        onSelected: newValue => root.writePath(
                            "background.widgets.mediaControls.visualizerPaletteMode", newValue)
                        options: [
                            { displayName: Translation.tr("Cava palette"), icon: "palette", value: "cava" },
                            { displayName: Translation.tr("Accent"), icon: "colors", value: "accent" },
                            { displayName: Translation.tr("Album"), icon: "album", value: "player" },
                        ]
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    WidgetSettingRow {
                        label: Translation.tr("Smoothing")
                        StyledSpinBox {
                            from: 0; to: 8; stepSize: 1
                            value: root.readPath("background.widgets.mediaControls.visualizerSmoothing", 2)
                            onValueModified: root.writePath("background.widgets.mediaControls.visualizerSmoothing", value)
                        }
                    }
                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.mediaControls.visualizerType", "wave") !== "organic"
                        label: Translation.tr("Opacity")
                        StyledSpinBox {
                            from: 5; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.visualizerOpacity", 55)
                            onValueModified: root.writePath("background.widgets.mediaControls.visualizerOpacity", value)
                        }
                    }
                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.mediaControls.visualizerType", "wave") !== "organic"
                        label: Translation.tr("Motion range")
                        StyledSpinBox {
                            from: 10; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.visualizerRange", 88)
                            onValueModified: root.writePath("background.widgets.mediaControls.visualizerRange", value)
                        }
                    }
                    WidgetSettingRow {
                        visible: root.readPath("background.widgets.mediaControls.visualizerType", "wave") === "bars"
                        label: Translation.tr("Bar count")
                        StyledSpinBox {
                            from: 8; to: 128; stepSize: 4
                            value: root.readPath("background.widgets.mediaControls.visualizerBarCount", 32)
                            onValueModified: root.writePath("background.widgets.mediaControls.visualizerBarCount", value)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Response")

                ConfigSelectionArray {
                    currentValue: root.readPath(
                        "background.widgets.mediaControls.visualizerFrequencyProfile", "flat")
                    onSelected: newValue => root.writePath(
                        "background.widgets.mediaControls.visualizerFrequencyProfile", newValue)
                    options: [
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                        { displayName: Translation.tr("Bass"), icon: "graphic_eq", value: "bass" },
                        { displayName: Translation.tr("Warm"), icon: "local_fire_department", value: "warm" },
                        { displayName: Translation.tr("Vocal"), icon: "record_voice_over", value: "vocal" },
                        { displayName: Translation.tr("Treble"), icon: "trending_up", value: "treble" },
                        { displayName: Translation.tr("Smile"), icon: "waves", value: "smile" },
                    ]
                }

                WidgetSettingRow {
                    label: Translation.tr("Accent strength")
                    enabled: root.readPath(
                        "background.widgets.mediaControls.visualizerFrequencyProfile", "flat") !== "flat"
                    opacity: enabled ? 1 : 0.45
                    StyledSpinBox {
                        from: 0; to: 100; stepSize: 5
                        value: root.readPath(
                            "background.widgets.mediaControls.visualizerAccentStrength", 70)
                        onValueModified: root.writePath(
                            "background.widgets.mediaControls.visualizerAccentStrength", value)
                    }
                }
            }

            ContentSubsection {
                visible: root.readPath("background.widgets.mediaControls.visualizerType", "wave") === "organic"
                title: Translation.tr("Organic motion")

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 12
                    rowSpacing: 8

                    WidgetSettingRow {
                        label: Translation.tr("Sensitivity")
                        StyledSpinBox {
                            from: 25; to: 200; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicSensitivity", 35)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicSensitivity", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Pulse")
                        StyledSpinBox {
                            from: 0; to: 150; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicPulse", 150)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicPulse", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Compression")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicCompression", 0)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicCompression", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Motion speed")
                        StyledSpinBox {
                            from: 20; to: 250; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicMotionSpeed", 250)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicMotionSpeed", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Glow")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicGlow", 100)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicGlow", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Reach")
                        StyledSpinBox {
                            from: 20; to: 140; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicReach", 35)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicReach", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Idle motion")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicIdleMotion", 40)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicIdleMotion", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Presence")
                        StyledSpinBox {
                            from: 10; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicOpacity", 100)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicOpacity", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Range")
                        StyledSpinBox {
                            from: 20; to: 100; stepSize: 5
                            value: root.readPath("background.widgets.mediaControls.organicRange", 20)
                            onValueModified: root.writePath("background.widgets.mediaControls.organicRange", value)
                        }
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.mediaControls"
                configEntry: root.readPath("background.widgets.mediaControls", ({}))
                hasCardControls: false
            }

        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.mediaControls"
                defaults: ({
                    "placementStrategy": "free",
                    "playerPreset": "full",
                    "visualizerType": "wave",
                    "visualizerPosition": "bottom",
                    "visualizerPaletteMode": "cava",
                    "visualizerOpacity": 55,
                    "visualizerSmoothing": 2,
                    "visualizerFrequencyProfile": "flat",
                    "visualizerAccentStrength": 70,
                    "visualizerRange": 88,
                    "visualizerBarCount": 32,
                    "organicSensitivity": 35,
                    "organicPulse": 150,
                    "organicCompression": 0,
                    "organicMotionSpeed": 250,
                    "organicIdleMotion": 40,
                    "organicGlow": 100,
                    "organicOpacity": 100,
                    "organicReach": 35,
                    "organicRange": 20,
                    "lyricsExpanded": false,
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "colorMode": "auto",
                    "dim": 0,
                    "x": 240,
                    "y": 240,
                    "locked": false
})
            }
        }
            }
        }
    }

    // ── Visualizer ──────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "media"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "media"
                expanded: false
        icon: "equalizer"
        title: Translation.tr("Visualizer")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.visualizer"
                configEntry: root.readPath("background.widgets.visualizer", ({}))
                defaultStrategy: "free"
                enableTooltip: Translation.tr("Audio visualizer widget on the desktop")
            }

            ContentSubsection {
                title: Translation.tr("Style")

                WidgetSettingRow {
                    label: Translation.tr("Preset")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.visualizer.preset", "default")
                    onSelected: newValue => {
                        root.writePath("background.widgets.visualizer.preset", newValue);
                        if (newValue === "default") {
                            root.writePath("background.widgets.visualizer.barRadius", 2);
                            root.writePath("background.widgets.visualizer.barMinHeight", 1);
                            root.writePath("background.widgets.visualizer.contentWidth", 304);
                            root.writePath("background.widgets.visualizer.contentHeight", 104);
                            root.writePath("background.widgets.visualizer.barCount", 48);
                            root.writePath("background.widgets.visualizer.barSpacing", 2);
                        } else if (newValue === "dense") {
                            root.writePath("background.widgets.visualizer.barRadius", 1);
                            root.writePath("background.widgets.visualizer.barMinHeight", 2);
                            root.writePath("background.widgets.visualizer.contentWidth", 304);
                            root.writePath("background.widgets.visualizer.contentHeight", 80);
                            root.writePath("background.widgets.visualizer.barCount", 64);
                            root.writePath("background.widgets.visualizer.barSpacing", 1);
                        } else if (newValue === "minimal") {
                            root.writePath("background.widgets.visualizer.barRadius", 4);
                            root.writePath("background.widgets.visualizer.barMinHeight", 1);
                            root.writePath("background.widgets.visualizer.contentWidth", 200);
                            root.writePath("background.widgets.visualizer.contentHeight", 80);
                            root.writePath("background.widgets.visualizer.barCount", 24);
                            root.writePath("background.widgets.visualizer.barSpacing", 3);
                        } else if (newValue === "wide") {
                            root.writePath("background.widgets.visualizer.barRadius", 2);
                            root.writePath("background.widgets.visualizer.barMinHeight", 1);
                            root.writePath("background.widgets.visualizer.contentWidth", 480);
                            root.writePath("background.widgets.visualizer.contentHeight", 120);
                            root.writePath("background.widgets.visualizer.barCount", 80);
                            root.writePath("background.widgets.visualizer.barSpacing", 2);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "equalizer", value: "default" },
                        { displayName: Translation.tr("Dense"), icon: "density_small", value: "dense" },
                        { displayName: Translation.tr("Minimal"), icon: "view_headline", value: "minimal" },
                        { displayName: Translation.tr("Wide"), icon: "width_wide", value: "wide" },
                    ]
                }

                ConfigSelectionArray {
                    currentValue: root.readPath(
                        "background.widgets.visualizer.vizType", "bars")
                    onSelected: newValue => root.writePath(
                        "background.widgets.visualizer.vizType", newValue)
                    options: [
                        { displayName: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                        { displayName: Translation.tr("Wave"), icon: "waves", value: "wave" },
                        { displayName: Translation.tr("Organic"), icon: "bubble_chart", value: "organic" },
                    ]
                }

                ConfigSelectionArray {
                    currentValue: root.readPath(
                        "background.widgets.visualizer.paletteMode", "cava")
                    onSelected: newValue => root.writePath(
                        "background.widgets.visualizer.paletteMode", newValue)
                    options: [
                        { displayName: Translation.tr("Cava"), icon: "palette", value: "cava" },
                        { displayName: Translation.tr("Accent"), icon: "colors", value: "accent" },
                        { displayName: Translation.tr("Primary"), icon: "format_color_fill", value: "primary" },
                        { displayName: Translation.tr("Album"), icon: "album", value: "album" },
                    ]
                }

                ConfigSelectionArray {
                    visible: root.readPath(
                        "background.widgets.visualizer.vizType", "bars") === "bars"
                    currentValue: root.readPath(
                        "background.widgets.visualizer.barsOrigin", "bottom")
                    onSelected: newValue => root.writePath(
                        "background.widgets.visualizer.barsOrigin", newValue)
                    options: [
                        { displayName: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                        { displayName: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                        { displayName: Translation.tr("Center rise"), icon: "center_focus_strong", value: "center" },
                        { displayName: Translation.tr("Mirrored"), icon: "unfold_more", value: "mirror" },
                    ]
                }

                ConfigSelectionArray {
                    visible: root.readPath(
                        "background.widgets.visualizer.vizType", "bars") === "wave"
                    currentValue: root.readPath(
                        "background.widgets.visualizer.waveMode", "fill")
                    onSelected: newValue => root.writePath(
                        "background.widgets.visualizer.waveMode", newValue)
                    options: [
                        { displayName: Translation.tr("Fill"), icon: "waves", value: "fill" },
                        { displayName: Translation.tr("Line"), icon: "line_weight", value: "line" },
                        { displayName: Translation.tr("Ribbon"), icon: "unfold_more", value: "ribbon" },
                    ]
                }
            }
            }

            ContentSubsection {
                visible: root.readPath(
                    "background.widgets.visualizer.vizType", "bars") === "bars"
                title: Translation.tr("Bars")

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        label: Translation.tr("Bar count")
                        StyledSpinBox {
                            from: 8; to: 128; stepSize: 4
                            value: root.readPath("background.widgets.visualizer.barCount", 48)
                            onValueModified: root.writePath("background.widgets.visualizer.barCount", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Bar spacing")
                        StyledSpinBox {
                            from: 0; to: 8; stepSize: 1
                            value: root.readPath("background.widgets.visualizer.barSpacing", 2)
                            onValueModified: root.writePath("background.widgets.visualizer.barSpacing", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Bar radius")
                        StyledSpinBox {
                            from: 0; to: 16; stepSize: 1
                            value: root.readPath("background.widgets.visualizer.barRadius", 2)
                            onValueModified: root.writePath("background.widgets.visualizer.barRadius", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Min height")
                        StyledSpinBox {
                            from: 0; to: 16; stepSize: 1
                            value: root.readPath("background.widgets.visualizer.barMinHeight", 1)
                            onValueModified: root.writePath("background.widgets.visualizer.barMinHeight", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Opacity")
                        StyledSpinBox {
                            from: 5; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.barOpacity", 100)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.barOpacity", value)
                        }
                    }
                }
            }

            ContentSubsection {
                visible: root.readPath(
                    "background.widgets.visualizer.vizType", "bars") === "wave"
                title: Translation.tr("Wave")

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        label: Translation.tr("Opacity")
                        StyledSpinBox {
                            from: 5; to: 100; stepSize: 5
                            value: {
                                const value = root.readPath(
                                    "background.widgets.visualizer.waveOpacity", -1)
                                return value >= 0 ? value
                                    : (Config.options?.appearance?.cava?.waveOpacity ?? 30)
                            }
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.waveOpacity", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Line width")
                        StyledSpinBox {
                            from: 1; to: 8; stepSize: 1
                            value: root.readPath(
                                "background.widgets.visualizer.lineWidth", 2)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.lineWidth", value)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Response")

                SettingsNote {
                    icon: "equalizer"
                    text: Translation.tr("Advanced → Cava controls the shared audio capture and global palette source. These controls shape only this desktop visualizer.")
                }

                ConfigSelectionArray {
                    currentValue: root.readPath(
                        "background.widgets.visualizer.frequencyProfile", "flat")
                    onSelected: newValue => root.writePath(
                        "background.widgets.visualizer.frequencyProfile", newValue)
                    options: [
                        { displayName: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                        { displayName: Translation.tr("Bass"), icon: "graphic_eq", value: "bass" },
                        { displayName: Translation.tr("Warm"), icon: "local_fire_department", value: "warm" },
                        { displayName: Translation.tr("Vocal"), icon: "record_voice_over", value: "vocal" },
                        { displayName: Translation.tr("Treble"), icon: "trending_up", value: "treble" },
                        { displayName: Translation.tr("Smile"), icon: "waves", value: "smile" },
                    ]
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        label: Translation.tr("Smoothing")
                        StyledSpinBox {
                            from: 0; to: 8; stepSize: 1
                            value: root.readPath(
                                "background.widgets.visualizer.smoothing", 2)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.smoothing", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Sensitivity")
                        StyledSpinBox {
                            from: 25; to: 200; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicSensitivity", 25)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicSensitivity", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Pulse (%)")
                        StyledSpinBox {
                            from: 0; to: 150; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicPulse", 150)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicPulse", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Compression (%)")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicCompression", 0)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicCompression", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Motion speed (%)")
                        StyledSpinBox {
                            from: 20; to: 250; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicMotionSpeed", 250)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicMotionSpeed", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Idle motion (%)")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicIdleMotion", 18)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicIdleMotion", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Halo opacity (%)")
                        StyledSpinBox {
                            from: 10; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicOpacity", 100)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicOpacity", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Glow (%)")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicGlow", 100)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicGlow", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Cover size (%)")
                        StyledSpinBox {
                            from: 30; to: 90; stepSize: 1
                            value: root.readPath(
                                "background.widgets.visualizer.organicCoverSize", 51)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicCoverSize", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") !== "organic"
                        label: Translation.tr("Spectrum height (%)")
                        StyledSpinBox {
                            from: 10; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.fillRatio", 90)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.fillRatio", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") === "organic"
                        label: Translation.tr("Motion range (%)")
                        StyledSpinBox {
                            from: 20; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.organicRange", 20)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.organicRange", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") !== "organic"
                        label: Translation.tr("Edge inset (px)")
                        StyledSpinBox {
                            from: 0; to: 32; stepSize: 1
                            value: root.readPath(
                                "background.widgets.visualizer.edgeInset", 0)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.edgeInset", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: root.readPath(
                            "background.widgets.visualizer.vizType", "bars") !== "organic"
                        label: Translation.tr("Curve headroom (%)")
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.edgeSoftness", 28)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.edgeSoftness", value)
                        }
                    }

                    WidgetSettingRow {
                        label: Translation.tr("Frequency accent strength (%)")
                        enabled: root.readPath(
                            "background.widgets.visualizer.frequencyProfile", "flat") !== "flat"
                        opacity: enabled ? 1 : 0.45
                        StyledSpinBox {
                            from: 0; to: 100; stepSize: 5
                            value: root.readPath(
                                "background.widgets.visualizer.accentStrength", 70)
                            onValueModified: root.writePath(
                                "background.widgets.visualizer.accentStrength", value)
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("visualizer")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    StyledSpinBox {
                        from: 100; to: 800; stepSize: 20
                        value: root.readPath("background.widgets.visualizer.contentWidth", 304)
                        onValueModified: root.writePath("background.widgets.visualizer.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    StyledSpinBox {
                        from: 40; to: 400; stepSize: 10
                        value: root.readPath("background.widgets.visualizer.contentHeight", 104)
                        onValueModified: root.writePath("background.widgets.visualizer.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.visualizer"
                configEntry: root.readPath("background.widgets.visualizer", ({}))
                hasSemanticPalette: {
                    const mode = root.readPath(
                        "background.widgets.visualizer.paletteMode", "cava")
                    return mode === "accent" || mode === "primary"
                }
                hasCardControls: true
            }

        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.visualizer"
                defaults: ({
                    "placementStrategy": "free",
                    "preset": "default",
                    "vizType": "bars",
                    "paletteMode": "cava",
                    "barsOrigin": "bottom",
                    "waveMode": "fill",
                    "frequencyProfile": "flat",
                    "smoothing": 2,
                    "organicSensitivity": 25,
                    "organicPulse": 150,
                    "organicCompression": 0,
                    "organicMotionSpeed": 250,
                    "organicIdleMotion": 18,
                    "organicOpacity": 100,
                    "organicGlow": 100,
                    "organicCoverSize": 51,
                    "organicRange": 20,
                    "fillRatio": 90,
                    "barOpacity": 100,
                    "waveOpacity": -1,
                    "barCount": 48,
                    "barSpacing": 2,
                    "lineWidth": 2,
                    "edgeInset": 0,
                    "edgeSoftness": 28,
                    "accentStrength": 70,
                    "dim": 0,
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "showBackground": true,
                    "useBlur": false,
                    "showBorder": true,
                    "backgroundOpacity": 0.16,
                    "borderWidth": 1,
                    "borderOpacity": 0.2,
                    "cornerRadius": -1,
                    "colorMode": "auto",
                    "x": 100,
                    "y": 100,
                    "barRadius": 2,
                    "barMinHeight": 1,
                    "contentWidth": 304,
                    "contentHeight": 104,
                    "locked": false
})
            }
        }
            }
        }
    }

    // ── System Monitor ──────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "system"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "system"
                expanded: true
        icon: "monitor_heart"
        title: Translation.tr("System Monitor")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.systemMonitor"
                configEntry: root.readPath("background.widgets.systemMonitor", ({}))
                defaultStrategy: "free"
                enableTooltip: Translation.tr("Show CPU, RAM, and GPU usage on the desktop")
            }

            ContentSubsection {
                title: Translation.tr("Layout")

                WidgetSettingRow {
                    label: Translation.tr("Preset")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.systemMonitor.preset", "default")
                    onSelected: newValue => {
                        root.writePath("background.widgets.systemMonitor.preset", newValue);
                        if (newValue === "default") {
                            root.writePath("background.widgets.systemMonitor.contentWidth", 320);
                            root.writePath("background.widgets.systemMonitor.contentHeight", 120);
                        } else if (newValue === "compact") {
                            root.writePath("background.widgets.systemMonitor.contentWidth", 240);
                            root.writePath("background.widgets.systemMonitor.contentHeight", 80);
                        } else if (newValue === "wide") {
                            root.writePath("background.widgets.systemMonitor.contentWidth", 480);
                            root.writePath("background.widgets.systemMonitor.contentHeight", 120);
                        } else if (newValue === "tall") {
                            root.writePath("background.widgets.systemMonitor.contentWidth", 320);
                            root.writePath("background.widgets.systemMonitor.contentHeight", 180);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "monitor_heart", value: "default" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                        { displayName: Translation.tr("Wide"), icon: "width_wide", value: "wide" },
                        { displayName: Translation.tr("Tall"), icon: "height", value: "tall" },
                    ]
                }
            }

            WidgetSettingRow {
                label: Translation.tr("Display mode")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.systemMonitor.displayMode", "bars")
                    onSelected: newValue => root.writePath("background.widgets.systemMonitor.displayMode", newValue)
                    options: [
                        { displayName: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { displayName: Translation.tr("Graph"), icon: "show_chart", value: "graph" },
                        { displayName: Translation.tr("Rings"), icon: "radio_button_checked", value: "rings" },
                        { displayName: Translation.tr("Text"), icon: "text_fields", value: "text" },
                        { displayName: Translation.tr("Tiles"), icon: "grid_view", value: "tiles" },
                        { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" },
                    ]
                }
            }
            }

            ContentSubsection {
                title: Translation.tr("Resources")

                WidgetSettingRow {
                    label: Translation.tr("Meters")
                    icon: "monitor_heart"
                    trailing: false
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showCpu"
                        defaultValue: true
                        buttonIcon: "memory"
                        buttonText: Translation.tr("CPU")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showMemory"
                        defaultValue: true
                        buttonIcon: "storage"
                        buttonText: Translation.tr("Memory")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showGpu"
                        defaultValue: true
                        buttonIcon: "developer_board"
                        buttonText: Translation.tr("GPU")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Thermals and disk")
                    icon: "thermostat"
                    trailing: false
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showTemp"
                        defaultValue: false
                        buttonIcon: "thermostat"
                        buttonText: Translation.tr("CPU temp")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showGpuTemp"
                        defaultValue: false
                        buttonIcon: "device_thermostat"
                        buttonText: Translation.tr("GPU temp")
                    }
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showDisk"
                        defaultValue: false
                        buttonIcon: "hard_drive"
                        buttonText: Translation.tr("Disk")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Labels")
                    icon: "label"
                    trailing: false
                    WidgetToggleChip {
                        configPath: "background.widgets.systemMonitor.showLabels"
                        defaultValue: true
                        buttonIcon: "label"
                        buttonText: Translation.tr("Labels and percentages")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("systemMonitor")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    StyledSpinBox {
                        from: 120; to: 800; stepSize: 20
                        value: root.readPath("background.widgets.systemMonitor.contentWidth", 320)
                        onValueModified: root.writePath("background.widgets.systemMonitor.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    StyledSpinBox {
                        from: 40; to: 400; stepSize: 10
                        value: root.readPath("background.widgets.systemMonitor.contentHeight", 120)
                        onValueModified: root.writePath("background.widgets.systemMonitor.contentHeight", value)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Style")

                WidgetSettingRow {
                    label: Translation.tr("Track opacity")
                    trailing: false
                    StyledSlider {
                        from: 0; to: 0.5; stepSize: 0.02
                        value: root.readPath("background.widgets.systemMonitor.trackAlpha", 0.08)
                        onMoved: root.writePath("background.widgets.systemMonitor.trackAlpha", Math.round(value * 100) / 100)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Fill opacity")
                    trailing: false
                    StyledSlider {
                        from: 0.1; to: 1; stepSize: 0.05
                        value: root.readPath("background.widgets.systemMonitor.fillOpacity", 0.7)
                        onMoved: root.writePath("background.widgets.systemMonitor.fillOpacity", Math.round(value * 100) / 100)
                    }
                }
                WidgetSettingRow {
                    visible: (root.readPath("background.widgets.systemMonitor.displayMode", "bars")) === "graph"
                    label: Translation.tr("Graph fill opacity")
                    trailing: false
                    StyledSlider {
                        from: 0; to: 1; stepSize: 0.05
                        value: root.readPath("background.widgets.systemMonitor.graphFillOpacity", 0.3)
                        onMoved: root.writePath("background.widgets.systemMonitor.graphFillOpacity", Math.round(value * 100) / 100)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.systemMonitor"
                configEntry: root.readPath("background.widgets.systemMonitor", ({}))
                hasCardControls: true
            }

        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.systemMonitor"
                defaults: ({
                    "placementStrategy": "free",
                    "displayMode": "bars",
                    "barCount": 32,
                    "barSpacing": 2,
                    "trackAlpha": 0.08,
                    "fillOpacity": 0.7,
                    "graphFillOpacity": 0.3,
                    "showCpu": true,
                    "showMemory": true,
                    "showGpu": true,
                    "showTemp": false,
                    "showGpuTemp": false,
                    "showDisk": false,
                    "showLabels": true,
                    "dim": 0,
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "showBackground": true,
                    "useBlur": false,
                    "showBorder": true,
                    "backgroundOpacity": 0.16,
                    "borderWidth": 1,
                    "borderOpacity": 0.2,
                    "cornerRadius": -1,
                    "colorMode": "auto",
                    "x": 50,
                    "y": 400,
                    "preset": "default",
                    "contentWidth": 320,
                    "contentHeight": 120,
                    "locked": false
})
            }
        }
            }
        }
    }

    // ── Battery ─────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "system"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "system"
                expanded: false
        icon: "battery_full"
        title: Translation.tr("Battery")

        SettingsGroup {
            StyledText {
                Layout.fillWidth: true
                visible: !Battery.available
                text: Translation.tr("No battery detected on this system.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            WidgetStateControls {
                configPath: "background.widgets.battery"
                configEntry: root.readPath("background.widgets.battery", ({}))
                defaultStrategy: "free"
                enableTooltip: Translation.tr("Show battery status on the desktop (only visible on laptops)")
            }

            ContentSubsection {
                title: Translation.tr("Style and display")

                WidgetSettingRow {
                    label: Translation.tr("Preset")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.battery.preset", "default")
                    onSelected: newValue => {
                        root.writePath("background.widgets.battery.preset", newValue);
                        if (newValue === "default") {
                            root.writePath("background.widgets.battery.ringLineWidth", 6);
                            root.writePath("background.widgets.battery.barCount", 20);
                            root.writePath("background.widgets.battery.pillHeight", 12);
                        } else if (newValue === "thin") {
                            root.writePath("background.widgets.battery.ringLineWidth", 3);
                            root.writePath("background.widgets.battery.barCount", 20);
                            root.writePath("background.widgets.battery.pillHeight", 8);
                        } else if (newValue === "thick") {
                            root.writePath("background.widgets.battery.ringLineWidth", 10);
                            root.writePath("background.widgets.battery.barCount", 12);
                            root.writePath("background.widgets.battery.pillHeight", 16);
                        } else if (newValue === "dense") {
                            root.writePath("background.widgets.battery.ringLineWidth", 6);
                            root.writePath("background.widgets.battery.barCount", 32);
                            root.writePath("background.widgets.battery.pillHeight", 12);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "battery_full", value: "default" },
                        { displayName: Translation.tr("Thin"), icon: "remove", value: "thin" },
                        { displayName: Translation.tr("Thick"), icon: "rectangle", value: "thick" },
                        { displayName: Translation.tr("Dense"), icon: "density_small", value: "dense" },
                    ]
                }
            }

            WidgetSettingRow {
                label: Translation.tr("Display")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.battery.displayMode", "ring")
                    onSelected: newValue => root.writePath("background.widgets.battery.displayMode", newValue)
                    options: [
                        { displayName: Translation.tr("Ring"), icon: "radio_button_checked", value: "ring" },
                        { displayName: Translation.tr("Bars"), icon: "bar_chart", value: "bars" },
                        { displayName: Translation.tr("Pill"), icon: "horizontal_rule", value: "pill" },
                        { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" },
                    ]
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "ring"
                        label: Translation.tr("Ring size")
                        StyledSpinBox {
                            from: 40; to: 120; stepSize: 4
                            value: root.readPath("background.widgets.battery.ringSize", 72)
                            onValueModified: root.writePath("background.widgets.battery.ringSize", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "ring"
                        label: Translation.tr("Line width")
                        StyledSpinBox {
                            from: 1; to: 16; stepSize: 1
                            value: root.readPath("background.widgets.battery.ringLineWidth", 6)
                            onValueModified: root.writePath("background.widgets.battery.ringLineWidth", value)
                        }
                    }
                }

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "bars"
                        label: Translation.tr("Bar count")
                        StyledSpinBox {
                            from: 4; to: 48; stepSize: 2
                            value: root.readPath("background.widgets.battery.barCount", 20)
                            onValueModified: root.writePath("background.widgets.battery.barCount", value)
                        }
                    }
                    WidgetSettingRow {
                        visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "bars"
                        label: Translation.tr("Bar spacing")
                        StyledSpinBox {
                            from: 0; to: 8; stepSize: 1
                            value: root.readPath("background.widgets.battery.barSpacing", 2)
                            onValueModified: root.writePath("background.widgets.battery.barSpacing", value)
                        }
                    }
                    WidgetSettingRow {
                        visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "bars"
                        label: Translation.tr("Bar radius")
                        StyledSpinBox {
                            from: 0; to: 12; stepSize: 1
                            value: root.readPath("background.widgets.battery.barRadius", 2)
                            onValueModified: root.writePath("background.widgets.battery.barRadius", value)
                        }
                    }
                }

                WidgetSettingRow {
                    visible: (root.readPath("background.widgets.battery.displayMode", "ring")) === "pill"
                    label: Translation.tr("Pill height")
                    StyledSpinBox {
                        from: 4; to: 32; stepSize: 2
                        value: root.readPath("background.widgets.battery.pillHeight", 12)
                        onValueModified: root.writePath("background.widgets.battery.pillHeight", value)
                    }
                }

                SettingsSwitch {
                    buttonIcon: "schedule"
                    text: Translation.tr("Show time estimate")
                    autoToggle: false

                    checked: root.readPath("background.widgets.battery.showTime", true)
                    onToggledByUser: checked => root.writePath("background.widgets.battery.showTime", checked)
                }
                SettingsSwitch {
                    visible: root.readPath("background.widgets.battery.displayMode", "ring") === "instrument"
                    buttonIcon: "electric_bolt"
                    text: Translation.tr("Show power draw")
                    autoToggle: false
                    checked: root.readPath("background.widgets.battery.showRate", true)
                    onToggledByUser: checked => root.writePath("background.widgets.battery.showRate", checked)
                }
            }

            }

            WidgetAppearanceControls {
                configPath: "background.widgets.battery"
                configEntry: root.readPath("background.widgets.battery", ({}))
                hasCardControls: true
            }

        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.battery"
                defaults: ({
                    "placementStrategy": "free",
                    "displayMode": "ring",
                    "showTime": true,
                    "showRate": true,
                    "ringSize": 72,
                    "dim": 0,
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "showBackground": true,
                    "useBlur": false,
                    "showBorder": true,
                    "backgroundOpacity": 0.16,
                    "borderWidth": 1,
                    "borderOpacity": 0.2,
                    "cornerRadius": -1,
                    "colorMode": "auto",
                    "x": 50,
                    "y": 50,
                    "preset": "default",
                    "ringLineWidth": 6,
                    "barCount": 20,
                    "barSpacing": 2,
                    "barRadius": 2,
                    "pillHeight": 12,
                    "locked": false
})
            }
        }
            }
        }
    }

    // ── Weather ─────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "system"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "system"
                expanded: true
        icon: "cloud"
        title: Translation.tr("Weather")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.weather"
                configEntry: root.readPath("background.widgets.weather", ({}))
                defaultStrategy: "free"
                defaultEnabled: false
            }

            ContentSubsection {
                title: Translation.tr("Style")

                WidgetSettingRow {
                    label: Translation.tr("Preset")
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.weather.preset", "default")
                    onSelected: newValue => {
                        root.writePath("background.widgets.weather.preset", newValue);
                        if (newValue === "default") {
                            root.writePath("background.widgets.weather.size", 200);
                            root.writePath("background.widgets.weather.tempSize", 80);
                            root.writePath("background.widgets.weather.iconSize", 80);
                            root.writePath("background.widgets.weather.showTemp", true);
                            root.writePath("background.widgets.weather.showIcon", true);
                            root.writePath("background.widgets.weather.showCondition", false);
                        } else if (newValue === "compact") {
                            root.writePath("background.widgets.weather.size", 140);
                            root.writePath("background.widgets.weather.tempSize", 50);
                            root.writePath("background.widgets.weather.iconSize", 50);
                            root.writePath("background.widgets.weather.showTemp", true);
                            root.writePath("background.widgets.weather.showIcon", true);
                            root.writePath("background.widgets.weather.showCondition", false);
                        } else if (newValue === "iconOnly") {
                            root.writePath("background.widgets.weather.size", 120);
                            root.writePath("background.widgets.weather.showTemp", false);
                            root.writePath("background.widgets.weather.showIcon", true);
                            root.writePath("background.widgets.weather.showCondition", false);
                        } else if (newValue === "textOnly") {
                            root.writePath("background.widgets.weather.size", 160);
                            root.writePath("background.widgets.weather.showTemp", true);
                            root.writePath("background.widgets.weather.showIcon", false);
                            root.writePath("background.widgets.weather.showCondition", true);
                        }
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "cloud", value: "default" },
                        { displayName: Translation.tr("Compact"), icon: "compress", value: "compact" },
                        { displayName: Translation.tr("Icon only"), icon: "image", value: "iconOnly" },
                        { displayName: Translation.tr("Text only"), icon: "text_fields", value: "textOnly" },
                    ]
                }
            }

            WidgetSettingRow {
                label: Translation.tr("Style")
                trailing: false

                ConfigSelectionArray {
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.weather.style", "pill")
                    onSelected: newValue => root.writePath("background.widgets.weather.style", newValue)
                    options: [
                        { displayName: Translation.tr("Shape"), icon: "category", value: "pill" },
                        { displayName: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                        { displayName: Translation.tr("Detail"), icon: "dashboard", value: "detail" },
                        { displayName: Translation.tr("Instrument"), icon: "wb_twilight", value: "dial" },
                    ]
                }

                ConfigSelectionArray {
                    visible: root.readPath("background.widgets.weather.style", "pill") === "pill"
                    Layout.fillWidth: true
                    currentValue: root.readPath("background.widgets.weather.shape", "pill")
                    onSelected: newValue => root.writePath("background.widgets.weather.shape", newValue)
                    options: [
                        { displayName: Translation.tr("Pill"), value: "pill" },
                        { displayName: Translation.tr("Circle"), value: "circle" },
                        { displayName: Translation.tr("Oval"), value: "oval" },
                        { displayName: Translation.tr("Diamond"), value: "diamond" },
                        { displayName: Translation.tr("Heart"), value: "heart" },
                        { displayName: Translation.tr("Flower"), value: "flower" },
                        { displayName: Translation.tr("Cookie"), value: "cookie4" },
                        { displayName: Translation.tr("Sunny"), value: "sunny" },
                        { displayName: Translation.tr("Clover"), value: "clover" },
                        { displayName: Translation.tr("Burst"), value: "softBurst" },
                        { displayName: Translation.tr("Gem"), value: "gem" },
                        { displayName: Translation.tr("Puffy"), value: "puffy" },
                    ]
                }
            }
            }

            ContentSubsection {
                title: Translation.tr("Content")

                ConfigRow {
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "thermostat"
                        text: Translation.tr("Temperature")
                        autoToggle: false

                        checked: root.readPath("background.widgets.weather.showTemp", true)
                        onToggledByUser: checked => root.writePath("background.widgets.weather.showTemp", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "cloud"
                        text: Translation.tr("Icon")
                        autoToggle: false

                        checked: root.readPath("background.widgets.weather.showIcon", true)
                        onToggledByUser: checked => root.writePath("background.widgets.weather.showIcon", checked)
                    }
                }
                SettingsSwitch {
                    buttonIcon: "description"
                    text: Translation.tr("Condition text")
                    autoToggle: false
                    visible: root.readPath("background.widgets.weather.style", "pill") !== "detail"

                    checked: root.readPath("background.widgets.weather.showCondition", false)
                    onToggledByUser: checked => root.writePath("background.widgets.weather.showCondition", checked)
                }
                SettingsSwitch {
                    buttonIcon: "monitoring"
                    text: Translation.tr("Metric chips")
                    autoToggle: false
                    visible: root.readPath("background.widgets.weather.style", "pill") === "detail"

                    checked: root.readPath("background.widgets.weather.showMetrics", true)
                    onToggledByUser: checked => root.writePath("background.widgets.weather.showMetrics", checked)
                }

                ConfigRow {
                    visible: root.readPath("background.widgets.weather.style", "pill") === "dial"
                    Layout.fillWidth: true
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "wb_twilight"
                        text: Translation.tr("Sun path")
                        autoToggle: false
                        checked: root.readPath("background.widgets.weather.showSunPath", true)
                        onToggledByUser: checked => root.writePath("background.widgets.weather.showSunPath", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "schedule"
                        text: Translation.tr("Sun times")
                        autoToggle: false
                        enabled: root.readPath("background.widgets.weather.showSunPath", true)
                        checked: root.readPath("background.widgets.weather.showSunTimes", true)
                        onToggledByUser: checked => root.writePath("background.widgets.weather.showSunTimes", checked)
                    }
                    SettingsSwitch {
                        Layout.fillWidth: false
                        buttonIcon: "location_on"
                        text: Translation.tr("Location")
                        autoToggle: false
                        checked: root.readPath("background.widgets.weather.showLocation", true)
                        onToggledByUser: checked => root.writePath("background.widgets.weather.showLocation", checked)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Sizing")
                // medium and large are the forecast face: the pill's sizes mean nothing there
                visible: !DesktopWidgetOptions.weatherForecast()

                GridLayout {
                    columns: 2
                    columnSpacing: 12
                    Layout.fillWidth: true

                    WidgetSettingRow {
                        label: Translation.tr("Widget size")
                        StyledSpinBox {
                            from: 80; to: 400; stepSize: 10
                            value: root.readPath("background.widgets.weather.size", 200)
                            onValueModified: root.writePath("background.widgets.weather.size", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Temp size")
                        StyledSpinBox {
                            from: 20; to: 200; stepSize: 5
                            value: root.readPath("background.widgets.weather.tempSize", 80)
                            onValueModified: root.writePath("background.widgets.weather.tempSize", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Icon size")
                        StyledSpinBox {
                            from: 20; to: 200; stepSize: 5
                            value: root.readPath("background.widgets.weather.iconSize", 80)
                            onValueModified: root.writePath("background.widgets.weather.iconSize", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Padding")
                        StyledSpinBox {
                            from: 0; to: 60; stepSize: 2
                            value: root.readPath("background.widgets.weather.padding", 20)
                            onValueModified: root.writePath("background.widgets.weather.padding", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Temp font weight")
                        StyledSpinBox {
                            from: 100; to: 900; stepSize: 100
                            value: root.readPath("background.widgets.weather.tempFontWeight", 500)
                            onValueModified: root.writePath("background.widgets.weather.tempFontWeight", value)
                        }
                    }
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.weather.showCondition", false)
                    label: Translation.tr("Condition opacity")
                    trailing: false
                    StyledSlider {
                        from: 0; to: 1; stepSize: 0.05
                        value: root.readPath("background.widgets.weather.conditionOpacity", 0.7)
                        onMoved: root.writePath("background.widgets.weather.conditionOpacity", Math.round(value * 100) / 100)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.weather"
                configEntry: root.readPath("background.widgets.weather", ({}))
                hasColorMode: root.readPath(
                    "background.widgets.weather.style", "pill") !== "pill"
                hasCardControls: root.readPath(
                    "background.widgets.weather.style", "pill") !== "pill"
            }

        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.weather"
                defaults: ({
                    "placementStrategy": "free",
                    "widgetScale": 100,
                    "widgetOpacity": 100,
                    "showBackground": true,
                    "useBlur": false,
                    "showBorder": true,
                    "backgroundOpacity": 0.16,
                    "borderWidth": 1,
                    "borderOpacity": 0.2,
                    "cornerRadius": -1,
                    "colorMode": "auto",
                    "dim": 0,
                    "x": 100,
                    "y": 200,
                    "preset": "default",
                    "style": "pill",
                    "shape": "pill",
                    "size": 200,
                    "tempSize": 80,
                    "iconSize": 80,
                    "showTemp": true,
                    "showIcon": true,
                    "showCondition": false,
                    "showMetrics": true,
                    "showSunPath": true,
                    "showSunTimes": true,
                    "showLocation": true,
                    "padding": 20,
                    "tempFontWeight": 500,
                    "conditionOpacity": 0.7,
                    "locked": false
})
            }
        }
            }
        }
    }

    // ── News Ticker ─────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "system"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "system"
                expanded: false
        icon: "newspaper"
        title: Translation.tr("News Ticker")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.newsTicker"
                configEntry: root.readPath("background.widgets.newsTicker", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Content")
                WidgetSettingRow {
                    label: Translation.tr("Presentation")
                    icon: "view_quilt"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.newsTicker.style", "card")
                        onSelected: newValue => root.writePath("background.widgets.newsTicker.style", newValue)
                        options: [
                            { displayName: Translation.tr("Card"), value: "card" },
                            { displayName: Translation.tr("Instrument"), value: "instrument" }
                        ]
                    }
                }
                SettingsSwitch {
                    buttonIcon: "label"
                    text: Translation.tr("Metadata")
                    autoToggle: false
                    checked: root.readPath("background.widgets.newsTicker.showMeta", true)
                    onToggledByUser: checked => root.writePath("background.widgets.newsTicker.showMeta", checked)
                }
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("newsTicker")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                StyledSpinBox {
                    from: 200; to: 600; stepSize: 10
                    value: root.readPath("background.widgets.newsTicker.contentWidth", 320)
                    onValueModified: root.writePath("background.widgets.newsTicker.contentWidth", value)
                }
            }
            WidgetSettingRow {
                label: Translation.tr("Height")
                icon: "swap_vert"
                StyledSpinBox {
                    from: 60; to: 300; stepSize: 4
                    value: root.readPath("background.widgets.newsTicker.contentHeight", 92)
                    onValueModified: root.writePath("background.widgets.newsTicker.contentHeight", value)
                }
            }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.newsTicker"
                configEntry: root.readPath("background.widgets.newsTicker", ({}))
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.newsTicker"
                defaults: ({
                    placementStrategy: "free", contentWidth: 320, contentHeight: 92,
                    style: "card", showMeta: true,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 100, y: 260
                })
            }
        }
            }
        }
    }

    // ── Notes ───────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: false
        icon: "sticky_note_2"
        title: Translation.tr("Notes")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.notes"
                configEntry: root.readPath("background.widgets.notes", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Text")
                WidgetSettingRow {
                    label: Translation.tr("Presentation")
                    icon: "view_quilt"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.notes.style", "card")
                        onSelected: newValue => root.writePath("background.widgets.notes.style", newValue)
                        options: [
                            { displayName: Translation.tr("Card"), value: "card" },
                            { displayName: Translation.tr("Instrument"), value: "instrument" }
                        ]
                    }
                }
                SettingsSwitch {
                    visible: root.readPath("background.widgets.notes.style", "card") === "instrument"
                    buttonIcon: "horizontal_rule"
                    text: Translation.tr("Writing guides")
                    autoToggle: false
                    checked: root.readPath("background.widgets.notes.showRules", true)
                    onToggledByUser: checked => root.writePath("background.widgets.notes.showRules", checked)
                }
                WidgetSettingRow {
                    label: Translation.tr("Font size")
                    icon: "format_size"
                    StyledSpinBox {
                        from: 10; to: 48; stepSize: 1
                        value: root.readPath("background.widgets.notes.fontSize", 14)
                        onValueModified: root.writePath("background.widgets.notes.fontSize", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Font")
                    icon: "font_download"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.notes.fontFamily", "sans")
                        onSelected: newValue => root.writePath("background.widgets.notes.fontFamily", newValue)
                        options: [
                            { displayName: Translation.tr("Sans"), value: "sans" },
                            { displayName: Translation.tr("Mono"), value: "mono" }
                        ]
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Alignment")
                    icon: "format_align_left"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.notes.textAlign", "left")
                        onSelected: newValue => root.writePath("background.widgets.notes.textAlign", newValue)
                        options: [
                            { displayName: Translation.tr("Left"), icon: "format_align_left", value: "left" },
                            { displayName: Translation.tr("Center"), icon: "format_align_center", value: "center" },
                            { displayName: Translation.tr("Right"), icon: "format_align_right", value: "right" }
                        ]
                    }
                }
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("notes")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 160; to: 720; stepSize: 10
                        value: root.readPath("background.widgets.notes.contentWidth", 240)
                        onValueModified: root.writePath("background.widgets.notes.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 100; to: 720; stepSize: 10
                        value: root.readPath("background.widgets.notes.contentHeight", 160)
                        onValueModified: root.writePath("background.widgets.notes.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.notes"
                configEntry: root.readPath("background.widgets.notes", ({}))
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.notes"
                defaults: ({
                    placementStrategy: "free", text: "", fontSize: 14, fontFamily: "sans",
                    textAlign: "left", style: "card", showRules: true,
                    contentWidth: 240, contentHeight: 160, dim: 0,
                    widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.10,
                    borderWidth: 1, borderOpacity: 0.12, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 80
                })
            }
        }
            }
        }
    }

    // ── Todo ────────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: true
                icon: "checklist"
                title: Translation.tr("Todo")

                SettingsGroup {
                    WidgetStateControls {
                        configPath: "background.widgets.todo"
                        configEntry: root.readPath("background.widgets.todo", ({}))
                        defaultStrategy: "free"
                    }
                    ContentSubsection {
                        title: Translation.tr("Style")
                        WidgetSettingRow {
                            label: Translation.tr("Presentation")
                            trailing: false
                            ConfigSelectionArray {
                                Layout.fillWidth: true
                                currentValue: root.readPath("background.widgets.todo.style", "card")
                                onSelected: newValue => root.writePath("background.widgets.todo.style", newValue)
                                options: [
                                    { displayName: Translation.tr("Card"), icon: "crop_landscape", value: "card" },
                                    { displayName: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                                ]
                            }
                        }
                        SettingsSwitch {
                            visible: root.readPath("background.widgets.todo.style", "card") === "instrument"
                            buttonIcon: "horizontal_rule"
                            text: Translation.tr("Row rules")
                            autoToggle: false
                            checked: root.readPath("background.widgets.todo.instrumentRules", true)
                            onToggledByUser: checked => root.writePath("background.widgets.todo.instrumentRules", checked)
                        }
                        SettingsSwitch {
                            buttonIcon: "done_all"
                            text: Translation.tr("Show completed tasks")
                            autoToggle: false
                            checked: root.readPath("background.widgets.todo.showCompleted", true)
                            onToggledByUser: checked => root.writePath("background.widgets.todo.showCompleted", checked)
                        }
                    }
                    ContentSubsection {
                        title: Translation.tr("Dimensions")
                        // a sized card takes its width and height from its size
                        visible: !root.sizedWidget("todo")
                        WidgetSettingRow {
                            label: Translation.tr("Width")
                            icon: "swap_horiz"
                            StyledSpinBox {
                                from: 240; to: 560; stepSize: 4
                                value: root.readPath("background.widgets.todo.contentWidth", 300)
                                onValueModified: root.writePath("background.widgets.todo.contentWidth", value)
                            }
                        }
                        WidgetSettingRow {
                            label: Translation.tr("Height")
                            icon: "swap_vert"
                            StyledSpinBox {
                                from: 220; to: 720; stepSize: 4
                                value: root.readPath("background.widgets.todo.contentHeight", 276)
                                onValueModified: root.writePath("background.widgets.todo.contentHeight", value)
                            }
                        }
                    }
                    WidgetAppearanceControls {
                        configPath: "background.widgets.todo"
                        configEntry: root.readPath("background.widgets.todo", ({}))
                        hasCardControls: true
                    }
                }

                SettingsGroup {
                    WidgetResetButton {
                        configPath: "background.widgets.todo"
                        defaults: ({
                            placementStrategy: "free", contentWidth: 300, contentHeight: 276,
                            style: "card", instrumentRules: true, showCompleted: true,
                            widgetScale: 100, widgetOpacity: 100, showBackground: true,
                            useBlur: false, showBorder: true, backgroundOpacity: 0.14,
                            borderWidth: 1, borderOpacity: 0.16, cornerRadius: -1,
                            colorMode: "auto", dim: 0, locked: false, x: 120, y: 180
                        })
                    }
                }
            }
        }
    }

    // ── User card ───────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: false
        icon: "account_circle"
        title: Translation.tr("User card")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.userCard"
                configEntry: root.readPath("background.widgets.userCard", ({}))
                defaultStrategy: "free"
            }

            ContentSubsection {
                title: Translation.tr("Content")
                WidgetSettingRow {
                    label: Translation.tr("Presentation")
                    icon: "view_quilt"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.userCard.style", "card")
                        onSelected: newValue => root.writePath("background.widgets.userCard.style", newValue)
                        options: [
                            { displayName: Translation.tr("Card"), value: "card" },
                            { displayName: Translation.tr("Instrument"), value: "instrument" }
                        ]
                    }
                }
                ConfigRow {
                    SettingsSwitch {
                        buttonIcon: "person"
                        text: Translation.tr("Avatar")
                        autoToggle: false
                        checked: root.readPath("background.widgets.userCard.showAvatar", true)
                        onToggledByUser: checked => root.writePath("background.widgets.userCard.showAvatar", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "cloud"
                        text: Translation.tr("Weather")
                        autoToggle: false
                        checked: root.readPath("background.widgets.userCard.showWeather", true)
                        onToggledByUser: checked => root.writePath("background.widgets.userCard.showWeather", checked)
                    }
                    SettingsSwitch {
                        buttonIcon: "computer"
                        text: Translation.tr("Hostname")
                        autoToggle: false
                        checked: root.readPath("background.widgets.userCard.showHostname", true)
                        onToggledByUser: checked => root.writePath("background.widgets.userCard.showHostname", checked)
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("userCard")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 240; to: 600; stepSize: 10
                        value: root.readPath("background.widgets.userCard.contentWidth", 280)
                        onValueModified: root.writePath("background.widgets.userCard.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 190; to: 320; stepSize: 2
                        value: root.readPath("background.widgets.userCard.contentHeight", 176)
                        onValueModified: root.writePath("background.widgets.userCard.contentHeight", value)
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.userCard"
                configEntry: root.readPath("background.widgets.userCard", ({}))
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.userCard"
                defaults: ({
                    placementStrategy: "free", contentWidth: 280, contentHeight: 176,
                    style: "card", showAvatar: true, showWeather: true, showHostname: true,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: true,
                    useBlur: false, showBorder: true, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 420
                })
            }
        }
            }
        }
    }

    // ── Custom image ────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: false
        icon: "add_photo_alternate"
        title: Translation.tr("Custom image")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.customImage"
                configEntry: root.readPath("background.widgets.customImage", ({}))
                defaultStrategy: "free"
                defaultEnabled: false
            }

            ContentSubsection {
                title: Translation.tr("Source")

                WidgetSettingRow {
                    label: Translation.tr("Show")
                    icon: "filter_alt"
                    trailing: false

                    GridLayout {
                        id: customMediaQuickChoices
                        Layout.fillWidth: true
                        readonly property var choices: [
                            { label: Translation.tr("File"), icon: "draft", value: "file",
                                available: Images.isValidMediaByName(root.readPath("background.widgets.customImage.path", "")) },
                            { label: Translation.tr("All") + " " + root._customMediaFolderCount,
                                icon: "perm_media", value: "all", available: root._customMediaFolderCount > 0 },
                            { label: Translation.tr("Images") + " " + root._customMediaFolderImageCount,
                                icon: "image", value: "images", available: root._customMediaFolderImageCount > 0 },
                            { label: "GIF " + root._customMediaFolderGifCount,
                                icon: "motion_photos_on", value: "gifs", available: root._customMediaFolderGifCount > 0 },
                            { label: Translation.tr("Videos") + " " + root._customMediaFolderVideoCount,
                                icon: "movie", value: "videos", available: root._customMediaFolderVideoCount > 0 }
                        ].filter(choice => choice.available)
                        columns: Math.max(1, choices.length)
                        columnSpacing: 4
                        rowSpacing: 4

                        Repeater {
                            model: customMediaQuickChoices.choices

                            SelectionGroupButton {
                                required property var modelData
                                Layout.fillWidth: true
                                leftmost: true; rightmost: true
                                toggled: root._customMediaChoiceActive(modelData.value)
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                onClicked: root._activateCustomMediaChoice(modelData.value)
                            }
                        }
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Source type")
                    icon: "perm_media"
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.customImage.sourceMode", "file")
                        onSelected: newValue => {
                            const path = root.readPath("background.widgets.customImage.path", "")
                            const folder = root.readPath("background.widgets.customImage.folder", "")
                            if (newValue === "folder" && folder.length === 0) {
                                customImageFolderDialog.open()
                                return
                            }
                            if (newValue === "file" && path.length === 0) {
                                customImageFileDialog.open()
                                return
                            }
                            root.writePath("background.widgets.customImage.sourceMode", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Single file"), icon: "draft", value: "file" },
                            { displayName: Translation.tr("Folder gallery"), icon: "folder_open", value: "folder" }
                        ]
                    }
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.customImage.sourceMode", "file") === "file"
                    label: Translation.tr("Media file")
                    icon: "perm_media"
                    trailing: false

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Image, GIF, or video")
                        text: root.readPath("background.widgets.customImage.path", "")
                        onAccepted: {
                            const path = text.trim();
                            if (path.length === 0 || Images.isValidMediaByName(path))
                                root.writePath("background.widgets.customImage.path", path);
                        }
                        onEditingFinished: {
                            const path = text.trim();
                            if (path.length === 0 || Images.isValidMediaByName(path))
                                root.writePath("background.widgets.customImage.path", path);
                        }
                    }

                    SelectionGroupButton {
                        Layout.fillWidth: false
                        leftmost: true; rightmost: true
                        buttonIcon: "folder_open"
                        buttonText: Translation.tr("Browse")
                        onClicked: customImageFileDialog.open()
                    }

                    SelectionGroupButton {
                        visible: root.readPath("background.widgets.customImage.path", "").length > 0
                        Layout.fillWidth: false
                        leftmost: true; rightmost: true
                        buttonIcon: "close"
                        buttonText: Translation.tr("Clear")
                        onClicked: {
                            const folder = root.readPath("background.widgets.customImage.folder", "")
                            const updates = ({ "background.widgets.customImage.path": "" })
                            if (folder.length > 0)
                                updates["background.widgets.customImage.sourceMode"] = "folder"
                            root.writePaths(updates)
                        }
                    }
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.customImage.sourceMode", "file") === "folder"
                    label: Translation.tr("Media folder")
                    icon: "folder_open"
                    trailing: false

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Folder containing images or videos")
                        text: root.readPath("background.widgets.customImage.folder", "")
                        onAccepted: root.writePath("background.widgets.customImage.folder", text.trim())
                        onEditingFinished: root.writePath("background.widgets.customImage.folder", text.trim())
                    }

                    SelectionGroupButton {
                        Layout.fillWidth: false
                        leftmost: true; rightmost: true
                        buttonIcon: "folder_open"
                        buttonText: Translation.tr("Browse")
                        onClicked: customImageFolderDialog.open()
                    }

                    SelectionGroupButton {
                        visible: root.readPath("background.widgets.customImage.folder", "").length > 0
                        Layout.fillWidth: false
                        leftmost: true; rightmost: true
                        buttonIcon: "close"
                        buttonText: Translation.tr("Clear")
                        onClicked: {
                            const path = root.readPath("background.widgets.customImage.path", "")
                            const updates = ({ "background.widgets.customImage.folder": "" })
                            if (path.length > 0)
                                updates["background.widgets.customImage.sourceMode"] = "file"
                            root.writePaths(updates)
                        }
                    }
                }

                WidgetSettingRow {
                    visible: root.readPath("background.widgets.customImage.sourceMode", "file") === "folder"
                    label: Translation.tr("Media type")
                    icon: "filter_alt"
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.customImage.mediaFilter", "all")
                        onSelected: newValue => root.writePath("background.widgets.customImage.mediaFilter", newValue)
                        options: [
                            { displayName: Translation.tr("All media") + " (" + root._customMediaFolderCount + ")", icon: "perm_media", value: "all", available: true },
                            { displayName: Translation.tr("Images only") + " (" + root._customMediaFolderImageCount + ")", icon: "image", value: "images", available: root._customMediaFolderImageCount > 0 },
                            { displayName: "GIF (" + root._customMediaFolderGifCount + ")", icon: "motion_photos_on", value: "gifs", available: root._customMediaFolderGifCount > 0 },
                            { displayName: Translation.tr("Videos only") + " (" + root._customMediaFolderVideoCount + ")", icon: "movie", value: "videos", available: root._customMediaFolderVideoCount > 0 }
                        ].filter(option => option.available)
                    }
                }

                SettingsNote {
                    icon: "volume_off"
                    text: Translation.tr("Videos play silently. Images, animated GIFs, and videos can share the same folder.")
                }
            }

            ContentSubsection {
                visible: root.readPath("background.widgets.customImage.sourceMode", "file") === "folder"
                title: Translation.tr("Gallery rotation")

                WidgetSettingRow {
                    label: Translation.tr("Order")
                    icon: "swap_vert"
                    trailing: false

                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.customImage.order", "sequential")
                        onSelected: newValue => root.writePath("background.widgets.customImage.order", newValue)
                        options: [
                            { displayName: Translation.tr("Sequential"), icon: "format_list_numbered", value: "sequential" },
                            { displayName: Translation.tr("Random"), icon: "shuffle", value: "random" }
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Change every")
                    icon: "timer"
                    StyledSpinBox {
                        from: 3; to: 3600; stepSize: 1
                        value: root.readPath("background.widgets.customImage.intervalSeconds", 30)
                        onValueModified: root.writePath("background.widgets.customImage.intervalSeconds", value)
                        StyledToolTip { text: Translation.tr("Seconds between media changes") }
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Quick timing")
                    icon: "speed"
                    trailing: false

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: [3, 10, 30, 60]
                            SelectionGroupButton {
                                required property int modelData
                                Layout.fillWidth: true
                                leftmost: true; rightmost: true
                                toggled: root.readPath(
                                    "background.widgets.customImage.intervalSeconds", 30) === modelData
                                buttonText: modelData + "s"
                                onClicked: root.writePath(
                                    "background.widgets.customImage.intervalSeconds", modelData)
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Shape")

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root._customImageShapes

                        Rectangle {
                            id: shapeCell
                            required property var modelData
                            width: 52
                            height: 52
                            radius: Appearance.rounding.small
                            readonly property bool selected: root.readPath("background.widgets.customImage.shape", "Cookie4Sided") === modelData.value
                            color: selected
                                ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
                                : ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, shapeMouse.containsMouse ? 0.07 : 0.03)
                            border.width: selected ? 1.5 : 0
                            border.color: Appearance.colors.colPrimary

                            MaterialShape {
                                anchors.centerIn: parent
                                implicitSize: 28
                                shape: shapeCell.modelData.shape
                                color: shapeCell.selected
                                    ? Appearance.colors.colPrimary
                                    : Appearance.colors.colOnLayer1
                            }

                            MouseArea {
                                id: shapeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.writePath("background.widgets.customImage.shape", shapeCell.modelData.value)
                            }
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Layout")

                WidgetSettingRow {
                    label: Translation.tr("Size")
                    icon: "photo_size_select_large"
                    StyledSpinBox {
                        from: 80; to: 1200; stepSize: 10
                        value: root.readPath("background.widgets.customImage.size", 220)
                        onValueModified: root.writePath("background.widgets.customImage.size", value)
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Fit")
                    icon: "fit_screen"
                    trailing: false
                    ConfigSelectionArray {
                        Layout.fillWidth: true
                        currentValue: root.readPath("background.widgets.customImage.fitMode", "cover")
                        onSelected: newValue => root.writePath("background.widgets.customImage.fitMode", newValue)
                        options: [
                            { displayName: Translation.tr("Crop to fill"), icon: "crop_free", value: "cover" },
                            { displayName: Translation.tr("Show full media"), icon: "fit_screen", value: "contain" }
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Transition")
                    icon: "animation"
                    StyledSpinBox {
                        from: 0; to: 2000; stepSize: 50
                        value: root.readPath("background.widgets.customImage.transitionDuration", 450)
                        onValueModified: root.writePath("background.widgets.customImage.transitionDuration", value)
                        StyledToolTip { text: Translation.tr("Crossfade duration in milliseconds; 0 disables it") }
                    }
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.customImage"
                configEntry: root.readPath("background.widgets.customImage", ({}))
                hasColorMode: false
                hasCardControls: false
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.customImage"
                defaults: ({
                    enable: false, locked: false, placementStrategy: "free",
                    sourceMode: "file", path: "", folder: "", mediaFilter: "all",
                    intervalSeconds: 30, order: "sequential", transitionDuration: 450,
                    shape: "Cookie4Sided", fitMode: "cover", size: 220,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, x: 120, y: 320
                })
            }
        }
            }
        }
    }

    // ── Image converter ─────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: false
        icon: "transform"
        title: Translation.tr("Image converter")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.imageConverter"
                configEntry: root.readPath("background.widgets.imageConverter", ({}))
                defaultStrategy: "free"
                defaultEnabled: false
            }

            ContentSubsection {
                title: Translation.tr("Conversion")

                ConfigSelectionArray {
                    currentValue: root.readPath("background.widgets.imageConverter.selectedFormat", "webp")
                    onSelected: newValue => root.writePath("background.widgets.imageConverter.selectedFormat", newValue)
                    options: [
                        { displayName: "PNG", icon: "image", value: "png" },
                        { displayName: "JPG", icon: "photo", value: "jpg" },
                        { displayName: "WEBP", icon: "motion_photos_on", value: "webp" },
                        { displayName: "AVIF", icon: "hd", value: "avif" },
                        { displayName: "BMP", icon: "grid_on", value: "bmp" },
                        { displayName: "TIFF", icon: "photo_library", value: "tiff" },
                        { displayName: "PDF", icon: "picture_as_pdf", value: "pdf" }
                    ]
                }

                SettingsNote {
                    icon: "info"
                    text: Translation.tr("Drop one or more images onto the desktop widget. Converted files are saved next to the originals.")
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.imageConverter"
                configEntry: root.readPath("background.widgets.imageConverter", ({}))
                hasColorMode: true
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.imageConverter"
                defaults: ({
                    enable: false, locked: false, placementStrategy: "free",
                    selectedFormat: "webp", contentWidth: 292, contentHeight: 260,
                    widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
                    showBackground: true, useBlur: false, showBorder: true,
                    backgroundOpacity: 0.22, borderWidth: 1, borderOpacity: 0.22,
                    cornerRadius: -1, x: 120, y: 360
                })
            }
        }
            }
        }
    }

    // ── Custom Widgets ──────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "personal"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "personal"
                expanded: false
        icon: "widgets"
        title: Translation.tr("Custom Widgets")

        SettingsGroup {
            // Description
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("QML widgets you create or install. Place widget folders in ~/.config/inir/widgets/ — each needs a widget.json manifest and a .qml file.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            // Action bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Create new
                SelectionGroupButton {
                    Layout.fillWidth: false
                    leftmost: true; rightmost: true
                    buttonIcon: "add"
                    buttonText: Translation.tr("New")
                    onClicked: _cwCreateRow.visible = !_cwCreateRow.visible
                }

                // Install example
                SelectionGroupButton {
                    visible: !root._customWidgetInstalled("example-widget")
                    Layout.fillWidth: false
                    leftmost: true; rightmost: true
                    buttonIcon: "download"
                    buttonText: Translation.tr("Example")
                    onClicked: CustomWidgets.installExample()
                    StyledToolTip { text: Translation.tr("Install the built-in example widget to learn from") }
                }

                Item { Layout.fillWidth: true }

                // Open folder
                RippleButton {
                    width: 36; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => CustomWidgets.openWidgetDir("")
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "folder_open"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Open widgets folder") }
                }

                // Reload
                RippleButton {
                    width: 36; height: 36
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                    colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                    downAction: () => CustomWidgets.reload()
                    contentItem: MaterialSymbol { anchors.centerIn: parent; text: "refresh"; iconSize: 20; color: Appearance.colors.colOnLayer1 }
                    StyledToolTip { text: Translation.tr("Scan for new or changed widgets") }
                }
            }

            // Create widget inline form (hidden by default)
            ColumnLayout {
                id: _cwCreateRow
                visible: false
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    MaterialTextField {
                        id: _newWidgetNameField
                        Layout.fillWidth: true
                        height: 40
                        placeholderText: Translation.tr("widget-name (lowercase, dashes)")
                        font.pixelSize: Appearance.font.pixelSize.small
                        validator: RegularExpressionValidator { regularExpression: /[a-z0-9][a-z0-9\-]*/ }
                        onAccepted: {
                            if (text.length > 0) {
                                CustomWidgets.create(text);
                                text = "";
                                _cwCreateRow.visible = false;
                            }
                        }
                    }
                    SelectionGroupButton {
                        id: _cwCreateBtn
                        Layout.fillWidth: false
                        leftmost: true; rightmost: true
                        buttonIcon: "add"
                        buttonText: Translation.tr("Create")
                        enabled: _newWidgetNameField.text.length > 0
                        opacity: enabled ? 1 : 0.4
                        onClicked: {
                            if (_newWidgetNameField.text.length > 0) {
                                CustomWidgets.create(_newWidgetNameField.text);
                                _newWidgetNameField.text = "";
                                _cwCreateRow.visible = false;
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Creates a template with all imports, services, and an example layout. Edit the .qml file to customize.")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    wrapMode: Text.WordWrap
                }
            }

            // Empty state
            ColumnLayout {
                visible: CustomWidgets.ready && CustomWidgets.widgets.length === 0
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.bottomMargin: 8
                spacing: 8

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "widgets"
                    iconSize: 40
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.2)
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No custom widgets installed")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Click 'New' to create one, or 'Example' to install a demo widget")
                    color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.35)
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }

        // Per-widget cards
        Repeater {
            model: CustomWidgets.ready ? CustomWidgets.widgets : []

            SettingsGroup {
                id: cwDelegate
                required property var modelData
                required property int index

                WidgetStateControls {
                    configPath: "background.widgets.custom." + cwDelegate.modelData.id
                    configEntry: root.readPath("background.widgets.custom." + cwDelegate.modelData.id, ({}))
                    defaultStrategy: "free"
                    widgetTitle: cwDelegate.modelData.name
                }

                ContentSubsection {
                    title: Translation.tr("Position")

                    ConfigRow {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Coordinates")
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        Row {
                            spacing: 8
                            StyledSpinBox {
                                from: 0; to: 10000; stepSize: root.readPath("background.widgets.editGrid.size", 32)
                                value: root.readPath("background.widgets.custom." + cwDelegate.modelData.id + ".x", 240 + cwDelegate.index * 36)
                                onValueModified: root.writePath("background.widgets.custom." + cwDelegate.modelData.id + ".x", value)
                                StyledToolTip { text: Translation.tr("X position") }
                            }
                            StyledSpinBox {
                                from: 0; to: 10000; stepSize: root.readPath("background.widgets.editGrid.size", 32)
                                value: root.readPath("background.widgets.custom." + cwDelegate.modelData.id + ".y", 240 + cwDelegate.index * 28)
                                onValueModified: root.writePath("background.widgets.custom." + cwDelegate.modelData.id + ".y", value)
                                StyledToolTip { text: Translation.tr("Y position") }
                            }
                        }
                    }

                    ConfigRow {
                        Layout.fillWidth: true
                        StyledText {
                            text: Translation.tr("Desktop editing")
                            color: Appearance.colors.colOnLayer1
                        }
                        Item { Layout.fillWidth: true }
                        SelectionGroupButton {
                            Layout.fillWidth: false
                            leftmost: true; rightmost: true
                            buttonIcon: "drag_pan"
                            buttonText: Translation.tr("Edit on desktop")
                            onClicked: {
                                DesktopWidgetLayout.setGloballyEnabled("custom." + cwDelegate.modelData.id, true);
                                GlobalStates.setWidgetEditMode(true);
                            }
                        }
                    }
                }

                ContentSubsection {
                    visible: Object.keys(cwDelegate.modelData.resizableAxes || {}).length > 0
                    title: Translation.tr("Size")

                    WidgetSettingRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).width !== undefined
                        label: Translation.tr("Width")
                        StyledSpinBox {
                            from: 40; to: 2000; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).width ?? "contentWidth", cwDelegate.modelData.defaultSize?.width ?? 200)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).width ?? "contentWidth", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).height !== undefined
                        label: Translation.tr("Height")
                        StyledSpinBox {
                            from: 30; to: 1200; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).height ?? "contentHeight", cwDelegate.modelData.defaultSize?.height ?? 100)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).height ?? "contentHeight", value)
                        }
                    }

                    WidgetSettingRow {
                        visible: (cwDelegate.modelData.resizableAxes || {}).uniform !== undefined && (cwDelegate.modelData.resizableAxes || {}).uniform !== "widgetScale"
                        label: Translation.tr("Size")
                        StyledSpinBox {
                            from: 30; to: 2000; stepSize: 10
                            value: CustomWidgets.getConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).uniform ?? "size", cwDelegate.modelData.defaultSize?.width ?? 200)
                            onValueModified: CustomWidgets.setConfigValue(cwDelegate.modelData.id, (cwDelegate.modelData.resizableAxes || {}).uniform ?? "size", value)
                        }
                    }
                }

                // Meta row: version, author, actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    StyledText {
                        text: (cwDelegate.modelData.author ? (cwDelegate.modelData.author + " · ") : "") + "v" + cwDelegate.modelData.version
                        color: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.5)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                    Item { Layout.fillWidth: true }

                    // Edit (open folder)
                    RippleButton {
                        width: 28; height: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colOnLayer1, 0.12)
                        downAction: () => CustomWidgets.openWidgetDir(cwDelegate.modelData.id)
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "edit"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                        StyledToolTip { text: Translation.tr("Open widget folder") }
                    }

                    // Delete
                    RippleButton {
                        width: 28; height: 28
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(Appearance.colors.colError, 0.08)
                        colRipple: ColorUtils.applyAlpha(Appearance.colors.colError, 0.12)
                        downAction: () => { _cwDeleteConfirm.widgetId = cwDelegate.modelData.id; _cwDeleteConfirm.widgetName = cwDelegate.modelData.name; _cwDeleteConfirm.visible = true }
                        contentItem: MaterialSymbol { anchors.centerIn: parent; text: "delete"; iconSize: 16; color: Appearance.colors.colError }
                        StyledToolTip { text: Translation.tr("Remove widget") }
                    }
                }

                // Validation warnings
                NoticeBox {
                    visible: !cwDelegate.modelData.valid
                    Layout.fillWidth: true
                    materialIcon: "warning"
                    text: (cwDelegate.modelData.warnings || []).join("\n")
                }

                // Auto-generated controls from manifest configKeys
                ContentSubsection {
                    visible: Object.keys(cwDelegate.modelData.configKeys || {}).length > 0
                    title: Translation.tr("Settings")

                    Repeater {
                        model: {
                            const keys = cwDelegate.modelData.configKeys || {};
                            return Object.keys(keys).map(k => ({
                                key: k, spec: keys[k],
                                widgetId: cwDelegate.modelData.id
                            }));
                        }

                        WidgetSettingRow {
                            required property var modelData
                            label: modelData.spec.label || modelData.key
                            trailing: false

                            StyledSwitch {
                                visible: modelData.spec.type === "bool"
                                readonly property bool currentChecked: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? false)
                                checked: currentChecked
                                onClicked: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, checked)
                            }
                            StyledSpinBox {
                                visible: modelData.spec.type === "int"
                                from: modelData.spec.min ?? 0; to: modelData.spec.max ?? 999; stepSize: modelData.spec.step ?? 1
                                value: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? 0)
                                onValueModified: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, value)
                            }
                            StyledSlider {
                                visible: modelData.spec.type === "real"
                                from: modelData.spec.min ?? 0; to: modelData.spec.max ?? 100; stepSize: modelData.spec.step ?? 1
                                value: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? 0)
                                onMoved: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, Math.round(value * 100) / 100)
                            }
                            ConfigSelectionArray {
                                visible: modelData.spec.type === "string" && (modelData.spec.options !== undefined)
                                Layout.fillWidth: false
                                currentValue: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? "")
                                onSelected: newValue => CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, newValue)
                                options: root._manifestOptions(modelData.spec.options)
                            }
                            MaterialTextField {
                                visible: modelData.spec.type === "string" && (modelData.spec.options === undefined)
                                Layout.preferredWidth: 180
                                text: CustomWidgets.getConfigValue(modelData.widgetId, modelData.key, modelData.spec.default ?? "")
                                onAccepted: CustomWidgets.setConfigValue(modelData.widgetId, modelData.key, text)
                            }
                        }
                    }
                }

                WidgetAppearanceControls {
                    configPath: "background.widgets.custom." + cwDelegate.modelData.id
                    configEntry: root.readPath("background.widgets.custom." + cwDelegate.modelData.id, ({}))
                    hasCardControls: root._manifestSupportsSurface(cwDelegate.modelData.configKeys)
                }
            }
        }
            }
        }
    }

    // ── Decorative shape ────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "art"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "art"
                expanded: false
        icon: "category"
        title: Translation.tr("Decorative shape")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.shape"
                configEntry: root.readPath("background.widgets.shape", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Dimensions")
                // a sized card takes its width and height from its size
                visible: !root.sizedWidget("shape")

                WidgetSettingRow {
                    label: Translation.tr("Width")
                    icon: "swap_horiz"
                    StyledSpinBox {
                        from: 64; to: 600; stepSize: 10
                        value: root.readPath("background.widgets.shape.contentWidth", 160)
                        onValueModified: root.writePath("background.widgets.shape.contentWidth", value)
                    }
                }
                WidgetSettingRow {
                    label: Translation.tr("Height")
                    icon: "swap_vert"
                    StyledSpinBox {
                        from: 64; to: 240; stepSize: 4
                        value: root.readPath("background.widgets.shape.contentHeight", 160)
                        onValueModified: root.writePath("background.widgets.shape.contentHeight", value)
                    }
                }
            }

            WidgetShapePicker {
                Layout.fillWidth: true
                selectedShape: root.readPath("background.widgets.shape.shape", "Flower")
                onShapeSelected: name => root.writePath("background.widgets.shape.shape", name)
            }
            WidgetSettingRow {
                label: Translation.tr("Rotation")
                StyledSpinBox {
                    from: 0; to: 360; stepSize: 15
                    value: root.readPath("background.widgets.shape.angle", 0)
                    onValueModified: root.writePath("background.widgets.shape.angle", value)
                }
            }
            ConfigSelectionArray {
                currentValue: root.readPath("background.widgets.shape.outline", false)
                onSelected: newValue => root.writePath("background.widgets.shape.outline", newValue)
                options: [{ displayName: Translation.tr("Filled"), value: false }, { displayName: Translation.tr("Outline"), value: true }]
            }
            ConfigSelectionArray {
                enabled: !root.readPath("background.widgets.shape.outline", false)
                currentValue: root.readPath("background.widgets.shape.treatment", "flat")
                onSelected: newValue => root.writePath("background.widgets.shape.treatment", newValue)
                options: [{ displayName: Translation.tr("Solid"), value: "flat" },
                    { displayName: Translation.tr("Inset"), value: "inset" },
                    { displayName: Translation.tr("Duotone"), value: "duotone" }]
            }
            WidgetAppearanceControls {
                configPath: "background.widgets.shape"
                configEntry: root.readPath("background.widgets.shape", ({}))
                hasCardControls: false
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.shape"
                defaults: ({
                    placementStrategy: "free", contentWidth: 160, contentHeight: 160,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, shape: "Flower", treatment: "flat", outline: false, angle: 0, strokeWidth: 3, showBackground: false,
                    useBlur: false, showBorder: false, backgroundOpacity: 0,
                    borderWidth: 0, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", locked: false, x: 80, y: 240
                })
            }
        }
            }
        }
    }

    // ── Japanese Typography ─────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "art"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "art"
                expanded: false
        icon: "translate"
        title: Translation.tr("Japanese Typography")

        SettingsGroup {
            WidgetStateControls {
                configPath: "background.widgets.japaneseTypography"
                configEntry: root.readPath("background.widgets.japaneseTypography", ({}))
                defaultStrategy: "free"
            }

            ContentSubsection {
                title: Translation.tr("Layout presets")
                JapaneseCompositionPicker {}
            }

            ContentSubsection {
                title: Translation.tr("Editorial content")

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Lead title")
                    text: root.readPath("background.widgets.japaneseTypography.primaryText", "夏の記憶")
                    onAccepted: root.writePath("background.widgets.japaneseTypography.primaryText", text)
                    onEditingFinished: root.writePath("background.widgets.japaneseTypography.primaryText", text)
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Secondary vertical copy")
                    text: root.readPath("background.widgets.japaneseTypography.secondaryText", "潮風と、あの子と、終わらない夏")
                    onAccepted: root.writePath("background.widgets.japaneseTypography.secondaryText", text)
                    onEditingFinished: root.writePath("background.widgets.japaneseTypography.secondaryText", text)
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Seal text")
                    text: root.readPath("background.widgets.japaneseTypography.sealText", "特別展")
                    onAccepted: root.writePath("background.widgets.japaneseTypography.sealText", text)
                    onEditingFinished: root.writePath("background.widgets.japaneseTypography.sealText", text)
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Footer label")
                    text: root.readPath("background.widgets.japaneseTypography.footerText", "PACIFIC DRIVE-IN")
                    onAccepted: root.writePath("background.widgets.japaneseTypography.footerText", text)
                    onEditingFinished: root.writePath("background.widgets.japaneseTypography.footerText", text)
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Date or edition line")
                    text: root.readPath("background.widgets.japaneseTypography.dateText", "7.12 — 8.31")
                    onAccepted: root.writePath("background.widgets.japaneseTypography.dateText", text)
                    onEditingFinished: root.writePath("background.widgets.japaneseTypography.dateText", text)
                }
            }

            ContentSubsection {
                title: Translation.tr("Visible elements")

                SettingsSwitch {
                    buttonIcon: "notes"
                    text: Translation.tr("Show secondary vertical copy")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".showSecondary", true)
                    onToggledByUser: checked => root._setJapaneseValue("showSecondary", checked, "composition")
                }

                SettingsSwitch {
                    buttonIcon: "ink_pen"
                    text: Translation.tr("Show exhibition seal")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".showSeal", true)
                    onToggledByUser: checked => root._setJapaneseValue("showSeal", checked, "composition")
                }

                SettingsSwitch {
                    buttonIcon: "subtitles"
                    text: Translation.tr("Show footer and date")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".showFooter", true)
                    onToggledByUser: checked => root._setJapaneseValue("showFooter", checked, "composition")
                }

                SettingsSwitch {
                    enabled: root.readPath(root._japanesePath + ".showFooter", true)
                    buttonIcon: "horizontal_rule"
                    text: Translation.tr("Show editorial rule")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".showRule", true)
                    onToggledByUser: checked => root._setJapaneseValue("showRule", checked, "composition")
                }

                SettingsSwitch {
                    buttonIcon: "swap_horiz"
                    text: Translation.tr("Mirror composition")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".mirrorLayout", false)
                    onToggledByUser: checked => root._setJapaneseValue("mirrorLayout", checked, "composition")
                }

                SettingsSwitch {
                    buttonIcon: "rotate_90_degrees_cw"
                    text: Translation.tr("Rotate Latin characters vertically")
                    autoToggle: false
                    checked: root.readPath(root._japanesePath + ".rotateLatin", false)
                    onToggledByUser: checked => root._setJapaneseValue("rotateLatin", checked, "composition")
                }
            }

            ContentSubsection {
                title: Translation.tr("Typography")

                WidgetSettingRow {
                    label: Translation.tr("Type direction")
                    icon: "font_download"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath(root._japanesePath + ".fontPreset", "mincho")
                        onSelected: newValue => root._applyJapaneseFontPreset(newValue)
                        options: [
                            { displayName: Translation.tr("Mincho"), icon: "history_edu", value: "mincho" },
                            { displayName: Translation.tr("Mixed"), icon: "format_shapes", value: "mixed" },
                            { displayName: Translation.tr("Gothic"), icon: "text_fields", value: "gothic" }
                        ]
                    }
                }

                FontSelector {
                    id: japaneseTypographyFontSelector
                    label: Translation.tr("Lead title font")
                    icon: "font_download"
                    selectedFont: root.readPath(root._japanesePath + ".fontFamily", "serif")
                    onFontChosen: fontFamily => root._setJapaneseValue("fontFamily", fontFamily, "font")
                    Connections {
                        target: Config.options?.background?.widgets?.japaneseTypography ?? null
                        function onFontFamilyChanged() {
                            japaneseTypographyFontSelector.selectedFont = root.readPath(root._japanesePath + ".fontFamily", "serif")
                        }
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Secondary font")
                    icon: "text_fields"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath(root._japanesePath + ".secondaryFontFamily", "")
                        onSelected: newValue => root._setJapaneseValue("secondaryFontFamily", newValue, "font")
                        options: [
                            { displayName: Translation.tr("Same as title"), value: "" },
                            { displayName: Translation.tr("Serif / Mincho"), value: "serif" },
                            { displayName: Translation.tr("Sans / Gothic"), value: "sans-serif" },
                            { displayName: Translation.tr("Monospace"), value: "monospace" }
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Footer font")
                    icon: "title"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath(root._japanesePath + ".latinFontFamily", "")
                        onSelected: newValue => root._setJapaneseValue("latinFontFamily", newValue, "font")
                        options: [
                            { displayName: Translation.tr("Interface font"), value: "" },
                            { displayName: Translation.tr("Serif"), value: "serif" },
                            { displayName: Translation.tr("Sans"), value: "sans-serif" },
                            { displayName: Translation.tr("Monospace"), value: "monospace" }
                        ]
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Lead weight")
                    icon: "format_bold"
                    StyledSpinBox {
                        from: 100; to: 900; stepSize: 100
                        value: root.readPath(root._japanesePath + ".primaryWeight", 500)
                        onValueModified: root._setJapaneseValue("primaryWeight", value, "font")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Secondary weight")
                    icon: "format_bold"
                    StyledSpinBox {
                        from: 100; to: 900; stepSize: 100
                        value: root.readPath(root._japanesePath + ".secondaryWeight", 400)
                        onValueModified: root._setJapaneseValue("secondaryWeight", value, "font")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Footer weight")
                    icon: "format_bold"
                    StyledSpinBox {
                        from: 100; to: 900; stepSize: 100
                        value: root.readPath(root._japanesePath + ".latinWeight", 600)
                        onValueModified: root._setJapaneseValue("latinWeight", value, "font")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Lead size")
                    icon: "format_size"
                    StyledSpinBox {
                        from: 28; to: 140; stepSize: 2
                        value: root.readPath(root._japanesePath + ".primarySize", 72)
                        onValueModified: root._setJapaneseValue("primarySize", value, "composition")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Secondary size")
                    icon: "text_fields"
                    StyledSpinBox {
                        from: 10; to: 48; stepSize: 1
                        value: root.readPath(root._japanesePath + ".secondarySize", 18)
                        onValueModified: root._setJapaneseValue("secondarySize", value, "composition")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Footer / date size")
                    icon: "format_size"
                    StyledSpinBox {
                        from: 8; to: 32; stepSize: 1
                        value: root.readPath(root._japanesePath + ".footerSize", 14)
                        onValueModified: root._setJapaneseValue("footerSize", value, "composition")
                    }
                    StyledSpinBox {
                        from: 8; to: 28; stepSize: 1
                        value: root.readPath(root._japanesePath + ".dateSize", 12)
                        onValueModified: root._setJapaneseValue("dateSize", value, "composition")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Lead / secondary columns")
                    icon: "view_column"
                    StyledSpinBox {
                        from: 1; to: 4; stepSize: 1
                        value: root.readPath(root._japanesePath + ".primaryColumns", 2)
                        onValueModified: root._setJapaneseValue("primaryColumns", value, "composition")
                    }
                    StyledSpinBox {
                        from: 1; to: 5; stepSize: 1
                        value: root.readPath(root._japanesePath + ".secondaryColumns", 2)
                        onValueModified: root._setJapaneseValue("secondaryColumns", value, "composition")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Column gap")
                    icon: "space_bar"
                    StyledSpinBox {
                        from: 4; to: 48; stepSize: 1
                        value: root.readPath(root._japanesePath + ".columnGap", 14)
                        onValueModified: root._setJapaneseValue("columnGap", value, "composition")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Lead / secondary spacing")
                    icon: "format_line_spacing"
                    StyledSpinBox {
                        from: 0; to: 20; stepSize: 1
                        value: root.readPath(root._japanesePath + ".letterSpacing", 2)
                        onValueModified: root._setJapaneseValue("letterSpacing", value, "font")
                    }
                    StyledSpinBox {
                        from: 0; to: 20; stepSize: 1
                        value: root.readPath(root._japanesePath + ".secondaryLetterSpacing", 1)
                        onValueModified: root._setJapaneseValue("secondaryLetterSpacing", value, "font")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Editorial palette")

                JapanesePalettePicker {}

                WidgetSettingRow {
                    label: Translation.tr("Color source")
                    icon: "palette"
                    trailing: false
                    ConfigSelectionArray {
                        currentValue: root.readPath(root._japanesePath + ".paletteMode", "adaptive")
                        onSelected: newValue => {
                            if (newValue === "adaptive") root._applyJapanesePalettePreset("adaptive")
                            else root._setJapaneseValue("paletteMode", "manual", "palette")
                        }
                        options: [
                            { displayName: Translation.tr("Wallpaper adaptive"), icon: "auto_awesome", value: "adaptive" },
                            { displayName: Translation.tr("Manual roles"), icon: "palette", value: "manual" }
                        ]
                    }
                }

                ColumnLayout {
                    visible: root.readPath(root._japanesePath + ".paletteMode", "adaptive") === "manual"
                    Layout.fillWidth: true
                    spacing: 2

                    JapaneseColorPickerRow { label: Translation.tr("Lead title"); configKey: "primaryColor"; fallbackColor: "#E7D4B2" }
                    JapaneseColorPickerRow { label: Translation.tr("Secondary copy"); configKey: "secondaryColor"; fallbackColor: "#CDB48D" }
                    JapaneseColorPickerRow { label: Translation.tr("Seal"); configKey: "sealColor"; fallbackColor: "#A64B39" }
                    JapaneseColorPickerRow { label: Translation.tr("Footer and date"); configKey: "detailColor"; fallbackColor: "#D0B996" }
                    JapaneseColorPickerRow { label: Translation.tr("Editorial rule"); configKey: "ruleColor"; fallbackColor: "#C18A53" }
                }

                WidgetSettingRow {
                    label: Translation.tr("Lead / secondary opacity")
                    icon: "opacity"
                    StyledSpinBox {
                        from: 10; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".primaryOpacity", 100)
                        onValueModified: root._setJapaneseValue("primaryOpacity", value, "palette")
                    }
                    StyledSpinBox {
                        from: 10; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".secondaryOpacity", 78)
                        onValueModified: root._setJapaneseValue("secondaryOpacity", value, "palette")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Seal / detail opacity")
                    icon: "opacity"
                    StyledSpinBox {
                        from: 10; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".sealOpacity", 100)
                        onValueModified: root._setJapaneseValue("sealOpacity", value, "palette")
                    }
                    StyledSpinBox {
                        from: 10; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".detailOpacity", 72)
                        onValueModified: root._setJapaneseValue("detailOpacity", value, "palette")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Rule opacity")
                    icon: "horizontal_rule"
                    StyledSpinBox {
                        from: 10; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".ruleOpacity", 78)
                        onValueModified: root._setJapaneseValue("ruleOpacity", value, "palette")
                    }
                    StyledSpinBox {
                        from: 1; to: 6; stepSize: 1
                        value: root.readPath(root._japanesePath + ".ruleThickness", 1)
                        onValueModified: root._setJapaneseValue("ruleThickness", value, "composition")
                        StyledToolTip { text: Translation.tr("Rule thickness") }
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Seal fill")
                    icon: "format_color_fill"
                    StyledSpinBox {
                        from: 0; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".sealFillOpacity", 0)
                        onValueModified: root._setJapaneseValue("sealFillOpacity", value, "palette")
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Legibility")

                WidgetSettingRow {
                    label: Translation.tr("Wallpaper shadow")
                    icon: "blur_on"
                    StyledSpinBox {
                        from: 0; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".shadowStrength", 35)
                        onValueModified: root._setJapaneseValue("shadowStrength", value, "palette")
                    }
                }

                WidgetSettingRow {
                    label: Translation.tr("Text outline")
                    icon: "border_outer"
                    StyledSpinBox {
                        from: 0; to: 100; stepSize: 5
                        value: root.readPath(root._japanesePath + ".outlineOpacity", 0)
                        onValueModified: root._setJapaneseValue("outlineOpacity", value, "palette")
                    }
                }

                JapaneseColorPickerRow {
                    visible: root.readPath(root._japanesePath + ".outlineOpacity", 0) > 0
                    label: Translation.tr("Outline color")
                    configKey: "outlineColor"
                    fallbackColor: "#000000"
                }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.japaneseTypography"
                configEntry: root.readPath("background.widgets.japaneseTypography", ({}))
                dimDefault: 10
                hasColorMode: root.readPath(root._japanesePath + ".paletteMode", "adaptive") === "adaptive"
                hasSemanticPalette: root.readPath(root._japanesePath + ".paletteMode", "adaptive") === "adaptive"
                hasCardControls: true
            }

            WidgetResetButton {
                configPath: "background.widgets.japaneseTypography"
                defaults: ({
                    enable: false, locked: false, placementStrategy: "free",
                    preset: "exhibition", primaryText: "夏の記憶",
                    secondaryText: "潮風と、あの子と、終わらない夏",
                    sealText: "特別展", footerText: "PACIFIC DRIVE-IN",
                    dateText: "7.12 — 8.31", showSecondary: true,
                    showSeal: true, showFooter: true, showRule: true,
                    fontPreset: "mincho", fontFamily: "serif",
                    secondaryFontFamily: "", latinFontFamily: "",
                    primaryWeight: 500, secondaryWeight: 400, latinWeight: 600,
                    primarySize: 72, secondarySize: 18, footerSize: 14,
                    dateSize: 12, primaryColumns: 2, secondaryColumns: 2,
                    columnGap: 14, letterSpacing: 2, secondaryLetterSpacing: 1,
                    mirrorLayout: false, rotateLatin: false,
                    paletteMode: "adaptive", palettePreset: "adaptive",
                    primaryColor: "#E7D4B2", secondaryColor: "#CDB48D",
                    sealColor: "#A64B39", detailColor: "#D0B996",
                    ruleColor: "#C18A53", primaryOpacity: 100,
                    secondaryOpacity: 78, sealOpacity: 100, detailOpacity: 72,
                    ruleOpacity: 78, sealFillOpacity: 0, ruleThickness: 1,
                    outlineColor: "#000000", outlineOpacity: 0,
                    shadowStrength: 35, contentWidth: 330,
                    contentHeight: 600, dim: 10, widgetScale: 100,
                    widgetOpacity: 100, showBackground: false, useBlur: false,
                    showBorder: false, backgroundOpacity: 0, borderWidth: 0,
                    borderOpacity: 0.12, cornerRadius: -1, colorMode: "auto",
                    x: 56, y: 120
                })
            }
        }
            }
        }
    }

    // ── Editorial ───────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "art"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "art"
                expanded: false
                icon: "text_fields"
                title: Translation.tr("Editorial")
                SettingsGroup {
                    WidgetStateControls {
                        configPath: "background.widgets.editorial"
                        configEntry: root.readPath("background.widgets.editorial", ({}))
                        defaultStrategy: "free"
                    }
                    ContentSubsection {
                        title: Translation.tr("Editorial content")
                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Title")
                            text: root.readPath("background.widgets.editorial.title", "Make room for wonder.")
                            onEditingFinished: root.writePath("background.widgets.editorial.title", text)
                        }
                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Caption")
                            text: root.readPath("background.widgets.editorial.caption", "A LITTLE EVERY DAY")
                            onEditingFinished: root.writePath("background.widgets.editorial.caption", text)
                        }
                        MaterialTextField {
                            Layout.fillWidth: true
                            placeholderText: Translation.tr("Footer")
                            text: root.readPath("background.widgets.editorial.footer", "YOUR OWN PERSPECTIVE")
                            onEditingFinished: root.writePath("background.widgets.editorial.footer", text)
                        }
                    }
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.editorial.style", "poster")
                        onSelected: newValue => root.writePath("background.widgets.editorial.style", newValue)
                        options: [{ displayName: Translation.tr("Poster"), value: "poster" }, { displayName: Translation.tr("Quote"), value: "quote" }, { displayName: Translation.tr("Label"), value: "label" }]
                    }
                    ConfigSelectionArray {
                        currentValue: root.readPath("background.widgets.editorial.showAccent", true)
                        onSelected: newValue => root.writePath("background.widgets.editorial.showAccent", newValue)
                        options: [{ displayName: Translation.tr("Decorative accents"), value: true }, { displayName: Translation.tr("Text only"), value: false }]
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Width")
                        StyledSpinBox {
                            from: 180; to: 900; stepSize: 20
                            value: root.readPath("background.widgets.editorial.contentWidth", 360)
                            onValueModified: root.writePath("background.widgets.editorial.contentWidth", value)
                        }
                    }
                    WidgetSettingRow {
                        label: Translation.tr("Height")
                        StyledSpinBox {
                            from: 140; to: 900; stepSize: 20
                            value: root.readPath("background.widgets.editorial.contentHeight", 240)
                            onValueModified: root.writePath("background.widgets.editorial.contentHeight", value)
                        }
                    }
                    WidgetAppearanceControls {
                        configPath: "background.widgets.editorial"
                        configEntry: root.readPath("background.widgets.editorial", ({}))
                        hasCardControls: true
                    }
                    WidgetResetButton {
                        configPath: "background.widgets.editorial"
                        defaults: ({ placementStrategy: "free", contentWidth: 360, contentHeight: 240,
                            title: "Make room for wonder.", caption: "A LITTLE EVERY DAY", footer: "YOUR OWN PERSPECTIVE",
                            style: "poster", showAccent: true, widgetScale: 100, widgetOpacity: 100,
                            colorMode: "auto", dim: 0, locked: false, showBackground: false, showBorder: false,
                            backgroundOpacity: 0.12, borderWidth: 1, borderOpacity: 0.2,
                            cornerRadius: -1, useBlur: false, x: 100, y: 300 })
                    }
                }
            }
        }
    }

    // ── Mascot ──────────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "art"
        sourceComponent: Component {
            SettingsCardSection {
                settingsTaskSection: "art"
                expanded: false
        icon: "pets"
        title: Translation.tr("Mascot")

        SettingsGroup {
            id: mascotWidgetGroup

            // Pose thumbnails come from the shared mascot catalog.
            readonly property var poseGroups: [
                { f: "all", label: Translation.tr("All") },
                { f: "featured", label: Translation.tr("Featured") },
                { f: "pixel", label: Translation.tr("Pixel") },
                { f: "street", label: Translation.tr("Street") },
                { f: "chibi", label: Translation.tr("Chibi") },
                { f: "loops", label: Translation.tr("Loops") },
                { f: "manual", label: Translation.tr("Manual") }
            ]
            function _optionsFor(poses: var): var {
                const result = []
                for (let i = 0; i < poses.length; ++i) {
                    const pose = poses[i]
                    result.push({
                        displayName: MascotCatalog.displayName(pose),
                        value: pose,
                        image: MascotCatalog.sourceFor(pose)
                    })
                }
                return result
            }
            readonly property var poseOptions: {
                MascotCatalog.revision
                return mascotWidgetGroup._optionsFor(
                    MascotCatalog.desktopWidgetSelectablePoses)
            }
            // Same persisted key as the widget popover chips, so both stay in sync
            readonly property string poseFilter: {
                Config.revision
                return root.readPath("background.widgets.mascot.poseFilter", "all")
            }
            readonly property var filteredPoseOptions: {
                MascotCatalog.revision
                return mascotWidgetGroup._optionsFor(
                    MascotCatalog.desktopWidgetPosesForGroup(
                        mascotWidgetGroup.poseFilter))
            }

            WidgetStateControls {
                configPath: "background.widgets.mascot"
                configEntry: root.readPath("background.widgets.mascot", ({}))
                defaultStrategy: "free"
            }
            ContentSubsection {
                title: Translation.tr("Image")

                StyledText {
                    Layout.fillWidth: true
                    visible: !(Config.options?.mascot?.enable ?? false)
                text: Translation.tr("Needs the global mascot switch (Settings › Mascot)")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 2
                Repeater {
                    model: mascotWidgetGroup.poseGroups
                    SelectionGroupButton {
                        required property var modelData
                        required property int index
                        leftmost: index === 0
                        rightmost: index === mascotWidgetGroup.poseGroups.length - 1
                        toggled: mascotWidgetGroup.poseFilter === modelData.f
                        buttonText: modelData.label
                        onClicked: root.writePath(
                            "background.widgets.mascot.poseFilter", modelData.f)
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: mascotWidgetGroup.poseFilter === "manual"
                text: Translation.tr("Manual-only poses never rotate automatically")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }
            MascotPoseGallery {
                Layout.fillWidth: true
                label: Translation.tr("Pose on the desktop")
                options: mascotWidgetGroup.filteredPoseOptions
                currentValue: {
                    const configured = root.readPath("background.widgets.mascot.pose", "reading")
                    return mascotWidgetGroup.poseOptions.some(o => o.value === configured)
                        ? configured
                        : (mascotWidgetGroup.poseOptions[0]?.value ?? "presence-idle-loop")
                }
                onSelected: value => root.writePath("background.widgets.mascot.pose", value)
            }
            WidgetSettingRow {
                label: Translation.tr("Custom image")
                icon: "image"
                trailing: false
                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Path to any image or GIF (empty = pose above)")
                    text: root.readPath("background.widgets.mascot.customPath", "")
                    onEditingFinished: root.writePath("background.widgets.mascot.customPath", text.trim())
                }
            }
            }

            WidgetAppearanceControls {
                configPath: "background.widgets.mascot"
                configEntry: root.readPath("background.widgets.mascot", ({}))
                hasColorMode: false
                hasCardControls: true
            }
        }

        SettingsGroup {
            WidgetResetButton {
                configPath: "background.widgets.mascot"
                defaults: ({
                    placementStrategy: "free", contentWidth: 200,
                    dim: 0, widgetScale: 100, widgetOpacity: 100, showBackground: false,
                    useBlur: false, showBorder: false, backgroundOpacity: 0.16,
                    borderWidth: 1, borderOpacity: 0.20, cornerRadius: -1,
                    colorMode: "auto", pose: "reading", customPath: "",
                    anchorWidget: "", locked: false, x: 120, y: 320
                })
            }
        }
            }
        }
    }

    // ── Screen edges ────────────────────────────────────────
    LazySection {
        requested: root.isIiActive && root.activeSection === "edges"
        sourceComponent: OrganicEdgeSettings {}
    }

    // Delete confirmation overlay (shared for all custom widgets)
    NoticeBox {
        id: _cwDeleteConfirm
        property string widgetId: ""
        property string widgetName: ""
        visible: false
        Layout.fillWidth: true
        materialIcon: "delete"
        text: Translation.tr("Remove '%1'? This deletes the widget folder permanently.").arg(_cwDeleteConfirm.widgetName)

        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: _cwDeleteConfirm.visible = false
        }
        DialogButton {
            buttonText: Translation.tr("Delete")
            colEnabled: Appearance.colors.colError
            onClicked: {
                CustomWidgets.remove(_cwDeleteConfirm.widgetId);
                _cwDeleteConfirm.visible = false;
            }
        }
    }
}
