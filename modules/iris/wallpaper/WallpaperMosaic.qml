pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Mosaic: the chosen wallpaper large on the left and the next five waiting beside it, two up top and three below.
// Stepping runs the line like a conveyor: the next one grows into the front as the front slides away, the rest move
// up a place. Everything the web knows about the one in front reads under it.
Item {
    id: root

    required property var engine
    required property var host
    property real maxWidth: 1600
    property real maxHeight: 900
    readonly property real d: IrisStyle.density
    readonly property real pad: Math.round(20 * root.d)
    readonly property real gap: Math.round(12 * root.d)

    readonly property real bodyWidth: Math.round(Math.max(960 * root.d, Math.min(1400 * root.d, root.maxWidth * 0.7)))
    readonly property real inner: root.bodyWidth - 2 * root.pad
    // The front's height is what makes the right side (two over three, all 16:10) exactly as tall as it.
    readonly property real heroHeight: Math.round(Math.min(root.maxHeight * 0.42, (0.52083 * root.inner - 0.25 * root.gap) / 1.83333))
    readonly property real heroWidth: Math.round(root.heroHeight * 1.6)
    readonly property real sideWidth: root.inner - root.heroWidth - root.gap
    readonly property real mediumWidth: (root.sideWidth - root.gap) / 2
    readonly property real smallWidth: (root.sideWidth - 2 * root.gap) / 3

    implicitWidth: root.bodyWidth
    implicitHeight: column.implicitHeight + 2 * root.pad

    function focusSearch(): void { search.focusField() }
    function navigate(event): bool {
        if (event.key === Qt.Key_Right) { root.engine.move(1); return true }
        if (event.key === Qt.Key_Left) { root.engine.move(-1); return true }
        // Down walks to the row below on the right (the third one waiting), up comes back.
        if (event.key === Qt.Key_Down) { root.engine.move(3); return true }
        if (event.key === Qt.Key_Up) { root.engine.move(-3); return true }
        if (event.key === Qt.Key_PageDown) { root.engine.move(6); return true }
        if (event.key === Qt.Key_PageUp) { root.engine.move(-6); return true }
        return root.host.commonKey(event)
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: root.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Math.round(8 * root.d)
            IrisSegmented {
                Layout.preferredHeight: Math.round(36 * root.d)
                Layout.preferredWidth: Math.max(Math.round(84 * root.d) * options.length + 2 * inset, fitWidth)
                accessibleName: Translation.tr("Source")
                options: root.engine.sources.map(entry => ({ value: entry.id, label: entry.label }))
                current: root.engine.source
                onPicked: value => root.engine.setSource(value, "")
            }
            Item { Layout.fillWidth: true }
            WallpaperSearch {
                id: search
                Layout.preferredWidth: Math.round(320 * root.d)
                engine: root.engine
                navigate: event => root.navigate(event)
            }
            WallpaperOrder { engine: root.engine }
            WallpaperGlyphButton {
                glyph: root.engine.online ? "refresh" : "shuffle"
                implicitWidth: Math.round(36 * root.d)
                enabled: root.engine.online || root.engine.count > 0
                Accessible.name: root.engine.online ? Translation.tr("Refresh") : Translation.tr("Random wallpaper")
                onClicked: root.engine.online ? root.engine.searchOnline(1, true) : root.engine.shuffle()
            }
            WallpaperLayoutSwitch { layout: "mosaic" }
        }

        WallpaperContext {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            id: context
            visible: context.filled && (root.engine.query.length === 0 || root.engine.online)
            engine: root.engine
        }
        WallpaperFilters {
            Layout.fillWidth: true
            visible: root.engine.online && (root.engine.filtersShaped || root.engine.ranged)
            engine: root.engine
        }

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.preferredHeight: root.heroHeight
            clip: true

            WallpaperSlots {
                anchors.fill: parent
                engine: root.engine
                pool: 10
                lead: 2.5
                recede: 0.06
                recedeMost: 0.16
                cardWidth: root.heroWidth
                cardHeight: root.heroHeight
                cardRadius: IrisStyle.concentric(IrisStyle.radiusPanel, root.pad, IrisStyle.radiusCard)
                dragPitch: root.mediumWidth
                readonly property real sideX: root.heroWidth + root.gap
                readonly property real mediumScale: root.mediumWidth / root.heroWidth
                readonly property real smallScale: root.smallWidth / root.heroWidth
                readonly property real mediumHeight: root.mediumWidth / 1.6
                readonly property real smallHeight: root.smallWidth / 1.6
                function medium(k: int): var {
                    return { x: sideX + k * (root.mediumWidth + root.gap) + root.mediumWidth / 2, y: mediumHeight / 2,
                        s: mediumScale, o: 1, z: 80 - k }
                }
                function small(k: int, o: real): var {
                    return { x: sideX + k * (root.smallWidth + root.gap) + root.smallWidth / 2, y: mediumHeight + root.gap + smallHeight / 2,
                        s: smallScale, o: o, z: 70 - k }
                }
                place: function(d) {
                    if (d === 0) return { x: root.heroWidth / 2, y: root.heroHeight / 2, s: 1, o: 1, z: 100 }
                    if (d === -1) return { x: root.heroWidth * 0.18, y: root.heroHeight / 2, s: 0.82, o: 0, z: 60 }
                    if (d < -1) return { x: 0, y: root.heroHeight / 2, s: 0.7, o: 0, z: 50 }
                    if (d <= 2) return medium(d - 1)
                    if (d <= 5) return small(d - 3, 1)
                    return small(d - 3, 0)
                }
                onActivated: index => root.engine.apply(root.engine.entryAt(index))
            }
            WallpaperEmpty {
                anchors.centerIn: parent
                width: parent.width - 80 * root.d
                visible: root.engine.count === 0
                picker: root.engine
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Math.round(4 * root.d)
            spacing: Math.round(20 * root.d)
            ColumnLayout {
                Layout.preferredWidth: root.heroWidth
                Layout.maximumWidth: root.heroWidth
                Layout.alignment: Qt.AlignTop
                spacing: Math.round(6 * root.d)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(10 * root.d)
                    IrisText {
                        Layout.fillWidth: true
                        text: root.engine.titleOf(root.engine.selected)
                        elide: Text.ElideRight
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeTitle
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        visible: root.engine.count > 0
                        text: (root.engine.selectedIndex + 1) + " / " + (root.engine.online && root.engine.onlineTotal > 0
                            ? root.engine.compact(root.engine.onlineTotal) : root.engine.count)
                        color: IrisStyle.subtext
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.Bold)
                    }
                }
                WallpaperFacts {
                    Layout.fillWidth: true
                    engine: root.engine
                    entry: root.engine.selected
                }
                IrisText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.engine.status
                    color: IrisStyle.muted
                    font.pixelSize: IrisStyle.typeMeta
                    elide: Text.ElideRight
                }
                WallpaperActions {
                    Layout.topMargin: Math.round(6 * root.d)
                    engine: root.engine
                }
            }
            WallpaperDetails {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                engine: root.engine
            }
        }
    }
}
