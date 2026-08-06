import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt GridItem — shelf card.
// Column(pad 12, width = GridThumbnailHeight*ratio): thumbnail (128dp, aspectRatio),
// 6dp spacer, title (bodyLarge Bold, 2 lines), subtitle (bodyMedium secondary, 2 lines).
Item {
    id: root
    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property real thumbnailRatio: 1.0
    property bool circle: false
    property bool isActive: false
    property bool isPlaying: false

    readonly property int thumbHeight: ITDimens.gridThumbnailHeight
    readonly property int thumbWidth: Math.round(thumbHeight * thumbnailRatio)

    implicitWidth: thumbWidth + 24            // 12dp padding each side
    implicitHeight: col.implicitHeight + 24

    signal clicked()
    signal longPressed()

    // Material state layer behind the card (InnerTune cards react to hover/press).
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: ITDimens.gridCardCornerRadius
        color: Appearance.colors.colOnSurface
        opacity: cardMouse.pressed ? 0.10 : (cardMouse.containsMouse ? 0.05 : 0)
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        ITThumbnail {
            Layout.preferredWidth: root.thumbWidth
            Layout.preferredHeight: root.thumbHeight
            Layout.alignment: Qt.AlignHCenter
            thumbnailUrl: root.thumbnailUrl
            isActive: root.isActive
            isPlaying: root.isPlaying
            circle: root.circle
        }

        Item { Layout.preferredHeight: 6 }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Bold
            color: Appearance.colors.colOnSurface
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            horizontalAlignment: root.circle ? Text.AlignHCenter : Text.AlignLeft
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.subtitle !== ""
            text: root.subtitle
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSecondary
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            horizontalAlignment: root.circle ? Text.AlignHCenter : Text.AlignLeft
        }
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.longPressed()
    }
}
