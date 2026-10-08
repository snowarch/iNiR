import QtQuick
import QtQuick.Window
import QtWebEngine
import org.kde.layershell 1.0 as LayerShell

Window {
    id: root

    readonly property var args: Qt.application.arguments
    readonly property bool probeMode: args.indexOf("--probe") >= 0
    readonly property bool interactive: args.indexOf("--interactive") >= 0
    readonly property int screenArg: args.indexOf("--screen")
    readonly property string screenName: screenArg >= 0 && screenArg + 1 < args.length
        ? args[screenArg + 1] : ""
    readonly property string sourceArg: args.length > 1 ? String(args[args.length - 1]).trim() : ""
    readonly property url sourceUrl: {
        if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(sourceArg))
            return sourceArg
        const localPath = sourceArg.endsWith("/") ? sourceArg + "index.html" : sourceArg
        return localPath.startsWith("file://") ? localPath : "file://" + localPath
    }

    visible: !root.probeMode
    color: "black"
    title: "iNiR Web Wallpaper"
    flags: root.interactive
        ? Qt.FramelessWindowHint
        : (Qt.FramelessWindowHint | Qt.WindowTransparentForInput)

    // Passive web wallpapers live below iNiR's desktop surface so widgets and
    // desktop items stay usable. Explicit interactive mode moves above that
    // surface and owns desktop input while the user is playing.
    LayerShell.Window.scope: "inir:web-wallpaper"
    LayerShell.Window.layer: root.interactive
        ? LayerShell.Window.LayerBottom
        : LayerShell.Window.LayerBackground
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop
        | LayerShell.Window.AnchorBottom
        | LayerShell.Window.AnchorLeft
        | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.activateOnShow: root.interactive
    LayerShell.Window.keyboardInteractivity: root.interactive
        ? LayerShell.Window.KeyboardInteractivityOnDemand
        : LayerShell.Window.KeyboardInteractivityNone

    Component.onCompleted: {
        if (root.probeMode) {
            Qt.callLater(Qt.quit)
            return
        }
        if (root.screenName.length > 0) {
            for (let i = 0; i < Qt.application.screens.length; ++i) {
                if (Qt.application.screens[i].name === root.screenName) {
                    root.screen = Qt.application.screens[i]
                    break
                }
            }
        }
    }

    WebEngineView {
        id: web
        anchors.fill: parent
        url: root.sourceUrl
        focus: root.interactive

        settings.webGLEnabled: true
        settings.localContentCanAccessFileUrls: true
        settings.localContentCanAccessRemoteUrls: false
        settings.javascriptCanOpenWindows: false
        settings.fullScreenSupportEnabled: false

        onLoadingChanged: loadRequest => {
            if (loadRequest.status === WebEngineView.LoadFailedStatus)
                console.warn("[WebWallpaperHost] load failed:", loadRequest.errorString)
        }

        onRenderProcessTerminated: (terminationStatus, exitCode) => {
            console.warn("[WebWallpaperHost] renderer terminated:", terminationStatus, exitCode)
        }
    }
}
