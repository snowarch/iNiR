import QtQuick
import qs
import qs.services
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RippleButton {
    id: root
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3
    property bool vertical: Config.options.bar.vertical
    property real buttonPadding: 5

    implicitWidth: 32
    implicitHeight: implicitWidth

    buttonRadius: Appearance.rounding.full
    colBackground: isMaterial ? M3Palette.primary : "transparent"
    colBackgroundHover: isMaterial
        ? ColorUtils.mix(M3Palette.primary, M3Palette.primaryForeground, 0.90)
        : Appearance.colors.colLayer1Hover
    colRipple: isMaterial
        ? ColorUtils.mix(M3Palette.primary, M3Palette.primaryForeground, 0.78)
        : Appearance.colors.colLayer1Active

    onPressed: {
        GlobalStates.sessionOpen = !GlobalStates.sessionOpen
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: !root.isMaterial
        text: "power_settings_new"
        iconSize: Appearance.font.pixelSize.larger
        color: Appearance.colors.colOnLayer0
    }

    MaterialShapeWrappedMaterialSymbol {
        anchors.centerIn: parent
        visible: root.isMaterial
        text: "power_settings_new"
        iconSize: Appearance.font.pixelSize.normal
        color: M3Palette.primaryForeground
        colSymbol: M3Palette.primary
        shape: MaterialShape.Shape.Cookie12Sided
        padding: 2
    }
}
