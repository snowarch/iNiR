pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.lock
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

PreviewScene {
    id: lockPreview
    readonly property real naturalWidth: Math.round(540 * lockPreview.d)
    readonly property real naturalHeight: Math.round(300 * lockPreview.d)
    readonly property string source: String(lockPreview.opt("iris.lock.scene.source", "desktop"))
    readonly property real blur: Number(lockPreview.opt("iris.lock.scene.blur", 100)) / 100
    readonly property real dim: Number(lockPreview.opt("iris.lock.scene.dim", 0)) / 100
    readonly property string clockFormat: String(lockPreview.opt("iris.lock.type.clockFormat", "auto"))
    readonly property string format: lockPreview.clockFormat === "24h" ? "HH:mm" : lockPreview.clockFormat === "12h" ? "h:mm AP" : String(Config.options?.time?.format ?? "hh:mm")
    Rectangle { anchors.fill: parent; color: IrisStyle.surface }
    IrisWallpaperView {
        id: lockWall
        anchors.fill: parent
        active: lockPreview.preview.visible && lockPreview.source !== "colour"
        live: false
        screen: GlobalStates.focusedScreen
        path: lockPreview.source === "custom" ? String(lockPreview.opt("iris.lock.scene.path", "")) : configuredPath
        provideTexture: true
        decodeSize: Qt.size(Math.round(lockPreview.width), 0)
        opacity: 0
    }
    MultiEffect {
        anchors.fill: parent
        visible: lockPreview.source !== "colour"
        source: lockWall.textureItem
        blurEnabled: lockPreview.blur > 0
        blur: lockPreview.blur
        blurMax: IrisStyle.glassBlurMax
        saturation: Number(lockPreview.opt("iris.lock.scene.saturation", 15)) / 100 - 1
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: IrisStyle.surface; opacity: lockPreview.dim }
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Math.round(64 * lockPreview.d)
        spacing: Math.round(10 * lockPreview.d)
        IrisText {
            visible: lockPreview.opt("iris.lock.blocks.clock.enable", true)
            Layout.alignment: Qt.AlignHCenter
            text: Translation.locale.toString(DateTime.clock.date, lockPreview.format + (lockPreview.opt("iris.lock.type.seconds", false) ? ":ss" : ""))
            font.family: IrisLockOptions.clockFamily
            font.pixelSize: Number(lockPreview.opt("iris.lock.type.clockSize", 112)) * 0.6 * IrisLockOptions.typeScale
            font.weight: Number(lockPreview.opt("iris.lock.type.clockWeight", 700))
            font.letterSpacing: Number(lockPreview.opt("iris.lock.type.clockTracking", -4))
            color: IrisLockOptions.accentColour
        }
        IrisText {
            visible: lockPreview.opt("iris.lock.blocks.clock.enable", true) && String(lockPreview.opt("iris.lock.type.dateFormat", "long")) !== "none"
            Layout.alignment: Qt.AlignHCenter
            text: Translation.locale.toString(DateTime.clock.date, String(lockPreview.opt("iris.lock.type.dateFormat", "long")) === "short" ? "ddd d MMM" : "dddd d MMMM")
            color: IrisStyle.onMediaSecondary
        }
        RowLayout {
            visible: lockPreview.opt("iris.lock.blocks.glance.enable", true)
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.round(16 * lockPreview.d)
            MaterialSymbol { visible: lockPreview.opt("iris.lock.blocks.glance.weather", true); text: "partly_cloudy_day"; color: IrisStyle.onMedia; iconSize: Math.round(22 * lockPreview.d) }
            MaterialSymbol { visible: lockPreview.opt("iris.lock.blocks.glance.events", true); text: "event"; color: IrisStyle.onMedia; iconSize: Math.round(22 * lockPreview.d) }
            MaterialSymbol { visible: lockPreview.opt("iris.lock.blocks.glance.battery", true); text: "battery_full"; color: IrisStyle.onMedia; iconSize: Math.round(22 * lockPreview.d) }
        }
        Rectangle {
            visible: lockPreview.opt("iris.lock.blocks.session.enable", true)
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Number(lockPreview.opt("iris.lock.blocks.session.width", 248)) * 0.65
            Layout.preferredHeight: Math.round(32 * lockPreview.d)
            radius: height / 2
            color: IrisStyle.onMediaFill
            MaterialSymbol { anchors.centerIn: parent; text: "lock"; color: IrisStyle.onMedia; iconSize: Math.round(18 * lockPreview.d) }
        }
        IrisText {
            visible: lockPreview.opt("iris.lock.blocks.media.enable", true)
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            text: MprisController.titleOf(MprisController.activePlayer) || Translation.tr("Now playing")
            color: IrisStyle.onMediaSecondary
            elide: Text.ElideRight
        }
    }
    Caption { glyph: "lock"; text: Translation.tr("Your lock screen, without locking") }
}
