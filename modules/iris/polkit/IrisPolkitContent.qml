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
    // The request it answers: the agent's, or a stand-in (the Design proof draws the dialog on one).
    property var service: PolkitService

    readonly property bool usePasswordChars: !(root.service.flow?.responseVisible ?? false)
    readonly property real d: IrisStyle.density

    function submit(): void {
        if (!root.service.interactionAvailable)
            return
        root.service.submit(input.text)
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.service.cancel()
            event.accepted = true
        }
    }

    Connections {
        target: root.service === PolkitService ? PolkitService : null
        function onInteractionAvailableChanged(): void {
            if (!root.service.interactionAvailable)
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
        radius: IrisStyle.fieldChamfer ? 0 : IrisStyle.radiusPlate
        raised: true
        // A Design that cuts the dialog its own way (IrisDesign part `authPlate`) draws its plate.
        quiet: authPlate.active
        IrisSkin { id: authPlate; part: "authPlate"; host: card; z: -1 }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20 * root.d
            anchors.rightMargin: 20 * root.d
            spacing: 0

            // A plate Design sets the request as a permit (許可証): its kind in mono capitals with the Japanese beside it,
            // then what is asked, left aligned as a form is; the key sign gives way to the caution band on its plate.
            Row {
                visible: IrisStyle.plateSelection
                spacing: 8 * root.d
                IrisText {
                    text: Translation.tr("Authentication")
                    color: IrisStyle.subtext
                    font.family: IrisStyle.fontMono
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Math.round(IrisStyle.typeFootnote * 0.16)
                    font.pixelSize: IrisStyle.typeFootnote
                }
                IrisText {
                    text: "認証"
                    color: IrisStyle.accent
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.Bold)
                }
            }
            Rectangle {
                visible: !IrisStyle.plateSelection
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.round(52 * root.d)
                implicitHeight: implicitWidth
                // A glyph-mark Design (AIRISU) shows the key alone, in the seal, on no disc.
                radius: IrisStyle.capsule(width)
                color: IrisStyle.plainMarks ? "transparent" : IrisStyle.tintFill(IrisStyle.accent)
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.service.batteryChargeLimitRequest ? "battery_charging_full" : "lock"
                    fill: 1
                    iconSize: Math.round(26 * root.d)
                    color: IrisStyle.accent
                }
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: (IrisStyle.plateSelection ? 6 : 14) * root.d
                horizontalAlignment: IrisStyle.plateSelection ? Text.AlignLeft : Text.AlignHCenter
                text: root.service.actionLabel !== Translation.tr("Authentication")
                    ? root.service.actionLabel : Translation.tr("Authentication required")
                font.family: IrisStyle.fontTitle
                font.pixelSize: IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.DemiBold)
                wrapMode: Text.Wrap
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: 6 * root.d
                visible: text.length > 0
                horizontalAlignment: IrisStyle.plateSelection ? Text.AlignLeft : Text.AlignHCenter
                text: root.service.cleanMessage
                color: IrisStyle.subtext
                font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
                font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeFootnote : IrisStyle.typeMeta
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
                enabled: root.service.interactionAvailable
                echoMode: root.usePasswordChars ? TextInput.Password : TextInput.Normal
                placeholderText: root.service.cleanPrompt
                font.pixelSize: IrisStyle.typeBody
                onAccepted: root.submit()
                // A plate Design cuts the field square on its fillet, the seal underlining the focus.
                // A plate Design writes on a ruled line, as on a form: the rule in ink, in the seal while it has the keys.
                background: Rectangle {
                    radius: IrisStyle.plateSelection ? 0 : height / 2
                    color: IrisStyle.plateSelection ? "transparent" : (input.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet)
                    border.width: IrisStyle.plateSelection ? 0 : input.activeFocus ? Math.max(1, Math.round(1.5 * root.d)) : 0
                    border.color: IrisStyle.tintBorder(IrisStyle.accent)
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    Rectangle {
                        visible: IrisStyle.plateSelection
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(1, Math.round((input.activeFocus ? 2 : 1) * root.d))
                        color: input.activeFocus ? IrisStyle.accentFill : IrisStyle.text
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14 * root.d
                spacing: 8 * root.d
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.d)
                    buttonRadius: IrisStyle.capsule(height)
                    buttonRadiusPressed: IrisStyle.capsule(height)
                    colBackground: IrisStyle.fill
                    colBackgroundHover: IrisStyle.fillHover
                    quiet: IrisStyle.plateSelection
                    text: Translation.tr("Cancel")
                    onClicked: root.service.cancel()
                }
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * root.d)
                    buttonRadius: IrisStyle.capsule(height)
                    buttonRadiusPressed: IrisStyle.capsule(height)
                    emphasized: true
                    enabled: root.service.interactionAvailable
                    text: Translation.tr("Authenticate")
                    onClicked: root.submit()
                }
            }
        }
    }
}
