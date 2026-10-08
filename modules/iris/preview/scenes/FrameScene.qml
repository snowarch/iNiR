pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.services
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.field as Field
import qs.modules.iris.preview.parts

PreviewScene {
    id: framePreview
    readonly property real naturalWidth: Math.round(540 * framePreview.d)
    readonly property real naturalHeight: Math.round(280 * framePreview.d)
    readonly property bool wave: framePreview.section === "frameMusic" && framePreview.opt("background.edgeWidgets.organic.enable", false) && String(framePreview.opt("iris.surround.music", "widget")) === "widget"
    readonly property bool music: framePreview.section === "frameMusic"
        && framePreview.opt("background.edgeWidgets.organic.enable", false)
        && String(framePreview.opt("iris.surround.music", "widget")) === "frame"
    property real phase: 0
    readonly property real strength: Number(framePreview.opt("iris.surround.musicStrength", 160)) / 100
    readonly property real sensitivity: Number(framePreview.opt("iris.surround.musicSensitivity", 140)) / 100
    readonly property string edges: String(framePreview.opt("iris.surround.musicEdges", "sides"))
    Timer {
        interval: 50
        repeat: true
        running: framePreview.playing && framePreview.preview.visible && (framePreview.wave || (framePreview.music && IrisFrame.framed)) && IrisStyle.motionEnabled
        onTriggered: framePreview.phase += 0.05 * Number(framePreview.opt("iris.surround.musicSpeed", 100)) / 100
    }
    Field.IrisField {
        anchors.fill: parent
        anchors.margins: Math.round(16 * framePreview.d)
        framed: IrisFrame.framed
        band: IrisFrame.band
        cornerRadius: IrisFrame.cornerRadius
        // Miniatures always sample wallpaper; they never blur Settings itself.
        compositorAllowed: false
        edgeWave: {
            const level = framePreview.music ? Math.min(20, (5 + 3 * Math.sin(framePreview.phase * 3)) * framePreview.strength * framePreview.sensitivity) : 0
            const sides = framePreview.edges !== "horizontal", horizontal = framePreview.edges !== "sides"
            return Qt.vector4d(horizontal ? level : 0, sides ? level : 0, horizontal ? level : 0, sides ? level : 0)
        }
        waveClock: framePreview.phase
        frameMusicLevel: framePreview.music ? 0.5 : 0
        shapes: [{ x: width / 2 - 66 * framePreview.d, y: 0, width: 132 * framePreview.d, height: 30 * framePreview.d,
            radius: IrisStyle.radiusTile, id: "island", joins: "frame", fuse: IrisStyle.fuse }]
    }
    IrisClock { anchors.centerIn: parent; pixelSize: 48 * IrisStyle.typeScale; separatorColor: IrisStyle.secondaryAccent }
    Shape {
        anchors.fill: parent
        visible: framePreview.wave
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.accent
            strokeWidth: Math.round(3 * framePreview.d)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathMultiline {
                paths: [Array.from({length: 49}, (_, i) => Qt.point(i / 48 * framePreview.width,
                    framePreview.height - 24 * framePreview.d - (10 + 7 * Math.sin(i * 0.2 + framePreview.phase * 3)) * framePreview.d))]
            }
        }
    }
    OffState { visible: !IrisFrame.framed && !framePreview.wave; text: Translation.tr("Frame off") }
    Caption { glyph: "crop_free"; text: framePreview.wave ? Translation.tr("Music follows the screen edges") : framePreview.music ? Translation.tr("A sample of your frame's music response") : Translation.tr("The frame's width, corners and material") }
}
