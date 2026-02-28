pragma ComponentBehavior: Bound
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root
    
    required property var event
    signal removeClicked()
    signal editClicked(var event)
    
    implicitHeight: cardContent.implicitHeight + 16
    
    // Style tokens
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colSubtext: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colError: Appearance.angelEverywhere ? Appearance.angel.colError
        : Appearance.inirEverywhere ? (Appearance.inir?.colError ?? Appearance.m3colors.m3error)
        : Appearance.m3colors.m3error
    readonly property color colBadge: Appearance.angelEverywhere ? Appearance.angel.colBorderSubtle
        : Appearance.inirEverywhere ? ColorUtils.transparentize(Appearance.inir.colBorder, 0.5)
        : Appearance.auroraEverywhere ? (Appearance.aurora?.colSubSurface ?? Appearance.colors.colLayer2)
        : Appearance.colors.colLayer2

    readonly property color priorityColor: {
        switch (root.event?.priority ?? "normal") {
            case "high": return root.colError
            case "low": return root.colSubtext
            default: return root.colPrimary
        }
    }
    readonly property date eventDate: new Date(event.dateTime)
    readonly property bool isToday: {
        const now = new Date()
        const evtDate = new Date(event.dateTime)
        return now.toDateString() === evtDate.toDateString()
    }
    readonly property bool isPast: new Date(event.dateTime) < new Date()
    
    StyledRectangularShadow {
        target: cardBg
        visible: !Appearance.inirEverywhere && !Appearance.auroraEverywhere
    }
    
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
            : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
            : Appearance.rounding.small
        color: {
            if (editMA.containsMouse) {
                if (Appearance.angelEverywhere) return Appearance.angel.colGlassCardHover
                if (Appearance.inirEverywhere) return Appearance.inir.colLayer1Hover
                if (Appearance.auroraEverywhere) return Appearance.aurora?.colSubSurface ?? Appearance.colors.colLayer1Hover
                return Appearance.colors.colLayer1Hover
            }
            if (Appearance.angelEverywhere) return Appearance.angel.colGlassCard
            if (Appearance.inirEverywhere) return Appearance.inir.colLayer1
            if (Appearance.auroraEverywhere) return Appearance.aurora?.colSubSurface ?? Appearance.colors.colLayer1
            return Appearance.colors.colLayer1
        }
        border.width: (Appearance.inirEverywhere || Appearance.angelEverywhere) ? 1 : 0
        border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
            : Appearance.inirEverywhere ? Appearance.inir.colBorder : "transparent"
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        
        // Priority indicator bar
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 4
            radius: parent.radius
            color: root.priorityColor
        }
        
        RowLayout {
            id: cardContent
            anchors.fill: parent
            anchors.margins: 12
            anchors.leftMargin: 16
            spacing: 12
            
            // Category icon
            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 20
                color: ColorUtils.transparentize(root.priorityColor, 0.85)
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: Events.getCategoryIcon(root.event.category)
                    iconSize: 20
                    color: root.priorityColor
                }
            }
            
            // Event info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                
                StyledText {
                    Layout.fillWidth: true
                    text: root.event.title
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.inirEverywhere ? Appearance.inir.colText
                        : Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                
                StyledText {
                    Layout.fillWidth: true
                    visible: root.event.description && root.event.description !== ""
                    text: root.event.description
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
                        : Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                        : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }
                
                RowLayout {
                    spacing: 8
                    
                    // Date/time badge
                    Rectangle {
                        implicitHeight: dateTimeRow.implicitHeight + 6
                        implicitWidth: dateTimeRow.implicitWidth + 10
                        radius: height / 2
                        color: root.isToday 
                            ? ColorUtils.transparentize(root.colPrimary, 0.85)
                            : root.colBadge
                        
                        RowLayout {
                            id: dateTimeRow
                            anchors.centerIn: parent
                            spacing: 4
                            
                            MaterialSymbol {
                                text: "schedule"
                                iconSize: 12
                                color: root.isToday ? root.colPrimary : root.colSubtext
                            }
                            
                            StyledText {
                                text: {
                                    if (root.isToday) return Translation.tr("Today") + " " + Qt.formatTime(root.eventDate, "HH:mm")
                                    const now = new Date()
                                    const tomorrow = new Date(now)
                                    tomorrow.setDate(tomorrow.getDate() + 1)
                                    if (root.eventDate.toDateString() === tomorrow.toDateString()) {
                                        return Translation.tr("Tomorrow") + " " + Qt.formatTime(root.eventDate, "HH:mm")
                                    }
                                    return Qt.formatDate(root.eventDate, "dd/MM") + " " + Qt.formatTime(root.eventDate, "HH:mm")
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: root.isToday ? root.colPrimary : root.colSubtext
                            }
                        }
                    }
                    
                    // Category badge
                    Rectangle {
                        implicitHeight: categoryText.implicitHeight + 6
                        implicitWidth: categoryText.implicitWidth + 12
                        radius: height / 2
                        color: root.colBadge
                        
                        StyledText {
                            id: categoryText
                            anchors.centerIn: parent
                            text: {
                                switch (root.event.category) {
                                    case "birthday": return Translation.tr("Birthday")
                                    case "meeting": return Translation.tr("Meeting")
                                    case "deadline": return Translation.tr("Deadline")
                                    case "reminder": return Translation.tr("Reminder")
                                    default: return Translation.tr("General")
                                }
                            }
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: root.colSubtext
                        }
                    }
                }
            }
            
            // Remove button
            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.colors.colLayer1Hover
                onClicked: root.removeClicked()
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: root.colSubtext
                }
                
                StyledToolTip {
                    text: Translation.tr("Remove")
                }
            }
        }
        
        AngelPartialBorder {
            targetRadius: cardBg.radius
            visible: Appearance.angelEverywhere
        }
        
        // Click to edit
        MouseArea {
            id: editMA
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editClicked(root.event)
        }
    }
}
