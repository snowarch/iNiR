import QtQuick
import "../components"

// AIRISU's cover where the engine shows one small (the Control Center's player): the record (ARecord), its sleeve with
// an obi of music's lacquer carrying the artist down its side, as a Japanese pressing is sold. Round covers become the
// disc. The engine keeps the art and the keys.
Item {
    id: root
    property Item host
    ARecord {
        anchors.fill: parent
        source: root.host?.source ?? ""
        artist: String(root.host?.artist ?? "")
        circular: root.host?.circular ?? false
        empty: String(root.host?.source ?? "").length === 0
    }
}
