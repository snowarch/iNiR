pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    id: root
    settingsPageIndex: 20
    settingsPageName: Translation.tr("Arrange")

    readonly property int pageRowHeight: 48
    readonly property int pageRowGap: 5
    readonly property real pagePitch: pageRowHeight + pageRowGap

    property var dragInfo: null
    property int pageDropCategory: -2
    property int pageDropIndex: -1
    property int editingGroup: -1

    readonly property bool pageDragging: dragInfo?.type === "page"
    readonly property bool groupDragging: dragInfo?.type === "group"
    readonly property int visiblePageCount: SettingsPageRegistry.pages.length - SettingsPageRegistry.hiddenPages.length

    function _pageIndexFromY(y: real, count: int): int {
        return Math.max(0, Math.min(Math.round(y / root.pagePitch), count))
    }

    function _beginPageDrag(categoryIndex: int, pageIndex: int, pageIdx: int): void {
        root.dragInfo = ({ type: "page", ci: categoryIndex, pi: pageIndex, pageIdx: pageIdx })
        root.pageDropCategory = -2
        root.pageDropIndex = -1
    }

    function _beginGroupDrag(index: int): void {
        root.dragInfo = ({ type: "group", index: index })
        root.editingGroup = -1
    }

    function _endDrag(): void {
        root.dragInfo = null
        root.pageDropCategory = -2
        root.pageDropIndex = -1
    }

    function _moveDraggedPage(targetCategory: int, targetIndex: int): void {
        if (!root.pageDragging) {
            root._endDrag()
            return
        }
        SettingsArrangement.movePage(root.dragInfo.ci, root.dragInfo.pi,
            root.dragInfo.pageIdx, targetCategory, targetIndex)
        root.editingGroup = -1
        root._endDrag()
    }

    function _hidePage(categoryIndex: int, pageIndex: int, pageIdx: int): void {
        if (SettingsArrangement.hidePage(categoryIndex, pageIndex, pageIdx))
            root.editingGroup = -1
        root._endDrag()
    }

    function _hideDraggedPage(): void {
        if (!root.pageDragging || root.dragInfo.ci < 0) {
            root._endDrag()
            return
        }
        root._hidePage(root.dragInfo.ci, root.dragInfo.pi, root.dragInfo.pageIdx)
    }

    function _restorePage(pageIdx: int): void {
        if (SettingsArrangement.restorePage(pageIdx))
            root.editingGroup = -1
        root._endDrag()
    }

    function _moveGroup(insertIndex: int): void {
        if (!root.groupDragging) {
            root._endDrag()
            return
        }
        SettingsArrangement.moveGroup(root.dragInfo.index, insertIndex)
        root.editingGroup = -1
        root._endDrag()
    }

    function renameCategory(index: int, label: string): void {
        if (SettingsArrangement.renameCategory(index, label))
            root.editingGroup = -1
        root._endDrag()
    }

    function removeCategory(index: int): void {
        if (SettingsArrangement.removeCategory(index))
            root.editingGroup = -1
        root._endDrag()
    }

    function addCategory(): void {
        SettingsArrangement.addCategory()
        root.editingGroup = -1
        root._endDrag()
    }

    component IconAction: RippleButton {
        property string symbol: ""
        property string tip: ""
        implicitWidth: 30
        implicitHeight: 30
        buttonRadius: Appearance.rounding.full
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: parent.symbol
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }
        StyledToolTip { text: parent.tip }
    }

    component PageRow: Rectangle {
        id: rowRoot
        required property int categoryIndex
        required property int pageIndex
        required property int pageIdx
        property bool hiddenSource: false

        readonly property var page: SettingsPageRegistry.pages[rowRoot.pageIdx] ?? null
        readonly property bool beingDragged: root.pageDragging
            && root.dragInfo.pageIdx === rowRoot.pageIdx
            && root.dragInfo.ci === rowRoot.categoryIndex

        width: parent ? parent.width : implicitWidth
        height: root.pageRowHeight
        radius: Appearance.rounding.small
        color: rowRoot.beingDragged
            ? Appearance.colors.colLayer2
            : (rowHover.hovered ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1)
        border.width: rowRoot.beingDragged ? 2 : 1
        border.color: rowRoot.beingDragged ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        scale: rowRoot.beingDragged ? 1.025 : 1
        opacity: root.pageDragging && !rowRoot.beingDragged ? 0.72 : 1

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 100 }
        }

        StyledRectangularShadow {
            target: rowRoot.beingDragged ? rowRoot : null
            visible: rowRoot.beingDragged
            z: -1
        }

        Drag.active: rowDrag.drag.active
        Drag.source: rowRoot
        Drag.keys: ["inir-settings-page"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
        states: State {
            when: rowDrag.drag.active
            ParentChange { target: rowRoot; parent: dragLayer }
            PropertyChanges { rowRoot { z: 500 } }
        }

        HoverHandler { id: rowHover }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 7
            spacing: 8

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "drag_indicator"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }

                MouseArea {
                    id: rowDrag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: rowRoot
                    drag.axis: Drag.XAndYAxis
                    onPressed: root._beginPageDrag(rowRoot.categoryIndex, rowRoot.pageIndex, rowRoot.pageIdx)
                    onReleased: {
                        if (rowRoot.Drag.target) rowRoot.Drag.drop()
                        else root._endDrag()
                    }
                    onCanceled: root._endDrag()
                }
            }

            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: Appearance.rounding.full
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: rowRoot.page?.icon ?? "settings"
                    rotation: rowRoot.page?.iconRotation ?? 0
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: rowRoot.page?.name ?? "?"
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: rowRoot.page?.desc ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            IconAction {
                symbol: rowRoot.hiddenSource ? "visibility" : "visibility_off"
                tip: rowRoot.hiddenSource
                    ? Translation.tr("Show in navigation")
                    : Translation.tr("Hide from navigation")
                onClicked: {
                    if (rowRoot.hiddenSource) root._restorePage(rowRoot.pageIdx)
                    else root._hidePage(rowRoot.categoryIndex, rowRoot.pageIndex, rowRoot.pageIdx)
                }
            }
        }
    }

    component GroupDropSlot: DropArea {
        id: groupSlot
        required property int insertIndex
        readonly property bool noOp: root.groupDragging
            && (root.dragInfo.index === groupSlot.insertIndex || root.dragInfo.index + 1 === groupSlot.insertIndex)

        keys: ["inir-settings-group"]
        Layout.fillWidth: true
        implicitHeight: root.groupDragging ? (groupSlot.noOp ? 6 : 20) : 4
        enabled: root.groupDragging && !groupSlot.noOp

        onDropped: root._moveGroup(groupSlot.insertIndex)

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 20
            height: parent.containsDrag ? 5 : 2
            radius: height / 2
            visible: root.groupDragging && !groupSlot.noOp
            color: parent.containsDrag
                ? Appearance.colors.colPrimary
                : ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.22)
            opacity: parent.containsDrag ? 1 : 0.65
            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 100 }
            }
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: 100 }
            }
        }
    }

    component CategoryCard: Rectangle {
        id: cardRoot
        required property int categoryIndex
        readonly property var category: SettingsPageRegistry.categories[cardRoot.categoryIndex] ?? ({ label: "", pages: [] })
        readonly property bool beingDragged: root.groupDragging && root.dragInfo.index === cardRoot.categoryIndex
        readonly property bool pageDropActive: root.pageDragging && root.pageDropCategory === cardRoot.categoryIndex

        width: parent ? parent.width : implicitWidth
        height: implicitHeight
        implicitHeight: cardColumn.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: cardRoot.pageDropActive
            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.94)
            : Appearance.colors.colLayer0
        border.width: cardRoot.beingDragged ? 2 : 1
        border.color: cardRoot.beingDragged || cardRoot.pageDropActive
            ? Appearance.colors.colPrimary
            : Appearance.colors.colOutlineVariant
        scale: cardRoot.beingDragged ? 1.015 : 1
        opacity: root.groupDragging && !cardRoot.beingDragged ? 0.72 : 1

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 100 }
        }

        StyledRectangularShadow {
            target: cardRoot.beingDragged ? cardRoot : null
            visible: cardRoot.beingDragged
            z: -1
        }

        Drag.active: groupDrag.drag.active
        Drag.source: cardRoot
        Drag.keys: ["inir-settings-group"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: 22
        states: State {
            when: groupDrag.drag.active
            ParentChange { target: cardRoot; parent: dragLayer }
            PropertyChanges { cardRoot { z: 450 } }
        }

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 7

            RowLayout {
                id: categoryHeader
                Layout.fillWidth: true
                spacing: 7
                readonly property bool editing: root.editingGroup === cardRoot.categoryIndex

                Item {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    enabled: !categoryHeader.editing
                    opacity: enabled ? 1 : 0.45

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "drag_indicator"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSubtext
                    }
                    MouseArea {
                        id: groupDrag
                        anchors.fill: parent
                        enabled: parent.enabled
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        drag.target: cardRoot
                        drag.axis: Drag.XAndYAxis
                        onPressed: root._beginGroupDrag(cardRoot.categoryIndex)
                        onReleased: {
                            if (cardRoot.Drag.target) cardRoot.Drag.drop()
                            else root._endDrag()
                        }
                        onCanceled: root._endDrag()
                    }
                }

                ColumnLayout {
                    visible: !categoryHeader.editing
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: cardRoot.category.label
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer0
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: cardRoot.category.pages.length === 1
                            ? Translation.tr("1 page")
                            : Translation.tr("%1 pages").arg(cardRoot.category.pages.length)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                Item {
                    visible: categoryHeader.editing
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    MaterialTextField {
                        id: renameField
                        anchors.fill: parent
                        text: cardRoot.category.label
                        onVisibleChanged: if (visible) { text = cardRoot.category.label; forceActiveFocus() }
                        onAccepted: root.renameCategory(cardRoot.categoryIndex, text)
                    }
                }

                IconAction {
                    symbol: categoryHeader.editing ? "check" : "edit"
                    tip: categoryHeader.editing ? Translation.tr("Save group name") : Translation.tr("Rename group")
                    visible: !root.groupDragging && !root.pageDragging
                    onClicked: {
                        if (categoryHeader.editing) root.renameCategory(cardRoot.categoryIndex, renameField.text)
                        else root.editingGroup = cardRoot.categoryIndex
                    }
                }

                IconAction {
                    symbol: "delete"
                    tip: SettingsPageRegistry.categories.length <= 1
                        ? Translation.tr("Keep at least one group")
                        : Translation.tr("Delete empty group")
                    visible: cardRoot.category.pages.length === 0 && !categoryHeader.editing
                        && !root.groupDragging && !root.pageDragging
                    enabled: SettingsPageRegistry.categories.length > 1
                    onClicked: root.removeCategory(cardRoot.categoryIndex)
                }
            }

            DropArea {
                id: pageDrop
                Layout.fillWidth: true
                implicitHeight: Math.max(pageRows.implicitHeight, root.pageRowHeight)
                keys: ["inir-settings-page"]
                readonly property int liveCount: cardRoot.category.pages.length
                    - ((root.pageDragging && root.dragInfo.ci === cardRoot.categoryIndex) ? 1 : 0)

                function updateDrop(y: real): void {
                    root.pageDropCategory = cardRoot.categoryIndex
                    root.pageDropIndex = root._pageIndexFromY(y, pageDrop.liveCount)
                }

                onEntered: drag => pageDrop.updateDrop(drag.y)
                onPositionChanged: drag => pageDrop.updateDrop(drag.y)
                onExited: {
                    if (root.pageDropCategory === cardRoot.categoryIndex) {
                        root.pageDropCategory = -2
                        root.pageDropIndex = -1
                    }
                }
                onDropped: root._moveDraggedPage(cardRoot.categoryIndex, root.pageDropIndex)

                Rectangle {
                    anchors.fill: parent
                    visible: pageDrop.liveCount === 0
                    radius: Appearance.rounding.small
                    color: pageDrop.containsDrag
                        ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)
                        : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.97)
                    border.width: 1
                    border.color: pageDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            text: pageDrop.containsDrag ? "move_down" : "add"
                            iconSize: Appearance.font.pixelSize.normal
                            color: pageDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: pageDrop.containsDrag ? Translation.tr("Release to add") : Translation.tr("Drag pages here")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: pageDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }
                }

                Column {
                    id: pageRows
                    width: parent.width
                    spacing: root.pageRowGap

                    Repeater {
                        model: cardRoot.category.pages
                        delegate: PageRow {
                            required property int modelData
                            required property int index
                            categoryIndex: cardRoot.categoryIndex
                            pageIndex: index
                            pageIdx: modelData
                        }
                    }

                    Item {
                        visible: root.pageDragging && root.dragInfo.ci === cardRoot.categoryIndex
                        width: parent.width
                        height: visible ? root.pageRowHeight : 0
                    }
                }

                Rectangle {
                    visible: pageDrop.containsDrag && root.pageDropIndex >= 0 && pageDrop.liveCount > 0
                    x: 6
                    width: parent.width - 12
                    height: 4
                    radius: 2
                    color: Appearance.colors.colPrimary
                    y: Math.min(root.pageDropIndex, pageDrop.liveCount) * root.pagePitch
                        - root.pageRowGap / 2 - height / 2
                    z: 40
                    Behavior on y {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }
                    Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: -4 }
                    Rectangle { width: 8; height: 8; radius: 4; color: parent.color; anchors.verticalCenter: parent.verticalCenter; x: parent.width - 4 }
                }
            }
        }
    }

    SettingsCardSection {
        expanded: true
        icon: "swap_vert"
        title: Translation.tr("Navigation layout")

        SettingsGroup {
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Make Settings yours")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Drag groups and pages into the order you want. Hide anything you don't need in the sidebar — Search can still open hidden pages.")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    implicitWidth: visibleCount.implicitWidth + 18
                    implicitHeight: 28
                    radius: Appearance.rounding.full
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.87)
                    StyledText {
                        id: visibleCount
                        anchors.centerIn: parent
                        text: Translation.tr("%1 visible").arg(root.visiblePageCount)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                RippleButtonWithIcon {
                    materialIcon: "create_new_folder"
                    mainText: Translation.tr("Add group")
                    onClicked: root.addCategory()
                }
                RippleButtonWithIcon {
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Reset arrangement")
                    onClicked: {
                        root._endDrag()
                        root.editingGroup = -1
                        Config.setNestedValue("settingsUi.categories", "")
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            z: 1000
            Item {
                id: dragLayer
                width: root.width
                height: root.height
            }
        }

        Repeater {
            id: categoryRepeater
            model: SettingsPageRegistry.categories.length

            delegate: ColumnLayout {
                id: groupWrapper
                required property int index
                Layout.fillWidth: true
                spacing: 0

                GroupDropSlot { insertIndex: groupWrapper.index }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: groupCard.implicitHeight
                    CategoryCard {
                        id: groupCard
                        categoryIndex: groupWrapper.index
                    }
                }
            }
        }

        GroupDropSlot { insertIndex: SettingsPageRegistry.categories.length }

        Rectangle {
            id: hiddenCard
            Layout.fillWidth: true
            implicitHeight: hiddenColumn.implicitHeight + 18
            radius: Appearance.rounding.normal
            color: hiddenDrop.containsDrag
                ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.92)
                : Appearance.colors.colLayer0
            border.width: 1
            border.color: hiddenDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }

            DropArea {
                id: hiddenDrop
                anchors.fill: parent
                keys: ["inir-settings-page"]
                onDropped: root._hideDraggedPage()
            }

            ColumnLayout {
                id: hiddenColumn
                anchors.fill: parent
                anchors.margins: 9
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Appearance.rounding.full
                        color: hiddenDrop.containsDrag
                            ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.82)
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.94)
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: hiddenDrop.containsDrag ? "move_down" : "visibility_off"
                            iconSize: Appearance.font.pixelSize.normal
                            color: hiddenDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Hidden from navigation")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: hiddenDrop.containsDrag
                                ? Translation.tr("Release to hide this page")
                                : Translation.tr("Still available from Search")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: hiddenDrop.containsDrag ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                        }
                    }

                    Rectangle {
                        implicitWidth: hiddenCount.implicitWidth + 14
                        implicitHeight: 24
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.94)
                        StyledText {
                            id: hiddenCount
                            anchors.centerIn: parent
                            text: SettingsPageRegistry.hiddenPages.length + ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: root.pageRowGap
                    visible: SettingsPageRegistry.hiddenPages.length > 0

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
                }

                StyledText {
                    visible: SettingsPageRegistry.hiddenPages.length === 0
                    Layout.fillWidth: true
                    text: Translation.tr("Nothing hidden. Use the eye button on any page or drag it here.")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                }
            }
        }
    }
}
