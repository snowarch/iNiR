pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// Material draws three expressive views of the active Material 3 scheme ("swatches", "ramp", "scheme"); it
// never reads the wallpaper. iRiS and Prism draw their own faces: five colours read from the wallpaper, the
// cover that plays or a harmony. A tap copies one, a right click keeps it through the next read. Looking never
// touches the theme.
AbstractBackgroundWidget {
    id: root

    configEntryName: "palette"
    needsColText: !root.familyFaced
    resizeMinWidth: 220
    resizeMinHeight: 150
    familyOptions: [
        { key: "source", label: Translation.tr("Colours from"), icon: "palette", fallback: "wallpaper", choices: [
            { value: "wallpaper", label: Translation.tr("Wallpaper"), icon: "wallpaper" },
            { value: "music", label: Translation.tr("Music"), icon: "album" },
            { value: "random", label: Translation.tr("Random"), icon: "shuffle" }
        ] }
    ]

    readonly property string paletteStyle: String(root._readConfigKey("style") ?? "swatches")
    readonly property bool showHex: Boolean(root._readConfigKey("showHex") ?? true)
    readonly property string colourSource: String(root.familyOption("source", "wallpaper"))
    readonly property var kept: Array.from(root.familyOption("kept", []) ?? [])
    readonly property var drawn: Array.from(root.familyOption("drawn", []) ?? [])
    readonly property var player: MprisController.activePlayer
    // Music with nothing playing reads the wallpaper and says so.
    readonly property bool coverRead: root.colourSource === "music" && artwork.displaySource.length > 0
    readonly property string from: root.colourSource === "random" ? "random" : root.coverRead ? "music" : "wallpaper"
    readonly property var screen: Quickshell.screens.find(entry => entry.name === root.outputName) ?? null
    readonly property string wallpaperStill: Wallpapers.stillUrlFor(WallpaperListener.wallpaperUrlForScreen(root.screen))

    MediaArtworkResolver {
        id: artwork
        sourceUrl: root.familyFaced && root.colourSource === "music" && root.player ? MprisController.effectiveArtUrl(root.player) : ""
        title: MprisController.titleOf(root.player) ?? ""
        artist: MprisController.artistOf(root.player) ?? ""
        album: root.player?.trackAlbum ?? ""
    }
    // Only a family face shows read colours; the Material styles show scheme roles and decode nothing.
    ColorQuantizer {
        id: quant
        source: !root.familyFaced ? "" : root.from === "music" ? artwork.displaySource : root.from === "wallpaper" ? root.wallpaperStill : ""
        depth: 3
        rescaleSize: 96
    }

    function hex(c: color): string {
        const part = value => Math.round(Math.max(0, Math.min(1, value)) * 255).toString(16).padStart(2, "0")
        return ("#" + part(c.r) + part(c.g) + part(c.b)).toUpperCase()
    }
    // Five that stand apart: the most telling colour first, then each one farthest from those taken,
    // laid dark to light. A picture with fewer than five gives tints of what it has.
    function pickFive(list: var): var {
        const pool = Array.from(list ?? []).map(entry => Qt.color(entry))
        if (pool.length === 0) return []
        const hue = c => c.hslHue < 0 ? 0 : c.hslHue
        const gap = (a, b) => {
            const dh = Math.min(Math.abs(hue(a) - hue(b)), 1 - Math.abs(hue(a) - hue(b)))
            return Math.hypot(dh * 2 * Math.min(a.hslSaturation, b.hslSaturation), a.hslLightness - b.hslLightness,
                (a.hslSaturation - b.hslSaturation) * 0.5)
        }
        const telling = c => c.hslSaturation * (1 - Math.abs(c.hslLightness - 0.5) * 1.4)
        const taken = [pool.reduce((best, c) => telling(c) > telling(best) ? c : best, pool[0])]
        while (taken.length < Math.min(5, pool.length)) {
            let far = null, farGap = -1
            for (const c of pool) {
                if (taken.includes(c)) continue
                const near = Math.min(...taken.map(t => gap(c, t)))
                if (near > farGap) { far = c; farGap = near }
            }
            taken.push(far)
        }
        for (let i = 0; taken.length < 5; i++) {
            const base = taken[i % taken.length]
            taken.push(Qt.hsla(hue(base), base.hslSaturation, Math.min(0.9, base.hslLightness + 0.18 * (1 + Math.floor(i / taken.length))), 1))
        }
        return taken.sort((a, b) => a.hslLightness - b.hslLightness).map(c => root.hex(c))
    }
    function harmony(): var {
        const base = Math.random()
        const shapes = [[0, 0.04, 0.5, 0.54, 0.08], [0, 0.33, 0.66, 0.05, 0.38], [0, 0.08, 0.16, 0.58, 0.5], [0, 0.42, 0.58, 0.02, 0.5]]
        const shape = shapes[Math.floor(Math.random() * shapes.length)]
        const light = [0.22, 0.38, 0.52, 0.66, 0.82]
        return shape.map((offset, i) => root.hex(Qt.hsla((base + offset) % 1, 0.42 + Math.random() * 0.38, light[i], 1)))
    }
    readonly property var read: root.from === "random" ? root.drawn : root.pickFive(quant.colors)
    readonly property var colours: [0, 1, 2, 3, 4].map(i => String(root.kept[i] || root.read[i] || ""))
    readonly property bool ready: root.colours.every(entry => entry.length > 0)

    function shuffle(): void {
        root.setFamilyOptions({ "source": "random", "drawn": root.harmony() })
    }
    function keep(index: int): void {
        const next = [0, 1, 2, 3, 4].map(i => String(root.kept[i] ?? ""))
        next[index] = next[index].length > 0 ? "" : root.colours[index]
        root.setFamilyOption("kept", next)
    }
    // Copies what it is given, as given.
    function copy(text: string): void {
        Quickshell.clipboardText = text
    }
    // The Material face copies one colour as hex and says so in its header for a moment.
    property string copiedHex: ""
    Timer {
        id: copiedClearTimer
        interval: 1600
        onTriggered: root.copiedHex = ""
    }
    function copyColour(value: color): void {
        const text = root.hex(value)
        root.copy(text)
        root.copiedHex = text
        copiedClearTimer.restart()
    }
    // A first turn to Random deals a hand; written after the change settles, never inside it.
    onColourSourceChanged: if (root.colourSource === "random" && root.drawn.length < 5)
        Qt.callLater(() => root.setFamilyOption("drawn", root.harmony()))

    // Material roles for "swatches" and "scheme"
    readonly property var materialRoles: [
        { name: Translation.tr("Primary"), color: Appearance.colors.colPrimary, on: Appearance.colors.colOnPrimary, shape: MaterialShape.Shape.Cookie9Sided },
        { name: Translation.tr("Secondary"), color: Appearance.colors.colSecondaryContainer, on: Appearance.colors.colOnSecondaryContainer, shape: MaterialShape.Shape.Clover4Leaf },
        { name: Translation.tr("Tertiary"), color: Appearance.colors.colTertiaryContainer, on: Appearance.colors.colOnTertiaryContainer, shape: MaterialShape.Shape.Sunny },
        { name: Translation.tr("Container"), color: Appearance.colors.colPrimaryContainer, on: Appearance.colors.colOnPrimaryContainer, shape: MaterialShape.Shape.Pentagon },
        { name: Translation.tr("Surface"), color: Appearance.colors.colSurfaceContainerHigh, on: Appearance.colors.colOnSurface, shape: MaterialShape.Shape.Square },
        { name: Translation.tr("Error"), color: Appearance.colors.colError, on: Appearance.colors.colOnError, shape: MaterialShape.Shape.Gem }
    ]
    readonly property var rampTones: [95, 90, 80, 70, 60, 50, 40, 30, 20, 10]
    readonly property var schemeFamilies: [
        { name: Translation.tr("Primary"), seed: Appearance.colors.colPrimary },
        { name: Translation.tr("Secondary"), seed: Appearance.colors.colSecondary },
        { name: Translation.tr("Tertiary"), seed: Appearance.colors.colTertiary },
        { name: Translation.tr("Error"), seed: Appearance.colors.colError }
    ]

    readonly property string themeTitle: {
        const t = String(Config.options?.appearance?.theme ?? "auto")
        if (t === "auto") return Translation.tr("Wallpaper palette")
        return t.charAt(0).toUpperCase() + t.slice(1).replace(/-/g, " ")
    }

    Loader {
        anchors.fill: parent
        active: !root.familyFaced
        sourceComponent: Item {
            id: materialFace

            WidgetSurface {
                widget: root
                anchors.fill: parent
                shown: !root.familyFaced
                surfaceColor: root.widgetInk
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Math.round(14 * root.scaleFactor)
                spacing: Math.round(8 * root.scaleFactor)

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(8 * root.scaleFactor)

                    MaterialSymbol {
                        text: root.copiedHex !== "" ? "content_copy" : "palette"
                        fill: 1
                        iconSize: Math.round(18 * root.scaleFactor)
                        color: root.widgetAccentVisible
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: root.copiedHex !== ""
                            ? Translation.tr("Copied") + " " + root.copiedHex
                            : root.isSmall ? Translation.tr("Palette") : root.themeTitle
                        color: root.widgetInk
                        font.family: root.widgetTitleFamily
                        font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                        font.weight: Font.DemiBold
                    }
                }

                // 1. "swatches": 6 expressive shapes in a 3x2 grid, click to copy hex
                GridLayout {
                    id: swatchesGrid
                    visible: root.paletteStyle === "swatches"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    columnSpacing: Math.round(4 * root.scaleFactor)
                    rowSpacing: Math.round(4 * root.scaleFactor)

                    Repeater {
                        model: root.paletteStyle === "swatches" ? root.materialRoles : []

                        Item {
                            id: swCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 1

                            readonly property real shapeDiameter: Math.max(24, Math.min(
                                width - Math.round(10 * root.scaleFactor),
                                height - Math.round((root.showHex && !root.isSmall ? 28 : 16) * root.scaleFactor)))

                            MaterialShape {
                                id: swShape
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Math.max(0, Math.round((parent.height - height - swLabels.implicitHeight - Math.round(2 * root.scaleFactor)) / 2))
                                implicitSize: swCell.shapeDiameter
                                shape: swCell.modelData.shape
                                color: swCell.modelData.color
                                rotation: swTap.containsMouse ? 20 : 0
                                scale: swTap.pressed ? 0.90 : 1.0

                                Behavior on rotation {
                                    enabled: root.animationsActive
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMove.duration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                                    }
                                }
                                Behavior on scale {
                                    enabled: root.animationsActive
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                        easing.type: Easing.BezierSpline
                                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                                    }
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    rotation: -swShape.rotation
                                    text: "Aa"
                                    color: swCell.modelData.on
                                    font.family: root.widgetTitleFamily
                                    font.pixelSize: Math.max(9, Math.round(swCell.shapeDiameter * 0.28))
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                id: swLabels
                                anchors.top: swShape.bottom
                                anchors.topMargin: Math.round(2 * root.scaleFactor)
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: -Math.round(1 * root.scaleFactor)

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: swCell.modelData.name
                                    color: root.widgetInk
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.round(10 * root.scaleFactor)
                                    font.weight: Font.Medium
                                }

                                StyledText {
                                    visible: root.showHex && !root.isSmall
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.hex(swCell.modelData.color)
                                    color: root.widgetInkMuted
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.round(9 * root.scaleFactor)
                                    font.features: ({ "tnum": 1 })
                                }
                            }

                            MouseArea {
                                id: swTap
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyColour(swCell.modelData.color)
                            }
                        }
                    }
                }

                // 2. "ramp": tonal scale 95..10 of the primary accent
                Row {
                    id: rampRow
                    visible: root.paletteStyle === "ramp"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(3 * root.scaleFactor)

                    Repeater {
                        model: root.paletteStyle === "ramp" ? root.rampTones : []

                        Rectangle {
                            id: stopRect
                            required property int modelData
                            required property int index
                            readonly property color stopColor: ColorUtils.atTone(Appearance.colors.colPrimary, stopRect.modelData)
                            readonly property bool hot: stopTap.containsMouse
                            readonly property real endRad: Math.round(14 * root.scaleFactor)
                            readonly property real midRad: Math.round(4 * root.scaleFactor)

                            width: Math.max(6, (rampRow.width - rampRow.spacing * (root.rampTones.length - 1)) / root.rampTones.length)
                            height: rampRow.height
                            topLeftRadius: stopRect.index === 0 ? endRad : midRad
                            bottomLeftRadius: stopRect.index === 0 ? endRad : midRad
                            topRightRadius: stopRect.index === root.rampTones.length - 1 ? endRad : midRad
                            bottomRightRadius: stopRect.index === root.rampTones.length - 1 ? endRad : midRad
                            color: stopRect.stopColor
                            scale: stopRect.hot ? 1.06 : 1.0
                            z: stopRect.hot ? 1 : 0

                            Behavior on scale {
                                enabled: root.animationsActive
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                                }
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: Math.round(6 * root.scaleFactor)
                                text: String(stopRect.modelData)
                                color: stopRect.modelData > 55 ? Qt.rgba(0, 0, 0, 0.72) : Qt.rgba(1, 1, 1, 0.82)
                                font.family: root.widgetNumbersFamily
                                font.pixelSize: Math.round(9.5 * root.scaleFactor)
                                font.weight: Font.DemiBold
                                font.features: ({ "tnum": 1 })
                            }

                            MouseArea {
                                id: stopTap
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyColour(stopRect.stopColor)
                            }
                        }
                    }
                }

                // 3. "scheme": 4 key color families, each a column of 5 chromatic tones
                Row {
                    id: schemeRow
                    visible: root.paletteStyle === "scheme"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(6 * root.scaleFactor)

                    Repeater {
                        model: root.paletteStyle === "scheme" ? root.schemeFamilies : []

                        Column {
                            id: famCol
                            required property var modelData
                            readonly property var steps: [75, 62, 50, 38, 28]
                            readonly property real labelH: famLabel.implicitHeight + Math.round(4 * root.scaleFactor)
                            readonly property real barH: Math.max(8, (schemeRow.height - labelH - spacing * 4) / 5)

                            width: Math.max(16, (schemeRow.width - schemeRow.spacing * 3) / 4)
                            spacing: Math.round(2 * root.scaleFactor)

                            Repeater {
                                model: famCol.steps

                                Rectangle {
                                    id: famBar
                                    required property int modelData
                                    required property int index
                                    readonly property color barColor: ColorUtils.atTone(famCol.modelData.seed, famBar.modelData)
                                    readonly property real endRad: Math.round(11 * root.scaleFactor)
                                    readonly property real midRad: Math.round(3 * root.scaleFactor)

                                    width: famCol.width
                                    height: famCol.barH
                                    topLeftRadius: famBar.index === 0 ? endRad : midRad
                                    topRightRadius: famBar.index === 0 ? endRad : midRad
                                    bottomLeftRadius: famBar.index === famCol.steps.length - 1 ? endRad : midRad
                                    bottomRightRadius: famBar.index === famCol.steps.length - 1 ? endRad : midRad
                                    color: famBar.barColor
                                    scale: famTap.containsMouse ? 1.04 : 1.0
                                    z: famTap.containsMouse ? 1 : 0

                                    Behavior on scale {
                                        enabled: root.animationsActive
                                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                    }

                                    MouseArea {
                                        id: famTap
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyColour(famBar.barColor)
                                    }
                                }
                            }

                            StyledText {
                                id: famLabel
                                width: famCol.width
                                topPadding: Math.round(2 * root.scaleFactor)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: famCol.modelData.name
                                color: root.widgetInkMuted
                                font.family: root.widgetBodyFamily
                                font.pixelSize: Math.round(10 * root.scaleFactor)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
