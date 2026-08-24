pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Rectangle {
    id: root

    color: Looks.colors.bg0Opaque
    readonly property bool usePasswordChars: !(PolkitService.flow?.responseVisible ?? false)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            PolkitService.cancel()
            event.accepted = true
        }
    }

    StyledImage {
        anchors.fill: parent
        source: Config.options?.background?.wallpaperPath ?? ""
        fillMode: Image.PreserveAspectCrop

        Rectangle {
            anchors.fill: parent
            color: ColorUtils.applyAlpha(Looks.colors.bg0Opaque, 0.69)

            WPane {
                id: dialog
                anchors.centerIn: parent
                implicitWidth: Looks.dp(460)
                radius: Looks.cookieEverywhere ? Looks.radius.xLarge : Looks.radius.large
                borderColor: Looks.glassActive ? Looks.colors.tooltipBorder : Looks.colors.bg2Border

                scale: 0.96
                opacity: 0
                Component.onCompleted: {
                    scale = 1
                    opacity = 1
                }
                Behavior on scale {
                    animation: NumberAnimation {
                        duration: Looks.transition.enabled ? Looks.transition.duration.panel : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.decelerate
                    }
                }
                Behavior on opacity {
                    animation: NumberAnimation {
                        duration: Looks.transition.enabled ? Looks.transition.duration.normal : 0
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Looks.transition.easing.bezierCurve.standard
                    }
                }

                contentItem: ColumnLayout {
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: authContent.implicitHeight + Looks.dp(40)

                        ColumnLayout {
                            id: authContent
                            anchors.fill: parent
                            anchors.margins: Looks.dp(20)
                            spacing: Looks.dp(16)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Looks.dp(14)

                                Rectangle {
                                    Layout.preferredWidth: Looks.dp(58)
                                    Layout.preferredHeight: Looks.dp(58)
                                    Layout.alignment: Qt.AlignTop
                                    radius: Looks.cookieEverywhere ? height / 2 : Looks.radius.large
                                    color: Looks.colors.bg1
                                    border.width: 1
                                    border.color: Looks.colors.bg2Border

                                    FluentIcon {
                                        anchors.centerIn: parent
                                        icon: PolkitService.batteryChargeLimitRequest
                                            ? "battery-saver" : "shield"
                                        implicitSize: Looks.dp(26)
                                        color: Looks.colors.accent
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Looks.dp(3)

                                    WText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Authentication")
                                        font.pixelSize: Looks.font.pixelSize.xlarger
                                        font.weight: Looks.font.weight.strongest
                                        color: Looks.colors.fg
                                        wrapMode: Text.WordWrap
                                    }

                                    WText {
                                        Layout.fillWidth: true
                                        visible: PolkitService.actionLabel !== Translation.tr("Authentication")
                                        text: PolkitService.actionLabel
                                        font.pixelSize: Looks.font.pixelSize.small
                                        font.weight: Looks.font.weight.strong
                                        color: Looks.colors.accent
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: messageText.implicitHeight + Looks.dp(20)
                                radius: Looks.cookieEverywhere ? Looks.radius.xLarge : Looks.radius.medium
                                color: Looks.colors.bg1
                                border.width: 1
                                border.color: Looks.colors.bg2Border

                                RowLayout {
                                    id: messageRow
                                    anchors.fill: parent
                                    anchors.margins: Looks.dp(10)
                                    spacing: Looks.dp(10)

                                    FluentIcon {
                                        icon: "info-filled"
                                        implicitSize: Looks.dp(16)
                                        color: Looks.colors.accent
                                        Layout.alignment: Qt.AlignTop
                                    }

                                    WText {
                                        id: messageText
                                        Layout.fillWidth: true
                                        text: PolkitService.cleanMessage
                                        font.pixelSize: Looks.font.pixelSize.small
                                        color: Looks.colors.fg1
                                        wrapMode: Text.WrapAnywhere
                                    }
                                }
                            }

                            WTextField {
                                id: inputField
                                Layout.fillWidth: true
                                focus: true
                                enabled: PolkitService.interactionAvailable
                                placeholderText: PolkitService.cleanPrompt
                                echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal
                                onAccepted: PolkitService.submit(inputField.text)

                                Keys.onPressed: event => {
                                    if (event.key === Qt.Key_Escape) {
                                        PolkitService.cancel()
                                        event.accepted = true
                                    }
                                }

                                Component.onCompleted: forceActiveFocus()

                                Connections {
                                    target: PolkitService
                                    function onInteractionAvailableChanged(): void {
                                        if (!PolkitService.interactionAvailable)
                                            return
                                        inputField.text = ""
                                        inputField.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Looks.colors.bg0Border
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: actionRow.implicitHeight + Looks.dp(28)

                        RowLayout {
                            id: actionRow
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: Looks.dp(16)
                            spacing: Looks.dp(8)

                            WBorderedButton {
                                implicitWidth: Looks.dp(104)
                                implicitHeight: Looks.dp(34)
                                text: Translation.tr("Cancel")
                                icon.name: "dismiss"
                                forceShowIcon: true
                                cookieMorphing: Looks.cookieEverywhere
                                onClicked: PolkitService.cancel()
                            }

                            WButton {
                                implicitWidth: Looks.dp(104)
                                implicitHeight: Looks.dp(34)
                                enabled: PolkitService.interactionAvailable
                                text: Translation.tr("OK")
                                icon.name: "checkmark"
                                forceShowIcon: true
                                cookieMorphing: Looks.cookieEverywhere
                                checked: true
                                onClicked: PolkitService.submit(inputField.text)
                            }
                        }
                    }
                }
            }
        }
    }
}
