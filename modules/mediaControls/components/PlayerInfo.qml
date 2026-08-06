pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayerInfo - Reusable title/artist display
 */
ColumnLayout {
    id: root
    
    // Required properties
    required property string title
    required property string artist
    
    // Optional properties
    property color titleColor: Appearance.zzzEverywhere ? Appearance.zzz.ink
        : Appearance.inirEverywhere
        ? Appearance.inir.colText 
        : Appearance.colors.colOnLayer0
    property color artistColor: Appearance.zzzEverywhere ? Appearance.zzz.inkMuted
        : Appearance.inirEverywhere
        ? Appearance.inir.colTextSecondary 
        : Appearance.colors.colSubtext
    property int titleSize: Appearance.font.pixelSize.large
    property int artistSize: Appearance.font.pixelSize.small
    property int titleWeight: Font.Medium
    property bool cleanTitle: true
    property bool animateTitle: true
    property int slideDirection: 1
    
    spacing: 0
    
    // Title
    StyledText {
        Layout.fillWidth: true
        text: root.cleanTitle ? StringUtils.cleanMusicTitle(root.title) || "—" : (root.title || "—")
        font.pixelSize: root.titleSize
        font.weight: Appearance.zzzEverywhere ? Font.Black : root.titleWeight
        font.italic: Appearance.zzzEverywhere
        color: root.titleColor
        elide: Text.ElideRight
        animateChange: root.animateTitle
        animationDistanceX: root.slideDirection * 8
        animationDistanceY: 0
    }
    
    // Artist
    StyledText {
        Layout.fillWidth: true
        text: root.artist || ""
        font.pixelSize: root.artistSize
        color: root.artistColor
        elide: Text.ElideRight
        visible: text !== ""
        animateChange: root.animateTitle
        animationDistanceX: root.slideDirection * 8
        animationDistanceY: 0
    }
}
