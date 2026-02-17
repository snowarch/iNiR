import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "root:services"

Item {
    id: root
    
    property int currentTab: 0  // 0: Schedule, 1: Seasonal, 2: Top
    property string selectedDay: "today"
    
    readonly property var daysList: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    readonly property string todayName: Qt.formatDate(new Date(), "dddd").toLowerCase()
    
    onFocusChanged: (focus) => {
        if (focus) {
            listView.forceActiveFocus()
        }
    }
    
    Component.onCompleted: {
        AnimeService.fetchSchedule("today")
    }
    
    function getCurrentData() {
        switch (root.currentTab) {
            case 0: return AnimeService.schedule
            case 1: return AnimeService.seasonalAnime
            case 2: return AnimeService.topAiring
            default: return []
        }
    }
    
    function refreshCurrentTab() {
        switch (root.currentTab) {
            case 0: 
                AnimeService.fetchSchedule(root.selectedDay)
                break
            case 1: 
                AnimeService.fetchSeasonalAnime()
                break
            case 2: 
                AnimeService.fetchTopAiring()
                break
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        // Tab selector with proper theming
        ButtonGroup {
            id: tabGroup
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            property int clickIndex: -1
            
            GroupButton {
                buttonText: Translation.tr("Schedule")
                toggled: root.currentTab === 0
                bounce: true
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? "transparent"
                    : Appearance.colors.colLayer1
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer1Hover
                colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                    : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colSecondaryContainerHover
                onClicked: {
                    tabGroup.clickIndex = 0
                    root.currentTab = 0
                    if (AnimeService.schedule.length === 0) {
                        AnimeService.fetchSchedule(root.selectedDay)
                    }
                }
            }
            GroupButton {
                buttonText: Translation.tr("Seasonal")
                toggled: root.currentTab === 1
                bounce: true
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? "transparent"
                    : Appearance.colors.colLayer1
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer1Hover
                colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                    : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colSecondaryContainerHover
                onClicked: {
                    tabGroup.clickIndex = 1
                    root.currentTab = 1
                    if (AnimeService.seasonalAnime.length === 0) {
                        AnimeService.fetchSeasonalAnime()
                    }
                }
            }
            GroupButton {
                buttonText: Translation.tr("Top")
                toggled: root.currentTab === 2
                bounce: true
                colBackground: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? "transparent"
                    : Appearance.colors.colLayer1
                colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer1Hover
                colBackgroundToggled: Appearance.angelEverywhere ? Appearance.angel.colGlassElevated
                    : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                    : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                    : Appearance.colors.colSecondaryContainerHover
                onClicked: {
                    tabGroup.clickIndex = 2
                    root.currentTab = 2
                    if (AnimeService.topAiring.length === 0) {
                        AnimeService.fetchTopAiring()
                    }
                }
            }
        }
        
        // Day selector (only for Schedule tab)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.currentTab === 0 ? dayGroup.implicitHeight : 0
            clip: true
            visible: Layout.preferredHeight > 0
            
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            ButtonGroup {
                id: dayGroup
                spacing: 2
                property int clickIndex: -1
                
                Repeater {
                    model: root.daysList
                    delegate: GroupButton {
                        required property string modelData
                        required property int index
                        
                        property bool isToday: modelData === root.todayName
                        property bool isSelected: (root.selectedDay === "today" && isToday) || root.selectedDay === modelData
                        
                        buttonText: modelData.charAt(0).toUpperCase() + modelData.slice(1, 3)
                        toggled: isSelected
                        bounce: true
                        
                        // Same theming as tabs above
                        colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? "transparent"
                            : Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : Appearance.colors.colLayer1Hover
                        colBackgroundToggled: Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainerHover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
                            : Appearance.colors.colSecondaryContainerHover
                        
                        onClicked: {
                            dayGroup.clickIndex = index
                            root.selectedDay = modelData
                            AnimeService.fetchSchedule(modelData)
                        }
                    }
                }
            }
        }
        
        // Season selector (only for Seasonal tab)
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.currentTab === 1 ? seasonSelector.implicitHeight : 0
            clip: true
            visible: Layout.preferredHeight > 0
            
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            
            RowLayout {
                id: seasonSelector
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                
                // Previous season button
                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    enabled: !AnimeService.loading
                    
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colLayer2Hover
                    
                    onClicked: AnimeService.prevSeason()
                    
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer1
                    }
                }
                
                // Season/Year display
                Rectangle {
                    implicitWidth: seasonLabel.implicitWidth + 24
                    implicitHeight: 32
                    radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
                    color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                        : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colSecondaryContainer
                    
                    StyledText {
                        id: seasonLabel
                        anchors.centerIn: parent
                        text: AnimeService.getSeasonDisplayName(AnimeService.selectedSeason) + " " + AnimeService.selectedYear
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
                
                // Next season button
                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    enabled: !AnimeService.loading
                    
                    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colLayer2Hover
                    
                    onClicked: AnimeService.nextSeason()
                    
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
        
        // Content area with rounded container
        Rectangle {
            id: contentContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.auroraEverywhere ? "transparent"
                : Appearance.colors.colLayer1
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                : Appearance.auroraEverywhere ? 0 : 1
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                : Appearance.colors.colLayer0Border
            clip: true
            
            // Loading indicator
            ColumnLayout {
                anchors.centerIn: parent
                visible: AnimeService.loading && root.getCurrentData().length === 0
                spacing: 10
                
                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    loading: true
                    implicitSize: 48
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("Loading...")
                    color: Appearance.colors.colSubtext
                }
            }
            
            // Error message
            PagePlaceholder {
                shown: AnimeService.lastError.length > 0 && root.getCurrentData().length === 0
                icon: "error"
                title: Translation.tr("Error")
                description: AnimeService.lastError
                shape: MaterialShape.Shape.Diamond
            }
            
            // Empty state
            PagePlaceholder {
                shown: !AnimeService.loading && AnimeService.lastError.length === 0 && root.getCurrentData().length === 0
                icon: "calendar_month"
                title: Translation.tr("No anime found")
                description: Translation.tr("Try a different day or refresh")
                shape: MaterialShape.Shape.Clover4Leaf
            }
            
            // Anime list scroll fade - softer and rounded
            ScrollEdgeFade {
                z: 1
                target: listView
                vertical: true
                fadeSize: 25
                color: ColorUtils.transparentize(Appearance.colors.colShadow, 0.5)
            }
            
            StyledListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 6
                visible: root.getCurrentData().length > 0
                spacing: 4
                clip: true
                
                model: root.getCurrentData()
                
                delegate: AnimeCard {
                    required property var modelData
                    required property int index
                    width: listView.width
                    anime: modelData
                    compact: false
                }
                
                // Pull to refresh
                property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-verticalOvershoot / 50)) * dragging)
                
                onDragEnded: {
                    if (verticalOvershoot > 60) {
                        root.refreshCurrentTab()
                    }
                }
            }
            
            // Refresh indicator
            MaterialLoadingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                visible: AnimeService.loading && root.getCurrentData().length > 0
                loading: true
                implicitSize: 32
            }
        }
        
        // Footer with refresh button
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                Layout.fillWidth: true
                text: root.currentTab === 0 
                    ? Translation.tr("Airing on %1").arg(AnimeService.getDayName(root.selectedDay === "today" ? root.todayName : root.selectedDay))
                    : root.currentTab === 1 
                        ? Translation.tr("%1 %2").arg(AnimeService.getSeasonDisplayName(AnimeService.selectedSeason)).arg(AnimeService.selectedYear)
                        : Translation.tr("Top Airing")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: !AnimeService.loading
                
                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer2Hover
                
                onClicked: root.refreshCurrentTab()
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    
                    RotationAnimation on rotation {
                        running: AnimeService.loading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                    }
                }
                
                StyledToolTip { text: Translation.tr("Refresh") }
            }
        }
    }
}
