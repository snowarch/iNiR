pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The right click menu of every text field, in the active family's look. A field opts in with (QQC is
// QtQuick.Controls: the kit has a ContextMenu of its own that hides Qt's attached one)
//     QQC.ContextMenu.menu: null
//     QQC.ContextMenu.onRequested: position => TextEditMenu.open(this, position)
// Qt's own menu (6.9+) is a Controls popup: it lives beside Quickshell's content item, so a panel that closes when
// the pointer leaves it closed under the menu. This one is drawn inside the window's content.
Singleton {
    id: root

    property Item current: null

    function open(editor: Item, position: point): void {
        root.close()
        const host = root.hostOf(editor)
        if (!host) return
        if (!editor.activeFocus) editor.forceActiveFocus()
        const at = editor.mapToItem(host, position.x, position.y)
        root.current = menuComponent.createObject(host, { editor: editor, anchorX: at.x, anchorY: at.y })
    }

    function close(): void {
        if (root.current) root.current.dismiss()
        root.current = null
    }

    // The top of the item tree that still belongs to the window's content (Quickshell's own content item).
    function hostOf(item: Item): Item {
        let node = item
        let below = null
        while (node && node.parent) {
            below = node
            node = node.parent
        }
        return below ?? node
    }

    Component {
        id: menuComponent

        Item {
            id: menu

            required property Item editor
            required property real anchorX
            required property real anchorY
            readonly property real s: FamilyStyle.density
            readonly property bool own: FamilyStyle.p !== null
            readonly property real pad: Math.round(6 * menu.s)
            readonly property real margin: Math.round(8 * menu.s)
            readonly property bool secret: (menu.editor?.echoMode ?? TextInput.Normal) !== TextInput.Normal
            readonly property string selected: menu.editor?.selectedText ?? ""
            readonly property bool editable: !(menu.editor?.readOnly ?? true)
            readonly property bool canCut: menu.editable && !menu.secret && menu.selected.length > 0
            readonly property bool canCopy: !menu.secret && menu.selected.length > 0
            readonly property bool canPaste: menu.editable && (menu.editor?.canPaste ?? false)
            readonly property bool canUndo: menu.editable && (menu.editor?.canUndo ?? false)
            readonly property bool canRedo: menu.editable && (menu.editor?.canRedo ?? false)
            readonly property bool canSelectAll: String(menu.editor?.text ?? "").length > menu.selected.length

            property real shown: 0
            property bool leaving: false

            function run(action: string): void {
                const target = menu.editor
                root.close()
                if (!target) return
                target.forceActiveFocus()
                target[action]()
            }

            // Only this menu: a leaving one hearing its editor go must not close the one that replaced it.
            function closeSelf(): void {
                if (root.current === menu) root.current = null
                menu.dismiss()
            }

            function dismiss(): void {
                if (menu.leaving) return
                menu.leaving = true
                menu.shown = 0
                gone.start()
            }

            anchors.fill: parent
            z: 1e6
            onEditorChanged: if (!menu.editor) menu.closeSelf()
            Component.onCompleted: menu.shown = 1
            Behavior on shown {
                NumberAnimation {
                    duration: menu.leaving ? FamilyStyle.recedeDuration : FamilyStyle.emergeDuration
                    easing.type: Easing.OutCubic
                }
            }
            Timer {
                id: gone
                interval: FamilyStyle.recedeDuration + 20
                onTriggered: menu.destroy()
            }
            Connections {
                target: menu.leaving ? null : menu.editor
                function onActiveFocusChanged(): void { if (!(menu?.editor?.activeFocus ?? false)) menu?.closeSelf() }
                function onVisibleChanged(): void { if (!(menu?.editor?.visible ?? false)) menu?.closeSelf() }
            }

            // A press anywhere else only closes the menu, as in any app.
            MouseArea {
                anchors.fill: parent
                enabled: !menu.leaving
                acceptedButtons: Qt.AllButtons
                onPressed: root.close()
                onWheel: root.close()
            }

            Item {
                id: card
                readonly property bool flipX: menu.anchorX + card.width + menu.margin > menu.width
                readonly property bool flipY: menu.anchorY + card.height + menu.margin > menu.height
                readonly property real radius: FamilyStyle.radiusTile
                width: Math.round(212 * menu.s)
                height: Math.round(list.implicitHeight + 2 * menu.pad)
                x: Math.round(Math.max(menu.margin, Math.min(menu.width - card.width - menu.margin,
                    card.flipX ? menu.anchorX - card.width : menu.anchorX)))
                y: Math.round(Math.max(menu.margin, Math.min(menu.height - card.height - menu.margin,
                    card.flipY ? menu.anchorY - card.height : menu.anchorY)))
                transformOrigin: card.flipY ? (card.flipX ? Item.BottomRight : Item.BottomLeft)
                    : (card.flipX ? Item.TopRight : Item.TopLeft)
                opacity: menu.shown
                scale: 0.94 + 0.06 * menu.shown

                // Presses inside the card are the card's.
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

                StyledRectangularShadow {
                    target: card
                    visible: !menu.own
                }
                Loader {
                    anchors.fill: parent
                    active: !menu.own
                    sourceComponent: PanelSurface {
                        elevation: 2
                        cardStyle: true
                        opaqueSurface: true
                        radiusOverride: card.radius
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    visible: menu.own
                    radius: card.radius
                    color: FamilyStyle.surface
                    Rectangle {
                        anchors.fill: parent
                        radius: card.radius
                        color: FamilyStyle.surfaceHigh
                        border.width: 1
                        border.color: FamilyStyle.border
                    }
                }

                Column {
                    id: list
                    readonly property real rowRadius: FamilyStyle.concentric(card.radius, menu.pad, FamilyStyle.radiusChip)
                    x: menu.pad
                    y: menu.pad
                    width: card.width - 2 * menu.pad
                    spacing: Math.round(2 * menu.s)

                    Row {
                        id: tiles
                        width: parent.width
                        spacing: Math.round(2 * menu.s)
                        Repeater {
                            model: [
                                { action: "cut", glyph: "content_cut", label: Translation.tr("Cut"), on: menu.canCut },
                                { action: "copy", glyph: "content_copy", label: Translation.tr("Copy"), on: menu.canCopy },
                                { action: "paste", glyph: "content_paste", label: Translation.tr("Paste"), on: menu.canPaste }
                            ]
                            delegate: MouseArea {
                                id: tile
                                required property var modelData
                                width: (list.width - 2 * tiles.spacing) / 3
                                height: Math.round(54 * menu.s)
                                enabled: tile.modelData.on
                                hoverEnabled: true
                                cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                Accessible.role: Accessible.Button
                                Accessible.name: tile.modelData.label
                                onClicked: menu.run(tile.modelData.action)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: list.rowRadius
                                    color: tile.pressed ? FamilyStyle.fillActive : tile.containsMouse ? FamilyStyle.fillHover : "transparent"
                                    Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: Math.round(3 * menu.s)
                                    opacity: tile.enabled ? 1 : 0.35
                                    MaterialSymbol {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tile.modelData.glyph
                                        iconSize: Math.round(19 * menu.s)
                                        color: FamilyStyle.textStrong
                                    }
                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: tile.modelData.label
                                        color: FamilyStyle.textSecondary
                                        font.family: FamilyStyle.fontMain
                                        font.pixelSize: FamilyStyle.typeFootnote
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - 2 * menu.pad
                        x: menu.pad
                        height: 1
                        color: FamilyStyle.border
                        visible: rows.count > 0
                    }

                    Repeater {
                        id: rows
                        model: [
                            { action: "selectAll", glyph: "select_all", label: Translation.tr("Select all"), on: menu.canSelectAll },
                            { action: "undo", glyph: "undo", label: Translation.tr("Undo"), on: menu.canUndo },
                            { action: "redo", glyph: "redo", label: Translation.tr("Redo"), on: menu.canRedo }
                        ].filter(entry => entry.on)
                        delegate: MouseArea {
                            id: row
                            required property var modelData
                            width: list.width
                            height: Math.round(34 * menu.s)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.MenuItem
                            Accessible.name: row.modelData.label
                            onClicked: menu.run(row.modelData.action)
                            Rectangle {
                                anchors.fill: parent
                                radius: list.rowRadius
                                color: row.pressed ? FamilyStyle.fillActive : row.containsMouse ? FamilyStyle.fillHover : "transparent"
                                Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
                            }
                            StyledText {
                                anchors.left: parent.left
                                anchors.leftMargin: Math.round(10 * menu.s)
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.label
                                color: FamilyStyle.text
                                font.family: FamilyStyle.fontMain
                                font.pixelSize: FamilyStyle.typeLabel
                            }
                            MaterialSymbol {
                                anchors.right: parent.right
                                anchors.rightMargin: Math.round(10 * menu.s)
                                anchors.verticalCenter: parent.verticalCenter
                                text: row.modelData.glyph
                                iconSize: Math.round(17 * menu.s)
                                color: FamilyStyle.textSecondary
                            }
                        }
                    }
                }
            }
        }
    }
}
