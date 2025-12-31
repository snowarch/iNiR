pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.synchronizer

Item {
    id: root
    property alias currentIndex: tabBar.currentIndex
    required property var tabButtonList
    property real maxWidth: -1
    property int compactThreshold: 4
    readonly property bool compactMode: (root.tabButtonList?.length ?? 0) >= root.compactThreshold

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

    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    Layout.minimumWidth: 0
    implicitWidth: root.maxWidth > 0 ? Math.min(groupContainer.implicitWidth, root.maxWidth) : groupContainer.implicitWidth
    implicitHeight: 40

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        interactive: contentWidth > width
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
                height: Appearance.inirEverywhere ? 36 : 40
                x: flick.contentWidth > flick.width ? 0 : Math.max(0, (flick.width - width) / 2)

                Rectangle {
                    id: groupBackground
                    anchors.fill: parent
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : height / 2
                    color: Appearance.inirEverywhere ? "transparent" 
                         : Appearance.auroraEverywhere ? "transparent"
                         : Appearance.colors.colSurfaceContainer
                    border.width: Appearance.inirEverywhere ? 1 : 0
                    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
                }

                Rectangle {
                    id: activeIndicator
                    z: 1
                    color: Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colPrimary, 0.85) 
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colSecondaryContainer
                    border.width: Appearance.inirEverywhere ? 1 : 0
                    border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderAccent : "transparent"
                    implicitWidth: targetItem ? targetItem.implicitWidth : 0
                    implicitHeight: targetItem ? (Appearance.inirEverywhere ? 28 : (Appearance.auroraEverywhere ? 32 : targetItem.implicitHeight)) : 0
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : height / 2
                    anchors.verticalCenter: parent.verticalCenter
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
                            required property int index
                            required property var modelData
                            current: index == root.currentIndex
                            showLabel: !root.compactMode || current
                            text: modelData.name
                            materialSymbol: modelData.icon
                            onClicked: {
                                root.setCurrentIndex(index)
                            }
                        }
                    }
                }
            }
        }
    }

    onCurrentIndexChanged: Qt.callLater(root.ensureCurrentVisible)
    onWidthChanged: Qt.callLater(root.ensureCurrentVisible)
    Component.onCompleted: Qt.callLater(root.ensureCurrentVisible)

    MouseArea {
        anchors.fill: parent
        z: 2
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: (event) => {
            if (event.angleDelta.y < 0) {
                root.incrementCurrentIndex();
            }
            else {
                root.decrementCurrentIndex();
            }
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
