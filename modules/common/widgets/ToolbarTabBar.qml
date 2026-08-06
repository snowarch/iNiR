pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    property real maxWidth: -1
    property int compactThreshold: 4
    readonly property bool compactMode: (root.tabButtonList?.length ?? 0) >= root.compactThreshold
    // Emitted only for direct user interaction (click/wheel), never for
    // programmatic setCurrentIndex — lets consumers persist explicit choices.
    signal userSelected(int index)
    property bool reorderEnabled: false
    signal reorderRequested(int fromIndex, int toIndex)
    property int reorderDragIndex: -1
    property int reorderHoverIndex: -1
    property real reorderStartX: 0
    property real reorderCurrentX: 0
    property var _reorderWidths: []

    function ensureCurrentVisible() {
        if (!flick.interactive) return;
        if (!activeIndicator.targetItem) return;

        const leftEdge = groupContainer.padding + activeIndicator.targetItem.x;
        const rightEdge = groupContainer.padding + activeIndicator.targetItem.x + activeIndicator.targetItem.width;
        const viewLeft = flick.contentX;
        const viewRight = flick.contentX + flick.width;

        if (leftEdge < viewLeft) {
            flick.contentX = Math.max(0, leftEdge - 8);
        }
        else if (rightEdge > viewRight) {
            flick.contentX = Math.max(0, rightEdge - flick.width + 8);
        }
    }

    function incrementCurrentIndex() {
        tabBar.incrementCurrentIndex()
    }
    function decrementCurrentIndex() {
        tabBar.decrementCurrentIndex()
    }
    function setCurrentIndex(index) {
        tabBar.setCurrentIndex(index)
    }

    function _cacheReorderWidths(): void {
        const widths = []
        for (let i = 0; i < tabRepeater.count; i++) {
            const item = tabRepeater.itemAt(i)
            widths.push(item?.width ?? 0)
        }
        _reorderWidths = widths
    }

    function startReorder(index: int, mouseX: real): void {
        if (!reorderEnabled) return
        _cacheReorderWidths()
        reorderDragIndex = index
        reorderHoverIndex = index
        reorderStartX = mouseX
        reorderCurrentX = mouseX
    }

    function updateReorder(mouseX: real): void {
        if (reorderDragIndex < 0) return
        reorderCurrentX = mouseX
        let lastIndex = reorderDragIndex
        for (let i = 0; i < tabRepeater.count; i++) {
            const item = tabRepeater.itemAt(i)
            if (!item) continue
            lastIndex = i
            if (mouseX < item.x + item.width / 2) {
                reorderHoverIndex = i
                return
            }
        }
        reorderHoverIndex = lastIndex
    }

    function reorderDisplacementX(index: int): real {
        if (reorderDragIndex < 0 || reorderHoverIndex < 0 || index === reorderDragIndex) return 0
        const span = (_reorderWidths[reorderDragIndex] ?? 0) + contentItem.spacing
        if (reorderDragIndex < reorderHoverIndex
                && index > reorderDragIndex && index <= reorderHoverIndex) return -span
        if (reorderDragIndex > reorderHoverIndex
                && index >= reorderHoverIndex && index < reorderDragIndex) return span
        return 0
    }

    function reorderFollowX(): real {
        return reorderDragIndex < 0 ? 0 : reorderCurrentX - reorderStartX
    }

    function endReorder(): void {
        const fromIndex = reorderDragIndex
        const toIndex = reorderHoverIndex
        if (fromIndex >= 0 && toIndex >= 0 && fromIndex !== toIndex)
            reorderRequested(fromIndex, toIndex)
        cancelReorder()
    }

    function cancelReorder(): void {
        reorderDragIndex = -1
        reorderHoverIndex = -1
        reorderStartX = 0
        reorderCurrentX = 0
        _reorderWidths = []
    }

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    Layout.minimumWidth: 0
    implicitWidth: root.maxWidth > 0 ? Math.min(groupContainer.implicitWidth, root.maxWidth) : groupContainer.implicitWidth
    implicitHeight: 40

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        interactive: contentWidth > width && root.reorderDragIndex < 0
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        contentWidth: groupContainer.implicitWidth
        contentHeight: height

        Item {
            width: Math.max(flick.width, groupContainer.implicitWidth)
            height: flick.height

            Item {
                id: groupContainer
                z: 0
                anchors.verticalCenter: parent.verticalCenter
                readonly property real padding: 4
                implicitWidth: contentItem.implicitWidth + padding * 2
                height: Appearance.angelEverywhere ? 36 : Appearance.inirEverywhere ? 36 : 40
                x: flick.contentWidth > flick.width ? 0 : Math.max(0, (flick.width - width) / 2)

                Rectangle {
                    id: groupBackground
                    anchors.fill: parent
                    radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
                        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : height / 2
                    color: Appearance.zzzEverywhere ? Appearance.zzz.chromeAlt
                        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.inirEverywhere ? "transparent" 
                         : Appearance.auroraEverywhere ? "transparent"
                         : Appearance.colors.colSurfaceContainer
                    border.width: Appearance.zzzEverywhere ? 1 : (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : 0
                    border.color: Appearance.zzzEverywhere ? Appearance.zzz.quietStroke
                        : Appearance.angelEverywhere ? Appearance.angel.colBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
                    // Organic morph on style/shape switch (organic-transitions)
                    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                }

                Rectangle {
                    id: activeIndicator
                    z: 1
                    opacity: root.reorderEnabled ? 0.35 : 1
                    Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                    color: Appearance.zzzEverywhere ? Appearance.zzz.chrome
                        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colPrimary, 0.85)
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.cookieEverywhere ? Appearance.colors.colLayer2
                        : Appearance.colors.colSecondaryContainer
                    border.width: Appearance.zzzEverywhere ? 1 : (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : 0
                    border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
                        : Appearance.angelEverywhere ? Appearance.angel.colBorderHover
                        : Appearance.inirEverywhere ? Appearance.inir.colBorderAccent : "transparent"
                    implicitWidth: targetItem ? targetItem.implicitWidth : 0
                    implicitHeight: targetItem ? (Appearance.zzzEverywhere ? 30 : Appearance.angelEverywhere ? 28 : Appearance.inirEverywhere ? 28 : (Appearance.auroraEverywhere ? 32 : targetItem.implicitHeight)) : 0
                    // Concentric with groupBackground (same controlRadius, but
                    // inset ~4px): echo the track's silhouette instead of looking
                    // more-rounded-than-parent. Other styles keep their own read.
                    radius: Appearance.zzzEverywhere ? Appearance.concentricRadius(Appearance.zzz.controlRadius, 4)
                        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : height / 2
                    anchors.verticalCenter: parent.verticalCenter

                    // Organic morph on style/shape switch (organic-transitions)
                    Behavior on radius { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve } }
                    Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on border.width { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    Behavior on border.color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    // Animation
                    property Item targetItem: tabRepeater.itemAt(root.currentIndex)
                    AnimatedTabIndexPair {
                        id: leftBound
                        idx1Duration: 50
                        idx2Duration: 200
                        index: activeIndicator.targetItem ? (groupContainer.padding + activeIndicator.targetItem.x) : 0
                    }
                    AnimatedTabIndexPair {
                        id: rightBound
                        idx1Duration: 50
                        idx2Duration: 200
                        index: activeIndicator.targetItem ? (groupContainer.padding + activeIndicator.targetItem.x + activeIndicator.targetItem.width) : 0
                    }
                    x: root.currentIndex >= 0 && activeIndicator.targetItem ? Math.min(leftBound.idx1, leftBound.idx2) : 0
                    width: root.currentIndex >= 0 && activeIndicator.targetItem ? (Math.max(rightBound.idx1, rightBound.idx2) - x) : 0
                }

                Row {
                    id: contentItem
                    z: 2
                    spacing: 4
                    x: groupContainer.padding
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        id: tabRepeater
                        model: root.tabButtonList
                        delegate: ToolbarTabButton {
                            id: tabButton
                            required property int index
                            required property var modelData
                            readonly property bool beingDragged: root.reorderDragIndex === index
                            readonly property bool dropTarget: root.reorderHoverIndex === index
                                && root.reorderDragIndex >= 0 && root.reorderDragIndex !== index
                            current: index == root.currentIndex
                            showLabel: !root.compactMode || current
                            text: modelData.name
                            materialSymbol: modelData.icon
                            opacity: root.reorderEnabled && root.reorderDragIndex >= 0 && !beingDragged ? 0.72 : 1
                            scale: beingDragged ? 1.08 : 1
                            z: beingDragged ? 8 : 0
                            transform: Translate {
                                x: tabButton.beingDragged
                                    ? root.reorderFollowX()
                                    : root.reorderDisplacementX(tabButton.index)
                                Behavior on x {
                                    enabled: Appearance.animationsEnabled && !tabButton.beingDragged
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                                }
                            }
                            Behavior on x {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                            }
                            Behavior on scale {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic }
                            }
                            onClicked: {
                                root.setCurrentIndex(index)
                                root.userSelected(index)
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: -contentItem.spacing / 2 - width / 2
                                width: 3
                                height: Math.max(14, parent.height - 10)
                                radius: width / 2
                                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                                visible: tabButton.dropTarget && root.reorderHoverIndex < root.reorderDragIndex
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: -contentItem.spacing / 2 - width / 2
                                width: 3
                                height: Math.max(14, parent.height - 10)
                                radius: width / 2
                                color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                                visible: tabButton.dropTarget && root.reorderHoverIndex > root.reorderDragIndex
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -2
                                visible: root.reorderEnabled
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: tabButton.beingDragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property bool dragStarted: false
                                onPressed: (mouse) => {
                                    dragStarted = true
                                    root.startReorder(tabButton.index,
                                        mapToItem(contentItem, mouse.x, mouse.y).x)
                                }
                                onPositionChanged: (mouse) => {
                                    if (dragStarted)
                                        root.updateReorder(mapToItem(contentItem, mouse.x, mouse.y).x)
                                }
                                onReleased: {
                                    if (dragStarted) root.endReorder()
                                    dragStarted = false
                                }
                                onCanceled: {
                                    root.cancelReorder()
                                    dragStarted = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    onCurrentIndexChanged: Qt.callLater(root.ensureCurrentVisible)
    onWidthChanged: Qt.callLater(root.ensureCurrentVisible)
    onReorderEnabledChanged: {
        if (!reorderEnabled) root.cancelReorder()
    }
    Component.onCompleted: Qt.callLater(root.ensureCurrentVisible)

    MouseArea {
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: (event) => {
            if (root.reorderEnabled) return
            if (event.angleDelta.y < 0) {
                root.incrementCurrentIndex();
            }
            else {
                root.decrementCurrentIndex();
            }
            root.userSelected(root.currentIndex)
            Qt.callLater(root.ensureCurrentVisible)
        }
    }

    // TabBar doesn't allow tabs to be of different sizes. Literally unusable. 
    // We use it only for the logic and draw stuff manually
    TabBar {
        id: tabBar
        z: -1
        background: null
        Repeater { // This is to fool the TabBar that it has tabs so it does the indices properly
            model: root.tabButtonList.length
            delegate: TabButton {
                background: null
            }
        }
    }
}
