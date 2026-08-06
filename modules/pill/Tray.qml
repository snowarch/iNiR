pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.modules.common

/**
 * System tray. Draws StatusNotifier items as warm-tinted icons. Left-click
 * activates, middle-click does the secondary action, right-click asks the shell
 * to open the item's native menu, wheel scrolls the item.
 *
 * The menu itself is not built here: it needs its own layer-shell window, which
 * cannot be declared under an Item that already belongs to another window. The
 * tray raises `menuRequested` and PillTrayMenu, hosted at the root Scope, owns it.
 */
Item {
    id: tray

    property real s: 1
    property var barWindow

    visible: SystemTray.items.values.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 24 * tray.s

    /** Raised for the shell to open this item's native menu at the given x. */
    signal menuRequested(var item, real anchorX)

    /** Set by the shell while it is showing a menu for this tray. */
    property bool menuOpen: false

    function showMenu(item, anchorItem) {
        if (!item.hasMenu)
            return;
        const p = anchorItem.mapToItem(null, anchorItem.width / 2, 0);
        tray.menuRequested(item, p.x);
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2 * tray.s

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: slot

                required property var modelData

                Layout.preferredWidth: 24 * tray.s
                Layout.preferredHeight: 24 * tray.s

                Rectangle {
                    anchors.fill: parent
                    radius: 6 * tray.s
                    color: PillTheme.frameBg
                    border.width: 1
                    border.color: PillTheme.frameBorder
                    opacity: area.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
                }

                Image {
                    anchors.centerIn: parent
                    source: slot.modelData.icon
                    sourceSize.width: 32
                    sourceSize.height: 32
                    width: 16 * tray.s
                    height: 16 * tray.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true
                    /**
                     * Loaded on the GUI thread on purpose. StatusNotifier icons
                     * come from an image:// provider that builds QObjects while
                     * decoding; on QQuickPixmapReader's thread Qt parents them to
                     * the QApplication and warns on every launch. These are 16px
                     * icons — the synchronous decode is not worth the noise.
                     */
                    asynchronous: false
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            slot.modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            tray.showMenu(slot.modelData, slot);
                        } else if (slot.modelData.onlyMenu) {
                            tray.showMenu(slot.modelData, slot);
                        } else {
                            slot.modelData.activate();
                        }
                    }
                    onWheel: (wheel) => {
                        slot.modelData.scroll(wheel.angleDelta.y, false);
                    }
                }

                Tooltip {
                    s: tray.s
                    placement: "below"
                    title: slot.modelData.tooltipTitle || slot.modelData.title || slot.modelData.id
                    show: area.containsMouse && !tray.menuOpen
                }
            }
        }
    }
}
