import QtQuick
import qs.services
import qs.modules.iris.style
import "../components"

// AIRISU's desk clock (board Desktop): the license plate, sized to the widget's box, and under it the host and the
// weather as a mono slate. The plate is its own paper: it reads on any wallpaper without the widget's veil.
Item {
    id: root
    property Item face
    readonly property real captionHeight: caption.implicitHeight + Math.round(10 * Airisu.d)
    ALicense {
        id: plate
        plateWidth: Math.max(Math.round(160 * Airisu.d), Math.min(root.width, (root.height - root.captionHeight) * 620 / 260))
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(0, Math.round((root.height - root.captionHeight - plate.implicitHeight) / 2))
    }
    AText {
        id: caption
        anchors.left: plate.left
        anchors.leftMargin: Math.round(4 * Airisu.d)
        anchors.top: plate.bottom
        anchors.topMargin: Math.round(10 * Airisu.d)
        width: plate.width
        voice: "mono"
        color: root.face?.inkSecondary ?? Airisu.data
        readonly property string weather: String(Weather.data?.temp ?? "").startsWith("--") ? "" : String(Weather.data?.temp ?? "")
        text: [`HOST ${SystemInfo.hostname || SystemInfo.distroName}`, weather].filter(s => s.length > 0).join(" · ")
    }
}
