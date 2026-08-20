pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.barM3
import qs.modules.common
import qs.modules.common.widgets

// Compact tooltip shape: subtle outline, very small radius, and the plate grows
// from nothing instead of scaling. Colours come from iNiR's generated palette.
PopupToolTip {
    id: root

    delay: 400
    horizontalPadding: 10
    verticalPadding: 5
    horizontalMargin: 0
    verticalMargin: 0

    contentItem: Item {
        id: content
        property string text: root.text
        property bool shown: false

        implicitWidth: label.implicitWidth + root.horizontalPadding * 2
        implicitHeight: label.implicitHeight + root.verticalPadding * 2

        Rectangle {
            id: plate
            anchors.centerIn: parent
            clip: true
            color: M3Palette.tooltip
            border.width: 1
            border.color: M3Palette.outlineVariant
            radius: Appearance.rounding.verysmall
            opacity: content.shown ? 1 : 0
            implicitWidth: content.shown ? content.implicitWidth : 0
            implicitHeight: content.shown ? content.implicitHeight : 0

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on implicitHeight {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            StyledText {
                id: label
                anchors.centerIn: parent
                text: content.text
                color: M3Palette.tooltipForeground
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.hintingPreference: Font.PreferNoHinting
                wrapMode: Text.Wrap
            }
        }
    }
}
