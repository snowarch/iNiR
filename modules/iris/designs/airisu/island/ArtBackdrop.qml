import QtQuick
import QtQuick.Effects
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// The record under AIRISU's page: the cover printed large and sharp in one ink on the lacquer, run off the right edge,
// faint enough to read over. Never a blur of its colours: those smear the lacquer.
Item {
    id: root
    clip: true
    Image {
        id: art
        visible: false
        source: MediaArtwork.displaySource
        width: Math.round(root.height * 1.1)
        height: width
        x: root.width - Math.round(width * 0.62)
        y: Math.round((root.height - height) / 2)
        sourceSize.width: width
        sourceSize.height: height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }
    MultiEffect {
        source: art
        anchors.fill: art
        saturation: -1
        contrast: 0.3
        opacity: 0.09 // iris-literal: a print under lacquer, read through
    }
    // The print fades out towards the page's reading side.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.35; color: IrisStyle.bodySurface }
            GradientStop { position: 0.75; color: "transparent" }
        }
    }
}
