import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool shown: true
    property string icon: ""
    property string text: ""
    property string explanation: ""
    property int shape: MaterialShape.Shape.Clover4Leaf
    property Action helpfulAction
    property real maximumWidth: 340
    property string actionIcon: ""
    property string actionText: helpfulAction?.text ?? ""
    property int textHorizontalAlignment: Text.AlignHCenter
    property bool compact: false

    opacity: shown ? 1 : 0
    visible: opacity > 0
    // Include the inset consumed below; otherwise an implicitly sized host
    // gives even short headings less width than their natural text width.
    implicitWidth: Math.min(root.maximumWidth, placeholderColumn.implicitWidth) + 24
    implicitHeight: placeholderColumn.implicitHeight
    y: shown ? 0 : 10

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: Appearance.animation.elementMoveEnter.duration
            easing.type: Appearance.animation.elementMoveEnter.type
            easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
        }
    }

    ColumnLayout {
        id: placeholderColumn
        anchors.centerIn: parent
        width: Math.max(0, Math.min(root.maximumWidth, parent ? parent.width - 24 : root.maximumWidth))
        spacing: Appearance.editorialEverywhere ? Math.round((root.compact ? 8 : 12) * Appearance.editorial.spacing) : root.compact ? 6 : (Appearance.inirEverywhere ? 8 : 10)

        Item {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Appearance.inirEverywhere ? (root.compact ? 48 : 72) : materialShape.implicitWidth
            implicitHeight: Appearance.inirEverywhere ? (root.compact ? 48 : 72) : materialShape.implicitHeight

            Rectangle {
                anchors.fill: parent
                visible: Appearance.inirEverywhere || (Appearance.editorialEverywhere && !Appearance.editorial.ornaments)
                radius: Appearance.editorialEverywhere ? Appearance.editorial.radius : Appearance.inir.roundingNormal
                color: Appearance.editorialEverywhere ? Appearance.editorial.secondaryField : Appearance.inir.colLayer2
                border.width: Appearance.editorialEverywhere ? 0 : 1
                border.color: Appearance.inir.colBorder
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: Appearance.inirEverywhere || (Appearance.editorialEverywhere && !Appearance.editorial.ornaments)
                text: root.icon
                iconSize: root.compact ? 24 : 32
                color: Appearance.editorialEverywhere ? Appearance.editorial.secondaryFieldInk : Appearance.inir.colTextSecondary
            }

            MaterialShapeWrappedMaterialSymbol {
                id: materialShape
                anchors.centerIn: parent
                visible: !Appearance.inirEverywhere && (!Appearance.editorialEverywhere || Appearance.editorial.ornaments)
                text: root.icon
                shape: root.shape
                padding: root.compact ? 8 : 12
                iconSize: Appearance.editorialEverywhere ? (root.compact ? 28 : 36) : root.compact ? 32 : 56
            }
        }

        StyledText {
            visible: root.text !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.text
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: root.compact ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.large
            font.family: Appearance.editorialEverywhere ? Appearance.font.family.title : Appearance.font.family.main
            font.weight: Appearance.editorialEverywhere ? Appearance.editorial.titleWeight : Font.DemiBold
            font.letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
            color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnSurface
        }

        StyledText {
            visible: root.explanation !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: root.explanation
            horizontalAlignment: root.textHorizontalAlignment
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
        }

        RippleButtonWithIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: root.helpfulAction !== null
            mainText: root.actionText
            materialIcon: root.actionIcon
            onClicked: root.helpfulAction.trigger()
        }
    }
}
