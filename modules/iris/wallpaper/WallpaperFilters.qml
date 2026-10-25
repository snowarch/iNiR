pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

// What the web is asked for besides the words: the shape, how far back Top rated looks, and (Wallhaven) one colour.
Flow {
    id: root

    required property var engine
    readonly property real d: IrisStyle.density

    spacing: Math.round(10 * root.d)

    IrisSegmented {
        visible: root.engine.filtersShaped
        glyphOnly: true
        implicitHeight: Math.round(32 * root.d)
        accessibleName: Translation.tr("Shape")
        options: root.engine.ratioChoices
        current: root.engine.ratio
        onPicked: value => root.engine.setRatio(value)
    }
    IrisSegmented {
        visible: root.engine.ranged
        implicitHeight: Math.round(32 * root.d)
        implicitWidth: Math.max(Math.round(58 * root.d) * 4 + 2 * inset, fitWidth)
        accessibleName: Translation.tr("Top of the")
        options: root.engine.rangeChoices
        current: root.engine.topRange
        onPicked: value => root.engine.setRange(value)
    }
    // Wallhaven's colours: first the shell's own accents (asked for as the nearest of its 29), then the 29 as paint.
    Row {
        id: colours
        visible: root.engine.provider === "wallhaven" || root.engine.colour.length > 0
        height: Math.round(32 * root.d)
        spacing: Math.round(10 * root.d)
        Rectangle {
            anchors.verticalCenter: colours.verticalCenter
            width: yours.implicitWidth + Math.round(20 * root.d)
            height: Math.round(32 * root.d)
            radius: IrisStyle.capsule(height)
            color: IrisStyle.fillQuiet
            Row {
                id: yours
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                MaterialSymbol {
                    anchors.verticalCenter: yours.verticalCenter
                    text: "palette"
                    iconSize: Math.round(16 * root.d)
                    color: IrisStyle.subtext
                }
                Repeater {
                    model: [{ colour: IrisStyle.accent, label: Translation.tr("Accent") },
                        { colour: IrisStyle.secondaryAccent, label: Translation.tr("Secondary accent") }]
                    MouseArea {
                        id: accentKey
                        required property var modelData
                        readonly property string hex: root.engine.nearestColour(accentKey.modelData.colour)
                        readonly property bool chosen: root.engine.colour === accentKey.hex
                        anchors.verticalCenter: yours.verticalCenter
                        width: Math.round(22 * root.d)
                        height: width
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: accentKey.modelData.label
                        onClicked: root.engine.setColour(accentKey.hex)
                        Rectangle {
                            anchors.centerIn: parent
                            width: accentKey.chosen || accentKey.containsMouse ? parent.width : Math.round(18 * root.d)
                            height: width
                            radius: width / 2
                            color: accentKey.modelData.colour
                            border.width: accentKey.chosen ? Math.round(2 * root.d) : 0
                            border.color: IrisStyle.onMedia
                            Behavior on width { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                        }
                    }
                }
            }
        }
        Repeater {
            model: root.engine.colourRuns
            WallpaperSpectrum {
                required property var modelData
                anchors.verticalCenter: colours.verticalCenter
                engine: root.engine
                stops: modelData.stops
                name: modelData.label
            }
        }
    }
    IrisChip {
        visible: root.engine.filtersOn > 0
        glyph: "filter_alt_off"
        label: Translation.tr("Clear")
        quiet: true
        onClicked: root.engine.clearFilters()
    }
}
