import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "root:services"

RippleButton {
    id: root
    
    required property var post
    property bool compact: false
    
    implicitHeight: compact ? 60 : (post.thumbnail ? 90 : 70)
    buttonRadius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
    
    colBackground: "transparent"
    colBackgroundHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2Hover
    
    onClicked: RedditService.openPost(post)
    altAction: () => post.thumbnail ? RedditService.openImage(post) : RedditService.openPost(post)
    
    contentItem: RowLayout {
        spacing: 10
        
        // Thumbnail
        Rectangle {
            Layout.preferredWidth: root.compact ? 50 : 70
            Layout.preferredHeight: root.compact ? 50 : 70
            Layout.alignment: Qt.AlignVCenter
            visible: post.thumbnail && post.thumbnail.length > 0
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
            color: Appearance.colors.colLayer2
            clip: true
            
            Image {
                anchors.fill: parent
                anchors.margins: 0
                source: post.thumbnail
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            
            // NSFW overlay
            Rectangle {
                anchors.fill: parent
                visible: post.isNsfw
                color: Appearance.colors.colError
                opacity: 0.8
                radius: parent.radius
                
                StyledText {
                    anchors.centerIn: parent
                    text: "NSFW"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.bold: true
                    color: Appearance.colors.colOnError
                }
            }
        }
        
        // Placeholder when no thumbnail
        Rectangle {
            Layout.preferredWidth: root.compact ? 50 : 70
            Layout.preferredHeight: root.compact ? 50 : 70
            Layout.alignment: Qt.AlignVCenter
            visible: !post.thumbnail || post.thumbnail.length === 0
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.verysmall
            color: Appearance.colors.colLayer2
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: post.isSelf ? "article" : "link"
                iconSize: 24
                color: Appearance.colors.colSubtext
            }
        }
        
        // Content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            
            // Title
            StyledText {
                Layout.fillWidth: true
                text: post.title
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }
            
            // Metadata row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // Subreddit
                StyledText {
                    text: "r/" + post.subreddit
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colPrimary
                }
                
                // Score
                RowLayout {
                    spacing: 2
                    MaterialSymbol {
                        text: "arrow_upward"
                        iconSize: 12
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: RedditService.formatScore(post.score)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
                
                // Comments
                RowLayout {
                    spacing: 2
                    MaterialSymbol {
                        text: "chat_bubble"
                        iconSize: 12
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: RedditService.formatScore(post.numComments)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }
                
                // Time
                StyledText {
                    text: RedditService.formatTime(post.created)
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                }
                
                Item { Layout.fillWidth: true }
            }
            
            // Author
            StyledText {
                visible: !root.compact
                text: "u/" + post.author
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
            }
        }
    }
    
    StyledToolTip {
        text: Translation.tr("Click to open post, right-click to open image")
    }
}
