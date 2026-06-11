pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root
    visible: GlobalStates.videoEditorOpen
    
    color: "transparent"
    
    WlrLayershell.namespace: "quickshell:videoEditor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MediaPlayer {
        id: player
        source: GlobalStates.videoEditorPath !== "" ? "file://" + GlobalStates.videoEditorPath : ""
        videoOutput: videoOutput
        audioOutput: AudioOutput {}
        loops: MediaPlayer.Infinite
        
        onPositionChanged: {
            if (player.position >= root.effectiveEndTime - 50) {
                player.position = root.startTime
            }
            if (player.position < root.startTime) {
                player.position = root.startTime
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            player.play()
            cropW = -1
            startTime = 0
            endTime = -1
        } else {
            player.stop()
        }
    }

    property real cropX: 0
    property real cropY: 0
    property real cropW: -1 
    property real cropH: -1
    property real startTime: 0
    property real endTime: -1
    readonly property real effectiveEndTime: endTime === -1 ? player.duration : endTime

    function applyPreset(ratio) {
        let vW = videoOutput.contentRect.width
        let vH = videoOutput.contentRect.height
        if (vW <= 0 || vH <= 0) return

        if (ratio === -1) {
            cropW = vW
            cropH = vH
            cropX = 0
            cropY = 0
            return
        }
        
        if (vW / vH > ratio) {
            cropH = vH
            cropW = vH * ratio
        } else {
            cropW = vW
            cropH = vW / ratio
        }
        cropX = (vW - cropW) / 2
        cropY = (vH - cropH) / 2
    }

    function save(replace) {
        if (videoOutput.contentRect.width <= 0) return
        
        let args = [
            Quickshell.shellPath("scripts/videos/process_video.sh"),
            GlobalStates.videoEditorPath,
            Math.round(cropW),
            Math.round(cropH),
            Math.round(cropX),
            Math.round(cropY),
            Math.round(startTime),
            Math.round(effectiveEndTime),
            Math.round(videoOutput.contentRect.width),
            Math.round(videoOutput.contentRect.height),
            replace ? "1" : "0"
        ]
        Quickshell.execDetached(args)
        GlobalStates.videoEditorOpen = false
    }

    Rectangle {
        id: mainContainer
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.9, 1400)
        height: Math.min(parent.height * 0.9, 900)
        radius: Appearance.rounding.windowRounding
        
        color: Config.options.appearance.transparency.enable ? Appearance.colors.colLayer1 : Appearance.m3colors.m3surfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Keys.onSpacePressed: {
            if (player.playbackState === MediaPlayer.PlayingState) player.pause()
            else player.play()
        }
        Keys.onEscapePressed: GlobalStates.videoEditorOpen = false
        focus: root.visible

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                MaterialSymbol {
                    text: "movie_edit"
                    iconSize: 42
                    color: Appearance.colors.colPrimary
                }
                StyledText {
                    text: Translation.tr("Video Editor")
                    font.pixelSize: 32
                    font.weight: Font.Bold
                    color: Appearance.colors.colOnSurface
                }
                Item { Layout.fillWidth: true }
                
                RippleButton {
                    id: closeBtn
                    width: 52
                    height: 52
                    buttonRadius: 26
                    colBackground: Appearance.colors.colSurfaceContainerHighest
                    contentItem: Item {
                        MaterialSymbol { 
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: 24
                            color: Appearance.colors.colOnSurface 
                        }
                    }
                    onClicked: GlobalStates.videoEditorOpen = false
                }
            }

            Item {
                id: videoContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                VideoOutput {
                    id: videoOutput
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    fillMode: VideoOutput.PreserveAspectFit

                    Item {
                        anchors.fill: parent
                        visible: root.cropW !== -1
                        Rectangle { x: videoOutput.contentRect.x; y: videoOutput.contentRect.y; width: videoOutput.contentRect.width; height: root.cropY; color: "#aa000000" }
                        Rectangle { x: videoOutput.contentRect.x; y: videoOutput.contentRect.y + root.cropY + root.cropH; width: videoOutput.contentRect.width; height: videoOutput.contentRect.height - (root.cropY + root.cropH); color: "#aa000000" }
                        Rectangle { x: videoOutput.contentRect.x; y: videoOutput.contentRect.y + root.cropY; width: root.cropX; height: root.cropH; color: "#aa000000" }
                        Rectangle { x: videoOutput.contentRect.x + root.cropX + root.cropW; y: videoOutput.contentRect.y + root.cropY; width: videoOutput.contentRect.width - (root.cropX + root.cropW); height: root.cropH; color: "#aa000000" }
                    }

                    Rectangle {
                        id: cropBox
                        visible: root.cropW !== -1
                        x: videoOutput.contentRect.x + root.cropX
                        y: videoOutput.contentRect.y + root.cropY
                        width: root.cropW
                        height: root.cropH
                        color: "transparent"
                        border.color: Appearance.colors.colPrimary
                        border.width: 2

                        MouseArea {
                            anchors.fill: parent
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let newX = Math.max(videoOutput.contentRect.x, Math.min(videoOutput.contentRect.x + videoOutput.contentRect.width - parent.width, parent.x + mouse.x - width/2))
                                    let newY = Math.max(videoOutput.contentRect.y, Math.min(videoOutput.contentRect.y + videoOutput.contentRect.height - parent.height, parent.y + mouse.y - height/2))
                                    root.cropX = newX - videoOutput.contentRect.x
                                    root.cropY = newY - videoOutput.contentRect.y
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            width: 32
                            height: 32
                            radius: 16
                            color: Appearance.colors.colPrimary
                            MaterialSymbol { anchors.centerIn: parent; text: "expand_content"; iconSize: 20; color: Appearance.colors.colOnPrimary }
                            
                            MouseArea {
                                anchors.fill: parent
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        let newW = Math.max(50, parent.parent.width + mouse.x)
                                        let newH = Math.max(50, parent.parent.height + mouse.y)
                                        if (parent.parent.x + newW <= videoOutput.contentRect.x + videoOutput.contentRect.width) root.cropW = newW
                                        if (parent.parent.y + newH <= videoOutput.contentRect.y + videoOutput.contentRect.height) root.cropH = newH
                                    }
                                }
                            }
                        }
                    }
                }

                RippleButton {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.margins: 16
                    width: 56
                    height: 56
                    buttonRadius: 28
                    colBackground: "#aa000000"
                    contentItem: Item {
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                            iconSize: 32
                            color: "white"
                        }
                    }
                    onClicked: {
                        if (player.playbackState === MediaPlayer.PlayingState) player.pause()
                        else player.play()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 24

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StyledText { text: Translation.tr("Trim Video"); font.weight: Font.Medium; color: Appearance.colors.colOnSurface }
                    Item {
                        id: timeline
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: Appearance.colors.colSurfaceContainer
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: 8; color: Appearance.colors.colLayer1 }
                            MouseArea {
                                anchors.fill: parent
                                onPressed: (mouse) => {
                                    let pos = Math.max(0, Math.min(1, mouse.x / width))
                                    player.position = pos * player.duration
                                }
                            }
                        }
                        Rectangle {
                            x: (root.startTime / player.duration) * parent.width
                            width: ((root.effectiveEndTime - root.startTime) / player.duration) * parent.width
                            height: parent.height
                            color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.3)
                        }
                        Rectangle {
                            x: (player.position / player.duration) * parent.width - 2
                            width: 4; height: parent.height; color: Appearance.colors.colSecondary
                        }
                        Rectangle {
                            id: startHandle
                            x: (root.startTime / player.duration) * parent.width - 15
                            width: 30; height: parent.height; radius: 6; color: Appearance.colors.colPrimary
                            MaterialSymbol { anchors.centerIn: parent; text: "chevron_right"; iconSize: 18; color: Appearance.colors.colOnPrimary }
                            MouseArea {
                                anchors.fill: parent
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        let newX = Math.max(-15, Math.min(endHandle.x - 40, parent.x + mouse.x - width/2))
                                        root.startTime = Math.max(0, (newX + 15) / timeline.width * player.duration)
                                        player.position = root.startTime
                                    }
                                }
                                onPressed: player.pause(); onReleased: player.play()
                            }
                        }
                        Rectangle {
                            id: endHandle
                            x: (root.effectiveEndTime / player.duration) * parent.width - 15
                            width: 30; height: parent.height; radius: 6; color: Appearance.colors.colPrimary
                            MaterialSymbol { anchors.centerIn: parent; text: "chevron_left"; iconSize: 18; color: Appearance.colors.colOnPrimary }
                            MouseArea {
                                anchors.fill: parent
                                onPositionChanged: (mouse) => {
                                    if (pressed) {
                                        let newX = Math.max(startHandle.x + 40, Math.min(timeline.width - 15, parent.x + mouse.x - width/2))
                                        root.endTime = Math.min(player.duration, (newX + 15) / timeline.width * player.duration)
                                        player.position = root.endTime
                                    }
                                }
                                onPressed: player.pause(); onReleased: player.play()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    Layout.alignment: Qt.AlignBottom

                    ColumnLayout {
                        spacing: 8
                        StyledText { text: Translation.tr("Aspect Ratio"); font.weight: Font.Medium; color: Appearance.colors.colOnSurface }
                        RowLayout {
                            spacing: 8
                            Repeater {
                                model: [
                                    { name: "Free", ratio: -1, icon: "aspect_ratio" },
                                    { name: "16:9", ratio: 1.7777777777777777, icon: "rectangle" },
                                    { name: "9:16", ratio: 0.5625, icon: "smartphone" },
                                    { name: "4:3", ratio: 1.3333333333333333, icon: "desktop_windows" },
                                    { name: "1:1", ratio: 1, icon: "square" }
                                ]
                                delegate: RippleButton {
                                    id: ratioBtn
                                    required property var modelData
                                    implicitWidth: 100
                                    implicitHeight: 44
                                    buttonRadius: 22
                                    property bool isActive: root.cropW !== -1 && Math.abs((root.cropW/root.cropH) - ratioBtn.modelData.ratio) < 0.01 || (root.cropW === videoOutput.contentRect.width && ratioBtn.modelData.ratio === -1)
                                    colBackground: isActive ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest
                                    contentItem: Item {
                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            MaterialSymbol { text: ratioBtn.modelData.icon; iconSize: 18; color: ratioBtn.isActive ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface }
                                            StyledText { text: ratioBtn.modelData.name; font.weight: Font.Medium; color: ratioBtn.isActive ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface }
                                        }
                                    }
                                    onClicked: root.applyPreset(ratioBtn.modelData.ratio)
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignBottom
                        
                        RippleButton {
                            implicitWidth: 180
                            implicitHeight: 56
                            buttonRadius: 28
                            colBackground: Appearance.colors.colSurfaceContainerHighest
                            contentItem: Item {
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    MaterialSymbol { text: "content_copy"; iconSize: 24; color: Appearance.colors.colOnSurface }
                                    StyledText { text: Translation.tr("Save Copy"); font.pixelSize: 16; font.weight: Font.Bold; color: Appearance.colors.colOnSurface }
                                }
                            }
                            onClicked: root.save(false)
                        }

                        RippleButton {
                            implicitWidth: 220
                            implicitHeight: 56
                            buttonRadius: 28
                            colBackground: Appearance.colors.colPrimary
                            contentItem: Item {
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 12
                                    MaterialSymbol { text: "check_circle"; iconSize: 24; color: Appearance.colors.colOnPrimary }
                                    StyledText { text: Translation.tr("Save and Replace"); font.pixelSize: 16; font.weight: Font.Bold; color: Appearance.colors.colOnPrimary }
                                }
                            }
                            onClicked: root.save(true)
                        }
                    }
                }
            }
        }
    }
}
