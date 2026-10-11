pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// A snip in progress: the screen veiled outside the region, the region's corners and size, a window it snaps to when
// that is on, and the toolbar with what you turned on (reading text, Japanese, recording).
PreviewScene {
    id: snipRoot
    readonly property bool snaps: snipRoot.opt("regionSelector.targetRegions.windows", true) === true
    readonly property bool japanese: snipRoot.opt("regionSelector.japaneseLookup.enabled", false) === true
    readonly property bool satty: snipRoot.opt("regionSelector.annotation.useSatty", false) === true
    readonly property string sound: String(snipRoot.opt("screenRecord.audioMode", "system"))
    readonly property real naturalWidth: Math.round(640 * snipRoot.d)
    readonly property real naturalHeight: Math.round(320 * snipRoot.d)
    property real grow: 0
    Loop on grow { running: snipRoot.playing; rest: 1600 }

    readonly property rect region: Qt.rect(Math.round(snipRoot.width * 0.24), Math.round(snipRoot.height * 0.14),
        Math.round(snipRoot.width * (0.36 + 0.16 * snipRoot.grow)), Math.round(snipRoot.height * (0.4 + 0.12 * snipRoot.grow)))

    // The veil outside the region, in four pieces so the region keeps the picture.
    Rectangle { x: 0; y: 0; width: snipRoot.width; height: snipRoot.region.y; color: IrisStyle.veil }
    Rectangle { x: 0; y: snipRoot.region.y + snipRoot.region.height; width: snipRoot.width; height: snipRoot.height - y; color: IrisStyle.veil }
    Rectangle { x: 0; y: snipRoot.region.y; width: snipRoot.region.x; height: snipRoot.region.height; color: IrisStyle.veil }
    Rectangle { x: snipRoot.region.x + snipRoot.region.width; y: snipRoot.region.y; width: snipRoot.width - x; height: snipRoot.region.height; color: IrisStyle.veil }

    // A window the selection would snap to.
    Rectangle {
        visible: snipRoot.snaps
        x: Math.round(snipRoot.width * 0.62)
        y: Math.round(snipRoot.height * 0.1)
        width: Math.round(snipRoot.width * 0.3)
        height: Math.round(snipRoot.height * 0.5)
        radius: IrisStyle.radiusChip
        color: "transparent"
        border.width: 1
        border.color: IrisStyle.onMediaTertiary
    }
    Repeater {
        model: 4
        Rectangle {
            required property int index
            readonly property real arm: Math.round(18 * snipRoot.d)
            x: snipRoot.region.x + (index % 2 === 0 ? -2 : snipRoot.region.width - arm + 2)
            y: snipRoot.region.y + (index < 2 ? -2 : snipRoot.region.height - arm + 2)
            width: arm
            height: arm
            color: "transparent"
            border.width: Math.max(2, Math.round(3 * snipRoot.d))
            border.color: IrisStyle.accentOnMedia
            radius: IrisStyle.radiusMicro
        }
    }
    Rectangle {
        x: snipRoot.region.x
        y: snipRoot.region.y + snipRoot.region.height + Math.round(8 * snipRoot.d)
        width: sizeText.implicitWidth + Math.round(16 * snipRoot.d)
        height: Math.round(22 * snipRoot.d)
        radius: height / 2
        color: IrisStyle.veilHeavy
        IrisText {
            id: sizeText
            anchors.centerIn: parent
            text: `${Math.round(snipRoot.region.width * 2)} × ${Math.round(snipRoot.region.height * 2)}`
            color: IrisStyle.onMedia
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: IrisStyle.typeMeta
        }
    }

    Plate {
        surface: "cards"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(18 * snipRoot.d)
        width: tools.implicitWidth + Math.round(16 * snipRoot.d)
        height: Math.round(48 * snipRoot.d)
        radius: height / 2
        Row {
            id: tools
            anchors.centerIn: parent
            spacing: Math.round(4 * snipRoot.d)
            Repeater {
                model: [{ glyph: "screenshot_region", lit: true }, { glyph: "select_window", lit: false }, { glyph: "text_fields", lit: false },
                    { glyph: "translate", lit: false, shown: snipRoot.japanese }, { glyph: snipRoot.satty ? "draw" : "edit", lit: false },
                    { glyph: snipRoot.sound === "none" ? "videocam" : "screen_record", lit: false }].filter(tool => tool.shown !== false)
                Rectangle {
                    required property var modelData
                    width: Math.round(36 * snipRoot.d)
                    height: width
                    radius: width / 2
                    color: modelData.lit ? IrisStyle.tintFill(IrisStyle.accent) : "transparent"
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        iconSize: Math.round(18 * snipRoot.d)
                        color: parent.modelData.lit ? IrisStyle.accent : IrisStyle.text
                    }
                }
            }
        }
    }

    Caption {
        glyph: "screenshot_region"
        text: [Translation.tr("Snip"), snipRoot.snaps ? Translation.tr("Snap to windows") : "",
            snipRoot.japanese ? Translation.tr("Look up Japanese") : ""].filter(part => part.length > 0).join(" · ")
    }
}
