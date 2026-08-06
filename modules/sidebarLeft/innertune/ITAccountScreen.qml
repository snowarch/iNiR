import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.sidebarLeft.innertune

// Account / sign-in surface. YouTube disabled the frictionless device-flow OAuth client, so the
// working auth (the same one InnerTune uses) is the logged-in browser's YouTube session: the user
// signs into YouTube Music in their browser, then "Connect" reuses those cookies. Signed-in shows
// the account avatar + name and a disconnect. Auth is owned by InnerTube; home/library follow.
StyledFlickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    signal backRequested()

    property bool showManual: false

    Component.onCompleted: InnerTube.detectBrowsers()

    // Friendly label for the browser an active session came from.
    function _browserName(id) {
        for (let i = 0; i < InnerTube.detectedBrowsers.length; i++)
            if (InnerTube.detectedBrowsers[i].id === id) return InnerTube.detectedBrowsers[i].name;
        return id;
    }

    ColumnLayout {
        id: column
        width: root.width
        spacing: 0

        // Back chevron.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: ITDimens.appBarHeight
            ITIconButton {
                anchors.verticalCenter: parent.verticalCenter
                x: 8
                symbol: "arrow_back"
                onClicked: root.backRequested()
            }
        }

        // Avatar (real account photo when connected) or fallback glyph.
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 24
            implicitWidth: 96
            implicitHeight: 96
            MaterialSymbol {
                anchors.fill: parent
                visible: !(InnerTube.authenticated && InnerTube.accountAvatar !== "")
                text: "account_circle"
                iconSize: 96
                fill: InnerTube.authenticated ? 1 : 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Appearance.colors.colPrimary
            }
            ITThumbnail {
                anchors.fill: parent
                visible: InnerTube.authenticated && InnerTube.accountAvatar !== ""
                thumbnailUrl: InnerTube.accountAvatar
                circle: true
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            text: InnerTube.authenticated
                ? (InnerTube.accountName || Translation.tr("Signed in"))
                : Translation.tr("Sign in to YouTube Music")
            font.family: Appearance.font.family.title
            font.pixelSize: Appearance.font.pixelSize.title
            font.weight: Font.Bold
            color: Appearance.colors.colOnSurface
        }

        // Sub-text: instructions / connecting / error / connected-via.
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: InnerTube.connecting
                ? Translation.tr("Connecting to your YouTube session…")
                : (InnerTube.authenticated
                    ? (InnerTube.connectedBrowser === "manual"
                        ? Translation.tr("Connected with imported cookies.")
                        : (InnerTube.connectedBrowser !== ""
                            ? Translation.tr("Connected via %1.").arg(root._browserName(InnerTube.connectedBrowser))
                            : Translation.tr("Connected.")))
                    : (InnerTube.connectError === "not_logged_in"
                        ? Translation.tr("No signed-in YouTube session found. Sign into YouTube Music in your browser, then connect.")
                        : (InnerTube.connectError === "no_browser"
                            ? Translation.tr("No supported browser detected. Import a cookies file instead.")
                            : (InnerTube.connectError !== ""
                                ? Translation.tr("Couldn't read your YouTube session. Make sure you're signed in, then retry.")
                                : Translation.tr("Connect to get your library, liked songs and a personalized home.")))))
            font.pixelSize: Appearance.font.pixelSize.small
            color: InnerTube.connectError !== "" ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
        }

        MaterialLoadingIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 16
            visible: InnerTube.connecting
            opacity: InnerTube.connecting ? 1 : 0
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration); easing.type: Easing.OutCubic }
            }
        }

        // Primary action: Connect automatically (signed out) / Disconnect (signed in).
        ITButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 20
            visible: !InnerTube.connecting
            kind: InnerTube.authenticated ? "outlined" : "filled"
            icon: InnerTube.authenticated ? "logout" : "link"
            label: InnerTube.authenticated ? Translation.tr("Disconnect")
                : (InnerTube.connectError !== "" ? Translation.tr("Retry") : Translation.tr("Connect"))
            onClicked: {
                if (InnerTube.authenticated) InnerTube.disconnect();
                else InnerTube.connect("auto");
            }
        }

        // Browser picker — pick which signed-in browser to read the session from. The system
        // default is highlighted. Hidden while connecting or once signed in.
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 14
            visible: !InnerTube.authenticated && !InnerTube.connecting && InnerTube.detectedBrowsers.length > 0
            text: Translation.tr("Or pick a browser")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
        }
        Flow {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            Layout.fillWidth: true
            spacing: 8
            visible: !InnerTube.authenticated && !InnerTube.connecting && InnerTube.detectedBrowsers.length > 0
            Repeater {
                model: InnerTube.detectedBrowsers
                ITButton {
                    required property var modelData
                    kind: modelData.id === InnerTube.defaultBrowser ? "tonal" : "outlined"
                    icon: "public"
                    label: modelData.name
                    onClicked: InnerTube.connect(modelData.id)
                }
            }
        }

        // Secondary: open YouTube Music so the user can sign in there first.
        ITButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 12
            visible: !InnerTube.authenticated && !InnerTube.connecting
            kind: "text"
            icon: "open_in_new"
            label: Translation.tr("Open YouTube Music")
            onClicked: Qt.openUrlExternally("https://music.youtube.com")
        }

        // "Having trouble?" expander → manual cookie import (the reliable incognito method).
        StyledText {
            id: manualToggle
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            visible: !InnerTube.authenticated && !InnerTube.connecting
            text: (root.showManual ? "▾ " : "▸ ") + Translation.tr("Having trouble? Import cookies manually")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colPrimary
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showManual = !root.showManual
            }
        }

        // Morphing container — grows to reveal the manual import controls.
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            clip: true
            implicitHeight: (root.showManual && !InnerTube.authenticated && !InnerTube.connecting) ? manualCol.implicitHeight : 0
            opacity: (root.showManual && !InnerTube.authenticated && !InnerTube.connecting) ? 1 : 0
            Behavior on implicitHeight {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMove.duration); easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: Appearance.calcEffectiveDuration(Appearance.animation.elementMoveFast.duration); easing.type: Easing.OutCubic }
            }
            ColumnLayout {
                id: manualCol
                width: parent.width
                spacing: 8
                StyledText {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    text: Translation.tr("YouTube rotates cookies on open tabs, which can break auto-connect. For a stable login: open a private/incognito window, sign into YouTube, visit youtube.com/robots.txt, export youtube.com cookies to a cookies.txt, then close the window. Paste the file path below.")
                }
                MaterialTextField {
                    id: cookiePathField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("/path/to/cookies.txt")
                    onAccepted: if (text.trim().length > 0) InnerTube.connectManual(text.trim())
                }
                ITButton {
                    Layout.alignment: Qt.AlignHCenter
                    kind: "tonal"
                    icon: "upload_file"
                    label: Translation.tr("Import cookies file")
                    enabled: cookiePathField.text.trim().length > 0
                    onClicked: InnerTube.connectManual(cookiePathField.text.trim())
                }
            }
        }

        Item { Layout.preferredHeight: 24 }
    }
}
