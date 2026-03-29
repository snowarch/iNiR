pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
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

    width: sourceSize.width
    height: sourceSize.height
    implicitWidth: sourceSize.width
    implicitHeight: sourceSize.height
    Layout.preferredWidth: sourceSize.width
    Layout.preferredHeight: sourceSize.height

    Rectangle {
        id: avatarMask
        anchors.fill: parent
        radius: width / 2
        visible: false
    }

    Image {
        id: avatarImg
        anchors.fill: parent
        source: Directories.userAvatarSourcePrimary
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        sourceSize.width: root.sourceSize.width * 2
        sourceSize.height: root.sourceSize.height * 2
        visible: false
        
        onStatusChanged: {
            if (status === Image.Error) {
                const nextSource = Directories.nextAvatarSource(source)
                if (nextSource.length > 0 && nextSource !== source)
                    source = nextSource
            }
        }
    }

    GE.OpacityMask {
        anchors.fill: parent
        source: avatarImg
        maskSource: avatarMask
        visible: avatarImg.status === Image.Ready
    }

    // Fallback icon
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Looks.colors.bg2Base
        visible: avatarImg.status !== Image.Ready

        MaterialSymbol {
            anchors.centerIn: parent
            text: "person"
            iconSize: Math.round(root.sourceSize.width * 0.55)
            color: Looks.colors.subfg
        }
    }
}
