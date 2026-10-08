pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

MouseArea {
    id: root

    required property var picker
    required property int index
    property string key: ""
    property string filePath: ""
    property string imageUrl: ""
    property string motionSource: ""
    property bool video: false
    property string quality: ""
    property string label: ""
    property bool selected: false
    property bool current: false
    property bool busy: false
    signal committed()

    readonly property real d: IrisStyle.density
    readonly property bool playing: root.video && root.motionSource.length > 0 && root.picker.motionKey === root.key

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    Accessible.role: Accessible.Button
    Accessible.name: root.label
    onClicked: root.picker.select(root.index)
    onDoubleClicked: root.committed()
    onContainsMouseChanged: root.picker.hoverTile(root.key, root.containsMouse)

    Item {
        anchors.fill: parent
        anchors.margins: Math.round(4 * root.d)
        scale: root.pressed ? IrisStyle.pressScale(0.97) : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }

        ClippingRectangle {
            id: tile
            anchors.fill: parent
            anchors.margins: Math.round(4 * root.d)
            radius: IrisStyle.radiusTile
            color: IrisStyle.surfaceHigh

            Loader {
                anchors.fill: parent
                active: root.filePath.length > 0
                sourceComponent: ThumbnailImage {
                    generateThumbnail: true
                    cleanVideoStill: true
                    sourcePath: root.filePath
                    thumbnailSizeName: "large"
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: Math.round(tile.width * 1.25)
                    sourceSize.height: Math.round(tile.height * 1.25)
                    mipmap: true
                }
            }
            IrisImage {
                anchors.fill: parent
                visible: root.imageUrl.length > 0
                source: root.imageUrl
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
            }
            Loader {
                anchors.fill: parent
                active: root.playing
                sourceComponent: Video {
                    id: motion
                    property bool shown: false
                    source: root.motionSource.startsWith("/") ? "file://" + root.motionSource : root.motionSource
                    fillMode: VideoOutput.PreserveAspectCrop
                    loops: MediaPlayer.Infinite
                    muted: true
                    autoPlay: true
                    opacity: motion.shown ? 1 : 0
                    onPositionChanged: if (motion.position > 0) motion.shown = true
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
                }
            }
        }

        Rectangle {
            visible: root.video
            x: tile.x + Math.round(6 * root.d)
            y: tile.y + Math.round(6 * root.d)
            height: Math.round(20 * root.d)
            width: liveRow.implicitWidth + Math.round(12 * root.d)
            radius: height / 2
            color: IrisStyle.veilStrong
            Row {
                id: liveRow
                anchors.centerIn: parent
                spacing: Math.round(3 * root.d)
                MaterialSymbol {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.playing ? "motion_photos_on" : "motion_photos_paused"
                    fill: 1
                    iconSize: Math.round(13 * root.d)
                    color: IrisStyle.onMedia
                }
                IrisText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.quality.length > 0
                    text: root.quality
                    color: IrisStyle.onMedia
                    font.family: IrisStyle.fontNumbers
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.Bold)
                }
            }
        }

        Rectangle {
            visible: root.current || root.busy
            x: tile.x + tile.width - width - Math.round(6 * root.d)
            y: tile.y + Math.round(6 * root.d)
            width: Math.round(22 * root.d)
            height: width
            radius: width / 2
            color: root.busy ? IrisStyle.surface : IrisStyle.accent
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.busy ? "downloading" : "check"
                iconSize: Math.round(14 * root.d)
                color: root.busy ? IrisStyle.accent : IrisStyle.inkOnAccent
            }
        }
    }
}
