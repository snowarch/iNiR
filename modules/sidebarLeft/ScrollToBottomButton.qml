import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    required property ListView target
    property bool compact: false

    anchors {
        bottom: parent.bottom
        horizontalCenter: root.compact ? undefined : parent.horizontalCenter
        right: root.compact ? parent.right : undefined
        rightMargin: root.compact ? 8 : 0
        bottomMargin: root.compact ? 8 : 10
    }

    opacity: !target.atYEnd ? 1 : 0
    scale: !target.atYEnd ? 1 : 0.7
    visible: opacity > 0
    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
    }
    Behavior on scale {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }

    implicitWidth: root.compact ? 32 : contentItem.implicitWidth + 8 * 2
    implicitHeight: root.compact ? 32 : contentItem.implicitHeight + 4 * 2
    rippleEnabled: !root.compact

    colBackground: root.compact ? Appearance.colors.colLayer1
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colSecondary
    colBackgroundHover: root.compact ? Appearance.colors.colLayer1
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryHover : Appearance.colors.colSecondaryHover
    colRipple: root.compact ? Appearance.colors.colLayer1Active
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryActive : Appearance.colors.colSecondaryActive
    buttonRadius: root.compact ? Appearance.rounding.small
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall

    downAction: () => {
        target.positionViewAtEnd()
    }

    contentItem: Item {
        implicitWidth: root.compact ? 18 : fullContent.implicitWidth
        implicitHeight: root.compact ? 18 : fullContent.implicitHeight

        MaterialSymbol {
            visible: root.compact
            anchors.centerIn: parent
            text: "arrow_downward"
            iconSize: 18
            color: Appearance.colors.colOnLayer1
        }

        Row {
            id: fullContent
            visible: !root.compact
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: "arrow_downward"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnSecondary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("Scroll to Bottom")
                font.pixelSize: Appearance.font.pixelSize.smallie
                color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimary : Appearance.colors.colOnSecondary
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
