pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks

Item {
    id: root
    property size sourceSize: Qt.size(32, 32)
    
    implicitWidth: sourceSize.width
    implicitHeight: sourceSize.height
    Layout.preferredWidth: sourceSize.width
    Layout.preferredHeight: sourceSize.height

    StyledImage {
        id: avatar
        anchors.fill: parent
        sourceSize: Qt.size(root.sourceSize.width * 2, root.sourceSize.height * 2)
        fillMode: Image.PreserveAspectCrop
        source: Directories.userAvatarPathAccountsService
        fallbacks: [Directories.userAvatarPathRicersAndWeirdSystems, Directories.userAvatarPathRicersAndWeirdSystems2]
        cache: true
        smooth: true
        mipmap: true

        layer.enabled: Appearance.effectsEnabled
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: Math.min(width, height) / 2
            }
        }
    }
}
