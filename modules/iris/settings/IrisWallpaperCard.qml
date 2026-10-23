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

ClippingRectangle {
    id: card

    readonly property real d: IrisStyle.settingsDensity
    readonly property int pad: Math.round(14 * card.d)
    // A page with room to spare gives the desk more of it (General's welcome, DI38).
    property int stageHeight: Math.round(196 * card.d)
    // The desk takes at most a third of a narrow card and leaves when the card cannot hold it beside a readable
    // column (a Settings window, a large text scale): the strip under it still shows the wallpapers.
    readonly property bool deskShown: card.width >= 520 * card.d
    readonly property real deskHeight: Math.round(Math.min(card.stageHeight - 60 * card.d, card.width * 0.54 * desk.screenH / Math.max(1, desk.screenW)))
    property var screen: GlobalStates.focusedScreen
    readonly property string current: Wallpapers.effectiveWallpaperPath
    readonly property string kind: Wallpapers.isVideoFile(card.current) ? Translation.tr("Live")
        : card.current.toLowerCase().endsWith(".gif") ? Translation.tr("Animated") : Translation.tr("Picture")
    readonly property string title: {
        const words = FileUtils.trimFileExt(FileUtils.fileNameForPath(card.current))
            .replace(/^(motionbgs|wallhaven|wallpaperflare|unsplash)[-_]/i, "")
            .split(/[-_\s]+/).filter(word => word.length > 0)
        // A name people gave it reads as one; a site's dump (ids, domains, a row of tags, a hash) is not a name: the folder
        // it lives in says it instead, else just "Wallpaper".
        const machine = words.length === 0 || words.length > 5 || words.some(word => /\d{4,}|\.[a-z]{2,4}$|^[0-9a-f]{12,}$/i.test(word))
            || (words.length === 1 && /\d/.test(words[0]) && /^[a-z0-9]{4,10}$/i.test(words[0]))
        if (!machine) return words.map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ")
        const folder = FileUtils.fileNameForPath(FileUtils.parentDirectory(card.current))
        const generic = ["", "pictures", "wallpapers", "wallpaper", "walls", "downloads", "images", "backgrounds", "imágenes", "descargas"]
        return generic.includes(folder.toLowerCase()) || /\d{4,}/.test(folder) ? Translation.tr("Wallpaper")
            : folder.split(/[-_\s]+/).filter(word => word.length > 0).map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ")
    }
    readonly property string name: SystemInfo.displayName || SystemInfo.username
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

    FontMetrics {
        id: buttonMetrics
        font.family: IrisStyle.fontMain
        font.pixelSize: IrisStyle.typeLabel
        font.weight: IrisStyle.weight(Font.Medium)
    }

    // What the strip of nearby wallpapers adds under the stage, for a page that sizes the stage to its room.
    readonly property real stripRoom: strip.visible ? strip.height + 2 * card.pad : 0
    Layout.fillWidth: true
    implicitHeight: welcome.active ? Number(welcome.item?.implicitHeight ?? 0) : card.stageHeight + (strip.visible ? strip.height + 2 * card.pad : 0)
    radius: IrisStyle.radiusTile
    color: welcome.active ? IrisStyle.bodyClip : IrisStyle.readingCard

    // A Design may greet its own way (AIRISU: the desktop printed beside the name); the card keeps what it knows and does.
    IrisSkin { id: welcome; part: "welcomeCard"; host: card }

    Item {
        id: stage
        visible: !welcome.active
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
            visible: card.deskShown
            height: card.deskHeight
            width: card.deskShown ? Math.round(height * desk.screenW / desk.screenH) : 0
            screen: card.screen
            radius: IrisStyle.radiusRow
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.openGallery()
            }
        }

        ColumnLayout {
            id: column
            // Beside the desk the words sit in the middle of the room it leaves, not against it with that room bare on their
            // right (DI38); they never shrink under what they need.
            readonly property real room: parent.width - (card.deskShown ? desk.x + desk.width : 0) - Math.round(52 * card.d)
            readonly property real measure: Math.min(column.room, Math.max(column.implicitWidth, Math.round(260 * card.d)))
            x: (card.deskShown ? desk.x + desk.width : 0) + Math.round(28 * card.d) + Math.max(0, Math.round((column.room - column.measure) / 2))
            width: column.measure
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
                        radius: IrisStyle.capsule(width)
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
                        radius: IrisStyle.capsule(width)
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
                        role: IrisText.Display
                        text: card.name
                        color: IrisStyle.accentOnMedia
                        elide: Text.ElideRight
                    }
                }
            }
            // What the desk wears, by name: the picture beside it says which, this says what it is.
            IrisText {
                Layout.fillWidth: true
                Layout.topMargin: Math.round(12 * card.d)
                visible: card.title.length > 0
                text: card.kind + "  ·  " + card.title
                color: IrisStyle.onMediaSecondary
                opacity: 0.8
                font.pixelSize: IrisStyle.typeLabel
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.topMargin: Math.round(14 * card.d)
                Layout.maximumWidth: column.width
                spacing: Math.round(8 * card.d)
                // The button keeps its word while the column holds it with the shuffle beside it; past that it is its glyph.
                GlassButton {
                    glyph: "photo_library"
                    label: buttonMetrics.advanceWidth(Translation.tr("Change wallpaper")) + Math.round((17 + 6 + 28 + 8 + 34) * card.d) <= column.width
                        ? Translation.tr("Change wallpaper") : ""
                    hint: Translation.tr("Change wallpaper")
                    onClicked: card.openGallery()
                }
                GlassButton { glyph: "shuffle"; label: ""; onClicked: Wallpapers.nextWallpaper() }
                Item { Layout.fillWidth: true }
            }
        }
    }

    Row {
        id: strip
        visible: card.nearby.length > 1 && !welcome.active
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
        property string hint: ""
        implicitHeight: Math.round(34 * card.d)
        implicitWidth: glassRow.implicitWidth + Math.round((glass.label.length > 0 ? 28 : 18) * card.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: glass.label.length > 0 ? glass.label : glass.hint.length > 0 ? glass.hint : Translation.tr("Random wallpaper")
        // A Design that cuts its bodies (AIRISU) squares the plate over the art and reads it in mono capitals.
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.fieldChamfer ? 0 : height / 2
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
                font.family: IrisStyle.monoCaptions ? IrisStyle.fontMono : IrisStyle.fontMain
                font.capitalization: IrisStyle.monoCaptions ? Font.AllUppercase : Font.MixedCase
                font.letterSpacing: IrisStyle.monoCaptions ? Math.round(IrisStyle.typeMeta * 0.12) : 0
                font.pixelSize: IrisStyle.monoCaptions ? IrisStyle.typeMeta : IrisStyle.typeLabel
                font.weight: IrisStyle.weight(Font.Medium)
            }
        }
    }
}
