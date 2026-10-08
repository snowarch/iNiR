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
    property color foreground: root.danger && root.emphasized ? IrisStyle.inkOnDanger
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
    pressScaleEnabled: true
    cookieMorphing: false

    colBackground: root.danger && root.emphasized ? IrisStyle.danger
        : root.emphasized ? IrisStyle.accent
        : root.quiet ? ColorUtils.applyAlpha(IrisStyle.surfaceHigh, 0)
        : IrisStyle.controlPlated ? IrisStyle.plateFillFor(IrisStyle.controlPlate)
        : IrisStyle.surfaceHigh
    colBackgroundHover: root.danger && root.emphasized
        ? ColorUtils.mix(IrisStyle.danger, IrisStyle.inkOnDanger, 0.90)
        : root.danger
            ? IrisStyle.tintFill(IrisStyle.danger)
        : root.emphasized
            ? IrisStyle.accentHover
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
            width: Math.min(implicitWidth, Math.max(0, contentHost.width - 16 * IrisStyle.density))
            elide: Text.ElideRight
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
