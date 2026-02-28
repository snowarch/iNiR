import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ToolTip {
    id: root
    property bool extraVisibleCondition: true
    property bool alternativeVisibleCondition: false
    property string position: "bottom" // "bottom", "left", "right", "top"

    // Visibility logic:
    // - If parent has buttonHovered (RippleButton), use it
    // - Else if parent has hovered, use it  
    // - Else default to true (for components without hover tracking)
    readonly property bool parentHoverState: {
        if (parent.buttonHovered !== undefined) return parent.buttonHovered
        if (parent.hovered !== undefined) return parent.hovered
        return true  // Default: show tooltip if no hover property exists
    }
    readonly property bool internalVisibleCondition: (extraVisibleCondition && parentHoverState) || alternativeVisibleCondition
    verticalPadding: 5
    horizontalPadding: 10
    background: null
    font {
        family: Appearance.font.family.main
        variableAxes: Appearance.font.variableAxes.main
        pixelSize: Appearance?.font.pixelSize.smaller ?? 14
        hintingPreference: Font.PreferNoHinting // Prevent shaky text
    }

    visible: internalVisibleCondition

    onVisibleChanged: {
        if (visible) {
            contentItem.shown = false
            _showTimer.restart()
        } else {
            contentItem.shown = false
        }
    }

    Timer {
        id: _showTimer
        interval: 16
        onTriggered: contentItem.shown = true
    }
    
    // Position offsets based on position property
    x: {
        if (position === "left") return -width - 8
        if (position === "right") return parent.width + 8
        return (parent.width - width) / 2  // center for top/bottom
    }
    y: {
        if (position === "top") return -height - 4
        if (position === "left" || position === "right") return (parent.height - height) / 2
        return parent.height + 4  // bottom default
    }

    contentItem: StyledToolTipContent {
        id: contentItem
        font: root.font
        text: root.text
        shown: false
        horizontalPadding: root.horizontalPadding
        verticalPadding: root.verticalPadding
    }
}
