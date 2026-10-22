pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Screenshots & Recording: a snip drawn over two windows. The pointer drags a region; snapping to windows lands it on
// the window under it, circle to search draws a ring instead, aim lines cross at the pointer. Then the recording pill
// says what sound it takes.
PreviewScene {
    id: captureRoot
    readonly property real naturalWidth: Math.round(600 * captureRoot.d)
    readonly property real naturalHeight: Math.round(320 * captureRoot.d)
    narrowest: Math.round(400 * captureRoot.d)
    lowest: Math.round(250 * captureRoot.d)
    subject: Qt.rect(region.x, region.y, region.width, region.height)
    readonly property bool snap: captureRoot.opt("regionSelector.targetRegions.windows", true) === true
    readonly property bool circle: captureRoot.opt("search.imageSearch.useCircleSelection", false) === true
    readonly property bool aim: captureRoot.opt("regionSelector.rect.showAimLines", true) === true
    readonly property bool satty: captureRoot.opt("regionSelector.annotation.useSatty", false) === true
    readonly property string sound: String(captureRoot.opt("screenRecord.audioMode", "system"))
    property real t: 1
    Loop on t { running: captureRoot.playing; rest: 1600 }

    // Two windows on the desktop.
    Plate {
        id: big
        surface: "windows"
        x: Math.round(captureRoot.width * 0.08)
        y: Math.round(34 * captureRoot.d)
        width: Math.round(captureRoot.width * 0.5)
        height: Math.round(captureRoot.height * 0.62)
        radius: IrisStyle.radiusPlate
        Row {
            x: Math.round(14 * captureRoot.d); y: Math.round(12 * captureRoot.d)
            spacing: Math.round(6 * captureRoot.d)
            Repeater { model: 3; Rectangle { width: Math.round(8 * captureRoot.d); height: width; radius: width / 2; color: IrisStyle.fillStrong } }
        }
        Column {
            x: Math.round(16 * captureRoot.d); y: Math.round(40 * captureRoot.d)
            spacing: Math.round(10 * captureRoot.d)
            Repeater {
                model: [0.8, 0.62, 0.7, 0.45]
                Rectangle { required property real modelData; width: big.width * modelData; height: Math.round(7 * captureRoot.d); radius: height / 2; color: IrisStyle.fill }
            }
        }
    }
    Plate {
        id: small
        surface: "windows"
        x: big.x + big.width + Math.round(18 * captureRoot.d)
        y: big.y + Math.round(30 * captureRoot.d)
        width: Math.round(captureRoot.width * 0.3)
        height: Math.round(captureRoot.height * 0.4)
        radius: IrisStyle.radiusPlate
        MaterialSymbol { anchors.centerIn: parent; text: "image"; iconSize: Math.round(34 * captureRoot.d); color: IrisStyle.textTertiary }
    }

    // The region: from where the pointer pressed to where it is; with snapping it settles on the window.
    readonly property rect free: Qt.rect(big.x + big.width * 0.18, big.y + big.height * 0.22, big.width * 0.62, big.height * 0.56)
    readonly property real drawn: Math.min(1, captureRoot.t / 0.7)
    readonly property real settle: captureRoot.snap ? Math.max(0, (captureRoot.t - 0.7) / 0.3) : 0
    readonly property rect target: captureRoot.snap ? Qt.rect(big.x, big.y, big.width, big.height) : captureRoot.free
    Item {
        id: region
        x: captureRoot.free.x + (captureRoot.target.x - captureRoot.free.x) * captureRoot.settle
        y: captureRoot.free.y + (captureRoot.target.y - captureRoot.free.y) * captureRoot.settle
        width: Math.max(1, (captureRoot.free.width + (captureRoot.target.width - captureRoot.free.width) * captureRoot.settle) * captureRoot.drawn)
        height: Math.max(1, (captureRoot.free.height + (captureRoot.target.height - captureRoot.free.height) * captureRoot.settle) * captureRoot.drawn)
        opacity: captureRoot.t > 0.02 ? 1 : 0
        Rectangle {
            anchors.fill: parent
            radius: captureRoot.circle ? Math.min(width, height) / 2 : (captureRoot.snap ? IrisStyle.radiusPlate * captureRoot.settle : 0)
            color: Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.1)
            border.width: Math.max(2, Math.round(2 * captureRoot.d))
            border.color: IrisStyle.accent
        }
    }
    // Aim lines cross at the pointer while it drags.
    Rectangle {
        visible: captureRoot.aim && captureRoot.drawn < 1 && captureRoot.t > 0.02
        x: 0; y: pointer.y + pointer.height / 2
        width: captureRoot.width; height: 1
        color: Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.6)
    }
    Rectangle {
        visible: captureRoot.aim && captureRoot.drawn < 1 && captureRoot.t > 0.02
        x: pointer.x + pointer.width / 2; y: 0
        width: 1; height: captureRoot.height
        color: Qt.rgba(IrisStyle.accent.r, IrisStyle.accent.g, IrisStyle.accent.b, 0.6)
    }
    Pointer {
        id: pointer
        travel: 0
        x: region.x + region.width - width / 2
        y: region.y + region.height - height / 2
    }
    // What happens next: annotate, and the recording pill with the sound it takes.
    Rectangle {
        id: record
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Math.round(14 * captureRoot.d)
        width: recordRow.implicitWidth + Math.round(24 * captureRoot.d)
        height: Math.round(32 * captureRoot.d)
        radius: height / 2
        color: IrisStyle.veilHeavy
        RowLayout {
            id: recordRow
            anchors.centerIn: parent
            spacing: Math.round(8 * captureRoot.d)
            Rectangle {
                width: Math.round(9 * captureRoot.d); height: width; radius: width / 2
                color: IrisStyle.danger
                SequentialAnimation on opacity {
                    running: captureRoot.playing
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: IrisStyle.duration(600) }
                    NumberAnimation { to: 1; duration: IrisStyle.duration(600) }
                }
            }
            IrisText { text: Translation.tr("Recording"); color: IrisStyle.onMedia; font.pixelSize: IrisStyle.typeMeta; font.weight: Font.DemiBold }
            MaterialSymbol {
                visible: captureRoot.sound !== "none"
                text: captureRoot.sound === "microphone" ? "mic" : "volume_up"
                fill: 1
                iconSize: Math.round(15 * captureRoot.d)
                color: IrisStyle.onMediaSecondary
            }
            MaterialSymbol {
                visible: captureRoot.sound === "both" || captureRoot.sound === "none"
                text: captureRoot.sound === "none" ? "volume_off" : "mic"
                fill: 1
                iconSize: Math.round(15 * captureRoot.d)
                color: IrisStyle.onMediaSecondary
            }
        }
    }
    Caption {
        glyph: captureRoot.circle ? "circle" : "screenshot_region"
        text: [captureRoot.circle ? Translation.tr("Circle to search") : captureRoot.snap ? Translation.tr("Snaps to windows") : Translation.tr("Free region"),
            captureRoot.satty ? Translation.tr("annotate in Satty") : ""].filter(part => part.length > 0).join(" · ")
    }
}
