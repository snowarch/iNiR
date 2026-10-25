pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// One wallpaper as a picture: the cheap preview first, the sharp one and its motion once it is worth it, and its marks
// (in use, hearted, live, downloading). It is laid out once at the size it rests at; layouts move it by transform.
ClippingRectangle {
    id: root

    required property var engine
    property var entry: null
    // Worth the full picture: the one in front, at rest.
    property bool sharp: false
    // And for a web still, the original file (megabytes): only after a longer look.
    property bool full: false
    property bool playing: false
    property bool marks: true
    property real markScale: 1

    readonly property real d: IrisStyle.density
    readonly property bool local: String(root.entry?.path ?? "").length > 0
    readonly property bool video: root.entry?.video ?? false
    readonly property bool current: root.marks && root.engine.isCurrent(root.entry)
    readonly property bool favorite: root.marks && root.entry !== null && Wallpapers.isFavorite(root.entry.key)
    readonly property bool busy: root.entry !== null && root.engine.downloadingKey === root.entry.key

    color: IrisStyle.surfaceHigh

    Loader {
        anchors.fill: parent
        active: root.local
        sourceComponent: ThumbnailImage {
            generateThumbnail: true
            cleanVideoStill: true
            sourcePath: String(root.entry?.path ?? "")
            thumbnailSizeName: "large"
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 256
            sourceSize.height: 256
            mipmap: true
        }
    }
    IrisImage {
        anchors.fill: parent
        visible: !root.local && source.toString().length > 0
        source: root.local ? "" : String(root.entry?.preview ?? "")
        decodeWidth: Math.min(root.width, 320)
        decodeHeight: Math.min(root.height, 200)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
    }
    IrisImage {
        id: sharpImage
        anchors.fill: parent
        source: !root.sharp || !root.entry ? ""
            : root.local ? (root.video ? Wallpapers.stillUrlFor(root.entry.path) : "file://" + root.entry.path)
            : root.full && !root.video ? String(root.entry.file ?? "")
            : String(root.entry.sample ?? "")
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(240); easing.type: IrisStyle.feedbackEasing } }
    }
    Loader {
        anchors.fill: parent
        active: root.playing && root.video && String(root.entry?.motion ?? "").length > 0
        sourceComponent: Video {
            id: motion
            property bool shown: false
            readonly property string path: String(root.entry?.motion ?? "")
            source: motion.path.startsWith("/") ? "file://" + motion.path : motion.path
            fillMode: VideoOutput.PreserveAspectCrop
            loops: MediaPlayer.Infinite
            muted: true
            autoPlay: true
            opacity: motion.shown ? 1 : 0
            onPositionChanged: if (motion.position > 0) motion.shown = true
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(280); easing.type: IrisStyle.feedbackEasing } }
        }
    }

    // Marks sit in the corners at a size of their own, so a card scaled down keeps them readable.
    Item {
        anchors.fill: parent
        anchors.margins: Math.round(10 * root.d * root.markScale)
        visible: root.marks && root.entry !== null

        Rectangle {
            visible: root.video
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: Math.round(22 * root.d * root.markScale)
            width: liveRow.implicitWidth + Math.round(14 * root.d * root.markScale)
            radius: IrisStyle.capsule(height)
            color: IrisStyle.veilStrong
            Row {
                id: liveRow
                anchors.centerIn: parent
                spacing: Math.round(4 * root.d)
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.playing ? "motion_photos_on" : "motion_photos_paused"
                    fill: 1
                    iconSize: Math.round(14 * root.d * root.markScale)
                    color: IrisStyle.onMedia
                }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: String(root.entry?.quality ?? "").length > 0
                    text: String(root.entry?.quality ?? "")
                    color: IrisStyle.onMedia
                    font.family: IrisStyle.fontNumbers
                    font.pixelSize: Math.round(IrisStyle.typeFootnote * root.markScale)
                    font.weight: IrisStyle.weight(Font.Bold)
                }
            }
        }
        Row {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Math.round(6 * root.d * root.markScale)
            Rectangle {
                visible: root.favorite
                width: Math.round(24 * root.d * root.markScale)
                height: width
                radius: IrisStyle.capsule(width)
                color: IrisStyle.veilStrong
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "favorite"
                    fill: 1
                    iconSize: Math.round(14 * root.d * root.markScale)
                    color: IrisStyle.onMedia
                }
            }
            Rectangle {
                visible: root.current || root.busy
                width: Math.round(24 * root.d * root.markScale)
                height: width
                radius: IrisStyle.capsule(width)
                color: root.busy ? IrisStyle.veilStrong : IrisStyle.accent
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.busy ? "downloading" : "check"
                    iconSize: Math.round(15 * root.d * root.markScale)
                    color: root.busy ? IrisStyle.onMedia : IrisStyle.inkOnAccent
                }
            }
        }
    }
    Rectangle {
        visible: root.busy
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: Math.max(3, Math.round(4 * root.d * root.markScale))
        width: parent.width * Math.max(0.04, root.engine.downloadProgress)
        color: IrisStyle.accent
        Behavior on width { NumberAnimation { duration: IrisStyle.duration(300); easing.type: IrisStyle.feedbackEasing } }
    }
}
