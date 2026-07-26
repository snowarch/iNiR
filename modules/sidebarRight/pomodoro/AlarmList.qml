pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * The Alarms tab. Lists what AlarmService holds, and swaps to
 * AlarmEditor for create and edit — one surface, no popup, so the tab keeps
 * its own focus and the sidebar keeps its size.
 *
 * ii/material family only. Waffle deliberately has no alarm tab.
 */
Item {
    id: root

    property bool compactMode: false
    property bool centerMode: true
    Layout.fillWidth: true
    Layout.fillHeight: true

    // -1 = a new alarm; only meaningful while editorOpen.
    property int editingId: -1
    property bool editorOpen: false

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext

    function openEditor(id: int): void {
        root.editingId = id;
        root.editorOpen = true;
    }

    Item {
        id: listPage
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        visible: !root.editorOpen

        // Nothing is claimed before the file has answered: an empty list with
        // loaded === false is "not read yet", not "you own no alarms".
        StyledText {
            anchors.centerIn: parent
            visible: !AlarmService.loaded
            text: Translation.tr("Loading alarms…")
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.colTextSecondary
        }

        MaterialPlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width
            visible: AlarmService.loaded && AlarmService.list.length === 0
            icon: "alarm"
            text: Translation.tr("No alarms")
            explanation: Translation.tr("Add one and it will ring while this session is awake.")
        }

        StyledListView {
            id: alarmListView
            anchors.fill: parent
            anchors.bottomMargin: addButton.height + 12
            visible: AlarmService.loaded && AlarmService.list.length > 0
            spacing: 8
            model: AlarmService.list

            delegate: AlarmCard {
                required property var modelData
                width: alarmListView.width
                alarm: modelData
                onEditRequested: id => root.openEditor(id)
                onDeleteRequested: id => AlarmService.removeAlarm(id)
            }
        }

        RippleButtonWithIcon {
            id: addButton
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 8
            materialIcon: "add_alarm"
            mainText: Translation.tr("Add alarm")
            enabled: AlarmService.loaded
            // mainText is this repo's own property, so the control's own text —
            // the one a screen reader reads — is empty unless it is said here.
            Accessible.role: Accessible.Button
            Accessible.name: mainText
            onClicked: root.openEditor(-1)
        }
    }

    AlarmEditor {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        visible: root.editorOpen
        alarmId: root.editingId
        onClosed: root.editorOpen = false
    }
}
