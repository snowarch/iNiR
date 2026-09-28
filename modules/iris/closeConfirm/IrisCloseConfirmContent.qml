pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces

Item {
    id: root
    focus: true

    required property var targetWindow
    signal confirm()
    signal cancel()

    readonly property string appId: String(targetWindow?.app_id ?? "")
    readonly property string titleText: String(targetWindow?.title ?? "")
    readonly property var desktopEntry: AppSearch.lookupDesktopEntry(root.appId)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            root.cancel()
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.confirm()
            event.accepted = true
        }
    }

    property real shown: 0
    Component.onCompleted: root.shown = 1
    Behavior on shown { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }

    Rectangle {
        anchors.fill: parent
        opacity: Math.min(1, root.shown)
        color: IrisStyle.scrim
        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
    }

    readonly property string appName: root.desktopEntry?.name ?? (root.appId.length > 0 ? root.appId : Translation.tr("this app"))

    IrisSurface {
        anchors.centerIn: parent
        opacity: Math.min(1, root.shown * 1.6)
        scale: 1.08 - 0.08 * root.shown
        width: Math.min(300 * IrisStyle.density, parent.width - 40)
        implicitHeight: alert.implicitHeight + 40 * IrisStyle.density
        radius: IrisStyle.radiusPlate
        raised: true
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: alert
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 20 * IrisStyle.density
            anchors.rightMargin: 20 * IrisStyle.density
            spacing: 0

            SmartAppIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: IrisPieces.appIcon(root.appId)
                fallback: "application-x-executable"
                iconSize: Math.round(52 * IrisStyle.density)
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: 14 * IrisStyle.density
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Close “%1”?").arg(root.appName)
                font.pixelSize: IrisStyle.typeHeadline
                font.weight: IrisStyle.weight(Font.DemiBold)
                wrapMode: Text.Wrap
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: 6 * IrisStyle.density
                horizontalAlignment: Text.AlignHCenter
                text: root.titleText.length > 0
                    ? Translation.tr("“%1” will close. Unsaved changes may be lost.").arg(root.titleText)
                    : Translation.tr("Unsaved changes may be lost.")
                color: IrisStyle.subtext
                font.pixelSize: IrisStyle.typeMeta
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 18 * IrisStyle.density
                spacing: 8 * IrisStyle.density
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(32 * IrisStyle.density)
                    buttonRadius: IrisStyle.radiusRow
                    colBackground: IrisStyle.fill
                    colBackgroundHover: IrisStyle.fillHover
                    text: Translation.tr("Cancel")
                    onClicked: root.cancel()
                }
                IrisButton {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(32 * IrisStyle.density)
                    buttonRadius: IrisStyle.radiusRow
                    emphasized: true
                    danger: true
                    text: Translation.tr("Close")
                    onClicked: root.confirm()
                }
            }
        }
    }

}
