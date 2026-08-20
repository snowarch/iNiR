import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import qs.modules.common.functions

Item {
    id: root
    signal clicked(event: var)
    property alias iconText: symbol.text
    property bool isActive: false
    property bool forceHovered: false
    property string toolTipText: ""
    property bool isMaterial: Config.options.bar.m3.cornerStyle === 3

    implicitWidth: vertical ? 26 : (hovered ? 54 : 26)
    implicitHeight: vertical ? (hovered ? 54 : 26) : 26

    property bool hovered: mouseArea.containsMouse || forceHovered

    // iNiR's motion tokens expose `type` + `bezierCurve`; upstream read a
    // non-existent `easing`, which left the curve undefined.
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root.hovered ? M3Palette.primary : "transparent"

        Behavior on color {
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on opacity {
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        MaterialSymbol {
            id: symbol
            anchors.centerIn: parent
            iconSize: Appearance.font.pixelSize.large
            color: root.hovered
                ? M3Palette.primaryForeground
                : root.isMaterial ? M3Palette.pillInk("utilButtons") : Appearance.colors.colPrimary

            Behavior on color {
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (e) => root.clicked(e)
    }

    M3ToolTip {
        text: root.toolTipText
        extraVisibleCondition: root.toolTipText.length > 0 && mouseArea.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: Config.options?.bar?.bottom ?? false ? Edges.Top : Edges.Bottom
    }
}
