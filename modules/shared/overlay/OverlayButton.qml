pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// The bench's one button: a bare glyph, or a glyph with its label. `toggled` tints it (an open tool, a pinned one),
// `strong` fills it with its tint (the one action of a group: Record).
RippleButton {
    id: root

    property string glyph: ""
    property string label: ""
    property string tip: ""
    property color tint: OverlayLook.colPrimary
    property bool strong: false
    property bool quiet: false
    // A resting fill, for a button that stands alone in a row (Screenshot, Copy screen).
    property bool filled: false
    property real size: Math.round(32 * OverlayLook.d)
    property real glyphSize: Math.round(size * 0.6)
    property bool filledGlyph: root.toggled || root.strong
    readonly property bool tinted: root.tint !== OverlayLook.colPrimary
    readonly property color ink: root.strong ? (OverlayLook.own ? FamilyStyle.onTintFor(root.tint) : root.tinted ? OverlayLook.colOnError : OverlayLook.colOnPrimary)
        : root.toggled ? (root.tinted ? root.tint : OverlayLook.colOnToggle)
        : root.quiet && !root.buttonHovered ? OverlayLook.colFaint
        : root.buttonHovered || root.filled ? OverlayLook.colOnLayer1 : OverlayLook.colSubtext

    implicitHeight: root.size
    implicitWidth: root.label.length > 0 ? row.implicitWidth + Math.round(root.size * 0.42) * 2 : root.size
    padding: 0
    rippleEnabled: !OverlayLook.own && !Appearance.regaliaEverywhere && !Appearance.editorialEverywhere
    buttonRadius: root.filled ? OverlayLook.roundingSmall
        : OverlayLook.own ? (root.label.length > 0 ? root.height / 2 : FamilyStyle.concentric(root.height / 2 + 4, 4, 6))
        : Appearance.rounding.full

    colBackground: root.strong ? root.tint : root.filled ? OverlayLook.colLayer2 : ColorUtils.applyAlpha(OverlayLook.colLayer2, 0)
    colBackgroundHover: root.strong ? ColorUtils.mix(root.tint, root.ink, 0.88) : OverlayLook.colLayer2Hover
    colRipple: root.strong ? ColorUtils.mix(root.tint, root.ink, 0.8) : OverlayLook.colLayer2Active
    colBackgroundToggled: root.strong ? root.tint : root.tinted ? FamilyStyle.tintFill(root.tint) : OverlayLook.colToggle
    colBackgroundToggledHover: root.strong ? ColorUtils.mix(root.tint, root.ink, 0.88) : root.tinted ? FamilyStyle.tintFillHover(root.tint) : OverlayLook.colToggleHover
    colRippleToggled: root.tinted ? FamilyStyle.tintFillHover(root.tint) : OverlayLook.colToggleHover

    Accessible.name: root.label.length > 0 ? root.label : root.tip

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: root.size
        Row {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(6 * OverlayLook.d)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.glyph.length > 0
                text: root.glyph
                iconSize: root.glyphSize
                fill: root.filledGlyph ? 1 : 0
                animateFill: true
                color: root.ink
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.label.length > 0
                text: root.label
                color: root.ink
                font.family: OverlayLook.fontMain
                font.pixelSize: OverlayLook.typeBody
                font.weight: Font.DemiBold
            }
        }
    }

    StyledToolTip {
        text: root.tip
    }
}
