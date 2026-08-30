pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.modules.background.widgets
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

AbstractBackgroundWidget {
    id: root

    configEntryName: "imageConverter"
    defaultConfig: ({
        enable: false,
        locked: false,
        placementStrategy: "free",
        selectedFormat: "webp",
        contentWidth: 292,
        contentHeight: 260,
        widgetScale: 100,
        widgetOpacity: 100,
        colorMode: "auto",
        dim: 0,
        showBackground: true,
        useBlur: false,
        showBorder: true,
        backgroundOpacity: 0.22,
        borderWidth: 1,
        borderOpacity: 0.22,
        cornerRadius: -1,
        x: 120,
        y: 360
    })

    readonly property var formatOptions: [
        { displayName: "PNG", icon: "image", value: "png" },
        { displayName: "JPG", icon: "photo", value: "jpg" },
        { displayName: "WEBP", icon: "motion_photos_on", value: "webp" },
        { displayName: "AVIF", icon: "hd", value: "avif" },
        { displayName: "BMP", icon: "grid_on", value: "bmp" },
        { displayName: "TIFF", icon: "photo_library", value: "tiff" },
        { displayName: "PDF", icon: "picture_as_pdf", value: "pdf" }
    ]
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

    implicitWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 292) * root.scaleFactor)
    implicitHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 260) * root.scaleFactor)
    resizableAxes: ({ width: "contentWidth", height: "contentHeight" })
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

    WidgetSurface {
        anchors.fill: parent
        regionBrightness: root.regionBrightness
        surfaceRadius: root.cornerRadiusOverride >= 0
            ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.widgetInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        visible: root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(10 * root.scaleFactor)

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "PNG · JPG · WEBP · AVIF · BMP · TIFF · PDF"
            color: ColorUtils.applyAlpha(root.widgetInk, 0.56)
            font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
        }

        Rectangle {
            id: dropZone
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Math.max(10, root.widgetCardRadius - 5)
            color: {
                switch (root.conversionState) {
                case "hover": return ColorUtils.applyAlpha(root.widgetAccent, 0.18)
                case "converting": return ColorUtils.applyAlpha(root.widgetAccent2, 0.18)
                case "done": return ColorUtils.applyAlpha(root.widgetAccent3, 0.18)
                case "error": return ColorUtils.applyAlpha(root.widgetSignal, 0.14)
                default: return ColorUtils.applyAlpha(root.widgetInk, 0.06)
                }
            }
            border.width: root.conversionState === "hover" ? 2 : 1
            border.color: {
                switch (root.conversionState) {
                case "hover": return root.widgetAccent
                case "converting": return root.widgetAccent2
                case "done": return root.widgetAccent3
                case "error": return root.widgetSignal
                default: return ColorUtils.applyAlpha(root.widgetInk, 0.20)
                }
            }

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            Behavior on border.color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -16 * root.scaleFactor
                visible: root.conversionState === "converting"
                loading: visible
                implicitSize: Math.round(44 * root.scaleFactor)
            }

            MaterialSymbol {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -16 * root.scaleFactor
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
                iconSize: Math.round(34 * root.scaleFactor)
                color: root.conversionState === "error"
                    ? root.widgetSemanticForeground(root.widgetSignalRole) : root.widgetAccentVisible
            }

            StyledText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 25 * root.scaleFactor
                width: parent.width - 24 * root.scaleFactor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                color: root.conversionState === "error"
                    ? root.widgetSemanticForeground(root.widgetSignalRole, root.accentBackdrop, 4.5) : root.widgetInk
                opacity: root.conversionState === "idle" ? 0.68 : 1
                font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                text: {
                    switch (root.conversionState) {
                    case "idle": return Translation.tr("Drop images here to convert to %1").arg(root.selectedFormat.toUpperCase())
                    case "hover": return Translation.tr("Release to convert to %1").arg(root.selectedFormat.toUpperCase())
                    default: return root.statusMessage
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.scaleFactor)

            StyledText {
                text: Translation.tr("Convert to")
                color: ColorUtils.applyAlpha(root.widgetInk, 0.72)
                font.pixelSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
            }

            SelectionGroupButton {
                Layout.fillWidth: true
                leftmost: true
                rightmost: true
                buttonIcon: root.selectedFormat === "pdf" ? "picture_as_pdf" : "image"
                buttonText: root.selectedFormat.toUpperCase()
                onClicked: {
                    const index = root.formatOptions.findIndex(item => item.value === root.selectedFormat)
                    const next = root.formatOptions[(index + 1) % root.formatOptions.length]
                    root.setFormat(next.value)
                }
                StyledToolTip {
                    text: Translation.tr("Click to choose the next output format")
                }
            }
        }
    }
}
