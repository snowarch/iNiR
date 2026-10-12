pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

RippleButton {
    id: root

    default property alias contentData: customContent.data
    property bool selected: false
    property bool quiet: false
    property bool emphasized: false
    property bool danger: false
    // A Design may draw the plate and the label its own way (AIRISU: a plate cut with a blade); the press, the toggle
    // and the content stay the button's.
    readonly property bool skinned: buttonSkin.active
    // Under a Design's skin the ink follows the skin's plates: lacquer on the chosen gofun, the seal's ink on the seal.
    property color foreground: root.skinned ? (root.danger && root.emphasized ? IrisStyle.onTintFor(IrisStyle.danger)
            : root.emphasized ? IrisStyle.inkOnAccentFill : root.selected ? IrisStyle.bodySurface
            : root.danger ? IrisStyle.danger : IrisStyle.text)
        : root.danger && root.emphasized ? IrisStyle.inkOnDanger
        : root.emphasized ? IrisStyle.inkOnAccent
        : root.danger ? IrisStyle.danger
        : root.selected ? IrisStyle.accent : IrisStyle.text

    implicitWidth: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitWidth + 22 * IrisStyle.density : 34 * IrisStyle.density)
    implicitHeight: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitHeight + 12 * IrisStyle.density : 34 * IrisStyle.density)
    Layout.minimumHeight: root.text.length > 0 ? label.implicitHeight + 10 * IrisStyle.density : 0

    toggled: root.selected
    buttonRadius: IrisStyle.radiusSmall
    buttonRadiusPressed: Math.max(3, IrisStyle.radiusSmall - 2)
    rippleEnabled: false
    rippleDuration: IrisStyle.duration(420)
    stateTransitionsEnabled: IrisStyle.motionEnabled
    // A skin answers the press its own way (AIRISU runs the plate out of register); it never also scales.
    pressScaleEnabled: !root.skinned
    cookieMorphing: false

    colBackground: root.skinned ? "transparent" : root.danger && root.emphasized ? IrisStyle.danger
        : root.emphasized ? IrisStyle.accent
        : root.quiet ? ColorUtils.applyAlpha(IrisStyle.surfaceHigh, 0)
        : IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate)
        : IrisStyle.surfaceHigh
    colBackgroundHover: root.skinned ? "transparent" : root.danger && root.emphasized
        ? ColorUtils.mix(IrisStyle.danger, IrisStyle.inkOnDanger, 0.90)
        : root.danger
            ? IrisStyle.tintFill(IrisStyle.danger)
        : root.emphasized
            ? IrisStyle.accentHover
            : root.quiet
                ? IrisStyle.fillHover
            : IrisStyle.surfaceHighest
    colBackgroundToggled: root.skinned ? "transparent" : IrisStyle.tintFill(IrisStyle.accent)
    colBackgroundToggledHover: root.skinned ? "transparent" : IrisStyle.tintFillHover(IrisStyle.accent)
    colRipple: root.skinned ? "transparent" : IrisStyle.tintFill((root.danger ? IrisStyle.danger : IrisStyle.accent))
    colRippleToggled: root.skinned ? "transparent" : IrisStyle.tintFill(IrisStyle.accent)

    Accessible.name: root.text
    Accessible.role: Accessible.Button
    Accessible.checked: root.selected

    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.visualFocus && !root.skinned ? 2 : 0
        border.color: IrisStyle.accent
        visible: border.width > 0
        Behavior on border.color {
            enabled: IrisStyle.motionEnabled
            ColorAnimation { duration: IrisStyle.duration(140) }
        }
    }

    contentItem: Item {
        id: contentHost

        IrisSkin {
            id: buttonSkin
            part: "button"
            host: root
            anchors.fill: undefined
            x: -contentHost.x
            y: -contentHost.y
            width: root.width
            height: root.height
            z: -1
        }

        IrisText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Math.max(0, contentHost.width - 16 * IrisStyle.density))
            elide: Text.ElideRight
            visible: root.text.length > 0 && !root.skinned
            text: root.text
            color: root.foreground
            font.pixelSize: IrisStyle.typeLabel
            font.weight: root.emphasized || root.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            id: customContent
            anchors.fill: parent
            // A skin that runs its plate out of register on a press carries the content with it.
            transform: Translate { x: buttonSkin.item?.shift ?? 0; y: buttonSkin.item?.shift ?? 0 }
        }
    }
}
