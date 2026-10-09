pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.background

Item {
    id: root
    required property var context
    property bool editing: false
    property string screenName: root.QsWindow.window?.screen?.name ?? ""
    property bool leaving: false
    readonly property bool sceneReady: !root.painted || wallpaper.status === Image.Ready || wallpaper.status === Image.Error
    property real presence: 0
    readonly property real arrival: IrisStyle.ramp(root.presence, 0.25, 0.75)
    readonly property int presenceTarget: root.leaving || !(root.sceneReady || sceneTimeout.fired) ? 0 : 1
    Behavior on presence {
        NumberAnimation {
            duration: root.presenceTarget > 0 ? IrisStyle.settleDuration : IrisStyle.recedeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.presenceTarget > 0 ? IrisStyle.emergeCurve : IrisStyle.recedeCurve
        }
    }
    Timer { id: sceneTimeout; property bool fired: false; interval: 400; running: true; onTriggered: fired = true }
    Component.onCompleted: {
        root.presence = Qt.binding(() => root.presenceTarget)
        root.focusPassword()
    }
    property alias peeking: stage.peeking
    readonly property string selected: stage.selected
    readonly property var selectedWidget: lockWidgets.selectedItem
    readonly property rect selectedRect: root.selectedWidget
        ? Qt.rect(root.selectedWidget.x, root.selectedWidget.y, root.selectedWidget.width, root.selectedWidget.height)
        : stage.selectedRect
    focus: true

    readonly property real d: IrisStyle.density
    readonly property var scene: {
        Config.revision
        return Config.options?.iris?.lock?.scene ?? ({})
    }
    readonly property string source: String(root.scene?.source ?? "desktop")
    readonly property string wallpaperPath: root.source === "custom" && String(root.scene?.path ?? "").length > 0
        ? String(root.scene.path) : (Config.options?.background?.wallpaperPath ?? "")
    readonly property bool videoWallpaper: Wallpapers.isVideoFile(root.wallpaperPath.toLowerCase())
    readonly property bool gifWallpaper: root.wallpaperPath.toLowerCase().endsWith(".gif")
    readonly property string wallpaperSource: Wallpapers.stillUrlFor(root.wallpaperPath)
    // Afterglow's "Grade the wallpaper" and Light leak's exposure: the whole screen matches, the lock included (the
    // desktop's own filter).
    readonly property bool graded: IrisStyle.afterglowWallpaper || IrisStyle.leakWallpaper
    readonly property int fillMode: String(root.scene?.fit ?? "cover") === "contain"
        ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    readonly property real vignette: Math.max(0, Math.min(1, Number(root.scene?.vignette ?? 0) / 100))
    readonly property bool drifts: root.painted && String(root.scene?.motion ?? "none") === "drift"
        && IrisStyle.motionEnabled
    readonly property real blur: Math.max(0, Math.min(1, Number(root.scene?.blur ?? 100) / 100))
    readonly property real dim: Math.max(0, Math.min(1, Number(root.scene?.dim ?? 0) / 100))
    readonly property real colourLeft: Math.max(0, Math.min(1, Number(root.scene?.saturation ?? 15) / 100))
    readonly property real scrimStrength: Math.max(0, Math.min(2, Number(root.scene?.scrimStrength ?? 100) / 100))
    readonly property string scrimStyle: String(root.scene?.scrim ?? "gradient")
    readonly property bool painted: root.source !== "colour"
    readonly property int driftMs: Math.max(4000, Math.round(Number(root.scene?.driftTime ?? 40) * 1000))
    readonly property bool blurEnabled: root.painted && root.blur > 0.01
    readonly property bool frosted: root.painted && IrisLockOptions.material === "glass"
    readonly property bool animates: root.painted && (Config.options?.lock?.enableAnimation ?? false)
        && !Wallpapers.batteryPauseActive
    readonly property bool playsVideo: root.animates && root.videoWallpaper
    readonly property bool playsGif: root.animates && root.gifWallpaper

    function wakeIfNeeded(): bool {
        if (!Brightness.asleep) return false
        Brightness.restoreAfterWake()
        return true
    }

    function focusPassword(): void {
        if (root.editing) return
        Qt.callLater(() => stage.input?.forceActiveFocus())
    }

    function submit(): void {
        if (root.editing) return
        if (!root.wakeIfNeeded() && root.context.currentText.length > 0 && !root.context.unlockInProgress)
            root.context.tryUnlock()
    }

    Connections {
        target: root.context
        function onShouldReFocus(): void { root.focusPassword() }
    }

    Keys.onPressed: event => {
        if (root.wakeIfNeeded()) {
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Escape && !root.editing) {
            root.context.clearText()
            event.accepted = true
            return
        }
        if (!root.editing || stage.selected.length === 0) return
        if (root.selectedWidget) {
            const px = (event.modifiers & Qt.ShiftModifier) ? 10 : 1
            const offsets = ({})
            offsets[Qt.Key_Left] = [-px, 0]
            offsets[Qt.Key_Right] = [px, 0]
            offsets[Qt.Key_Up] = [0, -px]
            offsets[Qt.Key_Down] = [0, px]
            const offset = offsets[event.key]
            if (!offset) return
            root.selectedWidget.nudge(offset[0], offset[1])
            event.accepted = true
            return
        }
        const step = (event.modifiers & Qt.ShiftModifier) ? 0.02 : 0.004
        const by = ({})
        by[Qt.Key_Left] = [-step, 0]
        by[Qt.Key_Right] = [step, 0]
        by[Qt.Key_Up] = [0, -step]
        by[Qt.Key_Down] = [0, step]
        const move = by[event.key]
        if (!move) return
        IrisLockOptions.nudge(stage.selected, move[0], move[1])
        event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: IrisStyle.surfaceOpaque
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.editing
        onClicked: { if (!root.wakeIfNeeded()) root.focusPassword() }
        onPositionChanged: root.wakeIfNeeded()
    }

    // One source item, one effect over it: still, GIF or live video all end up here,
    // so blur, drift and the washes never have to know which kind is playing.
    Item {
        id: scenery
        anchors.fill: parent
        visible: root.painted && !root.blurEnabled
        layer.enabled: root.blurEnabled
        transform: [
            Scale {
                id: driftScale
                origin.x: root.width / 2
                origin.y: root.height / 2
                xScale: root.blurEnabled ? 1 + 0.06 * root.presence : 1
                yScale: driftScale.xScale
            },
            Translate { id: driftShift }
        ]

        // What the picture is; a texture that filters the wallpaper (Afterglow, Light leak) draws it filtered over itself
        // inside the scenery, so drift, blur and the washes still see one item.
        Item {
            id: sceneryContent
            anchors.fill: parent
            Image {
                id: wallpaper
                anchors.fill: parent
                source: root.painted ? root.wallpaperSource : ""
                sourceSize: Qt.size(root.width, root.height)
                fillMode: root.fillMode
                asynchronous: false
                cache: false
            }
            Loader {
                anchors.fill: parent
                active: root.playsGif
                sourceComponent: AnimatedImage {
                    source: root.wallpaperSource
                    fillMode: root.fillMode
                    cache: false
                    playing: true
                }
            }
            Loader {
                anchors.fill: parent
                active: root.playsVideo
                sourceComponent: Video {
                    source: "file://" + root.wallpaperPath
                    fillMode: root.fillMode === Image.PreserveAspectFit
                        ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop
                    loops: MediaPlayer.Infinite
                    muted: true
                    autoPlay: true
                }
            }
        }
        Loader {
            anchors.fill: parent
            active: root.graded && root.painted
            sourceComponent: IrisStyle.leak ? leakFilter : afterglowFilter
        }
        Component {
            id: afterglowFilter
            IrisAfterglowWallpaper {
                source: sceneryContent
                live: root.playsVideo || root.playsGif
            }
        }
        Component {
            id: leakFilter
            IrisLeakWallpaper {
                source: sceneryContent
                live: root.playsVideo || root.playsGif
            }
        }
    }

    SequentialAnimation {
        running: root.drifts
        loops: Animation.Infinite
        ParallelAnimation {
            NumberAnimation { target: driftScale; properties: "xScale"; to: 1.12; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "x"; to: Math.round(-18 * root.d); duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "y"; to: Math.round(-12 * root.d); duration: root.driftMs; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: driftScale; properties: "xScale"; to: root.blurEnabled ? 1 + 0.06 * root.presence : 1; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "x"; to: 0; duration: root.driftMs; easing.type: Easing.InOutSine }
            NumberAnimation { target: driftShift; property: "y"; to: 0; duration: root.driftMs; easing.type: Easing.InOutSine }
        }
        onRunningChanged: if (!running) {
            driftScale.xScale = Qt.binding(() => root.blurEnabled ? 1 + 0.06 * root.presence : 1)
            driftShift.x = 0
            driftShift.y = 0
        }
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.blurEnabled
        source: scenery
        blurEnabled: true
        blur: root.presence
        blurMax: Math.round(48 * root.blur)
        // MultiEffect's 0 leaves the colour as it is and -1 is grey: "colour left" 0 % is graphite, 100 % the picture.
        saturation: (root.colourLeft - 1) * root.presence
    }
    Item {
        anchors.fill: parent
        opacity: root.presence
        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "gradient"
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28 * root.scrimStrength) } // iris-literal: wallpaper legibility wash
                GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.12 * root.scrimStrength) } // iris-literal: wallpaper legibility wash
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.42 * root.scrimStrength) } // iris-literal: wallpaper legibility wash
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.scrimStyle === "flat"
            color: Qt.rgba(0, 0, 0, 0.32 * root.scrimStrength) // iris-literal: wallpaper legibility wash
        }
        // Rectangle only takes a linear gradient, so the vignette is a Shape.
        Loader {
            anchors.fill: parent
            active: root.vignette > 0.001
            sourceComponent: Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: root.width / 2
                        centerY: root.height / 2
                        centerRadius: Math.max(root.width, root.height) * 0.72
                        focalX: root.width / 2
                        focalY: root.height / 2
                        focalRadius: 0
                        GradientStop { position: 0.4; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, root.vignette) } // iris-literal: a vignette is black by definition
                    }
                    startX: 0; startY: 0
                    PathLine { x: root.width; y: 0 }
                    PathLine { x: root.width; y: root.height }
                    PathLine { x: 0; y: root.height }
                    PathLine { x: 0; y: 0 }
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            visible: root.dim > 0.001
            color: Qt.rgba(0, 0, 0, root.dim) // iris-literal: user dim, black by definition
        }
    }

    // An explicit texture: handing the scene to MultiEffect directly hides the scene itself.
    ShaderEffectSource {
        id: sceneTexture
        anchors.fill: parent
        visible: false
        sourceItem: root.frosted ? scenery : null
        hideSource: false
        live: true
    }
    Item {
        id: frost
        anchors.fill: parent
        visible: false
        layer.enabled: root.frosted
        MultiEffect {
            anchors.fill: parent
            visible: root.frosted
            autoPaddingEnabled: false
            source: sceneTexture
            blurEnabled: true
            blur: 1
            blurMax: 64
            // The plates keep the scene's colour left, a little more vivid, never a coloured window into a grey scene.
            saturation: (root.colourLeft - 1) * root.presence + 0.35 * root.colourLeft
        }
    }

    IrisLockWidgets {
        id: lockWidgets
        anchors.fill: parent
        screenName: root.screenName
        opacity: root.arrival
        transform: Translate { y: Math.round((1 - root.arrival) * 18 * root.d) }
    }

    IrisLockStage {
        id: stage
        anchors.fill: parent
        opacity: root.arrival
        transform: Translate { y: Math.round((1 - root.arrival) * 24 * root.d) }
        frost: root.frosted ? frost : null
        context: root.context
        editing: root.editing
        onSubmitted: root.submit()
    }
}
