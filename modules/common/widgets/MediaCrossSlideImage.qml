pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property string source: ""
    property string transitionKey: source
    property int slideDirection: 1
    property bool downloaded: true
    property color placeholderColor: Appearance.colors.colLayer1
    property color iconColor: Appearance.colors.colSubtext
    property int iconSize: 32
    property real artRadius: Appearance.rounding.small
    property bool effectEnabled: false
    property bool blurEnabled: false
    property real blur: 0
    property real blurMax: 32
    property real saturation: 1
    property bool animateChanges: Appearance.animationsEnabled
    property int enterDuration: Appearance.animationsEnabled
        ? Appearance.animation.elementMoveEnter.duration : 240
    property int exitDuration: Appearance.animationsEnabled
        ? Appearance.animation.elementMoveExit.duration : 150

    signal transitionStarted(string source)
    signal transitionFinished(string source)

    property int _frontIndex: 0
    readonly property var _frontLayer: root._frontIndex === 0 ? layerA : layerB
    readonly property var _backLayer: root._frontIndex === 0 ? layerB : layerA
    readonly property bool _hasRenderableArt:
        (layerA.visible && layerA.status === Image.Ready)
        || (layerB.visible && layerB.status === Image.Ready)
    property string _displayedSrc: ""
    property string _displayedKey: ""
    property string _pendingSrc: ""
    property string _pendingKey: ""
    property int _pendingDirection: 1
    property string _candidateSrc: ""
    property string _candidateKey: ""
    property int _candidateDirection: 1
    property bool _waitingForReady: false
    property bool _transitionRunning: false
    property var _transitionIncoming: null
    property var _transitionOutgoing: null

    radius: artRadius
    color: "transparent"
    clip: true

    layer.enabled: true
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    function _resetLayer(layer, shown: bool): void {
        layer.x = 0
        layer.opacity = shown ? 1 : 0
        layer.visible = shown
    }

    function _clearLayer(layer): void {
        layer.visible = false
        layer.opacity = 0
        layer.x = 0
        layer.source = ""
    }

    function _stopAnimations(): void {
        slideAToB.stop()
        slideBToA.stop()
    }

    function _clearAll(): void {
        root._stopAnimations()
        emptySourceTimer.stop()
        root._transitionRunning = false
        root._transitionIncoming = null
        root._transitionOutgoing = null
        root._waitingForReady = false
        root._pendingSrc = ""
        root._pendingKey = ""
        root._candidateSrc = ""
        root._candidateKey = ""
        root._displayedSrc = ""
        root._displayedKey = ""
        root._frontIndex = 0
        root._clearLayer(layerA)
        root._clearLayer(layerB)
    }

    function _finishTransition(): void {
        if (!root._transitionRunning)
            return

        const incoming = root._transitionIncoming
        const outgoing = root._transitionOutgoing
        if (incoming)
            root._resetLayer(incoming, true)
        if (outgoing)
            root._clearLayer(outgoing)

        root._frontIndex = root._frontIndex === 0 ? 1 : 0
        root._transitionRunning = false
        root._transitionIncoming = null
        root._transitionOutgoing = null
        root.transitionFinished(root._displayedSrc)
    }

    function _settleTransition(): void {
        if (!root._transitionRunning)
            return
        root._stopAnimations()
        root._finishTransition()
    }

    function _showFirstSource(src: string, key: string): void {
        root._clearAll()
        root._displayedSrc = src
        root._displayedKey = key
        layerA.source = src
        root._resetLayer(layerA, true)
    }

    function _promotePendingInstantly(): void {
        const incoming = root._backLayer
        const outgoing = root._frontLayer
        root._displayedSrc = root._pendingSrc
        root._displayedKey = root._pendingKey
        root._pendingSrc = ""
        root._pendingKey = ""
        root._waitingForReady = false
        root.transitionStarted(root._displayedSrc)
        root._resetLayer(incoming, true)
        root._clearLayer(outgoing)
        root._frontIndex = root._frontIndex === 0 ? 1 : 0
        root.transitionFinished(root._displayedSrc)
    }

    function _startTransitionWhenReady(): void {
        if (!root._waitingForReady || !root._pendingSrc.length)
            return

        const incoming = root._backLayer
        if (incoming.status !== Image.Ready
                || incoming.source.toString() !== root._pendingSrc)
            return

        if (!root._frontLayer.visible
                || root._frontLayer.status !== Image.Ready
                || !root.animateChanges) {
            root._promotePendingInstantly()
            return
        }

        root._transitionIncoming = incoming
        root._transitionOutgoing = root._frontLayer
        root._transitionRunning = true
        root._displayedSrc = root._pendingSrc
        root._displayedKey = root._pendingKey
        root._waitingForReady = false
        root._pendingSrc = ""
        root._pendingKey = ""

        const distance = Math.min(18, Math.max(8, root.width * 0.28))
        root._transitionIncoming.visible = true
        root._transitionIncoming.x = root._pendingDirection * distance
        root._transitionIncoming.opacity = 0
        root._transitionOutgoing.visible = true
        root._transitionOutgoing.x = 0
        root._transitionOutgoing.opacity = 1
        root.transitionStarted(root._displayedSrc)
        if (root._frontIndex === 0) {
            slideAToB.dir = root._pendingDirection
            slideAToB.distance = distance
            slideAToB.restart()
        } else {
            slideBToA.dir = root._pendingDirection
            slideBToA.distance = distance
            slideBToA.restart()
        }
    }

    function _queueSource(src: string, key: string): void {
        root._settleTransition()
        emptySourceTimer.stop()

        if (src === root._displayedSrc) {
            root._displayedKey = key
            return
        }
        if (src === root._pendingSrc) {
            root._pendingKey = key
            root._pendingDirection = root.slideDirection < 0 ? -1 : 1
            return
        }

        root._waitingForReady = false
        root._pendingSrc = src
        root._pendingKey = key
        root._pendingDirection = root.slideDirection < 0 ? -1 : 1

        const incoming = root._backLayer
        root._clearLayer(incoming)
        incoming.source = src
        incoming.x = root._pendingDirection * Math.min(18, Math.max(8, root.width * 0.28))
        incoming.opacity = 0
        incoming.visible = true
        root._waitingForReady = true
        root._startTransitionWhenReady()
    }

    function _handleSourceChange(): void {
        const src = root.source
        const key = root.transitionKey && root.transitionKey.length > 0
            ? root.transitionKey : src

        if (!src || src.length === 0) {
            sourceSettleTimer.stop()
            root._candidateSrc = ""
            root._candidateKey = ""
            root._waitingForReady = false
            root._pendingSrc = ""
            root._pendingKey = ""
            if (!root._transitionRunning)
                root._clearLayer(root._backLayer)
            if (root._hasRenderableArt)
                emptySourceTimer.restart()
            else
                root._clearAll()
            return
        }

        emptySourceTimer.stop()
        if (!root._displayedSrc.length) {
            root._showFirstSource(src, key)
            return
        }
        if (src === root._displayedSrc) {
            sourceSettleTimer.stop()
            root._candidateSrc = ""
            root._candidateKey = ""
            root._displayedKey = key
            return
        }

        root._candidateSrc = src
        root._candidateKey = key
        root._candidateDirection = root.slideDirection < 0 ? -1 : 1
        sourceSettleTimer.restart()
    }

    Image {
        id: layerA
        width: root.width
        height: root.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: false
        sourceSize.width: Math.max(1, Math.round(root.width * 2))
        sourceSize.height: Math.max(1, Math.round(root.height * 2))
        onStatusChanged: {
            if (root._backLayer === layerA)
                root._startTransitionWhenReady()
        }
        layer.enabled: root.effectEnabled
        layer.effect: MultiEffect {
            blurEnabled: root.blurEnabled
            blur: root.blur
            blurMax: root.blurMax
            saturation: root.saturation
        }
    }

    Image {
        id: layerB
        width: root.width
        height: root.height
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        visible: false
        sourceSize.width: Math.max(1, Math.round(root.width * 2))
        sourceSize.height: Math.max(1, Math.round(root.height * 2))
        onStatusChanged: {
            if (root._backLayer === layerB)
                root._startTransitionWhenReady()
        }
        layer.enabled: root.effectEnabled
        layer.effect: MultiEffect {
            blurEnabled: root.blurEnabled
            blur: root.blur
            blurMax: root.blurMax
            saturation: root.saturation
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.placeholderColor
        visible: !root._hasRenderableArt

        MaterialSymbol {
            anchors.centerIn: parent
            text: "music_note"
            iconSize: root.iconSize
            color: root.iconColor
        }
    }

    ParallelAnimation {
        id: slideAToB
        property int dir: 1
        property real distance: 12

        NumberAnimation {
            target: layerB
            property: "x"
            from: slideAToB.dir * slideAToB.distance
            to: 0
            duration: root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardDecel
        }
        NumberAnimation {
            target: layerB
            property: "opacity"
            from: 0
            to: 1
            duration: root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardDecel
        }
        NumberAnimation {
            target: layerA
            property: "x"
            from: 0
            to: -slideAToB.dir * slideAToB.distance * 0.65
            duration: root.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardAccel
        }
        NumberAnimation {
            target: layerA
            property: "opacity"
            from: 1
            to: 0
            duration: root.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardAccel
        }
        onFinished: root._finishTransition()
    }

    ParallelAnimation {
        id: slideBToA
        property int dir: 1
        property real distance: 12

        NumberAnimation {
            target: layerA
            property: "x"
            from: slideBToA.dir * slideBToA.distance
            to: 0
            duration: root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardDecel
        }
        NumberAnimation {
            target: layerA
            property: "opacity"
            from: 0
            to: 1
            duration: root.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardDecel
        }
        NumberAnimation {
            target: layerB
            property: "x"
            from: 0
            to: -slideBToA.dir * slideBToA.distance * 0.65
            duration: root.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardAccel
        }
        NumberAnimation {
            target: layerB
            property: "opacity"
            from: 1
            to: 0
            duration: root.exitDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.standardAccel
        }
        onFinished: root._finishTransition()
    }

    Timer {
        id: sourceSettleTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (!root._candidateSrc.length
                    || root.source !== root._candidateSrc)
                return
            const src = root._candidateSrc
            const key = root._candidateKey
            root._candidateSrc = ""
            root._candidateKey = ""
            root._pendingDirection = root._candidateDirection
            root._queueSource(src, key)
        }
    }

    Timer {
        id: emptySourceTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (!root.source.length)
                root._clearAll()
        }
    }

    onSourceChanged: root._handleSourceChange()
    Component.onCompleted: root._handleSourceChange()
}
