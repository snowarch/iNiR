pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.services
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import "../components"

// AIRISU's photo: a print laid on the lacquer, cut with the bodies' die so its corners are the plate's. A folder it turns
// through is named in a band of lacquer at the foot with the key to the next print; an empty or broken frame is the
// blank state. The engine's widget keeps the pictures (crossfade, GIFs, video) and draws them in this print's host.
Item {
    id: root
    property var face
    readonly property var widget: root.face?.widget ?? null
    readonly property bool small: root.face?.small ?? true
    readonly property bool large: root.face?.large ?? false
    function dp(v: real): real { return root.face ? root.face.dp(v) : Math.round(v) }
    function px(v: real): real { return root.face ? root.face.px(v) : Math.round(v) }
    readonly property int pad: root.dp(14)
    readonly property bool shows: root.face?.showsPicture ?? false
    readonly property bool dropping: root.face?.dropping ?? false
    readonly property bool failed: root.face?.failed ?? false

    AStock {
        id: stock
        anchors.fill: parent
        face: root.face
        subject: "rest"
    }
    Item {
        id: host
        anchors.fill: parent
        layer.enabled: root.shows
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cutMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }
    Item {
        id: cutMask
        anchors.fill: parent
        visible: false
        layer.enabled: root.shows
        ALacquer {
            anchors.fill: parent
            lacquer: "black"
            coat: "black"
        }
    }
    // The widget draws into whichever host is set last; the engine's face takes it back when this skin goes.
    onFaceChanged: if (root.face?.widget) root.face.widget.irisPhotoHost = host
    Component.onDestruction: if (root.face?.widget && root.face.widget.irisPhotoHost === host) root.face.widget.irisPhotoHost = null

    // The folder's name and the next key, on a band of the lacquer cut along the foot.
    Item {
        id: band
        visible: root.shows && (root.face?.folder ?? false) && !root.small
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.dp(root.large ? 48 : 40)
        ALacquer {
            anchors.fill: parent
            cutTopRight: false
            lacquer: ColorUtils.applyAlpha(stock.lacquer, 0.92) // iris-literal: the band lets the print breathe through
            coat: stock.coat
        }
        Column {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - next.width - root.dp(8) - root.pad
            AText {
                width: parent.width
                voice: "mono"
                size: IrisStyle.typeCaption
                color: stock.inkSecond
                text: root.face?.folderName ?? ""
            }
            AText {
                visible: root.large
                width: parent.width
                size: IrisStyle.typeFootnote
                font.weight: Font.Bold
                color: stock.ink
                text: FileUtils.fileNameForPath(root.widget?.currentPath ?? "").replace(/\.[^.]+$/, "")
            }
        }
        Item {
            id: next
            visible: (root.widget?.mediaCount ?? 0) > 1
            anchors.right: parent.right
            anchors.rightMargin: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.dp(26)
            height: width
            AKey {
                id: nextPlate
                anchors.fill: parent
                lacquer: "transparent"
                under: stock.lacquer
                hovered: nextHover.hovered
                pressed: nextTap.pressed
            }
            ADie {
                x: nextPlate.shift
                y: nextPlate.shift
                width: parent.width
                height: parent.height
                kind: "chamfer"
                cut: Airisu.cutFor(height)
                stroke: stock.inkThird
                strokeWidth: Airisu.hair
            }
            MaterialSymbol {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: nextPlate.shift
                anchors.verticalCenterOffset: nextPlate.shift
                text: "skip_next"
                fill: 1
                iconSize: root.px(15)
                color: stock.ink
            }
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Next picture")
            HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: nextTap; onTapped: root.widget.advance(1, false) }
        }
    }

    AText {
        visible: !root.shows
        x: root.pad
        y: root.pad
        width: root.width - 2 * root.pad
        voice: "mono"
        size: IrisStyle.typeCaption
        color: stock.inkSecond
        text: Translation.tr("Picture")
    }
    ABlank {
        visible: !root.shows
        x: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        width: root.width - 2 * root.pad
        face: root.face
        stock: stock
        label: root.dropping ? Translation.tr("Drop to show it")
            : root.failed ? Translation.tr("This picture won't open") : Translation.tr("Add a photo")
        line: root.dropping ? "" : root.failed ? String(root.widget?.currentName ?? "") : Translation.tr("Drop a picture or a folder here")
    }
    // Something held over the frame: its die is ruled in the seal where it will land.
    ADie {
        anchors.fill: parent
        visible: root.dropping
        kind: "chamfer"
        cut: Airisu.chamfer
        stroke: Airisu.seal
        strokeWidth: Airisu.strong
    }
}
