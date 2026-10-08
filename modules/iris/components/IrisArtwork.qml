pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root
    property string source: ""
    // With no cover: the icon of the app an empty player offers to open, instead of a generic note.
    property string appIcon: ""
    property bool circular: false
    property real radius: circular ? width / 2 : Math.min(IrisStyle.iconRadius(width), IrisStyle.radiusTile)
    property real decodeSize: 0
    implicitWidth: 64 * IrisStyle.density
    implicitHeight: implicitWidth
    IrisImage {
        id: cover
        anchors.fill: parent
        source: root.source
        decodeWidth: root.decodeSize > 0 ? root.decodeSize : root.width
        decodeHeight: root.decodeSize > 0 ? root.decodeSize : root.height
        visible: false
        // An effect samples this texture without mipmaps; a mipmapped one makes Qt rebuild its filtering.
        mipmap: false
    }
    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: cover
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: roundMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        visible: cover.status === Image.Ready
    }
    readonly property bool bare: root.source.length === 0 || cover.status === Image.Error || cover.status === Image.Null
    IconImage {
        anchors.centerIn: parent
        visible: root.bare && root.appIcon.length > 0
        implicitSize: Math.round(root.width * 0.62)
        source: root.appIcon.length > 0 ? Quickshell.iconPath(root.appIcon, "audio-x-generic") : ""
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.bare && root.appIcon.length === 0
        text: "music_note"
        iconSize: root.width * 0.55
        color: IrisStyle.subtext
    }
}
