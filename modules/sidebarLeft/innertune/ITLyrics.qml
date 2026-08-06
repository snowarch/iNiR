import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Translation of Lyrics.kt — synced line list (current line highlighted primary + bold,
// others secondary at 0.5 alpha), auto-scrolling to keep the active line centered.
// Falls back to plain scrollable text when no synced lyrics are available.
Item {
    id: root
    property var lyrics: ({})           // InnerTube.lyrics: { plain, synced, source }
    readonly property var synced: lyrics?.synced ?? null
    readonly property string plain: lyrics?.plain ?? ""
    readonly property bool isSynced: synced !== null && synced !== undefined && synced.length > 0

    readonly property int currentLine: {
        if (!isSynced) return -1;
        const pos = YtMusic.currentPosition;
        let idx = -1;
        for (let i = 0; i < synced.length; i++) {
            if (synced[i].t <= pos) idx = i; else break;
        }
        return idx;
    }
    onCurrentLineChanged: if (isSynced && currentLine >= 0) lineView.positionViewAtIndex(currentLine, ListView.Center)

    // Synced lyrics.
    ListView {
        id: lineView
        anchors.fill: parent
        visible: root.isSynced
        model: root.synced
        clip: true
        preferredHighlightBegin: height / 2 - 30
        preferredHighlightEnd: height / 2 + 30
        highlightRangeMode: ListView.ApplyRange
        delegate: Item {
            required property var modelData
            required property int index
            width: lineView.width
            height: lineText.implicitHeight + 16
            StyledText {
                id: lineText
                anchors.centerIn: parent
                width: parent.width - ITDimens.playerHorizontalPadding * 2
                text: modelData.line
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Bold
                color: index === root.currentLine ? Appearance.colors.colPrimary : Appearance.colors.colSecondary
                opacity: index === root.currentLine ? 1.0 : 0.5
                Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
                Behavior on opacity { enabled: Appearance.animationsEnabled; NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: YtMusic.seek(modelData.t)
            }
        }
    }

    // Plain fallback.
    StyledFlickable {
        anchors.fill: parent
        visible: !root.isSynced && root.plain !== ""
        contentHeight: plainText.implicitHeight
        clip: true
        StyledText {
            id: plainText
            width: root.width - ITDimens.playerHorizontalPadding * 2
            x: ITDimens.playerHorizontalPadding
            text: root.plain
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurface
        }
    }

    StyledText {
        anchors.centerIn: parent
        visible: !root.isSynced && root.plain === ""
        text: Translation.tr("No lyrics")
        color: Appearance.colors.colOnSurfaceVariant
    }
}
