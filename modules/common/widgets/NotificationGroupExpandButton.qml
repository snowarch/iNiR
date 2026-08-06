import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton { // Expand button
    id: root
    required property int count
    required property bool expanded
    property real fontSize: Appearance?.font.pixelSize.small ?? 12
    property real iconSize: Appearance?.font.pixelSize.normal ?? 16
    implicitHeight: fontSize + 4 * 2
    implicitWidth: Math.max(contentItem.implicitWidth + 5 * 2, 30)
    Layout.alignment: Qt.AlignVCenter
    Layout.fillHeight: false

    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
    colBackground: Appearance.zzzEverywhere
        ? (expanded ? Appearance.zzz.sticker : Appearance.zzz.paperAlt)
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere 
        ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere 
        ? Appearance.aurora.colSubSurface
        : ColorUtils.mix(Appearance?.colors.colLayer2, Appearance?.colors.colLayer2Hover, 0.5)
    colBackgroundHover: Appearance.zzzEverywhere
        ? (expanded ? ColorUtils.applyAlpha(Appearance.zzz.sticker, 0.88) : ColorUtils.mix(Appearance.zzz.paperAlt, Appearance.zzz.signal, 0.92))
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere 
        ? Appearance.inir.colLayer3Hover
        : Appearance.auroraEverywhere 
        ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer2Hover
    colRipple: Appearance.zzzEverywhere
        ? ColorUtils.applyAlpha(Appearance.zzz.accent, 0.28)
        : Appearance.angelEverywhere
        ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere 
        ? Appearance.inir.colLayer3Active
        : Appearance.auroraEverywhere 
        ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: contentRow.implicitWidth
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: 3
            StyledText {
                Layout.leftMargin: 4
                visible: root.count > 1
                text: root.count
                font.pixelSize: root.fontSize
                color: Appearance.zzzEverywhere
                    ? (expanded ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : Appearance.colors.colOnLayer2
            }
            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: root.iconSize
                color: Appearance.zzzEverywhere
                    ? (expanded ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                    : Appearance.colors.colOnLayer2
                rotation: expanded ? 180 : 0
                Behavior on rotation {
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }
        }
    }
}
