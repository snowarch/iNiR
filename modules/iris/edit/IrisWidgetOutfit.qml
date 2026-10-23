pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.widgets

// What a desktop widget wears while the desktop is arranged in iRiS (the family's part `widgetOutfit`, loaded by
// AbstractBackgroundWidget): under the pointer a hairline concentric with its card and its name hanging under it;
// chosen, a ring and its keys riding out of the top-right corner the way the Island's bubbles ride out of it (its size,
// its controls, the lock, back on the shelf); carried, it casts the shadow of something lifted. AIRISU marks a chosen
// widget with crop marks instead of a ring; under the Nothing layer the ring is ink and the name a Label.
Item {
    id: root

    property Item widget: null
    anchors.fill: parent

    readonly property bool selected: root.widget?.editSelected ?? false
    readonly property bool hovered: (root.widget?.editHovered ?? false) && !root.selected
    readonly property bool carried: root.widget?.isDragging ?? false
    readonly property bool locked: root.widget?.locked ?? false
    readonly property bool cut: IrisStyle.fieldChamfer
    readonly property bool ink: IrisStyle.nothingAt("widgets")
    // The card shrinks the desktop: the outfit's type and keys keep their true size on screen.
    readonly property var card: DesktopEditStage.cardFor(root.widget?.outputName ?? "", root.widget?.scaledScreenWidth ?? 0,
        root.widget?.scaledScreenHeight ?? 0)
    readonly property real hair: 1 / Math.max(0.2, root.card.s)
    readonly property real d: IrisStyle.density
    readonly property real cardRadius: Math.round((root.widget?.widgetCardRadius ?? 18) * (root.widget?.scaleFactor ?? 1))
    readonly property real gap: 4 * root.hair
    readonly property color ringInk: root.ink ? IrisStyle.text : IrisStyle.accent

    readonly property string name: {
        const key = String(root.widget?.configEntryName ?? "")
        const entry = IrisFaceData.galleryEntries.concat(IrisFaceData.otherEntries).find(e => e.key === key)
        if (entry) return entry.label
        const words = key.split(".").pop().replace(/([A-Z])/g, " $1").toLowerCase().trim()
        return words.charAt(0).toUpperCase() + words.slice(1)
    }
    readonly property var sizes: root.widget?.irisSizeChoices ?? []
    readonly property bool sized: (root.widget?.irisFaced ?? false) && root.sizes.length > 1
    readonly property string size: root.widget?.irisSize ?? ""
    readonly property string sizeName: root.sized ? (root.widget?.irisSizeLabels?.[root.size] ?? "") : ""
    function nextSize(): void {
        const i = root.sizes.indexOf(root.size)
        root.widget.commitIrisSize(root.sizes[(i + 1) % root.sizes.length])
    }

    // ── The ring, or AIRISU's crop marks ──
    property real lit: root.selected ? 1 : root.hovered ? 0.55 : 0
    Behavior on lit { NumberAnimation { duration: 110; easing.type: IrisStyle.feedbackEasing } }
    Rectangle {
        visible: !root.cut && root.lit > 0.01
        anchors.fill: parent
        anchors.margins: -root.gap
        radius: root.cardRadius + root.gap
        color: "transparent"
        border.width: (root.selected ? 1.5 : 1) * root.hair * IrisStyle.devicePx
        border.color: root.selected ? root.ringInk : IrisStyle.hairlineStrong
        opacity: root.lit
        antialiasing: true
    }
    Repeater {
        model: root.cut ? 4 : 0
        delegate: Item {
            id: mark
            required property int index
            readonly property bool east: mark.index % 2 === 1
            readonly property bool south: mark.index >= 2
            readonly property real arm: 12 * root.hair
            readonly property real thick: 2 * root.hair
            x: mark.east ? root.width + root.gap - mark.arm : -root.gap
            y: mark.south ? root.height + root.gap - mark.arm : -root.gap
            width: mark.arm
            height: mark.arm
            opacity: root.lit
            Rectangle { y: mark.south ? mark.arm - mark.thick : 0; width: mark.arm; height: mark.thick; color: root.selected ? root.ringInk : IrisStyle.text }
            Rectangle { x: mark.east ? mark.arm - mark.thick : 0; width: mark.thick; height: mark.arm; color: root.selected ? root.ringInk : IrisStyle.text }
        }
    }

    // ── Lifted while carried ──
    IrisBodyShadow {
        z: -1
        visible: root.carried
        x: 0
        y: 10 * root.hair
        width: root.width
        height: root.height
        radius: root.cut ? 0 : root.cardRadius
        blur: 30 * root.hair
        spread: -6 * root.hair
        color: ColorUtils.applyAlpha(IrisStyle.shadow, Math.min(1, IrisStyle.shadow.a * 1.4))
    }

    // ── Room round the widget, for the keys and the name ──
    readonly property real roomTop: root.widget?._safeTop ?? 0
    readonly property real roomBottom: root.widget?._safeBottom ?? 1080
    readonly property real keysHeight: keys.height * root.hair
    readonly property bool keysAbove: (root.widget?.y ?? 0) - root.keysHeight - 2 * root.gap >= root.roomTop
    readonly property bool tagBelow: !root.keysAbove ? false
        : (root.widget?.y ?? 0) + root.height + 2 * root.gap + tag.height * root.hair <= root.roomBottom

    // ── Its name ──
    Item {
        id: tag
        readonly property real pad: 10 * root.d
        readonly property bool shown: (root.hovered || root.selected) && !root.carried
        width: tagRow.implicitWidth + 2 * tag.pad
        height: Math.round(24 * root.d)
        scale: root.hair * (0.92 + 0.08 * tag.show)
        transformOrigin: root.tagBelow ? Item.Top : Item.Bottom
        x: (root.width - tag.width) / 2
        y: root.tagBelow ? root.height + 2 * root.gap : -2 * root.gap - tag.height
        opacity: tag.show
        visible: tag.show > 0.01
        property real show: tag.shown ? 1 : 0
        Behavior on show { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }

        Rectangle {
            anchors.fill: parent
            visible: !root.cut
            radius: height / 2
            color: IrisStyle.surfaceOpaque
            border.width: IrisStyle.devicePx
            border.color: IrisStyle.hairlineStrong
        }
        // AIRISU: a seal box, its cut parallel to the widget's.
        Shape {
            anchors.fill: parent
            visible: root.cut
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: root.selected ? IrisStyle.accent : IrisStyle.surfaceOpaque
                PathSvg {
                    readonly property real c: Math.round(tag.height / 4)
                    path: `M 0 0 L ${tag.width - c} 0 L ${tag.width} ${c} L ${tag.width} ${tag.height} L ${c} ${tag.height} L 0 ${tag.height - c} Z`
                }
            }
        }
        Row {
            id: tagRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                visible: root.locked
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                iconSize: Math.round(12 * root.d)
                color: IrisStyle.textSecondary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.name
                color: root.cut && root.selected ? IrisStyle.inkOnAccent : IrisStyle.text
                font.family: root.ink || root.cut ? IrisStyle.fontLabel : IrisStyle.fontMain
                font.pixelSize: root.ink || root.cut ? Math.round(10 * root.d) : IrisStyle.typeFootnote
                font.weight: root.ink || root.cut ? Font.Medium : Font.DemiBold
                font.capitalization: root.ink || root.cut ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: root.ink || root.cut ? 0.8 * root.d : 0
            }
            // Chosen, the size key says it.
            StyledText {
                visible: root.sizeName.length > 0 && !root.selected
                anchors.verticalCenter: parent.verticalCenter
                text: root.sizeName
                color: root.cut && root.selected ? IrisStyle.inkOnAccent : IrisStyle.textSecondary
                font.family: root.ink || root.cut ? IrisStyle.fontLabel : IrisStyle.fontMain
                font.pixelSize: root.ink || root.cut ? Math.round(10 * root.d) : IrisStyle.typeFootnote
                font.weight: Font.Medium
                font.capitalization: root.ink || root.cut ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: root.ink || root.cut ? 0.8 * root.d : 0
            }
        }
    }

    // ── Its keys, riding out of the top-right corner ──
    IrisSpring {
        id: emerge
        surface: "panels"
        to: root.selected && !root.carried ? 1 : 0
        intent: "auto"
        minimum: 0
    }
    Row {
        id: keys
        readonly property real out: Math.max(0, Math.min(1, emerge.value))
        spacing: Math.round(6 * root.d)
        scale: root.hair * (0.6 + 0.4 * keys.out)
        transformOrigin: root.keysAbove ? Item.BottomRight : Item.TopRight
        x: root.width - keys.width
        y: root.keysAbove ? -2 * root.gap - keys.height : root.height + 2 * root.gap
        opacity: IrisStyle.contentAt(keys.out)
        visible: keys.out > 0.01
        enabled: root.selected

        // The size it is, as a little grid of the cells it takes; a press moves to the next one.
        IrisButton {
            visible: root.sized && !root.locked
            implicitHeight: Math.round(32 * root.d)
            implicitWidth: sizeRow.implicitWidth + Math.round(20 * root.d)
            Accessible.name: Translation.tr("Size: %1").arg(root.sizeName)
            onClicked: root.nextSize()
            Row {
                id: sizeRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                Grid {
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    spacing: Math.round(2 * root.d)
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            readonly property bool filled: root.size === "large" || index === 0 || (root.size === "medium" && index === 1)
                            width: Math.round(5 * root.d)
                            height: width
                            radius: root.cut ? 0 : Math.round(1.5 * root.d)
                            color: IrisStyle.text
                            opacity: filled ? 1 : 0.28
                            Behavior on opacity { NumberAnimation { duration: 110; easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sizeName
                    color: IrisStyle.text
                    font.family: root.ink ? IrisStyle.fontLabel : IrisStyle.fontMain
                    font.pixelSize: root.ink ? Math.round(10 * root.d) : IrisStyle.typeFootnote
                    font.weight: Font.DemiBold
                    font.capitalization: root.ink ? Font.AllUppercase : Font.MixedCase
                }
            }
        }
        IrisIconButton {
            visible: !root.locked
            implicitWidth: Math.round(32 * root.d)
            quiet: false
            materialIcon: "tune"
            selected: (root.widget?.quickControlsOpen ?? false) && root.widget?.quickTab !== root.widget?._arrangeTab
            Accessible.name: Translation.tr("Edit")
            onClicked: selected ? root.widget.closeQuickControls() : root.widget.openQuickControls("widget")
        }
        IrisIconButton {
            implicitWidth: Math.round(32 * root.d)
            quiet: false
            materialIcon: root.locked ? "lock" : "lock_open"
            selected: root.locked
            Accessible.name: root.locked ? Translation.tr("Unlock") : Translation.tr("Lock")
            onClicked: root.widget._setOutputValue("locked", !root.locked)
        }
        IrisIconButton {
            visible: !root.locked
            implicitWidth: Math.round(32 * root.d)
            quiet: false
            materialIcon: "remove"
            Accessible.name: Translation.tr("Put back")
            onClicked: {
                GlobalStates.clearDesktopWidgetSelection()
                root.widget.takeAway()
            }
        }
    }
}
