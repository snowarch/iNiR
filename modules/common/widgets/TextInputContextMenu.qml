import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property var target

    anchors.fill: parent

    Item {
        id: anchor
        width: 1
        height: 1
    }

    function _hasSelection(): bool {
        return (root.target?.selectedText ?? "").length > 0
    }

    function _isEditable(): bool {
        return !(root.target?.readOnly ?? false)
    }

    function _menuModel(): var {
        const items = []
        const canUndo = root.target?.canUndo ?? false
        const canRedo = root.target?.canRedo ?? false

        items.push({
            text: Translation.tr("Undo"),
            iconName: "undo",
            monochromeIcon: true,
            enabled: canUndo,
            action: () => root.target?.undo()
        })

        items.push({
            text: Translation.tr("Redo"),
            iconName: "redo",
            monochromeIcon: true,
            enabled: canRedo,
            action: () => root.target?.redo()
        })

        items.push({ type: "separator" })

        if (root._isEditable() && root._hasSelection()) {
            items.push({
                text: Translation.tr("Cut"),
                iconName: "content_cut",
                monochromeIcon: true,
                action: () => root.target?.cut()
            })
        }

        if (root._hasSelection()) {
            items.push({
                text: Translation.tr("Copy"),
                iconName: "content_copy",
                monochromeIcon: true,
                action: () => root.target?.copy()
            })
        }

        if (root._isEditable()) {
            items.push({
                text: Translation.tr("Paste"),
                iconName: "content_paste",
                monochromeIcon: true,
                action: () => root.target?.paste()
            })
        }

        if (root._isEditable() && root._hasSelection()) {
            items.push({
                text: Translation.tr("Delete"),
                iconName: "delete",
                monochromeIcon: true,
                action: () => root.target?.remove(root.target.selectionStart, root.target.selectionEnd)
            })
        }

        const textLength = (root.target?.text ?? "").length
        if (textLength > 0) {
            if (items.length > 0) {
                items.push({ type: "separator" })
            }
            items.push({
                text: Translation.tr("Select all"),
                iconName: "select_all",
                monochromeIcon: true,
                action: () => root.target?.selectAll()
            })
        }

        return items
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.IBeamCursor
        onPressed: mouse => {
            root.target?.forceActiveFocus()
            anchor.x = mouse.x
            anchor.y = mouse.y
            mouse.accepted = true
        }
        onClicked: mouse => {
            const model = root._menuModel()
            if (model.length === 0) return
            root.target?.forceActiveFocus()
            contextMenu.model = model
            contextMenu.requestOpen()
            mouse.accepted = true
        }
    }

    ContextMenu {
        id: contextMenu
        anchorItem: anchor
        closeOnHoverLost: false
        model: []
    }
}
