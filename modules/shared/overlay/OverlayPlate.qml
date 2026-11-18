pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// What a tool and the strip stand on: Material's panel skin in each global style, the family's body surface otherwise.
// `fillOpacity` is how much of it shows (a pinned tool's background), its shadow fading with it. A glass style
// frosts the wallpaper behind it, so it never reads as a hole over a game; `screenX/Y` is where it sits, since a tool
// moves as a whole and the surface can't see that.
Item {
    id: root

    property real radius: OverlayLook.plateRadius
    property real fillOpacity: 1
    property bool shadow: true
    property real screenX: 0
    property real screenY: 0

    Item {
        id: body
        anchors.fill: parent
        readonly property real radius: root.radius
    }

    StyledRectangularShadow {
        target: body
        visible: !OverlayLook.own && root.shadow && root.fillOpacity > 0.02
        opacity: root.fillOpacity
    }
    RectangularShadow {
        visible: OverlayLook.own && root.shadow && root.fillOpacity > 0.02
        anchors.fill: body
        anchors.topMargin: Math.round(6 * OverlayLook.d)
        radius: root.radius
        blur: Math.round(28 * OverlayLook.d)
        spread: -Math.round(6 * OverlayLook.d)
        color: ColorUtils.applyAlpha(FamilyStyle.shadow, FamilyStyle.shadow.a * root.fillOpacity)
    }

    Loader {
        anchors.fill: parent
        active: !OverlayLook.own && root.fillOpacity > 0.005
        opacity: root.fillOpacity
        sourceComponent: PanelSurface {
            elevation: 2
            cardStyle: true
            radiusOverride: root.radius
            wallpaperBackdrop: true
            backdropScreenX: root.screenX
            backdropScreenY: root.screenY
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: OverlayLook.own && root.fillOpacity > 0.005
        radius: root.radius
        color: ColorUtils.applyAlpha(FamilyStyle.bodySurface, FamilyStyle.bodySurface.a * root.fillOpacity)
        border.width: 1
        border.color: ColorUtils.applyAlpha(FamilyStyle.border, FamilyStyle.border.a * Math.min(1, root.fillOpacity * 1.5))
    }
}
