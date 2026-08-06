import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property bool shown: true
    property string icon: ""
    property string title: ""
    property string description: ""
    // Optional mascot pose shown instead of the icon (gated by mascot.enable;
    // the icon is the switched-off fallback)
    property string mascotPose: ""
    property int shape: MaterialShape.Shape.Clover4Leaf
    property int descriptionHorizontalAlignment: Text.AlignLeft

    opacity: shown ? 1 : 0
    visible: opacity > 0
    anchors {
        fill: parent
        topMargin: -30 * (1 - opacity)
        bottomMargin: 30 * (1 - opacity)
    }

    Behavior on opacity {
        animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Appearance.inirEverywhere ? 8 : 5

        MascotImage {
            id: placeholderMascot
            visible: active && root.mascotPose.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 110
            Layout.preferredHeight: 110
            pose: root.mascotPose
            surface: "emptyStates"
        }

        // Inir: simple rectangle with centered icon
        Item {
            visible: Appearance.inirEverywhere && !placeholderMascot.visible
            Layout.alignment: Qt.AlignHCenter
            width: 72
            height: 72
            
            Rectangle {
                anchors.fill: parent
                radius: Appearance.inir.roundingNormal
                color: Appearance.inir.colLayer2
                border.width: 1
                border.color: Appearance.inir.colBorder
            }
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                iconSize: 32
                color: Appearance.inir.colTextSecondary
            }
        }

        // Material/Aurora: decorative shape wrapper
        MaterialShapeWrappedMaterialSymbol {
            visible: !Appearance.inirEverywhere && !placeholderMascot.visible
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            shape: root.shape
            padding: 12
            iconSize: 56
            rotation: -30 * (1 - root.opacity)
        }
        
        StyledText {
            visible: root.title !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.larger
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOutline
            horizontalAlignment: Text.AlignHCenter
        }
        StyledText {
            visible: root.description !== ""
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOutline
            horizontalAlignment: root.descriptionHorizontalAlignment
            wrapMode: Text.Wrap
        }
    }
}
