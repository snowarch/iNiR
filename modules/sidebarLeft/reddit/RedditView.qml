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
    
    property int currentSort: 0  // 0: hot, 1: new, 2: top
    property int currentSubredditIndex: 0
    
    readonly property var sortOptions: ["hot", "new", "top"]
    readonly property var subreddits: Config.options?.sidebar?.reddit?.subreddits ?? ["unixporn", "linux", "archlinux"]
    
    onSubredditsChanged: {
        if (root.currentSubredditIndex >= root.subreddits.length) {
            root.currentSubredditIndex = Math.max(0, root.subreddits.length - 1)
        }
    }
    
    Component.onCompleted: {
        if (root.subreddits.length > 0) {
            RedditService.fetchPosts(root.subreddits[0], "hot")
        }
    }
    
    function refreshCurrent() {
        RedditService.fetchPosts(root.subreddits[root.currentSubredditIndex], root.sortOptions[root.currentSort])
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        
        // Sort selector
        ButtonGroup {
            id: sortGroup
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            property int clickIndex: -1
            
            Repeater {
                model: [
                    { text: Translation.tr("Hot"), icon: "local_fire_department" },
                    { text: Translation.tr("New"), icon: "schedule" },
                    { text: Translation.tr("Top"), icon: "trending_up" }
                ]
                delegate: GroupButton {
                    required property var modelData
                    required property int index
                    
                    buttonText: modelData.text
                    toggled: root.currentSort === index
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
                        sortGroup.clickIndex = index
                        root.currentSort = index
                        RedditService.fetchPosts(root.subreddits[root.currentSubredditIndex], root.sortOptions[index])
                    }
                }
            }
        }
        
        // Subreddit selector
        ButtonGroup {
            id: subGroup
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            property int clickIndex: -1
            
            Repeater {
                model: root.subreddits
                delegate: GroupButton {
                    required property string modelData
                    required property int index
                    
                    buttonText: modelData
                    toggled: root.currentSubredditIndex === index
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
                        subGroup.clickIndex = index
                        root.currentSubredditIndex = index
                        RedditService.fetchPosts(modelData, root.sortOptions[root.currentSort])
                    }
                }
            }
        }
        
        // Content area
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
            
            // Loading
            ColumnLayout {
                anchors.centerIn: parent
                visible: RedditService.loading && RedditService.posts.length === 0
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
            
            // Error
            PagePlaceholder {
                shown: RedditService.lastError.length > 0 && RedditService.posts.length === 0
                icon: "error"
                title: Translation.tr("Error")
                description: RedditService.lastError
                shape: MaterialShape.Shape.Diamond
            }
            
            // Empty
            PagePlaceholder {
                shown: !RedditService.loading && RedditService.lastError.length === 0 && RedditService.posts.length === 0
                icon: "forum"
                title: Translation.tr("No posts")
                description: Translation.tr("Try a different subreddit")
                shape: MaterialShape.Shape.Clover4Leaf
            }
            
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
                visible: RedditService.posts.length > 0
                spacing: 4
                clip: true
                
                model: RedditService.posts
                
                delegate: RedditCard {
                    required property var modelData
                    required property int index
                    width: listView.width
                    post: modelData
                }
                
                property real normalizedPullDistance: Math.max(0, (1 - Math.exp(-verticalOvershoot / 50)) * dragging)
                
                onDragEnded: {
                    if (verticalOvershoot > 60) root.refreshCurrent()
                }
            }
            
            // Refresh indicator
            MaterialLoadingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                visible: RedditService.loading && RedditService.posts.length > 0
                loading: true
                implicitSize: 32
            }
        }
        
        // Footer
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText {
                Layout.fillWidth: true
                text: "r/" + RedditService.currentSubreddit + " • " + RedditService.currentSort
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            
            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                enabled: !RedditService.loading
                
                colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                    : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                    : Appearance.colors.colLayer2Hover
                
                onClicked: root.refreshCurrent()
                
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "refresh"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    
                    RotationAnimation on rotation {
                        running: RedditService.loading
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
