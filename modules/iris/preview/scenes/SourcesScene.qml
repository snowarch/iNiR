pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// Sources: where the Island's data comes from, one card each, refreshing in turn. A source that is off sits dimmed
// with nothing to say; weather reads in the unit chosen, readings leave the GPU out when told to.
PreviewScene {
    id: sourcesRoot
    readonly property real naturalWidth: Math.round(600 * sourcesRoot.d)
    readonly property real naturalHeight: Math.round(300 * sourcesRoot.d)
    narrowest: Math.round(440 * sourcesRoot.d)
    lowest: Math.round(240 * sourcesRoot.d)
    subject: Qt.rect(grid.x, grid.y, grid.width, grid.height)
    readonly property bool weather: sourcesRoot.opt("bar.weather.enable", false) === true
    readonly property bool fahrenheit: sourcesRoot.opt("bar.weather.useUSCS", false) === true
    readonly property bool calendars: sourcesRoot.opt("calendar.externalSync.enable", false) === true
    readonly property bool vpn: sourcesRoot.opt("vpn.quickToggle", false) === true
    readonly property bool updates: sourcesRoot.opt("shellUpdates.enabled", true) === true
    readonly property bool gpu: sourcesRoot.opt("resources.monitorGpu", true) === true
    // The card being refreshed now.
    property int pulse: 0
    Timer { interval: 900; running: sourcesRoot.playing; repeat: true; onTriggered: sourcesRoot.pulse = (sourcesRoot.pulse + 1) % 4 }

    Grid {
        id: grid
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(14 * sourcesRoot.d)
        columns: 2
        spacing: Math.round(12 * sourcesRoot.d)
        readonly property real cellW: Math.round(Math.min(250 * sourcesRoot.d, (sourcesRoot.width - 60 * sourcesRoot.d) / 2))
        readonly property real cellH: Math.round(86 * sourcesRoot.d)
        Repeater {
            model: [
                { glyph: "partly_cloudy_day", name: Translation.tr("Weather"), on: sourcesRoot.weather, tint: IrisStyle.identity.sky },
                { glyph: "event", name: Translation.tr("Calendar"), on: true, tint: IrisStyle.identity.red },
                { glyph: "memory", name: Translation.tr("Readings"), on: true, tint: IrisStyle.identity.green },
                { glyph: "system_update_alt", name: Translation.tr("New iNiR"), on: sourcesRoot.updates, tint: IrisStyle.identity.yellow }
            ]
            Plate {
                id: source
                required property var modelData
                required property int index
                readonly property bool fresh: source.index === sourcesRoot.pulse && source.modelData.on
                width: grid.cellW
                height: grid.cellH
                radius: IrisStyle.radiusPlate
                opacity: source.modelData.on ? 1 : 0.4
                RowLayout {
                    x: Math.round(14 * sourcesRoot.d); y: Math.round(12 * sourcesRoot.d)
                    width: parent.width - 2 * x
                    spacing: Math.round(8 * sourcesRoot.d)
                    MaterialSymbol { text: source.modelData.glyph; fill: 1; iconSize: Math.round(17 * sourcesRoot.d); color: source.modelData.tint }
                    IrisText { Layout.fillWidth: true; text: source.modelData.name; font.weight: Font.DemiBold; font.pixelSize: IrisStyle.typeMeta }
                    MaterialSymbol {
                        text: "sync"
                        iconSize: Math.round(15 * sourcesRoot.d)
                        color: IrisStyle.textTertiary
                        opacity: source.fresh ? 1 : 0.35
                        RotationAnimation on rotation { running: source.fresh; from: 0; to: -360; duration: 900; loops: 1 }
                    }
                }
                // What each says.
                Item {
                    x: Math.round(14 * sourcesRoot.d)
                    y: Math.round(42 * sourcesRoot.d)
                    width: parent.width - 2 * x
                    height: parent.height - y - Math.round(12 * sourcesRoot.d)
                    IrisText {
                        visible: source.index === 0 && source.modelData.on
                        anchors.verticalCenter: parent.verticalCenter
                        text: sourcesRoot.fahrenheit ? "64°F" : "18°C"
                        font.family: IrisStyle.fontNumbers
                        font.weight: IrisStyle.figureWeight
                        font.pixelSize: IrisStyle.typeTitle
                    }
                    RowLayout {
                        visible: source.index === 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: Math.round(8 * sourcesRoot.d)
                        Rectangle { implicitWidth: Math.round(4 * sourcesRoot.d); implicitHeight: Math.round(24 * sourcesRoot.d); radius: width / 2; color: IrisStyle.identity.red }
                        IrisText { Layout.fillWidth: true; elide: Text.ElideRight; text: Translation.tr("Dinner"); font.pixelSize: IrisStyle.typeMeta }
                        MaterialSymbol { visible: sourcesRoot.calendars; text: "cloud_sync"; iconSize: Math.round(15 * sourcesRoot.d); color: IrisStyle.textSecondary }
                    }
                    Column {
                        visible: source.index === 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: Math.round(6 * sourcesRoot.d)
                        Repeater {
                            model: sourcesRoot.gpu ? [0.42, 0.66] : [0.42]
                            Rectangle {
                                required property real modelData
                                width: parent.width; height: Math.round(6 * sourcesRoot.d); radius: height / 2; color: IrisStyle.fill
                                Rectangle { width: parent.width * parent.modelData * (source.fresh ? 1.12 : 1); height: parent.height; radius: height / 2; color: IrisStyle.identity.green
                                    Behavior on width { NumberAnimation { duration: IrisStyle.duration(400); easing.type: IrisStyle.feedbackEasing } } }
                            }
                        }
                    }
                    Rectangle {
                        visible: source.index === 3 && source.modelData.on
                        anchors.verticalCenter: parent.verticalCenter
                        width: updateText.implicitWidth + Math.round(18 * sourcesRoot.d)
                        height: Math.round(24 * sourcesRoot.d)
                        radius: height / 2
                        color: Qt.rgba(IrisStyle.identity.yellow.r, IrisStyle.identity.yellow.g, IrisStyle.identity.yellow.b, 0.2)
                        IrisText { id: updateText; anchors.centerIn: parent; text: Translation.tr("Ready to update"); font.pixelSize: IrisStyle.typeCaption; font.weight: Font.DemiBold }
                    }
                }
            }
        }
    }
    Caption {
        glyph: "cloud_sync"
        text: [sourcesRoot.weather ? Translation.tr("Weather on") : Translation.tr("Weather off"), sourcesRoot.vpn ? Translation.tr("VPN in quick controls") : "",
            sourcesRoot.updates ? Translation.tr("watching for new iNiR") : ""].filter(part => part.length > 0).join(" · ")
    }
}
