pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

// Material's Now Playing at rest: the song that played last (state dir, `Persistent.states.lastPlayed`), its cover
// leading. Small stacks the cover over the title; Medium sets the words beside it; Large gives the cover the top.
Item {
    id: root

    required property var widget
    readonly property var last: Persistent.states.lastPlayed
    readonly property bool known: String(root.last.title ?? "").length > 0
    readonly property string size: root.widget.materialSize
    readonly property real s: root.widget.scaleFactor
    function px(value: real): int { return Math.round(value * root.s) }
    readonly property color ink: root.widget.widgetInk
    readonly property color inkMuted: ColorUtils.applyAlpha(root.ink, 0.62)
    readonly property string when: {
        const minutes = Math.round((DateTime.clock.date.getTime() - Number(root.last.at ?? 0)) / 60000)
        const ago = minutes < 1 ? Translation.tr("Now") : minutes < 60 ? Translation.tr("%1 min ago").arg(minutes)
            : minutes < 1440 ? Translation.tr("%1 h ago").arg(Math.round(minutes / 60))
            : Translation.tr("%1 days ago").arg(Math.round(minutes / 1440))
        return [String(root.last.source ?? ""), ago].filter(part => part.length > 0).join(" · ")
    }

    component Cover: Rectangle {
        id: cover
        radius: Math.max(root.px(8), Math.round(width * 0.12))
        color: root.widget.widgetSemanticContainer(root.widget.widgetPrimaryRole)
        clip: true
        StyledImage {
            anchors.fill: parent
            visible: status === Image.Ready
            source: String(root.last.art ?? "").length > 0 ? "file://" + String(root.last.art).replace(/^file:\/\//, "") : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            layer.enabled: true
            layer.effect: GE.OpacityMask { maskSource: Rectangle { width: cover.width; height: cover.height; radius: cover.radius } }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            visible: String(root.last.art ?? "").length === 0
            text: "music_note"
            fill: 1
            iconSize: Math.round(parent.width * 0.4)
            color: root.widget.widgetSemanticOnContainer(root.widget.widgetPrimaryRole)
        }
    }

    component Words: ColumnLayout {
        property bool centred: false
        spacing: root.px(1)
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Last played")
            horizontalAlignment: parent.centred ? Text.AlignHCenter : Text.AlignLeft
            color: root.widget.widgetAccentVisible
            elide: Text.ElideRight
            font.pixelSize: root.px(Appearance.font.pixelSize.smaller)
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            text: String(root.last.title ?? "")
            horizontalAlignment: parent.centred ? Text.AlignHCenter : Text.AlignLeft
            color: root.ink
            elide: Text.ElideRight
            font.family: root.widget.widgetTitleFamily
            font.pixelSize: root.px(Appearance.font.pixelSize.normal)
            font.weight: Font.DemiBold
        }
        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: String(root.last.artist ?? "")
            horizontalAlignment: parent.centred ? Text.AlignHCenter : Text.AlignLeft
            color: root.inkMuted
            elide: Text.ElideRight
            font.pixelSize: root.px(Appearance.font.pixelSize.small)
        }
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: root.px(3)
            visible: !parent.centred
            text: root.when
            color: root.inkMuted
            elide: Text.ElideRight
            font.pixelSize: root.px(Appearance.font.pixelSize.smallest)
        }
    }

    // Small: the cover over its song.
    Item {
        anchors.fill: parent
        anchors.margins: root.px(14)
        visible: root.size === "small"
        Cover {
            width: Math.min(parent.width, parent.height - smallTitle.height - root.px(8))
            height: width
            x: Math.round((parent.width - width) / 2)
        }
        StyledText {
            id: smallTitle
            y: parent.height - height
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: String(root.last.title ?? "")
            color: root.ink
            elide: Text.ElideRight
            font.pixelSize: root.px(Appearance.font.pixelSize.small)
            font.weight: Font.DemiBold
        }
    }

    // Medium: the cover beside the words.
    RowLayout {
        anchors.fill: parent
        anchors.margins: root.px(16)
        visible: root.size === "medium"
        spacing: root.px(14)
        Cover {
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height
        }
        Words {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }

    // Large: the cover on top, the words under it.
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.px(16)
        visible: root.size === "large"
        spacing: root.px(12)
        Cover {
            Layout.preferredWidth: Math.min(parent.width, parent.height - largeWords.implicitHeight - root.px(12))
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignHCenter
        }
        Words {
            id: largeWords
            Layout.fillWidth: true
        }
    }
}
