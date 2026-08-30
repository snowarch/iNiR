pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    property int currentPage: -1
    signal pageActivated(int pageIndex)
    signal pageHidden(int pageIndex)
    signal doneRequested()

    readonly property int rowHeight: 38
    readonly property int rowGap: 4
    readonly property real rowPitch: rowHeight + rowGap

    property var dragInfo: null
    property int pageDropCategory: -2
    property int pageDropIndex: -1

    readonly property bool pageDragging: dragInfo?.type === "page"
    readonly property bool groupDragging: dragInfo?.type === "group"

    function beginPageDrag(categoryIndex: int, pageIndex: int, pageIdx: int): void {
        root.dragInfo = ({ type: "page", ci: categoryIndex, pi: pageIndex, pageIdx })
        root.pageDropCategory = -2
        root.pageDropIndex = -1
    }

    function beginGroupDrag(index: int): void {
        root.dragInfo = ({ type: "group", index })
    }

    function endDrag(): void {
        root.dragInfo = null
        root.pageDropCategory = -2
        root.pageDropIndex = -1
    }

    function indexFromY(y: real, count: int): int {
        return Math.max(0, Math.min(Math.round(y / root.rowPitch), count))
    }

    function movePage(targetCategory: int, targetIndex: int): void {
        if (!root.pageDragging) {
            root.endDrag()
            return
        }
        SettingsArrangement.movePage(root.dragInfo.ci, root.dragInfo.pi,
            root.dragInfo.pageIdx, targetCategory, targetIndex)
        root.endDrag()
    }

    function hidePage(categoryIndex: int, pageIndex: int, pageIdx: int): void {
        if (SettingsArrangement.hidePage(categoryIndex, pageIndex, pageIdx))
            root.pageHidden(pageIdx)
        root.endDrag()
    }

    function hideDraggedPage(): void {
        if (!root.pageDragging || root.dragInfo.ci < 0) {
            root.endDrag()
            return
        }
        root.hidePage(root.dragInfo.ci, root.dragInfo.pi, root.dragInfo.pageIdx)
    }

    function restorePage(pageIdx: int): void {
        SettingsArrangement.restorePage(pageIdx)
        root.endDrag()
    }

    function moveGroup(insertIndex: int): void {
        if (root.groupDragging)
            SettingsArrangement.moveGroup(root.dragInfo.index, insertIndex)
        root.endDrag()
    }

    component PageRow: Item {
        id: rowWrap
        required property int categoryIndex
        required property int pageIndex
        required property int pageIdx
        property bool hiddenSource: false

        readonly property var page: SettingsPageRegistry.pages[rowWrap.pageIdx] ?? null
        readonly property bool dragged: root.pageDragging
            && root.dragInfo.pageIdx === rowWrap.pageIdx
            && root.dragInfo.ci === rowWrap.categoryIndex

        width: parent ? parent.width : 0
        height: root.rowHeight

        Rectangle {
            id: rowCard
            width: rowWrap.width
            height: root.rowHeight
            radius: Appearance.rounding.small
            color: rowWrap.dragged
                ? Appearance.colors.colLayer2
                : (rowHover.hovered ? Appearance.colors.colLayer1Hover : "transparent")
            border.width: rowWrap.dragged ? 2 : 0
            border.color: Appearance.colors.colPrimary
            opacity: root.pageDragging && !rowWrap.dragged ? 0.58 : 1
            scale: rowWrap.dragged ? 1.025 : 1

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 100 }
            }
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
            }

            Drag.active: rowDrag.drag.active
            Drag.source: rowCard
            Drag.keys: ["inir-settings-page"]
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
            states: State {
                when: rowDrag.drag.active
                ParentChange { target: rowCard; parent: dragLayer }
                PropertyChanges { rowCard { z: 800 } }
            }

            HoverHandler { id: rowHover }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 3
                spacing: 5

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 30

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "drag_indicator"
                        iconSize: 17
                        color: Appearance.colors.colSubtext
                    }

                    MouseArea {
                        id: rowDrag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: rowCard
                        drag.axis: Drag.XAndYAxis
                        onPressed: root.beginPageDrag(rowWrap.categoryIndex, rowWrap.pageIndex, rowWrap.pageIdx)
                        onReleased: {
                            if (rowCard.Drag.target)
                                rowCard.Drag.drop()
                            else
                                root.endDrag()
                        }
                        onCanceled: root.endDrag()
                    }
                }

                MaterialSymbol {
                    text: rowWrap.page?.icon ?? "settings"
                    rotation: rowWrap.page?.iconRotation ?? 0
                    iconSize: 17
                    color: rowWrap.pageIdx === root.currentPage
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: rowWrap.page?.name ?? "?"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: rowWrap.pageIdx === root.currentPage ? Font.Medium : Font.Normal
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight

                    TapHandler {
                        onTapped: root.pageActivated(rowWrap.pageIdx)
                    }
                }

                RippleButton {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: Appearance.rounding.full
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        if (rowWrap.hiddenSource)
                            root.restorePage(rowWrap.pageIdx)
                        else
                            root.hidePage(rowWrap.categoryIndex, rowWrap.pageIndex, rowWrap.pageIdx)
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: rowWrap.hiddenSource ? "visibility" : "visibility_off"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    StyledToolTip {
                        text: rowWrap.hiddenSource
                            ? Translation.tr("Show in navigation")
                            : Translation.tr("Hide from navigation")
                    }
                }
            }
        }
    }

    component GroupSlot: DropArea {
        id: slot
        required property int insertIndex
        readonly property bool noOp: root.groupDragging
            && (root.dragInfo.index === slot.insertIndex
                || root.dragInfo.index + 1 === slot.insertIndex)

        keys: ["inir-settings-group"]
        width: parent ? parent.width : 0
        height: root.groupDragging ? (slot.noOp ? 3 : 14) : 2
        enabled: root.groupDragging && !slot.noOp
        onDropped: root.moveGroup(slot.insertIndex)

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 16)
            height: parent.containsDrag ? 4 : 2
            radius: height / 2
            visible: root.groupDragging && !parent.noOp
            color: Appearance.colors.colPrimary
            opacity: parent.containsDrag ? 1 : 0.28
        }
    }

    component CategoryBlock: Column {
        id: categoryBlock
        required property int categoryIndex
        readonly property var category: SettingsPageRegistry.categories[categoryBlock.categoryIndex]
            ?? ({ label: "", pages: [] })
        readonly property bool dragged: root.groupDragging
            && root.dragInfo.index === categoryBlock.categoryIndex

        width: parent ? parent.width : 0
        spacing: 4
        opacity: root.groupDragging && !categoryBlock.dragged ? 0.55 : 1

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 100 }
        }

        Rectangle {
            id: groupHeader
            width: parent.width
            height: 32
            radius: Appearance.rounding.small
            color: categoryBlock.dragged
                ? Appearance.colors.colPrimaryContainer
                : Appearance.colors.colLayer0
            border.width: categoryBlock.dragged ? 1 : 0
            border.color: Appearance.colors.colPrimary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 7
                spacing: 5

                Item {
                    id: groupHandle
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 28

                    Drag.active: groupDrag.drag.active
                    Drag.source: groupHandle
                    Drag.keys: ["inir-settings-group"]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    states: State {
                        when: groupDrag.drag.active
                        ParentChange { target: groupHandle; parent: dragLayer }
                        PropertyChanges { groupHandle { z: 850 } }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.full
                        color: groupDrag.containsMouse || groupDrag.drag.active
                            ? Appearance.colors.colLayer1Hover : "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "drag_indicator"
                            iconSize: 17
                            color: Appearance.colors.colSubtext
                        }
                    }

                    MouseArea {
                        id: groupDrag
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: groupHandle
                        drag.axis: Drag.XAndYAxis
                        onPressed: root.beginGroupDrag(categoryBlock.categoryIndex)
                        onReleased: {
                            if (groupHandle.Drag.target)
                                groupHandle.Drag.drop()
                            else
                                root.endDrag()
                        }
                        onCanceled: root.endDrag()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: categoryBlock.category.label
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colPrimary
                    elide: Text.ElideRight
                }

                StyledText {
                    text: categoryBlock.category.pages.length + ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }
        }

        DropArea {
            id: pageDrop
            width: parent.width
            height: Math.max(pageRows.height, root.rowHeight)
            keys: ["inir-settings-page"]
            readonly property int liveCount: categoryBlock.category.pages.length
                - ((root.pageDragging && root.dragInfo.ci === categoryBlock.categoryIndex) ? 1 : 0)

            function updateDrop(y: real): void {
                root.pageDropCategory = categoryBlock.categoryIndex
                root.pageDropIndex = root.indexFromY(y, pageDrop.liveCount)
            }

            onEntered: drag => pageDrop.updateDrop(drag.y)
            onPositionChanged: drag => pageDrop.updateDrop(drag.y)
            onExited: {
                if (root.pageDropCategory === categoryBlock.categoryIndex) {
                    root.pageDropCategory = -2
                    root.pageDropIndex = -1
                }
            }
            onDropped: root.movePage(categoryBlock.categoryIndex, root.pageDropIndex)

            Column {
                id: pageRows
                width: parent.width
                spacing: root.rowGap

                Repeater {
                    model: categoryBlock.category.pages
                    delegate: PageRow {
                        required property int modelData
                        required property int index
                        categoryIndex: categoryBlock.categoryIndex
                        pageIndex: index
                        pageIdx: modelData
                    }
                }

                Item {
                    visible: root.pageDragging && root.dragInfo.ci === categoryBlock.categoryIndex
                    width: parent.width
                    height: visible ? root.rowHeight : 0
                }
            }

            Rectangle {
                visible: pageDrop.containsDrag && root.pageDropIndex >= 0 && pageDrop.liveCount > 0
                x: 5
                width: parent.width - 10
                height: 3
                radius: 1.5
                color: Appearance.colors.colPrimary
                y: Math.min(root.pageDropIndex, pageDrop.liveCount) * root.rowPitch
                    - root.rowGap / 2 - height / 2
                z: 30
                Behavior on y {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                }
            }
        }
    }

    Flickable {
        id: editFlick
        anchors.fill: parent
        clip: true
        contentHeight: editorColumn.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ScrollBar.vertical: StyledScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: editorColumn
            width: editFlick.width
            spacing: 5

            Rectangle {
                width: parent.width
                height: 40
                radius: Appearance.rounding.small
                color: Appearance.colors.colPrimaryContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 5
                    spacing: 6

                    MaterialSymbol {
                        text: "edit"
                        iconSize: 17
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Editing navigation")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }
                    RippleButton {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        onClicked: root.doneRequested()
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "done"
                            iconSize: 17
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        StyledToolTip { text: Translation.tr("Done editing") }
                    }
                }
            }

            Repeater {
                model: SettingsPageRegistry.categories.length
                delegate: Column {
                    id: categoryWrap
                    required property int index
                    width: parent.width
                    spacing: 0

                    GroupSlot { insertIndex: categoryWrap.index }
                    CategoryBlock { categoryIndex: categoryWrap.index }
                }
            }

            GroupSlot { insertIndex: SettingsPageRegistry.categories.length }

            Rectangle {
                id: hiddenCard
                width: parent.width
                height: hiddenColumn.height + 12
                radius: Appearance.rounding.small
                color: hiddenDrop.containsDrag
                    ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                    : Appearance.colors.colLayer0
                border.width: 1
                border.color: hiddenDrop.containsDrag
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOutlineVariant

                DropArea {
                    id: hiddenDrop
                    anchors.fill: parent
                    keys: ["inir-settings-page"]
                    onDropped: root.hideDraggedPage()
                }

                Column {
                    id: hiddenColumn
                    x: 6
                    y: 6
                    width: parent.width - 12
                    spacing: 4

                    RowLayout {
                        width: parent.width
                        height: 28
                        spacing: 6
                        MaterialSymbol {
                            text: hiddenDrop.containsDrag ? "move_down" : "visibility_off"
                            iconSize: 16
                            color: hiddenDrop.containsDrag
                                ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: hiddenDrop.containsDrag
                                ? Translation.tr("Release to hide")
                                : Translation.tr("Hidden")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.DemiBold
                            color: hiddenDrop.containsDrag
                                ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: SettingsPageRegistry.hiddenPages.length + ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    Repeater {
                        model: SettingsPageRegistry.hiddenPages
                        delegate: PageRow {
                            required property int modelData
                            required property int index
                            categoryIndex: -1
                            pageIndex: index
                            pageIdx: modelData
                            hiddenSource: true
                        }
                    }

                    StyledText {
                        visible: SettingsPageRegistry.hiddenPages.length === 0
                        width: parent.width
                        height: visible ? 28 : 0
                        text: Translation.tr("Drop pages here to hide them")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
            }

            RippleButton {
                width: parent.width
                height: 34
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: root.pageActivated(20)
                contentItem: RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 7
                    MaterialSymbol {
                        text: "tune"
                        iconSize: 16
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Open full Arrange")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    MaterialSymbol {
                        text: "arrow_forward"
                        iconSize: 15
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    Item {
        id: dragLayer
        anchors.fill: parent
        z: 1000
        clip: false
    }
}
