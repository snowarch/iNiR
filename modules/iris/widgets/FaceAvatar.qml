pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components

ClippingRectangle {
    id: root

    property int sourceIndex: 0
    readonly property string primarySource: Directories.userAvatarSourcePrimary
    onPrimarySourceChanged: root.sourceIndex = 0

    radius: width / 2
    color: IrisStyle.fill

    IrisImage {
        id: picture
        anchors.fill: parent
        source: Directories.avatarSourceAt(root.sourceIndex)
        onStatusChanged: {
            if (status === Image.Error && root.sourceIndex + 1 < Directories.userAvatarPaths.length)
                Qt.callLater(() => root.sourceIndex++)
        }
    }
    StyledText {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
        color: IrisStyle.text
        font.family: IrisStyle.fontTitle
        font.pixelSize: root.height * 0.42
        font.weight: IrisStyle.weight(Font.DemiBold)
    }
}
