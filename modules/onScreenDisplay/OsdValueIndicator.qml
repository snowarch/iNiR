import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false

    readonly property bool _zzz: Appearance.zzzEverywhere

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 20

    implicitWidth: Appearance.sizes.osdWidth + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow {
        target: valueIndicator
        visible: !root._zzz
    }
    GlassBackground {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: root._zzz ? Appearance.zzz.panelRadius : Appearance.rounding.full
        fallbackColor: root._zzz ? Appearance.zzz.bg0 : Appearance.colors.colLayer0
        inirColor: Appearance.inir.colLayer1
        auroraTransparency: Appearance.aurora.popupTransparentize
        border.width: root._zzz || auroraEverywhere || inirEverywhere ? 1 : 0
        border.color: root._zzz ? Appearance.zzz.borderColor
            : Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : Appearance.colors.colLayer0Border

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout {
            id: valueRow
            Layout.margins: 10
            anchors.fill: parent
            spacing: 10

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                CookieFace {
                    anchors.fill: parent
                    visible: Appearance.cookieEverywhere
                    role: "badge"
                    color: Appearance.colors.colPrimaryContainer
                }

                MaterialSymbol {
                    anchors {
                        centerIn: parent
                        alignWhenCentered: !root.rotateIcon
                    }
                    color: root._zzz ? Appearance.zzz.onColor
                        : Appearance.cookieEverywhere
                            ? Appearance.colors.colOnPrimaryContainer
                            : Appearance.colors.colOnLayer0

                    text: root.icon
                    iconSize: 20 + 10 * (root.scaleIcon ? value : 1)
                    rotation: 180 * (root.rotateIcon ? value : 0)

                    Behavior on iconSize {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                    }
                    Behavior on rotation {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                    }
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout {
                    Layout.leftMargin: root._zzz ? 0 : valueProgressBar.height / 2
                    Layout.rightMargin: root._zzz ? 0 : valueProgressBar.height / 2
                    spacing: 8

                    StyledText {
                        color: root._zzz ? Appearance.zzz.onColor : Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: root._zzz ? Font.Bold : Font.Normal
                        text: root._zzz ? root.name.toUpperCase() : root.name
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        color: root._zzz ? Appearance.zzz.accent : Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: root._zzz ? Font.Black : Font.Normal
                        Layout.fillWidth: false
                        text: Math.round(root.value * 100)
                    }
                }

                StyledProgressBar {
                    id: valueProgressBar
                    Layout.fillWidth: true
                    value: root.value
                }
            }
        }
    }
}
