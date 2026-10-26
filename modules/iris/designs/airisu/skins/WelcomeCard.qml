pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.preview
import qs.modules.iris.components
import "../components"

// AIRISU's welcome (General's head): the frontispiece of the catalogue. The desktop as it is now is printed as the
// plate (the live miniature, cut by the body's die and standing on its offset shadow); beside it the greeting as ruby
// over the person's name set large in the figure voice, the machine as a line of ruby, and the two keys that change the
// picture, the first one the seal. Under it the wallpapers next in the folder as a strip of small prints, the one on the
// desktop with its line band in the seal along its foot. The card (IrisWallpaperCard) keeps what it knows and does.
Item {
    id: root
    property Item host
    readonly property real d: Airisu.d
    function u(n: real): int { return Airisu.u(n) }
    readonly property var screen: root.host?.screen ?? GlobalStates.focusedScreen
    readonly property real aspect: root.screen ? root.screen.height / Math.max(1, root.screen.width) : 0.5625
    readonly property real plateW: Math.round(Math.min(root.width * 0.46, root.u(80)))
    readonly property real plateH: Math.round(root.plateW * root.aspect)
    readonly property var nearby: root.host?.nearby ?? []
    readonly property int cells: root.nearby.length + 1
    readonly property real cellW: Math.floor((root.width - (root.cells - 1) * root.u(2)) / Math.max(1, root.cells))
    readonly property real cellH: Math.round(root.cellW * 10 / 16)
    // The head is as tall as the taller of the plate and the words: a narrow sheet wraps the keys under each other, and
    // words centred on a shorter plate rose over the sheet's top and lost the greeting to its edge.
    readonly property real headH: Math.max(root.plateH + Airisu.offset, words.implicitHeight)
    implicitHeight: root.headH + (root.nearby.length > 1 ? root.u(5) + root.cellH + root.u(1) : 0)

    // ── The plate: the desktop now.
    ALacquer {
        x: Airisu.offset
        y: Airisu.offset
        width: root.plateW
        height: root.plateH
        lacquer: Airisu.shade
        cut: Airisu.chamfer
    }
    Item {
        id: plate
        width: root.plateW
        height: root.plateH
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: plateDie
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
        IrisScreenPreview {
            anchors.fill: parent
            screen: root.screen
            radius: 0
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Change wallpaper")
            onClicked: root.host.openGallery()
        }
    }
    ADie {
        id: plateDie
        visible: false
        width: root.plateW
        height: root.plateH
        kind: "chamfer"
        cut: Airisu.chamfer
        fill: "white"
        layer.enabled: true
    }

    // ── The greeting.
    Column {
        id: words
        x: root.plateW + root.u(7)
        y: Math.max(0, Math.round((root.plateH - words.implicitHeight) / 2))
        width: root.width - x
        spacing: 0
        AText {
            id: name
            readonly property int most: Math.round(IrisStyle.typeDisplay * 1.35)
            width: parent.width
            voice: "figure"
            size: Math.max(IrisStyle.typeTitleLarge, Math.min(name.most, Math.floor(name.most * width / Math.max(1, nameMetrics.advanceWidth))))
            lineHeight: 0.95
            color: Airisu.sealText
            text: String(root.host?.name ?? "")
            TextMetrics {
                id: nameMetrics
                font.family: name.font.family
                font.weight: name.font.weight
                font.pixelSize: name.most
                font.letterSpacing: -Math.round(name.most * 0.03)
                text: name.text
            }
        }
        AText {
            width: parent.width
            topPadding: root.u(1.5)
            voice: "ruby"
            size: IrisStyle.typeMeta
            text: [String(root.host?.kind ?? ""), String(root.host?.title ?? "")].filter(part => part.length > 0).join(" · ")
        }
        Flow {
            width: parent.width
            topPadding: root.u(4)
            spacing: root.u(1.5)
            Key {
                glyph: "photo_library"
                label: Translation.tr("Change wallpaper")
                sealed: true
                onClicked: root.host.openGallery()
            }
            Key {
                glyph: "shuffle"
                label: ""
                name: Translation.tr("Random wallpaper")
                onClicked: Wallpapers.nextWallpaper()
            }
        }
    }

    // ── The strip: the wallpapers next in the folder, and the way to all of them.
    Row {
        visible: root.nearby.length > 1
        y: root.headH + root.u(5)
        spacing: root.u(2)
        Repeater {
            model: root.nearby
            MouseArea {
                id: shot
                required property string modelData
                readonly property bool chosen: shot.modelData === String(root.host?.current ?? "")
                width: root.cellW
                height: root.cellH + root.u(1)
                hoverEnabled: true
                cursorShape: shot.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: FileUtils.fileNameForPath(shot.modelData)
                onClicked: if (!shot.chosen) root.host.apply(shot.modelData)
                Item {
                    id: picture
                    width: parent.width
                    height: root.cellH
                    // The pointer and the press move the print, never shrink it: a hair up, then down and right.
                    y: shot.pressed ? Airisu.nudge : shot.containsMouse && !shot.chosen ? -Airisu.nudge : 0
                    x: shot.pressed ? Airisu.nudge : 0
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: cellDie
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                    IrisImage {
                        anchors.fill: parent
                        source: Wallpapers.stillUrlFor(shot.modelData)
                    }
                }
                // The line band: the one on the desktop.
                Rectangle {
                    visible: shot.chosen
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Airisu.strong
                    color: Airisu.seal
                }
            }
        }
        MouseArea {
            id: all
            width: root.cellW
            height: root.cellH
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("All wallpapers")
            onClicked: root.host.openGallery()
            AKey {
                anchors.fill: parent
                lacquer: "transparent"
                under: Airisu.sheet
                hovered: all.containsMouse
                pressed: all.pressed
            }
            ADie {
                anchors.fill: parent
                kind: "chamfer"
                cut: Airisu.cutFor(root.cellH)
                stroke: all.containsMouse ? Airisu.ink : Airisu.inkThird
                strokeWidth: Airisu.hair
            }
            Column {
                anchors.centerIn: parent
                spacing: Airisu.nudge
                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "grid_view"
                    iconSize: Math.round(18 * root.d)
                    color: Airisu.ink
                }
                AText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: IrisStyle.typeMeta
                    font.weight: Font.DemiBold
                    text: Translation.tr("All")
                }
            }
        }
    }
    ADie {
        id: cellDie
        visible: false
        width: root.cellW
        height: root.cellH
        kind: "chamfer"
        cut: Airisu.cutFor(root.cellH)
        fill: "white"
        layer.enabled: true
    }

    // A key of the greeting: the seal for the first thing to do; the rest are tags, a die ruled in the third ink on the
    // sheet (a filled grey box read as a key that cannot be taken).
    component Key: MouseArea {
        id: key
        property string glyph
        property string label
        property string name: key.label
        property bool sealed: false
        readonly property color stock: key.sealed ? Airisu.seal : Airisu.sheet
        // A narrow card (Drawer's plate) keeps the key whole as its glyph alone, never a word cut by the card's edge.
        readonly property bool worded: key.label.length > 0
            && keyGlyph.implicitWidth + keyRow.spacing + keyLabel.implicitWidth + root.u(7) <= (key.parent?.width ?? Infinity)
        width: keyRow.implicitWidth + root.u(key.worded ? 7 : 4)
        height: root.u(9)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: key.name
        AKey {
            id: keyFace
            anchors.fill: parent
            lacquer: key.sealed ? key.stock : "transparent"
            under: key.stock
            hovered: key.containsMouse
            pressed: key.pressed
        }
        ADie {
            visible: !key.sealed
            anchors.fill: parent
            kind: "chamfer"
            cut: keyFace.cut
            stroke: key.containsMouse ? Airisu.ink : Airisu.inkThird
            strokeWidth: Airisu.hair
        }
        Row {
            id: keyRow
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: keyFace.shift
            anchors.verticalCenterOffset: keyFace.shift
            spacing: root.u(1.5)
            MaterialSymbol {
                id: keyGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: key.glyph
                iconSize: Math.round(17 * root.d)
                color: Airisu.inkOn(key.stock)
            }
            AText {
                id: keyLabel
                visible: key.worded
                anchors.verticalCenter: parent.verticalCenter
                size: IrisStyle.typeLabel
                font.weight: Font.DemiBold
                color: Airisu.inkOn(key.stock)
                text: key.label
            }
        }
    }
}
