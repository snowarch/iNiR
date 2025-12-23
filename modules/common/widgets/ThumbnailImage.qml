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
        if (sourcePath.length == 0) return;
        const resolvedUrlWithoutFileProtocol = FileUtils.trimFileProtocol(`${Qt.resolvedUrl(sourcePath)}`);
        const encodedUrlWithoutFileProtocol = resolvedUrlWithoutFileProtocol.split("/").map(part => encodeURIComponent(part)).join("/");
        const md5Hash = Qt.md5(`file://${encodedUrlWithoutFileProtocol}`);
        return `${Directories.genericCache}/thumbnails/${thumbnailSizeName}/${md5Hash}.png`;
    }
    source: ""

    asynchronous: true
    smooth: true
    mipmap: false

    opacity: status === Image.Ready ? 1 : 0
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    onStatusChanged: {
        if (status === Image.Error) {
            root.source = "";
        }
    }

    onThumbnailPathChanged: {
        if (!thumbnailPath || thumbnailPath.length === 0) {
            root.source = "";
            return;
        }
        thumbnailProbe.reload();
    }

    Component.onCompleted: {
        if (thumbnailPath && thumbnailPath.length > 0) {
            thumbnailProbe.reload();
        }
    }

    FileView {
        id: thumbnailProbe
        path: thumbnailPath && thumbnailPath.length > 0 ? Qt.resolvedUrl(thumbnailPath) : ""
        onLoaded: {
            // Only set source when file exists to avoid QML Image warning spam
            root.source = root.thumbnailPath;
        }
        onLoadFailed: (error) => {
            if (root.fallbackToDownscaledSource && root.sourceUrl.length > 0) {
                root.source = root.sourceUrl;
            } else {
                root.source = "";
            }
        }
    }
}
