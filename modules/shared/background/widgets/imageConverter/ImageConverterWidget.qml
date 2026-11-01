pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.shared.background.widgets
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

AbstractBackgroundWidget {
    id: root

    configEntryName: "imageConverter"

    readonly property var formats: ["png", "jpg", "webp", "avif", "bmp", "tiff", "pdf"]
    readonly property var acceptedExtensions: [
        "png", "jpg", "jpeg", "webp", "avif", "bmp", "gif", "tiff", "tif"
    ]

    property string selectedFormat: String(root._readConfigKey("selectedFormat") ?? "webp")
    property string conversionState: "idle"
    property string statusMessage: ""
    property var fileQueue: []
    property var pdfPaths: []
    property int queueTotal: 0
    property int queueDone: 0
    property var outputPaths: []
    signal conversionFinished(var paths)

    resizeMinWidth: 250
    resizeMinHeight: 220
    needsColText: false

    function cleanPath(url): string {
        return FileUtils.trimFileProtocol(String(url ?? ""))
    }

    function outputPath(inputPath, suffix): string {
        return inputPath.replace(/\.[^/.]+$/, "") + suffix
    }

    function setFormat(format): void {
        if (root.selectedFormat === format)
            return
        root.selectedFormat = format
        Config.setNestedValue(root._configPath + ".selectedFormat", format)
    }

    function resetQueue(): void {
        root.fileQueue = []
        root.pdfPaths = []
        root.queueTotal = 0
        root.queueDone = 0
        root.outputPaths = []
    }

    function fail(message): void {
        root.resetQueue()
        root.conversionState = "error"
        root.statusMessage = message
        resetTimer.restart()
    }

    function processNext(): void {
        if (root.fileQueue.length === 0) {
            const outputs = root.outputPaths.slice()
            root.conversionState = "done"
            root.statusMessage = root.queueTotal === 1
                ? Translation.tr("Image converted")
                : Translation.tr("%1 images converted").arg(root.queueTotal)
            root.queueTotal = 0
            root.queueDone = 0
            root.outputPaths = []
            root.conversionFinished(outputs)
            resetTimer.restart()
            return
        }

        const nextPath = root.fileQueue[0]
        root.fileQueue = root.fileQueue.slice(1)
        converter.inputPath = nextPath
        converter.outputPath = root.outputPath(nextPath, "_converted." + root.selectedFormat)
        converter.running = true
    }

    function enqueueFiles(urls): void {
        const valid = []
        for (let i = 0; i < urls.length; ++i) {
            const path = root.cleanPath(urls[i])
            const extension = path.split(".").pop().toLowerCase()
            if (root.acceptedExtensions.includes(extension))
                valid.push(path)
        }

        if (valid.length === 0) {
            root.fail(Translation.tr("No supported images were dropped"))
            return
        }

        root.conversionState = "converting"
        if (root.selectedFormat === "pdf") {
            root.pdfPaths = valid
            root.statusMessage = valid.length === 1
                ? Translation.tr("Converting to PDF")
                : Translation.tr("Merging %1 images into PDF").arg(valid.length)
            pdfMaker.outputPath = root.outputPath(valid[0], valid.length > 1
                ? "_merged.pdf" : "_converted.pdf")
            pdfMaker.command = ["magick"].concat(valid).concat([pdfMaker.outputPath])
            pdfMaker.running = true
            return
        }

        root.fileQueue = valid
        root.queueTotal = valid.length
        root.queueDone = 0
        root.statusMessage = valid.length === 1
            ? Translation.tr("Converting image")
            : Translation.tr("Converting 0 of %1").arg(valid.length)
        root.processNext()
    }

    Process {
        id: converter
        property string inputPath: ""
        property string outputPath: ""
        command: ["ffmpeg", "-y", "-i", inputPath, outputPath]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.fail(Translation.tr("Conversion failed for %1").arg(
                    converter.inputPath.replace(/.*\//, "")))
                return
            }
            root.outputPaths = root.outputPaths.concat([converter.outputPath])
            root.queueDone++
            root.statusMessage = root.queueDone < root.queueTotal
                ? Translation.tr("Converting %1 of %2").arg(root.queueDone).arg(root.queueTotal)
                : Translation.tr("Finishing conversion")
            root.processNext()
        }
    }

    Process {
        id: pdfMaker
        property string outputPath: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.fail(Translation.tr("PDF conversion failed"))
                return
            }
            const count = root.pdfPaths.length
            const output = pdfMaker.outputPath
            root.conversionState = "done"
            root.statusMessage = count === 1
                ? Translation.tr("PDF created")
                : Translation.tr("PDF created from %1 images").arg(count)
            root.resetQueue()
            root.conversionFinished([output])
            resetTimer.restart()
        }
    }

    Timer {
        id: resetTimer
        interval: 3500
        onTriggered: {
            root.conversionState = "idle"
            root.statusMessage = ""
        }
    }

    readonly property color bodyInk: root.widgetHasSurface ? root.widgetInk : root.widgetSemanticOnContainer("surface")
    readonly property color bodyColor: {
        const c = Qt.color(root.widgetHasSurface ? root.widgetPlateColor : root.widgetSemanticContainer("surface"))
        return Qt.rgba(c.r, c.g, c.b, 1)
    }

    WidgetSurface {
        widget: root
        anchors.fill: parent
        surfaceColor: root.widgetInk
        shown: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    // Plate off, it still stands on one opaque body: a place to drop things can't float loose on a wallpaper.
    Rectangle {
        anchors.fill: parent
        visible: !root.widgetHasSurface
        radius: root.widgetCardRadius
        color: root.bodyColor
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(12 * root.scaleFactor)
        spacing: Math.round(8 * root.scaleFactor)

        Rectangle {
            id: dropZone
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Math.max(8, root.widgetCardRadius - Math.round(12 * root.scaleFactor))
            color: {
                switch (root.conversionState) {
                case "hover": return ColorUtils.applyAlpha(root.widgetAccent, 0.24)
                case "converting": return ColorUtils.applyAlpha(root.widgetAccent2, 0.2)
                case "done": return ColorUtils.applyAlpha(root.widgetAccent3, 0.2)
                case "error": return ColorUtils.applyAlpha(root.widgetSignal, 0.18)
                default: return ColorUtils.applyAlpha(root.bodyInk, 0.06)
                }
            }

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Math.round(24 * root.scaleFactor)
                spacing: Math.round(6 * root.scaleFactor)

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Math.round(36 * root.scaleFactor)
                    implicitHeight: implicitWidth

                    MaterialLoadingIndicator {
                        anchors.centerIn: parent
                        visible: root.conversionState === "converting"
                        loading: visible
                        implicitSize: parent.width
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: root.conversionState !== "converting"
                        text: {
                            switch (root.conversionState) {
                            case "hover": return "download"
                            case "done": return "check_circle"
                            case "error": return "error"
                            default: return root.selectedFormat === "pdf" ? "picture_as_pdf" : "image"
                            }
                        }
                        fill: root.conversionState === "done" ? 1 : 0
                        iconSize: Math.round(32 * root.scaleFactor)
                        // The zone's fill is translucent: contrast is read on the body under it.
                        color: root.widgetSemanticForeground(root.conversionState === "error"
                            ? root.widgetSignalRole : root.widgetPrimaryRole, root.bodyColor)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: root.conversionState === "error"
                        ? root.widgetSemanticForeground(root.widgetSignalRole, root.bodyColor, 4.5) : root.bodyInk
                    font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                    text: {
                        switch (root.conversionState) {
                        case "idle": return Translation.tr("Drop images here to convert to %1").arg(root.selectedFormat.toUpperCase())
                        case "hover": return Translation.tr("Release to convert to %1").arg(root.selectedFormat.toUpperCase())
                        default: return root.statusMessage
                        }
                    }
                }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: drag => {
                    drag.accept(Qt.CopyAction)
                    if (root.conversionState !== "converting")
                        root.conversionState = "hover"
                }
                onExited: {
                    if (root.conversionState === "hover")
                        root.conversionState = "idle"
                }
                onDropped: drop => {
                    if (root.conversionState === "converting")
                        return
                    if (drop.hasUrls && drop.urls.length > 0)
                        root.enqueueFiles(drop.urls)
                    else
                        root.fail(Translation.tr("Could not read the dropped file"))
                }
            }
        }

        // Every format a key: one press picks it, seven presses of one button only went round them.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false
            spacing: Math.round(2 * root.scaleFactor)

            Repeater {
                model: root.formats

                WidgetChoiceButton {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    horizontalPadding: 2
                    leftmost: index === 0
                    rightmost: index === root.formats.length - 1
                    toggled: root.selectedFormat === modelData
                    buttonText: modelData.toUpperCase()
                    onClicked: root.setFormat(modelData)
                }
            }
        }
    }
}
