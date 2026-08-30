pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Recorder surface: start/stop screen recording from the pill. Upstream's
 * recorder carried its own 1400-line wf-recorder pipeline; iNiR already owns
 * one (scripts/videos/record.sh + RecorderStatus), so this surface is a thin
 * Ricelin-dialect face over that — two capture actions, the configured audio
 * profile, and a live elapsed counter while a recording runs.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 14

    readonly property bool recording: RecorderStatus.isRecording
    readonly property string audioMode: RecorderStatus.configuredAudioMode
    readonly property bool withSound: audioMode !== "none"

    function audioModeLabel(mode) {
        switch (mode) {
        case "microphone": return Translation.tr("Microphone")
        case "both": return Translation.tr("System + microphone")
        case "none": return Translation.tr("No audio")
        default: return Translation.tr("System audio")
        }
    }

    readonly property string elapsed: {
        const t = Math.max(0, RecorderStatus.elapsedSeconds);
        const m = Math.floor(t / 60);
        const sec = t % 60;
        return String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0");
    }

    function start(fullscreen) {
        const args = ["/usr/bin/bash", Directories.recordScriptPath];
        if (fullscreen)
            args.push("--fullscreen");
        if (root.withSound)
            args.push("--sound");
        Quickshell.execDetached(args);
        RecorderStatus.scheduleQuickCheck();
        // Region capture hands the screen to slurp; the pill must get out of
        // the way either way.
        root.requestClose();
    }

    function stop() {
        Quickshell.execDetached(["/usr/bin/bash", Directories.recordScriptPath, "--stop"]);
        RecorderStatus.scheduleQuickCheck();
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: PillTheme.showGlyphs
                text: PillTheme.glyph("recorder")
                color: PillTheme.cream
                font.family: PillTheme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Translation.tr("RECORD")
                color: PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11.5 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s
            visible: root.recording

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8 * root.s
                height: 8 * root.s
                radius: width / 2
                color: PillTheme.verm

                SequentialAnimation on opacity {
                    running: root.recording && root.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.elapsed
                color: PillTheme.cream
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: PillTheme.hair
    }

    /** Large capture-action card, one per mode. */
    component ActionCard: Rectangle {
        id: card
        property string glyph: ""
        property string label: ""
        property string sub: ""
        signal triggered()

        height: 64 * root.s
        radius: 10 * root.s
        color: cardArea.containsMouse ? PillTheme.frameBg : Qt.alpha(PillTheme.cream, 0.025)
        border.width: 1
        border.color: cardArea.containsMouse ? PillTheme.frameBorder : PillTheme.border
        Behavior on color { ColorAnimation { duration: PillMotion.fast } }

        Column {
            anchors.centerIn: parent
            spacing: 5 * root.s

            GlyphIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 18 * root.s
                height: 18 * root.s
                name: card.glyph
                color: cardArea.containsMouse ? PillTheme.vermLit : PillTheme.iconDim
                stroke: 1.7
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.label
                color: cardArea.containsMouse ? PillTheme.cream : PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: cardArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.triggered()
        }
    }

    /** Idle face: pick a capture mode. */
    Item {
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !root.recording

        Row {
            id: actions
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10 * root.s

            ActionCard {
                width: (parent.width - 10 * root.s) / 2
                glyph: "scaling"
                label: Translation.tr("Region")
                onTriggered: root.start(false)
            }
            ActionCard {
                width: (parent.width - 10 * root.s) / 2
                glyph: "monitor"
                label: Translation.tr("Screen")
                onTriggered: root.start(true)
            }
        }

        Row {
            anchors.top: actions.bottom
            anchors.topMargin: 10 * root.s
            anchors.left: parent.left
            spacing: 8 * root.s

            Rectangle {
                id: soundChip
                anchors.verticalCenter: parent.verticalCenter
                width: 34 * root.s
                height: 34 * root.s
                radius: 8 * root.s
                color: root.withSound ? PillTheme.frameBg : "transparent"
                border.width: 1
                border.color: root.withSound ? PillTheme.frameBorder : PillTheme.border

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 18 * root.s
                    height: 18 * root.s
                    name: root.withSound ? "speaker" : "speaker-off"
                    color: root.withSound ? PillTheme.vermLit : PillTheme.iconDim
                    stroke: 1.7
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: RecorderStatus.setConfiguredAudioMode(root.withSound ? "none" : "system")
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.audioModeLabel(root.audioMode)
                color: root.withSound ? PillTheme.cream : PillTheme.dim
                font.family: PillTheme.font
                font.pixelSize: 10.5 * root.s
                font.weight: Font.Medium
            }
        }
    }

    /** Recording face: hero counter and a stop bar. */
    Item {
        anchors.top: divider.bottom
        anchors.topMargin: 10 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: root.recording

        Text {
            id: heroElapsed
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.elapsed
            color: PillTheme.cream
            font.family: PillTheme.font
            font.pixelSize: 30 * root.s
            font.weight: Font.ExtraBold
            font.letterSpacing: -0.8 * root.s
            font.features: ({ "tnum": 1 })
        }

        Rectangle {
            anchors.top: heroElapsed.bottom
            anchors.topMargin: 10 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 36 * root.s
            radius: 9 * root.s
            color: stopArea.containsMouse ? Qt.alpha(PillTheme.verm, 0.18) : PillTheme.frameBg
            border.width: 1
            border.color: stopArea.containsMouse ? PillTheme.vermLit : PillTheme.frameBorder
            Behavior on color { ColorAnimation { duration: PillMotion.fast } }

            Text {
                anchors.centerIn: parent
                text: Translation.tr("Stop recording")
                color: stopArea.containsMouse ? PillTheme.vermLit : PillTheme.subtle
                font.family: PillTheme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: stopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.stop()
            }
        }
    }
}
