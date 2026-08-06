pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.common

/**
 * The tray's native context menu, in a layer-shell window of its own so it can
 * grab keyboard focus for dismissal.
 *
 * It lives here, at the shell's root Scope, rather than inside Tray.qml. A
 * PanelWindow declared under an Item that already belongs to another window makes
 * Qt build it against the wrong parent and warn about creating children in a
 * different thread. The tray only raises `open()`; this owns the window.
 */
Scope {
    id: root

    property real s: 1
    property var hostWindow

    /**
     * The layer-shell window is built on first open, not at startup. An idle
     * PanelWindow parked from boot makes Qt construct parts of it off the main
     * thread and warn on every launch; a tray menu is rare enough that paying for
     * the window up front buys nothing.
     */
    property bool wantOpen: false
    property real anchorX: 0
    property int expandedIdx: -1

    readonly property bool shown: wantOpen

    function open(item, anchorX) {
        if (!item || !item.hasMenu)
            return;
        root.expandedIdx = -1;
        opener.menu = item.menu;
        root.anchorX = anchorX;
        root.wantOpen = true;
    }

    function close() {
        root.wantOpen = false;
        root.expandedIdx = -1;
        opener.menu = null;
    }

    QsMenuOpener {
        id: opener
    }

    /**
     * One menu line: separator, or a row with optional checkbox/radio state,
     * icon, label and a submenu chevron that rotates when expanded. Used for both
     * top-level entries and indented submenu children.
     *
     * `entryData` goes null for a frame after the menu closes, while the delegates
     * outlive the model — every read is guarded.
     */
    component MenuRow: Item {
        id: mrow

        property var entryData
        property real indent: 0
        property bool expanded: false
        signal activated()

        readonly property bool isSeparator: mrow.entryData?.isSeparator ?? false
        readonly property bool isEnabled: mrow.entryData?.enabled ?? false

        height: mrow.isSeparator ? 9 * root.s : 32 * root.s

        Rectangle {
            visible: mrow.isSeparator
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8 * root.s + mrow.indent
            anchors.rightMargin: 8 * root.s
            height: 1
            color: PillTheme.hair
        }

        Rectangle {
            visible: !mrow.isSeparator
            anchors.fill: parent
            anchors.leftMargin: mrow.indent
            radius: 8 * root.s
            color: mrowArea.containsMouse && mrow.isEnabled ? PillTheme.frameBg : "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 6 * root.s
                width: 2 * root.s
                height: parent.height * 0.46
                radius: width / 2
                color: PillTheme.vermLit
                opacity: mrowArea.containsMouse && mrow.isEnabled ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: PillMotion.fast } }
            }

            Rectangle {
                id: stateBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 16 * root.s
                readonly property int btype: mrow.entryData?.buttonType ?? QsMenuButtonType.None
                readonly property bool isCheck: btype === QsMenuButtonType.CheckBox
                readonly property bool isRadio: btype === QsMenuButtonType.RadioButton
                readonly property bool present: isCheck || isRadio
                readonly property bool checked: (mrow.entryData?.checkState ?? Qt.Unchecked) === Qt.Checked
                visible: present
                width: present ? 11 * root.s : 0
                height: 11 * root.s
                radius: isRadio ? width / 2 : 3 * root.s
                color: "transparent"
                border.width: 1
                border.color: checked ? PillTheme.vermLit : PillTheme.border

                Rectangle {
                    anchors.centerIn: parent
                    visible: stateBox.checked
                    width: 5 * root.s
                    height: 5 * root.s
                    radius: stateBox.isRadio ? width / 2 : 1.5 * root.s
                    color: PillTheme.vermLit
                }
            }

            Image {
                id: entryIcon
                anchors.left: stateBox.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: stateBox.present ? 8 * root.s : 0
                readonly property string src: mrow.entryData?.icon ?? ""
                width: src.length > 0 ? 15 * root.s : 0
                height: 15 * root.s
                source: src
                sourceSize.width: 30
                sourceSize.height: 30
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: true
                visible: src.length > 0
            }

            Text {
                anchors.left: entryIcon.right
                anchors.leftMargin: entryIcon.visible ? 9 * root.s : 0
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: chevron.visible ? chevron.left : parent.right
                anchors.rightMargin: 14 * root.s
                text: mrow.entryData?.text ?? ""
                color: mrow.isEnabled ? PillTheme.creamMenu : PillTheme.faint
                font.family: PillTheme.font
                font.pixelSize: 12 * root.s
                elide: Text.ElideRight
            }

            GlyphIcon {
                id: chevron
                anchors.right: parent.right
                anchors.rightMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 12 * root.s
                height: 12 * root.s
                visible: mrow.entryData?.hasChildren ?? false
                name: "chevron-right"
                color: PillTheme.faint
                stroke: 1.7
                rotation: mrow.expanded ? 90 : 0
                Behavior on rotation { NumberAnimation { duration: PillMotion.fast; easing.type: PillMotion.easeStandard } }
            }

            MouseArea {
                id: mrowArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: mrow.isEnabled
                cursorShape: Qt.PointingHandCursor
                onClicked: mrow.activated()
            }
        }
    }

    LazyLoader {
        active: root.wantOpen

    component: PanelWindow {
        id: menu

        screen: root.hostWindow ? root.hostWindow.screen : null
        visible: true
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "inir-pill-tray"

        anchors { top: true; left: true; right: true; bottom: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        FocusScope {
            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.close()

            Rectangle {
                id: card

                /** Whole pixels: a card on a half pixel renders its labels blurred. */
                x: Math.round(Math.max(8 * root.s, Math.min(root.anchorX - width / 2, menu.width - width - 8 * root.s)))
                y: Math.round(50 * root.s)
                width: Math.round(220 * root.s)
                radius: 12 * root.s
                clip: true

                gradient: Gradient {
                    GradientStop { position: 0.0; color: PillTheme.cardTop }
                    GradientStop { position: 1.0; color: PillTheme.cardBot }
                }
                border.width: 1
                border.color: PillTheme.border

                implicitHeight: col.implicitHeight + 12 * root.s
                height: implicitHeight

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 1
                    anchors.leftMargin: 10 * root.s
                    anchors.rightMargin: 10 * root.s
                    height: 1
                    color: PillTheme.sheen
                }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: PillTheme.shadow
                    shadowBlur: 0.9
                    shadowVerticalOffset: 4 * root.s
                }

                MouseArea { anchors.fill: parent }

                Column {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6 * root.s
                    spacing: 0

                    Repeater {
                        model: opener.children ? opener.children.values : []

                        delegate: Column {
                            id: entry

                            required property var modelData
                            required property int index
                            readonly property bool expanded: root.expandedIdx === index

                            width: col.width

                            MenuRow {
                                width: parent.width
                                entryData: entry.modelData
                                expanded: entry.expanded
                                onActivated: {
                                    if (entry.modelData?.hasChildren ?? false) {
                                        root.expandedIdx = entry.expanded ? -1 : entry.index;
                                    } else {
                                        entry.modelData?.triggered();
                                        root.close();
                                    }
                                }
                            }

                            QsMenuOpener {
                                id: childOpener
                                menu: entry.expanded ? entry.modelData : null
                            }

                            Repeater {
                                model: childOpener.children ? childOpener.children.values : []

                                delegate: MenuRow {
                                    id: childRow
                                    required property var modelData
                                    width: entry.width
                                    indent: 14 * root.s
                                    entryData: childRow.modelData
                                    onActivated: {
                                        if (!(childRow.modelData?.hasChildren ?? false)) {
                                            childRow.modelData?.triggered();
                                            root.close();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    }
}
