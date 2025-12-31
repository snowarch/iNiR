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

    property bool generateThumbnail: false
    required property string sourcePath
    property bool fallbackToDownscaledSource: true
    readonly property string sourceUrl: {
        if (!sourcePath || sourcePath.length === 0) return "";
        const resolved = String(Qt.resolvedUrl(sourcePath));
        return resolved.startsWith("file://") ? resolved : ("file://" + resolved);
    }
    property string thumbnailSizeName: Images.thumbnailSizeNameForDimensions(sourceSize.width, sourceSize.height)
    property string thumbnailPath: {
        if (sourcePath.length == 0) return "";
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    
    // Try thumbnail first, fall back to source
    source: ""

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onStatusChanged: {
        if (status === Image.Error && source === thumbnailPath) {
            // Thumbnail failed, try fallback
            if (fallbackToDownscaledSource && sourceUrl.length > 0) {
                source = sourceUrl;
            } else {
                source = "";
            }
        }
    }

    onThumbnailPathChanged: {
        if (!thumbnailPath || thumbnailPath.length === 0) {
            source = "";
            return;
        }
        // Try to load thumbnail - if it fails, onStatusChanged handles fallback
        source = thumbnailPath;
    }

    Component.onCompleted: {
        if (thumbnailPath && thumbnailPath.length > 0) {
            source = thumbnailPath;
        }
    }
}
