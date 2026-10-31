pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.services
import qs
import qs.modules.common.functions
import qs.modules.shared.background.widgets
import qs.modules.shared.background.widgets.instrument
import qs.modules.shared.mediaControls.presets
import qs.modules.shared.mediaControls.components
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "mediaControls"
    designFaceKey: "widgetNowPlaying"

    readonly property var presetGeometry: ({
        "full": { w: 380, h: 150 },
        "compact": { w: 380, h: 122 },
        "minimal": { w: 340, h: 110 },
        "classic": { w: 380, h: 150 },
        "visualizer": { w: 380, h: 164 },
        "albumart": { w: 300, h: 330 },
        "lyrics": { w: 340, h: 400, hBare: 190 },
        "lyricsSplit": { w: 470, h: 268, hBare: 156 },
        "expandingLyrics": { w: 400, h: 128 },
        "instrument": { w: 380, h: 116 }
    })
    readonly property bool instrument: !root.familyFaced && root._readConfigKey("style") === "instrument"
    readonly property var sizedGeometry: root.instrument ? root.presetGeometry["instrument"]
        : root.presetGeometry[root.effectiveSizedPreset] ?? root.presetGeometry["full"]

    readonly property real widgetWidth: root.footprintWidth

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

    readonly property string chosenPreset: Config.getNestedValue("background.widgets.mediaControls.playerPreset", "full")
    // A size class picks the player that fits it: Small the cover tile, Medium the chosen wide player, Large the
    // cover or the lyrics sheet.
    readonly property string selectedPreset: {
        const tall = ["albumart", "lyrics", "lyricsSplit"].includes(root.chosenPreset)
        if (root.sizeClass === "small")
            return "albumart"
        if (root.sizeClass === "large")
            return tall ? root.chosenPreset : "albumart"
        return tall || root.chosenPreset === "expandingLyrics" ? "full" : root.chosenPreset
    }
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

    readonly property bool nativeIrisPlayer: root.familyDesign && ["full", "compact", "minimal", "classic"].includes(root.effectiveRenderedPreset)

    readonly property real widgetHeight: root.footprintHeight

    // The plate a player draws: glass is a tint over the blurred wallpaper, so the words read against that mix.
    readonly property color mediaPlate: root.look.glassOver(root._regionBg)
    // A player draws its own plate; the resting mark sits bare on the wallpaper and reads against it.
    accentBackdrop: root.hasPlayer ? root.mediaPlate
        : root._hasBrightness ? root._regionBg
        : root.look.restBackdrop
    readonly property color mediaSurfaceInk: root.forceLightInk ? root._inkLight
        : root.forceDarkInk ? root._inkDark
        // a title is the scheme's own text (M3 onSurface): the role helper takes the first tone past 4.5, a pale grey
        : ColorUtils.ensureReadable(root.widgetSurfaceRole === "surface" ? Appearance.colors.colOnLayer0
            : root.widgetSemanticForeground(root.widgetSurfaceRole, root.mediaPlate, 4.5), root.mediaPlate, 4.5)
    // the artist and times are body text: a step toward the plate like M3 onSurfaceVariant (two thirds alpha gave 2.7)
    readonly property color mediaSurfaceInkMuted: root.forceLightInk || root.forceDarkInk
        ? ColorUtils.applyAlpha(root.mediaSurfaceInk, 0.72)
        // glass keeps a margin: the cover art under it, a fifth of the mix, is not in the estimate
        : ColorUtils.ensureReadable(ColorUtils.mix(root.mediaSurfaceInk, root.mediaPlate, 0.8), root.mediaPlate,
            root.look.glassPlates ? 6 : 4.5)
    readonly property QtObject _desktopInkOverride: QtObject {
        property color colOnLayer0: root.mediaSurfaceInk
        property color colSubtext: root.mediaSurfaceInkMuted
    }
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
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
        title: MprisController.titleOf(root.meaningfulPlayer) ?? ""
        artist: MprisController.artistOf(root.meaningfulPlayer) ?? ""
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
            readonly property string vizPath: "background.widgets.mediaControls."
            readonly property string profile: Config.getNestedValue(mediaQuickRoot.vizPath + "visualizerFrequencyProfile", "flat")
            spacing: 14

            component VizSlider: WidgetQuickSlider {
                id: vizSlider
                required property string key
                required property int minimum
                required property int maximum
                property int step: 5
                property string suffix: "%"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                from: vizSlider.minimum
                to: vizSlider.maximum
                stepSize: vizSlider.step
                unit: vizSlider.suffix
                value: Number(Config.getNestedValue("background.widgets.mediaControls." + vizSlider.key, vizSlider.minimum))
                onCommitted: v => Config.setNestedValue("background.widgets.mediaControls." + vizSlider.key, Math.round(v))
            }

            WidgetQuickSection {
                title: Translation.tr("Player")
                WidgetQuickChoices {
                    current: root.chosenPreset
                    model: [
                        { label: Translation.tr("Full"), icon: "view_agenda", value: "full" },
                        { label: Translation.tr("Compact"), icon: "view_compact", value: "compact" },
                        { label: Translation.tr("Minimal"), icon: "minimize", value: "minimal" },
                        { label: Translation.tr("Album"), icon: "album", value: "albumart" },
                        { label: Translation.tr("Visualizer"), icon: "graphic_eq", value: "visualizer" },
                        { label: Translation.tr("Classic"), icon: "music_note", value: "classic" },
                        { label: Translation.tr("Lyrics"), icon: "lyrics", value: "lyrics" },
                        { label: Translation.tr("Lyrics wide"), icon: "subtitles", value: "lyricsSplit" },
                        { label: Translation.tr("Cover"), icon: "art_track", value: "expandingLyrics" }
                    ]
                    onPicked: value => Config.setNestedValue(mediaQuickRoot.vizPath + "playerPreset", value)
                }
            }

            WidgetQuickSection {
                title: Translation.tr("Visualizer")
                WidgetQuickToggle {
                    Layout.fillWidth: true
                    iconName: "graphic_eq"
                    label: Translation.tr("Show visualizer")
                    checked: root.vizPosition !== "none"
                    onToggled: Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerPosition",
                        root.vizPosition === "none" ? (root.vizType === "organic" ? "fill" : "bottom") : "none")
                }
                WidgetQuickChoices {
                    current: root.vizType
                    model: [
                        { label: Translation.tr("Wave"), icon: "waves", value: "wave" },
                        { label: Translation.tr("Bars"), icon: "equalizer", value: "bars" },
                        { label: Translation.tr("Organic"), icon: "bubble_chart", value: "organic" }
                    ]
                    onPicked: value => {
                        Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerType", value)
                        if (root.vizPosition === "none")
                            Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerPosition", value === "organic" ? "fill" : "bottom")
                    }
                }
            }

            WidgetQuickSection {
                visible: root.vizPosition !== "none"
                title: Translation.tr("Colour")
                WidgetQuickChoices {
                    current: Config.getNestedValue(mediaQuickRoot.vizPath + "visualizerPaletteMode", "cava")
                    model: [
                        { label: Translation.tr("Cava"), icon: "palette", value: "cava" },
                        { label: Translation.tr("Accent"), icon: "colors", value: "accent" },
                        { label: Translation.tr("Album"), icon: "album", value: "player" }
                    ]
                    onPicked: value => Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerPaletteMode", value)
                }
            }

            WidgetQuickSection {
                visible: root.vizType !== "organic" && root.vizPosition !== "none"
                title: Translation.tr("Placement")
                WidgetQuickChoices {
                    maxColumns: 3
                    current: root.vizPosition
                    model: [
                        { label: Translation.tr("Bottom"), icon: "vertical_align_bottom", value: "bottom" },
                        { label: Translation.tr("Top"), icon: "vertical_align_top", value: "top" },
                        { label: Translation.tr("Fill"), icon: "fullscreen", value: "fill" }
                    ]
                    onPicked: value => Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerPosition", value)
                }
            }

            WidgetQuickSection {
                visible: root.vizType !== "organic" && root.vizPosition !== "none"
                title: Translation.tr("Response")
                WidgetQuickChoices {
                    current: mediaQuickRoot.profile
                    model: [
                        { label: Translation.tr("Flat"), icon: "horizontal_rule", value: "flat" },
                        { label: Translation.tr("Bass"), icon: "graphic_eq", value: "bass" },
                        { label: Translation.tr("Warm"), icon: "local_fire_department", value: "warm" },
                        { label: Translation.tr("Vocal"), icon: "record_voice_over", value: "vocal" },
                        { label: Translation.tr("Treble"), icon: "trending_up", value: "treble" },
                        { label: Translation.tr("Smile"), icon: "waves", value: "smile" }
                    ]
                    onPicked: value => Config.setNestedValue(mediaQuickRoot.vizPath + "visualizerFrequencyProfile", value)
                }
            }

            GridLayout {
                visible: root.vizType !== "organic" && root.vizPosition !== "none"
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 10
                VizSlider { title: Translation.tr("Opacity"); key: "visualizerOpacity"; minimum: 5; maximum: 100 }
                VizSlider { title: Translation.tr("Range"); key: "visualizerRange"; minimum: 10; maximum: 100 }
                VizSlider { title: Translation.tr("Smoothing"); key: "visualizerSmoothing"; minimum: 0; maximum: 8; step: 1; suffix: "" }
                VizSlider { visible: root.vizType === "bars"; title: Translation.tr("Bars"); key: "visualizerBarCount"; minimum: 8; maximum: 128; step: 4; suffix: "" }
                VizSlider { visible: mediaQuickRoot.profile !== "flat"; title: Translation.tr("Accent"); key: "visualizerAccentStrength"; minimum: 0; maximum: 100 }
            }

            GridLayout {
                visible: root.vizType === "organic" && root.vizPosition !== "none"
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 16
                rowSpacing: 10
                VizSlider { title: Translation.tr("Reach"); key: "organicReach"; minimum: 20; maximum: 140 }
                VizSlider { title: Translation.tr("Pulse"); key: "organicPulse"; minimum: 0; maximum: 150 }
                VizSlider { title: Translation.tr("Sensitivity"); key: "organicSensitivity"; minimum: 25; maximum: 200 }
                VizSlider { title: Translation.tr("Compression"); key: "organicCompression"; minimum: 0; maximum: 100 }
                VizSlider { title: Translation.tr("Glow"); key: "organicGlow"; minimum: 0; maximum: 100 }
                VizSlider { title: Translation.tr("Motion"); key: "organicMotionSpeed"; minimum: 20; maximum: 250 }
                VizSlider { title: Translation.tr("Presence"); key: "organicOpacity"; minimum: 10; maximum: 100 }
                VizSlider { title: Translation.tr("Range"); key: "organicRange"; minimum: 20; maximum: 100 }
                VizSlider { title: Translation.tr("Idle"); key: "organicIdleMotion"; minimum: 0; maximum: 100 }
            }
        }
    }

    // What plays is kept so the widget at rest shows the song that played last (the iRiS face keeps it itself).
    PlayerBase {
        id: rememberBase
        player: root.familyFaced ? null : root.meaningfulPlayer
        positionUpdatesActive: false
        readonly property string key: root.familyFaced || !rememberBase.effectiveIsPlaying ? ""
            : [rememberBase.effectiveTitle, rememberBase.effectiveArtist, rememberBase.displayedArtFilePath].join("\u0001")
        onKeyChanged: {
            if (rememberBase.key.length === 0 || rememberBase.effectiveTitle.length === 0) return
            const last = Persistent.states.lastPlayed
            const identity = String(root.meaningfulPlayer?.identity || String(root.meaningfulPlayer?.desktopEntry ?? "").split(".").pop() || "")
            last.title = rememberBase.effectiveTitle
            last.artist = rememberBase.effectiveArtist
            last.source = identity.length > 0 ? identity.charAt(0).toUpperCase() + identity.slice(1) : ""
            last.art = rememberBase.displayedArtFilePath
            last.entry = String(root.meaningfulPlayer?.desktopEntry ?? "")
            last.at = Date.now()
        }
        onEffectiveIsPlayingChanged: if (!root.familyFaced && !rememberBase.effectiveIsPlaying
                && Persistent.states.lastPlayed.title === rememberBase.effectiveTitle) Persistent.states.lastPlayed.at = Date.now()
    }
    readonly property MprisPlayer meaningfulPlayer: MprisController.activePlayer
    readonly property var meaningfulPlayers: root.meaningfulPlayer
        ? [root.meaningfulPlayer] : []
    readonly property bool hasPlayer: root.meaningfulPlayers.length > 0
    familyOptions: [
        { key: "lyrics", label: Translation.tr("Synced lyrics"), icon: "lyrics", fallback: true },
        { key: "rest", label: Translation.tr("Rest when paused"), icon: "bedtime", fallback: false }
    ]
    readonly property real placeholderWidth: Math.round(
        (root.instrument ? 220 : 96) * Appearance.fontSizeScale * scaleFactor)
    readonly property real placeholderHeight: Math.round(
        (root.instrument ? 56 : 96) * Appearance.fontSizeScale * scaleFactor)

    // This instance only exists when its effective output-local enable state is
    // true. Rechecking the global base would incorrectly disable Cava for a
    // widget enabled only on this monitor.
    // Frozen (covered, paused for power) the field shows its last frame: nothing reads the audio then.
    readonly property bool visualizerActive: !root.familyFaced && !root.instrument && root.vizPosition !== "none"
        && root.visible && root.motionActive && MprisController.isPlaying

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
        id: familyPlayerComponent
        FamilyPart {
            property var player: null
            part: "mediaCard"
            props: ({ compact: ["compact", "minimal"].includes(root.effectiveRenderedPreset), active: root.visible && root.powerActive,
                showBackground: false, player: player })
        }
    }

    Component {
        id: instrumentPlayerComponent
        InstrumentPlayer { widget: root }
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

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            ColumnLayout {
                id: playerColumnLayout
                anchors.fill: parent
                visible: !root.familyFaced
                spacing: -Appearance.sizes.elevationMargin

                Repeater {
                    model: ScriptModel {
                        values: root.familyFaced ? [] : root.meaningfulPlayers
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
                            visible: !root.instrument && root.vizType === "organic" && root.vizPosition !== "none"
                            visualizerPoints: root.visualizerPoints
                            audioActive: root.visualizerActive
                            // Organic has its own idle motion. Keep the edge field alive
                            // whenever a player exists; audio activity modulates it through
                            // visualizerPoints instead of deciding whether it exists at all.
                            active: root.hasPlayer && root.visible && root.powerActive
                            animate: root.motionActive
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
                            visible: !root.familyDesign && !root.instrument && (root.vizType !== "organic" || root.vizPosition === "none")
                        }

                        Loader {
                            id: playerLoader
                            z: 0
                            anchors.fill: parent
                            active: root.presetLoaderActive
                            sourceComponent: root.instrument ? instrumentPlayerComponent
                                : root.nativeIrisPlayer ? familyPlayerComponent : root.presetComponent

                            onLoaded: {
                                item.player = delegateRoot.modelData
                                if (root.instrument)
                                    return
                                if (!root.nativeIrisPlayer) {
                                    item.blendedColors = root._desktopInkOverride
                                    item.themeSourceColor = Qt.binding(() => root.widgetAccentVisible)
                                    item.visualizerPoints = Qt.binding(() => root.visualizerPoints)
                                    item.radius = root.popupRounding
                                    item.screenX = Qt.binding(() => root.widgetScreenPos.x)
                                    item.screenY = Qt.binding(() => root.widgetScreenPos.y)
                                    item.motion = Qt.binding(() => root.motionActive)
                                }
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

                    RowLayout {
                        visible: root.instrument
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * root.scaleFactor)
                        spacing: Math.round(10 * root.scaleFactor)
                        InstrumentBrackets {
                            Layout.preferredWidth: Math.round(34 * root.scaleFactor)
                            Layout.preferredHeight: Layout.preferredWidth
                            color: root.widgetAccentVisible
                            length: Math.round(9 * root.scaleFactor)
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "music_note"
                                iconSize: Math.round(18 * root.scaleFactor)
                                color: root.widgetInkMuted
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            InstrumentLabel { Layout.fillWidth: true; text: Translation.tr("Transport / Idle"); color: root.widgetAccentVisible; scaleFactor: root.scaleFactor; strong: true }
                            StyledText { Layout.fillWidth: true; text: Translation.tr("Nothing playing"); color: root.widgetInk; elide: Text.ElideRight; font.family: root.widgetTitleFamily; font.pixelSize: Math.round(15 * root.scaleFactor); font.weight: Font.DemiBold }
                        }
                    }
                    FamilyPart {
                        anchors.centerIn: parent
                        when: root.familyDesign
                        part: "artwork"
                        width: Math.min(parent.width, parent.height) * 0.6
                        height: width
                    }
                    // At rest there is no player to draw the card: the rest wears the widget's own plate, so its words
                    // aren't left on the wallpaper and Background and Outline have something to change.
                    WidgetSurface {
                        widget: root
                        anchors.fill: parent
                        shown: !root.familyFaced
                        surfaceColor: root.widgetInk
                    }
                    MediaRest {
                        id: materialRest
                        anchors.fill: parent
                        visible: !root.instrument && materialRest.known
                        widget: root
                    }
                    WidgetBlank {
                        anchors.fill: parent
                        visible: !root.instrument && !materialRest.known
                        widget: root
                        icon: "music_note"
                        title: Translation.tr("Nothing playing")
                    }
                }
            }
        }
    }
}
