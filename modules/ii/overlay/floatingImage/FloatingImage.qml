pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.utils
import qs.modules.common.widgets
import qs.modules.ii.overlay
import qs.services

StyledOverlayWidget {
    id: root
    showClickabilityButton: false
    resizable: false
    clickthrough: true

    property string imageSource: Config.options?.overlay?.floatingImage?.imageSource ?? ""
    property real scaleFactor: Config.options?.overlay?.floatingImage?.scale ?? 0.5
    property int imageWidth: 0
    property int imageHeight: 0
    property string _requestedPath: ""
    property bool _componentReady: false
    property bool _dialogEngaged: false
    property bool imageFailed: false
    readonly property bool hasImage: root.imageWidth > 0 && root.imageHeight > 0
        && animatedImage.status === Image.Ready

    title: Translation.tr("Floating image")

    // Override to always save 0 size
    function savePosition(xPos = root.x, yPos = root.y, width = 0, height = 0) {
        root.persistentStateEntry.x = Math.round(xPos);
        root.persistentStateEntry.y = Math.round(yPos);
        root.persistentStateEntry.width = 0
        root.persistentStateEntry.height = 0
    }

    function refreshImage(): void {
        imageDownloader.running = false
        animatedImage.source = ""
        root.imageWidth = 0
        root.imageHeight = 0
        root._requestedPath = ""
        root.imageFailed = false

        const source = root.imageSource.trim()
        if (!source.length) {
            root.setSize()
            return
        }

        const path = Qt.resolvedUrl(
            Directories.tempImages + "/" + Qt.md5(source)).toString()
        root._requestedPath = path
        imageDownloader.sourceUrl = source
        imageDownloader.filePath = path
        imageDownloader.running = true
    }

    onImageSourceChanged: {
        if (root._componentReady)
            root.refreshImage()
    }
    Component.onCompleted: {
        root._componentReady = true
        root.refreshImage()
    }
    onScaleFactorChanged: {
        setSize();
    }

    function setSize() {
        if (root.imageWidth <= 0 || root.imageHeight <= 0) {
            bg.implicitWidth = 340;
            bg.implicitHeight = 164;
            return;
        }
        bg.implicitWidth = root.imageWidth * root.scaleFactor;
        bg.implicitHeight = root.imageHeight * root.scaleFactor;
    }

    function syncImageDialogLayer(): void {
        const visible = Boolean(imageDialog.visible)
        if (visible === root._dialogEngaged) return
        root._dialogEngaged = visible
        OverlayContext.setNativeDialogVisible("floating-image", visible)
    }

    contentItem: OverlayBackground {
        id: bg
        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainer, root.actuallyPinned ? 1 : 0)
        radius: root.contentRadius

        WheelHandler {
            onWheel: (event) => {
                const currentScale = Config.options?.overlay?.floatingImage?.scale ?? 0.5;
                if (event.angleDelta.y < 0) {
                    Config.setNestedValue("overlay.floatingImage.scale", Math.max(0.1, currentScale - 0.1));
                }
                else if (event.angleDelta.y > 0) {
                    Config.setNestedValue("overlay.floatingImage.scale", Math.min(5.0, currentScale + 0.1));
                }
            }
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: bg.width
                height: bg.height
                radius: bg.radius
            }
        }

        AnimatedImage {
            id: animatedImage
            anchors.centerIn: parent
            width: root.imageWidth * root.scaleFactor
            height: root.imageHeight * root.scaleFactor
            sourceSize.width: width
            sourceSize.height: height

            playing: visible && status === Image.Ready
            asynchronous: true
            source: ""
            onStatusChanged: {
                if (status === Image.Ready) {
                    const w = sourceSize.width > 0 ? sourceSize.width : Math.max(1, implicitWidth)
                    const h = sourceSize.height > 0 ? sourceSize.height : Math.max(1, implicitHeight)
                    if (root.imageWidth <= 0 || root.imageHeight <= 0) {
                        root.imageWidth = w;
                        root.imageHeight = h;
                        root.setSize();
                    }
                }
            }

            ImageDownloaderProcess {
                id: imageDownloader
                running: false
                filePath: ""
                sourceUrl: ""

                onDone: (path, width, height) => {
                    if (!root.imageSource.trim().length
                            || path.toString() !== root._requestedPath)
                        return
                    root.imageWidth = width
                    root.imageHeight = height
                    root.imageFailed = false
                    root.setSize()
                    animatedImage.source = path
                }

                onFailed: (path, reason) => {
                    if (!root.imageSource.trim().length
                            || path.toString() !== root._requestedPath)
                        return
                    root.imageWidth = 0
                    root.imageHeight = 0
                    root.imageFailed = true
                    root.setSize()
                    animatedImage.source = ""
                    console.warn("[FloatingImage] Image download failed:", reason)
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 250)
            spacing: 8
            visible: !root.hasImage

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: root.imageSource.trim().length > 0 && !root.imageFailed
                    ? "progress_activity"
                    : root.imageFailed ? "broken_image" : "add_photo_alternate"
                iconSize: 38
                color: Appearance.colors.colOnLayer2
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.imageSource.trim().length > 0 && !root.imageFailed
                    ? Translation.tr("Loading...")
                    : root.imageFailed
                        ? Translation.tr("Error")
                        : Translation.tr("Choose file")
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignHCenter
                visible: root.imageSource.trim().length === 0 || root.imageFailed
                materialIcon: "folder_open"
                mainText: Translation.tr("Choose file")
                colBackground: Appearance.colors.colPrimaryContainer
                colBackgroundHover: ColorUtils.mix(
                    Appearance.colors.colPrimaryContainer,
                    Appearance.colors.colOnPrimaryContainer, 0.90)
                colRipple: ColorUtils.mix(
                    Appearance.colors.colPrimaryContainer,
                    Appearance.colors.colOnPrimaryContainer, 0.78)
                contentColor: ColorUtils.ensureReadable(
                    Appearance.colors.colOnPrimaryContainer,
                    colBackground, 4.5)
                onClicked: imageDialog.open()
            }
        }

        RippleButtonWithIcon {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 8
            visible: GlobalStates.overlayOpen && root.hasImage
            materialIcon: "image_search"
            mainText: Translation.tr("Change")
            colBackground: ColorUtils.applyAlpha(Appearance.colors.colLayer2, 0.94)
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            contentColor: ColorUtils.ensureReadable(
                Appearance.colors.colOnLayer2, colBackground, 4.5)
            onClicked: imageDialog.open()

            StyledToolTip {
                text: Translation.tr("Choose file")
            }
        }
    }

    FileDialog {
        id: imageDialog
        title: Translation.tr("Choose source image")
        fileMode: FileDialog.OpenFile
        currentFolder: Directories.pictures
        nameFilters: [
            Translation.tr("Images and animations") + " (*.png *.jpg *.jpeg *.webp *.tif *.tiff *.gif *.svg)",
            Translation.tr("All files") + " (*)"
        ]
        onAccepted: {
            const path = FileUtils.trimFileProtocol(String(selectedFile))
            if (Images.isValidImageByName(path))
                Config.setNestedValue("overlay.floatingImage.imageSource", path)
        }
    }

    Connections {
        target: imageDialog
        function onVisibleChanged(): void { root.syncImageDialogLayer() }
    }

    Component.onDestruction: {
        if (root._dialogEngaged)
            OverlayContext.setNativeDialogVisible("floating-image", false)
    }
}
