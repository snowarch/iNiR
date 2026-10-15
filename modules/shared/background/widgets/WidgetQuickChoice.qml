pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

// One choice in a widget's quick controls. It sizes from its whole content with equal side padding,
// and in a grid it takes the cell's width and keeps its icon and label centred together.
// iRiS draws the Island's quiet fill with the accent on the chosen one; the ii family its Global Style.
Rectangle {
    id: root

    property string iconName: ""
    property string label: ""
    property bool selected: false
    property bool danger: false
    property string tooltip: ""
    signal clicked()

    readonly property bool iris: (Config.options?.panelFamily ?? "ii") === "iris"
    readonly property real d: root.iris ? IrisStyle.density : 1
    property real sidePadding: Math.round(12 * root.d)
    readonly property color ink: root.iris
        ? (root.selected ? IrisStyle.text : IrisStyle.textSecondary)
        : Appearance.zzzEverywhere ? (root.selected ? Appearance.zzz.onSticker : Appearance.zzz.ink)
        : Appearance.regaliaEverywhere ? (root.selected ? Appearance.regalia.primaryPlateInk : Appearance.regalia.onColor)
        : root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
    readonly property color dangerInk: root.iris ? IrisStyle.danger : Appearance.colors.colError
    readonly property color glyphInk: root.danger ? root.dangerInk : root.iris && root.selected ? IrisStyle.accent : root.ink

    implicitWidth: content.implicitWidth + root.sidePadding * 2
    implicitHeight: Math.round(34 * root.d)
    radius: root.iris ? height / 2
        : Appearance.zzzEverywhere ? Appearance.zzz.controlRadius
        : Appearance.regaliaEverywhere ? Appearance.regalia.controlRadius
        : Appearance.editorialEverywhere ? Appearance.rounding.small
        : Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : height / 2
    color: root.iris
        ? (root.selected ? IrisStyle.tintFill(IrisStyle.accent) : hover.hovered ? IrisStyle.fillHover : IrisStyle.fillQuiet)
        : root.selected
            ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker
                : Appearance.regaliaEverywhere ? Appearance.regalia.primaryPlate
                : hover.hovered ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer)
            : ColorUtils.applyAlpha(Appearance.colors.colOnLayer2, hover.hovered ? 0.1 : 0.055)
    border.width: root.iris && root.selected ? 1 : Appearance.editorialEverywhere && root.selected ? 1 : 0
    border.color: root.iris ? IrisStyle.tintBorder(IrisStyle.accent) : Appearance.editorialEverywhere ? Appearance.editorial.edge : "transparent"
    scale: tap.pressed ? (root.iris ? IrisStyle.pressScale(0.97) : 0.97) : 1
    Behavior on color {
        enabled: root.iris ? IrisStyle.motionEnabled : Appearance.animationsEnabled
        ColorAnimation { duration: root.iris ? IrisStyle.feedbackDuration : Appearance.animation.elementMoveFast.duration }
    }
    Behavior on scale {
        enabled: root.iris ? IrisStyle.motionEnabled : Appearance.animationsEnabled
        NumberAnimation { duration: root.iris ? IrisStyle.feedbackDuration : Appearance.animation.elementMoveFast.duration }
    }

    Row {
        id: content
        readonly property real room: root.width - root.sidePadding * 2
        anchors.centerIn: parent
        spacing: root.iconName.length > 0 && root.label.length > 0 ? Math.round(6 * root.d) : 0

        MaterialSymbol {
            id: glyph
            visible: root.iconName.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.iconName
            fill: root.selected ? 1 : 0
            iconSize: Math.round(16 * root.d)
            color: root.glyphInk
        }
        StyledText {
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(Math.ceil(implicitWidth), Math.max(0, content.room - (glyph.visible ? glyph.width + content.spacing : 0)))
            text: root.label
            elide: Text.ElideRight
            color: root.danger ? root.dangerInk : root.ink
            font.family: root.iris ? IrisStyle.fontMain : Appearance.font.family.main
            font.pixelSize: root.iris ? IrisStyle.typeLabel : Appearance.font.pixelSize.smaller
            font.weight: root.selected ? Font.DemiBold : Font.Medium
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; gesturePolicy: TapHandler.WithinBounds; onTapped: answer.restart() }
    // Answered after the tap returns: a pick can rebuild the rows this cell lives in, and a cell
    // destroyed inside its own tap swallows the next click.
    Timer { id: answer; interval: 0; onTriggered: root.clicked() }
    StyledToolTip { text: root.tooltip; extraVisibleCondition: hover.hovered && root.tooltip.length > 0 }
    Accessible.role: Accessible.RadioButton
    Accessible.name: root.label
    Accessible.checked: root.selected
}
