pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 10

    property int configVersion: 0
    property string liftedId: ""
    property string liftedSource: ""

    readonly property var defaultModules: ["locator", "trail", "niri", "actions", "stash"]
    readonly property var descriptors: ({
        locator: { icon: "hub", label: Translation.tr("Workspace") },
        trail: { icon: "history", label: Translation.tr("Trail") },
        niri: { icon: "view_column", label: Translation.tr("Niri controls") },
        actions: { icon: "bolt", label: Translation.tr("Actions") },
        stash: { icon: "inventory_2", label: Translation.tr("Stash") }
    })
    readonly property var shelfModules: {
        root.configVersion
        const saved = Config.options?.orbit?.shelf?.modules ?? root.defaultModules
        const result = []
        const source = Array.isArray(saved) ? saved : root.defaultModules
        for (const id of source) {
            if (!root.defaultModules.includes(id) || result.includes(id)) continue
            result.push(id)
        }
        return result
    }
    readonly property var availableModules: root.defaultModules.filter(id => !root.shelfModules.includes(id))

    function toggleLift(source: string, id: string): void {
        if (liftedSource === source && liftedId === id) {
            cancelLift()
            return
        }
        liftedSource = source
        liftedId = id
    }

    function cancelLift(): void {
        liftedSource = ""
        liftedId = ""
    }

    function saveModules(modules): void {
        Config.setNestedValue("orbit.shelf.modules", modules)
        cancelLift()
    }

    function place(insertPosition: int): void {
        const order = [...shelfModules]
        if (liftedSource === "available") {
            const target = Math.max(0, Math.min(insertPosition, order.length))
            order.splice(target, 0, liftedId)
            saveModules(order)
            return
        }
        const from = order.indexOf(liftedId)
        if (liftedSource !== "shelf" || from < 0) {
            cancelLift()
            return
        }
        const moved = order.splice(from, 1)[0]
        let target = insertPosition
        if (target > from) target--
        target = Math.max(0, Math.min(target, order.length))
        order.splice(target, 0, moved)
        saveModules(order)
    }

    function removeLifted(): void {
        if (liftedSource !== "shelf") return
        saveModules(shelfModules.filter(id => id !== liftedId))
    }

    Connections {
        target: Config
        function onConfigChanged(): void { root.configVersion++ }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                text: Translation.tr("Shelf modules")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Tap a module to lift it, then choose a slot. Removed modules stay available below.")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }

        RippleButtonWithIcon {
            materialIcon: "restart_alt"
            mainText: Translation.tr("Reset")
            onClicked: root.saveModules(root.defaultModules)
        }
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 44

        Flickable {
            anchors.fill: parent
            contentWidth: shelfOrderRow.implicitWidth
            contentHeight: height
            clip: true
            interactive: contentWidth > width
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: shelfOrderRow
                height: parent.height
                spacing: 6

                Repeater {
                    model: root.shelfModules

                    delegate: Row {
                        id: shelfDelegate
                        required property string modelData
                        required property int index
                        height: shelfOrderRow.height
                        spacing: 6
                        readonly property var descriptor: root.descriptors[modelData]

                        ArrangeDropSlot {
                            anchors.verticalCenter: parent.verticalCenter
                            active: root.liftedId.length > 0
                                && !(root.liftedSource === "shelf"
                                    && (root.liftedId === shelfDelegate.modelData
                                        || (shelfDelegate.index > 0
                                            && root.shelfModules[shelfDelegate.index - 1] === root.liftedId)))
                            onPlaced: root.place(shelfDelegate.index)
                        }

                        ArrangeChip {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: shelfDelegate.descriptor?.icon ?? "widgets"
                            label: shelfDelegate.descriptor?.label ?? shelfDelegate.modelData
                            lifted: root.liftedSource === "shelf" && root.liftedId === shelfDelegate.modelData
                            dimmed: root.liftedId.length > 0 && !lifted
                            onTapped: root.toggleLift("shelf", shelfDelegate.modelData)
                        }
                    }
                }

                ArrangeDropSlot {
                    anchors.verticalCenter: parent.verticalCenter
                    active: root.liftedId.length > 0
                        && !(root.liftedSource === "shelf"
                            && root.shelfModules[root.shelfModules.length - 1] === root.liftedId)
                    onPlaced: root.place(root.shelfModules.length)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.availableModules.length > 0 || root.liftedSource === "shelf"
        spacing: 8

        StyledText {
            text: Translation.tr("Available")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.availableModules

                ArrangeChip {
                    required property string modelData
                    readonly property var descriptor: root.descriptors[modelData]
                    icon: descriptor?.icon ?? "widgets"
                    label: descriptor?.label ?? modelData
                    lifted: root.liftedSource === "available" && root.liftedId === modelData
                    dimmed: root.liftedId.length > 0 && !lifted
                    onTapped: root.toggleLift("available", modelData)
                }
            }
        }

        RippleButtonWithIcon {
            visible: root.liftedSource === "shelf"
            materialIcon: "remove"
            mainText: Translation.tr("Remove")
            onClicked: root.removeLifted()
        }
    }

    RippleButtonWithIcon {
        visible: root.liftedId.length > 0
        materialIcon: "close"
        mainText: Translation.tr("Cancel move")
        onClicked: root.cancelLift()
    }
}
