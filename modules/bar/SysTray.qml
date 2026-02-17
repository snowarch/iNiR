import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
    id: root
    implicitWidth: gridLayout.implicitWidth
    implicitHeight: gridLayout.implicitHeight
    property bool vertical: false
    property bool invertSide: false
    property bool trayOverflowOpen: false
    property bool showSeparator: true
    property bool showOverflowMenu: true
    property var activeMenu: null

    Timer {
        id: overflowAutoCloseTimer
        interval: 700
        repeat: false
        onTriggered: root.trayOverflowOpen = false
    }

    function updateOverflowAutoClose(): void {
        if (!root.trayOverflowOpen) {
            overflowAutoCloseTimer.stop();
            return;
        }
        const hovering = trayOverflowButton.hovered || overflowPopup.popupHovered
        if (hovering) overflowAutoCloseTimer.stop();
        else overflowAutoCloseTimer.restart();
    }

    // Signal to close all tray menus before opening a new one
    signal closeAllTrayMenus()

    property bool smartTray: Config.options.bar.tray.filterPassive
    
    // Filter out invalid items (null or missing id)
    function isValidItem(item) {
        return item && item.id;
    }
    
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => {
        if (!isValidItem(i)) return false;
        const id = (i.id || "").toLowerCase();
        const title = (i.title || "").toLowerCase();
        const isSpotify = id.indexOf("spotify") !== -1 || title.indexOf("spotify") !== -1;
        return (Config.options?.bar?.tray?.pinnedItems ?? []).includes(i.id)
                && (!smartTray || i.status !== Status.Passive || isSpotify);
    })
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => {
        if (!isValidItem(i)) return false;
        const id = (i.id || "").toLowerCase();
        const title = (i.title || "").toLowerCase();
        const isSpotify = id.indexOf("spotify") !== -1 || title.indexOf("spotify") !== -1;
        return !(Config.options?.bar?.tray?.pinnedItems ?? []).includes(i.id)
                && (!smartTray || i.status !== Status.Passive || isSpotify);
    })

    property bool invertPins: Config.options?.bar?.tray?.invertPinnedItems ?? false
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList
    onUnpinnedItemsChanged: {
        if (unpinnedItems.length == 0) root.closeOverflowMenu();
    }

    function grabFocus() {
        focusGrab.active = true;
    }

    function setExtraWindowAndGrabFocus(window) {
        root.activeMenu = window;
        root.grabFocus();
    }

    function releaseFocus() {
        focusGrab.active = false;
    }

    function closeOverflowMenu() {
        focusGrab.active = false;
    }

    CompositorFocusGrab {
        id: focusGrab
        active: (root.trayOverflowOpen && overflowPopup.QsWindow?.window !== null) || root.activeMenu !== null
        windows: [overflowPopup.QsWindow?.window, root.activeMenu]
        onCleared: {
            root.trayOverflowOpen = false;
            if (root.activeMenu) {
                root.activeMenu.close();
                root.activeMenu = null;
            }
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.fill: parent
        rowSpacing: 8
        columnSpacing: 15

        RippleButton {
            id: trayOverflowButton
            visible: root.showOverflowMenu && root.unpinnedItems.length > 0
            toggled: root.trayOverflowOpen
            property bool containsMouse: hovered

            onHoveredChanged: root.updateOverflowAutoClose()

            downAction: () => root.trayOverflowOpen = !root.trayOverflowOpen

            Layout.fillHeight: !root.vertical
            Layout.fillWidth: root.vertical
            background.implicitWidth: 24
            background.implicitHeight: 24
            background.anchors.centerIn: this
            colBackgroundToggled: Appearance.inirEverywhere ? Appearance.inir.colSelection 
                : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface 
                : Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.inirEverywhere ? Appearance.inir.colSelectionHover 
                : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover 
                : Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive 
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive 
                : Appearance.colors.colSecondaryContainerActive

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.larger
                text: "expand_more"
                horizontalAlignment: Text.AlignHCenter
                color: root.trayOverflowOpen
                    ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary : Appearance.inirEverywhere ? Appearance.inir.colOnSelection : Appearance.colors.colOnSecondaryContainer)
                    : (Appearance.angelEverywhere ? Appearance.angel.colText : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer2)
                rotation: (root.trayOverflowOpen ? 180 : 0) - (90 * root.vertical) + (180 * root.invertSide)
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            StyledPopup {
                id: overflowPopup
                hoverTarget: trayOverflowButton
                hoverActivates: false
                active: root.trayOverflowOpen && root.unpinnedItems.length > 0
                popupBackgroundMargin: 0
                closeOnOutsideClick: false
                onRequestClose: root.trayOverflowOpen = false
                onPopupHoveredChanged: root.updateOverflowAutoClose()
                onActiveChanged: root.updateOverflowAutoClose()

                GridLayout {
                    id: trayOverflowLayout
                    anchors.centerIn: parent
                    columns: Math.ceil(Math.sqrt(root.unpinnedItems.length))
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: root.unpinnedItems

                        delegate: SysTrayItem {
                            required property SystemTrayItem modelData
                            item: modelData
                            trayParent: root
                            Layout.fillHeight: !root.vertical
                            Layout.fillWidth: root.vertical
                            onMenuClosed: root.releaseFocus();
                            onMenuOpened: (qsWindow) => root.setExtraWindowAndGrabFocus(qsWindow);
                        }
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.pinnedItems
            }

            delegate: SysTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                trayParent: root
                Layout.fillHeight: !root.vertical
                Layout.fillWidth: root.vertical
                onMenuClosed: root.releaseFocus();
                onMenuOpened: (qsWindow) => {
                    root.setExtraWindowAndGrabFocus(qsWindow);
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
            text: "•"
            visible: root.showSeparator && SystemTray.items.values.length > 0
        }
    }
}
