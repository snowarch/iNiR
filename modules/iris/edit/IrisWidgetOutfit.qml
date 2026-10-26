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
    // In the card the outfit fills its widget; the edit window (IrisEditDesk) draws one over the card instead, at true
    // size where nothing clips it (`overlay`, placed by its host), and the one in the card keeps only the lifted shadow.
    property bool hostedElsewhere: false
    property bool overlay: false
    // The overlay's room on screen: keys and name stay inside it.
    property rect room: Qt.rect(0, 0, 1920, 1080)
    anchors.fill: root.overlay ? undefined : parent
    readonly property bool dressed: root.overlay || !root.hostedElsewhere

    readonly property bool selected: root.widget?.editSelected ?? false
    readonly property bool hovered: (root.widget?.editHovered ?? false) && !root.selected
    readonly property bool carried: root.widget?.isDragging ?? false
    readonly property bool locked: root.widget?.locked ?? false
    readonly property bool cut: IrisStyle.fieldChamfer
    readonly property bool ink: IrisStyle.nothingAt("widgets")
    // The card shrinks the desktop: the outfit's type and keys keep their true size on screen.
    readonly property var card: DesktopEditStage.cardFor(root.widget?.outputName ?? "", root.widget?.scaledScreenWidth ?? 0,
        root.widget?.scaledScreenHeight ?? 0)
    readonly property real hair: root.overlay ? 1 : 1 / Math.max(0.2, root.card.s)
    readonly property real d: IrisStyle.density
    readonly property real cardRadius: Math.round((root.widget?.widgetCardRadius ?? 18) * (root.widget?.scaleFactor ?? 1)) * (root.overlay ? root.card.s : 1)
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
        visible: root.dressed && !root.cut && root.lit > 0.01
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
        model: root.cut && root.dressed ? 4 : 0
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
        visible: root.carried && !root.overlay
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
    // In the card: the desktop's safe area in desktop px. Over it: the screen above the shelf, in screen px.
    readonly property real topNow: root.overlay ? (root.parent?.y ?? 0) + root.y : (root.widget?.y ?? 0)
    readonly property real leftNow: root.overlay ? (root.parent?.x ?? 0) + root.x : (root.widget?.x ?? 0)
    readonly property real roomTop: root.overlay ? root.room.y : (root.widget?._safeTop ?? 0)
    readonly property real roomBottom: root.overlay ? root.room.y + root.room.height : (root.widget?._safeBottom ?? 1080)
    readonly property real roomLeft: root.overlay ? root.room.x : 0
    readonly property real roomRight: root.overlay ? root.room.x + root.room.width : (root.widget?.scaledScreenWidth ?? 1920)
    readonly property real keysHeight: keys.height * root.hair
    readonly property real keysWidth: keys.width * root.hair
    // Above the widget, else below it, else inside its top edge.
    readonly property string keysAt: root.topNow - root.keysHeight - 2 * root.gap >= root.roomTop ? "above"
        : root.topNow + root.height + 2 * root.gap + root.keysHeight <= root.roomBottom ? "below" : "inside"
    readonly property bool keysAbove: root.keysAt === "above"
    readonly property bool tagBelow: root.topNow + root.height + 2 * root.gap + tag.height * root.hair <= root.roomBottom
    // Right-aligned with the widget, slid back inside the room at either side.
    function inside(x: real, w: real): real {
        return Math.max(root.roomLeft + 2 * root.gap, Math.min(root.roomRight - 2 * root.gap - w, x))
    }
    readonly property real keysX: root.inside(root.leftNow + root.width - root.keysWidth, root.keysWidth) - root.leftNow

    // ── Its name ──
    Item {
        id: tag
        readonly property real pad: 10 * root.d
        readonly property bool shown: root.dressed && root.hovered && !root.carried
        width: tagRow.implicitWidth + 2 * tag.pad
        height: Math.round(24 * root.d)
        scale: root.hair * (0.92 + 0.08 * tag.show)
        transformOrigin: root.tagBelow ? Item.Top : Item.Bottom
        x: root.inside(root.leftNow + (root.width - tag.width * root.hair) / 2, tag.width * root.hair) - root.leftNow
            + (tag.width * root.hair - tag.width) / 2
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
                font.weight: IrisStyle.weight(Font.Medium)
                font.capitalization: root.ink || root.cut ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: root.ink || root.cut ? 0.8 * root.d : 0
            }
        }
    }

    // ── Its keys, riding out of the top-right corner ──
    IrisSpring {
        id: emerge
        surface: "panels"
        to: root.dressed && root.selected && !root.carried ? 1 : 0
        intent: "auto"
        minimum: 0
    }
    readonly property Item keysItem: keys
    Row {
        id: keys
        readonly property real out: Math.max(0, Math.min(1, emerge.value))
        spacing: Math.round(6 * root.d)
        scale: root.hair * (0.6 + 0.4 * keys.out)
        transformOrigin: root.keysAt === "below" ? Item.TopRight : Item.BottomRight
        // The row is scaled about its right edge: place that edge.
        x: root.keysX + root.keysWidth - keys.width
        y: root.keysAt === "above" ? -2 * root.gap - keys.height
            : root.keysAt === "below" ? root.height + 2 * root.gap
            : 2 * root.gap + root.keysHeight - keys.height
        opacity: IrisStyle.contentAt(keys.out)
        visible: keys.out > 0.01
        enabled: root.selected

        // Chosen, its name leads the keys: one row, never a tag stacked on them.
        Rectangle {
            implicitHeight: Math.round(32 * root.d)
            implicitWidth: keyName.implicitWidth + Math.round(24 * root.d)
            radius: root.cut ? 0 : height / 2
            color: IrisStyle.surfaceOpaque
            border.width: IrisStyle.devicePx
            border.color: IrisStyle.hairlineStrong
            Row {
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                MaterialSymbol {
                    visible: root.locked
                    anchors.verticalCenter: parent.verticalCenter
                    text: "lock"
                    iconSize: Math.round(13 * root.d)
                    color: IrisStyle.textSecondary
                }
                StyledText {
                    id: keyName
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.name
                    color: IrisStyle.text
                    font.family: root.ink ? IrisStyle.fontLabel : IrisStyle.fontMain
                    font.pixelSize: root.ink ? Math.round(10 * root.d) : IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.DemiBold)
                    font.capitalization: root.ink ? Font.AllUppercase : Font.MixedCase
                    font.letterSpacing: root.ink ? 0.8 * root.d : 0
                }
            }
        }
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
                    font.weight: IrisStyle.weight(Font.DemiBold)
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
