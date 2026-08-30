pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    required property var pages
    required property int requestedIndex
    property bool loadEnabled: true
    property int cacheLimit: 2

    readonly property int currentIndex: _currentIndex
    readonly property bool error: _errorIndex === requestedIndex
    readonly property Item currentItem: {
        void(_statusRevision)
        const loader = _loaderFor(_currentIndex)
        return loader?.item ?? null
    }
    readonly property bool loading: {
        void(_statusRevision)
        const currentLoader = _loaderFor(_currentIndex)
        if (currentLoader?.status === Loader.Loading)
            return true
        const pendingLoader = _loaderFor(_pendingIndex)
        return pendingLoader?.status === Loader.Loading
    }

    property int _currentIndex: -1
    property int _pendingIndex: -1
    property int _direction: 1
    property bool _transitionRunning: false
    property var _retainedIndices: []
    property var _lruIndices: []
    property int _statusRevision: 0
    property int _errorIndex: -1

    clip: _transitionRunning

    function _sourceFor(index) {
        if (index < 0 || index >= pages.length)
            return ""
        return pages[index]?.component ?? ""
    }

    function _loaderFor(index) {
        if (index < 0 || index >= pageRepeater.count)
            return null
        return pageRepeater.itemAt(index)
    }

    function _syncResidency() {
        for (let index = 0; index < pageRepeater.count; index++) {
            const loader = pageRepeater.itemAt(index)
            if (!loader)
                continue
            const shouldBeActive = loadEnabled
                && _retainedIndices.indexOf(index) >= 0
            if (loader.active !== shouldBeActive)
                loader.active = shouldBeActive
        }
    }

    function _retain(index) {
        if (index < 0)
            return

        let retained = _retainedIndices.slice()
        if (retained.indexOf(index) < 0) {
            retained.push(index)
            _retainedIndices = retained
        }

        let lru = _lruIndices.filter(value => value !== index)
        lru.push(index)
        _lruIndices = lru
        _syncResidency()
    }

    function _trimCache() {
        const limit = Math.max(2, cacheLimit)
        let retained = _retainedIndices.slice()
        let lru = _lruIndices.slice()

        while (retained.length > limit) {
            let evictIndex = -1
            for (let i = 0; i < lru.length; i++) {
                const candidate = lru[i]
                if (candidate !== _currentIndex
                        && candidate !== _pendingIndex
                        && candidate !== requestedIndex) {
                    evictIndex = candidate
                    lru.splice(i, 1)
                    break
                }
            }

            if (evictIndex < 0)
                break
            retained = retained.filter(value => value !== evictIndex)
        }

        _retainedIndices = retained
        _lruIndices = lru.filter(value => retained.indexOf(value) >= 0)
        _syncResidency()
    }

    function _reset() {
        switchAnimation.stop()
        _transitionRunning = false
        _currentIndex = -1
        _pendingIndex = -1
        _retainedIndices = []
        _lruIndices = []
        _errorIndex = -1
        _syncResidency()
        _statusRevision++
    }

    function _requestPage() {
        if (!loadEnabled || requestedIndex < 0 || requestedIndex >= pages.length)
            return

        if (_transitionRunning)
            switchAnimation.complete()

        if (_currentIndex < 0) {
            _currentIndex = requestedIndex
            _errorIndex = -1
            const loader = _loaderFor(_currentIndex)
            if (loader) {
                loader.opacity = 1
                loader.x = 0
            }
            _retain(_currentIndex)
            _trimCache()
            return
        }

        if (requestedIndex === _currentIndex) {
            if (_errorIndex === requestedIndex) {
                _errorIndex = -1
                _retain(_currentIndex)
            }
            _retain(_currentIndex)
            _trimCache()
            return
        }

        if (_pendingIndex >= 0) {
            const stalePending = _loaderFor(_pendingIndex)
            if (stalePending) {
                stalePending.opacity = 0
                stalePending.x = 0
            }
        }

        _direction = requestedIndex >= _currentIndex ? 1 : -1
        _pendingIndex = requestedIndex
        _errorIndex = -1

        const pendingLoader = _loaderFor(_pendingIndex)
        if (pendingLoader) {
            pendingLoader.opacity = 0
            pendingLoader.x = _direction * Appearance.sizes.spacingMedium * 2
        }

        // Pending pages incubate while the current page stays visible. The LRU
        // keeps completed revisits cheap without blocking navigation on creation.
        _retain(_pendingIndex)

        Qt.callLater(function() {
            const loader = root._loaderFor(root._pendingIndex)
            if (loader)
                root._handleStatus(root._pendingIndex, loader.status)
        })
    }

    function _handleStatus(index, status) {
        _statusRevision++

        if (status === Loader.Error && (index === _currentIndex || index === _pendingIndex)) {
            console.warn("SettingsPageHost: failed to load page", index, _sourceFor(index))
            _errorIndex = index
            if (index === _pendingIndex)
                _pendingIndex = -1

            _retainedIndices = _retainedIndices.filter(value => value !== index)
            _lruIndices = _lruIndices.filter(value => value !== index)
            _syncResidency()
            return
        }

        if (index === _currentIndex && _pendingIndex < 0 && status === Loader.Ready) {
            if (_errorIndex === index)
                _errorIndex = -1
            const currentLoader = _loaderFor(index)
            if (currentLoader) {
                currentLoader.opacity = 1
                currentLoader.x = 0
            }
            return
        }

        if (index !== _pendingIndex || _transitionRunning)
            return

        if (status !== Loader.Ready)
            return

        if (_pendingIndex !== requestedIndex) {
            const staleLoader = _loaderFor(_pendingIndex)
            if (staleLoader) {
                staleLoader.opacity = 0
                staleLoader.x = 0
            }
            _pendingIndex = -1
            Qt.callLater(root._requestPage)
            return
        }

        if (!Appearance.animationsEnabled || Appearance.animation.elementMoveFast.duration <= 0) {
            _finishSwap()
            return
        }

        const currentLoader = _loaderFor(_currentIndex)
        const pendingLoader = _loaderFor(_pendingIndex)
        if (!currentLoader || !pendingLoader) {
            _finishSwap()
            return
        }

        currentFade.target = currentLoader
        pendingFade.target = pendingLoader
        pendingSlide.target = pendingLoader
        _transitionRunning = true
        switchAnimation.start()
    }

    function _finishSwap() {
        if (_pendingIndex < 0)
            return

        const oldIndex = _currentIndex
        const nextIndex = _pendingIndex
        const oldLoader = _loaderFor(oldIndex)
        const nextLoader = _loaderFor(nextIndex)

        if (oldLoader) {
            oldLoader.opacity = 0
            oldLoader.x = 0
        }
        if (nextLoader) {
            nextLoader.opacity = 1
            nextLoader.x = 0
        }

        _currentIndex = nextIndex
        _pendingIndex = -1
        _transitionRunning = false
        _retain(_currentIndex)
        _trimCache()

        if (requestedIndex !== _currentIndex)
            Qt.callLater(root._requestPage)
    }

    onRequestedIndexChanged: Qt.callLater(root._requestPage)
    onLoadEnabledChanged: {
        if (loadEnabled)
            Qt.callLater(root._requestPage)
        else
            _reset()
    }
    onCacheLimitChanged: _trimCache()
    Component.onCompleted: Qt.callLater(root._requestPage)

    Repeater {
        id: pageRepeater
        model: root.pages.length

        delegate: Loader {
            id: pageLoader
            required property int index

            anchors.fill: parent
            // Imperative residency avoids a Loader construction feedback cycle.
            active: false
            source: root._sourceFor(index)
            asynchronous: index !== root._currentIndex
            visible: active && (index === root._currentIndex || index === root._pendingIndex)
            enabled: index === root._currentIndex
                && root._pendingIndex < 0
                && !root._transitionRunning
            z: index === root._pendingIndex ? 1 : 0
            layer.enabled: root._transitionRunning && visible

            onStatusChanged: root._handleStatus(index, status)
            onActiveChanged: {
                root._statusRevision++
                if (!active) {
                    opacity = 0
                    x = 0
                }
            }
        }

        onItemAdded: (index, item) => {
            item.active = root.loadEnabled
                && root._retainedIndices.indexOf(index) >= 0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.error
        color: SettingsMaterialPreset.cardColor
        z: 20

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 420)
            spacing: Appearance.sizes.spacingSmall

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "error"
                iconSize: Appearance.font.pixelSize.hugeass
                color: Appearance.colors.colError
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("This settings page could not be loaded.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Check iNiR logs for the QML error, then retry after correcting it.")
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
            }

            RippleButtonWithIcon {
                Layout.alignment: Qt.AlignHCenter
                materialIcon: "refresh"
                mainText: Translation.tr("Retry")
                onClicked: root._requestPage()
            }
        }
    }

    ParallelAnimation {
        id: switchAnimation

        NumberAnimation {
            id: currentFade
            property: "opacity"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            id: pendingFade
            property: "opacity"
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            id: pendingSlide
            property: "x"
            to: 0
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

        onFinished: root._finishSwap()
    }
}
