import qs.modules.common
import qs.modules.common.functions
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

MaterialShape { // App icon
    id: root
    property var appIcon: ""
    property var summary: ""
    property var urgency: NotificationUrgency.Normal
    property bool isUrgent: urgency === NotificationUrgency.Critical
    property var image: ""
    property real materialIconScale: 0.57
    property real appIconScale: 0.8
    property real smallAppIconScale: 0.49
    property real materialIconSize: implicitSize * materialIconScale
    property real appIconSize: implicitSize * appIconScale
    property real smallAppIconSize: implicitSize * smallAppIconScale

    implicitSize: 38 * scale
    property list<var> urgentShapes: [
        MaterialShape.Shape.VerySunny,
        MaterialShape.Shape.SoftBurst,
    ]
    shape: isUrgent ? urgentShapes[Math.floor(Math.random() * urgentShapes.length)] : MaterialShape.Shape.Circle

    color: isUrgent ? Appearance.colors.colPrimaryContainer : "transparent"
    Loader {
        id: materialSymbolLoader
        // Only show MaterialSymbol when there's no appIcon AND no image
        active: root.appIcon == "" && root.image == ""
        anchors.fill: parent
        sourceComponent: MaterialSymbol {
            text: {
                const defaultIcon = NotificationUtils.findSuitableMaterialSymbol("")
                const guessedIcon = NotificationUtils.findSuitableMaterialSymbol(root.summary)
                return (root.urgency == NotificationUrgency.Critical && guessedIcon === defaultIcon) ?
                    "priority_high" : guessedIcon
            }
            anchors.fill: parent
            color: isUrgent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            iconSize: root.materialIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Loader {
        id: appIconLoader
        active: root.image == "" && root.appIcon != ""
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: {
                const icon = String(root.appIcon ?? "");
                if (icon === "") return "image-missing";
                if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("image://icon/")) {
                    let path = icon;
                    if (icon.startsWith("file://")) {
                        path = icon.substring(7);
                    } else if (icon.startsWith("image://icon/")) {
                        const rest = icon.substring(13);
                        path = rest.startsWith("/") ? rest : "";
                    }
                    if (path === "") return "image-missing";
                    if (TrayService.fileExists(path)) {
                        return icon;
                    } else {
                        return "image-missing";
                    }
                }
                return Quickshell.iconPath(icon, "image-missing");
            }
        }
    }
    Loader {
        id: notifImageLoader
        active: root.image != "" && root.image !== undefined && TrayService.fileExists(root.image)
        anchors.fill: parent
        sourceComponent: Item {
            id: notifImageContainer
            anchors.fill: parent
            property bool imageValid: true
            Image {
                id: notifImage
                anchors.fill: parent
                readonly property int size: parent.width
                visible: status === Image.Ready

                source: notifImageContainer.imageValid && TrayService.fileExists(root.image) ? root.image : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                asynchronous: true

                width: size
                height: size
                sourceSize.width: size
                sourceSize.height: size
                onStatusChanged: {
                    if (status === Image.Error) {
                        notifImageContainer.imageValid = false
                        notifImageLoader.active = false
                    }
                }

                layer.enabled: status === Image.Ready
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: notifImage.size
                        height: notifImage.size
                        radius: Appearance.rounding.full
                    }
                }
            }
            Loader {
                id: notifImageAppIconLoader
                active: root.appIcon != ""
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                sourceComponent: IconImage {
                    implicitSize: root.smallAppIconSize
                    asynchronous: true
                    source: {
                        const icon = String(root.appIcon ?? "");
                        if (icon === "") return "image-missing";
                        if (icon.startsWith("/") || icon.startsWith("file://") || icon.startsWith("image://icon/")) {
                            let path = icon;
                            if (icon.startsWith("file://")) {
                                path = icon.substring(7);
                            } else if (icon.startsWith("image://icon/")) {
                                const rest = icon.substring(13);
                                path = rest.startsWith("/") ? rest : "";
                            }
                            if (path === "") return "image-missing";
                            if (TrayService.fileExists(path)) {
                                return icon;
                            } else {
                                return "image-missing";
                            }
                        }
                        return Quickshell.iconPath(icon, "image-missing");
                    }
                }
            }
        }
    }
}