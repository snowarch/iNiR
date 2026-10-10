import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Shapes

// A slanted plate: the skew deck's control. Leans like the cards; accent when active.
Item {
    id: root

    property string label: ""
    property string icon: ""
    property bool active: false
    // Secondary entries (subfolders) sit lighter on the preview
    property bool muted: false
    property int slant: Math.round(height * 0.3)
    readonly property bool hovered: chipMouse.containsMouse
    signal clicked()

    readonly property bool editorial: Appearance.editorialEverywhere
    readonly property color plateColor: editorial ? Appearance.editorial.ink
        : ColorUtils.applyAlpha(Appearance.colors.colLayer2, muted ? 0.62 : 0.9)
    readonly property color plateHoverColor: editorial ? ColorUtils.mix(Appearance.editorial.ink, Appearance.editorial.accent, 0.8)
        : ColorUtils.applyAlpha(Appearance.colors.colLayer2Hover, 0.95)
    readonly property color plateInk: editorial ? Appearance.editorial.paperOnInk : Appearance.colors.colOnLayer2
    readonly property color accentColor: editorial ? Appearance.editorial.accent : Appearance.colors.colPrimary
    readonly property color accentInk: editorial ? Appearance.editorial.accentInk : Appearance.colors.colOnPrimary
    readonly property color ink: active ? accentInk : plateInk

    implicitHeight: 36
    implicitWidth: contentRow.implicitWidth + slant + 28

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.active ? root.accentColor : root.hovered ? root.plateHoverColor : root.plateColor
            strokeColor: "transparent"
            Behavior on fillColor {
                enabled: Appearance.animationsEnabled
                ColorAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
            startX: root.slant; startY: 0
            PathLine { x: root.width;              y: 0 }
            PathLine { x: root.width - root.slant; y: root.height }
            PathLine { x: 0;                       y: root.height }
            PathLine { x: root.slant;              y: 0 }
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 6

        MaterialSymbol {
            visible: root.icon.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            fill: root.active ? 1 : 0
            color: root.ink
            opacity: root.muted && !root.hovered ? 0.8 : 1
        }
        StyledText {
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.ink
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: root.active ? Font.DemiBold : Font.Medium
            opacity: root.muted && !root.hovered ? 0.85 : 1
        }
    }

    MouseArea {
        id: chipMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
