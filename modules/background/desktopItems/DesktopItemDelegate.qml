pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Item {
    id: root

    required property string itemId
    required property var itemData
    required property string outputName
    required property int canvasWidth
    required property int canvasHeight
    property var workArea: ({ left: 0, top: 0, right: canvasWidth, bottom: canvasHeight,
        width: canvasWidth, height: canvasHeight })
    property int gridSize: 16
    property bool gridSnap: true
    property bool dragEnabled: true
    readonly property string instanceKey: root.outputName + "::desktopItem." + root.itemId
    readonly property bool selected: GlobalStates.selectedDesktopItem === root.instanceKey
    readonly property bool locked: root.itemData?.locked === true
    readonly property bool isApplication: String(root.itemData?.kind ?? "") === "application"
    readonly property string target: String(root.itemData?.target ?? "")
    readonly property string label: String(root.itemData?.label ?? root.target)
    readonly property bool targetAvailable: {
        if (root.isApplication)
            return AppSearch.lookupDesktopEntry(root.target) !== null
        if (!root.target)
            return false
        if (/^https?:\/\//i.test(root.target))
            return true
        return root._targetExists
    }
    property bool _targetExists: true
    property string editMode: ""
    property string editText: ""
    property bool _componentReady: false
    property bool _positionOverride: false
    property bool _targetProbePending: false
    property real _pressX: 0
    property real _pressY: 0

    signal contextMenuRequested(var menuModel, real anchorX, real anchorY)
    signal contextMenuCloseRequested()

    width: DesktopItems.itemWidth
    height: DesktopItems.itemHeight
    // Widget-owned DropAreas are created after this repeater at the same base
    // z, so they remain the eligible receiver when bounds overlap.
    // Persisted desktop layers stay below the explicit DesktopImageChoice band
    // and do not rise just because an item is selected. Widget-owned surfaces
    // and their DropAreas therefore retain their own input/stacking contract.
    z: Math.max(0, Math.min(299, Number(root.itemData?.layer ?? 0)))

    Binding {
        target: root
        property: "x"
        value: Number(root.workArea.left ?? 0) + Number(root.itemData?.x ?? 0)
        when: !root._positionOverride
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "y"
        value: Number(root.workArea.top ?? 0) + Number(root.itemData?.y ?? 0)
        when: !root._positionOverride
        restoreMode: Binding.RestoreNone
    }

    function _pathForProbe(): string {
        return FileUtils.trimFileProtocol(root.target)
    }

    function _refreshTarget(): void {
        if (root.isApplication || /^https?:\/\//i.test(root.target)) {
            root._targetExists = true
            root._targetProbePending = false
            return
        }
        root._targetProbePending = true
        root._targetExists = false
        targetProbe.exec(["test", "-e", root._pathForProbe()])
    }

    function _clampPosition(px: real, py: real): var {
        const left = Number(root.workArea.left ?? 0)
        const top = Number(root.workArea.top ?? 0)
        const arranged = DesktopItems.arrangePosition(root.outputName,
            px - left, py - top,
            Number(root.workArea.width ?? root.canvasWidth),
            Number(root.workArea.height ?? root.canvasHeight),
            root.gridSize, root.gridSnap, root.itemId)
        return {
            x: left + arranged.x,
            y: top + arranged.y
        }
    }

    function _moveToOutput(targetOutput: string): void {
        const name = String(targetOutput ?? "")
        const screen = Quickshell.screens.find(candidate =>
            String(candidate?.name ?? "") === name)
        if (!screen || name === String(root.itemData?.output ?? ""))
            return

        const currentWidth = Math.max(0,
            Number(root.workArea.width ?? root.canvasWidth) - root.width)
        const currentHeight = Math.max(0,
            Number(root.workArea.height ?? root.canvasHeight) - root.height)
        const relativeX = currentWidth > 0
            ? Number(root.itemData?.x ?? 0) / currentWidth : 0
        const relativeY = currentHeight > 0
            ? Number(root.itemData?.y ?? 0) / currentHeight : 0
        const targetWork = ShellLayoutController.desktopZoneWorkArea(
            name, screen.width ?? 0, screen.height ?? 0)
        const targetWidth = Math.max(0, Number(targetWork.width ?? 0) - root.width)
        const targetHeight = Math.max(0, Number(targetWork.height ?? 0) - root.height)
        const arranged = DesktopItems.arrangePosition(name,
            Math.round(Math.max(0, Math.min(1, relativeX)) * targetWidth),
            Math.round(Math.max(0, Math.min(1, relativeY)) * targetHeight),
            Number(targetWork.width ?? 0), Number(targetWork.height ?? 0),
            root.gridSize, root.gridSnap, root.itemId)
        if (!DesktopItems.update(root.itemId, {
                output: name,
                x: arranged.x,
                y: arranged.y
            }))
            return
        GlobalStates.selectDesktopItem(name + "::desktopItem." + root.itemId)
    }

    function _reconcilePersistedPosition(): void {
        if (!root._componentReady || root._positionOverride
                || String(root.itemData?.output ?? "") !== root.outputName)
            return
        const arranged = DesktopItems.arrangePosition(root.outputName,
            Number(root.itemData?.x ?? 0), Number(root.itemData?.y ?? 0),
            Number(root.workArea.width ?? root.canvasWidth),
            Number(root.workArea.height ?? root.canvasHeight),
            root.gridSize, root.gridSnap, root.itemId)
        const x = arranged.x
        const y = arranged.y
        if (x === Math.round(Number(root.itemData?.x ?? 0))
                && y === Math.round(Number(root.itemData?.y ?? 0)))
            return
        DesktopItems.update(root.itemId, { x: x, y: y })
    }

    function select(): void {
        GlobalStates.selectDesktopItem(root.instanceKey)
    }

    function activate(): void {
        root.select()
        if (!root.targetAvailable) {
            root._openTargetParent()
            return
        }
        if (root.isApplication) {
            const entry = AppSearch.lookupDesktopEntry(root.target)
            if (entry)
                AppSearch.launchEntry(entry)
        } else {
            ShellExec.execDetachedArgs(["xdg-open", root.target], "Open desktop item")
        }
    }

    function _openTargetParent(): void {
        if (root.isApplication || /^https?:\/\//i.test(root.target))
            return
        const parent = FileUtils.parentDirectory(root.target)
        if (parent.length > 0)
            ShellExec.execDetachedArgs(["xdg-open", "file://" + parent], "Open desktop item folder")
    }

    function _remove(): void {
        if (DesktopItems.remove(root.itemId))
            GlobalStates.clearDesktopItemSelection()
    }

    function beginRename(): void {
        root.editText = root.label
        root.editMode = "label"
        renameField.forceActiveFocus()
        renameField.selectAll()
    }

    function beginDestinationEdit(): void {
        root.editText = root.target
        root.editMode = "destination"
        renameField.forceActiveFocus()
        renameField.selectAll()
    }

    function finishEdit(commit: bool): void {
        const value = root.editText.trim()
        if (commit && value.length > 0) {
            if (root.editMode === "destination")
                DesktopItems.repair(root.itemId, value)
            else
                DesktopItems.update(root.itemId, { label: value, customLabel: true })
        }
        root.editMode = ""
    }

    function _showMenu(anchorX: real, anchorY: real): void {
        const model = [
            { text: Translation.tr("Open"), iconName: "open_in_new", monochromeIcon: true,
                enabled: root.targetAvailable, action: () => root.activate() },
            { text: Translation.tr("Locate target"), iconName: "folder_open", monochromeIcon: true,
                enabled: !root.targetAvailable && !root.isApplication, action: () => root._openTargetParent() },
            { text: Translation.tr("Edit destination"), iconName: "edit", monochromeIcon: true,
                action: () => root.beginDestinationEdit() },
            { text: Translation.tr("Rename"), iconName: "drive_file_rename_outline", monochromeIcon: true,
                action: () => root.beginRename() },
            { text: root.locked ? Translation.tr("Unlock") : Translation.tr("Lock"), iconName: root.locked ? "lock_open" : "lock", monochromeIcon: true,
                action: () => DesktopItems.update(root.itemId, { locked: !root.locked }) },
            { text: Translation.tr("Promote to front"), iconName: "flip_to_front", monochromeIcon: true,
                action: () => DesktopItems.update(root.itemId, {
                    layer: Math.min(299, Number(root.itemData?.layer ?? 0) + 1)
                }) }
        ]
        const persistedOutput = String(root.itemData?.output ?? "")
        const otherOutputs = Quickshell.screens.filter(screen =>
            String(screen?.name ?? "") !== persistedOutput)
        if (otherOutputs.length > 0) {
            model.push({ type: "separator" })
            for (const screen of otherOutputs) {
                const name = String(screen?.name ?? "")
                model.push({
                    text: Translation.tr("Move") + " · " + name,
                    iconName: "monitor",
                    monochromeIcon: true,
                    action: () => root._moveToOutput(name)
                })
            }
        }
        model.push(
            { type: "separator" },
            { text: Translation.tr("Remove from desktop"), iconName: "delete", monochromeIcon: true,
                action: () => root._remove() },
            { text: Translation.tr("Undo remove"), iconName: "undo", monochromeIcon: true,
                enabled: DesktopItems.canUndo, action: () => DesktopItems.undoRemove() }
        )
        root.contextMenuRequested(model, anchorX, anchorY)
    }

    Process {
        id: targetProbe
        running: false
        onExited: (exitCode, exitStatus) => {
            root._targetProbePending = false
            root._targetExists = exitCode === 0
        }
    }

    Component.onCompleted: {
        root._componentReady = true
        root._refreshTarget()
        positionReconcile.restart()
    }
    onTargetChanged: if (root._componentReady) root._refreshTarget()
    onWorkAreaChanged: if (root._componentReady) positionReconcile.restart()
    onGridSizeChanged: {
        if (root._componentReady && !root.locked)
            positionReconcile.restart()
    }
    onGridSnapChanged: {
        if (root._componentReady && !root.locked && root.gridSnap)
            positionReconcile.restart()
    }

    Timer {
        id: positionReconcile
        interval: 120
        repeat: false
        onTriggered: root._reconcilePersistedPosition()
    }

    Rectangle {
        id: selectionPlate
        anchors.fill: parent
        anchors.margins: 2
        radius: Appearance.rounding.large
        color: root.selected || root._dragging
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.14)
            : mouse.containsMouse
                ? ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainerHighest, 0.10)
                : "transparent"
        // Cookie separates selected content by tonal plates. An outline here,
        // plus the icon plate and the icon artwork, produced three nested rings.
        border.width: Appearance.cookieEverywhere
            ? 0 : (root.selected || root._dragging || mouse.containsMouse ? 1 : 0)
        border.color: root.selected || root._dragging
            ? Appearance.colors.colPrimary
            : ColorUtils.applyAlpha(Appearance.colors.colOutline, 0.46)
        opacity: 1

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    Rectangle {
        id: iconPlate
        anchors.top: parent.top
        anchors.topMargin: 7
        anchors.horizontalCenter: parent.horizontalCenter
        width: 54
        height: 54
        radius: Appearance.rounding.normal
        color: root.selected || root._dragging
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimaryContainer, 0.58)
            : mouse.containsMouse
                ? ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainerHighest, 0.36)
                : "transparent"
        // The outer selection plate already owns selection emphasis. Keep this
        // border only for a broken target so every dialect avoids double frames.
        border.width: root.targetAvailable || root._targetProbePending ? 0 : 2
        border.color: root.targetAvailable || root._targetProbePending
            ? ColorUtils.applyAlpha(Appearance.colors.colPrimary, 0.48)
            : Appearance.colors.colError

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        IconImage {
            id: icon
            anchors.centerIn: parent
            implicitSize: DesktopItems.itemIconSize
            source: {
                const entry = root.isApplication ? AppSearch.lookupDesktopEntry(root.target) : null
                const iconName = String(root.itemData?.icon ?? entry?.icon ?? "")
                return AppSearch.resolveIcon(iconName,
                    root.targetAvailable ? "text-x-generic" : "dialog-warning")
            }
            opacity: root.targetAvailable ? 1 : 0.48
            scale: root._dragging ? 0.92 : 1
            Behavior on scale {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: -3
            width: 19
            height: 19
            radius: Appearance.rounding.full
            visible: !root.targetAvailable && !root._targetProbePending
            color: Appearance.colors.colError

            MaterialSymbol {
                anchors.centerIn: parent
                text: "priority_high"
                iconSize: 13
                color: Appearance.colors.colOnError
            }
        }
    }

    Rectangle {
        id: labelPlate
        anchors.top: iconPlate.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(root.width - 4, Math.max(48, labelText.implicitWidth + 12))
        height: Math.min(31, Math.max(23, labelText.implicitHeight + 5))
        radius: Appearance.rounding.small
        color: root.selected || mouse.containsMouse || root.editMode.length > 0
            ? ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainerHighest, 0.72)
            : ColorUtils.applyAlpha(Appearance.colors.colSurfaceContainer, 0.38)
    }

    StyledText {
        id: labelText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: iconPlate.bottom
        anchors.topMargin: 4
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignTop
        elide: Text.ElideRight
        maximumLineCount: 2
        wrapMode: Text.Wrap
        text: root.label
        visible: root.editMode.length === 0
        color: Appearance.colors.colOnSurface
        font.pixelSize: Appearance.font.pixelSize.small
        opacity: root.targetAvailable || root._targetProbePending ? 1 : 0.76
    }

    TextInput {
        id: renameField
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: iconPlate.bottom
        anchors.topMargin: 5
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        visible: root.editMode.length > 0
        text: root.editText
        color: Appearance.colors.colOnSurface
        font.pixelSize: Appearance.font.pixelSize.small
        horizontalAlignment: Text.AlignHCenter
        selectByMouse: true
        onTextChanged: root.editText = text
        Keys.onReturnPressed: root.finishEdit(true)
        Keys.onEscapePressed: root.finishEdit(false)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.smoothed: false
        drag.minimumX: Number(root.workArea.left ?? 0)
        drag.minimumY: Number(root.workArea.top ?? 0)
        drag.maximumX: Math.max(Number(root.workArea.left ?? 0), Number(root.workArea.right ?? root.canvasWidth) - root.width)
        drag.maximumY: Math.max(Number(root.workArea.top ?? 0), Number(root.workArea.bottom ?? root.canvasHeight) - root.height)
        drag.threshold: 8
        enabled: !GlobalStates.screenLocked
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                root.contextMenuCloseRequested()
            root.select()
            root._pressX = root.x
            root._pressY = root.y
            if (event.button === Qt.RightButton)
                mouse.drag.target = null
            else if (root.locked || !root.dragEnabled)
                mouse.drag.target = null
            else
                root._positionOverride = true
        }
        onReleased: event => {
            mouse.drag.target = root
            if (event.button === Qt.RightButton) {
                root._showMenu(event.x, event.y)
                return
            }
            if (!root._positionOverride)
                return
            const pos = root._clampPosition(root.x, root.y)
            root.x = pos.x
            root.y = pos.y
            if (Math.abs(root.x - root._pressX) > 1 || Math.abs(root.y - root._pressY) > 1)
                DesktopItems.update(root.itemId, {
                    output: root.outputName,
                    x: root.x - Number(root.workArea.left ?? 0),
                    y: root.y - Number(root.workArea.top ?? 0)
                })
            root._positionOverride = false
        }
        onCanceled: {
            mouse.drag.target = root
            root.x = root._pressX
            root.y = root._pressY
            root._positionOverride = false
        }
        onDoubleClicked: root.activate()
    }

    readonly property bool _dragging: mouse.drag.active

}
