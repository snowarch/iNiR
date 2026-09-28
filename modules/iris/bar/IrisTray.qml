pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ColumnLayout {
    id: root
    property bool bottomEdge: false
    readonly property real d: IrisStyle.density
    property var items: []
    property bool showHeader: true
    spacing: 12 * root.d

    RowLayout {
        visible: root.showHeader
        Layout.fillWidth: true
        IrisText { text: Translation.tr("Tray"); font.pixelSize: IrisStyle.typeTitleLarge; font.weight: IrisStyle.weight(Font.Bold) }
        IrisText { text: root.items.length; color: IrisStyle.secondaryAccent; font.weight: IrisStyle.weight(Font.Bold) }
        Item { Layout.fillWidth: true }
        IrisText { text: Translation.tr("Background apps"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: Math.max(2, Math.min(6, Config.options?.iris?.tray?.columns ?? 4))
        columnSpacing: 6 * root.d
        rowSpacing: 6 * root.d
        Repeater {
            model: root.items
            delegate: ColumnLayout {
                id: entry
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                spacing: 5 * root.d
                MouseArea {
                    id: button
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48 * root.d
                    implicitHeight: implicitWidth
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: entry.modelData?.tooltipTitle || entry.modelData?.title || entry.modelData?.id || ""
                    function activate(button: int): void {
                        const item = entry.modelData
                        if (!item) return
                        if (button === Qt.RightButton || (button === Qt.LeftButton && item.onlyMenu)) {
                            if (item.hasMenu) menu.open()
                        } else if (button === Qt.MiddleButton) item.secondaryActivate()
                        else if (!TrayService.smartToggle(item)) item.activate()
                    }
                    onClicked: event => button.activate(event.button)
                    activeFocusOnTab: true
                    Keys.onReturnPressed: button.activate(Qt.LeftButton)
                    Keys.onEnterPressed: button.activate(Qt.LeftButton)
                    Keys.onSpacePressed: button.activate(Qt.LeftButton)
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) {
                            button.activate(Qt.RightButton)
                            event.accepted = true
                        }
                    }
                    onVisibleChanged: if (!visible && menu.opened) menu.close()
                    onWheel: event => {
                        entry.modelData?.scroll(event.angleDelta.y || event.angleDelta.x, event.angleDelta.y === 0)
                        event.accepted = true
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.iconRadius(width)
                        border.width: button.activeFocus ? 2 : 0
                        border.color: IrisStyle.accent
                        color: (button.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet)
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    }
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 26 * root.d
                        source: entry.modelData ? TrayService.getSafeIcon(entry.modelData) : ""
                    }
                    Rectangle {
                        visible: entry.modelData?.status === Status.NeedsAttention
                        anchors.right: parent.right
                        width: 8 * root.d; height: width; radius: width / 2
                        color: IrisStyle.danger
                    }
                    IrisTrayMenu {
                        id: menu
                        handle: entry.modelData?.menu ?? null
                        anchorItem: button
                        opensToward: root.bottomEdge ? "up" : "down"
                        title: String(entry.modelData?.tooltipTitle || entry.modelData?.title || entry.modelData?.id || "")
                        icon: entry.modelData ? TrayService.getSafeIcon(entry.modelData) : ""
                    }
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: Config.options?.iris?.tray?.labels ?? true
                    text: entry.modelData?.tooltipTitle || entry.modelData?.title || entry.modelData?.id || ""
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.pixelSize: IrisStyle.typeFootnote
                    color: IrisStyle.subtext
                }
            }
        }
    }
    IrisText {
        Layout.fillWidth: true
        visible: root.items.length === 0
        text: Translation.tr("No background apps")
        color: IrisStyle.muted
        horizontalAlignment: Text.AlignHCenter
        Layout.topMargin: 16 * root.d
        Layout.bottomMargin: 16 * root.d
    }
    IrisText {
        Layout.fillWidth: true
        visible: root.items.length > 0
        text: Translation.tr("Click to open · Right-click for app actions")
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeFootnote
        wrapMode: Text.WordWrap
    }
}
