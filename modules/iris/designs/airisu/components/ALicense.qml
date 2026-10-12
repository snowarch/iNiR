import QtQuick
import qs.services
import qs.modules.iris.style

// The license plate (ナンバープレート): AIRISU's clock on the lock and the desk. A gofun plate inside a double fillet,
// the date in Japanese along the top and the time below it in the wide face, hours and minutes joined by a dash the
// way a plate's number is. Sized by `plateWidth`; everything inside scales with it.
Item {
    id: root
    property real plateWidth: Math.round(620 * Airisu.d)
    property date when: DateTime.clock.date
    readonly property real k: root.plateWidth / 620
    implicitWidth: root.plateWidth
    implicitHeight: Math.round(260 * root.k)

    // Outer fillet: a gofun line two units from the plate, the lacquer gap between them.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Math.max(1, Math.round(3 * root.k))
        border.color: Airisu.gofun
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(2, Math.round(9 * root.k))
        color: Airisu.gofun
        // Inner fillet: lacquer, close to the plate's edge.
        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(1, Math.round(3 * root.k))
            color: "transparent"
            border.width: Math.max(1, Math.round(2 * root.k))
            border.color: Airisu.inkOnGofun
            opacity: 0.85 // iris-literal: the stamped rim reads lighter than the figures
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(20 * root.k)
            text: Qt.locale("ja_JP").toString(root.when, "dddd・M月d日")
            font.family: "Noto Sans CJK JP"
            font.pixelSize: Math.round(28 * root.k)
            font.weight: Font.Medium
            font.letterSpacing: Math.round(2 * root.k)
            color: Airisu.inkOnGofun
            renderType: Text.NativeRendering
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: date.bottom
            anchors.topMargin: -Math.round(10 * root.k)
            text: Qt.formatTime(root.when, "hh-mm")
            font.family: Airisu.wide
            font.pixelSize: Math.round(170 * root.k)
            font.weight: Font.ExtraBold
            font.letterSpacing: -Math.round(4 * root.k)
            font.features: { "tnum": 1 }
            color: Airisu.inkOnGofun
            renderType: Text.NativeRendering
        }
    }
}
