import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import "root:services"

RippleButton {
    id: root
    
    required property var anime
    property bool compact: false
    
    readonly property real cardRadius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property real imageRadius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.small
    
    implicitHeight: compact ? 80 : 120
    Layout.fillWidth: true
    buttonRadius: cardRadius
    
    // Theming - aurora/inir/material
    colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colLayer1
    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer1Hover
    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer1Active
    colBackgroundToggled: colBackgroundHover
    colBackgroundToggledHover: colRipple
    
    // Left click -> AniList page
    onClicked: {
        if (root.anime?.url) {
            Qt.openUrlExternally(root.anime.url)
        }
    }
    
    // Right click -> context menu
    altAction: () => contextMenu.active = true
    
    function truncateSynopsis(text, maxLen) {
        if (!text) return ""
        return text.length <= maxLen ? text : text.substring(0, maxLen).trim() + "..."
    }
    
    // Custom watch site from config, or HiAnime as default
    function getWatchUrl() {
        const title = root.anime?.title ?? ""
        const customSite = Config.options?.sidebar?.animeSchedule?.watchSite ?? ""
        if (customSite) {
            return customSite.replace("%s", encodeURIComponent(title))
        }
        return "https://hianime.to/search?keyword=" + encodeURIComponent(title)
    }
    
    ContextMenu {
        id: contextMenu
        anchorItem: root
        popupSide: Edges.Right
        visualMargin: 12
        closeOnHoverLost: true
        anchorHovered: root.buttonHovered
        
        model: [
            { text: Translation.tr("Watch"), iconName: "play_circle", monochromeIcon: true, action: () => Qt.openUrlExternally(root.getWatchUrl()) },
            { type: "separator" },
            { text: Translation.tr("Open on AniList"), iconName: "open_in_new", monochromeIcon: true, action: () => Qt.openUrlExternally(root.anime?.url ?? "") }
        ]
    }
    
    contentItem: RowLayout {
        spacing: 12
        
        // Cover image with proper rounded corners
        Item {
            Layout.preferredWidth: root.compact ? 55 : 75
            Layout.preferredHeight: root.compact ? 70 : 105
            
            Rectangle {
                id: imageMask
                anchors.fill: parent
                radius: root.imageRadius
                visible: false
            }
            
            Image {
                id: coverImage
                anchors.fill: parent
                source: root.anime?.image ?? root.anime?.imageSmall ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
            }
            
            OpacityMask {
                anchors.fill: parent
                source: coverImage
                maskSource: imageMask
            }
            
            // Placeholder
            Rectangle {
                anchors.fill: parent
                radius: root.imageRadius
                color: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                    : Appearance.auroraEverywhere ? ColorUtils.transparentize(Appearance.colors.colLayer2, 0.5)
                    : Appearance.colors.colLayer2
                visible: coverImage.status !== Image.Ready
                
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "image"
                    iconSize: 24
                    color: Appearance.colors.colSubtext
                }
            }
            
            // Border
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: root.imageRadius
                border.width: Appearance.auroraEverywhere ? 0 : 1
                border.color: Appearance.inirEverywhere ? Appearance.inir.colBorderSubtle
                    : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
            }
        }
        
        // Info
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            
            // Title
            StyledText {
                Layout.fillWidth: true
                text: root.anime?.titleEnglish ?? root.anime?.title ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
                maximumLineCount: root.compact ? 1 : 2
                wrapMode: Text.Wrap
            }
            
            // Japanese title
            StyledText {
                Layout.fillWidth: true
                visible: !root.compact && root.anime?.titleJapanese && root.anime.titleJapanese !== (root.anime?.titleEnglish ?? root.anime?.title)
                text: root.anime?.titleJapanese ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
            
            // Metadata
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                
                // Score
                RowLayout {
                    spacing: 3
                    visible: (root.anime?.score ?? 0) > 0
                    
                    MaterialSymbol {
                        text: "star"
                        iconSize: Appearance.font.pixelSize.smaller
                        color: Appearance.m3colors.m3tertiary
                        fill: 1
                    }
                    StyledText {
                        text: root.anime?.score?.toFixed(1) ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }
                }
                
                // Episodes
                RowLayout {
                    spacing: 3
                    visible: root.anime?.episodes
                    
                    MaterialSymbol {
                        text: "movie"
                        iconSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        text: root.anime?.episodes ?? "?"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
                
                // Type badge
                Rectangle {
                    visible: root.anime?.type
                    implicitWidth: typeText.implicitWidth + 8
                    implicitHeight: typeText.implicitHeight + 4
                    radius: Appearance.rounding.verysmall
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                        : Appearance.colors.colSecondaryContainer
                    
                    StyledText {
                        id: typeText
                        anchors.centerIn: parent
                        text: root.anime?.type ?? ""
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.inirEverywhere ? Appearance.inir.colOnPrimaryContainer
                            : Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
            
            // Broadcast time
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: !root.compact && root.anime?.broadcast
                
                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.smaller
                    color: Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: AnimeService.formatBroadcast(root.anime?.broadcast ?? "")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
            
            // Genres
            Flow {
                Layout.fillWidth: true
                visible: !root.compact && (root.anime?.genres?.length ?? 0) > 0
                spacing: 4
                
                Repeater {
                    model: (root.anime?.genres ?? []).slice(0, 3)
                    delegate: Rectangle {
                        required property string modelData
                        implicitWidth: genreText.implicitWidth + 6
                        implicitHeight: genreText.implicitHeight + 2
                        radius: Appearance.rounding.verysmall
                        color: Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                            : Appearance.colors.colSurfaceContainer
                        
                        StyledText {
                            id: genreText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.inirEverywhere ? Appearance.inir.colOnSecondaryContainer
                                : Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }
            }
            
            Item { Layout.fillHeight: true }
        }
    }
}
