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
    // In iRiS: a button with a quiet plate of its own (Add widgets), or one that sits inside a quiet pill (the tools).
    property bool plate: false
    property bool inPill: false
    // The +/- that appears over a tile on hover; search results act on the widget instead.
    property bool badge: true
    readonly property bool showLabel: !compact && label.length > 0
    // iRiS draws edit controls in the Island's material: quiet translucent
    // states on black, the accent reserved for the one committing action.
    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    // iRiS widget rail: each widget is an app-icon-shaped tile in its category
    // tint, lit when the widget is on; the fill carries the state, nothing else does.
    property color tileTint: "transparent"
    readonly property bool irisTile: root.iris && root.tileTint.a > 0
    readonly property real d: root.iris ? IrisStyle.density : 1
    // Buttons keep their own height in iRiS: the base fills the row, which made "Done" as tall as the bar.
    Layout.fillHeight: !root.iris
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: root.irisTile ? Math.round(30 * root.d) : showLabel ? Math.ceil(labelMetrics.width) + iconSize + 34 : implicitHeight
    implicitHeight: root.irisTile ? Math.round(38 * root.d) : Math.round((root.inPill ? 30 : 38) * root.d)
    iconSize: Math.round(18 * root.d)
    width: implicitWidth
    height: implicitHeight
    toggled: primary
    opacity: enabled ? 1 : 0.38

    // Do not bind a property to itself for the non-iRiS branch. These temporary
    // overrides preserve the inherited Material/Waffle bindings and restore them
    // if the family changes without rebuilding the component.
    Binding { target: root; property: "buttonRadius"; value: root.height / 2; when: root.iris; restoreMode: Binding.RestoreBinding }
    Binding {
        target: root; property: "colBackground"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.plate ? IrisStyle.fillQuiet : "transparent"
    }
    Binding {
        target: root; property: "colBackgroundHover"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? "transparent" : IrisStyle.fillHover
    }
    Binding {
        target: root; property: "colBackgroundToggled"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? "transparent" : root.primary ? IrisStyle.accent : IrisStyle.fillActive
    }
    Binding {
        target: root; property: "colBackgroundToggledHover"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.irisTile ? "transparent" : root.primary ? Qt.lighter(IrisStyle.accent, 1.08) : IrisStyle.fillActive
    }
    Binding {
        target: root; property: "colText"; when: root.iris; restoreMode: Binding.RestoreBinding
        value: root.primary ? IrisStyle.inkOnAccent : root.toggled ? IrisStyle.text : IrisStyle.subtext
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
            anchors.centerIn: parent
            width: Math.round(30 * root.d)
            height: width
            radius: Math.round(width * 0.26)
            scale: root.down ? 0.92 : root.buttonHovered ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            color: root.toggled ? IrisStyle.containerOf(root.tileTint) : root.buttonHovered ? IrisStyle.fillHover : IrisStyle.fill
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(140) } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.iconName
                fill: root.toggled ? 1 : 0
                iconSize: Math.round(17 * root.d)
                color: root.toggled ? IrisStyle.onContainerOf(root.tileTint) : ColorUtils.applyAlpha(root.tileTint, root.buttonHovered ? 1 : 0.78)
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
                opacity: root.badge && root.buttonHovered ? 1 : 0
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
