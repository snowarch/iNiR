import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

GroupButton {
    id: root
    horizontalPadding: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingHorizontal : 11
    verticalPadding: Appearance.regaliaEverywhere ? Appearance.regalia.controlPaddingVertical : 6
    bounce: false
    property string buttonIcon
    property string buttonPreviewKind: ""
    property bool leftmost: false
    property bool rightmost: false
    readonly property bool showZzzPreview: Appearance.zzzEverywhere && buttonPreviewKind.length > 0
    leftRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : (toggled || leftmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    rightRadius: Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : (toggled || rightmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    Behavior on leftRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    Behavior on rightRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    // ZZZ: idle segments are NEUTRAL plate, not bright secondary. Under zzz
    // colSecondaryContainer resolves to zzz.secondary (a signal) — using it for
    // the unselected base/hover made every segment glow and the hover glare.
    // Selected state stays the inherited GroupButton sticker (colBackgroundToggled).
    colBackground: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlate
        : Appearance.zzzEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.auroraEverywhere ? "transparent" : Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateHover
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Hover
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover : Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.regaliaEverywhere ? Appearance.regalia.controlPlateActive
        : Appearance.zzzEverywhere ? Appearance.colors.colLayer1Active
        : Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive

    /**
     * Mini screen-top mockup: the tile is a screen, the shape is the bar. Every
     * kind shares one size and one fill (zzz doctrine: separation by fill, no
     * outlines) so only the actual corner geometry differs — hug touches the
     * top edge and rounds downward, float detaches fully rounded, rect bleeds
     * square, card floats narrower with its accent tick.
     */
    component ZzzCornerPreview: Item {
        id: preview
        required property string kind
        implicitWidth: 18
        implicitHeight: 12

        readonly property bool hug: kind === "hug"
        readonly property bool rect: kind === "rect"
        readonly property bool card: kind === "card"
        readonly property color barFill: root.toggled
            ? ColorUtils.mix(Appearance.zzz.onSticker, Appearance.zzz.sticker, 0.75)
            : ColorUtils.applyAlpha(Appearance.zzz.ink, 0.5)

        Rectangle {
            id: miniBar
            x: preview.card ? 3 : (preview.hug || preview.rect ? 0 : 2)
            y: preview.hug || preview.rect ? 0 : 2
            width: preview.implicitWidth - 2 * x
            height: 7
            color: preview.barFill
            topLeftRadius: preview.hug || preview.rect ? 0 : 3
            topRightRadius: preview.hug || preview.rect ? 0 : 3
            bottomLeftRadius: preview.rect ? 0 : 3
            bottomRightRadius: preview.rect ? 0 : 3
        }

        Rectangle {
            visible: preview.card
            anchors.horizontalCenter: miniBar.horizontalCenter
            y: miniBar.y + miniBar.height + 2
            width: 8
            height: 1.5
            radius: height / 2
            color: preview.barFill
            opacity: 0.7
        }
    }

    contentItem: RowLayout {
        spacing: (root.showZzzPreview || root.buttonIcon?.length > 0) && root.buttonText?.length > 0 ? 4 : 0

        Behavior on spacing {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        Item {
            id: iconReveal
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.showZzzPreview ? cornerPreview.implicitWidth : (root.buttonIcon?.length > 0 ? materialSymbol.implicitWidth : 0)
            implicitHeight: root.showZzzPreview ? cornerPreview.implicitHeight : materialSymbol.implicitHeight
            opacity: root.showZzzPreview || root.buttonIcon?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Loader {
                id: cornerPreview
                anchors.centerIn: parent
                active: root.showZzzPreview
                sourceComponent: ZzzCornerPreview {
                    kind: root.buttonPreviewKind
                }
            }

            MaterialSymbol {
                id: materialSymbol
                anchors.centerIn: parent
                visible: !root.showZzzPreview
                text: root.buttonIcon
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.regaliaEverywhere
                    ? (root.toggled ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
                    : Appearance.zzzEverywhere
                        ? (root.toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                        : (root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)
            }
        }

        Item {
            implicitWidth: root.buttonText?.length > 0 ? textItem.implicitWidth : 0
            implicitHeight: textMetrics.height // Force height to that of regular text
            opacity: root.buttonText?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            TextMetrics {
                id: textMetrics
                font.family: Appearance.font.family.main
                text: "Abc"
            }

            StyledText {
                id: textItem
                anchors.centerIn: parent
                color: Appearance.regaliaEverywhere
                    ? (root.toggled ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
                    : Appearance.zzzEverywhere
                        ? (root.toggled ? Appearance.zzz.onSticker : Appearance.zzz.ink)
                        : (root.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer)
                text: root.buttonText
            }
        }
    }
}
