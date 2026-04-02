import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Thumbnail image. It currently generates to the right place at the right size, but does not handle metadata/maintenance on modification.
 * See Freedesktop's spec: https://specifications.freedesktop.org/thumbnail-spec/thumbnail-spec-latest.html
 */
StyledImage {
    id: root

    property bool generateThumbnail: true
    required property string sourcePath
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property bool isVideo: Images.isValidVideoByName(sourcePath)
    property string thumbnailPath: {
        if (sourcePath.length === 0) return ""

        let cleanPath = FileUtils.trimFileProtocol(String(sourcePath ?? ""))
        if (!cleanPath.startsWith("/"))
            cleanPath = Quickshell.env("PWD") + "/" + cleanPath

        const encodedParts = cleanPath.split("/").map(part => {
            return encodeURIComponent(part).replace(/[!'()*]/g, function(c) {
                return '%' + c.charCodeAt(0).toString(16)
            })
        })

        const md5Hash = Qt.md5("file://" + encodedParts.join("/"))
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`
    }
    source: thumbnailPath

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }

    onStatusChanged: {
        // Graceful error handling: silently fall back for missing/corrupted thumbnails
        if (status === Image.Error && generateThumbnail) {
            // Don't spam warnings - just log at debug level
            // The image will remain invisible until another source is set
        }
    }

    onSourcePathChanged: {
        if (!sourcePath || sourcePath.length === 0) {
            thumbnailGeneration.running = false;
            root.source = "";
            return;
        }

        root.source = root.thumbnailPath
        if (!root.generateThumbnail) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }

    onThumbnailSizeNameChanged: {
        if (!sourcePath || sourcePath.length === 0) return;
        root.source = root.thumbnailPath
        if (!root.generateThumbnail) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }

    onSourceSizeChanged: {
        // Only re-generate if the thumbnail wasn't already loaded successfully.
        // This prevents layout-driven sourceSize oscillation from spawning
        // redundant magick processes when the thumbnail is already showing.
        if (!root.generateThumbnail) return;
        if (root.status === Image.Ready) return;
        thumbnailGeneration.running = false;
        thumbnailGeneration.running = true;
    }
    Process {
        id: thumbnailGeneration
        command: {
            const maxSize = Images.thumbnailSizes[root.thumbnailSizeName];
            const thumbPath = FileUtils.trimFileProtocol(root.thumbnailPath);
            const thumbDir = FileUtils.parentDirectory(thumbPath);
            if (root.isVideo) {
                // Extract first frame from video with ffmpeg
                return ["bash", "-c",
                    `mkdir -p '${thumbDir}' && [ -f '${thumbPath}' ] && exit 0 || { ffmpeg -y -i '${root.sourcePath}' -vframes 1 -vf "scale='min(${maxSize},iw)':'min(${maxSize},ih)':force_original_aspect_ratio=decrease" '${thumbPath}' 2>/dev/null && exit 1; }`
                ]
            }
            return ["bash", "-c",
                `mkdir -p '${thumbDir}' && [ -f '${thumbPath}' ] && exit 0 || { magick '${root.sourcePath}[0]' -resize ${maxSize}x${maxSize} '${thumbPath}' && exit 1; }`
            ]
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 1) { // Force reload if thumbnail had to be generated
                root.source = "";
                root.source = root.thumbnailPath; // Force reload
            }
        }
    }
}
