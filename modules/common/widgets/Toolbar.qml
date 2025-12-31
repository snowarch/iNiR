import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 expressive style toolbar.
 * https://m3.material.io/components/toolbars
 */
Item {
    id: root

    property bool enableShadow: true
    property real padding: 8
    property alias colBackground: background.color
    property alias spacing: toolbarLayout.spacing
    default property alias data: toolbarLayout.data
    implicitWidth: background.implicitWidth
    implicitHeight: background.implicitHeight
    property alias radius: background.radius

    Loader {
        active: root.enableShadow && !Appearance.inirEverywhere && !Appearance.auroraEverywhere
        anchors.fill: background
        sourceComponent: StyledRectangularShadow {
            target: background
            anchors.fill: undefined
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
             : Appearance.auroraEverywhere ? "transparent"
             : Appearance.m3colors.m3surfaceContainer
        border.width: Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        implicitHeight: 56
        implicitWidth: toolbarLayout.implicitWidth + root.padding * 2
        radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : (height / 2)

        RowLayout {
            id: toolbarLayout
            spacing: 4
            anchors {
                fill: parent
                margins: root.padding
            }
        }
    }
}
