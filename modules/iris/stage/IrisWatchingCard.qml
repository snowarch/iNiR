pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.bar.island

ColumnLayout {
    id: continuing
    readonly property real d: IrisStyle.density
    signal closeRequested()
    readonly property var entries: AnimeWatch.shows
    spacing: 8 * continuing.d
    Component.onCompleted: AnimeWatch.reload()
    CardHeader {
        glyph: IrisPieces.glyphOf("watching", "")
        tint: IrisStyle.identity.pink
        title: Translation.tr("Continue")
        detail: AnimeWatch.betweenEpisodes
            ? Translation.tr("What next?")
            : AnimeWatch.phase === "searching"
            ? Translation.tr("Looking for “%1”").arg(AnimeWatch.query)
            : AnimeWatch.phase === "launching"
            ? (AnimeWatch.busyEpisode.length > 0
                ? Translation.tr("Starting episode %1…").arg(AnimeWatch.busyEpisode) : Translation.tr("Starting…"))
            : AnimeWatch.phase === "playing"
                ? Translation.tr("Playing episode %1").arg(AnimeWatch.busyEpisode)
                : AnimeWatch.error.length > 0
                    ? AnimeWatch.error
                    : continuing.entries.length > 0
                        ? Translation.tr("%1 · %2 in progress").arg(AnimeWatch.cli).arg(continuing.entries.length)
                        : AnimeWatch.available ? Translation.tr("Nothing watched yet")
                            : Translation.tr("No anime CLI found")
        IrisIconButton {
            visible: AnimeWatch.running && !AnimeWatch.choosing && AnimeWatch.phase !== "playing"
            materialIcon: "close"
            Accessible.name: Translation.tr("Stop")
            onClicked: AnimeWatch.cancel()
        }
        IrisIconButton {
            visible: !AnimeWatch.busy
            materialIcon: "refresh"
            Accessible.name: Translation.tr("Check again")
            onClicked: AnimeWatch.refresh()
        }
    }
    IrisButton {
        Layout.fillWidth: true
        visible: !AnimeWatch.canTarget
        enabled: AnimeWatch.available
        text: AnimeWatch.available ? Translation.tr("Resume in %1").arg(AnimeWatch.cli) : Translation.tr("Resume")
        buttonRadius: IrisStyle.radiusTile
        implicitHeight: Math.round(38 * continuing.d)
        onClicked: { continuing.closeRequested(); AnimeWatch.resume(null) }
    }
    IrisField {
        id: watchSearch
        Layout.fillWidth: true
        visible: AnimeWatch.canTarget && !AnimeWatch.busy
        implicitHeight: Math.round(38 * continuing.d)
        topPadding: 0
        bottomPadding: 0
        verticalAlignment: TextInput.AlignVCenter
        font.pixelSize: IrisStyle.typeLabel
        placeholderText: Translation.tr("Search anime")
        onAccepted: {
            AnimeWatch.search(text)
            text = ""
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: AnimeWatch.choosing
        spacing: Math.round(6 * continuing.d)
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(6 * continuing.d)
            Layout.rightMargin: Math.round(8 * continuing.d)
            IrisText {
                Layout.fillWidth: true
                text: AnimeWatch.betweenEpisodes
                    ? Translation.tr("Episode finished")
                    : AnimeWatch.pickingShow
                        ? Translation.tr("Which one?")
                        : AnimeWatch.pickingQuality
                            ? Translation.tr("Which quality?")
                            : Translation.tr("Which episode?")
                color: IrisStyle.muted
                font.pixelSize: IrisStyle.typeFootnote
            }
            IrisIconButton {
                materialIcon: "close"
                Accessible.name: Translation.tr("Cancel")
                onClicked: AnimeWatch.cancel()
            }
        }
        Repeater {
            model: AnimeWatch.pickingShow ? AnimeWatch.pickItems : []
            MouseArea {
                id: showPick
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Math.round(40 * continuing.d)
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                Accessible.role: Accessible.Button
                Accessible.name: AnimeWatch.pickLabel(showPick.modelData)
                onClicked: AnimeWatch.choose(AnimeWatch.pickValue(showPick.modelData))
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.radiusTile
                    color: showPick.containsMouse ? IrisStyle.fillHover : "transparent"
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                }
                IrisText {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(10 * continuing.d)
                    anchors.rightMargin: Math.round(10 * continuing.d)
                    verticalAlignment: Text.AlignVCenter
                    text: AnimeWatch.pickLabel(showPick.modelData)
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.pixelSize: IrisStyle.typeLabel
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(6 * continuing.d)
            Layout.rightMargin: Math.round(8 * continuing.d)
            visible: AnimeWatch.betweenEpisodes || AnimeWatch.pickingQuality
            spacing: Math.round(5 * continuing.d)
            Repeater {
                model: AnimeWatch.betweenEpisodes || AnimeWatch.pickingQuality ? AnimeWatch.pickItems : []
                MouseArea {
                    id: actionChip
                    required property var modelData
                    readonly property string action: AnimeWatch.pickValue(actionChip.modelData)
                    readonly property bool primary: actionChip.action === "next"
                    implicitWidth: actionLabel.implicitWidth + Math.round(20 * continuing.d)
                    implicitHeight: Math.round(28 * continuing.d)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    Accessible.role: Accessible.Button
                    Accessible.name: actionLabel.text
                    onClicked: AnimeWatch.choose(actionChip.action)
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.radiusChip
                        color: actionChip.primary
                            ? (actionChip.containsMouse ? IrisStyle.tintFillHover(IrisStyle.identity.pink) : IrisStyle.tintFill(IrisStyle.identity.pink))
                            : (actionChip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet)
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    }
                    IrisText {
                        id: actionLabel
                        anchors.centerIn: parent
                        text: AnimeWatch.pickingQuality ? AnimeWatch.pickLabel(actionChip.modelData) : AnimeWatch.actionLabel(actionChip.action)
                        color: actionChip.primary ? IrisStyle.identity.pink : IrisStyle.textSecondary
                        font.pixelSize: IrisStyle.typeFootnote
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Math.round(6 * continuing.d)
            Layout.rightMargin: Math.round(8 * continuing.d)
            visible: AnimeWatch.pickingEpisode
            spacing: Math.round(5 * continuing.d)
            Repeater {
                model: AnimeWatch.pickingEpisode ? AnimeWatch.pickItems : []
                MouseArea {
                    id: epPick
                    required property var modelData
                    implicitWidth: Math.max(Math.round(28 * continuing.d), epLabel.implicitWidth + Math.round(14 * continuing.d))
                    implicitHeight: Math.round(26 * continuing.d)
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Episode %1").arg(epLabel.text)
                    onClicked: AnimeWatch.choose(AnimeWatch.pickValue(epPick.modelData))
                    Rectangle {
                        anchors.fill: parent
                        radius: IrisStyle.radiusChip
                        color: epPick.containsMouse ? IrisStyle.tintFill(IrisStyle.identity.pink) : IrisStyle.fillQuiet
                        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    }
                    IrisText {
                        id: epLabel
                        anchors.centerIn: parent
                        text: String(epPick.modelData)
                        color: epPick.containsMouse ? IrisStyle.identity.pink : IrisStyle.textSecondary
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: IrisStyle.typeFootnote
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.round(6 * continuing.d)
        Layout.rightMargin: Math.round(8 * continuing.d)
        visible: AnimeWatch.subtitles.length > 0
        spacing: Math.round(6 * continuing.d)
        IrisText {
            text: Translation.tr("Subtitles")
            color: IrisStyle.muted
            font.pixelSize: IrisStyle.typeFootnote
        }
        Item { Layout.fillWidth: true }
        Repeater {
            model: [{ id: 0, off: true }].concat(AnimeWatch.subtitles)
            MouseArea {
                id: subChip
                required property var modelData
                required property int index
                readonly property bool off: modelData.off === true
                readonly property int trackId: subChip.off ? 0 : Number(modelData.id) || 0
                readonly property bool active: AnimeWatch.subtitleId === subChip.trackId
                implicitWidth: subLabel.implicitWidth + Math.round(16 * continuing.d)
                implicitHeight: Math.round(22 * continuing.d)
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                Accessible.role: Accessible.RadioButton
                Accessible.checked: subChip.active
                Accessible.name: subLabel.text
                onClicked: AnimeWatch.selectSubtitle(subChip.trackId)
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.radiusChip
                    color: subChip.active ? IrisStyle.tintFill(IrisStyle.identity.pink)
                        : subChip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                }
                IrisText {
                    id: subLabel
                    anchors.centerIn: parent
                    text: subChip.off ? Translation.tr("Off")
                        : AnimeWatch.subtitleLabel(subChip.modelData, subChip.index - 1)
                    color: subChip.active ? IrisStyle.identity.pink : IrisStyle.textSecondary
                    font.pixelSize: IrisStyle.typeFootnote
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
            }
        }
    }
    Repeater {
        model: AnimeWatch.choosing ? [] : continuing.entries
        MouseArea {
            id: watchRow
            required property var modelData
            readonly property var state: AnimeWatch.stateOf(watchRow.modelData)
            readonly property string targetEpisode: watchRow.state.episode
            readonly property double targetStart: watchRow.state.start
            readonly property bool mine: AnimeWatch.isBusyFor(watchRow.modelData)
            Layout.fillWidth: true
            implicitHeight: Math.round(46 * continuing.d)
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: AnimeWatch.canTarget && !AnimeWatch.busy
            opacity: !AnimeWatch.busy || watchRow.mine ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("Resume %1 episode %2").arg(watchRow.modelData.title).arg(watchRow.targetEpisode)
            onClicked: AnimeWatch.resume(watchRow.modelData)
            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusTile
                color: watchRow.pressed ? IrisStyle.fillActive : watchRow.containsMouse ? IrisStyle.fillHover : "transparent"
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(6 * continuing.d)
                anchors.rightMargin: Math.round(8 * continuing.d)
                spacing: 10 * continuing.d
                ClippingRectangle {
                    id: posterFrame
                    readonly property string cover: AnimeWatch.coverOf(watchRow.modelData)
                    readonly property bool marked: watchRow.mine || watchRow.containsMouse || poster.status !== Image.Ready
                    implicitWidth: Math.round(28 * continuing.d)
                    implicitHeight: Math.round(38 * continuing.d)
                    radius: IrisStyle.iconRadius(width)
                    color: watchRow.mine || watchRow.containsMouse
                        ? IrisStyle.tintFill(IrisStyle.identity.pink) : IrisStyle.fillQuiet
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                    IrisImage {
                        id: poster
                        anchors.fill: parent
                        source: posterFrame.cover
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: poster.status === Image.Ready && posterFrame.marked
                        color: IrisStyle.veilStrong
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: posterFrame.marked
                        text: watchRow.mine && AnimeWatch.phase === "playing" ? "graphic_eq" : "play_arrow"
                        fill: 1
                        iconSize: Math.round(15 * continuing.d)
                        color: IrisStyle.identity.pink
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: watchRow.modelData.title
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: IrisStyle.typeLabel
                        font.weight: IrisStyle.weight(Font.DemiBold)
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: watchRow.mine
                            ? (AnimeWatch.phase === "playing" ? Translation.tr("Playing") : Translation.tr("Starting…"))
                            : watchRow.targetStart > 0.5
                                ? Translation.tr("%1 in").arg(AnimeWatch.clock(watchRow.targetStart))
                                : String(watchRow.modelData.total).length > 0
                                    ? Translation.tr("of %1").arg(watchRow.modelData.total)
                                    : ""
                        color: watchRow.mine || watchRow.targetStart > 0.5 ? IrisStyle.identity.pink : IrisStyle.muted
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: IrisStyle.typeFootnote
                    }
                }
                Metric {
                    value: watchRow.targetEpisode
                    unit: Translation.tr("ep")
                    pixelSize: IrisStyle.typeLabel
                }
            }
        }
    }
    IrisText {
        Layout.fillWidth: true
        visible: continuing.entries.length === 0 && !AnimeWatch.busy && !AnimeWatch.choosing
        text: AnimeWatch.canTarget
            ? Translation.tr("Search above to start watching")
            : AnimeWatch.available
                ? Translation.tr("%1 keeps your place; what you watch shows up here").arg(AnimeWatch.cli)
                : Translation.tr("Install ani-cli to search and watch from here")
        color: IrisStyle.muted
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: IrisStyle.typeMeta
    }
    IrisText {
        Layout.fillWidth: true
        visible: (continuing.entries.length > 0 || AnimeWatch.busy) && !AnimeWatch.choosing
        text: AnimeWatch.phase === "searching"
            ? Translation.tr("Searching…")
            : AnimeWatch.phase === "launching"
            ? Translation.tr("Finding the stream")
            : AnimeWatch.phase === "playing"
                ? Translation.tr("Your place is saved as you watch")
                : AnimeWatch.busy
                    ? Translation.tr("Waiting for ani-cli")
                    : AnimeWatch.canTarget
                        ? Translation.tr("Tap a show to continue it")
                        : Translation.tr("%1 picks what to resume").arg(AnimeWatch.cli)
        color: IrisStyle.muted
        font.pixelSize: IrisStyle.typeMeta
        horizontalAlignment: Text.AlignHCenter
    }
}
