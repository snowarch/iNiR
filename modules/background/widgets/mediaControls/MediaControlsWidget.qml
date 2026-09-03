pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.background.widgets
import qs.modules.mediaControls.presets
import qs.modules.mediaControls.components

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
        visualizerPaletteMode: "cava", visualizerOpacity: 55,
        visualizerSmoothing: 2, visualizerFrequencyProfile: "flat",
        visualizerAccentStrength: 70, visualizerRange: 88, visualizerBarCount: 32,
        organicSensitivity: 35, organicPulse: 150, organicMotionSpeed: 250,
        organicIdleMotion: 40, organicGlow: 100, organicOpacity: 100,
        organicReach: 35, organicRange: 20, organicCompression: 0,
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

    MediaArtworkResolver {
        id: organicArtworkResolver
        sourceUrl: root.vizType === "organic" && root.meaningfulPlayer
            ? MprisController.effectiveArtUrl(root.meaningfulPlayer) : ""
        title: root.meaningfulPlayer?.trackTitle ?? ""
        artist: root.meaningfulPlayer?.trackArtist ?? ""
        album: root.meaningfulPlayer?.trackAlbum ?? ""
    }

    ColorQuantizer {
        id: organicArtworkQuantizer
        source: root.vizType === "organic" ? organicArtworkResolver.displaySource : ""
        depth: 2
        rescaleSize: 24
    }

    readonly property var organicArtworkPalette: {
        const colors = organicArtworkQuantizer?.colors ?? []
        if (colors.length === 0)
            return [root.widgetAccentVisible, root.widgetAccent2Visible, root.widgetAccent3Visible]
        const primary = colors[0]
        const secondary = colors[Math.min(1, colors.length - 1)]
        const tertiary = colors[Math.min(2, colors.length - 1)]
        return [primary, secondary, tertiary]
    }

    editPopoverContent: Component {
        ColumnLayout {
            id: mediaQuickRoot
            implicitWidth: 360
            readonly property bool narrow: width < 300
            spacing: 10

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Player style")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.quickControlsWide ? 5 : 3
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
                        required property int index
                        Layout.fillWidth: true
                        readonly property int groupColumns:
                            root.quickControlsWide ? 5 : 3
                        leftmost: index % groupColumns === 0
                        rightmost: index % groupColumns === groupColumns - 1
                            || index === 8
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.selectedPreset === modelData.value
                        onClicked: Config.setNestedValue("background.widgets.mediaControls.playerPreset", modelData.value)
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: mediaVizQuick.implicitHeight + 20
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colOutlineVariant

                ColumnLayout {
                    id: mediaVizQuick
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Visualizer")
                            color: Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                        }
                        SelectionGroupButton {
                            leftmost: true; rightmost: true
                            buttonIcon: root.vizPosition === "none" ? "visibility_off" : "visibility"
                            buttonText: root.vizPosition === "none" ? Translation.tr("Off") : Translation.tr("On")
                            toggled: root.vizPosition !== "none"
                            onClicked: Config.setNestedValue("background.widgets.mediaControls.visualizerPosition",
                                root.vizPosition === "none" ? (root.vizType === "organic" ? "fill" : "bottom") : "none")
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 4
                        Repeater {
                            model: [
                                { label: Translation.tr("Wave"), icon: "waves", value: "wave" },
                                { label: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                                { label: Translation.tr("Organic"), icon: "bubble_chart", value: "organic" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: index === 0
                                rightmost: index === 2
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: root.vizType === modelData.value
                                onClicked: {
                                    Config.setNestedValue("background.widgets.mediaControls.visualizerType", modelData.value)
                                    if (root.vizPosition === "none")
                                        Config.setNestedValue("background.widgets.mediaControls.visualizerPosition",
                                            modelData.value === "organic" ? "fill" : "bottom")
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 0
                        Repeater {
                            model: [
                                { label: Translation.tr("Cava"), icon: "palette", value: "cava" },
                                { label: Translation.tr("Accent"), icon: "colors", value: "accent" },
                                { label: Translation.tr("Album"), icon: "album", value: "player" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: index === 0
                                rightmost: index === 2
                                horizontalPadding: 8
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: Config.getNestedValue(
                                    "background.widgets.mediaControls.visualizerPaletteMode", "cava") === modelData.value
                                onClicked: Config.setNestedValue(
                                    "background.widgets.mediaControls.visualizerPaletteMode", modelData.value)
                            }
                        }
                    }

                    component MediaVizMetric: ColumnLayout {
                        id: mediaVizMetric
                        required property string labelText
                        required property string configKey
                        required property int minimum
                        required property int maximum
                        property int step: 5
                        property string suffix: "%"
                        readonly property real currentValue: Number(
                            Config.getNestedValue(mediaVizMetric.configKey, mediaVizMetric.minimum))
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText {
                                Layout.fillWidth: true
                                text: mediaVizMetric.labelText
                                color: Appearance.colors.colSubtext
                                font.pixelSize: Appearance.font.pixelSize.smaller
                            }
                            StyledText {
                                text: Math.round(mediaVizMetric.currentValue) + mediaVizMetric.suffix
                                color: Appearance.colors.colOnLayer2
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.family: Appearance.font.family.numbers
                                font.weight: Font.DemiBold
                            }
                        }
                        StyledSlider {
                            Layout.fillWidth: true
                            from: mediaVizMetric.minimum
                            to: mediaVizMetric.maximum
                            stepSize: mediaVizMetric.step
                            configuration: StyledSlider.Configuration.XS
                            stopIndicatorValues: []
                            value: mediaVizMetric.currentValue
                            tooltipContent: Math.round(value) + mediaVizMetric.suffix
                            onMoved: Config.setNestedValue(
                                mediaVizMetric.configKey, Math.round(value))
                        }
                    }

                    RowLayout {
                        visible: root.vizType !== "organic"
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: [
                                { label: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                                { label: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                                { label: Translation.tr("Fill"), icon: "fullscreen", value: "fill" },
                                { label: Translation.tr("Off"), icon: "visibility_off", value: "none" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: index === 0
                                rightmost: index === 3
                                horizontalPadding: 6
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: root.vizPosition === modelData.value
                                onClicked: Config.setNestedValue(
                                    "background.widgets.mediaControls.visualizerPosition", modelData.value)
                            }
                        }
                    }

                    GridLayout {
                        visible: root.vizType !== "organic"
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 16
                        rowSpacing: 4

                        MediaVizMetric {
                            labelText: Translation.tr("Opacity")
                            configKey: "background.widgets.mediaControls.visualizerOpacity"
                            minimum: 5; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Range")
                            configKey: "background.widgets.mediaControls.visualizerRange"
                            minimum: 10; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Smoothing")
                            configKey: "background.widgets.mediaControls.visualizerSmoothing"
                            minimum: 0; maximum: 8; step: 1; suffix: ""
                        }
                        MediaVizMetric {
                            visible: root.vizType === "bars"
                            labelText: Translation.tr("Bars")
                            configKey: "background.widgets.mediaControls.visualizerBarCount"
                            minimum: 8; maximum: 128; step: 4; suffix: ""
                        }
                    }

                    GridLayout {
                        visible: root.vizType !== "organic"
                        Layout.fillWidth: true
                        columns: 3
                        columnSpacing: 4
                        rowSpacing: 4
                        Repeater {
                            model: [
                                { label: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                                { label: Translation.tr("Bass"), icon: "graphic_eq", value: "bass" },
                                { label: Translation.tr("Warm"), icon: "local_fire_department", value: "warm" },
                                { label: Translation.tr("Vocal"), icon: "record_voice_over", value: "vocal" },
                                { label: Translation.tr("Treble"), icon: "trending_up", value: "treble" },
                                { label: Translation.tr("Smile"), icon: "waves", value: "smile" }
                            ]
                            SelectionGroupButton {
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                leftmost: index % 3 === 0
                                rightmost: index % 3 === 2
                                horizontalPadding: 6
                                buttonIcon: modelData.icon
                                buttonText: modelData.label
                                toggled: Config.getNestedValue(
                                    "background.widgets.mediaControls.visualizerFrequencyProfile", "flat") === modelData.value
                                onClicked: Config.setNestedValue(
                                    "background.widgets.mediaControls.visualizerFrequencyProfile", modelData.value)
                            }
                        }
                    }

                    MediaVizMetric {
                        visible: root.vizType !== "organic"
                            && Config.getNestedValue(
                                "background.widgets.mediaControls.visualizerFrequencyProfile", "flat") !== "flat"
                        labelText: Translation.tr("Accent")
                        configKey: "background.widgets.mediaControls.visualizerAccentStrength"
                        minimum: 0; maximum: 100
                    }

                    GridLayout {
                        visible: root.vizType === "organic"
                        Layout.fillWidth: true
                        columns: root.quickControlsWide ? 4
                            : mediaQuickRoot.narrow ? 1 : 2
                        columnSpacing: 16
                        rowSpacing: 4

                        MediaVizMetric {
                            labelText: Translation.tr("Reach")
                            configKey: "background.widgets.mediaControls.organicReach"
                            minimum: 20; maximum: 140
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Pulse")
                            configKey: "background.widgets.mediaControls.organicPulse"
                            minimum: 0; maximum: 150
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Sensitivity")
                            configKey: "background.widgets.mediaControls.organicSensitivity"
                            minimum: 25; maximum: 200
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Compression")
                            configKey: "background.widgets.mediaControls.organicCompression"
                            minimum: 0; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Glow")
                            configKey: "background.widgets.mediaControls.organicGlow"
                            minimum: 0; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Motion")
                            configKey: "background.widgets.mediaControls.organicMotionSpeed"
                            minimum: 20; maximum: 250
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Presence")
                            configKey: "background.widgets.mediaControls.organicOpacity"
                            minimum: 10; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Range")
                            configKey: "background.widgets.mediaControls.organicRange"
                            minimum: 20; maximum: 100
                        }
                        MediaVizMetric {
                            labelText: Translation.tr("Idle")
                            configKey: "background.widgets.mediaControls.organicIdleMotion"
                            minimum: 0; maximum: 100
                        }
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

                MediaOrganicEdgeAura {
                    anchors.fill: parent
                    // Organic lives outside the card as a sibling field. The
                    // player occludes its interior while the field remains visible
                    // beyond the rounded perimeter.
                    z: -1
                    visible: root.vizType === "organic" && root.vizPosition !== "none"
                    visualizerPoints: root.visualizerPoints
                    audioActive: root.visualizerActive
                    // Organic has its own idle motion. Keep the edge field alive
                    // whenever a player exists; audio activity modulates it through
                    // visualizerPoints instead of deciding whether it exists at all.
                    active: root.hasPlayer && root.visible && root.powerActive
                    playerColor: root.widgetAccentVisible
                    albumPalette: root.organicArtworkPalette
                    accentPalette: [root.widgetAccentVisible,
                        root.widgetAccent2Visible, root.widgetAccent3Visible]
                    cardRadius: root.popupRounding
                }

                StyledRectangularShadow {
                    z: -2
                    target: playerLoader
                    radius: root.popupRounding
                    visible: root.vizType !== "organic" || root.vizPosition === "none"
                }

                Loader {
                    id: playerLoader
                    z: 0
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
