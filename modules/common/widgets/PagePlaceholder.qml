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
        width: Appearance.editorialEverywhere ? Math.max(0, Math.min(340, root.width - 24)) : implicitWidth
        spacing: Appearance.editorialEverywhere ? Math.round(12 * Appearance.editorial.spacing) : Appearance.inirEverywhere ? 8 : 5

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
            visible: (Appearance.inirEverywhere || (Appearance.editorialEverywhere && !Appearance.editorial.ornaments)) && !placeholderMascot.visible
            Layout.alignment: Qt.AlignHCenter
            width: 72
            height: 72
            
            Rectangle {
                anchors.fill: parent
                radius: Appearance.editorialEverywhere ? Appearance.editorial.radius : Appearance.inir.roundingNormal
                color: Appearance.editorialEverywhere ? Appearance.editorial.secondaryField : Appearance.inir.colLayer2
                border.width: Appearance.editorialEverywhere ? 0 : 1
                border.color: Appearance.inir.colBorder
            }
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.icon
                iconSize: 32
                color: Appearance.editorialEverywhere ? Appearance.editorial.secondaryFieldInk : Appearance.inir.colTextSecondary
            }
        }

        // Material/Aurora: decorative shape wrapper
        MaterialShapeWrappedMaterialSymbol {
            visible: !Appearance.inirEverywhere && (!Appearance.editorialEverywhere || Appearance.editorial.ornaments) && !placeholderMascot.visible
            Layout.alignment: Qt.AlignHCenter
            text: root.icon
            shape: root.shape
            padding: 12
            iconSize: Appearance.editorialEverywhere ? 36 : 56
            rotation: -30 * (1 - root.opacity)
        }
        
        StyledText {
            visible: root.title !== ""
            Layout.alignment: Qt.AlignHCenter
            text: root.title
            Layout.fillWidth: Appearance.editorialEverywhere
            wrapMode: Text.WordWrap
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.larger * (Appearance.editorialEverywhere ? Appearance.editorial.titleScale : 1)
                weight: Appearance.editorialEverywhere ? Appearance.editorial.titleWeight : Font.Normal
                letterSpacing: Appearance.editorialEverywhere ? Appearance.editorial.titleTracking : 0
                variableAxes: Appearance.font.variableAxes.title
            }
            color: Appearance.editorialEverywhere ? Appearance.editorial.ink : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOutline
            horizontalAlignment: Text.AlignHCenter
        }
        StyledText {
            visible: root.description !== ""
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.editorialEverywhere ? Appearance.editorial.muted : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOutline
            horizontalAlignment: root.descriptionHorizontalAlignment
            wrapMode: Text.Wrap
        }
    }
}
