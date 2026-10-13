import QtQuick
import "../components"

// AIRISU's plate under a group of the Control Center: a group of discs sits in a tray sunk into the body, the way a
// lacquer box holds its pieces; a block and the player are the body's next coat. All are cut by the same die as the
// controls on them.
Item {
    id: root
    property Item host
    readonly property string kind: String(root.host?.plateKind ?? "block")
    ALacquer {
        anchors.fill: parent
        lacquer: root.kind === "group" ? Airisu.slot : Airisu.groundRaised
    }
}
