pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Where the Island's data comes from, shown where it lands: the clock with the weather beside it in your units, the next
// event, and the updates bubble counting what is waiting.
PreviewScene {
    id: sourcesRoot
    readonly property bool fahrenheit: sourcesRoot.opt("bar.weather.useUSCS", false) === true
    readonly property string temperature: String(Weather.data?.temp ?? "--°C")
    readonly property string sky: String(Weather.data?.description ?? "")
    readonly property bool calendars: sourcesRoot.opt("calendar.externalSync.enable", false) === true
    readonly property real naturalWidth: Math.round(600 * sourcesRoot.d)
    readonly property real naturalHeight: Math.round(260 * sourcesRoot.d)
    narrowest: Math.round(420 * sourcesRoot.d)
    lowest: Math.round(180 * sourcesRoot.d)

    component Piece: Rectangle {
        id: piece
        property string glyph: ""
        property string label: ""
        property color tint: IrisStyle.identity.blue
        implicitWidth: Math.max(implicitHeight, pieceRow.implicitWidth + Math.round(20 * sourcesRoot.d))
        implicitHeight: Math.round(IrisFrame.islandBand)
        radius: IrisStyle.capsule(height)
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        RowLayout {
            id: pieceRow
            anchors.centerIn: parent
            spacing: Math.round(6 * sourcesRoot.d)
            MaterialSymbol { text: piece.glyph; fill: 1; iconSize: Math.round(17 * sourcesRoot.d); color: piece.tint }
            IrisText {
                visible: piece.label.length > 0
                text: piece.label
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.weight: IrisStyle.weight(Font.DemiBold)
            }
        }
    }

    Row {
        id: islandRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(IrisFrame.band + 6 * sourcesRoot.d)
        spacing: IrisStyle.weld + Math.round(4 * sourcesRoot.d)
        Piece { glyph: "event"; label: sourcesRoot.calendars ? "3" : ""; tint: IrisStyle.identity.red }
        IslandPill {}
        Piece { glyph: "partly_cloudy_day"; label: sourcesRoot.temperature; tint: IrisStyle.identity.yellow }
        Piece { glyph: "system_update_alt"; label: String(Updates.count ?? 0); tint: IrisStyle.identity.green }
    }

    Plate {
        surface: "cards"
        own: IrisStyle.identity.yellow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: islandRow.bottom
        anchors.topMargin: Math.round(18 * sourcesRoot.d)
        width: Math.min(parent.width - Math.round(48 * sourcesRoot.d), weatherRow.implicitWidth + Math.round(32 * sourcesRoot.d))
        height: Math.round(68 * sourcesRoot.d)
        radius: IrisStyle.radiusPlate
        RowLayout {
            id: weatherRow
            anchors.centerIn: parent
            spacing: Math.round(12 * sourcesRoot.d)
            IrisSquircle {
                implicitWidth: Math.round(36 * sourcesRoot.d)
                implicitHeight: implicitWidth
                tint: IrisStyle.identity.yellow
                glyph: "partly_cloudy_day"
            }
            IrisText {
                text: sourcesRoot.temperature
                font.family: IrisStyle.fontNumbers
                font.pixelSize: IrisStyle.typeTitleLarge
                font.weight: IrisStyle.weight(Font.Bold)
            }
            IrisText {
                Layout.maximumWidth: Math.round(220 * sourcesRoot.d)
                visible: text.length > 0
                text: sourcesRoot.sky
                color: IrisStyle.subtext
                elide: Text.ElideRight
            }
        }
    }

    Caption {
        glyph: "cloud_sync"
        text: [sourcesRoot.fahrenheit ? "°F" : "°C", sourcesRoot.calendars ? Translation.tr("Bring in other calendars") : ""].filter(part => part.length > 0).join(" · ")
    }
}
