pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Singleton {
    id: root

    readonly property bool enabled: Config.options?.appearance?.wallpaperTheming?.enableCava ?? false
    readonly property string colorSource: Config.options?.appearance?.cava?.colorSource ?? "theme"
    readonly property bool useCoverSource: root.colorSource === "cover"
    readonly property int gradientCount: Math.max(1,
        Math.min(8, Config.options?.appearance?.cava?.gradientCount ?? 8))

    function _clamp01(value): real {
        return Math.max(0, Math.min(1, value))
    }

    function _visualColor(value, fallback, saturationFloor, saturationBoost, hueShift): color {
        let source = Qt.color(value)
        const fallbackColor = Qt.color(fallback)
        if (!source.valid)
            source = fallbackColor

        let hue = source.hslHue
        if (!(hue >= 0))
            hue = fallbackColor.hslHue >= 0 ? fallbackColor.hslHue : 0
        hue = (hue + hueShift / 360 + 1) % 1

        const saturation = root._clamp01(Math.max(saturationFloor,
            source.hslSaturation * saturationBoost))
        const minimumLightness = Appearance.m3colors.darkmode ? 0.46 : 0.28
        const maximumLightness = Appearance.m3colors.darkmode ? 0.72 : 0.58
        const lightness = Math.max(minimumLightness,
            Math.min(maximumLightness, source.hslLightness))
        return Qt.hsla(hue, saturation, lightness, 1)
    }

    function _mixColor(first, second, amount): color {
        const a = Qt.color(first)
        const b = Qt.color(second)
        const t = root._clamp01(amount)
        return Qt.rgba(
            a.r + (b.r - a.r) * t,
            a.g + (b.g - a.g) * t,
            a.b + (b.b - a.b) * t,
            1)
    }

    function _resamplePalette(source, count): var {
        const palette = []
        for (let i = 0; i < source.length; ++i) {
            const color = Qt.color(source[i])
            if (color.valid)
                palette.push(color)
        }
        if (palette.length === 0)
            palette.push(Qt.color(Appearance.colors.colPrimary))

        const output = []
        const targetCount = Math.max(1, Math.min(8, count))
        if (targetCount === 1)
            return [palette[Math.floor(palette.length / 2)]]
        for (let i = 0; i < targetCount; ++i) {
            const position = i * (palette.length - 1) / Math.max(1, targetCount - 1)
            const lower = Math.floor(position)
            const upper = Math.min(palette.length - 1, lower + 1)
            output.push(root._mixColor(palette[lower], palette[upper], position - lower))
        }
        return output
    }

    readonly property var themeColors: [
        root._visualColor(Appearance.colors.colSecondary,
            Appearance.colors.colPrimary, 0.28, 1.08, 0),
        root._visualColor(Appearance.colors.colPrimary,
            Appearance.colors.colPrimary, 0.34, 1.12, 0),
        root._visualColor(Appearance.colors.colTertiary,
            Appearance.colors.colPrimary, 0.30, 1.10, 0),
    ]

    // Vibrant is not merely a brighter primary. It deliberately widens hue
    // separation so the selected source is obvious even on a small bar.
    readonly property var vibrantColors: [
        root._visualColor(Appearance.colors.colSecondary,
            Appearance.colors.colPrimary, 0.82, 1.9, -18),
        root._visualColor(Appearance.colors.colPrimary,
            Appearance.colors.colPrimary, 0.88, 2.0, 0),
        root._visualColor(Appearance.colors.colTertiary,
            Appearance.colors.colPrimary, 0.82, 1.9, 22),
        root._visualColor(Appearance.colors.colPrimary,
            Appearance.colors.colPrimary, 0.84, 2.0, 48),
    ]

    readonly property string coverSourceUrl: {
        if (MprisController.isYtMusicActive && YtMusic.currentVideoId)
            return YtMusic.currentThumbnail ?? ""
        return MprisController.activePlayer?.trackArtUrl ?? ""
    }

    readonly property string coverTitle: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? YtMusic.currentTitle
        : (MprisController.activePlayer?.trackTitle ?? "")

    readonly property string coverArtist: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? YtMusic.currentArtist
        : (MprisController.activePlayer?.trackArtist ?? "")

    readonly property string coverAlbum: MprisController.isYtMusicActive && YtMusic.currentVideoId
        ? ""
        : (MprisController.activePlayer?.trackAlbum ?? "")

    MediaArtworkResolver {
        id: coverArt
        sourceUrl: root.coverSourceUrl
        title: root.coverTitle
        artist: root.coverArtist
        album: root.coverAlbum
        cacheDirectory: Directories.coverArt

        onReadyChanged: if (coverArt.ready) root._scheduleCoverRefresh()
    }

    ColorQuantizer {
        id: coverQuantizer
        source: root.useCoverSource && coverArt.ready ? coverArt.displaySource : ""
        depth: 2
        rescaleSize: 64
    }

    readonly property bool coverPaletteAvailable: root.useCoverSource
        && coverArt.ready
        && (coverQuantizer?.colors?.length ?? 0) > 0

    readonly property var coverColors: {
        const raw = coverQuantizer?.colors ?? []
        if (!root.coverPaletteAvailable)
            return root.themeColors

        const palette = []
        const maximum = Math.min(4, raw.length)
        for (let i = 0; i < maximum; ++i) {
            palette.push(root._visualColor(raw[i],
                root.themeColors[i % root.themeColors.length], 0.46, 1.35, 0))
        }
        while (palette.length < 3)
            palette.push(root.themeColors[palette.length % root.themeColors.length])
        return palette
    }

    readonly property var sourceColors: root.colorSource === "vibrant"
        ? root.vibrantColors
        : root.colorSource === "cover"
            ? root.coverColors
            : root.themeColors
    readonly property var visualizerColors: root._resamplePalette(
        root.sourceColors, root.gradientCount)
    readonly property color primaryColor: root.visualizerColors.length > 0
        ? root.visualizerColors[Math.floor(root.visualizerColors.length / 2)]
        : Appearance.colors.colPrimary

    Timer {
        id: coverRefreshDebounce
        interval: 450
        repeat: false
        onTriggered: root._applyCoverTheme()
    }

    function _scheduleCoverRefresh(): void {
        if (!root.enabled || !root.useCoverSource) return
        coverRefreshDebounce.restart()
    }

    function _applyCoverTheme(): void {
        if (!root.enabled || !root.useCoverSource) return
        if (!coverArt.ready) return

        const path = FileUtils.trimFileProtocol(coverArt.displaySource)
        if (!path || path.length === 0) return

        Quickshell.execDetached([
            "/usr/bin/bash",
            Directories.scriptsPath + "/cava/apply_cover_theme.sh",
            path,
        ])
    }

    onEnabledChanged: root._scheduleCoverRefresh()
    onUseCoverSourceChanged: root._scheduleCoverRefresh()

    Connections {
        target: MprisController
        function onTrackChanged(): void {
            root._scheduleCoverRefresh()
        }
    }
}
