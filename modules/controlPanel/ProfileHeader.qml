pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root
    implicitHeight: 56
    Layout.fillWidth: true
    
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere

    function getGreeting(): string {
        const hour = new Date().getHours()
        if (hour < 5) return Translation.tr("Good Night")
        if (hour < 12) return Translation.tr("Good Morning")
        if (hour < 18) return Translation.tr("Good Afternoon")
        return Translation.tr("Good Evening")
    }

    RowLayout {
        anchors.fill: parent
        spacing: 12

        // Avatar - themed circle with border using OpacityMask
        Item {
            id: avatarContainer
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48

            // Border ring
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                            : root.inirEverywhere ? Appearance.inir.colPrimary 
                            : root.auroraEverywhere ? Appearance.m3colors.m3primary
                            : Appearance.colors.colPrimary
            }

            // Avatar with OpacityMask for proper circular clipping
            Item {
                anchors.centerIn: parent
                width: 42
                height: 42

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: `file://${Directories.userAvatarPathRicersAndWeirdSystems}`
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    sourceSize.width: 84
                    sourceSize.height: 84
                    visible: false
                    
                    onStatusChanged: {
                        if (status === Image.Error) {
                            source = `file://${Directories.userAvatarPathAccountsService}`
                        }
                    }
                }

                GE.OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }
                
                // Fallback
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                         : root.inirEverywhere ? Appearance.inir.colLayer2 
                         : root.auroraEverywhere ? Appearance.aurora.colSubSurface
                         : Appearance.colors.colLayer2
                    visible: avatarImg.status !== Image.Ready

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "person"
                        iconSize: 22
                        color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                             : root.inirEverywhere ? Appearance.inir.colPrimary 
                             : root.auroraEverywhere ? Appearance.m3colors.m3primary
                             : Appearance.colors.colPrimary
                    }
                }
            }
        }

        // Text
        ColumnLayout {
            spacing: 0
            StyledText {
                text: root.getGreeting()
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                     : root.inirEverywhere ? Appearance.inir.colPrimary 
                     : root.auroraEverywhere ? Appearance.m3colors.m3primary
                     : Appearance.colors.colPrimary
            }
            StyledText {
                text: SystemInfo.username
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                font.capitalization: Font.Capitalize
                color: Appearance.angelEverywhere ? Appearance.angel.colText
                     : root.inirEverywhere ? Appearance.inir.colText 
                     : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                     : Appearance.colors.colOnLayer0
            }
        }

        Item { Layout.fillWidth: true }

        // Action Buttons
        RowLayout {
            spacing: 4

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                  : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                                  : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                  : Appearance.colors.colLayer2Hover
                onClicked: {
                    GlobalStates.controlPanelOpen = false
                    lockProc.running = true
                }
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "lock"
                    iconSize: 18
                    color: Appearance.angelEverywhere ? Appearance.angel.colText
                         : root.inirEverywhere ? Appearance.inir.colText 
                         : root.auroraEverywhere ? Appearance.m3colors.m3onSurface
                         : Appearance.colors.colOnLayer0
                }
                StyledToolTip { text: Translation.tr("Lock") }
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                  : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                                  : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                  : Appearance.colors.colLayer2Hover
                onClicked: {
                    GlobalStates.controlPanelOpen = false
                    GlobalStates.sessionOpen = true
                }
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    iconSize: 18
                    color: root.inirEverywhere ? Appearance.inir.colError ?? Appearance.colors.colError
                         : root.auroraEverywhere ? Appearance.m3colors.m3error
                         : Appearance.colors.colError 
                }
                StyledToolTip { text: Translation.tr("Power") }
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                            : root.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.full
                colBackground: "transparent"
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                  : root.inirEverywhere ? Appearance.inir.colLayer2Hover 
                                  : root.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                                  : Appearance.colors.colLayer2Hover
                onClicked: GlobalStates.controlPanelOpen = false
                contentItem: MaterialSymbol { 
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 18
                    color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                         : root.inirEverywhere ? Appearance.inir.colTextSecondary 
                         : root.auroraEverywhere ? Appearance.m3colors.m3outline
                         : Appearance.colors.colSubtext
                }
                StyledToolTip { text: Translation.tr("Close") }
            }
        }
    }

    Process {
        id: lockProc
        command: ["/usr/bin/qs", "-c", "ii", "ipc", "call", "lock", "activate"]
    }
}
