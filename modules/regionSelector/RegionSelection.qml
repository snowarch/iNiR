pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.regionSelector as WaffleRegion
import qs.services
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: true
    color: "transparent"
    WlrLayershell.namespace: "quickshell:regionSelector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    enum SnipAction { Copy, Edit, Search, CharRecognition, Record, RecordWithSound } 
    enum SelectionMode { RectCorners, Circle }
    property var action: RegionSelection.SnipAction.Copy
    property var selectionMode: RegionSelection.SelectionMode.RectCorners
    signal dismiss()
    
    readonly property bool useNiri: CompositorService.isNiri

    property string screenshotDir: Directories.screenshotTemp
    property string imageSearchEngineBaseUrl: Config.options?.search?.imageSearch?.imageSearchEngineBaseUrl ?? "https://lens.google.com/uploadbyurl?url="
    property string fileUploadApiEndpoint: Config.options?.search?.imageSearch?.fileUploadApiEndpoint ?? "https://0x0.st"

    // Tri-style color support
    property color overlayColor: Appearance.angelEverywhere ? "#55000000"
        : Appearance.inirEverywhere ? "#88000000"
        : Appearance.auroraEverywhere ? "#66000000" : "#88111111"
    property color brightText: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0
        : (Appearance.m3colors.darkmode ? Appearance.colors.colOnLayer0 : Appearance.colors.colLayer0)
    property color brightSecondary: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.auroraEverywhere ? Appearance.aurora.colTextSecondary
        : (Appearance.m3colors.darkmode ? Appearance.colors.colSecondary : Appearance.colors.colOnSecondary)
    property color brightTertiary: Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.auroraEverywhere ? Appearance.colors.colPrimary
        : (Appearance.m3colors.darkmode ? Appearance.colors.colTertiary : Qt.lighter(Appearance.colors.colPrimary))
    property color selectionBorderColor: Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : ColorUtils.mix(brightText, brightSecondary, 0.5)
    property color selectionFillColor: Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colPrimary, 0.8)
        : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
        : "#33ffffff"
    property color windowBorderColor: brightSecondary
    property color windowFillColor: ColorUtils.transparentize(windowBorderColor, 0.85)
    property color imageBorderColor: brightTertiary
    property color imageFillColor: ColorUtils.transparentize(imageBorderColor, 0.85)
    property color onBorderColor: Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer0 : "#ff000000"
    readonly property var windows: useNiri
        ? (NiriService.windows || [])
        : [...HyprlandData.windowList].sort((a, b) => {
            // Sort floating=true windows before others
            if (a.floating === b.floating) return 0;
            return a.floating ? -1 : 1;
        })
    readonly property var layers: useNiri ? ({}) : HyprlandData.layers
    readonly property real falsePositivePreventionRatio: 0.5

    readonly property var hyprlandMonitor: CompositorService.isHyprland ? null : null // Disabled for Niri
    readonly property real monitorScale: root.useNiri
        ? ((NiriService.displayScales && NiriService.displayScales[screen.name] !== undefined)
            ? NiriService.displayScales[screen.name]
            : 1)
        : (hyprlandMonitor ? hyprlandMonitor.scale : 1)
    readonly property real monitorOffsetX: root.useNiri ? 0 : (hyprlandMonitor ? hyprlandMonitor.x : 0)
    readonly property real monitorOffsetY: root.useNiri ? 0 : (hyprlandMonitor ? hyprlandMonitor.y : 0)
    property int activeWorkspaceId: root.useNiri 
        ? (NiriService.focusedWorkspaceIndex ?? 0)
        : (hyprlandMonitor && hyprlandMonitor.activeWorkspace ? hyprlandMonitor.activeWorkspace.id : 0)
    property string screenshotPath: `${root.screenshotDir}/image-${screen.name}`
    property bool screenshotReady: false
    property real dragStartX: 0
    property real dragStartY: 0
    property real draggingX: 0
    property real draggingY: 0
    property real dragDiffX: 0
    property real dragDiffY: 0
    property bool draggedAway: (dragDiffX !== 0 || dragDiffY !== 0)
    property bool dragging: false
    property list<point> points: []
    property var mouseButton: null
    property var imageRegions: []
    readonly property list<var> windowRegions: {
        if (root.useNiri) {
            const wins = NiriService.windows || []
            const regions = []
            for (let i = 0; i < wins.length; ++i) {
                const w = wins[i]
                const layout = w.layout
                if (!layout || !layout.tile_pos_in_workspace_view || !layout.tile_size)
                    continue

                const pos = layout.tile_pos_in_workspace_view
                const size = layout.tile_size

                regions.push({
                    at: [pos[0], pos[1]],
                    size: [size[0], size[1]],
                    class: w.app_id || w.appId || "",
                    title: w.title || "",
                })
            }
            return regions
        }

        return RegionFunctions.filterWindowRegionsByLayers(
            root.windows.filter(w => w.workspace.id === root.activeWorkspaceId),
            root.layerRegions
        ).map(window => {
            return {
                at: [window.at[0] - root.monitorOffsetX, window.at[1] - root.monitorOffsetY],
                size: [window.size[0], window.size[1]],
                class: window.class,
                title: window.title,
            }
        })
    }
    readonly property list<var> layerRegions: {
        if (root.useNiri)
            return [];

        const layersOfThisMonitor = root.layers[root.hyprlandMonitor.name]
        const topLayers = layersOfThisMonitor?.levels["2"]
        if (!topLayers) return [];
        const nonBarTopLayers = topLayers
            .filter(layer => !(layer.namespace.includes(":bar") || layer.namespace.includes(":verticalBar") || layer.namespace.includes(":dock")))
            .map(layer => {
            return {
                at: [layer.x, layer.y],
                size: [layer.w, layer.h],
                namespace: layer.namespace,
            }
        })
        const offsetAdjustedLayers = nonBarTopLayers.map(layer => {
            return {
                at: [layer.at[0] - root.monitorOffsetX, layer.at[1] - root.monitorOffsetY],
                size: layer.size,
                namespace: layer.namespace,
            }
        });
        return offsetAdjustedLayers;
    }

    property bool isCircleSelection: (root.selectionMode === RegionSelection.SelectionMode.Circle)
    property bool enableWindowRegions: (Config.options?.regionSelector?.targetRegions?.windows ?? true) && !isCircleSelection
    property bool enableLayerRegions: (Config.options?.regionSelector?.targetRegions?.layers ?? true) && !isCircleSelection
    property bool enableContentRegions: Config.options?.regionSelector?.targetRegions?.content ?? true
    property real targetRegionOpacity: Config.options?.regionSelector?.targetRegions?.opacity ?? 0.5
    property real contentRegionOpacity: Config.options?.regionSelector?.targetRegions?.contentRegionOpacity ?? 0.3

    property real targetedRegionX: -1
    property real targetedRegionY: -1
    property real targetedRegionWidth: 0
    property real targetedRegionHeight: 0
    function targetedRegionValid() {
        return (root.targetedRegionX >= 0 && root.targetedRegionY >= 0)
    }
    function setRegionToTargeted() {
        const padding = Config.options?.regionSelector?.targetRegions?.selectionPadding ?? 2; // Make borders not cut off n stuff
        root.regionX = root.targetedRegionX - padding;
        root.regionY = root.targetedRegionY - padding;
        root.regionWidth = root.targetedRegionWidth + padding * 2;
        root.regionHeight = root.targetedRegionHeight + padding * 2;
    }

    function updateTargetedRegion(x, y) {
        function regionContainsPoint(region) {
            if (!region || !region.at || !region.size)
                return false;
            if (region.at.length < 2 || region.size.length < 2)
                return false;

            const rx = region.at[0];
            const ry = region.at[1];
            const rw = region.size[0];
            const rh = region.size[1];
            return rx <= x && x <= rx + rw && ry <= y && y <= ry + rh;
        }

        // Image regions
        const clickedRegion = root.imageRegions.find(region => regionContainsPoint(region));
        if (clickedRegion) {
            root.targetedRegionX = clickedRegion.at[0];
            root.targetedRegionY = clickedRegion.at[1];
            root.targetedRegionWidth = clickedRegion.size[0];
            root.targetedRegionHeight = clickedRegion.size[1];
            return;
        }

        // Layer regions
        const clickedLayer = root.layerRegions.find(region => regionContainsPoint(region));
        if (clickedLayer) {
            root.targetedRegionX = clickedLayer.at[0];
            root.targetedRegionY = clickedLayer.at[1];
            root.targetedRegionWidth = clickedLayer.size[0];
            root.targetedRegionHeight = clickedLayer.size[1];
            return;
        }

        // Window regions
        const clickedWindow = root.windowRegions.find(region => regionContainsPoint(region));
        if (clickedWindow) {
            root.targetedRegionX = clickedWindow.at[0];
            root.targetedRegionY = clickedWindow.at[1];
            root.targetedRegionWidth = clickedWindow.size[0];
            root.targetedRegionHeight = clickedWindow.size[1];
            return;
        }

        root.targetedRegionX = -1;
        root.targetedRegionY = -1;
        root.targetedRegionWidth = 0;
        root.targetedRegionHeight = 0;
    }

    function regionMatchesTarget(region) {
        if (!region || !region.at || !region.size)
            return false;
        if (region.at.length < 2 || region.size.length < 2)
            return false;

        return root.targetedRegionX === region.at[0]
            && root.targetedRegionY === region.at[1]
            && root.targetedRegionWidth === region.size[0]
            && root.targetedRegionHeight === region.size[1];
    }

    property real regionWidth: Math.abs(draggingX - dragStartX)
    property real regionHeight: Math.abs(draggingY - dragStartY)
    property real regionX: Math.min(dragStartX, draggingX)
    property real regionY: Math.min(dragStartY, draggingY)

    Component.onCompleted: {
        root.screenshotReady = false
        screenshotProc.running = true
    }

    Process {
        id: screenshotProc
        running: false
        command: ["/usr/bin/bash", "-c", `/usr/bin/mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}' && /usr/bin/grim -o '${StringUtils.shellSingleQuoteEscape(root.screen.name)}' '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.screenshotReady = false
                Quickshell.execDetached(["/usr/bin/notify-send", "Region search failed", "grim failed to capture the screen" , "-a", "Region Selector", "-t", "4000"])
            } else {
                root.screenshotReady = true
            }
            if (root.enableContentRegions) imageDetectionProcess.running = true;
            root.preparationDone = !checkRecordingProc.running;
        }
    }
    property bool isRecording: root.action === RegionSelection.SnipAction.Record || root.action === RegionSelection.SnipAction.RecordWithSound
    property bool recordingShouldStop: false
    Process {
        id: checkRecordingProc
        running: isRecording
        command: ["/usr/bin/pidof", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            root.preparationDone = !screenshotProc.running
            root.recordingShouldStop = (exitCode === 0);
        }
    }
    property bool preparationDone: false
    onPreparationDoneChanged: {
        if (!preparationDone) return;
        if (root.isRecording && root.recordingShouldStop) {
            Quickshell.execDetached([Directories.recordScriptPath]);
            root.dismiss();
            return;
        }
        Qt.callLater(() => { root.visible = true; });
    }

    Process {
        id: imageDetectionProcess
        command: ["/usr/bin/bash", "-c", `${Directories.scriptPath}/images/find-regions-venv.sh ` 
            + `--image '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' ` 
            + `--max-width ${Math.round(root.screen.width * root.falsePositivePreventionRatio)} ` 
            + `--max-height ${Math.round(root.screen.height * root.falsePositivePreventionRatio)} `]
        stdout: StdioCollector {
            id: imageDimensionCollector
            onStreamFinished: {
                try {
                    const text = imageDimensionCollector.text.trim()
                    if (text) {
                        imageRegions = RegionFunctions.filterImageRegions(
                            JSON.parse(text),
                            root.windowRegions
                        );
                    }
                } catch (e) {
                    imageRegions = []
                }
            }
        }
    }

    function snip() {
        if (root.regionWidth <= 0 || root.regionHeight <= 0) {
            root.dismiss();
            return;
        }

        root.regionX = Math.max(0, Math.min(root.regionX, root.screen.width - root.regionWidth));
        root.regionY = Math.max(0, Math.min(root.regionY, root.screen.height - root.regionHeight));
        root.regionWidth = Math.max(0, Math.min(root.regionWidth, root.screen.width - root.regionX));
        root.regionHeight = Math.max(0, Math.min(root.regionHeight, root.screen.height - root.regionY));

        if (root.action === RegionSelection.SnipAction.Copy || root.action === RegionSelection.SnipAction.Edit) {
            root.action = root.mouseButton === Qt.RightButton ? RegionSelection.SnipAction.Edit : RegionSelection.SnipAction.Copy;
        }

        const rx = Math.round(root.regionX * root.monitorScale);
        const ry = Math.round(root.regionY * root.monitorScale);
        const rw = Math.round(root.regionWidth * root.monitorScale);
        const rh = Math.round(root.regionHeight * root.monitorScale);
        const cropBase = `magick ${StringUtils.shellSingleQuoteEscape(root.screenshotPath)} `
            + `-crop ${rw}x${rh}+${rx}+${ry}`
        const cropToStdout = `${cropBase} -`
        const cropInPlace = `${cropBase} '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`
        const cleanup = `/usr/bin/rm '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}'`
        const slurpRegion = `${rx},${ry} ${rw}x${rh}`
        const uploadAndGetUrl = (filePath) => {
            return `/usr/bin/curl -sF file=@'${StringUtils.shellSingleQuoteEscape(filePath)}' ${root.fileUploadApiEndpoint}`
        }
        const annotationCommand = `${(Config.options?.regionSelector?.annotation?.useSatty ?? false) ? "satty" : "swappy"} -f -`;
        switch (root.action) {
            case RegionSelection.SnipAction.Copy:
                snipProc.command = ["/usr/bin/bash", "-c", `${cropToStdout} | /usr/bin/wl-copy && ${cleanup} && /usr/bin/notify-send "Screenshot copied" "${rw}x${rh} region copied to clipboard" -a "Screenshot" -i camera-photo -t 3000`]
                break;
            case RegionSelection.SnipAction.Edit:
                snipProc.command = ["/usr/bin/bash", "-c", `${cropToStdout} | ${annotationCommand} && ${cleanup}`]
                break;
            case RegionSelection.SnipAction.Search:
                snipProc.command = ["/usr/bin/bash", "-c", `${cropInPlace} && /usr/bin/xdg-open "${root.imageSearchEngineBaseUrl}$(${uploadAndGetUrl(root.screenshotPath)})" && ${cleanup}`]
                break;
            case RegionSelection.SnipAction.CharRecognition:
                snipProc.command = ["/usr/bin/bash", "-c", `${cropInPlace} && /usr/bin/tesseract '${StringUtils.shellSingleQuoteEscape(root.screenshotPath)}' stdout -l $(/usr/bin/tesseract --list-langs | /usr/bin/awk 'NR>1{print $1}' | /usr/bin/tr '\\n' '+' | /usr/bin/sed 's/\\+$/\\n/') | /usr/bin/wl-copy && ${cleanup} && /usr/bin/notify-send "Text recognized" "OCR text copied to clipboard" -a "OCR" -i edit-find -t 3000`]
                break;
            case RegionSelection.SnipAction.Record:
                snipProc.command = ["/usr/bin/bash", "-c", `${Directories.recordScriptPath} --region '${slurpRegion}'`]
                break;
            case RegionSelection.SnipAction.RecordWithSound:
                snipProc.command = ["/usr/bin/bash", "-c", `${Directories.recordScriptPath} --region '${slurpRegion}' --sound`]
                break;
            default:
                root.dismiss();
                return;
        }

        // Image post-processing
        snipProc.startDetached();
        root.dismiss();
    }

    Process {
        id: snipProc
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        Image {
            anchors.fill: parent
            source: root.visible && root.screenshotReady ? `file://${root.screenshotPath}` : ""
            fillMode: Image.PreserveAspectFit
            cache: false
        }

        focus: root.visible
        Keys.onPressed: (event) => { // Esc to close
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            cursorShape: Qt.CrossCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true

            // Controls
            onPressed: (mouse) => {
                root.dragStartX = mouse.x;
                root.dragStartY = mouse.y;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragging = true;
                root.mouseButton = mouse.button;
            }
            onReleased: (mouse) => {
                // Detect if it was a click -> Try to select targeted region
                if (root.draggingX === root.dragStartX && root.draggingY === root.dragStartY) {
                    if (root.targetedRegionValid()) {
                        root.setRegionToTargeted();
                    }
                }
                // Circle dragging?
                else if (root.selectionMode === RegionSelection.SelectionMode.Circle) {
                    const padding = (Config.options?.regionSelector?.circle?.padding ?? 10) + (Config.options?.regionSelector?.circle?.strokeWidth ?? 2) / 2;
                    const dragPoints = (root.points.length > 0) ? root.points : [{ x: mouseArea.mouseX, y: mouseArea.mouseY }];
                    const maxX = Math.max(...dragPoints.map(p => p.x));
                    const minX = Math.min(...dragPoints.map(p => p.x));
                    const maxY = Math.max(...dragPoints.map(p => p.y));
                    const minY = Math.min(...dragPoints.map(p => p.y));
                    root.regionX = minX - padding;
                    root.regionY = minY - padding;
                    root.regionWidth = maxX - minX + padding * 2;
                    root.regionHeight = maxY - minY + padding * 2;
                }
                root.snip();
            }
            onPositionChanged: (mouse) => {
                root.updateTargetedRegion(mouse.x, mouse.y);
                if (!root.dragging) return;
                root.draggingX = mouse.x;
                root.draggingY = mouse.y;
                root.dragDiffX = mouse.x - root.dragStartX;
                root.dragDiffY = mouse.y - root.dragStartY;
                root.points.push({ x: mouse.x, y: mouse.y });
            }
            
            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.RectCorners
                sourceComponent: RectCornersSelectionDetails {
                    regionX: root.regionX
                    regionY: root.regionY
                    regionWidth: root.regionWidth
                    regionHeight: root.regionHeight
                    mouseX: mouseArea.mouseX
                    mouseY: mouseArea.mouseY
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                }
            }

            Loader {
                z: 2
                anchors.fill: parent
                active: root.selectionMode === RegionSelection.SelectionMode.Circle
                sourceComponent: CircleSelectionDetails {
                    color: root.selectionBorderColor
                    overlayColor: root.overlayColor
                    points: root.points
                }
            }

            // Window regions
            Repeater {
                model: ScriptModel {
                    values: root.enableWindowRegions ? root.windowRegions : []
                }
                delegate: TargetRegion {
                    z: 2
                    required property var modelData
                    clientDimensions: modelData
                    showIcon: true
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    text: `${modelData.class}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Layer regions
            Repeater {
                model: ScriptModel {
                    values: root.enableLayerRegions ? root.layerRegions : []
                }
                delegate: TargetRegion {
                    z: 3
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.targetRegionOpacity
                    borderColor: root.windowBorderColor
                    fillColor: targeted ? root.windowFillColor : "transparent"
                    text: `${modelData.namespace}`
                    radius: Appearance.rounding.windowRounding
                }
            }

            // Content regions
            Repeater {
                model: ScriptModel {
                    values: root.enableContentRegions ? root.imageRegions : []
                }
                delegate: TargetRegion {
                    z: 4
                    required property var modelData
                    clientDimensions: modelData
                    targeted: !root.draggedAway && root.regionMatchesTarget(modelData)

                    opacity: root.draggedAway ? 0 : root.contentRegionOpacity
                    borderColor: root.imageBorderColor
                    fillColor: targeted ? root.imageFillColor : "transparent"
                    text: Translation.tr("Content region")
                }
            }

            // Controls
            Item {
                id: regionSelectionControls
                z: 9999
                implicitWidth: controlsLoader.implicitWidth
                implicitHeight: controlsLoader.implicitHeight
                opacity: 0
                
                readonly property bool useWaffle: Config.options?.panelFamily === "waffle"
                
                // Position: waffle = top center, material = bottom center
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: useWaffle ? parent.top : undefined
                    bottom: useWaffle ? undefined : parent.bottom
                    topMargin: useWaffle ? -height : 0
                    bottomMargin: useWaffle ? 0 : -height
                }
                
                Connections {
                    target: root
                    function onVisibleChanged() {
                        if (!visible) return;
                        if (regionSelectionControls.useWaffle) {
                            regionSelectionControls.anchors.topMargin = 16;
                        } else {
                            regionSelectionControls.anchors.bottomMargin = 8;
                        }
                        regionSelectionControls.opacity = 1;
                    }
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on anchors.topMargin {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
                Behavior on anchors.bottomMargin {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Loader {
                    id: controlsLoader
                    sourceComponent: regionSelectionControls.useWaffle ? waffleControls : materialControls
                }

                // Material ii controls
                Component {
                    id: materialControls
                    Row {
                        spacing: 6

                        OptionsToolbar {
                            action: root.action
                            selectionMode: root.selectionMode
                            onActionChanged: root.action = action
                            onSelectionModeChanged: root.selectionMode = selectionMode
                            onDismiss: root.dismiss();
                        }
                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: closeFab.implicitWidth
                            implicitHeight: closeFab.implicitHeight
                            StyledRectangularShadow {
                                target: closeFab
                                radius: closeFab.buttonRadius
                            }
                            FloatingActionButton {
                                id: closeFab
                                baseSize: 48
                                iconText: "close"
                                onClicked: root.dismiss();
                                StyledToolTip {
                                    text: Translation.tr("Close")
                                }
                                colBackground: Appearance.colors.colTertiaryContainer
                                colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                                colRipple: Appearance.colors.colTertiaryContainerActive
                                colOnBackground: Appearance.colors.colOnTertiaryContainer
                            }
                        }
                    }
                }

                // Waffle (Windows 11) controls
                Component {
                    id: waffleControls
                    WaffleRegion.WOptionsToolbar {
                        action: root.action
                        selectionMode: root.selectionMode
                        onActionChanged: root.action = action
                        onSelectionModeChanged: root.selectionMode = selectionMode
                        onDismiss: root.dismiss()
                    }
                }
            }
            
        }
    }
}
