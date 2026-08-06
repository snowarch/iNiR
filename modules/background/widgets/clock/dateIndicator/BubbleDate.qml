pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick

Item {
    id: root
    property bool isMonth: false
    property real targetSize: 0
    property alias text: bubbleText.text

    text: Qt.locale().toString(DateTime.clock.date, root.isMonth ? "MM" : "d")

    // These bubbles sit at the clock corners over bare wallpaper with no plate. A soft
    // contact shadow (the shell's own shadow vocabulary) detaches them from any
    // wallpaper and matches the edge of every other desktop widget.
    readonly property color bubbleColor: root.isMonth ? Appearance.colors.colSecondaryContainer : Appearance.colors.colTertiaryContainer

    StyledDropShadow {
        target: bubble
        visible: !Appearance.zzzEverywhere
    }

    MaterialShape {
        id: bubble
        z: 5
        // sides: root.isMonth ? 1 : 4
        shape: root.isMonth ? MaterialShape.Shape.Pill : MaterialShape.Shape.Pentagon
        anchors.centerIn: parent
        color: root.bubbleColor
        implicitSize: targetSize
    }

    StyledText {
        id: bubbleText
        z: 6
        anchors.centerIn: parent
        color: root.isMonth ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnTertiaryContainer
        font {
            family: Config.getNestedValue("background.widgets.clock.fontFamily", "Space Grotesk")
            pixelSize: 30
            weight: Font.Black
        }
    }
}