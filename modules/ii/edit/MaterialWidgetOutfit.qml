pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.shared.background.widgets

// What a desktop widget wears while the desktop is arranged under Material (the family's part `widgetOutfit`): under
// the pointer an outline and its name; chosen, a primary ring and a floating toolbar (its name, its size, its controls,
// the lock, back on the shelf). The edit window (MaterialEditDesk) draws it over the card at true size (`overlay`),
// where the neighbours can't take its clicks; the one in the card then keeps only the lifted shadow.
Item {
    id: root

    property Item widget: null
    property bool hostedElsewhere: false
    property bool overlay: false
    // The overlay's room on screen: the toolbar and the name stay inside it.
    property rect room: Qt.rect(0, 0, 1920, 1080)
    anchors.fill: root.overlay ? undefined : parent
    readonly property bool dressed: root.overlay || !root.hostedElsewhere
    readonly property Item keysItem: bar

    readonly property bool selected: root.widget?.editSelected ?? false
    readonly property bool hovered: (root.widget?.editHovered ?? false) && !root.selected
    readonly property bool carried: root.widget?.isDragging ?? false
    readonly property bool locked: root.widget?.locked ?? false
    readonly property var card: DesktopEditStage.cardFor(root.widget?.outputName ?? "", root.widget?.scaledScreenWidth ?? 0,
        root.widget?.scaledScreenHeight ?? 0)
    // In the card everything is drawn 1/s so it reads at true size; over it, it already is.
    readonly property real hair: root.overlay ? 1 : 1 / Math.max(0.2, root.card.s)
    readonly property real gap: 5 * root.hair
    readonly property real cardRadius: Math.round((root.widget?.widgetCardRadius ?? Appearance.rounding.normal) * (root.widget?.scaleFactor ?? 1))
        * (root.overlay ? root.card.s : 1)
    readonly property string name: {
        const key = String(root.widget?.configEntryName ?? "")
        if (DesktopWidgetRegistry.has(key)) return Translation.tr(DesktopWidgetRegistry.nameOf(key))
        const words = key.split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    readonly property var sizes: (root.widget?.materialSized ?? false) ? (root.widget?.materialSizes ?? []) : []
    readonly property string size: root.widget?.materialSize ?? ""

    property real lit: root.dressed ? (root.selected ? 1 : root.hovered ? 0.7 : 0) : 0
    Behavior on lit { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
    Rectangle {
        visible: root.lit > 0.01
        anchors.fill: parent
        anchors.margins: -root.gap
        radius: root.cardRadius + root.gap
        color: "transparent"
        border.width: (root.selected ? 2.5 : 1.5) * root.hair
        border.color: root.locked ? Appearance.colors.colError
            : root.selected ? Appearance.colors.colPrimary : Appearance.colors.colOutline
        opacity: root.lit
        antialiasing: true
    }

    RectangularShadow {
        z: -1
        visible: root.carried && !root.overlay
        y: 12 * root.hair
        width: root.width
        height: root.height
        radius: root.cardRadius
        blur: 32 * root.hair
        spread: -4 * root.hair
        color: ColorUtils.applyAlpha(Appearance.colors.colShadow, 0.55)
    }

    // ── Room round the widget, in this item's pixels ──
    readonly property real topNow: root.overlay ? (root.parent?.y ?? 0) + root.y : (root.widget?.y ?? 0)
    readonly property real leftNow: root.overlay ? (root.parent?.x ?? 0) + root.x : (root.widget?.x ?? 0)
    readonly property real roomTop: root.overlay ? root.room.y : (root.widget?._safeTop ?? 0)
    readonly property real roomBottom: root.overlay ? root.room.y + root.room.height : (root.widget?._safeBottom ?? 1080)
    readonly property real roomLeft: root.overlay ? root.room.x : 0
    readonly property real roomRight: root.overlay ? root.room.x + root.room.width : (root.widget?.scaledScreenWidth ?? 1920)
    function inside(x: real, w: real): real {
        return Math.max(root.roomLeft + 2 * root.gap, Math.min(root.roomRight - 2 * root.gap - w, x))
    }
    readonly property real barHeight: bar.height * root.hair
    readonly property real barWidth: bar.width * root.hair
    // Above the widget, else below it, else over its top edge.
    readonly property string barAt: root.topNow - root.barHeight - 2 * root.gap >= root.roomTop ? "above"
        : root.topNow + root.height + 2 * root.gap + root.barHeight <= root.roomBottom ? "below" : "inside"
    readonly property bool chipBelow: root.topNow + root.height + 2 * root.gap + chip.height * root.hair <= root.roomBottom

    // ── Its name, under the pointer ──
    Rectangle {
        id: chip
        readonly property bool shown: root.dressed && root.hovered && !root.carried
        property real show: chip.shown ? 1 : 0
        Behavior on show { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        visible: chip.show > 0.01
        opacity: chip.show
        width: chipRow.implicitWidth + 20
        height: 26
        radius: Math.min(height / 2, Appearance.rounding.full)
        scale: root.hair * (0.92 + 0.08 * chip.show)
        transformOrigin: root.chipBelow ? Item.Top : Item.Bottom
        x: root.inside(root.leftNow + (root.width - chip.width * root.hair) / 2, chip.width * root.hair) - root.leftNow
            + (chip.width * root.hair - chip.width) / 2
        y: root.chipBelow ? root.height + 2 * root.gap : -2 * root.gap - chip.height
        color: Appearance.colors.colSecondaryContainer
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: root.locked ? "lock" : (root.widget?.identityGlyph ?? "widgets")
                iconSize: 14
                fill: 1
                color: Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSecondaryContainer
            }
        }
    }

    // ── Chosen: a floating toolbar ──
    component Key: RippleButton {
        id: key
        property string glyph
        property bool selected: false
        property bool danger: false
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: key.selected ? Appearance.rounding.small : Appearance.rounding.full
        colBackground: key.selected ? Appearance.colors.colSecondaryContainer : "transparent"
        colBackgroundHover: key.selected ? Appearance.colors.colSecondaryContainerHover
            : key.danger ? ColorUtils.transparentize(Appearance.colors.colError, 0.84) : Appearance.colors.colLayer3Hover
        colRipple: key.selected ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer3Active
        Behavior on buttonRadius { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.OutCubic } }
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: key.glyph
            iconSize: 18
            fill: key.selected ? 1 : 0
            color: key.selected ? Appearance.colors.colOnSecondaryContainer
                : key.danger && key.hovered ? Appearance.colors.colError : Appearance.colors.colOnLayer2
        }
    }
    property real rise: root.dressed && root.selected && !root.carried ? 1 : 0
    Behavior on rise { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial } }
    Rectangle {
        id: bar
        visible: root.rise > 0.01
        enabled: root.selected
        opacity: Math.min(1, root.rise * 1.6)
        width: barRow.implicitWidth + 8
        height: 40
        radius: Math.min(height / 2, Appearance.rounding.full)
        color: Appearance.colors.colLayer2
        scale: root.hair * (0.86 + 0.14 * root.rise)
        transformOrigin: root.barAt === "below" ? Item.Top : Item.Bottom
        x: root.inside(root.leftNow + (root.width - root.barWidth) / 2, root.barWidth) - root.leftNow + (root.barWidth - bar.width) / 2
        y: root.barAt === "above" ? -2 * root.gap - bar.height + (1 - root.rise) * 10 * root.hair
            : root.barAt === "below" ? root.height + 2 * root.gap - (1 - root.rise) * 10 * root.hair
            : 2 * root.gap
        StyledRectangularShadow { target: bar; z: -1 }
        // The press lands here, never on the widget or the card under it.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: 2
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: nameRow.implicitWidth + 20
                height: 32
                radius: Math.min(height / 2, Appearance.rounding.full)
                color: root.locked ? Appearance.colors.colErrorContainer : Appearance.colors.colSecondaryContainer
                Row {
                    id: nameRow
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.locked ? "lock" : (root.widget?.identityGlyph ?? "widgets")
                        iconSize: 16
                        fill: 1
                        color: root.locked ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.name
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                        color: root.locked ? Appearance.colors.colOnErrorContainer : Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
            // S M L as one segmented track; the chosen size is a pill sliding inside it, every key the same size.
            Rectangle {
                id: sizeTrack
                readonly property var shown: ["small", "medium", "large"].filter(size => root.sizes.includes(size))
                readonly property int chosenIndex: Math.max(0, sizeTrack.shown.indexOf(root.size))
                readonly property real cell: 26
                anchors.verticalCenter: parent.verticalCenter
                visible: root.sizes.length > 1 && !root.locked
                width: sizeTrack.shown.length * sizeTrack.cell + 6
                height: 32
                radius: Math.min(height / 2, Appearance.rounding.full)
                color: Appearance.colors.colLayer3
                Rectangle {
                    x: 3 + sizeTrack.chosenIndex * sizeTrack.cell
                    y: 3
                    width: sizeTrack.cell
                    height: sizeTrack.height - 6
                    radius: Math.min(height / 2, Appearance.rounding.full)
                    color: Appearance.colors.colPrimary
                    Behavior on x { NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial } }
                }
                Row {
                    x: 3
                    y: 3
                    Repeater {
                        model: sizeTrack.shown
                        delegate: RippleButton {
                            id: sizeKey
                            required property string modelData
                            readonly property bool chosen: root.size === sizeKey.modelData
                            implicitWidth: sizeTrack.cell
                            implicitHeight: sizeTrack.height - 6
                            buttonRadius: Math.min(height / 2, Appearance.rounding.full)
                            colBackground: "transparent"
                            colBackgroundHover: sizeKey.chosen ? "transparent" : Appearance.colors.colLayer3Hover
                            colRipple: sizeKey.chosen ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Active
                            Accessible.name: root.widget?.materialSizeLabels?.[sizeKey.modelData] ?? sizeKey.modelData
                            onClicked: if (!sizeKey.chosen) root.widget.commitMaterialSize(sizeKey.modelData)
                            contentItem: StyledText {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: sizeKey.modelData.charAt(0).toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: sizeKey.chosen ? Font.Bold : Font.Medium
                                color: sizeKey.chosen ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3
                                Behavior on color { ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }
                            }
                        }
                    }
                }
            }
            Item { width: 2; height: 1 }
            Key {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.locked
                glyph: "tune"
                selected: (root.widget?.quickControlsOpen ?? false) && root.widget?.quickTab !== root.widget?._arrangeTab
                Accessible.name: Translation.tr("Edit")
                onClicked: selected ? root.widget.closeQuickControls() : root.widget.openQuickControls("widget")
            }
            Key {
                anchors.verticalCenter: parent.verticalCenter
                glyph: root.locked ? "lock" : "lock_open"
                selected: root.locked
                Accessible.name: root.locked ? Translation.tr("Unlock") : Translation.tr("Lock")
                onClicked: root.widget._setOutputValue("locked", !root.locked)
            }
            Key {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.locked
                glyph: "remove"
                danger: true
                Accessible.name: Translation.tr("Put back")
                onClicked: {
                    GlobalStates.clearDesktopWidgetSelection()
                    root.widget.takeAway()
                }
            }
        }
    }
}
