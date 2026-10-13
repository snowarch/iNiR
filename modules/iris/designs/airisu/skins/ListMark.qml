import QtQuick
import "../components"

// AIRISU's mark on the current row of a list (Spotlight's result): the row is a step of ink and the keyboard's crop
// marks stand at its corners in shu, as they do on any piece the keyboard holds.
Item {
    id: root
    property Item host
    AMarks {
        anchors.fill: parent
        shown: root.visible && root.width > 0
        color: Airisu.seal
        gap: Math.max(2, Math.round(Airisu.m / 2))
        arm: Math.max(3, Math.round(Airisu.m * 1.5))
    }
}
