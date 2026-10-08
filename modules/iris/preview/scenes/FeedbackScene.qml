pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: feedRoot
    readonly property bool banners: feedRoot.opt("iris.modules.notificationPopup", true)
    readonly property bool osd: feedRoot.opt("iris.modules.osd", true)
    readonly property real bannerWidth: Math.max(340, Math.min(560, Number(feedRoot.opt("iris.notifications.width", 380)))) * feedRoot.d
    readonly property real osdWidth: Math.max(260, Math.min(520, Number(feedRoot.opt("iris.osd.width", 320)))) * feedRoot.d
    readonly property int duration: Math.max(2000, Math.min(12000, Number(feedRoot.opt("iris.notifications.duration", 4000))))
    readonly property real naturalWidth: Math.max(feedRoot.bannerWidth, feedRoot.osdWidth) + Math.round(120 * feedRoot.d)
    readonly property real naturalHeight: Math.round(300 * feedRoot.d)
    IslandPill { id: feedIsland; anchors.horizontalCenter: parent.horizontalCenter; y: IrisFrame.band }
    Plate {
        id: bannerPlate
        surface: "cards"
        own: IrisStyle.identity.orange
        opacity: feedRoot.banners ? 1 : 0.3
        anchors.horizontalCenter: parent.horizontalCenter
        y: feedIsland.y + feedIsland.height + IrisStyle.weld
        width: feedRoot.bannerWidth
        height: Math.round(76 * feedRoot.d)
        radius: IrisStyle.radiusPlate
        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.round(14 * feedRoot.d)
            spacing: Math.round(12 * feedRoot.d)
            IrisMark { implicitSize: Math.round(38 * feedRoot.d) }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Math.round(2 * feedRoot.d)
                IrisText { text: Translation.tr("A notification"); font.weight: IrisStyle.weight(Font.DemiBold) }
                IrisText { Layout.fillWidth: true; text: Translation.tr("Stays %1 s, then folds back into the Island.").arg((feedRoot.duration / 1000).toFixed(1)); color: IrisStyle.textSecondary; elide: Text.ElideRight }
            }
        }
        Rectangle {
            id: drain
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(6 * feedRoot.d)
            x: Math.round(18 * feedRoot.d)
            height: 2
            radius: 1
            color: IrisStyle.secondaryAccent
            readonly property real full: parent.width - 2 * x
            width: drain.full
            NumberAnimation on width {
                running: feedRoot.playing && feedRoot.banners
                loops: Animation.Infinite
                from: drain.full; to: 0
                duration: feedRoot.duration
            }
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: bannerPlate.y + bannerPlate.height + Math.round(40 * feedRoot.d)
        opacity: feedRoot.osd ? 1 : 0.3
        width: feedRoot.osdWidth
        height: Math.round(44 * feedRoot.d)
        radius: height / 2
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Math.round(14 * feedRoot.d)
            anchors.rightMargin: Math.round(16 * feedRoot.d)
            spacing: Math.round(10 * feedRoot.d)
            MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(18 * feedRoot.d); color: IrisStyle.text }
            Level { value: Math.min(1, Audio.value ?? 0.7); tint: IrisStyle.text }
            IrisText { text: Math.round(Math.min(1, Audio.value ?? 0.7) * 100); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.DemiBold) }
        }
    }
    Caption {
        glyph: "campaign"
        text: [feedRoot.banners ? Translation.tr("Banners on") : Translation.tr("Banners off"), feedRoot.osd ? Translation.tr("level feedback on") : Translation.tr("level feedback off")].join(" · ")
    }
}
