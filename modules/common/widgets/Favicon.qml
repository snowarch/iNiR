import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Io
import Quickshell.Widgets

IconImage {
    id: root
    property string url
    property string displayText

    property real size: 32
    property string downloadUserAgent: Config.options?.networking.userAgent ?? ""
    property string faviconDownloadPath: Directories.favicons
    property string domainName: url.includes("vertexaisearch") ? displayText : StringUtils.getDomain(url)
    property string faviconUrl: `https://www.google.com/s2/favicons?domain=${domainName}&sz=32`
    property string fileName: `${domainName}.ico`
    property string faviconFilePath: `${faviconDownloadPath}/${fileName}`
    property string urlToLoad

    Process {
        id: faviconDownloadProcess
        running: false
        // -f + --remove-on-error: Google answers 404 with an HTML body for any
        // domain it cannot resolve (a localhost player, an intranet host), and
        // without this the error page is cached as an .ico that the image
        // loader then fails to decode on every startup, forever, because the
        // [ -f ] guard never re-fetches it.
        command: ["/usr/bin/bash", "-c", `[ -f ${faviconFilePath} ] || /usr/bin/curl -sfL --remove-on-error '${root.faviconUrl}' -o '${faviconFilePath}' -H 'User-Agent: ${downloadUserAgent}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.urlToLoad = root.faviconFilePath
        }
    }

    Component.onCompleted: {
        faviconDownloadProcess.running = true
    }

    source: Qt.resolvedUrl(root.urlToLoad)
    implicitSize: root.size

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.implicitSize
            height: root.implicitSize
            radius: Appearance.rounding.full
        }
    }
}