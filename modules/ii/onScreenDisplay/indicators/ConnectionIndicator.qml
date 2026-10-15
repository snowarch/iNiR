pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property var event: DeviceEvents.last
    readonly property string tone: root.event?.tone ?? "on"
    readonly property color accent: root.tone === "warn" ? Appearance.colors.colError
        : root.tone === "off" ? Appearance.colors.colSubtext
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colAccent
        : Appearance.colors.colPrimary
    readonly property color ink: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer0

    implicitWidth: Math.max(Appearance.sizes.osdWidth, Math.min(420, contentRow.implicitWidth + contentRow.anchors.leftMargin + contentRow.anchors.rightMargin))
        + 2 * Appearance.sizes.elevationMargin
    implicitHeight: card.implicitHeight + 2 * Appearance.sizes.elevationMargin
    clip: true

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.editorialEverywhere ? Appearance.editorial.radius : Appearance.rounding.full
        color: Appearance.angelEverywhere ? Appearance.angel.colGlassPopup
             : Appearance.inirEverywhere ? Appearance.inir.colLayer1
             : Appearance.auroraEverywhere ? Appearance.aurora.colPopupSurface
             : Appearance.colors.colLayer0
        border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
            : Appearance.auroraEverywhere || Appearance.inirEverywhere ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder
            : Appearance.auroraEverywhere ? Appearance.aurora.colTooltipBorder : "transparent"
        implicitHeight: contentRow.implicitHeight + contentRow.anchors.topMargin + contentRow.anchors.bottomMargin

        RowLayout {
            id: contentRow
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 20
                topMargin: 9
                bottomMargin: 9
            }
            spacing: 12

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                CookieFace {
                    anchors.fill: parent
                    visible: Appearance.cookieEverywhere
                    role: "badge"
                    selected: root.tone === "on"
                    color: Appearance.colors.colPrimaryContainer
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.event?.icon ?? "link"
                    iconSize: Appearance.font.pixelSize.hugeass
                    fill: 1
                    color: Appearance.cookieEverywhere ? Appearance.colors.colOnPrimaryContainer : root.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.event?.title ?? ""
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: root.ink
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.event?.detail ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            StyledText {
                visible: (root.event?.value ?? -1) >= 0
                text: (root.event?.value ?? 0) + "%"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
                color: Appearance.colors.colSubtext
            }
        }
    }
}
