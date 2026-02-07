pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.bar

RowLayout {
    id: root

    property bool overflowOpen: false
    property bool dragging: false
    
    // Signal to close all tray menus before opening a new one
    signal closeAllTrayMenus()

    Layout.fillHeight: true
    spacing: 0

    BarIconButton {
        id: overflowButton

        visible: (TrayService.unpinnedItems.length > 0 || root.dragging) && !GameMode.active
        checked: root.overflowOpen

        iconName: "chevron-down"
        iconMonochrome: true
        iconRotation: ((Config.options?.waffles?.bar?.bottom ?? false) ? 180 : 0) + (root.overflowOpen ? 180 : 0)
        Behavior on iconRotation {
            animation: Looks.transition.rotate.createObject(this)
        }

        onClicked: {
            if (!root.overflowOpen) {
                trayOverflowLayout.active = true;
                root.overflowOpen = true;
            } else {
                trayOverflowLayout.close();
                root.overflowOpen = false;
            }
        }

        TrayOverflowMenu {
            id: trayOverflowLayout
            property var trayRoot: root  // Explicit reference to parent Tray
            trayParent: trayRoot
            
            onActiveChanged: {
                // Sync state back to parent when popup closes
                if (!active && trayRoot) {
                    trayRoot.overflowOpen = false;
                }
            }
        }

        BarToolTip {
            extraVisibleCondition: overflowButton.shouldShowTooltip && !root.overflowOpen
            text: Translation.tr("Show hidden icons")
        }

        DropArea {
            id: pinDropArea
            anchors.fill: parent
            property bool willPin: false
            onEntered: willPin = true
            onExited: willPin = false
        }
    }

    ScriptModel {
        id: trayModel
        values: TrayService.pinnedItems
    }

    Repeater {
        model: GameMode.active ? null : trayModel
        delegate: TrayButton {
            id: trayButton
            required property var modelData
            item: modelData
            trayParent: root

            property real initialX
            property real initialY

            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: parent
                drag.axis: Drag.XAxis
                drag.threshold: 2

                onPressed: event => {
                    trayButton.Drag.hotSpot.x = event.x;
                    trayButton.initialX = trayButton.x;
                    root.dragging = true;
                    trayButton.Drag.active = true;
                }
                onPositionChanged: {
                    pinTooltip.updateAnchor();
                }
                onReleased: {
                    if (!dragArea.drag.active) {
                        trayButton.clicked();
                    } else {
                        if (pinDropArea.containsDrag && pinDropArea.willPin) {
                            // Quickshell would crash if we don't hide this item first. Took me fucking 3 hours to figure out...
                            trayButton.visible = false;
                            TrayService.togglePin(trayButton.item.id);
                            pinDropArea.willPin = false;
                        } else {
                            trayButton.x = trayButton.initialX;
                        }
                    }
                    trayButton.Drag.active = false;
                    root.dragging = false;
                }
            }

            BarToolTip {
                id: pinTooltip
                extraVisibleCondition: trayButton.Drag.active && pinDropArea.containsDrag && pinDropArea.willPin
                horizontalPadding: 6
                verticalPadding: 6
                realContentItem: FluentIcon {
                    anchors.centerIn: parent
                    icon: "pin-off"
                    implicitSize: 18
                }
            }
        }
    }
}
