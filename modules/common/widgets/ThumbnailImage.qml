import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

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
    // Videos use iNiR's own still: the shared freedesktop cache may hold a film-strip frame.
    property bool cleanVideoStill: false
    readonly property bool _ownsStill: root.cleanVideoStill && root.isVideo
    property bool thumbnailAvailable: false
    property string resolvedThumbnailSource: ""
    // The thumbnail path this tile asked Wallpapers about and is waiting to hear back on.
    property string _pendingCheck: ""
    // A thumbnail that exists but will not decode is made again once, then left alone.
    property bool _repairTried: false
    property string thumbnailPath: {
        if (sourcePath.length === 0) return ""
        if (root._ownsStill) return Wallpapers.videoStillPath(sourcePath)

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
    source: resolvedThumbnailSource

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation {
            duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration)
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Queue thumbnail generation through Wallpapers' serial queue instead of
    // spawning a per-item magick/ffmpeg process.  This avoids a thundering herd
    // when opening a directory with many uncached thumbnails.
    function _ensureThumbnail() {
        if (!root.generateThumbnail) return
        if (!root.sourcePath || root.sourcePath.length === 0) return
        // Batch generator already running — it will emit thumbnailGeneratedFile
        if (root._ownsStill) { Wallpapers.ensureVideoStill(root.sourcePath); return }
        if (Wallpapers.thumbnailGenerationRunning) return
        Wallpapers.ensureThumbnailForPath(root.sourcePath, root.thumbnailSizeName)
    }

    function _repairThumbnail() {
        root._repairTried = true
        Wallpapers.forgetThumbnail(root.thumbnailPath)
        root._clearResolvedThumbnail()
        if (!root.generateThumbnail) return
        if (root._ownsStill) Wallpapers.ensureVideoStill(root.sourcePath, true)
        else Wallpapers.ensureThumbnailForPath(root.sourcePath, root.thumbnailSizeName, true)
    }

    function _clearResolvedThumbnail() {
        root.thumbnailAvailable = false
        root.resolvedThumbnailSource = ""
    }

    function reloadThumbnail() {
        if (!root.sourcePath || root.sourcePath.length === 0 || !root.thumbnailPath || root.thumbnailPath.length === 0) {
            root._pendingCheck = ""
            root._clearResolvedThumbnail()
            return
        }

        const normalizedThumbnailPath = FileUtils.trimFileProtocol(root.thumbnailPath)
        if (Wallpapers.hasKnownThumbnail(normalizedThumbnailPath)) {
            root._pendingCheck = ""
            root.thumbnailAvailable = true
            root.resolvedThumbnailSource = root.thumbnailPath
            return
        }

        root._clearResolvedThumbnail()
        root._pendingCheck = normalizedThumbnailPath
        Wallpapers.requestThumbnailCheck(normalizedThumbnailPath)
    }

    onStatusChanged: {
        if (status === Image.Ready) {
            Wallpapers.rememberThumbnail(root.thumbnailPath)
        } else if (status === Image.Error && root.resolvedThumbnailSource.length > 0) {
            if (root._repairTried) {
                Wallpapers.forgetThumbnail(root.thumbnailPath)
                root._clearResolvedThumbnail()
            } else {
                root._repairThumbnail()
            }
        }
    }

    onSourcePathChanged: {
        root._repairTried = false
        root.reloadThumbnail()
    }

    onThumbnailSizeNameChanged: {
        root.reloadThumbnail()
    }

    onSourceSizeChanged: {
        if (root.status === Image.Ready) return
        root.reloadThumbnail()
    }

    Connections {
        target: Wallpapers
        function onThumbnailGenerated(directory) {
            if (!root.sourcePath || root.sourcePath.length === 0) return
            if (FileUtils.parentDirectory(root.sourcePath) !== directory) return
            root.reloadThumbnail()
        }
        function onThumbnailGeneratedFile(filePath) {
            if (!root.sourcePath || root.sourcePath.length === 0) return
            if (Qt.resolvedUrl(root.sourcePath) !== Qt.resolvedUrl(filePath)) return
            root.reloadThumbnail()
        }
        function onThumbnailsChecked(found) {
            const checked = root._pendingCheck
            if (checked.length === 0 || found[checked] === undefined) return
            root._pendingCheck = ""
            if (checked !== FileUtils.trimFileProtocol(root.thumbnailPath)) {
                root.reloadThumbnail()
                return
            }
            if (found[checked]) {
                root.thumbnailAvailable = true
                root.resolvedThumbnailSource = root.thumbnailPath
            } else {
                root._ensureThumbnail()
            }
        }
    }
}
