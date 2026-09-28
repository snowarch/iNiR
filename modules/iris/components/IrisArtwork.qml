pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.modules.common.widgets
import qs.modules.iris.style

Item {
    id: root
    property string source: ""
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
    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.source.length === 0 || cover.status === Image.Error || cover.status === Image.Null
        text: "music_note"
        iconSize: root.width * 0.55
        color: IrisStyle.subtext
    }
}
