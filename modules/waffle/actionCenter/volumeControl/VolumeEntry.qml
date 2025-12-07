import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks

RowLayout {
    id: root
    required property PwNode node
    property string icon: ""
    property bool monochrome: false

    // Cache icon path to avoid repeated lookups
    readonly property string cachedIconPath: {
        if (root.monochrome) return "";
        const props = root.node?.properties;
        if (!props) return "";
        const iconName = props["application.icon-name"] ?? "";
        const nodeName = props["node.name"] ?? "";
        let guessed = AppSearch.guessIcon(iconName);
        if (guessed && AppSearch.iconExists(guessed))
            return Quickshell.iconPath(guessed, "");
        guessed = AppSearch.guessIcon(nodeName);
        if (guessed && AppSearch.iconExists(guessed))
            return Quickshell.iconPath(guessed, "");
        return "";
    }

    PwObjectTracker {
        objects: [root.node]
    }

    spacing: 8

    // App icon
    Image {
        id: appIcon
        Layout.alignment: Qt.AlignVCenter
        visible: !root.monochrome && root.cachedIconPath !== "" && status === Image.Ready
        sourceSize: Qt.size(24, 24)
        width: 24
        height: 24
        asynchronous: true
        cache: true
        source: root.cachedIconPath
    }

    // Fallback fluent icon
    FluentIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.monochrome || root.cachedIconPath === "" || appIcon.status !== Image.Ready
        icon: root.icon || "speaker"
        implicitSize: 20
    }

    WSlider {
        Layout.fillWidth: true
        value: root.node?.audio.volume ?? 0
        onMoved: root.node.audio.volume = value
    }

    WBorderlessButton {
        implicitWidth: 28
        implicitHeight: 28
        onClicked: root.node.audio.muted = !root.node?.audio.muted
        contentItem: FluentIcon {
            anchors.centerIn: parent
            icon: root.node?.audio.muted ? "speaker-mute" : "speaker"
            implicitSize: 16
            color: root.node?.audio.muted ? Looks.colors.fg1 : Looks.colors.fg
        }
    }
}
