import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// InnerTune library route body. The bottom navigation owns the route; this screen only
// renders the authenticated items that InnerTube fetched for that route.
StyledFlickable {
    id: root

    property string route: "songs"
    property var items: []
    property bool loading: false
    property bool authenticated: false

    contentHeight: column.implicitHeight
    clip: true

    signal loginRequested()
    signal playRequested(int index)
    signal albumRequested(string browseId)
    signal playlistRequested(string playlistId)
    signal artistRequested(string browseId)

    function _open(item, index) {
        switch (root.route) {
            case "songs":
                root.playRequested(index);
                break;
            case "albums":
                if (item.browseId) root.albumRequested(item.browseId);
                break;
            case "artists":
                if (item.browseId) root.artistRequested(item.browseId);
                break;
            case "playlists":
                if (item.playlistId || item.browseId) root.playlistRequested(item.playlistId || item.browseId);
                break;
        }
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 220
            visible: !root.authenticated || root.loading || root.items.length === 0

            MaterialLoadingIndicator {
                anchors.centerIn: parent
                visible: root.authenticated && root.loading
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 48, 320)
                spacing: 12
                visible: !root.loading

                StyledText {
                    Layout.fillWidth: true
                    text: root.authenticated ? Translation.tr("No results") : Translation.tr("Sign in to see your library")
                    color: Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                ITButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.authenticated
                    kind: "filled"
                    icon: "login"
                    label: Translation.tr("Sign in")
                    onClicked: root.loginRequested()
                }
            }
        }

        Repeater {
            model: root.authenticated ? root.items : []
            delegate: ITListItem {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                implicitWidth: column.width
                title: modelData.title ?? ""
                subtitle: modelData.subtitle ?? modelData.artist ?? modelData.album ?? ""
                thumbnailUrl: modelData.thumbnail ?? ""
                circle: root.route === "artists"
                isActive: modelData.videoId !== undefined && modelData.videoId === YtMusic.currentVideoId
                isPlaying: isActive && YtMusic.isPlaying
                onClicked: root._open(modelData, index)
            }
        }
    }
}
