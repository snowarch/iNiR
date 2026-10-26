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
    // Gel: whether the light cap shows (the act, a lit tile).
    property bool gloss: root.emphasized && !root.danger
    // Which of the Design's parts dresses it, and what that part needs to know: a control in the Control Center is
    // drawn as the Design's control tile, with its state, while the button keeps the press, the keys and the toggle.
    property string skinPart: "button"
    property var skinData: null
    // A Design may draw the plate and the label its own way (AIRISU: a plate cut with a blade); the press, the toggle
    // and the content stay the button's.
    readonly property bool skinned: buttonSkin.active
    // Under a Design's skin the ink follows the skin's plates: the chosen plate's ink, the seal's ink on the seal.
    property color foreground: root.skinned ? (root.danger && root.emphasized ? IrisStyle.onTintFor(IrisStyle.danger)
            : root.emphasized ? IrisStyle.inkOnAccentFill : root.selected ? IrisStyle.selectionLabel
            : root.danger ? IrisStyle.danger : IrisStyle.text)
        : root.danger && root.emphasized ? IrisStyle.inkOnDanger
        : root.emphasized && root.synth ? IrisStyle.inkOnSynthOn
        : root.emphasized && root.gel ? IrisStyle.inkOnGel
        : root.emphasized ? (root.nothing || !IrisStyle.mono ? IrisStyle.inkOnAccent : IrisStyle.appleInkOnAccentFill)
        : root.danger ? IrisStyle.danger
        : root.selected ? (root.nothing ? IrisStyle.selectionLabel : IrisStyle.appleAccent) : IrisStyle.text
    // Apple: a rounded plate, the accent on what is chosen. Nothing (S4): a capsule, primary inverted, destructive
    // the signal as text.
    // Synth: a key on a drop edge, orange for the one act. Gel: the act is a glossy accent capsule.
    readonly property string look: IrisStyle.lookOf(root)
    readonly property bool nothing: root.look === "nothing"
    readonly property bool synth: root.look === "synth" && !root.skinned
    readonly property bool gel: root.look === "gel" && !root.skinned

    implicitWidth: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitWidth + 22 * IrisStyle.density : 34 * IrisStyle.density)
    implicitHeight: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitHeight + 12 * IrisStyle.density : 34 * IrisStyle.density)
    Layout.minimumHeight: root.text.length > 0 ? label.implicitHeight + 10 * IrisStyle.density : 0

    toggled: root.selected
    buttonRadius: root.nothing || root.gel ? IrisStyle.capsule(root.height) : root.synth ? IrisStyle.synthKeyRadius : IrisStyle.radiusSmall
    buttonRadiusPressed: root.nothing || root.gel ? IrisStyle.capsule(root.height) : root.synth ? IrisStyle.synthKeyRadius : Math.max(3, IrisStyle.radiusSmall - 2)
    rippleEnabled: false
    rippleDuration: IrisStyle.duration(420)
    stateTransitionsEnabled: IrisStyle.motionEnabled
    // A skin answers the press its own way (AIRISU runs the plate out of register); it never also scales.
    pressScaleEnabled: !root.skinned
    cookieMorphing: false

    colBackground: root.skinned ? "transparent" : root.danger && root.emphasized ? IrisStyle.danger
        : root.emphasized ? (root.nothing ? IrisStyle.accent : root.synth ? IrisStyle.synthOn : root.gel ? IrisStyle.gelBody : IrisStyle.appleAccent)
        : root.quiet ? ColorUtils.applyAlpha(IrisStyle.surfaceHigh, 0)
        : root.synth ? IrisStyle.synthKey
        : IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate)
        : root.nothing ? IrisStyle.fill : IrisStyle.surfaceHigh
    colBackgroundHover: root.skinned ? "transparent" : root.danger && root.emphasized
        ? ColorUtils.mix(IrisStyle.danger, IrisStyle.inkOnDanger, 0.90)
        : root.danger
            ? IrisStyle.tintFill(IrisStyle.danger)
        : root.emphasized && root.synth ? Qt.lighter(IrisStyle.synthOn, 1.08)
        : root.emphasized && root.gel ? Qt.lighter(IrisStyle.gelBody, 1.08)
        : root.synth && !root.quiet ? ColorUtils.mix(IrisStyle.text, IrisStyle.synthKey, 0.08)
        : root.emphasized
            ? (root.nothing || !IrisStyle.mono ? IrisStyle.accentHover : ColorUtils.mix(IrisStyle.appleAccent, IrisStyle.appleInkOnAccentFill, 0.9))
            : root.nothing || root.quiet ? IrisStyle.fillHover : IrisStyle.surfaceHighest
    colBackgroundToggled: root.skinned ? "transparent" : root.nothing ? IrisStyle.selectionFill : IrisStyle.tintFill(IrisStyle.appleAccent)
    colBackgroundToggledHover: root.skinned ? "transparent" : root.nothing ? (IrisStyle.invertSelection ? IrisStyle.accentHover : IrisStyle.tintFillHover(IrisStyle.accent)) : IrisStyle.tintFillHover(IrisStyle.appleAccent)
    colRipple: root.skinned ? "transparent" : IrisStyle.tintFill((root.danger ? IrisStyle.danger : IrisStyle.accent))
    colRippleToggled: root.skinned ? "transparent" : IrisStyle.tintFill(IrisStyle.accent)
    // A skinned button draws nothing of its own, whatever colours a caller handed it (they were for iRiS's anatomy).
    buttonColor: root.skinned ? "transparent" : root.toggled
        ? (root.buttonHovered ? root.colBackgroundToggledHover : root.colBackgroundToggled)
        : (root.buttonHovered ? root.colBackgroundHover : root.colBackground)

    Accessible.name: root.text
    Accessible.role: Accessible.Button
    Accessible.checked: root.selected

    // Synth's drop edge and the solid key over it, under the face (a Control's background sits at z -1): a film of a
    // fill over glass would show the edge through.
    Loader {
        active: root.synth && !root.quiet
        z: -1.5
        width: root.width
        height: root.height
        sourceComponent: Item {
            Rectangle {
                y: Math.round(3 * IrisStyle.density)
                width: parent.width
                height: parent.height
                radius: root.buttonEffectiveRadius
                color: IrisStyle.synthKeyEdge
            }
            Rectangle {
                width: parent.width
                height: parent.height
                radius: root.buttonEffectiveRadius
                color: IrisStyle.synthKey
            }
        }
    }
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
            part: root.skinPart
            host: root
            anchors.fill: undefined
            x: -contentHost.x
            y: -contentHost.y
            width: root.width
            height: root.height
            z: -1
        }
        // Gel: the light cap over the act's upper half.
        Loader {
            active: root.gel && root.gloss
            z: -1
            readonly property real inset: Math.round(Math.min(root.height * 0.3, root.width * 0.15))
            x: -contentHost.x + inset
            y: -contentHost.y + Math.round(2 * IrisStyle.density)
            width: root.width - 2 * inset
            height: Math.round(root.height * 0.42)
            sourceComponent: Rectangle {
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: IrisStyle.gelShineTop }
                    GradientStop { position: 1; color: IrisStyle.gelShineBottom }
                }
            }
        }

        IrisText {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Math.max(0, contentHost.width - 16 * IrisStyle.density))
            elide: Text.ElideRight
            visible: root.text.length > 0 && !root.skinned
            text: root.text
            color: root.foreground
            font.family: root.synth ? IrisStyle.fontSynthLabel : label.defaultFont
            font.capitalization: root.synth ? Font.AllLowercase : Font.MixedCase
            font.pixelSize: IrisStyle.typeLabel
            font.weight: root.emphasized || root.selected ? IrisStyle.weight(Font.DemiBold) : IrisStyle.weight(Font.Medium)
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
