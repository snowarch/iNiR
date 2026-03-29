pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

import qs.modules.common

Item {
    id: root

    // ── Public API ──────────────────────────────────────────────────────
    property string source
    property int fillMode: Image.PreserveAspectCrop
    property size sourceSize

    // Transition config — read from Config with sensible defaults
    property int transitionBaseDuration: Config.options?.background?.transition?.duration ?? 800
    property int transitionDuration: Appearance.calcEffectiveDuration(transitionBaseDuration)
    property string transitionType: Config.options?.background?.transition?.type ?? "crossfade"
    property string transitionDirection: Config.options?.background?.transition?.direction ?? "right"
    property bool enableTransitions: Config.options?.background?.transition?.enable ?? true
    readonly property list<real> _defaultBezier: [0.54, 0.0, 0.34, 0.99]
    readonly property var _configuredBezier: Config.options?.background?.transition?.bezier ?? _defaultBezier
    readonly property list<real> _effectiveBezier: _normalizeBezier(_configuredBezier)
    readonly property list<real> transitionBezierCurve: [_effectiveBezier[0], _effectiveBezier[1], _effectiveBezier[2], _effectiveBezier[3], 1, 1]
    readonly property list<real> transitionMoveCurve: _positionCurveFor(_effectiveType)
    readonly property int transitionMoveEasingType: Easing.BezierSpline

    // Read-only state — `ready` stays true during transitions so that
    // external consumers (blur layers, visibility guards) don't flicker.
    readonly property bool ready: img0.status === Image.Ready || img1.status === Image.Ready
    readonly property alias activeIndex: internal.activeIndex

    // Transition signals for external consumers (e.g. defer magick identify)
    signal transitionStarted()
    signal transitionFinished()

    // ── Internal state ─────────────────────────────────────────────────
    property bool _transitioning: false
    readonly property bool _canTransition: enableTransitions && Appearance.animationsEnabled && _normalizedTransitionType(transitionType) !== "none"
    readonly property string _effectiveType: _canTransition ? _normalizedTransitionType(transitionType) : "none"
    readonly property real _zoomEnterFrom: 1.12
    readonly property real _zoomExitTo: 0.9
    readonly property real _wipeIncomingParallax: 0.08
    readonly property real _wipeOutgoingParallax: 0.045
    readonly property real _slideExitDistance: 0.32
    readonly property real _pushDistance: 1.05
    readonly property real _crossfadeIncomingScale: 1.018
    readonly property real _crossfadeOutgoingScale: 0.985
    readonly property real _blurFadeIncomingScale: 1.035
    readonly property real _blurFadeOutgoingScale: 0.96
    readonly property real _blurFadeMax: 0.82
    readonly property list<real> transitionProgressCurve: _progressCurveFor(_effectiveType)
    property real _transitionWidthSnapshot: 0
    property real _transitionHeightSnapshot: 0
    property size _transitionSourceSizeSnapshot: Qt.size(0, 0)

    function _normalizeBezier(raw): list<real> {
        if (!raw || raw.length !== 4)
            return _defaultBezier

        const result = []
        for (let i = 0; i < 4; i++) {
            const value = Number(raw[i])
            if (!Number.isFinite(value))
                return _defaultBezier
            result.push(value)
        }
        return result
    }

    function _positionCurveFor(type: string): list<real> {
        switch (type) {
        case "slide":
            return Appearance.animationCurves.expressiveSlowSpatial
        case "push":
            return Appearance.animationCurves.expressiveDefaultSpatial
        case "wipe":
            return Appearance.animationCurves.expressiveDefaultSpatial
        default:
            return transitionBezierCurve
        }
    }

    function _progressCurveFor(type: string): list<real> {
        switch (type) {
        case "slide":
            return _positionCurveFor(type)
        case "push":
            return _positionCurveFor(type)
        case "wipe":
            return _positionCurveFor(type)
        case "zoom":
            return Appearance.animationCurves.emphasizedDecel
        case "fadeThrough":
            return Appearance.animationCurves.emphasized
        case "blurFade":
            return Appearance.animationCurves.expressiveEffects
        default:
            return transitionBezierCurve
        }
    }

    function _clamp01(value: real): real {
        return Math.max(0, Math.min(1, value))
    }

    // Instantly complete the current transition so a new one can begin.
    // Called when a new wallpaper arrives while a transition is in progress.
    function _fastForwardTransition(): void {
        if (!root._transitioning) return
        transitionAnim.stop()
        transitionState.progress = 0
        if (internal.transitionToIndex >= 0)
            internal.activeIndex = internal.transitionToIndex
        _transitioning = false
        internal.displayedSource = internal.activeImage().source
        internal.loadingSource = ""
        if (internal.pendingSource === internal.displayedSource)
            internal.pendingSource = ""
        internal.transitionFromIndex = -1
        internal.transitionToIndex = -1
        root._transitionWidthSnapshot = 0
        root._transitionHeightSnapshot = 0
        root._transitionSourceSizeSnapshot = Qt.size(0, 0)
        transitionFinished()
    }

    function _normalizedTransitionType(rawType: string): string {
        switch (String(rawType ?? "crossfade")) {
        case "none":
            return "none"
        case "simple":
        case "fade":
            return "crossfade"
        case "left":
        case "right":
        case "top":
        case "bottom":
            return "slide"
        case "wave":
        case "wipe":
            return "wipe"
        case "grow":
        case "center":
        case "outer":
        case "any":
        case "random":
            return "zoom"
        default:
            return String(rawType ?? "crossfade")
        }
    }

    function _resolvedTransitionDirection(): string {
        if (["left", "right", "top", "bottom"].includes(transitionType))
            return transitionType
        return transitionDirection
    }

    function _lerp(from: real, to: real, progress: real): real {
        return from + ((to - from) * progress)
    }

    function _isVerticalDirection(): bool {
        const direction = _resolvedTransitionDirection()
        return direction === "top" || direction === "bottom"
    }

    function _directionSign(): real {
        const direction = _resolvedTransitionDirection()
        return direction === "right" || direction === "bottom" ? 1 : -1
    }

    function _travelDistance(): real {
        return _isVerticalDirection() ? root.height : root.width
    }

    function _transitionWidth(): real {
        return Math.max(1, root._transitioning ? root._transitionWidthSnapshot : root.width)
    }

    function _transitionHeight(): real {
        return Math.max(1, root._transitioning ? root._transitionHeightSnapshot : root.height)
    }

    function _slotRenderWidth(slotIndex: int): real {
        if (_transitioning && internal.transitionFromIndex === slotIndex)
            return _transitionWidth()
        return root.width
    }

    function _slotRenderHeight(slotIndex: int): real {
        if (_transitioning && internal.transitionFromIndex === slotIndex)
            return _transitionHeight()
        return root.height
    }

    function _slotSourceSize(slotIndex: int): size {
        if (_transitioning && internal.transitionFromIndex === slotIndex)
            return _transitionSourceSizeSnapshot
        return root.sourceSize
    }

    QtObject {
        id: transitionState
        property real progress: 0
    }

    NumberAnimation {
        id: transitionAnim
        target: transitionState
        property: "progress"
        from: 0
        to: 1
        duration: root.transitionDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.transitionProgressCurve
        onFinished: root._onTransitionEnd()
    }

    QtObject {
        id: internal
        property int activeIndex: 0
        property int transitionFromIndex: -1
        property int transitionToIndex: -1
        property string displayedSource: ""
        property string pendingSource: ""
        property string loadingSource: ""

        function slotImage(slotIndex: int): Item {
            return slotIndex === 0 ? img0 : img1
        }

        function activeImage(): Item {
            return slotImage(activeIndex)
        }

        function inactiveImage(): Item {
            return slotImage(activeIndex === 0 ? 1 : 0)
        }

        function resetTransition(): void {
            transitionAnim.stop()
            transitionState.progress = 0
            transitionFromIndex = -1
            transitionToIndex = -1
            root._transitionWidthSnapshot = 0
            root._transitionHeightSnapshot = 0
            root._transitionSourceSizeSnapshot = Qt.size(0, 0)
        }

        function switchTo(newSource: string): void {
            if (newSource === "") {
                resetTransition()
                root._transitioning = false
                img0.source = ""
                img1.source = ""
                displayedSource = ""
                pendingSource = ""
                loadingSource = ""
                activeIndex = 0
                return
            }

            pendingSource = newSource

            if (!root._canTransition) {
                const active = activeImage()
                active.source = newSource
                if (activeIndex === 0)
                    img1.source = ""
                else
                    img0.source = ""
                displayedSource = newSource
                pendingSource = ""
                loadingSource = ""
                resetTransition()
                return
            }

            if (newSource === displayedSource && !root._transitioning && loadingSource === "") {
                pendingSource = ""
                loadingSource = ""
                return
            }

            if (root._transitioning) {
                // Fast-forward current transition so the new wallpaper
                // starts loading immediately instead of waiting.
                root._fastForwardTransition()
                // pendingSource was already set above; now load it.
            }

            loadPending()
        }

        function loadPending(): void {
            if (root._transitioning)
                return

            if (pendingSource === "" || pendingSource === displayedSource) {
                pendingSource = ""
                loadingSource = ""
                return
            }

            const inactive = inactiveImage()
            if (inactive.source === pendingSource && inactive.status === Image.Ready) {
                loadingSource = ""
                performSwitch()
                return
            }

            loadingSource = pendingSource
            inactive.source = pendingSource
        }

        function handleReady(slotIndex: int, loadedSource: string): void {
            if (loadedSource === "" || loadedSource !== pendingSource)
                return

            const inactiveIndex = activeIndex === 0 ? 1 : 0
            if (slotIndex !== inactiveIndex || root._transitioning)
                return

            loadingSource = ""
            performSwitch()
        }

        function handleError(slotIndex: int, failedSource: string): void {
            const inactiveIndex = activeIndex === 0 ? 1 : 0
            if (slotIndex !== inactiveIndex)
                return

            if (failedSource !== pendingSource && failedSource !== loadingSource)
                return

            loadingSource = ""
            pendingSource = ""
        }

        function performSwitch(): void {
            if (pendingSource === "" || pendingSource === displayedSource)
                return

            root._transitioning = true
            root._transitionWidthSnapshot = Math.max(1, root.width)
            root._transitionHeightSnapshot = Math.max(1, root.height)
            root._transitionSourceSizeSnapshot = Qt.size(
                Math.max(0, Number(root.sourceSize.width) || 0),
                Math.max(0, Number(root.sourceSize.height) || 0)
            )
            transitionStarted()
            transitionFromIndex = activeIndex
            transitionToIndex = activeIndex === 0 ? 1 : 0
            transitionState.progress = 0
            transitionAnim.restart()
        }
    }

    function _onTransitionEnd(): void {
        transitionAnim.stop()
        const fromIndex = internal.transitionFromIndex
        if (internal.transitionToIndex >= 0)
            internal.activeIndex = internal.transitionToIndex
        _transitioning = false
        transitionState.progress = 0
        internal.displayedSource = internal.activeImage().source
        internal.loadingSource = ""
        if (internal.pendingSource === internal.displayedSource)
            internal.pendingSource = ""
        internal.transitionFromIndex = -1
        internal.transitionToIndex = -1

        // Release the old wallpaper texture from the inactive slot.
        // Without this, every wallpaper ever displayed stays in Qt's
        // QPixmapCache because cache:true retains decoded pixmaps by URL.
        // Only clear when there's no pending source that needs the slot.
        if (internal.pendingSource === "" || internal.pendingSource === internal.displayedSource) {
            internal.inactiveImage().source = ""
        }

        transitionFinished()
        if (internal.pendingSource !== "" && internal.pendingSource !== internal.displayedSource)
            internal.loadPending()
    }

    onSourceChanged: internal.switchTo(source)

    clip: true

    function _transitionDirection(): int {
        return _directionSign()
    }

    function _slotVisible(slotIndex: int): bool {
        if (_transitioning)
            return internal.transitionFromIndex === slotIndex || internal.transitionToIndex === slotIndex
        return internal.activeIndex === slotIndex && internal.slotImage(slotIndex).source !== ""
    }

    function _slotOpacity(slotIndex: int): real {
        if (!_transitioning)
            return internal.activeIndex === slotIndex ? 1 : 0

        const progress = _clamp01(transitionState.progress)
        const isFrom = internal.transitionFromIndex === slotIndex
        const isTo = internal.transitionToIndex === slotIndex

        switch (_effectiveType) {
        case "slide":
        case "push":
            return (isFrom || isTo) ? 1 : 0
        case "wipe":
            return isFrom ? _lerp(1, 0.86, progress) : isTo ? _lerp(0.74, 1, progress) : 0
        case "zoom":
            return isFrom ? (1 - progress) : isTo ? progress : 0
        case "blurFade":
            return isFrom ? (1 - progress) : isTo ? _clamp01((progress - 0.08) / 0.92) : 0
        case "fadeThrough": {
            const outProgress = _clamp01(progress / 0.4)
            const inProgress = progress <= 0.5 ? 0 : _clamp01((progress - 0.5) / 0.5)
            return isFrom ? (1 - outProgress) : isTo ? inProgress : 0
        }
        default:
            return isFrom ? (1 - progress) : isTo ? progress : 0
        }
    }

    function _slotX(slotIndex: int): real {
        if (!_transitioning)
            return 0

        const progress = _clamp01(transitionState.progress)
        const travelWidth = _transitionWidth()
        const vertical = _isVerticalDirection()
        const direction = _transitionDirection()
        const isFrom = internal.transitionFromIndex === slotIndex
        const isTo = internal.transitionToIndex === slotIndex

        if (vertical)
            return 0

        switch (_effectiveType) {
        case "slide":
            if (isFrom)
                return -direction * travelWidth * _slideExitDistance * progress
            if (isTo)
                return direction * travelWidth * (1 - progress)
            return 0
        case "push":
            if (isFrom)
                return -direction * travelWidth * _pushDistance * progress
            if (isTo)
                return direction * travelWidth * _pushDistance * (1 - progress)
            return 0
        case "wipe":
            if (isFrom)
                return -direction * travelWidth * _wipeOutgoingParallax * progress
            if (isTo)
                return direction * travelWidth * _wipeIncomingParallax * (1 - progress)
            return 0
        default:
            return 0
        }
    }

    function _slotY(slotIndex: int): real {
        if (!_transitioning)
            return 0

        const progress = _clamp01(transitionState.progress)
        const travelHeight = _transitionHeight()
        const vertical = _isVerticalDirection()
        const direction = _transitionDirection()
        const isFrom = internal.transitionFromIndex === slotIndex
        const isTo = internal.transitionToIndex === slotIndex

        if (!vertical)
            return 0

        switch (_effectiveType) {
        case "slide":
            if (isFrom)
                return -direction * travelHeight * _slideExitDistance * progress
            if (isTo)
                return direction * travelHeight * (1 - progress)
            return 0
        case "push":
            if (isFrom)
                return -direction * travelHeight * _pushDistance * progress
            if (isTo)
                return direction * travelHeight * _pushDistance * (1 - progress)
            return 0
        case "wipe":
            if (isFrom)
                return -direction * travelHeight * _wipeOutgoingParallax * progress
            if (isTo)
                return direction * travelHeight * _wipeIncomingParallax * (1 - progress)
            return 0
        default:
            return 0
        }
    }

    function _slotZ(slotIndex: int): real {
        if (_transitioning)
            return internal.transitionToIndex === slotIndex ? 2 : internal.transitionFromIndex === slotIndex ? 1 : 0
        return internal.activeIndex === slotIndex ? 1 : 0
    }

    function _slotScale(slotIndex: int): real {
        if (!_transitioning) {
            if (_effectiveType === "zoom")
                return internal.activeIndex === slotIndex ? 1 : _zoomEnterFrom
            return 1
        }

        const progress = _clamp01(transitionState.progress)
        const isFrom = internal.transitionFromIndex === slotIndex
        const isTo = internal.transitionToIndex === slotIndex

        switch (_effectiveType) {
        case "crossfade":
            if (isFrom)
                return _lerp(1, _crossfadeOutgoingScale, progress)
            if (isTo)
                return _lerp(_crossfadeIncomingScale, 1, progress)
            return 1
        case "wipe":
            if (isFrom)
                return _lerp(1, 0.975, progress)
            if (isTo)
                return _lerp(1.04, 1, progress)
            return 1
        case "zoom":
            if (isFrom)
                return _lerp(1, _zoomExitTo, progress)
            if (isTo)
                return _lerp(_zoomEnterFrom, 1, progress)
            return 1
        case "blurFade":
            if (isFrom)
                return _lerp(1, _blurFadeOutgoingScale, progress)
            if (isTo)
                return _lerp(_blurFadeIncomingScale, 1, progress)
            return 1
        case "fadeThrough": {
            const outProgress = _clamp01(progress / 0.4)
            const inProgress = progress <= 0.5 ? 0 : _clamp01((progress - 0.5) / 0.5)
            if (isFrom)
                return _lerp(1, 0.96, outProgress)
            if (isTo)
                return _lerp(0.92, 1, inProgress)
            return 1
        }
        default:
            return 1
        }
    }

    function _slotBlur(slotIndex: int): real {
        if (!_transitioning || _effectiveType !== "blurFade")
            return 0
        if (internal.transitionFromIndex !== slotIndex)
            return 0
        return _blurFadeMax * _clamp01(transitionState.progress)
    }

    function _slotClipEnabled(slotIndex: int): bool {
        return _transitioning && _effectiveType === "wipe" && internal.transitionToIndex === slotIndex
    }

    function _slotWrapperX(slotIndex: int): real {
        if (!_slotClipEnabled(slotIndex) || _isVerticalDirection())
            return 0

        const progress = _clamp01(transitionState.progress)
        const width = _transitionWidth() * progress
        return _resolvedTransitionDirection() === "right" ? _transitionWidth() - width : 0
    }

    function _slotWrapperY(slotIndex: int): real {
        if (!_slotClipEnabled(slotIndex) || !_isVerticalDirection())
            return 0

        const progress = _clamp01(transitionState.progress)
        const height = _transitionHeight() * progress
        return _resolvedTransitionDirection() === "bottom" ? _transitionHeight() - height : 0
    }

    function _slotWrapperWidth(slotIndex: int): real {
        if (!_slotClipEnabled(slotIndex) || _isVerticalDirection())
            return _slotRenderWidth(slotIndex)
        return Math.max(1, _transitionWidth() * _clamp01(transitionState.progress))
    }

    function _slotWrapperHeight(slotIndex: int): real {
        if (!_slotClipEnabled(slotIndex) || !_isVerticalDirection())
            return _slotRenderHeight(slotIndex)
        return Math.max(1, _transitionHeight() * _clamp01(transitionState.progress))
    }

    Item {
        id: slot0
        x: root._slotWrapperX(0)
        y: root._slotWrapperY(0)
        width: root._slotWrapperWidth(0)
        height: root._slotWrapperHeight(0)
        clip: root._slotClipEnabled(0)
        visible: root._slotVisible(0)
        z: root._slotZ(0)

        Image {
            id: img0
            x: root._slotX(0)
            y: root._slotY(0)
            width: root._slotRenderWidth(0)
            height: root._slotRenderHeight(0)
            fillMode: root.fillMode
            sourceSize: root._slotSourceSize(0)
            asynchronous: true
            cache: false
            mipmap: true
            smooth: true
            opacity: root._slotOpacity(0)
            scale: root._slotScale(0)
            transformOrigin: Item.Center

            onStatusChanged: {
                if (status === Image.Ready)
                    internal.handleReady(0, source)
                else if (status === Image.Error)
                    internal.handleError(0, source)
            }

            layer.enabled: root._canTransition && Appearance.effectsEnabled
                           && root._effectiveType === "blurFade"
                           && root._transitioning
                           && internal.transitionFromIndex === 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root._slotBlur(0)
                blurMax: 64
            }
        }
    }

    Item {
        id: slot1
        x: root._slotWrapperX(1)
        y: root._slotWrapperY(1)
        width: root._slotWrapperWidth(1)
        height: root._slotWrapperHeight(1)
        clip: root._slotClipEnabled(1)
        visible: root._slotVisible(1)
        z: root._slotZ(1)

        Image {
            id: img1
            x: root._slotX(1)
            y: root._slotY(1)
            width: root._slotRenderWidth(1)
            height: root._slotRenderHeight(1)
            fillMode: root.fillMode
            sourceSize: root._slotSourceSize(1)
            asynchronous: true
            cache: false
            mipmap: true
            smooth: true
            opacity: root._slotOpacity(1)
            scale: root._slotScale(1)
            transformOrigin: Item.Center

            onStatusChanged: {
                if (status === Image.Ready)
                    internal.handleReady(1, source)
                else if (status === Image.Error)
                    internal.handleError(1, source)
            }

            layer.enabled: root._canTransition && Appearance.effectsEnabled
                           && root._effectiveType === "blurFade"
                           && root._transitioning
                           && internal.transitionFromIndex === 1
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root._slotBlur(1)
                blurMax: 64
            }
        }
    }

    Component.onCompleted: {
        if (root.source !== "") {
            img0.source = root.source
            internal.displayedSource = root.source
        }
    }
}
