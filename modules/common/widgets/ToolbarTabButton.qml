import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RippleButton {
    id: root
    required property string materialSymbol
    required property bool current
    property bool showLabel: true
    horizontalPadding: 10

    implicitHeight: 40
    readonly property real _iconOnlyImplicitWidth: icon.implicitWidth + horizontalPadding * 2
    implicitWidth: root.showLabel ? (implicitContentWidth + horizontalPadding * 2) : root._iconOnlyImplicitWidth
    buttonRadius: height / 2

    colBackground: "transparent"
    colBackgroundHover: current ? "transparent" : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)
    colRipple: current ? ColorUtils.transparentize(Appearance.colors.colOnSurface, 1) : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.95)

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.showLabel ? 6 : 0

        MaterialSymbol {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            iconSize: 22
            text: root.materialSymbol
        }
        Loader {
            id: labelLoader
            active: root.showLabel
            visible: root.showLabel
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: StyledText {
                text: root.text
            }
        }
    }
}
