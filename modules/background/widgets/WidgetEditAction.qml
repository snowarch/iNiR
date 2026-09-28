pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

IconToolbarButton {
    id: root
    property string iconName: ""
    property string label: ""
    property string tooltip: label
    property string tooltipPosition: "bottom"
    property bool compact: false
    property bool primary: false
    readonly property bool showLabel: !compact && label.length > 0
    // iRiS draws edit controls in the Island's material: quiet translucent
    // states on black, the accent reserved for the one committing action.
    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    // iRiS widget rail: each widget is an app-icon-shaped tile in its category
    // tint, and an enabled widget carries the Dock's "running" dot — the edit
    // toolbar reads as the Dock it replaces while editing.
    property color tileTint: "transparent"
    readonly property bool irisTile: root.iris && root.tileTint.a > 0
    implicitWidth: root.irisTile ? 36 : showLabel ? Math.ceil(labelMetrics.width) + iconSize + 34 : implicitHeight
    implicitHeight: root.irisTile ? 40 : 32
    iconSize: 18
    width: implicitWidth
    height: implicitHeight
    toggled: primary
    opacity: enabled ? 1 : 0.38

    // Do not bind a property to itself for the non-iRiS branch. These temporary
    // overrides preserve the inherited Material/Waffle bindings and restore them
    // if the family changes without rebuilding the component.
    Binding { target: root; property: "buttonRadius"; value: root.height / 2; when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding {
        target: root; property: "colBackgroundHover"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? ColorUtils.applyAlpha(IrisStyle.text, 0) : ColorUtils.applyAlpha(IrisStyle.text, 0.12)
    }
    Binding {
        target: root; property: "colBackgroundToggled"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? ColorUtils.applyAlpha(IrisStyle.text, 0)
            : root.primary ? IrisStyle.accent : ColorUtils.applyAlpha(IrisStyle.text, 0.16)
    }
    Binding {
        target: root; property: "colBackgroundToggledHover"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? ColorUtils.applyAlpha(IrisStyle.text, 0)
            : root.primary ? Qt.lighter(IrisStyle.accent, 1.08) : ColorUtils.applyAlpha(IrisStyle.text, 0.22)
    }
    Binding {
        target: root; property: "colText"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.primary ? IrisStyle.onAccent : root.toggled ? IrisStyle.text : IrisStyle.subtext
    }

    TextMetrics {
        id: labelMetrics
        text: root.label
        font.family: root.iris ? IrisStyle.fontMain : Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Appearance.editorialEverywhere ? Appearance.editorial.labelWeight : Font.Medium
    }
    contentItem: Item {
        clip: !root.irisTile

        Rectangle {
            id: tile
            visible: root.irisTile
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 3
            width: 28
            height: 28
            radius: Math.round(width * 0.26)
            scale: root.down ? 0.9 : root.buttonHovered ? 1.1 : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            color: root.toggled ? root.tileTint : root.buttonHovered ? IrisStyle.fillHover : IrisStyle.fillQuiet
            gradient: root.toggled ? onGradient : null
            border.width: root.toggled ? 0 : 1
            border.color: ColorUtils.applyAlpha(root.tileTint, root.buttonHovered ? 0.6 : 0.24)
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140) } }
            Gradient {
                id: onGradient
                GradientStop { position: 0; color: Qt.lighter(root.tileTint, 1.18) }
                GradientStop { position: 1; color: root.tileTint }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                fill: root.toggled ? 1 : 0
                iconSize: 17
                color: root.toggled ? IrisStyle.onTint : ColorUtils.applyAlpha(root.tileTint, root.buttonHovered ? 1 : 0.78)
            }
            Rectangle {
                x: parent.width - width * 0.7
                y: -height * 0.3
                width: 13
                height: 13
                radius: width / 2
                color: root.toggled ? IrisStyle.danger : IrisStyle.accent
                border.width: 1.5
                border.color: IrisStyle.surface
                opacity: root.buttonHovered ? 1 : 0
                scale: opacity > 0 ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120) } }
                Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.toggled ? "remove" : "add"
                    iconSize: 11
                    color: IrisStyle.onTint
                }
            }
        }
        Rectangle {
            visible: root.irisTile && root.toggled
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: 4
            height: 4
            radius: 2
            color: IrisStyle.text
        }

        Row {
            visible: !root.irisTile
            anchors.centerIn: parent
            spacing: root.showLabel ? 6 : 0
            MaterialSymbol {
                width: root.iconSize
                height: root.iconSize
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.iconName
                iconSize: root.iconSize
                color: root.colText
            }
            StyledText {
                visible: root.showLabel
                width: Math.ceil(labelMetrics.width)
                horizontalAlignment: Text.AlignHCenter
                text: root.label
                font.family: root.iris ? IrisStyle.fontMain : Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Appearance.editorialEverywhere ? Appearance.editorial.labelWeight : Font.Medium
                color: root.colText
            }
        }
    }
    StyledToolTip { text: root.tooltip; position: root.tooltipPosition }
}
