import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.sidebarLeft.innertune

// Literal translation of Screens.kt MainScreens NavigationBar — Material3 bottom nav
// (80dp) with Home/Songs/Artists/Albums/Playlists, pill indicator on the selected item.
Item {
    id: root
    implicitHeight: ITDimens.navigationBarHeight

    property string currentRoute: "home"
    signal selected(string route)

    readonly property var items: [
        { route: "home", icon: "home", label: Translation.tr("Home") },
        { route: "songs", icon: "music_note", label: Translation.tr("Songs") },
        { route: "artists", icon: "artist", label: Translation.tr("Artists") },
        { route: "albums", icon: "album", label: Translation.tr("Albums") },
        { route: "playlists", icon: "queue_music", label: Translation.tr("Playlists") }
    ]

    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 12
        anchors.bottomMargin: 16
        spacing: 0

        Repeater {
            model: root.items
            delegate: Item {
                id: navItem
                required property var modelData
                readonly property bool active: modelData.route === root.currentRoute
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 4

                    // Pill indicator + icon.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 64
                        implicitHeight: 32
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64
                            height: 32
                            radius: height / 2
                            color: Appearance.colors.colSecondaryContainer
                            opacity: navItem.active ? 1 : 0
                            Behavior on opacity {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration) }
                            }
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: navItem.modelData.icon
                            iconSize: Appearance.font.pixelSize.huge
                            fill: navItem.active ? 1 : 0
                            color: navItem.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: navItem.modelData.label
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: navItem.active ? Font.Bold : Font.Medium
                        color: navItem.active ? Appearance.colors.colOnSurface : Appearance.colors.colOnSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(navItem.modelData.route)
                }
            }
        }
    }
}
