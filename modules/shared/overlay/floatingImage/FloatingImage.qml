pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import qs.modules.shared.overlay
import qs.services

// A picture kept over the game: a map, a build, a reference. A new one opens small enough to leave the game in view and
// is resized from any edge or with the wheel, always in its own shape; pinned, only the picture stays, faded when
// clicks go through it. A file, a dropped file or a link.
StyledOverlayWidget {
    id: root
    resizable: root.known
    hudPlate: false
    aspectRatio: root.known ? root.imageWidth / root.imageHeight : 0
    // Small enough to tuck in a corner, wide enough for its header.
    minimumWidth: root.known ? Math.round(Math.max(200 * root.d, 96 * root.d * root.aspectRatio)) : frame.implicitWidth
    minimumHeight: root.known ? 0 : frame.implicitHeight

    readonly property string imageSource: (Config.options?.overlay?.floatingImage?.imageSource ?? "").trim()
    property int imageWidth: 0
    property int imageHeight: 0
    property string _requestedPath: ""
    property bool _dialogEngaged: false
    property bool imageFailed: false
    // Its size is known once fetched, before it is decoded: the frame takes its shape first and the picture is
    // decoded once, at that size.
    readonly property bool known: root.imageWidth > 0 && root.imageHeight > 0
    readonly property bool hasImage: root.known && picture.status === Image.Ready
    readonly property bool loading: root.imageSource.length > 0 && !root.imageFailed && !root.hasImage
    readonly property string clipboardLink: {
        const text = String(Quickshell.clipboardText ?? "").trim()
        return /^https?:\/\/\S+$/.test(text) ? text : ""
    }

    // Where a new picture opens: a third of the screen's width or half its height at most, never past its own pixels.
    readonly property real openingW: root.canvasW > 0
        ? Math.min(root.imageWidth, 0.36 * root.canvasW, 0.5 * root.canvasH * root.aspectRatio)
        : root.imageWidth

    fact: root.hasImage ? Math.round(root.contentW / root.imageWidth * 100) + "%" : ""
    titlebarActionSymbol: root.hasImage || root.imageFailed ? "image_search" : ""
    titlebarActionTooltip: Translation.tr("Change image")
    onTitlebarActionClicked: imageDialog.open()

    function use(source: string): void {
        Config.setNestedValue("overlay.floatingImage.imageSource", source)
    }
    // Another picture starts again from its opening size.
    function forgetSize(): void {
        const e = root.persistentStateEntry
        if (!e) return
        e.width = 0
        e.height = 0
    }

    function refreshImage(): void {
        imageDownloader.running = false
        picture.source = ""
        root.imageWidth = 0
        root.imageHeight = 0
        root._requestedPath = ""
        root.imageFailed = false
        if (root.imageSource.length === 0) return
        const path = Qt.resolvedUrl(Directories.tempImages + "/" + Qt.md5(root.imageSource)).toString()
        root._requestedPath = path
        imageDownloader.sourceUrl = root.imageSource
        imageDownloader.filePath = path
        imageDownloader.running = true
    }
    onImageSourceChanged: {
        root.forgetSize()
        root.refreshImage()
    }
    Component.onCompleted: refreshImage()

    function syncImageDialogLayer(): void {
        const visible = Boolean(imageDialog.visible)
        if (visible === root._dialogEngaged) return
        root._dialogEngaged = visible
        OverlayContext.setNativeDialogVisible("floating-image", visible)
    }

    ImageDownloaderProcess {
        id: imageDownloader
        running: false
        filePath: ""
        sourceUrl: ""
        onDone: (path, width, height) => {
            if (path.toString() !== root._requestedPath) return
            root.imageWidth = width
            root.imageHeight = height
            root.imageFailed = false
            picture.source = path
        }
        onFailed: (path, reason) => {
            if (path.toString() !== root._requestedPath) return
            root.imageWidth = 0
            root.imageHeight = 0
            root.imageFailed = true
            picture.source = ""
            console.warn("[Overlay Image] Could not load the image:", reason)
        }
    }

    contentItem: Item {
        id: frame
        anchors.fill: parent
        implicitWidth: root.known ? root.openingW : Math.round(300 * root.d)
        implicitHeight: root.known ? root.openingW / root.aspectRatio : Math.round(180 * root.d)

        WheelHandler {
            enabled: root.hasImage && !root.resizing
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            // A tenth per notch; fine wheels and touchpads send parts of one.
            onWheel: event => {
                root.scaleBy(Math.pow(1.1, event.angleDelta.y / 120))
                wheelRest.restart()
            }
        }
        Timer {
            id: wheelRest
            interval: 300
        }

        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drag => {
                const url = drag.urls?.[0] ? String(drag.urls[0]) : ""
                if (url.length === 0) return
                const path = url.startsWith("file://") ? FileUtils.trimFileProtocol(url) : url
                if (!url.startsWith("file://") || Images.isValidImageByName(path)) root.use(path)
            }
        }

        Item {
            id: rounded
            anchors.fill: parent
            visible: root.hasImage
            layer.enabled: root.hasImage
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: rounded.width
                    height: rounded.height
                    radius: root.contentRadius
                }
            }
            AnimatedImage {
                id: picture
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                playing: root.visible && status === Image.Ready
                asynchronous: true
                source: ""
                onStatusChanged: {
                    if (status === Image.Error) {
                        root.imageFailed = true
                        root.imageWidth = 0
                        root.imageHeight = 0
                    }
                }
            }
        }

        // Decoded at the size it rests at; while an edge or the wheel moves it the last decode is scaled.
        Binding {
            target: picture
            property: "sourceSize"
            when: root.known && !root.resizing && !wheelRest.running
            value: Qt.size(root.contentW, root.contentH)
            restoreMode: Binding.RestoreNone
        }

        // No picture yet, or one that didn't load: a place to drop one.
        Rectangle {
            anchors.fill: parent
            visible: !root.hasImage
            radius: root.contentRadius
            color: drop.containsDrag ? OverlayLook.colToggle : OverlayLook.colRecessed
            border.width: drop.containsDrag ? 2 : 0
            border.color: OverlayLook.colPrimary
            Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Math.round(32 * root.d)
                spacing: Math.round(6 * root.d)

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.loading ? "progress_activity" : root.imageFailed ? "broken_image" : "add_photo_alternate"
                    iconSize: Math.round(30 * root.d)
                    color: drop.containsDrag ? OverlayLook.colOnToggle : root.imageFailed ? OverlayLook.colError : OverlayLook.colFaint
                    RotationAnimation on rotation {
                        running: root.loading && root.visible
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.loading ? Translation.tr("Loading...")
                        : root.imageFailed ? Translation.tr("Couldn't load the image")
                        : Translation.tr("Drop an image here")
                    color: OverlayLook.colOnLayer1
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeBody
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.imageFailed
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideMiddle
                    text: root.imageSource
                    color: OverlayLook.colSubtext
                    font.family: OverlayLook.fontMain
                    font.pixelSize: OverlayLook.typeFootnote
                }
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Math.round(4 * root.d)
                    visible: !root.loading
                    spacing: Math.round(6 * root.d)
                    OverlayButton {
                        filled: true
                        glyph: "folder_open"
                        label: Translation.tr("Choose file")
                        onClicked: imageDialog.open()
                    }
                    OverlayButton {
                        visible: root.clipboardLink.length > 0 && root.clipboardLink !== root.imageSource
                        filled: true
                        glyph: "content_paste"
                        label: Translation.tr("Paste link")
                        tip: root.clipboardLink
                        onClicked: root.use(root.clipboardLink)
                    }
                }
            }
        }
    }

    FilePickerDialog {
        id: imageDialog
        title: Translation.tr("Choose source image")
        currentFolder: Directories.pictures
        nameFilters: [
            Translation.tr("Images and animations") + " (*.png *.jpg *.jpeg *.webp *.tif *.tiff *.gif *.svg)",
            Translation.tr("All files") + " (*)"
        ]
        onAccepted: {
            const path = FileUtils.trimFileProtocol(String(selectedFile))
            if (Images.isValidImageByName(path)) root.use(path)
        }
        onVisibleChanged: root.syncImageDialogLayer()
    }

    Component.onDestruction: {
        if (root._dialogEngaged)
            OverlayContext.setNativeDialogVisible("floating-image", false)
    }
}
