import QtQuick

// The 1 px fillet that separates AIRISU's parts (鉄 Tetsu): no shadows, no rounded plates.
Rectangle {
    property bool vertical: false
    implicitWidth: vertical ? Airisu.line : 0
    implicitHeight: vertical ? 0 : Airisu.line
    color: Airisu.fillet
}
