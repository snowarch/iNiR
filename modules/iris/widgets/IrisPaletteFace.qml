pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property var colours: root.widget.colours
    readonly property var kept: root.widget.kept
    property int chosen: 2
    property int copied: -1
    property bool copiedAll: false
    readonly property var sources: [
        { value: "wallpaper", glyph: "wallpaper", label: Translation.tr("Wallpaper") },
        { value: "music", glyph: "album", label: Translation.tr("Music") },
        { value: "random", glyph: "shuffle", label: Translation.tr("Random") }
    ]
    readonly property string fromLabel: root.widget.from === "music" ? Translation.tr("Cover")
        : root.widget.from === "random" ? Translation.tr("Random") : Translation.tr("Wallpaper")

    function copyOne(index: int): void {
        root.chosen = index
        root.widget.copy(root.colours[index])
        root.copiedAll = false
        root.copied = index
        copiedReset.restart()
    }
    function copyAll(): void {
        root.widget.copy(root.colours.join(" "))
        root.copied = -1
        root.copiedAll = true
        copiedReset.restart()
    }
    Timer { id: copiedReset; interval: 1200; onTriggered: { root.copied = -1; root.copiedAll = false } }

    // One colour: tap copies it, right click keeps it through the next read. It pops when it changes,
    // left to right, the way SekaiPop's strip deals a new hand.
    component Chip: Rectangle {
        id: chip
        required property int index
        property bool hexInside: false
        readonly property string value: String(root.colours[chip.index] ?? "")
        readonly property bool held: String(root.kept[chip.index] ?? "").length > 0
        readonly property color onChip: root.onFill(chip.color)
        readonly property bool justCopied: root.copied === chip.index
        color: chip.value.length > 0 ? chip.value : root.fill
        border.width: chipHover.hovered ? root.dp(2) : 0
        border.color: ColorUtils.applyAlpha(chip.onChip, 0.45) // iris-literal: a swatch ring in its own colour
        transformOrigin: Item.Center
        scale: chipTap.pressed ? IrisStyle.pressScale(0.94) : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on color {
            SequentialAnimation {
                PauseAnimation { duration: chip.index * 12 }
                ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
            }
        }
        onValueChanged: if (root.live) pop.restart()
        SequentialAnimation {
            id: pop
            PauseAnimation { duration: chip.index * 12 }
            NumberAnimation { target: chip; property: "scale"; from: 0.86; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
        // The large face's chosen colour, the one "Use as accent" takes: a ring around it, concentric.
        Rectangle {
            visible: root.large && root.chosen === chip.index
            anchors.fill: parent
            anchors.margins: -root.dp(3)
            radius: chip.radius + root.dp(3)
            color: "transparent"
            border.width: root.dp(2)
            border.color: root.ink
        }
        MaterialSymbol {
            visible: chip.held
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: root.dp(5)
            text: "push_pin"
            fill: 1
            iconSize: root.px(11)
            color: chip.onChip
        }
        FaceText {
            face: root
            visible: chip.hexInside || chip.justCopied
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: chip.hexInside ? root.dp(10) : root.dp(2)
            anchors.rightMargin: anchors.leftMargin
            horizontalAlignment: chip.hexInside ? Text.AlignLeft : Text.AlignHCenter
            text: chip.justCopied ? Translation.tr("Copied") : chip.value
            color: chip.onChip
            size: 11
            weight: Font.DemiBold
            font.family: chip.justCopied ? root.fontMain : root.fontNumbers
            elide: Text.ElideRight
        }
        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: chipTap
            gesturePolicy: TapHandler.WithinBounds
            onTapped: root.copyOne(chip.index)
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: root.widget.keep(chip.index)
        }
        Accessible.role: Accessible.Button
        Accessible.name: chip.value
    }

    // A labelled key, for the large face where there is room to say what it does.
    component Key: Rectangle {
        id: key
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal activated()
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: root.dp(30)
        radius: IrisStyle.capsule(height)
        color: key.on ? root.fillActive : keyHover.hovered ? root.fillHover : root.fill
        scale: keyTap.pressed ? IrisStyle.pressScale(0.95) : 1
        Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        Row {
            anchors.centerIn: parent
            spacing: root.dp(5)
            width: Math.min(implicitWidth, key.width - root.dp(12))
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: key.glyph
                fill: key.on ? 1 : 0
                iconSize: root.px(14)
                color: key.on ? root.ink : root.inkSecondary
            }
            FaceText {
                face: root
                anchors.verticalCenter: parent.verticalCenter
                text: key.label
                color: key.on ? root.ink : root.inkSecondary
                size: 11.5
                weight: key.on ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }
        }
        HoverHandler { id: keyHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: keyTap; gesturePolicy: TapHandler.WithinBounds; onTapped: key.activated() }
        Accessible.role: Accessible.Button
        Accessible.name: key.label
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(3)
        Repeater {
            model: 5
            Chip {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: root.dp(7)
                hexInside: true
            }
        }
    }

    ColumnLayout {
        visible: !root.small
        anchors.fill: parent
        spacing: root.dp(root.large ? 10 : 8)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "palette"
            text: Translation.tr("Palette")
            trailing: root.large ? "" : root.fromLabel
        }

        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            spacing: root.dp(4)
            Repeater {
                model: root.sources
                Key {
                    required property var modelData
                    glyph: modelData.glyph
                    label: modelData.label
                    on: root.widget.colourSource === modelData.value
                    onActivated: modelData.value === "random" && root.widget.colourSource === "random"
                        ? root.widget.shuffle() : root.widget.setIrisOption("source", modelData.value)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(6)
            Repeater {
                model: 5
                ColumnLayout {
                    id: column
                    required property int index
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    spacing: root.dp(5)
                    Chip {
                        index: column.index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: root.dp(root.large ? 12 : 10)
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: String(root.colours[column.index] ?? "").slice(1)
                        color: root.large && root.chosen === column.index ? root.ink : root.inkSecondary
                        size: 10.5
                        weight: root.large && root.chosen === column.index ? Font.DemiBold : Font.Medium
                        font.family: root.fontNumbers
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            visible: root.large
            Layout.fillWidth: true
            spacing: root.dp(4)
            Key {
                glyph: "shuffle"
                label: Translation.tr("Shuffle")
                onActivated: root.widget.shuffle()
            }
            Key {
                glyph: root.copiedAll ? "check" : "content_copy"
                label: root.copiedAll ? Translation.tr("Copied") : Translation.tr("Copy all")
                onActivated: root.copyAll()
            }
            Key {
                visible: root.widget.canUseAccent
                glyph: root.widget.accentBefore ? "undo" : "format_paint"
                label: root.widget.accentBefore ? Translation.tr("Undo") : Translation.tr("Use as accent")
                on: root.widget.accentBefore !== null
                onActivated: root.widget.accentBefore ? root.widget.undoAccent() : root.widget.useAsAccent(root.colours[root.chosen])
            }
        }
    }
}
