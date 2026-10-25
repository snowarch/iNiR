pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// Reel: one wallpaper in front, its neighbours fanned behind it on either side, all riding one spring. Quick to flick
// through (wheel, drag, arrows), the desktop behind shows the one in front; what the web knows folds out under it.
Item {
    id: root

    required property var engine
    required property var host
    property real maxWidth: 1600
    property real maxHeight: 900
    readonly property real d: IrisStyle.density
    readonly property real pad: Math.round(20 * root.d)
    readonly property real gap: Math.round(12 * root.d)

    readonly property real bodyWidth: Math.round(Math.max(880 * root.d, Math.min(1320 * root.d, root.maxWidth * 0.64)))
    readonly property real cardHeight: Math.round(Math.max(220 * root.d, Math.min(root.bodyWidth * 0.27, root.maxHeight * 0.34)))
    readonly property real cardWidth: Math.round(root.cardHeight * 1.6)

    implicitWidth: root.bodyWidth
    implicitHeight: column.implicitHeight + 2 * root.pad

    function focusSearch(): void { search.focusField() }
    function navigate(event): bool {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) { root.engine.move(1); return true }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) { root.engine.move(-1); return true }
        if (event.key === Qt.Key_PageDown) { root.engine.move(5); return true }
        if (event.key === Qt.Key_PageUp) { root.engine.move(-5); return true }
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
                id: sources
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
                Layout.preferredWidth: Math.round(300 * root.d)
                engine: root.engine
                navigate: event => root.navigate(event)
            }
            WallpaperOrder { engine: root.engine }
            WallpaperGlyphButton {
                visible: root.engine.online && (root.engine.filtersShaped || root.engine.ranged)
                glyph: "tune"
                implicitWidth: Math.round(36 * root.d)
                selected: root.host.filtersOpen || root.engine.filtersOn > 0
                Accessible.name: Translation.tr("Filters")
                onClicked: root.host.filtersOpen = !root.host.filtersOpen
            }
            WallpaperGlyphButton {
                glyph: root.engine.online ? "refresh" : "shuffle"
                implicitWidth: Math.round(36 * root.d)
                enabled: root.engine.online || root.engine.count > 0
                Accessible.name: root.engine.online ? Translation.tr("Refresh") : Translation.tr("Random wallpaper")
                onClicked: root.engine.online ? root.engine.searchOnline(1, true) : root.engine.shuffle()
            }
            WallpaperLayoutSwitch { layout: "reel" }
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
            visible: root.engine.online && root.host.filtersOpen
            engine: root.engine
        }

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.preferredHeight: root.cardHeight + Math.round(36 * root.d)
            clip: true

            WallpaperSlots {
                id: slots
                anchors.fill: parent
                engine: root.engine
                pool: 9
                cardWidth: root.cardWidth
                cardHeight: root.cardHeight
                cardRadius: IrisStyle.concentric(IrisStyle.radiusPanel, root.pad, IrisStyle.radiusCard)
                dragPitch: root.cardWidth * 0.55
                // Each step back is smaller and tucks a quarter of itself behind the one before it.
                readonly property var sizes: [1, 0.6, 0.4, 0.27, 0.18]
                function reach(n: int): real {
                    let x = 0
                    for (let i = 1; i <= n; i++) {
                        const a = sizes[Math.min(i - 1, 4)], b = sizes[Math.min(i, 4)]
                        x += (a + b) / 2 * root.cardWidth - 0.24 * b * root.cardWidth
                    }
                    return x
                }
                place: function(d) {
                    const n = Math.abs(d)
                    const s = sizes[Math.min(n, 4)]
                    return { x: stage.width / 2 + Math.sign(d) * reach(n), y: stage.height / 2 - Math.round(4 * root.d),
                        s: s, o: n >= 4 ? 0 : n === 3 ? 0.5 : 1, z: 100 - n * 10 }
                }
                onActivated: index => root.host.detailsOpen = !root.host.detailsOpen
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
            spacing: Math.round(16 * root.d)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(4 * root.d)
                IrisText {
                    Layout.fillWidth: true
                    text: root.engine.titleOf(root.engine.selected)
                    elide: Text.ElideRight
                    font.family: IrisStyle.fontTitle
                    font.pixelSize: IrisStyle.typeTitle
                    font.weight: IrisStyle.weight(Font.DemiBold)
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
            }
            WallpaperGlyphButton {
                glyph: "info"
                implicitWidth: Math.round(36 * root.d)
                filled: root.host.detailsOpen
                selected: root.host.detailsOpen
                enabled: root.engine.selected !== null
                Accessible.name: Translation.tr("Details")
                onClicked: root.host.detailsOpen = !root.host.detailsOpen
            }
            WallpaperActions { engine: root.engine }
        }

        WallpaperDetails {
            Layout.fillWidth: true
            visible: root.host.detailsOpen && root.engine.selected !== null
            engine: root.engine
        }
    }
}
