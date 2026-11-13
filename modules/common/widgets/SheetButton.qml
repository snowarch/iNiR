import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// A sheet's button in the family's colours: a pill with a label (`strong` fills it with the accent), or a glyph.
MouseArea {
    id: button
    readonly property real s: FamilyStyle.density
    property string glyph: ""
    property string label: ""
    property string tip: ""
    property bool strong: false
    property bool toggled: false
    readonly property bool buttonHovered: button.containsMouse
    implicitHeight: Math.round(34 * button.s)
    implicitWidth: button.label.length > 0 ? buttonLabel.implicitWidth + Math.round(32 * button.s) : implicitHeight
    hoverEnabled: true
    cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    opacity: button.enabled ? 1 : 0.4
    Accessible.role: Accessible.Button
    Accessible.name: button.label.length > 0 ? button.label : button.tip
    Rectangle {
        anchors.fill: parent
        radius: button.label.length > 0 ? height / 2 : FamilyStyle.radiusRow
        color: button.strong ? (button.containsMouse ? Qt.lighter(FamilyStyle.accent, 1.08) : FamilyStyle.accent)
            : button.toggled ? ColorUtils.applyAlpha(FamilyStyle.accent, 0.18)
            : button.containsMouse ? FamilyStyle.fillHover : button.label.length > 0 ? FamilyStyle.fillQuiet : "transparent"
        Behavior on color { ColorAnimation { duration: FamilyStyle.feedbackDuration } }
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: button.glyph.length > 0
        text: button.glyph
        iconSize: Math.round(18 * button.s)
        color: button.toggled ? FamilyStyle.accent : FamilyStyle.textSecondary
    }
    StyledText {
        id: buttonLabel
        anchors.centerIn: parent
        visible: button.label.length > 0
        text: button.label
        color: button.strong ? FamilyStyle.inkOnAccent : FamilyStyle.textStrong
        font.family: FamilyStyle.fontMain
        font.pixelSize: FamilyStyle.typeMeta
        font.weight: Font.DemiBold
    }
    StyledToolTip {
        text: button.tip
    }
}
