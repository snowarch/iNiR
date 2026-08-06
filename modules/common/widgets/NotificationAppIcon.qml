import qs.modules.common
import qs.modules.common.functions
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

    readonly property string imageValue: String(image ?? "")
    readonly property bool imageIsIconHint: imageValue.startsWith("image://icon/")
    readonly property string hintedIcon: imageIsIconHint ? imageValue.substring(13) : ""
    readonly property string effectiveAppIcon: appIcon != "" ? String(appIcon) : hintedIcon
    readonly property string defaultMaterialSymbol: NotificationUtils.findSuitableMaterialSymbol("")
    readonly property string guessedMaterialSymbol: NotificationUtils.findSuitableMaterialSymbol(String(summary ?? ""))
    readonly property bool preferMaterialSymbol: appIcon == "" && imageIsIconHint
        && guessedMaterialSymbol !== defaultMaterialSymbol
    readonly property bool hasVisualImage: imageValue.length > 0 && !imageIsIconHint

    implicitSize: 38 * scale
    property list<var> urgentShapes: [
        MaterialShape.Shape.VerySunny,
        MaterialShape.Shape.SoftBurst,
    ]
    shape: isUrgent ? urgentShapes[Math.floor(Math.random() * urgentShapes.length)] : MaterialShape.Shape.Circle

    color: Appearance.zzzEverywhere
        ? (isUrgent ? Appearance.zzz.secondary : Appearance.zzz.paperAlt)
        : isUrgent ? Appearance.colors.colPrimaryContainer : "transparent"
    Loader {
        id: materialSymbolLoader
        // Icon-theme hints such as notify-send's `-i camera-photo` are not
        // notification artwork. Prefer a semantic Material Symbol when the
        // summary identifies one (for example screenshot notifications).
        active: root.preferMaterialSymbol
            || (root.effectiveAppIcon == "" && !root.hasVisualImage)
        anchors.fill: parent
        sourceComponent: MaterialSymbol {
            text: {
                return (root.urgency == NotificationUrgency.Critical
                    && root.guessedMaterialSymbol === root.defaultMaterialSymbol)
                    ? "priority_high" : root.guessedMaterialSymbol
            }
            anchors.fill: parent
            color: Appearance.zzzEverywhere
                ? (isUrgent ? Appearance.zzz.onSecondary : Appearance.zzz.ink)
                : isUrgent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer
            iconSize: root.materialIconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
    Loader {
        id: appIconLoader
        active: !root.hasVisualImage && !root.preferMaterialSymbol
            && root.effectiveAppIcon != ""
        anchors.centerIn: parent
        sourceComponent: IconImage {
            id: appIconImage
            implicitSize: root.appIconSize
            asynchronous: true
            source: Quickshell.iconPath(root.effectiveAppIcon, "image-missing")
        }
    }
    Loader {
        id: notifImageLoader
        active: root.hasVisualImage
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

                source: notifImageContainer.imageValid ? root.image : ""
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
                        radius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
                        Behavior on radius {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
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
                    source: Quickshell.iconPath(root.appIcon, "image-missing")
                }
            }
        }
    }
}
