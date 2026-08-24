pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.background.widgets
import qs.modules.mediaControls.presets

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "mediaControls"
    defaultConfig: ({
        placementStrategy: "free", playerPreset: "full",
        visualizerType: "wave", visualizerPosition: "bottom",
        lyricsExpanded: false,
        widgetScale: 100, widgetOpacity: 100, colorMode: "auto", dim: 0,
        x: 240, y: 240
    })

    readonly property var presetGeometry: ({
        "full": { w: 380, h: 150 },
        "compact": { w: 380, h: 122 },
        "minimal": { w: 340, h: 110 },
        "classic": { w: 380, h: 150 },
        "visualizer": { w: 380, h: 164 },
        "albumart": { w: 300, h: 330 },
        "lyrics": { w: 340, h: 400, hBare: 190 },
        "lyricsSplit": { w: 470, h: 268, hBare: 156 },
        "expandingLyrics": { w: 400, h: 128 }
    })
    readonly property var sizedGeometry: root.presetGeometry[root.effectiveSizedPreset]
        ?? root.presetGeometry["full"]

    readonly property real widgetWidth: Math.round(
        root.sizedGeometry.w * Appearance.fontSizeScale * scaleFactor)

    readonly property bool lyricsAvailable: LyricsService.status === "ok"
        && LyricsService.lyricsLines.length > 0
    readonly property bool _shrinksWithoutLyrics: root.placementStrategy === "free"
    property real lyricsSheetHeight: (root.sizedGeometry.hBare !== undefined
            && (root.lyricsAvailable || !root._shrinksWithoutLyrics))
        ? Math.round((root.sizedGeometry.h - root.sizedGeometry.hBare)
            * Appearance.fontSizeScale * scaleFactor)
        : 0
    Behavior on lyricsSheetHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
        }
    }

    readonly property string selectedPreset: Config.getNestedValue("background.widgets.mediaControls.playerPreset", "full")
    property string renderedPreset: ""
    property string sizedPreset: ""
    property bool presetLoaderActive: true
    property bool _presetLifecycleReady: false
    readonly property string effectiveRenderedPreset: root.renderedPreset !== "" ? root.renderedPreset : root.selectedPreset
    readonly property string effectiveSizedPreset: root.sizedPreset !== "" ? root.sizedPreset : root.effectiveRenderedPreset

    Component.onCompleted: {
        root.renderedPreset = root.selectedPreset;
        root.sizedPreset = root.selectedPreset;
        root._presetLifecycleReady = true;
    }

    onSelectedPresetChanged: {
        if (root._presetLifecycleReady)
            presetUnloadTimer.restart();
    }

    Timer {
        id: presetUnloadTimer
        interval: 1
        repeat: false
        onTriggered: {
            root.presetLoaderActive = false;
            presetLoadTimer.restart();
        }
    }

    Timer {
        id: presetLoadTimer
        interval: 64
        repeat: false
        onTriggered: {
            root.renderedPreset = root.selectedPreset;
            root.presetLoaderActive = true;
        }
    }

    readonly property bool lyricsPanelOpen: root.effectiveSizedPreset === "expandingLyrics"
        && Config.getNestedValue("background.widgets.mediaControls.lyricsExpanded", false)
    property real lyricsPanelHeight: root.lyricsPanelOpen
        ? Math.round(250 * Appearance.fontSizeScale * scaleFactor) : 0
    Behavior on lyricsPanelHeight {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementResize.duration
            easing.type: Appearance.animation.elementResize.type
            easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
        }
    }

    readonly property real widgetHeight: Math.round(
        (root.sizedGeometry.hBare ?? root.sizedGeometry.h) * Appearance.fontSizeScale * scaleFactor)
        + root.lyricsSheetHeight + root.lyricsPanelHeight

    accentBackdrop: Appearance.colors.colLayer0
    readonly property color mediaSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        : root.widgetSemanticForeground(root.widgetSurfaceRole,
            Appearance.colors.colLayer0, 4.5)
    readonly property color mediaSurfaceInkMuted: ColorUtils.applyAlpha(root.mediaSurfaceInk, 0.66)
    readonly property QtObject _desktopInkOverride: QtObject {
        property color colOnLayer0: root.mediaSurfaceInk
        property color colSubtext: root.mediaSurfaceInkMuted
    }
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
    resizableAxes: ({ uniform: "widgetScale" })
    resizeMinWidth: 160
    resizeMinHeight: 80
    needsColText: true

    readonly property color accentPrimary: root.widgetAccent

    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")

    editPopoverContent: Component {
        ColumnLayout {
            spacing: 6
            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Full"), icon: "view_agenda", value: "full" },
                        { label: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                        { label: Translation.tr("Minimal"), icon: "minimize", value: "minimal" },
                        { label: Translation.tr("Album"), icon: "album", value: "albumart" },
                        { label: Translation.tr("Viz"), icon: "graphic_eq", value: "visualizer" },
                        { label: Translation.tr("Classic"), icon: "music_note", value: "classic" },
                        { label: Translation.tr("Lyrics"), icon: "lyrics", value: "lyrics" },
                        { label: Translation.tr("Lyrics wide"), icon: "subtitles", value: "lyricsSplit" },
                        { label: Translation.tr("Cover"), icon: "art_track", value: "expandingLyrics" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.selectedPreset === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.playerPreset", modelData.value)
                    }
                }
            }
            GridLayout {
                columns: 2
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Wave"), icon: "waves", value: "wave" },
                        { label: Translation.tr("Bars"), icon: "equalizer", value: "bars" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.vizType === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.visualizerType", modelData.value)
                    }
                }
            }
            GridLayout {
                columns: 4
                columnSpacing: 4
                rowSpacing: 4
                Repeater {
                    model: [
                        { label: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                        { label: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                        { label: Translation.tr("Fill"), icon: "fullscreen", value: "fill" },
                        { label: Translation.tr("Off"), icon: "visibility_off", value: "none" }
                    ]
                    SelectionGroupButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.vizPosition === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.visualizerPosition", modelData.value)
                    }
                }
            }
        }
    }

    readonly property MprisPlayer meaningfulPlayer: MprisController.activePlayer
    readonly property var meaningfulPlayers: root.meaningfulPlayer
        ? [root.meaningfulPlayer] : []
    readonly property bool hasPlayer: root.meaningfulPlayers.length > 0

    implicitWidth: root.hasPlayer ? root.widgetWidth : root.placeholderWidth
    implicitHeight: root.hasPlayer ? root.widgetHeight : root.placeholderHeight
    readonly property real placeholderWidth: Math.round(
        96 * Appearance.fontSizeScale * scaleFactor)
    readonly property real placeholderHeight: root.placeholderWidth

    property int _idleShapeIndex: 0
    readonly property var _idleShapes: [
        MaterialShape.Shape.Cookie4Sided,
        MaterialShape.Shape.Clover4Leaf,
        MaterialShape.Shape.Cookie12Sided,
        MaterialShape.Shape.SoftBurst
    ]

    Timer {
        running: !root.hasPlayer && root.visible && root.powerActive
            && Appearance.animationsEnabled
        interval: 9000
        repeat: true
        onTriggered: root._idleShapeIndex = (root._idleShapeIndex + 1) % root._idleShapes.length
    }

    // This instance only exists when its effective output-local enable state is
    // true. Rechecking the global base would incorrectly disable Cava for a
    // widget enabled only on this monitor.
    readonly property bool visualizerActive: root.vizPosition !== "none"
        && root.visible && root.powerActive && MprisController.isPlaying

    CavaProcess {
        id: cavaProcess
        active: root.visualizerActive
    }

    property list<real> visualizerPoints: cavaProcess.points

    readonly property point widgetScreenPos: root.mapToItem(null, 0, 0)
    
    readonly property Component presetComponent: {
        switch (root.effectiveRenderedPreset) {
            case "compact": return compactPlayerComponent
            case "minimal": return minimalPlayerComponent
            case "albumart": return albumArtPlayerComponent
            case "visualizer": return visualizerPlayerComponent
            case "classic": return classicPlayerComponent
            case "lyrics": return lyricsPlayerComponent
            case "lyricsSplit": return lyricsSplitPlayerComponent
            case "expandingLyrics": return expandingLyricsPlayerComponent
            case "full":
            default: return fullPlayerComponent
        }
    }
    
    Component {
        id: fullPlayerComponent
        FullPlayer {}
    }
    
    Component {
        id: compactPlayerComponent
        CompactPlayer {}
    }
    
    Component {
        id: minimalPlayerComponent
        MinimalPlayer {}
    }
    
    Component {
        id: albumArtPlayerComponent
        AlbumArtPlayer {}
    }
    
    Component {
        id: visualizerPlayerComponent
        VisualizerPlayer {}
    }
    
    Component {
        id: classicPlayerComponent
        ClassicPlayer {}
    }

    Component {
        id: lyricsPlayerComponent
        LyricsPlayer {}
    }

    Component {
        id: lyricsSplitPlayerComponent
        LyricsSplitPlayer {}
    }

    Component {
        id: expandingLyricsPlayerComponent
        ExpandingLyricsPlayer {}
    }

    ColumnLayout {
        id: playerColumnLayout
        anchors.fill: parent
        spacing: -Appearance.sizes.elevationMargin

        Repeater {
            model: ScriptModel {
                values: root.meaningfulPlayers
            }
            delegate: Item {
                id: delegateRoot
                required property MprisPlayer modelData
                Layout.preferredWidth: root.widgetWidth
                Layout.preferredHeight: root.widgetHeight

                StyledRectangularShadow {
                    target: playerLoader
                    radius: root.popupRounding
                }

                Loader {
                    id: playerLoader
                    anchors.fill: parent
                    active: root.presetLoaderActive
                    sourceComponent: root.presetComponent

                    onLoaded: {
                        item.player = delegateRoot.modelData
                        item.blendedColors = root._desktopInkOverride
                        item.themeSourceColor = Qt.binding(() => root.widgetAccentVisible)
                        item.visualizerPoints = Qt.binding(() => root.visualizerPoints)
                        item.radius = root.popupRounding
                        item.screenX = Qt.binding(() => root.widgetScreenPos.x)
                        item.screenY = Qt.binding(() => root.widgetScreenPos.y)
                        const loadedPreset = root.effectiveRenderedPreset;
                        Qt.callLater(() => {
                            if (root.presetLoaderActive
                                    && root.effectiveRenderedPreset === loadedPreset
                                    && root.selectedPreset === loadedPreset)
                                root.sizedPreset = loadedPreset;
                        });
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasPlayer

            MaterialShape {
                id: idleOrnament
                anchors.centerIn: parent
                implicitSize: Math.max(24, Math.min(parent.width, parent.height)
                    - Appearance.sizes.elevationMargin)
                shape: root._idleShapes[root._idleShapeIndex]
                color: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.20)

                animation: NumberAnimation {
                    duration: Appearance.animation.elementMoveEnter.duration
                    easing.type: Appearance.animation.elementMoveEnter.type
                    easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "music_note"
                    fill: 1
                    iconSize: Math.round(idleOrnament.implicitSize * 0.34)
                    color: root.widgetAccentVisible
                }

                StyledToolTip {
                    text: Translation.tr("No active player")
                    visible: idleHover.hovered
                }

                HoverHandler {
                    id: idleHover
                }
            }
        }
    }
}
