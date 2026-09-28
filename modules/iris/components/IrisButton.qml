pragma ComponentBehavior: Bound

import QtQuick
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
    readonly property color foreground: root.danger && root.emphasized ? IrisStyle.onDanger
        : root.emphasized ? IrisStyle.onAccent
        : root.danger ? IrisStyle.danger
        : root.selected ? IrisStyle.accent : IrisStyle.text

    implicitWidth: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitWidth + 22 * IrisStyle.density : 34 * IrisStyle.density)
    implicitHeight: Math.max(34 * IrisStyle.density,
        root.text.length > 0 ? label.implicitHeight + 12 * IrisStyle.density : 34 * IrisStyle.density)

    toggled: root.selected
    buttonRadius: IrisStyle.radiusSmall
    buttonRadiusPressed: Math.max(3, IrisStyle.radiusSmall - 2)
    rippleEnabled: false
    rippleDuration: IrisStyle.duration(420)
    stateTransitionsEnabled: IrisStyle.motionEnabled
    pressScaleEnabled: true
    cookieMorphing: false

    colBackground: root.danger && root.emphasized ? IrisStyle.danger
        : root.emphasized ? IrisStyle.accent
        : root.quiet ? ColorUtils.applyAlpha(IrisStyle.surfaceHigh, 0)
        // The raised step of whatever the family is made of: solid on solid, a lit layer on glass.
        : IrisStyle.surfaceHigh
    colBackgroundHover: root.danger && root.emphasized
        ? ColorUtils.mix(IrisStyle.danger, IrisStyle.onDanger, 0.90)
        : root.danger
            ? IrisStyle.tintFill(IrisStyle.danger)
        : root.emphasized
            ? ColorUtils.mix(IrisStyle.accent, IrisStyle.onAccent, 0.90)
            : root.quiet
                ? IrisStyle.fillHover
            : IrisStyle.surfaceHighest
    colBackgroundToggled: IrisStyle.tintFill(IrisStyle.accent)
    colBackgroundToggledHover: IrisStyle.tintFillHover(IrisStyle.accent)
    colRipple: IrisStyle.tintFill((root.danger ? IrisStyle.danger : IrisStyle.accent))
    colRippleToggled: IrisStyle.tintFill(IrisStyle.accent)

    Accessible.name: root.text
    Accessible.role: Accessible.Button
    Accessible.checked: root.selected

    Rectangle {
        anchors.fill: parent
        z: 2
        radius: root.buttonEffectiveRadius
        color: "transparent"
        border.width: root.visualFocus ? 2 : 0
        border.color: IrisStyle.accent
        visible: border.width > 0
        Behavior on border.color {
            enabled: IrisStyle.motionEnabled
            ColorAnimation { duration: IrisStyle.duration(140) }
        }
    }

    contentItem: Item {
        id: contentHost

        IrisText {
            id: label
            anchors.centerIn: parent
            visible: root.text.length > 0
            text: root.text
            color: root.foreground
            font.pixelSize: IrisStyle.typeLabel
            font.weight: root.emphasized || root.selected ? Font.DemiBold : Font.Medium
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            id: customContent
            anchors.fill: parent
        }
    }
}
