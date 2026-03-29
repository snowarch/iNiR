pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root

    signal closed
    signal activateWindow(int windowId)

    required property var itemSnapshot
    property int selectedIndex: 0
    property bool cardVisible: true
    property int availableWidth: 0
    property int availableHeight: 0
    readonly property int _effectiveAvailableWidth: availableWidth > 0 ? availableWidth : (parent ? parent.width : 0)
    readonly property int _effectiveAvailableHeight: availableHeight > 0 ? availableHeight : (parent ? parent.height : 0)

    // Slice geometry constants (scaled for better fit)
    readonly property int skewSliceWidth: 135
    readonly property int skewExpandedWidth: 924
    readonly property int skewSliceHeight: 520
    readonly property int skewOffset: 35
    readonly property int skewSliceSpacing: -22
    readonly property int skewVisibleCount: 12
    readonly property int skewCardWidth: 1600
    readonly property int skewCardHeight: root.skewSliceHeight + 40

    // Config getters for live updates
    function cfg() { return Config.options?.waffles?.altSwitcher ?? {} }
    function getPreset() { return cfg().preset ?? "thumbnails" }
    function getThumbnailWidth() { return cfg().thumbnailWidth ?? 280 }
    function getThumbnailHeight() { return cfg().thumbnailHeight ?? 180 }

    // Reactive properties that update when config changes
    property string preset: getPreset()
    property int thumbnailWidth: getThumbnailWidth()
    property int thumbnailHeight: getThumbnailHeight()

    property int columns: Math.min(5, Math.max(1, itemSnapshot?.length ?? 1))

    // Update properties when config changes
    Connections {
        target: Config
        function onOptionsChanged() {
            root.preset = root.getPreset()
            root.thumbnailWidth = root.getThumbnailWidth()
            root.thumbnailHeight = root.getThumbnailHeight()
        }
    }

    implicitWidth: contentLoader.item?.implicitWidth ?? 400
    implicitHeight: contentLoader.item?.implicitHeight ?? 300

    property real contentOpacity: 1
    property real contentScale: 1

    function prepareForOpen(): void {
        closeAnim.stop()
        openAnim.stop()

        if (root.preset === "skew") {
            root.contentOpacity = 1
            root.contentScale = 1
            return
        }

        root.contentOpacity = 0
        root.contentScale = 0.95
        openAnim.restart()
    }

    function syncVisualState(): void {
        closeAnim.stop()
        openAnim.stop()

        if (root.preset === "skew") {
            root.contentOpacity = 1
            root.contentScale = 1
            return
        }

        if (GlobalStates.waffleAltSwitcherOpen) {
            root.prepareForOpen()
            return
        }

        root.contentOpacity = 1
        root.contentScale = 1
    }

    Component.onCompleted: root.syncVisualState()
    onPresetChanged: root.syncVisualState()

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "contentOpacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "contentScale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "contentScale"; to: 0.95; duration: 150; easing.type: Easing.InCubic }
        }
        ScriptAction { script: root.closed() }
    }

    function close() {
        if (root.preset === "skew") {
            root.closed()
        } else {
            closeAnim.start()
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        opacity: root.contentOpacity
        scale: root.contentScale
        sourceComponent: {
            switch (root.preset) {
                case "compact": return compactPreset
                case "list": return listPreset
                case "skew": return skewPreset
                case "cards": return cardsPreset
                case "none": return nonePreset
                default: return thumbnailsPreset
            }
        }
    }

    // === PRESET: Thumbnails ===
    Component {
        id: thumbnailsPreset
        Column {
            spacing: 16
            Grid {
                columns: root.columns
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    WaffleAltSwitcherThumbnail {
                        required property var modelData
                        required property int index
                        item: modelData
                        selected: root.selectedIndex === index
                        thumbnailWidth: root.thumbnailWidth
                        thumbnailHeight: root.thumbnailHeight
                        onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: appNameText.implicitWidth + 32
                height: 36
                radius: Looks.radius.large
                color: Looks.colors.bg1Base
                WText {
                    id: appNameText
                    anchors.centerIn: parent
                    text: root.itemSnapshot?.[root.selectedIndex]?.appName ?? ""
                    font.pixelSize: Looks.font.pixelSize.large
                    color: Looks.colors.fg
                }
            }
        }
    }

    // === PRESET: Compact ===
    Component {
        id: compactPreset
        WPane {
            radius: Looks.radius.xLarge
            contentItem: Row {
                spacing: 4
                leftPadding: 8; rightPadding: 8; topPadding: 8; bottomPadding: 8
                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }
                    WaffleAltSwitcherTile {
                        required property var modelData
                        required property int index
                        item: modelData
                        selected: root.selectedIndex === index
                        compact: true
                        onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                    }
                }
            }
        }
    }

    // === PRESET: List ===
    Component {
        id: listPreset
        WPane {
            radius: Looks.radius.large

            contentItem: Column {
                spacing: 0

                RowLayout {
                    width: 400
                    height: 44

                    Item { width: 16 }
                    WText {
                        text: Translation.tr("Switch windows")
                        font.pixelSize: Looks.font.pixelSize.larger
                        font.weight: Looks.font.weight.strong
                        color: Looks.colors.fg
                    }
                    Item { Layout.fillWidth: true }
                    WText {
                        text: (root.itemSnapshot?.length ?? 0) + " " + Translation.tr("windows")
                        font.pixelSize: Looks.font.pixelSize.small
                        color: Looks.colors.subfg
                    }
                    Item { width: 16 }
                }

                WPanelSeparator { width: 400 }

                Column {
                    width: 400
                    topPadding: 8; bottomPadding: 8; leftPadding: 8; rightPadding: 8
                    spacing: 4

                    Repeater {
                        model: ScriptModel { values: root.itemSnapshot }
                        WaffleAltSwitcherTile {
                            required property var modelData
                            required property int index
                            width: 384
                            item: modelData
                            selected: root.selectedIndex === index
                            compact: false
                            onClicked: { root.selectedIndex = index; root.activateWindow(modelData.id) }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: skewPreset
        Item {
            id: skewPresetItem
            // Card container with fade-in (matching piixident structure)
            implicitWidth: root.skewCardWidth
            implicitHeight: root.skewCardHeight
            anchors.centerIn: parent

            opacity: root.cardVisible ? 1 : 0
            property bool animateIn: root.cardVisible

            onAnimateInChanged: {
                fadeInAnim.stop()
                if (animateIn) {
                    opacity = 0
                    fadeInAnim.start()
                }
            }

            NumberAnimation {
                id: fadeInAnim
                target: skewPresetItem
                property: "opacity"
                from: 0; to: 1
                duration: 400
                easing.type: Easing.OutCubic
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            Item {
                id: backgroundRect
                anchors.fill: parent
            }

            // Horizontal parallelogram slice list view (matching piixident)
            ListView {
                id: skewDeck
                anchors.top: parent.top
                anchors.topMargin: 15
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.skewExpandedWidth + (root.skewVisibleCount - 1) * (root.skewSliceWidth + root.skewSliceSpacing)

                currentIndex: root.selectedIndex
                orientation: ListView.Horizontal
                model: ScriptModel { values: root.itemSnapshot }
                spacing: root.skewSliceSpacing
                clip: false
                interactive: false
                flickDeceleration: 1500
                maximumFlickVelocity: 3000
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: root.skewExpandedWidth * 2
                highlightFollowsCurrentItem: true
                highlightMoveDuration: 350
                highlight: Item {}
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - root.skewExpandedWidth) / 2
                preferredHighlightEnd: (width + root.skewExpandedWidth) / 2
                header: Item { width: (skewDeck.width - root.skewExpandedWidth) / 2; height: 1 }
                footer: Item { width: (skewDeck.width - root.skewExpandedWidth) / 2; height: 1 }

                delegate: Item {
                    id: skewSlice
                    required property var modelData
                    required property int index
                    readonly property real viewX: x - skewDeck.contentX
                    readonly property real fadeZone: root.skewSliceWidth * 1.5
                    readonly property real edgeOpacity: {
                        if (fadeZone <= 0)
                            return 1.0
                        const center = viewX + width * 0.5
                        const leftFade = Math.min(1.0, Math.max(0.0, center / fadeZone))
                        const rightFade = Math.min(1.0, Math.max(0.0, (skewDeck.width - center) / fadeZone))
                        return Math.min(leftFade, rightFade)
                    }
                    width: ListView.isCurrentItem ? root.skewExpandedWidth : root.skewSliceWidth
                    height: skewDeck.height
                    z: ListView.isCurrentItem ? 100 : 50 - Math.min(Math.abs(index - root.selectedIndex), 50)
                    opacity: edgeOpacity

                    containmentMask: Item {
                        function contains(point) {
                            const w = skewSlice.width
                            const h = skewSlice.height
                            const sk = root.skewOffset
                            if (h <= 0 || w <= 0)
                                return false
                            const leftX = sk * (1.0 - point.y / h)
                            const rightX = w - sk * (point.y / h)
                            return point.x >= leftX && point.x <= rightX && point.y >= 0 && point.y <= h
                        }
                    }

                    property string previewUrl: ""

                    function refreshPreview(): void {
                        if (modelData?.id === undefined)
                            return
                        const url = WindowPreviewService.getPreviewUrl(modelData.id)
                        if (url && url.length > 0)
                            previewUrl = url
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Looks.transition.enabled ? 200 : 0
                            easing.type: Easing.OutQuad
                        }
                    }

                    Component.onCompleted: Qt.callLater(() => skewSlice.refreshPreview())

                    Connections {
                        target: WindowPreviewService
                        function onPreviewUpdated(updatedId: int): void {
                            if (updatedId === skewSlice.modelData?.id)
                                skewSlice.previewUrl = WindowPreviewService.getPreviewUrl(updatedId)
                        }
                        function onCaptureComplete(): void {
                            skewSlice.refreshPreview()
                        }
                    }

                    Canvas {
                        id: shadowCanvas
                        z: -1
                        anchors.fill: parent
                        anchors.margins: -10
                        property real shadowOffsetX: ListView.isCurrentItem ? 4 : 2
                        property real shadowOffsetY: ListView.isCurrentItem ? 10 : 5
                        property real shadowAlpha: ListView.isCurrentItem ? 0.6 : 0.4
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        onShadowAlphaChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            const ox = 10
                            const oy = 10
                            const w = skewSlice.width
                            const h = skewSlice.height
                            const sk = root.skewOffset
                            const sx = shadowOffsetX
                            const sy = shadowOffsetY
                            const layers = [
                                { dx: sx, dy: sy, alpha: shadowAlpha * 0.5 },
                                { dx: sx * 0.6, dy: sy * 0.6, alpha: shadowAlpha * 0.3 },
                                { dx: sx * 1.4, dy: sy * 1.4, alpha: shadowAlpha * 0.2 }
                            ]
                            for (let i = 0; i < layers.length; i++) {
                                const layer = layers[i]
                                ctx.globalAlpha = layer.alpha
                                ctx.fillStyle = "#000000"
                                ctx.beginPath()
                                ctx.moveTo(ox + sk + layer.dx, oy + layer.dy)
                                ctx.lineTo(ox + w + layer.dx, oy + layer.dy)
                                ctx.lineTo(ox + w - sk + layer.dx, oy + h + layer.dy)
                                ctx.lineTo(ox + layer.dx, oy + h + layer.dy)
                                ctx.closePath()
                                ctx.fill()
                            }
                        }
                    }

                    Item {
                        id: maskedBody
                        anchors.fill: parent
                        layer.enabled: true
                        layer.smooth: true
                        layer.samples: 4
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: ShaderEffectSource {
                                sourceItem: Item {
                                    width: maskedBody.width
                                    height: maskedBody.height
                                    layer.enabled: true
                                    layer.smooth: true
                                    layer.samples: 8

                                    Shape {
                                        anchors.fill: parent
                                        antialiasing: true
                                        preferredRendererType: Shape.CurveRenderer

                                        ShapePath {
                                            fillColor: "white"
                                            strokeColor: "transparent"
                                            startX: root.skewOffset
                                            startY: 0
                                            PathLine { x: skewSlice.width; y: 0 }
                                            PathLine { x: skewSlice.width - root.skewOffset; y: skewSlice.height }
                                            PathLine { x: 0; y: skewSlice.height }
                                            PathLine { x: root.skewOffset; y: 0 }
                                        }
                                    }
                                }
                            }
                            maskThresholdMin: 0.3
                            maskSpreadAtMin: 0.3
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Looks.colors.bgPanelFooter }
                                GradientStop { position: 1.0; color: Looks.colors.bg1Base }
                            }
                        }

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            source: skewSlice.previewUrl
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            asynchronous: true
                            cache: false
                            visible: status === Image.Ready && source.toString().length > 0
                            sourceSize.width: root.skewExpandedWidth
                            sourceSize.height: root.skewSliceHeight
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, ListView.isCurrentItem ? 0.0 : 0.4)

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            anchors.left: parent.left
                            anchors.leftMargin: root.skewOffset + 6
                            width: focusedLabel.width + 12
                            height: 20
                            radius: 10
                            color: Looks.colors.accent
                            visible: skewSlice.modelData?.isFocused ?? false
                            z: 10

                            WText {
                                id: focusedLabel
                                anchors.centerIn: parent
                                text: "FOCUSED"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Looks.colors.accentFg
                            }
                        }

                        Text {
                            id: bigIconFallback
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -20
                            text: "?"
                            property int iconSize: ListView.isCurrentItem ? 96 : 48
                            font.pixelSize: iconSize
                            font.family: Looks.font.family.ui
                            opacity: previewImage.visible ? 0.7 : 1.0
                            color: ListView.isCurrentItem
                                ? Looks.colors.accent
                                : Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.5)
                            visible: !(skewSlice.modelData?.icon ?? "")

                            Behavior on iconSize {
                                NumberAnimation { duration: Looks.transition.enabled ? 200 : 0; easing.type: Easing.OutQuad }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: Looks.transition.enabled ? 200 : 0 }
                            }

                            Behavior on color {
                                ColorAnimation { duration: Looks.transition.enabled ? 200 : 0 }
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: -20
                            width: ListView.isCurrentItem ? 96 : 48
                            height: width
                            source: skewSlice.modelData?.icon ?? ""
                            sourceSize: Qt.size(width, height)
                            fillMode: Image.PreserveAspectFit
                            opacity: previewImage.visible ? 0.7 : 1.0
                            smooth: true
                            visible: !!(skewSlice.modelData?.icon ?? "")

                            Behavior on width {
                                NumberAnimation { duration: Looks.transition.enabled ? 200 : 0; easing.type: Easing.OutQuad }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: Looks.transition.enabled ? 200 : 0 }
                            }
                        }

                        Rectangle {
                            id: nameLabel
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 40
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: nameLabelCol.width + 24
                            height: nameLabelCol.height + 16
                            radius: 6
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.5)
                            visible: ListView.isCurrentItem
                            opacity: ListView.isCurrentItem ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 200 }
                            }

                            Column {
                                id: nameLabelCol
                                anchors.centerIn: parent
                                spacing: 4

                                WText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (skewSlice.modelData?.appName ?? "Window").toUpperCase()
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    color: Looks.colors.accent
                                }

                                WText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const title = skewSlice.modelData?.title ?? ""
                                        return title.length > 60 ? title.substring(0, 60) + "…" : title
                                    }
                                    width: Math.min(implicitWidth, skewSlice.width - 80)
                                    font.pixelSize: Looks.font.pixelSize.small
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: root.skewOffset + 8
                            anchors.bottomMargin: 8
                            width: wsBadgeText.implicitWidth + 8
                            height: 16
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.4)
                            z: 10

                            WText {
                                id: wsBadgeText
                                anchors.centerIn: parent
                                text: "WS " + (skewSlice.modelData?.workspaceIdx ?? "")
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.92)
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            anchors.left: parent.left
                            anchors.leftMargin: root.skewOffset + 8
                            width: floatLabel.implicitWidth + 8
                            height: 16
                            radius: 4
                            color: Qt.rgba(0, 0, 0, 0.75)
                            border.width: 1
                            border.color: Qt.rgba(Looks.colors.accent.r, Looks.colors.accent.g, Looks.colors.accent.b, 0.4)
                            visible: skewSlice.modelData?.isFloating ?? false
                            z: 10

                            WText {
                                id: floatLabel
                                anchors.centerIn: parent
                                text: "FLOAT"
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.92)
                            }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            fillColor: "transparent"
                            strokeColor: ListView.isCurrentItem ? Looks.colors.accent : Qt.rgba(0, 0, 0, 0.6)
                            strokeWidth: ListView.isCurrentItem ? 3 : 1
                            Behavior on strokeColor { ColorAnimation { duration: Looks.transition.enabled ? 200 : 0 } }
                            startX: root.skewOffset
                            startY: 0
                            PathLine { x: skewSlice.width; y: 0 }
                            PathLine { x: skewSlice.width - root.skewOffset; y: skewSlice.height }
                            PathLine { x: 0; y: skewSlice.height }
                            PathLine { x: root.skewOffset; y: 0 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.selectedIndex = index
                    }
                }
            }

        }
    }

    // === PRESET: None (no UI, just switch) ===
    Component {
        id: nonePreset
        Item {
            implicitWidth: 1
            implicitHeight: 1
            visible: false
        }
    }


    // === PRESET: Cards (Fluent-style with shadows and acrylic) ===
    Component {
        id: cardsPreset
        Item {
            implicitWidth: cardsRow.width
            implicitHeight: cardsRow.height + selectedLabel.height + 24

            Row {
                id: cardsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Repeater {
                    model: ScriptModel { values: root.itemSnapshot }

                    Item {
                        required property var modelData
                        required property int index
                        width: 180
                        height: 200

                        // Shadow behind card
                        WRectangularShadow {
                            target: cardPane
                        }

                        // Main card using WPane
                        Rectangle {
                            id: cardPane
                            anchors.fill: parent
                            radius: Looks.radius.large
                            color: root.selectedIndex === index ? Looks.colors.accent : Looks.colors.bgPanelFooter
                            border.width: root.selectedIndex === index ? 0 : 1
                            border.color: Looks.colors.bg2Border
                            scale: cardMouse.pressed ? 0.95 : (cardMouse.containsMouse ? 1.02 : 1.0)
                            
                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                animation: ColorAnimation { duration: Looks.transition.enabled ? 70 : 0; easing.type: Easing.BezierSpline; easing.bezierCurve: Looks.transition.easing.bezierCurve.standard }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                // Icon area with gradient background
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: Looks.radius.medium
                                    color: root.selectedIndex === index 
                                        ? ColorUtils.transparentize(Looks.colors.accentFg, 0.9)
                                        : Looks.colors.bg1Base

                                    Image {
                                        anchors.centerIn: parent
                                        width: 72
                                        height: 72
                                        source: modelData?.icon ?? ""
                                        sourceSize: Qt.size(72, 72)
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }
                                }

                                // App name
                                WText {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: modelData?.appName ?? "Window"
                                    font.pixelSize: Looks.font.pixelSize.normal
                                    font.weight: Looks.font.weight.strong
                                    color: root.selectedIndex === index ? Looks.colors.accentFg : Looks.colors.fg
                                    elide: Text.ElideMiddle
                                }

                                // Workspace indicator
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    visible: (modelData?.workspaceIdx ?? 0) > 0
                                    width: wsCardText.implicitWidth + 12
                                    height: 20
                                    radius: Looks.radius.small
                                    color: root.selectedIndex === index 
                                        ? ColorUtils.transparentize(Looks.colors.accentFg, 0.8)
                                        : Looks.colors.bg2

                                    WText {
                                        id: wsCardText
                                        anchors.centerIn: parent
                                        text: Translation.tr("WS") + " " + (modelData?.workspaceIdx ?? "")
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: root.selectedIndex === index ? Looks.colors.accentFg : Looks.colors.subfg
                                    }
                                }
                            }

                            // Selection indicator at bottom
                            Rectangle {
                                visible: root.selectedIndex === index
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 8
                                width: 32
                                height: 4
                                radius: 2
                                color: Looks.colors.accentFg
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedIndex = index
                                root.activateWindow(modelData.id)
                            }
                        }
                    }
                }
            }

            // Window title label
            Rectangle {
                id: selectedLabel
                anchors.top: cardsRow.bottom
                anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(titleLabelText.implicitWidth + 40, 200)
                height: 44
                radius: Looks.radius.large
                color: Looks.colors.bgPanelFooter
                border.width: 1
                border.color: Looks.colors.bg2Border

                WRectangularShadow {
                    target: parent
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Image {
                        width: 24
                        height: 24
                        source: root.itemSnapshot?.[root.selectedIndex]?.icon ?? ""
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                    }

                    WText {
                        id: titleLabelText
                        text: root.itemSnapshot?.[root.selectedIndex]?.title ?? ""
                        font.pixelSize: Looks.font.pixelSize.normal
                        color: Looks.colors.fg
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 350
                    }
                }
            }
        }
    }
}
