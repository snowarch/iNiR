import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    required property PwNode node
    PwObjectTracker {
        objects: [node]
    }

    implicitHeight: rowLayout.implicitHeight

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        spacing: 6

        Image {
            property real size: 36
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            visible: source != ""
            sourceSize.width: size
            sourceSize.height: size
            source: {
                if (!root.node)
                    return ""
                let icon;
                icon = AppSearch.guessIcon(root.node.properties?.["application.icon-name"] ?? "");
                if (AppSearch.iconExists(icon))
                    return Quickshell.iconPath(icon, "image-missing");
                icon = AppSearch.guessIcon(root.node.properties?.["node.name"] ?? "");
                return Quickshell.iconPath(icon, "image-missing");
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -4

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                text: {
                    if (!root.node)
                        return ""
                    // application.name -> description -> name
                    const app = root.node.properties?.["application.name"] ?? (root.node.description != "" ? root.node.description : root.node.name);
                    const media = root.node.properties?.["media.name"];
                    return media != undefined ? `${app} • ${media}` : app;
                }
            }

            StyledSlider {
                id: slider
                configuration: StyledSlider.Configuration.S
                property real modelValue: root.node?.audio.volume ?? 0
                to: (root.node === Audio.sink) ? 1.5 : 1

                Binding {
                    target: slider
                    property: "value"
                    value: slider.modelValue
                    when: !slider.pressed && !slider._userInteracting
                }
                onMoved: {
                    if (root.node === Audio.sink) {
                        Audio.setSinkVolume(value)
                    } else if (root.node === Audio.source) {
                        Audio.setSourceVolume(value)
                    } else if (root.node?.audio) {
                        root.node.audio.volume = value
                    }
                }
            }
        }
    }
}
