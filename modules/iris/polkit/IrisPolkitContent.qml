pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    id: root
    focus: true

    readonly property bool usePasswordChars: !(PolkitService.flow?.responseVisible ?? false)
    readonly property real d: IrisStyle.density

    function submit(): void {
        if (!PolkitService.interactionAvailable)
            return
        PolkitService.submit(input.text)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            PolkitService.cancel()
            event.accepted = true
        }
    }

    Connections {
        target: PolkitService
        function onInteractionAvailableChanged(): void {
            if (!PolkitService.interactionAvailable)
                return
            input.text = ""
            input.forceActiveFocus()
        }
    }

    property real shown: 0
    Component.onCompleted: root.shown = 1
    Behavior on shown { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }

    Rectangle {
        anchors.fill: parent
        opacity: Math.min(1, root.shown)
        color: IrisStyle.scrim
    }

    IrisSurface {
        id: card
        anchors.centerIn: parent
        opacity: Math.min(1, root.shown * 1.6)
        scale: 1.08 - 0.08 * root.shown
        width: Math.min(320 * root.d, parent.width - 40)
        implicitHeight: body.implicitHeight + 40 * root.d
        radius: IrisStyle.radiusPlate
        raised: true

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20 * root.d
            anchors.rightMargin: 20 * root.d
            spacing: 0

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(52 * root.d)
                implicitHeight: implicitWidth
                radius: width / 2
                color: IrisStyle.tintFill(IrisStyle.accent)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: PolkitService.batteryChargeLimitRequest ? "battery_charging_full" : "lock"
                    fill: 1
                    iconSize: Math.round(26 * root.d)
                    color: IrisStyle.accent
                }
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: 14 * root.d
                horizontalAlignment: Text.AlignHCenter
                text: PolkitService.actionLabel !== Translation.tr("Authentication")
                    ? PolkitService.actionLabel : Translation.tr("Authentication required")
                font.pixelSize: IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.DemiBold)
                wrapMode: Text.Wrap
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: 6 * root.d
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                text: PolkitService.cleanMessage
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }

            IrisField {
                id: input
                Layout.fillWidth: true
                Layout.topMargin: 16 * root.d
                implicitHeight: Math.round(40 * root.d)
                focus: true
                enabled: PolkitService.interactionAvailable
                echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal
                placeholderText: PolkitService.cleanPrompt
                font.pixelSize: IrisStyle.typeBody
                onAccepted: root.submit()
                background: Rectangle {
                    radius: height / 2
                    color: (input.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet)
                    border.width: input.activeFocus ? Math.max(1, Math.round(1.5 * root.d)) : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.accent)
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14 * root.d
                spacing: 8 * root.d
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    colBackground: IrisStyle.fill
                    colBackgroundHover: IrisStyle.fillHover
                    text: Translation.tr("Cancel")
                    onClicked: PolkitService.cancel()
                }
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.d)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    emphasized: true
                    enabled: PolkitService.interactionAvailable
                    text: Translation.tr("Authenticate")
                    onClicked: root.submit()
                }
            }
        }
    }
}
