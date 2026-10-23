pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// What a desktop widget wears while the desktop is arranged under Material (the family's part `widgetOutfit`, loaded
// by AbstractBackgroundWidget): under the pointer an outline and its name as a chip under it; chosen, a primary
// outline and a floating toolbar over it (its controls, the lock, back on the shelf) that rises out of its top edge;
// carried, the shadow of something lifted. Its resize handles stay the engine's.
Item {
    id: root

    property Item widget: null
    anchors.fill: parent

    readonly property bool selected: root.widget?.editSelected ?? false
    readonly property bool hovered: (root.widget?.editHovered ?? false) && !root.selected
    readonly property bool carried: root.widget?.isDragging ?? false
    readonly property bool locked: root.widget?.locked ?? false
    readonly property var card: DesktopEditStage.cardFor(root.widget?.outputName ?? "", root.widget?.scaledScreenWidth ?? 0,
        root.widget?.scaledScreenHeight ?? 0)
    readonly property real hair: 1 / Math.max(0.2, root.card.s)
    readonly property real gap: 4 * root.hair
    readonly property real cardRadius: Math.round((root.widget?.widgetCardRadius ?? Appearance.rounding.normal) * (root.widget?.scaleFactor ?? 1))
    readonly property string name: {
        const words = String(root.widget?.configEntryName ?? "").split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }

    property real lit: root.selected ? 1 : root.hovered ? 0.6 : 0
    Behavior on lit { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
    Rectangle {
        visible: root.lit > 0.01
        anchors.fill: parent
        anchors.margins: -root.gap
        radius: root.cardRadius + root.gap
        color: "transparent"
        border.width: (root.selected ? 2 : 1) * root.hair
        border.color: root.locked ? Appearance.colors.colError
            : root.selected ? Appearance.colors.colPrimary : Appearance.colors.colOutline
        opacity: root.lit
        antialiasing: true
    }

    RectangularShadow {
        z: -1
        visible: root.carried
        y: 10 * root.hair
        width: root.width
        height: root.height
        radius: root.cardRadius
        blur: 28 * root.hair
        spread: -4 * root.hair
        color: ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.6)
    }

    readonly property real roomTop: root.widget?._safeTop ?? 0
    readonly property real barHeight: bar.height * root.hair
    readonly property bool barAbove: (root.widget?.y ?? 0) - root.barHeight - 2 * root.gap >= root.roomTop

    // Its name, an assist chip under it.
    Rectangle {
        id: chip
        readonly property bool shown: (root.hovered || root.selected) && !root.carried
        property real show: chip.shown ? 1 : 0
        Behavior on show { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        visible: chip.show > 0.01
        opacity: chip.show
        width: chipRow.implicitWidth + 20
        height: 26
        radius: Appearance.rounding.small
        scale: root.hair * (0.94 + 0.06 * chip.show)
        transformOrigin: root.barAbove ? Item.Top : Item.Bottom
        x: (root.width - chip.width) / 2
        y: root.barAbove ? root.height + 2 * root.gap : -2 * root.gap - chip.height
        color: Appearance.colors.colSecondaryContainer
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                visible: root.locked
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                iconSize: 14
                color: Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
    }

    // Chosen: a floating toolbar rising out of its top edge.
    property real rise: root.selected && !root.carried ? 1 : 0
    Behavior on rise { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve } }
    Rectangle {
        id: bar
        visible: root.rise > 0.01
        enabled: root.selected
        opacity: Math.min(1, root.rise * 1.6)
        width: barRow.implicitWidth + 12
        height: 48
        radius: height / 2
        color: Appearance.colors.colSurfaceContainerHigh
        scale: root.hair * (0.85 + 0.15 * root.rise)
        transformOrigin: root.barAbove ? Item.Bottom : Item.Top
        x: (root.width - bar.width) / 2
        y: root.barAbove ? -2 * root.gap - bar.height + (1 - root.rise) * 8 * root.hair : root.height + 2 * root.gap
        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            blur: 14
            spread: -2
            offset: Qt.vector2d(0, 3)
            color: ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.45)
        }
        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 2
            WidgetEditAction {
                visible: !root.locked
                iconName: "tune"
                label: Translation.tr("Edit")
                toggled: (root.widget?.quickControlsOpen ?? false) && root.widget?.quickTab !== root.widget?._arrangeTab
                onClicked: toggled ? root.widget.closeQuickControls() : root.widget.openQuickControls("widget")
            }
            WidgetEditAction {
                compact: true
                iconName: root.locked ? "lock" : "lock_open"
                label: root.locked ? Translation.tr("Unlock") : Translation.tr("Lock")
                toggled: root.locked
                onClicked: root.widget._setOutputValue("locked", !root.locked)
            }
            WidgetEditAction {
                visible: !root.locked
                compact: true
                iconName: "remove"
                label: Translation.tr("Put back")
                onClicked: {
                    GlobalStates.clearDesktopWidgetSelection()
                    root.widget.takeAway()
                }
            }
        }
    }
}
