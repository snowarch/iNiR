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

// The colours of the wallpaper or the song's cover (or five random ones), read by ColorQuantizer in iRiS,
// and in Material: three expressive views of the active Material 3 scheme ("swatches", "ramp", "scheme").
AbstractBackgroundWidget {
    id: root

    configEntryName: "palette"
    needsColText: true
    resizeMinWidth: 220
    resizeMinHeight: 150
    familyOptions: [
        { key: "source", label: Translation.tr("Colors from"), icon: "palette", fallback: "wallpaper", choices: [
            { value: "wallpaper", label: Translation.tr("Wallpaper"), icon: "wallpaper" },
            { value: "music", label: Translation.tr("Music"), icon: "album" },
            { value: "random", label: Translation.tr("Random"), icon: "shuffle" }
        ] }
    ]

    readonly property string paletteStyle: String(root._readConfigKey("style") ?? "swatches")
    readonly property bool showHex: Boolean(root._readConfigKey("showHex") ?? true)
    readonly property string colourSource: String(root.familyOption("source", "wallpaper"))
    readonly property string coverUrl: MprisController.activePlayer
        ? MprisController.effectiveArtUrl(MprisController.activePlayer) : ""

    MediaArtworkResolver {
        id: coverResolver
        sourceUrl: root.colourSource === "music" ? root.coverUrl : ""
        title: MprisController.titleOf(MprisController.activePlayer) ?? ""
        artist: MprisController.artistOf(MprisController.activePlayer) ?? ""
        album: MprisController.activePlayer?.trackAlbum ?? ""
        cacheDirectory: Directories.coverArt
    }

    readonly property bool readingMusic: root.colourSource === "music" && coverResolver.displaySource.length > 0
    readonly property string imageSource: root.colourSource === "random" ? ""
        : root.readingMusic ? coverResolver.displaySource
        : Wallpapers.effectiveWallpaperUrl
    readonly property string from: root.colourSource === "random" || root.shuffled.length === 5 ? "random"
        : root.readingMusic ? "music" : "wallpaper"

    ColorQuantizer {
        id: quantizer
        source: root.visible && root.powerActive ? root.imageSource : ""
        depth: 3
        rescaleSize: 64
    }

    property var shuffled: []
    property var kept: ["", "", "", "", ""]
    onImageSourceChanged: root.shuffled = []

    function _hex(c: var): string {
        const q = Qt.color(c)
        const b = v => Math.max(0, Math.min(255, Math.round(v * 255))).toString(16).padStart(2, "0")
        return "#" + b(q.r) + b(q.g) + b(q.b)
    }

    readonly property var fallback: [
        root._hex(Appearance.m3colors.m3background),
        root._hex(Appearance.m3colors.m3secondaryContainer),
        root._hex(Appearance.m3colors.m3primary),
        root._hex(Appearance.m3colors.m3tertiary),
        root._hex(Appearance.m3colors.m3onSurface)
    ]

    readonly property var read: {
        const raw = quantizer.colors ?? []
        if (raw.length < 5)
            return root.fallback
        const seen = []
        for (const c of raw) {
            const h = root._hex(c)
            if (!seen.includes(h)) seen.push(h)
        }
        seen.sort((a, b) => ColorUtils.relativeLuminance(a) - ColorUtils.relativeLuminance(b))
        if (seen.length <= 5) {
            while (seen.length < 5) seen.push(root.fallback[seen.length])
            return seen
        }
        const out = []
        for (let i = 0; i < 5; i++)
            out.push(seen[Math.round(i * (seen.length - 1) / 4)])
        return out
    }

    readonly property var colours: {
        const base = root.shuffled.length === 5 ? root.shuffled : root.read
        return base.map((c, i) => root.kept[i] ? root.kept[i] : c)
    }

    function shuffle(): void {
        const h0 = Math.random()
        const step = 0.14 + Math.random() * 0.12
        const next = []
        for (let i = 0; i < 5; i++) {
            const h = (h0 + (i - 2) * step + 1) % 1
            const s = 0.45 + Math.random() * 0.35
            const l = 0.18 + i * 0.16 + (Math.random() - 0.5) * 0.05
            next.push(root._hex(Qt.hsla(h, s, Math.max(0.12, Math.min(0.88, l)), 1)))
        }
        root.shuffled = next
    }

    onColourSourceChanged: if (root.colourSource === "random" && root.shuffled.length < 5) root.shuffle()
    Component.onCompleted: if (root.colourSource === "random") root.shuffle()

    function keep(index: int): void {
        const next = root.kept.slice()
        next[index] = next[index] ? "" : root.colours[index]
        root.kept = next
    }

    property string copiedHex: ""
    Timer {
        id: copiedClearTimer
        interval: 1600
        onTriggered: root.copiedHex = ""
    }

    function copy(value: var): void {
        const hex = root._hex(value)
        Quickshell.clipboardText = hex
        root.copiedHex = hex
        copiedClearTimer.restart()
    }

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
                            ? Translation.tr("Copied") + " " + root.copiedHex.toUpperCase()
                            : root.themeTitle
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
                                    text: root._hex(swCell.modelData.color).toUpperCase()
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
                                onClicked: root.copy(swCell.modelData.color)
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
                                onClicked: root.copy(stopRect.stopColor)
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
                                        onClicked: root.copy(famBar.barColor)
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
