pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var imagePaths: []
    property var resultPaths: []
    property bool resultMode: false
    property bool noticeMode: false
    property string noticeText: ""
    property bool open: false
    property real requestedX: 0
    property real requestedY: 0
    signal chosen(string action)
    signal dismissed()

    function openAt(paths, x, y): void {
        root.imagePaths = Array.from(paths ?? [])
        root.resultPaths = []
        root.resultMode = false
        root.noticeMode = false
        root.noticeText = ""
        root.requestedX = x
        root.requestedY = y
        root.open = true
    }

    function showResults(paths, x, y): void {
        root.imagePaths = []
        root.resultPaths = Array.from(paths ?? [])
        root.resultMode = true
        root.noticeMode = false
        root.requestedX = x
        root.requestedY = y
        root.open = root.resultPaths.length > 0
    }

    function showNotice(message, x, y): void {
        root.imagePaths = []
        root.resultPaths = []
        root.resultMode = false
        root.noticeMode = true
        root.noticeText = String(message ?? "")
        root.requestedX = x
        root.requestedY = y
        root.open = root.noticeText.length > 0
    }

    function closeChoice(): void {
        root.open = false
        root.dismissed()
    }

    visible: root.open
    enabled: root.open
    z: 300

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton
        onClicked: root.closeChoice()
    }

    Rectangle {
        id: panel
        z: 1
        x: Math.max(12, Math.min(root.width - width - 12, root.requestedX - width / 2))
        y: Math.max(12, Math.min(root.height - height - 12, root.requestedY - height / 2))
        width: 288
        height: root.resultMode ? resultColumn.implicitHeight + 28
            : root.noticeMode ? noticeColumn.implicitHeight + 28
            : choiceColumn.implicitHeight + 28
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        ColumnLayout {
            id: choiceColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: !root.resultMode && !root.noticeMode

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("What should happen to this image?")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.imagePaths.length === 1
                    ? Translation.tr("Choose an action for the dropped image.")
                    : Translation.tr("Choose an action for %1 dropped images.").arg(root.imagePaths.length)
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RippleButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("File access")
                    onClicked: root.chosen("access")
                }
                RippleButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Decorative image")
                    onClicked: root.chosen("decorative")
                }
            }

            RippleButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Convert image")
                onClicked: root.chosen("convert")
            }
        }

        ColumnLayout {
            id: noticeColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.noticeMode

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Desktop image")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            StyledText {
                Layout.fillWidth: true
                text: root.noticeText
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            RippleButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Dismiss")
                onClicked: root.closeChoice()
            }
        }

        ColumnLayout {
            id: resultColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.resultMode

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Images converted")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Place the converted result on the desktop?")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                RippleButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Place result here")
                    onClicked: root.chosen("place-results")
                }
                RippleButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Dismiss")
                    onClicked: root.closeChoice()
                }
            }
        }
    }
}
