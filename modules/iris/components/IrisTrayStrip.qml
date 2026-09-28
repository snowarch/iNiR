pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.SystemTray
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style

Grid {
    id: root

    property real cellSize: 32
    property bool vertical: false
    property string screenName: ""
    property string menuToward: "down"
    property bool draggable: false
    property real screenOffsetY: 0
    readonly property var items: SystemTray.items.values.filter(item => item && item.id
        && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.Passive))
    signal cellHover(bool on)

    columns: root.vertical ? 1 : Math.max(1, root.items.length)
    spacing: Math.round(4 * IrisStyle.density)

    Repeater {
        model: root.items
        delegate: Item {
            id: cell
            required property var modelData
            width: root.cellSize
            height: root.cellSize

            function primary(): void {
                const item = cell.modelData
                if (!item) return
                if (item.onlyMenu && item.hasMenu) menu.open()
                else if (!TrayService.smartToggle(item)) item.activate()
            }

            IrisBubbleFace {
                anchors.fill: parent
                screenName: root.screenName
                kind: "trayApp"
                trayItem: cell.modelData
                plated: true
                hovered: hover.hovered
                pressed: grip.pressed || clicks.pressed
            }
            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: root.cellHover(hover.hovered)
            }
            Component.onDestruction: if (hover.hovered) root.cellHover(false)
            IrisBubbleGrip {
                id: grip
                anchors.fill: parent
                visible: root.draggable
                slot: "extra-tray"
                kind: "tray"
                screenName: root.screenName
                screenOffsetY: root.screenOffsetY
                holdLifts: !GlobalStates.irisEdit
                pullDistance: GlobalStates.irisEdit ? 6 * IrisStyle.density : 0
                onTapped: {
                    if (GlobalStates.irisEdit) return
                    cell.primary()
                }
            }
            MouseArea {
                id: clicks
                anchors.fill: parent
                acceptedButtons: root.draggable ? Qt.RightButton | Qt.MiddleButton : Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: event => {
                    const item = cell.modelData
                    if (!item) return
                    if (event.button === Qt.MiddleButton) item.secondaryActivate()
                    else if (event.button === Qt.RightButton) { if (item.hasMenu) menu.open() }
                    else cell.primary()
                }
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => cell.modelData?.scroll(event.angleDelta.y || event.angleDelta.x, event.angleDelta.y === 0)
            }
            IrisTrayMenu {
                id: menu
                handle: cell.modelData?.menu ?? null
                anchorItem: cell
                opensToward: root.menuToward
                title: String(cell.modelData?.tooltipTitle || cell.modelData?.title || cell.modelData?.id || "")
                icon: cell.modelData ? TrayService.getSafeIcon(cell.modelData) : ""
            }
            Accessible.role: Accessible.Button
            Accessible.name: String(cell.modelData?.tooltipTitle || cell.modelData?.title || cell.modelData?.id || "")
        }
    }
}
