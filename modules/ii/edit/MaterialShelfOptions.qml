pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// The bar's or the Dock's everyday options on Material's shelf, as M3 cards in a row that scrolls sideways: a switch, a
// short choice as chips, a size as a slider. The card above shows each change as it lands; the rest is in Settings.
Flickable {
    id: root

    // [{ path, label, kind: "switch" | "choice" | "range", options: [{ label, value }], min, max, step, unit }]
    property var specs: []
    property string settingsPage: "bar"
    readonly property real gap: 10
    readonly property real cardHeight: Math.floor((root.height - root.gap) / 2)
    FontMetrics { id: labelMetrics; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.small; font.weight: Font.Medium }
    FontMetrics { id: chipMetrics; font.family: Appearance.font.family.main; font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium }
    // Each card as wide as what it holds, in two rows that stay even: the next one goes on the shorter row.
    readonly property var placed: {
        const rows = [0, 0], out = []
        const lay = (w, item) => {
            const r = rows[0] <= rows[1] ? 0 : 1
            out.push(Object.assign({ x: rows[r], y: r * (root.cardHeight + root.gap), w: Math.ceil(w) }, item))
            rows[r] += Math.ceil(w) + root.gap
        }
        for (const spec of root.specs) {
            const label = labelMetrics.advanceWidth(Translation.tr(String(spec.label ?? ""))) + 28
            if (spec.kind === "switch") lay(Math.max(170, label + 60), { spec: spec, key: spec.path })
            else if (spec.kind === "range") lay(Math.max(240, label + 80), { spec: spec, key: spec.path })
            else {
                const chips = (spec.options ?? []).reduce((sum, option) => sum + chipMetrics.advanceWidth(Translation.tr(String(option.label))) + 22, 0)
                    + 6 * Math.max(0, (spec.options ?? []).length - 1) + 14 + 28
                lay(Math.max(label, chips), { spec: spec, key: spec.path })
            }
        }
        lay(150, { spec: null, key: "more" })
        return out
    }

    contentWidth: board.width
    contentHeight: height
    flickableDirection: Flickable.HorizontalFlick
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y
            root.contentX = Math.max(0, Math.min(root.contentWidth - root.width, root.contentX - delta / 120 * 180))
        }
    }

    Item {
        id: board
        width: Math.max(0, ...root.placed.map(cell => cell.x + cell.w))
        height: root.height
        Repeater {
            model: ScriptModel { values: root.placed; objectProp: "key" }
            Loader {
                id: cell
                required property var modelData
                x: cell.modelData.x
                y: cell.modelData.y
                width: cell.modelData.w
                height: root.cardHeight
                sourceComponent: !cell.modelData.spec ? moreCard : cell.modelData.spec.kind === "switch" ? switchCard
                    : cell.modelData.spec.kind === "range" ? rangeCard : choiceCard
                onLoaded: if (cell.modelData.spec) cell.item.spec = cell.modelData.spec
            }
        }
    }
    Component {
        id: moreCard
        RippleButton {
            buttonRadius: Appearance.rounding.normal
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: GlobalStates.openSettingsAt(root.settingsPage)
            Accessible.name: Translation.tr("More in Settings")
            contentItem: Item {
                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                    border.width: 1
                    border.color: Appearance.colors.colOutlineVariant
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    MaterialSymbol { anchors.verticalCenter: parent.verticalCenter; text: "tune"; iconSize: 18; color: Appearance.colors.colOnLayer1 }
                    StyledText { anchors.verticalCenter: parent.verticalCenter; text: Translation.tr("More in Settings"); font.pixelSize: Appearance.font.pixelSize.smaller; font.weight: Font.Medium }
                }
            }
        }
    }

    component Card: Rectangle {
        id: card
        property var spec: null
        readonly property var value: { Config.revision; return Config.getNestedValue(String(card.spec?.path ?? ""), undefined) }
        height: root.cardHeight
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2
        StyledText {
            id: cardLabel
            x: 14
            y: 8
            width: card.width - 28
            elide: Text.ElideRight
            text: Translation.tr(String(card.spec?.label ?? ""))
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: Appearance.colors.colOnLayer2
        }
    }
    Component {
        id: switchCard
        Card {
            id: sw
            StyledSwitch {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                checked: !!sw.value
                onToggled: Config.setNestedValue(sw.spec.path, checked)
                Accessible.name: Translation.tr(String(sw.spec?.label ?? ""))
            }
            StyledText {
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: sw.value ? Translation.tr("On") : Translation.tr("Off")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }
    Component {
        id: choiceCard
        Card {
            id: choice
            Row {
                id: chips
                x: 14
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                spacing: 6
                Repeater {
                    model: choice.spec?.options ?? []
                    RippleButton {
                        id: chip
                        required property var modelData
                        readonly property bool chosen: choice.value === chip.modelData.value
                        implicitHeight: 26
                        implicitWidth: chipText.implicitWidth + (chip.chosen ? 36 : 22)
                        buttonRadius: Appearance.rounding.small
                        colBackground: chip.chosen ? Appearance.colors.colSecondaryContainer : "transparent"
                        colBackgroundHover: chip.chosen ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer2Hover
                        Behavior on implicitWidth { NumberAnimation { duration: Appearance.animationsEnabled ? 160 : 0; easing.type: Easing.OutCubic } }
                        onClicked: Config.setNestedValue(choice.spec.path, chip.modelData.value)
                        Accessible.name: Translation.tr(String(chip.modelData.label))
                        contentItem: Item {
                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: "transparent"
                                border.width: chip.chosen ? 0 : 1
                                border.color: Appearance.colors.colOutlineVariant
                            }
                            Row {
                                anchors.centerIn: parent
                                spacing: 4
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: chip.chosen
                                    text: "check"
                                    iconSize: 14
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                StyledText {
                                    id: chipText
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Translation.tr(String(chip.modelData.label))
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Medium
                                    color: chip.chosen ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: rangeCard
        Card {
            id: range
            property real dragged: NaN
            readonly property real shown: Number.isFinite(range.dragged) ? range.dragged : Number(range.value ?? range.spec?.min ?? 0)
            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 14
                y: 8
                text: Math.round(range.shown) + (range.spec?.unit ? " " + range.spec.unit : "")
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: ({ "tnum": 1 })
                color: Appearance.colors.colSubtext
            }
            StyledSlider {
                x: 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: parent.width - 12
                configuration: StyledSlider.Configuration.XS
                enableSettingsSearch: false
                from: Number(range.spec?.min ?? 0)
                to: Number(range.spec?.max ?? 1)
                stepSize: Number(range.spec?.step ?? 1)
                value: range.shown
                // Seen live in memory while it moves, written once on release.
                onMoved: {
                    range.dragged = value
                    Config.previewNestedValue(range.spec.path, value)
                    if (!pressed) { Config.setNestedValue(range.spec.path, value); range.dragged = NaN }
                }
                onPressedChanged: if (!pressed && Number.isFinite(range.dragged)) {
                    const v = range.dragged
                    range.dragged = NaN
                    Config.setNestedValue(range.spec.path, v)
                }
            }
        }
    }
}
