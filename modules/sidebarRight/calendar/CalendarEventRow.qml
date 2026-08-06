pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts

// Compact event row for calendar views.
// Used in upcoming events list and day detail view.
// Supports both local (Events service) and external (CalendarSync) events.
Item {
    id: root

    required property var event
    property bool showDate: false
    property bool interactive: true

    signal clicked()

    implicitHeight: eventRow.implicitHeight + 10
    implicitWidth: parent?.width ?? 200

    readonly property bool isExternal: (root.event?.source ?? "local") === "external"
    readonly property bool isAllDay: root.event?.allDay ?? false
    readonly property color dotColor: {
        if (root.isExternal) return root.event?.sourceColor ?? colPrimary
        // Local events use priority color
        switch (root.event?.priority ?? "normal") {
            case "high": return colError
            case "low": return colSubtext
            default: return colPrimary
        }
    }

    // Style tokens
    readonly property color colPrimary: Appearance.zzzEverywhere ? Appearance.zzz.accent
        : Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colText: Appearance.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colError: Appearance.angelEverywhere ? Appearance.angel.colError
        : Appearance.inirEverywhere ? (Appearance.inir?.colError ?? Appearance.colors.colError)
        : Appearance.colors.colError
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1
    readonly property color colCardHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colSubSurface ?? Appearance.colors.colLayer1Hover)
        : Appearance.colors.colLayer1Hover
    readonly property real cardRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.cardRadius
        color: eventMA.containsMouse && root.interactive ? root.colCardHover : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            id: eventRow
            anchors.fill: parent
            anchors.margins: 5
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 10

            // Source color indicator
            Rectangle {
                Layout.preferredWidth: 4
                Layout.preferredHeight: parent.height - 8
                Layout.alignment: Qt.AlignVCenter
                radius: 2
                color: root.dotColor
            }

            // Event info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    text: root.event?.title ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: root.colText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Source name for external events, or description for local
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (root.isExternal) return root.event?.sourceName ?? ""
                        return root.event?.description ?? ""
                    }
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            // Time display
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: {
                    if (root.isAllDay) return Translation.tr("All day")
                    const d = new Date(root.event?.startDate ?? root.event?.dateTime ?? "")
                    if (isNaN(d.getTime())) return ""
                    if (root.showDate) {
                        const now = new Date()
                        const tomorrow = new Date(now)
                        tomorrow.setDate(tomorrow.getDate() + 1)
                        if (d.toDateString() === now.toDateString())
                            return Translation.tr("Today") + " " + Qt.formatTime(d, "HH:mm")
                        if (d.toDateString() === tomorrow.toDateString())
                            return Translation.tr("Tomorrow") + " " + Qt.formatTime(d, "HH:mm")
                        return Qt.formatDate(d, "dd/MM") + " " + Qt.formatTime(d, "HH:mm")
                    }
                    return Qt.formatTime(d, "HH:mm")
                }
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.numbers
                color: root.colSubtext
            }
        }

        MouseArea {
            id: eventMA
            anchors.fill: parent
            hoverEnabled: root.interactive
            cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.interactive) root.clicked()
        }
    }
}
