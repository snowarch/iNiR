import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    required property string label
    required property string colorKey
    property string contrastAgainst: ""  // Key to check contrast against (e.g., "m3background")
    signal colorChanged()

    property color currentColor: Config.options?.appearance?.customTheme?.[colorKey] ?? "#888888"
    property color bgColor: contrastAgainst ? (Config.options?.appearance?.customTheme?.[contrastAgainst] ?? "#000000") : "#000000"
    property real ratio: contrastAgainst ? ColorUtils.contrastRatio(currentColor, bgColor) : 0
    property bool showContrast: contrastAgainst !== ""

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 4

        RowLayout {
            spacing: 4

            StyledText {
                text: root.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }

            // Contrast indicator
            Rectangle {
                visible: root.showContrast
                implicitWidth: contrastRow.implicitWidth + 6
                implicitHeight: 16
                radius: 8
                color: root.ratio >= 4.5 ? Appearance.colors.colSuccessContainer ?? "#1a3a1a"
                     : root.ratio >= 3 ? Appearance.colors.colWarningContainer ?? "#3a3a1a"
                     : Appearance.colors.colErrorContainer ?? "#3a1a1a"

                RowLayout {
                    id: contrastRow
                    anchors.centerIn: parent
                    spacing: 2

                    MaterialSymbol {
                        text: root.ratio >= 4.5 ? "check" : "warning"
                        iconSize: 10
                        color: root.ratio >= 4.5 ? Appearance.colors.colOnSuccessContainer ?? "#a8d8a8"
                             : root.ratio >= 3 ? Appearance.colors.colOnWarningContainer ?? "#d8d8a8"
                             : Appearance.colors.colOnErrorContainer ?? "#d8a8a8"
                    }

                    StyledText {
                        text: root.ratio.toFixed(1) + ":1"
                        font.pixelSize: 9
                        font.family: Appearance.font.family.monospace
                        color: root.ratio >= 4.5 ? Appearance.colors.colOnSuccessContainer ?? "#a8d8a8"
                             : root.ratio >= 3 ? Appearance.colors.colOnWarningContainer ?? "#d8d8a8"
                             : Appearance.colors.colOnErrorContainer ?? "#d8a8a8"
                    }
                }

                StyledToolTip {
                    text: root.ratio >= 4.5 ? Translation.tr("WCAG AA ✓")
                        : root.ratio >= 3 ? Translation.tr("Low contrast")
                        : Translation.tr("Poor contrast - hard to read")
                }
            }
        }

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 36
            colBackground: Appearance.colors.colLayer2
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: root.currentColor
                    border.width: 1
                    border.color: Appearance.colors.colOutline
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.currentColor.toString().toUpperCase().substring(0, 7)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.monospace
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: "edit"
                    iconSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            onClicked: colorDialog.open()
        }
    }

    ColorDialog {
        id: colorDialog
        selectedColor: root.currentColor
        onAccepted: {
            Config.setNestedValue("appearance.customTheme." + root.colorKey, selectedColor.toString())
            root.colorChanged()
        }
    }
}
