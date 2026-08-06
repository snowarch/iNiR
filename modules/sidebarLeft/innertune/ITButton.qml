import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// InnerTune Material 3 button (Button.kt) — pill with a leading icon + label and one of four
// M3 variants. State-layer feedback on hover/press; all colors from m3 tokens.
//   filled   → primary container, onPrimary content (the main action: Play / Sign in)
//   tonal    → secondaryContainer, onSecondaryContainer content
//   outlined → transparent + m3outline border, primary content (the secondary action: Shuffle)
//   text     → transparent, primary content (low-emphasis: Cancel)
Item {
    id: root
    property string kind: "filled"   // filled | tonal | outlined | text
    property string icon: ""
    property string label: ""
    property bool enabled: true

    signal clicked()

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 40

    readonly property color _bg: kind === "filled" ? Appearance.colors.colPrimary
        : kind === "tonal" ? Appearance.colors.colSecondaryContainer
        : "transparent"
    readonly property color _fg: !root.enabled ? Appearance.colors.colOutline
        : kind === "filled" ? Appearance.colors.colOnPrimary
        : kind === "tonal" ? Appearance.colors.colOnSecondaryContainer
        : Appearance.colors.colPrimary

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root._bg
        border.width: root.kind === "outlined" ? 1 : 0
        border.color: Appearance.colors.colOutline
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    // M3 state layer (hover/press) over the button surface.
    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.full
        color: root._fg
        opacity: !root.enabled ? 0 : (mouse.pressed ? 0.12 : (mouse.containsMouse ? 0.08 : 0))
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MaterialSymbol {
            visible: root.icon !== ""
            text: root.icon
            iconSize: Appearance.font.pixelSize.larger
            color: root._fg
            fill: 1
        }
        StyledText {
            text: root.label
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
            color: root._fg
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
