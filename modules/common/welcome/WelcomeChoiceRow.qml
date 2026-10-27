import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    readonly property var root: WelcomeHost.wizard
    id: choiceRow

    property string title: ""
    property string detail: ""
    property string symbol: "check"
    property string badge: ""
    property bool selected: false
    property bool compactRow: false

    Layout.fillWidth: true
    implicitHeight: compactRow ? 50 : (detail.length > 0 ? 76 : 52)
    buttonRadius: choiceRow.compactRow ? root.welcomeControlRadius : root.welcomeChoiceRadius
    colBackground: selected
        ? root.welcomeAccentContainer
        : "transparent"
    colBackgroundHover: selected
        ? root.welcomeAccentHover
        : root.welcomeSurfaceHigh
    colRipple: root.welcomeSurfaceHighest

    contentItem: Item {
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            radius: choiceRow.buttonRadius
            color: "transparent"
            border.width: choiceRow.selected ? 1 : 0
            border.color: ColorUtils.applyAlpha(root.welcomeAccent, 0.58)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 10

            Item {
                Layout.preferredWidth: choiceRow.compactRow ? 28 : 34
                Layout.preferredHeight: choiceRow.compactRow ? 28 : 34

                MaterialCookie {
                    anchors.centerIn: parent
                    visible: root.welcomeChoiceMark && choiceRow.selected && !choiceRow.compactRow
                    implicitSize: 32
                    sides: 8
                    color: ColorUtils.applyAlpha(root.welcomeSurfaceHighest, 0.96)
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: choiceRow.symbol
                    iconSize: choiceRow.compactRow ? 17 : 19
                    color: choiceRow.selected ? root.welcomeAccent : root.welcomeOnSurfaceVariant
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                WelcomeText {
                    Layout.fillWidth: true
                    text: choiceRow.title
                    font.family: root.welcomeFontTitle
                    font.pixelSize: choiceRow.compactRow
                        ? root.welcomeFontBody
                        : choiceRow.selected ? root.welcomeFontSection : root.welcomeFontBody
                    font.weight: choiceRow.selected ? Font.Bold : Font.Medium
                    color: choiceRow.selected ? root.welcomeOnAccentContainer : root.welcomeOnSurface
                    elide: Text.ElideRight
                }
                WelcomeText {
                    Layout.fillWidth: true
                    visible: choiceRow.detail.length > 0 && !choiceRow.compactRow
                    text: choiceRow.detail
                    font.pixelSize: root.welcomeFontCaption
                    color: choiceRow.selected
                        ? root.welcomeOnAccentContainer
                        : root.welcomeSecondaryText
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: choiceRow.badge.length > 0
                implicitWidth: badgeText.implicitWidth + 14
                implicitHeight: 24
                radius: 12
                color: root.welcomeGuideContainer

                WelcomeText {
                    id: badgeText
                    anchors.centerIn: parent
                    text: choiceRow.badge
                    font.pixelSize: root.welcomeFontMeta
                    font.weight: Font.Bold
                    color: root.welcomeGuideText
                }
            }

            MaterialSymbol {
                visible: choiceRow.selected
                text: "check"
                iconSize: 16
                color: root.welcomeOnAccentContainer
            }
        }
    }
}
