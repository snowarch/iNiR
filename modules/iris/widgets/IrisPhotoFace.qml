pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.iris.style

// A picture of your own, the whole face. The widget keeps its media slots (crossfade, GIFs, video) and draws them in
// this face's clip; the face adds what a frame on a desk says: where a rotation comes from, the key to the next one,
// and an empty frame that asks for a picture to be dropped on it.
IrisWidgetFace {
    id: root
    designFace: IrisDesign.skin("widgetPhoto")

    readonly property bool empty: String(root.widget.currentPath ?? "").length === 0
    readonly property bool failed: !root.empty && Boolean(root.widget.activeFailed)
    readonly property bool dropping: Boolean(root.widget.dropHover)
    readonly property bool folder: root.widget.sourceMode === "folder" && !root.empty
    readonly property string folderName: FileUtils.folderNameForPath(String(root.widget.folderPath ?? ""))
    readonly property bool showsPicture: !root.empty && !root.failed
    readonly property color tint: root.inked(IrisStyle.identity.blue)

    padding: root.showsPicture ? 0 : root.edgePad

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        Item {
            id: host
            anchors.fill: parent
        }
        // The folder it turns through, on a veil at the foot; a single picture needs no words.
        Rectangle {
            visible: root.folder && !root.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.round(parent.height * (root.large ? 0.3 : 0.48))
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: IrisStyle.veilStrong }
            }
        }
    }
    // A Design that prints the photo lends its own host; this one takes it back when the Design goes.
    Component.onCompleted: if (!root.designed) root.widget.irisPhotoHost = host
    onDesignedChanged: if (!root.designed) root.widget.irisPhotoHost = host
    Component.onDestruction: if (root.widget.irisPhotoHost === host) root.widget.irisPhotoHost = null

    RowLayout {
        visible: root.folder && !root.small
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.edgePad
        spacing: root.dp(8)
        ColumnLayout {
            Layout.fillHeight: false
            Layout.fillWidth: true
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.folderName
                color: IrisStyle.onMedia
                size: root.large ? 15 : 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.large
                text: FileUtils.fileNameForPath(root.widget.currentPath ?? "").replace(/\.[^.]+$/, "")
                color: IrisStyle.onMediaSecondary
                size: 12
            }
        }
        FaceAction {
            face: root
            visible: root.widget.mediaCount > 1
            implicitWidth: root.dp(32)
            glyph: "skip_next"
            name: Translation.tr("Next picture")
            tint: IrisStyle.onMedia
            color: IrisStyle.onMediaFill
            onActivated: root.widget.advance(1, false)
        }
    }

    // Empty on a large frame: a head names it and the empty state waits under it, not lost in the middle.
    FaceHeader {
        id: blankHead
        face: root
        visible: !root.showsPicture && root.large
        width: parent.width
        glyph: "photo"
        text: Translation.tr("Image")
        tint: root.tint
    }
    FaceBlank {
        face: root
        visible: !root.showsPicture
        y: root.large ? blankHead.height + root.dp(24) : Math.round((parent.height - height) / 2)
        width: parent.width
        glyph: root.dropping ? "download" : root.failed ? "broken_image" : "add_photo_alternate"
        tint: root.tint
        title: root.dropping ? Translation.tr("Drop to show it")
            : root.failed ? Translation.tr("This picture won't open") : Translation.tr("Add a photo")
        detail: root.failed ? String(root.widget.currentName ?? "") : Translation.tr("Drop a picture or a folder here")
    }

    // Something held over the frame: the edge lights where it will land.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -root.padding
        visible: root.dropping
        radius: root.radius
        color: root.showsPicture ? IrisStyle.tintFillHover(root.tint) : "transparent"
        border.width: root.dp(2)
        border.color: root.tint
    }
}
