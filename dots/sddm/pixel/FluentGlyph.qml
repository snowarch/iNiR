// A Fluent System Icon (fluent/, MIT, the ones Waffle wears) in any colour: the glyph's shape cut from a fill.
import QtQuick 2.15
import QtQuick.Effects

Item {
    id: glyph
    property string icon: ""
    property color colour: "#ffffff"
    implicitWidth: 20
    implicitHeight: 20

    Image {
        id: shape
        anchors.fill: parent
        source: glyph.icon.length > 0 ? "fluent/" + glyph.icon + ".svg" : ""
        sourceSize: Qt.size(glyph.width * 2, glyph.height * 2)
        smooth: true
        visible: false
    }
    Rectangle {
        id: fill
        anchors.fill: parent
        color: glyph.colour
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: fill
        maskEnabled: true
        maskSource: shape
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
