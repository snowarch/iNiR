import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects

// The focused wallpaper at full screen behind a coverflow picker. Painted inside the
// picker (the desktop is untouched until apply), so no window shows through. Two slots
// crossfade; each decodes at screen size, after the selection settles.
Item {
    id: root

    // The wallpaper to show (a video shows its first frame)
    property string path: ""
    // While browsing fast, wait longer before decoding
    property bool rapid: false
    // 0 = sharp preview, 1 = soft backdrop behind a hero card
    property real blurAmount: 0
    // How much the lower part darkens for the controls (0 = none)
    property real bottomShade: 0.62

    readonly property real _dpr: root.window ? root.window.devicePixelRatio : 1
    property Image _front: slotA
    property string _pendingUrl: ""

    function _urlFor(path: string): string {
        const p = FileUtils.trimFileProtocol(String(path ?? ""))
        if (p.length === 0) return ""
        if (!Images.isValidVideoByName(p)) return "file://" + p
        const ff = Wallpapers.videoFirstFrames[p] ?? ""
        if (!ff) {
            Wallpapers.ensureVideoFirstFrame(p)
            return ""
        }
        return ff.startsWith("file://") ? ff : "file://" + ff
    }

    function showNow(): void {
        const url = root._urlFor(root.path)
        if (url.length === 0 || String(root._front.source) === url) return
        root._pendingUrl = url
        const back = root._front === slotA ? slotB : slotA
        if (String(back.source) === url && back.status === Image.Ready)
            root._front = back
        else
            back.source = url
    }

    function _adopt(slot: Image): void {
        if (slot.status === Image.Ready && String(slot.source) === root._pendingUrl)
            root._front = slot
    }

    onPathChanged: settle.restart()
    Component.onCompleted: showNow()

    // Holding an arrow does not decode every wallpaper it passes
    Timer {
        id: settle
        interval: root.rapid ? 160 : 40
        onTriggered: root.showNow()
    }

    Connections {
        target: Wallpapers
        function onVideoFirstFramesChanged() {
            if (Images.isValidVideoByName(root.path)) settle.restart()
        }
    }

    // Black base: nothing shows through while the first decode lands
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
    }

    Item {
        id: slots
        anchors.fill: parent
        // Blur fades at its source's edges: overscan so the fade lands off screen
        anchors.margins: root.blurAmount > 0 ? -64 : 0
        // Blur only while it shows: a sharp preview costs no extra pass
        layer.enabled: Appearance.effectsEnabled && root.blurAmount > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 64
            blur: root.blurAmount
            saturation: -0.1 * root.blurAmount
        }

        Image {
            id: slotA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: Math.round(root.width * root._dpr)
            sourceSize.height: Math.round(root.height * root._dpr)
            opacity: root._front === slotA ? 1 : 0
            onStatusChanged: root._adopt(slotA)
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        Image {
            id: slotB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize.width: Math.round(root.width * root._dpr)
            sourceSize.height: Math.round(root.height * root._dpr)
            opacity: root._front === slotB ? 1 : 0
            onStatusChanged: root._adopt(slotB)
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    // A soft backdrop sits back a little further than a sharp preview
    Rectangle {
        anchors.fill: parent
        color: Appearance.colors.colScrim
        opacity: 0.25 * root.blurAmount
    }

    // Shade only under the controls; the top of the preview stays clean
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.round(parent.height * 0.62)
        opacity: root.bottomShade
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        gradient: Gradient {
            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0) }
            GradientStop { position: 0.45; color: ColorUtils.applyAlpha(Appearance.colors.colScrim, 0.52) }
            GradientStop { position: 1.0; color: Appearance.colors.colScrim }
        }
    }
}
