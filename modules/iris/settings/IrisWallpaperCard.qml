pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.components
import qs.modules.iris.preview
import qs.modules.iris.style
import qs.modules.iris.widgets
import qs.modules.settings

ClippingRectangle {
    id: card

    readonly property real d: IrisStyle.density
    readonly property int pad: Math.round(14 * card.d)
    readonly property int stageHeight: Math.round(228 * card.d)
    property var screen: GlobalStates.focusedScreen
    readonly property string current: Wallpapers.effectiveWallpaperPath
    readonly property string kind: Wallpapers.isVideoFile(card.current) ? Translation.tr("Live")
        : card.current.toLowerCase().endsWith(".gif") ? Translation.tr("Animated") : Translation.tr("Picture")
    readonly property string title: {
        const words = FileUtils.trimFileExt(FileUtils.fileNameForPath(card.current))
            .replace(/^(motionbgs|wallhaven|wallpaperflare|unsplash)[-_]/i, "")
            .split(/[-_\s]+/).filter(word => word.length > 0)
        if (words.length === 1 && /\d/.test(words[0]) && /^[a-z0-9]{4,10}$/i.test(words[0])) return ""
        return words.map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ")
    }
    readonly property string name: SystemInfo.displayName || SystemInfo.username
    readonly property string greeting: {
        const hour = DateTime.clock.date.getHours()
        return hour < 5 ? Translation.tr("Still up,") : hour < 12 ? Translation.tr("Good morning,")
            : hour < 19 ? Translation.tr("Good afternoon,") : Translation.tr("Good evening,")
    }
    readonly property string facts: [
        ShellUpdates.localVersion.length > 0 ? "iNiR " + ShellUpdates.localVersion : "iNiR",
        SystemInfo.distroName !== "Unknown" ? SystemInfo.distroName : "",
        card.screen ? `${desk.screenW} × ${desk.screenH}` : ""
    ].filter(part => part.length > 0).join("  ·  ")
    readonly property var nearby: {
        const all = (Wallpapers.wallpapers ?? []).filter(path => Wallpapers.extensions.includes(String(path).split(".").pop().toLowerCase()))
        if (all.length === 0) return []
        const at = Math.max(0, all.indexOf(card.current))
        const out = []
        for (let i = 0; i < Math.min(6, all.length); i++) out.push(all[(at + i) % all.length])
        return out
    }
    function apply(path: string): void {
        Wallpapers.applySelectionTarget(path, "main", Appearance.m3colors.darkmode, "")
    }
    function chooseAvatar(): void {
        avatarDialog.open()
    }
    FileDialog {
        id: avatarDialog
        title: Translation.tr("Profile picture")
        fileMode: FileDialog.OpenFile
        nameFilters: [Translation.tr("Images") + " (*.png *.jpg *.jpeg *.webp *.bmp *.avif)"]
        onAccepted: {
            setAvatar.command = [Quickshell.shellPath("scripts/accounts/set-avatar.sh"), FileUtils.trimFileProtocol(String(selectedFile))]
            setAvatar.running = true
        }
    }
    // Settings steps down a layer while the chooser is up, so the chooser is never under it.
    SettingsNativeDialogGuard {
        dialog: avatarDialog
        dialogKey: "iris-profile-picture"
    }
    Process {
        id: setAvatar
        onExited: exitCode => { if (exitCode === 0) Directories.userAvatarRevision++ }
    }
    function openGallery(): void {
        GlobalStates.settingsOverlayOpen = false
        GlobalStates.wallpaperSelectorOpen = true
    }

    Layout.fillWidth: true
    implicitHeight: card.stageHeight + (strip.visible ? strip.height + 2 * card.pad : 0)
    radius: IrisStyle.radiusTile
    color: IrisStyle.readingCard

    Item {
        id: stage
        width: parent.width
        height: card.stageHeight
        clip: true

        IrisImage {
            id: backdropSource
            anchors.fill: parent
            anchors.margins: -Math.round(48 * card.d)
            decodeWidth: 160
            decodeHeight: 90
            source: Wallpapers.effectiveWallpaperUrl
            visible: false
            // An effect samples this texture without mipmaps; a mipmapped one makes Qt rebuild its filtering.
            mipmap: false
        }
        MultiEffect {
            anchors.fill: parent
            anchors.margins: -Math.round(48 * card.d)
            source: backdropSource
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.15
        }
        Rectangle {
            anchors.fill: parent
            color: IrisStyle.veilStrong
        }

        RectangularShadow {
            anchors.fill: desk
            radius: desk.radius
            blur: Math.round(28 * card.d)
            offset.y: Math.round(8 * card.d)
            color: IrisStyle.shadow
        }
        IrisScreenPreview {
            id: desk
            anchors.left: parent.left
            anchors.leftMargin: Math.round(28 * card.d)
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(168 * card.d)
            width: Math.round(height * desk.screenW / desk.screenH)
            screen: card.screen
            radius: IrisStyle.radiusRow
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.openGallery()
            }
        }

        ColumnLayout {
            anchors.left: desk.right
            anchors.leftMargin: Math.round(28 * card.d)
            anchors.right: parent.right
            anchors.rightMargin: Math.round(24 * card.d)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(16 * card.d)
                MouseArea {
                    id: avatar
                    readonly property int size: Math.round(64 * card.d)
                    readonly property int ring: Math.max(2, Math.round(2 * card.d))
                    readonly property int air: Math.round(3 * card.d)
                    Layout.preferredWidth: avatar.size
                    Layout.preferredHeight: avatar.size
                    Layout.alignment: Qt.AlignVCenter
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: Translation.tr("Change profile picture")
                    onClicked: card.chooseAvatar()
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.width: avatar.ring
                        border.color: IrisStyle.accentOnMedia
                        opacity: avatar.containsMouse ? 1 : 0.85
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    }
                    FaceAvatar {
                        anchors.fill: parent
                        anchors.margins: avatar.ring + avatar.air
                        scale: avatar.pressed ? IrisStyle.pressScale(0.96) : 1
                        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: Math.round(22 * card.d)
                        height: width
                        radius: width / 2
                        color: IrisStyle.accent
                        border.width: avatar.ring
                        border.color: IrisStyle.bodySurface
                        opacity: avatar.containsMouse ? 1 : 0
                        scale: avatar.containsMouse ? 1 : 0.6
                        Behavior on opacity { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                        Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "edit"
                            fill: 1
                            iconSize: Math.round(12 * card.d)
                            color: IrisStyle.onTintFor(IrisStyle.accent)
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: card.greeting
                        color: IrisStyle.onMediaSecondary
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: IrisStyle.typeTitleLarge
                        font.weight: IrisStyle.weight(Font.Normal)
                        elide: Text.ElideRight
                    }
                    IrisText {
                        Layout.fillWidth: true
                        role: IrisText.Display
                        text: card.name
                        color: IrisStyle.accentOnMedia
                        elide: Text.ElideRight
                    }
                }
            }
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(12 * card.d)
                text: card.facts
                color: IrisStyle.onMediaSecondary
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.topMargin: Math.round(14 * card.d)
                spacing: Math.round(8 * card.d)
                GlassButton { glyph: "photo_library"; label: Translation.tr("Change wallpaper"); onClicked: card.openGallery() }
                GlassButton { glyph: "shuffle"; label: ""; onClicked: Wallpapers.nextWallpaper() }
            }
        }
    }

    Row {
        id: strip
        visible: card.nearby.length > 1
        x: card.pad
        y: card.stageHeight + card.pad
        width: parent.width - 2 * card.pad
        spacing: Math.round(10 * card.d)
        readonly property int count: card.nearby.length + 1
        readonly property real tileW: Math.floor((strip.width - strip.spacing * (strip.count - 1)) / strip.count)
        height: Math.round(strip.tileW * 10 / 16)
        Repeater {
            model: card.nearby
            MouseArea {
                id: tile
                required property string modelData
                readonly property bool chosen: tile.modelData === card.current
                width: strip.tileW
                height: strip.height
                hoverEnabled: true
                cursorShape: tile.chosen ? Qt.ArrowCursor : Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: FileUtils.fileNameForPath(tile.modelData)
                onClicked: if (!tile.chosen) card.apply(tile.modelData)
                Rectangle {
                    visible: tile.chosen
                    anchors.fill: parent
                    radius: IrisStyle.radiusRow
                    color: "transparent"
                    border.width: 2
                    border.color: IrisStyle.accentOnMedia
                }
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: tile.chosen ? Math.round(4 * card.d) : 0
                    radius: tile.chosen ? Math.max(IrisStyle.radiusMicro, IrisStyle.radiusRow - Math.round(4 * card.d)) : IrisStyle.radiusRow
                    color: IrisStyle.surfaceHighest
                    opacity: tile.containsMouse || tile.chosen ? 1 : 0.78
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                    IrisImage {
                        anchors.fill: parent
                        source: Wallpapers.stillUrlFor(tile.modelData)
                    }
                }
            }
        }
        MouseArea {
            id: all
            width: strip.tileW
            height: strip.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.openGallery()
            Accessible.role: Accessible.Button
            Accessible.name: Translation.tr("All wallpapers")
            Rectangle {
                anchors.fill: parent
                radius: IrisStyle.radiusRow
                color: all.containsMouse ? IrisStyle.fillHover : IrisStyle.fill
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            }
            Column {
                anchors.centerIn: parent
                spacing: 2 * card.d
                MaterialSymbol {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "grid_view"
                    iconSize: Math.round(20 * card.d)
                    color: IrisStyle.subtext
                }
                IrisText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Translation.tr("All")
                    color: IrisStyle.subtext
                    font.pixelSize: IrisStyle.typeMeta
                }
            }
        }
    }

    component GlassButton: MouseArea {
        id: glass
        property string glyph: ""
        property string label: ""
        implicitHeight: Math.round(34 * card.d)
        implicitWidth: glassRow.implicitWidth + Math.round((glass.label.length > 0 ? 28 : 18) * card.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: glass.label.length > 0 ? glass.label : Translation.tr("Random wallpaper")
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: glass.containsMouse ? IrisStyle.onMediaFillHover : IrisStyle.onMediaFill
            scale: glass.pressed ? IrisStyle.pressScale(0.94) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            id: glassRow
            anchors.centerIn: parent
            spacing: 6 * card.d
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: glass.glyph
                iconSize: Math.round(17 * card.d)
                color: IrisStyle.onMedia
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                visible: glass.label.length > 0
                text: glass.label
                color: IrisStyle.onMedia
                font.pixelSize: IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.Medium)
            }
        }
    }
}
