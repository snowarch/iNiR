import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarLeft.innertune

// Literal translation of Items.kt ListItem (the 64dp row used by Song/Artist/Album/Playlist).
// Row: thumbnail box (6dp pad) + weighted title/subtitle column (6dp pad) + trailing slot.
Item {
    id: root
    implicitHeight: ITDimens.listItemHeight

    property string title: ""
    property string subtitle: ""
    property string thumbnailUrl: ""
    property bool circle: false
    property int albumIndex: -1
    property bool isActive: false
    property bool isPlaying: false
    property bool liked: false
    property int thumbnailSize: ITDimens.listThumbnailSize
    default property alias trailingData: trailingRow.data

    signal clicked()
    signal longPressed()

    // Subtle Material press/hover feedback (InnerTune rows ripple on tap).
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: Appearance.rounding.small
        color: Appearance.colors.colOnSurface
        opacity: mouse.pressed ? 0.10 : (mouse.containsMouse ? 0.05 : 0)
        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
        }
    }

    // Whole-row click handler — BELOW the content so trailing controls (e.g. queue
    // reorder arrows) keep their own clicks; non-interactive areas fall through to here.
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onPressAndHold: root.longPressed()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 0

        // Thumbnail (6dp padding box, centered).
        Item {
            Layout.preferredWidth: root.thumbnailSize + 12
            Layout.preferredHeight: root.thumbnailSize + 12
            ITThumbnail {
                anchors.centerIn: parent
                width: root.thumbnailSize
                height: root.thumbnailSize
                thumbnailUrl: root.thumbnailUrl
                albumIndex: root.albumIndex
                isActive: root.isActive
                isPlaying: root.isPlaying
                circle: root.circle
            }
        }

        // Title + subtitle.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: ITDimens.titleTextSize
                font.weight: Font.Bold
                color: Appearance.colors.colOnSurface
                maximumLineCount: 1
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.liked || root.subtitle !== ""

                MaterialSymbol {
                    visible: root.liked
                    text: "favorite"
                    iconSize: ITDimens.subtitleTextSize + 2
                    color: Appearance.colors.colSecondary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.subtitle
                    font.pixelSize: ITDimens.subtitleTextSize
                    color: Appearance.colors.colSecondary
                    maximumLineCount: 1
                    elide: Text.ElideRight
                }
            }
        }

        // Trailing slot (default content goes here).
        RowLayout {
            id: trailingRow
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
        }
    }
}
