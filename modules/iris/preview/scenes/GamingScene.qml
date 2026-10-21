pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.parts

// What iRiS lets through over a fullscreen game, drawn on a stand-in game: the notice that arrives or waits in Today, the
// volume and song pills as the Fullscreen rule leaves them, and which of Game mode's stops are in force.
PreviewScene {
    id: gameRoot
    readonly property bool bannerModule: gameRoot.opt("iris.modules.notificationPopup", true) === true
    readonly property bool osdModule: gameRoot.opt("iris.modules.osd", true) === true
    readonly property bool bannersOver: gameRoot.opt("iris.notifications.fullscreen", true) === true
    readonly property string pillRule: String(gameRoot.opt("iris.osd.fullscreen", "show"))
    // Game mode starts by itself for a fullscreen window; with that off it only runs when it was turned on by hand.
    readonly property bool gameOn: gameRoot.opt("gameMode.autoDetect", true) === true || GameMode.manuallyActivated
    readonly property bool holdsBanners: gameRoot.gameOn && gameRoot.opt("gameMode.suppressNotifications", true) === true
    readonly property bool held: !gameRoot.bannerModule || !gameRoot.bannersOver || gameRoot.holdsBanners
    readonly property bool volumeShown: gameRoot.osdModule && gameRoot.pillRule !== "hide"
    readonly property bool songShown: gameRoot.osdModule && gameRoot.pillRule === "show"
    readonly property var stops: [
        { glyph: "animation", label: Translation.tr("animations"), on: gameRoot.gameOn && gameRoot.opt("gameMode.disableAnimations", true) === true },
        { glyph: "blur_on", label: Translation.tr("blur"), on: gameRoot.gameOn && gameRoot.opt("gameMode.disableEffects", true) === true },
        { glyph: "graphic_eq", label: Translation.tr("visualizers"), on: gameRoot.gameOn && gameRoot.opt("gameMode.disableVisualizers", true) === true }
    ]
    readonly property bool quiet: gameRoot.held || !gameRoot.songShown || !gameRoot.volumeShown || gameRoot.stops.some(stop => stop.on)
    readonly property real naturalWidth: Math.round(600 * gameRoot.d)
    readonly property real naturalHeight: Math.round(300 * gameRoot.d)
    narrowest: Math.round(360 * gameRoot.d)
    lowest: Math.round(250 * gameRoot.d)
    // 1 while what the rule lets through is on show, 0 as it steps out for the next round.
    property real shown: 1
    // A stand-in level: the real one can be anything, and the pill is about whether it shows.
    readonly property real volume: 0.65
    Loop on shown { running: gameRoot.playing; rest: 1800 }

    component Stop: Rectangle {
        id: stop
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property color tint: IrisStyle.identity.purple
        implicitHeight: Math.round(26 * gameRoot.d)
        implicitWidth: stopRow.implicitWidth + Math.round(18 * gameRoot.d)
        radius: IrisStyle.capsule(height)
        // On a body of its own: the row sits over the wallpaper, not over a plate.
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: stop.lit ? IrisStyle.tintFill(stop.tint) : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing } }
        }
        RowLayout {
            id: stopRow
            anchors.centerIn: parent
            spacing: Math.round(6 * gameRoot.d)
            MaterialSymbol { text: stop.glyph; fill: stop.lit ? 1 : 0; iconSize: Math.round(14 * gameRoot.d); color: stop.lit ? stop.tint : IrisStyle.subtext }
            IrisText {
                visible: stop.label.length > 0
                text: stop.label
                font.pixelSize: IrisStyle.typeMeta
                font.weight: IrisStyle.weight(Font.DemiBold)
                color: stop.lit ? IrisStyle.text : IrisStyle.subtext
            }
        }
    }

    // Game mode first, then what it stops: lit while it holds that thing back.
    // A Flow: a narrow stage wraps the chips onto a second line before it cuts a word.
    Flow {
        id: stopRowTop
        x: Math.round(14 * gameRoot.d)
        y: Math.round(14 * gameRoot.d)
        width: parent.width - 2 * x
        spacing: Math.round(6 * gameRoot.d)
        Stop {
            glyph: "sports_esports"
            label: gameRoot.width >= Math.round(440 * gameRoot.d) ? Translation.tr("Game mode") : ""
            lit: gameRoot.gameOn
            tint: IrisStyle.identity.green
        }
        Repeater {
            model: gameRoot.stops
            Stop {
                required property var modelData
                glyph: modelData.on ? "pause" : modelData.glyph
                label: modelData.label
                lit: modelData.on
            }
        }
    }

    ClippingRectangle {
        id: screen
        x: Math.round(14 * gameRoot.d)
        y: stopRowTop.y + stopRowTop.height + Math.round(8 * gameRoot.d)
        width: parent.width - 2 * x
        height: parent.height - y - Math.round(50 * gameRoot.d)
        radius: IrisStyle.radiusTile
        color: Qt.darker(IrisStyle.identity.purple, 5)
        // The game itself is a stand-in: a dusk, two ridges, a crosshair and a few HUD marks, all in the section's hues.
        readonly property color hud: Qt.lighter(IrisStyle.identity.purple, 1.45)
        readonly property real w: width
        readonly property real h: height

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.darker(IrisStyle.identity.indigo, 3.4) }
                GradientStop { position: 0.45; color: Qt.darker(IrisStyle.identity.purple, 2.4) }
                GradientStop { position: 0.66; color: Qt.darker(IrisStyle.identity.pink, 1.7) }
                GradientStop { position: 1; color: Qt.darker(IrisStyle.identity.purple, 5) }
            }
        }
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: screen.w * 0.5; centerY: screen.h * 0.62
                    centerRadius: screen.w * 0.42
                    focalX: screen.w * 0.5; focalY: screen.h * 0.62
                    GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.identity.orange, 0.75) } // iris-literal: stand-in game art
                    GradientStop { position: 0.55; color: ColorUtils.applyAlpha(IrisStyle.identity.pink, 0.22) } // iris-literal: stand-in game art
                    GradientStop { position: 1; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: screen.w; y: 0 }
                PathLine { x: screen.w; y: screen.h }
                PathLine { x: 0; y: screen.h }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.darker(IrisStyle.identity.indigo, 5)
                startX: 0; startY: screen.h * 0.7
                PathLine { x: screen.w * 0.16; y: screen.h * 0.55 }
                PathLine { x: screen.w * 0.3; y: screen.h * 0.66 }
                PathLine { x: screen.w * 0.5; y: screen.h * 0.48 }
                PathLine { x: screen.w * 0.68; y: screen.h * 0.64 }
                PathLine { x: screen.w * 0.84; y: screen.h * 0.54 }
                PathLine { x: screen.w; y: screen.h * 0.64 }
                PathLine { x: screen.w; y: screen.h }
                PathLine { x: 0; y: screen.h }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: Qt.darker(IrisStyle.identity.indigo, 9)
                startX: 0; startY: screen.h * 0.88
                PathLine { x: screen.w * 0.22; y: screen.h * 0.74 }
                PathLine { x: screen.w * 0.42; y: screen.h * 0.86 }
                PathLine { x: screen.w * 0.72; y: screen.h * 0.76 }
                PathLine { x: screen.w; y: screen.h * 0.88 }
                PathLine { x: screen.w; y: screen.h }
                PathLine { x: 0; y: screen.h }
            }
        }
        // Health, top left; the map, top right.
        Rectangle {
            x: Math.round(12 * gameRoot.d); y: Math.round(14 * gameRoot.d)
            width: Math.round(54 * gameRoot.d); height: Math.round(5 * gameRoot.d)
            radius: height / 2
            color: ColorUtils.applyAlpha(screen.hud, 0.22) // iris-literal: stand-in game art
            Rectangle { width: parent.width * 0.72; height: parent.height; radius: height / 2; color: screen.hud }
        }
        Rectangle {
            x: parent.width - width - Math.round(12 * gameRoot.d); y: Math.round(12 * gameRoot.d)
            width: Math.round(34 * gameRoot.d); height: width; radius: width / 2
            color: ColorUtils.applyAlpha(screen.hud, 0.12) // iris-literal: stand-in game art
            border.width: 1
            border.color: ColorUtils.applyAlpha(screen.hud, 0.45) // iris-literal: stand-in game art
            Rectangle { anchors.centerIn: parent; width: Math.round(5 * gameRoot.d); height: width; radius: width / 2; color: screen.hud }
        }
        // Crosshair
        Item {
            anchors.centerIn: parent
            readonly property real gap: Math.round(5 * gameRoot.d)
            readonly property real len: Math.round(7 * gameRoot.d)
            Repeater {
                model: [{ x: -1, y: 0 }, { x: 1, y: 0 }, { x: 0, y: -1 }, { x: 0, y: 1 }]
                Rectangle {
                    required property var modelData
                    readonly property bool horizontal: modelData.y === 0
                    width: horizontal ? parent.len : Math.round(1.5 * gameRoot.d)
                    height: horizontal ? Math.round(1.5 * gameRoot.d) : parent.len
                    x: horizontal ? (modelData.x < 0 ? -parent.gap - parent.len : parent.gap) : -width / 2
                    y: horizontal ? -height / 2 : (modelData.y < 0 ? -parent.gap - parent.len : parent.gap)
                    color: screen.hud
                }
            }
        }

        // The notice. Kept over the game, it arrives with the rest; held, it stays ghosted and says where it went.
        Plate {
            id: banner
            surface: "cards"
            own: IrisStyle.identity.orange
            readonly property real lift: gameRoot.held ? 0 : (1 - gameRoot.shown) * -Math.round(14 * gameRoot.d)
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(10 * gameRoot.d) + banner.lift
            width: Math.min(Math.round(236 * gameRoot.d), screen.width - Math.round(90 * gameRoot.d))
            height: Math.round(48 * gameRoot.d)
            radius: IrisStyle.radiusTile
            opacity: gameRoot.held ? 0.78 : gameRoot.shown
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Math.round(10 * gameRoot.d)
                anchors.rightMargin: Math.round(10 * gameRoot.d)
                spacing: Math.round(8 * gameRoot.d)
                IrisMark { implicitSize: Math.round(28 * gameRoot.d); opacity: gameRoot.held ? 0.5 : 1 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(4 * gameRoot.d)
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr("A notification")
                        font.pixelSize: IrisStyle.typeMeta
                        font.weight: IrisStyle.weight(Font.DemiBold)
                        elide: Text.ElideRight
                    }
                    // Kept: the usual placeholder line. Held: the same place says where the notice went.
                    Rectangle { visible: !gameRoot.held; Layout.preferredWidth: parent.width * 0.7; Layout.preferredHeight: Math.round(4 * gameRoot.d); radius: height / 2; color: IrisStyle.fill }
                    RowLayout {
                        visible: gameRoot.held
                        spacing: Math.round(4 * gameRoot.d)
                        MaterialSymbol { text: "today"; iconSize: Math.round(12 * gameRoot.d); color: IrisStyle.identity.orange }
                        IrisText { Layout.fillWidth: true; text: Translation.tr("Banners wait in Today"); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeCaption; elide: Text.ElideRight }
                    }
                }
            }
        }
        // The volume pill and the song pill, as the Fullscreen rule leaves them: the song drops out first, then both.
        component Pill: Rectangle {
            id: pill
            property bool allowed: true
            default property alias content: pillRow.data
            implicitHeight: Math.round(32 * gameRoot.d)
            implicitWidth: pillRow.implicitWidth + Math.round(26 * gameRoot.d)
            radius: IrisStyle.capsule(height)
            color: IrisStyle.bodySurface
            border.width: IrisStyle.rim.a > 0 ? 1 : 0
            border.color: IrisStyle.rim
            opacity: pill.allowed ? gameRoot.shown : 0.28
            scale: pill.allowed ? 0.94 + 0.06 * gameRoot.shown : 1
            Behavior on opacity { enabled: !gameRoot.playing; NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
            IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
            RowLayout {
                id: pillRow
                anchors.centerIn: parent
                spacing: Math.round(8 * gameRoot.d)
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(12 * gameRoot.d)
            spacing: Math.round(8 * gameRoot.d)
            Pill {
                allowed: gameRoot.volumeShown
                MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(16 * gameRoot.d); color: IrisStyle.text }
                Level { Layout.preferredWidth: Math.round(42 * gameRoot.d); Layout.fillWidth: false; value: gameRoot.volume; tint: IrisStyle.text }
                IrisText { text: Math.round(gameRoot.volume * 100); font.family: IrisStyle.fontNumbers; font.features: ({ "tnum": 1 }); font.weight: IrisStyle.weight(Font.DemiBold) }
            }
            Pill {
                allowed: gameRoot.songShown
                IrisSquircle { implicitWidth: Math.round(20 * gameRoot.d); implicitHeight: implicitWidth; tint: IrisStyle.identity.pink; glyph: "music_note" }
                IrisText { Layout.maximumWidth: Math.round(110 * gameRoot.d); text: Translation.tr("Song title"); elide: Text.ElideRight; font.weight: IrisStyle.weight(Font.DemiBold) }
            }
        }
    }

    Caption {
        glyph: gameRoot.quiet ? "do_not_disturb_on" : "sports_esports"
        text: gameRoot.quiet ? Translation.tr("Quiet while you play") : Translation.tr("Everything shows")
    }
}
