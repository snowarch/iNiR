pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.common
import qs.modules.iris.style
import "../components"

// AIRISU's OSD (board Desktop): a level is its figure wide, a tachometer of twenty ascending steps whose last three
// are the red line, and its name in mono standing on end. Media, keyboard, devices and warnings keep the same plate:
// a mono caption over the fact, wide. IrisOSD keeps the triggers, the window and the body.
Item {
    id: root
    property var osd
    readonly property real d: Airisu.d
    readonly property string kind: root.osd?.kind ?? "volume"
    readonly property bool level: root.osd?.level ?? true
    implicitWidth: root.level ? Math.round(396 * root.d) : Math.min(Math.round(440 * root.d), fact.implicitWidth + Airisu.pad * 2)
    implicitHeight: Math.round(64 * root.d)

    // ── Levels ──────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: root.level
        AText {
            id: figure
            x: Airisu.pad
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(64 * root.d)
            voice: root.osd?.muted ? "mono" : "wide"
            size: root.osd?.muted ? IrisStyle.typeMeta : IrisStyle.typeDisplay + Math.round(8 * IrisStyle.typeScale)
            font.weight: Font.Black
            color: root.osd?.muted ? Airisu.sealText : Airisu.gofun
            text: root.osd?.muted ? Translation.tr("Muted") : Math.round((root.osd?.value ?? 0) * 100)
        }
        AMeter {
            anchors.left: figure.right
            anchors.leftMargin: Math.round(14 * root.d)
            anchors.right: name.left
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(26 * root.d)
            ascending: true
            interactive: false
            value: root.osd?.muted ? 0 : (root.osd?.value ?? 0)
        }
        // The name stands on end, read top to bottom: the slot is the text's height wide.
        Item {
            id: name
            anchors.right: parent.right
            anchors.rightMargin: Math.round(12 * root.d)
            anchors.verticalCenter: parent.verticalCenter
            width: label.implicitHeight
            height: label.implicitWidth
            AText {
                id: label
                anchors.centerIn: parent
                elide: Text.ElideNone
                rotation: 90
                voice: "mono"
                color: Airisu.quiet
                text: root.kind === "brightness" ? "BRI" : root.kind === "mic" ? "MIC" : "VOL"
            }
        }
    }

    // ── Everything else: a caption and the fact ────────────────────────────
    Column {
        id: fact
        visible: !root.level
        anchors.left: parent.left
        anchors.leftMargin: Airisu.pad
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, root.width - Airisu.pad * 2)
        spacing: Math.round(2 * root.d)
        readonly property var connection: root.osd?.connection ?? null
        AText {
            voice: "mono"
            color: root.kind === "warning" || fact.connection?.tone === "warn" ? Airisu.amber : Airisu.quiet
            text: root.kind === "media" ? [root.osd?.mediaAction === "next" ? Translation.tr("Next") : root.osd?.mediaAction === "previous" ? Translation.tr("Previous")
                    : root.osd?.mediaAction === "pause" ? Translation.tr("Paused") : Translation.tr("Now playing"), root.osd?.mediaArtist ?? ""].filter(s => s.length > 0).join(" · ")
                : root.kind === "keyboard" ? Translation.tr("Keyboard")
                : root.kind === "warning" ? Translation.tr("Volume held back")
                : root.kind === "connection" ? [fact.connection?.detail ?? "", (fact.connection?.value ?? -1) >= 0 ? `${fact.connection.value}%` : ""].filter(s => s.length > 0).join(" · ")
                : ""
        }
        AText {
            width: Math.min(implicitWidth, Math.round(400 * root.d))
            voice: "wide"
            size: IrisStyle.typeTitle
            text: root.kind === "media" ? (root.osd?.mediaTitle || Translation.tr("Now playing"))
                : root.kind === "keyboard" ? (root.osd?.keyboardText ?? "")
                : root.kind === "warning" ? (root.osd?.warningText ?? "")
                : root.kind === "connection" ? (fact.connection?.title ?? "")
                : ""
        }
    }
}
