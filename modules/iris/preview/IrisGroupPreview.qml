pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.background.widgets
import qs.modules.background.widgets.instrument
import qs.modules.iris.lock
import qs.modules.iris.style
import qs.modules.iris.frame
import qs.modules.iris.components
import qs.modules.iris.pieces
import qs.modules.iris.control
import qs.modules.iris.field as Field
import qs.modules.iris.bar.island as IslandParts

ClippingRectangle {
    id: root

    property string section: ""
    property string group: ""
    property bool playing: true
    property bool compact: false
    property string caption: ""
    readonly property real d: IrisStyle.density
    readonly property int rev: Config.revision
    readonly property string scene: root.sceneFor(root.section, root.group)
    readonly property bool available: (Config.options?.iris?.appearance?.previews ?? true) && root.scene.length > 0
    readonly property real wantedHeight: Math.round(Math.min(420 * root.d, Math.max(260 * root.d, Number(sceneLoader.item?.naturalHeight ?? 0))))
    readonly property string wallpaper: WallpaperListener.wallpaperUrlForScreen(GlobalStates.focusedScreen)

    function sceneFor(section: string, group: string): string {
        if (group.length === 0)
            return ({ dock: "dock", player: "player", desktop: "widgets", sidebars: "panels", controlCenter: "controlCenter", spotlight: "spotlight", bubbles: "bubbles",
                bar: "islandEdge", appearance: "light", motion: "motion", lock: "lock", frameMusic: "frame", notifications: "feedback", sound: "feedback" })[section] ?? ""
        const key = section + "/" + group
        return ({
            "bar/Visibility": "islandReserve", "bar/Interaction": "islandInteraction",
            "bar/Shape": "shapes", "bar/Layout": "islandEdge", "bar/Bar": "barZones",
            "appearance/Light": "light", "appearance/Shape": "shapes", "appearance/Colour theme": "glass", "appearance/Scheme": "glass", "appearance/Dark look": "glass", "appearance/Ink look": "glass", "appearance/Light look": "glass", "appearance/Corners per surface": "fusion", "appearance/Glass": "glass", "appearance/Edges": "glass",
            "appearance/Menus": "menus", "appearance/Settings": "settings",
            "appearance/Material": "glass", "appearance/Material per surface": "glass", "appearance/Look": "fusion",
            "appearance/Adaptive": "fusion", "appearance/Accent": "controlCenter", "appearance/Highlight": "controlCenter",
            "appearance/Faces": "typography", "appearance/Text": "typography", "appearance/Frame": "frame",
            "desktop/Desktop menu": "menus",
            "motion/Motion": "motion", "motion/Curve": "motion", "motion/Timing": "motion",
            "motion/Per surface": "motion", "motion/Style per surface": "motion", "motion/Touch": "motion",
            "frameMusic/On the edges": "frame", "frameMusic/Frame response": "frame", "frameMusic/Finish": "frame",
            "lock/Scene": "lock", "lock/Type": "lock", "lock/Clock": "lock", "lock/At a glance": "lock",
            "lock/Now playing": "lock", "lock/Activity": "lock", "lock/Sign in": "lock", "lock/Status": "lock",
            "bar/Desktop page": "islandPage", "bar/Pages": "islandPage", "bar/Player page": "islandPage",
            "bubbles/Behaviour": "bubbles", "bubbles/Floating": "bubbles", "bubbles/On the contour": "bubbles", "bubbles/Size": "bubbles",
            "bubbles/Cards": "cards", "bubbles/Card contents": "cards", "bubbles/Joining": "joining", "bubbles/Tray": "tray",
            "dock/Visibility": "dock", "dock/Icons": "dock", "dock/Look": "dock",
            "desktop/Widgets": "widgets", "desktop/Overview backdrop": "backdrop", "desktop/Wallpaper gallery": "gallery",
            "spotlight/Spotlight": "spotlight", "controlCenter/Control Center": "controlCenter",
            "sidebars/Panel look": "panels",
            "notifications/Banners": "feedback", "notifications/Notifications": "feedback", "sound/Feedback": "feedback",
            "player/Player": "player", "player/Bubble": "player"
        })[key] ?? ""
    }
    function opt(path: string, fallback: var): var {
        root.rev
        return Config.getNestedValue(path, fallback)
    }

    radius: IrisStyle.radiusTile
    color: IrisStyle.surfaceHigh

    IrisWallpaperView {
        live: false
        id: wallpaperImage
        anchors.fill: parent
        active: root.available && root.visible
        screen: GlobalStates.focusedScreen
        provideTexture: true
        decodeSize: Qt.size(Math.round(root.width * 2), 0)
        opacity: root.scene !== "backdrop" ? 1 : 0
    }

    Item {
        id: world
        readonly property real fit: Math.min(1, root.width / Math.max(1, sceneLoader.item?.naturalWidth ?? 1),
            sceneLoader.item?.cropBottom ? 1 : root.height / Math.max(1, sceneLoader.item?.naturalHeight ?? 1))
        readonly property real k: world.fit >= 0.85 ? 1 : world.fit
        width: root.width / world.k
        height: root.height / world.k
        scale: world.k
        transformOrigin: Item.TopLeft
        layer.enabled: world.k < 0.999
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(root.width * 2)), Math.max(1, Math.ceil(root.height * 2)))

        Loader {
            id: sceneLoader
            anchors.fill: parent
            active: root.available && root.visible
            sourceComponent: ({
                typography: typographyScene, frame: frameScene, lock: lockScene, motion: motionScene,
                dock: dockScene, widgets: widgetsScene, backdrop: backdropScene, gallery: galleryScene,
                spotlight: spotlightScene, controlCenter: controlScene, cards: cardsScene, menus: menusScene,
                settings: settingsScene, panels: panelsScene, joining: joiningScene, feedback: feedbackScene,
                tray: trayScene, player: playerScene, islandReserve: reserveScene, islandEdge: edgeScene, barZones: zonesScene,
                light: lightScene, fusion: fusionScene, shapes: shapesScene, glass: glassScene, islandInteraction: interactionScene, islandPage: islandPageScene, bubbles: bubblesScene
            })[root.scene] ?? null
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: IrisStyle.border
    }

    component Plate: Rectangle {
        id: plate
        property string surface: ""
        property int fallbackRadius: IrisStyle.radiusSheet
        property color own: IrisStyle.accent
        readonly property color light: IrisStyle.surfaceLight(plate.surface, plate.own)
        radius: IrisStyle.surfaceRadius(plate.surface, plate.fallbackRadius)
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        IrisLightWash {
            anchors.fill: parent
            radius: plate.radius
            light: plate.light
        }
    }

    component Caption: Rectangle {
        id: caption
        property string text: ""
        property string glyph: "info"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Math.round(14 * root.d)
        implicitWidth: captionRow.implicitWidth + Math.round(22 * root.d)
        implicitHeight: Math.round(28 * root.d)
        radius: height / 2
        color: IrisStyle.veilHeavy
        visible: caption.text.length > 0 && !root.compact
        Binding { target: root; property: "caption"; value: caption.text }
        RowLayout {
            id: captionRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MaterialSymbol { text: caption.glyph; iconSize: Math.round(14 * root.d); color: IrisStyle.subtext }
            IrisText { text: caption.text; font.pixelSize: IrisStyle.typeMeta; color: IrisStyle.text }
        }
    }

    component OffState: Rectangle {
        id: off
        property string text: ""
        anchors.centerIn: parent
        implicitWidth: offRow.implicitWidth + Math.round(28 * root.d)
        implicitHeight: Math.round(36 * root.d)
        radius: height / 2
        color: IrisStyle.veilHeavy
        border.width: 1
        border.color: IrisStyle.border
        RowLayout {
            id: offRow
            anchors.centerIn: parent
            spacing: Math.round(8 * root.d)
            MaterialSymbol { text: "visibility_off"; iconSize: Math.round(16 * root.d); color: IrisStyle.subtext }
            IrisText { text: off.text; font.weight: IrisStyle.weight(Font.DemiBold) }
        }
    }

    component IslandPill: Rectangle {
        id: pill
        property bool vertical: false
        width: pill.vertical ? Math.round(IrisFrame.islandBand) : Math.round(150 * root.d)
        height: pill.vertical ? Math.round(150 * root.d) : Math.round(IrisFrame.islandBand)
        radius: Math.min(width, height) / 2
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        IrisClock {
            visible: !pill.vertical
            anchors.centerIn: parent
            pixelSize: IrisStyle.typeHeadline
            separatorColor: IrisStyle.secondaryAccent
        }
        IslandParts.IslandStackedClock {
            visible: pill.vertical
            anchors.centerIn: parent
            pixelSize: IrisStyle.typeHeadline
            accent: IrisStyle.secondaryAccent
        }
    }

    component Row2: RowLayout {
        id: row2
        property string glyph: "apps"
        property string title: ""
        property string detail: ""
        property bool lit: false
        Layout.fillWidth: true
        spacing: Math.round(10 * root.d)
        Rectangle {
            implicitWidth: Math.round(30 * root.d)
            implicitHeight: implicitWidth
            radius: IrisStyle.iconRadius(width)
            color: row2.lit ? IrisStyle.accent : IrisStyle.fill
            MaterialSymbol { anchors.centerIn: parent; text: row2.glyph; iconSize: Math.round(16 * root.d); color: row2.lit ? IrisStyle.inkOnAccent : IrisStyle.text }
        }
        IrisText { Layout.fillWidth: true; text: row2.title; font.weight: row2.lit ? Font.DemiBold : Font.Normal; elide: Text.ElideRight }
        IrisText { text: row2.detail; color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
    }

    component Level: Rectangle {
        property real value: 0.6
        property color tint: IrisStyle.fillStrong
        Layout.fillWidth: true
        implicitHeight: Math.round(6 * root.d)
        radius: height / 2
        color: IrisStyle.fill
        Rectangle { width: parent.width * parent.value; height: parent.height; radius: height / 2; color: parent.tint }
    }

    component Pointer: Item {
        id: pointer
        property bool grabbing: false
        property int travel: 560
        width: Math.round(22 * root.d)
        height: width
        z: 50
        function click(): void { pointerRing.width = 0; pointerRing.opacity = 1; pointerPulse.restart() }
        Behavior on x { NumberAnimation { duration: IrisStyle.duration(pointer.travel); easing.type: Easing.InOutCubic } }
        Behavior on y { NumberAnimation { duration: IrisStyle.duration(pointer.travel); easing.type: Easing.InOutCubic } }
        Rectangle {
            id: pointerRing
            anchors.centerIn: parent
            width: 0
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: IrisStyle.accent
            opacity: 0
        }
        ParallelAnimation {
            id: pointerPulse
            NumberAnimation { target: pointerRing; property: "width"; to: pointer.width * 1.7; duration: IrisStyle.duration(320); easing.type: Easing.OutCubic }
            NumberAnimation { target: pointerRing; property: "opacity"; to: 0; duration: IrisStyle.duration(420); easing.type: Easing.InQuad }
        }
        MaterialSymbol {
            anchors.centerIn: parent
            text: pointer.grabbing ? "back_hand" : "arrow_selector_tool"
            fill: 1
            iconSize: pointer.width
            color: "white"
        }
    }

    component BlockRow: RowLayout {
        id: blockRow
        property string glyph: "circle"
        property string title: ""
        property string detail: ""
        Layout.fillWidth: true
        spacing: Math.round(12 * root.d)
        Item {
            implicitWidth: Math.round(40 * root.d)
            implicitHeight: implicitWidth
            Rectangle { anchors.fill: parent; radius: width / 2; color: IrisStyle.fill }
            MaterialSymbol { anchors.centerIn: parent; text: blockRow.glyph; fill: 1; iconSize: Math.round(20 * root.d); color: IrisStyle.text }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Math.round(1 * root.d)
            IrisText { Layout.fillWidth: true; text: blockRow.title; font.weight: IrisStyle.weight(Font.DemiBold); elide: Text.ElideRight }
            IrisText { Layout.fillWidth: true; text: blockRow.detail; color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta; elide: Text.ElideRight }
        }
    }

    Component {
        id: dockScene
        Item {
            id: dockRoot
            readonly property string edge: IrisFrame.dockEdge
            readonly property bool vertical: dockRoot.edge === "left" || dockRoot.edge === "right"
            readonly property real naturalWidth: Math.round((dockRoot.vertical ? 620 : 760) * root.d)
            readonly property real naturalHeight: dockRoot.vertical ? Math.max(Math.round(300 * root.d), Math.round(dockRoot.length + 64 * root.d)) : Math.round(300 * root.d)
            readonly property bool enabledDock: root.opt("iris.dock.enable", true)
            readonly property bool autoHide: root.opt("iris.dock.autoHide", true)
            readonly property bool reserve: !dockRoot.autoHide && root.opt("iris.dock.reserveSpace", true)
            readonly property bool revealOnEmpty: root.opt("iris.dock.revealOnEmpty", true)
            readonly property bool notch: root.opt("iris.dock.notch", true)
            readonly property string material: String(root.opt("iris.dock.material", "inherit"))
            readonly property bool blur: dockRoot.material === "glass" || dockRoot.material === "blur"
                || (dockRoot.material === "inherit" && (root.opt("iris.dock.blur", false) || IrisStyle.glassy))
            readonly property bool badges: root.opt("iris.dock.badges", true)
            readonly property bool launcher: root.opt("iris.dock.launcher", true)
            readonly property bool magnify: root.opt("iris.dock.magnification", false)
            readonly property real icon: Math.max(28, Math.min(64, Number(root.opt("iris.dock.iconSize", 40)))) * root.d
            readonly property var apps: (TaskbarApps.apps ?? []).filter(app => app && !app.separator && String(app.appId ?? "").length > 0 && app.appId !== "SEPARATOR").slice(0, 6)
            readonly property int count: dockRoot.apps.length + (dockRoot.launcher ? 1 : 0)
            readonly property real length: dockRoot.count * (dockRoot.icon + 10 * root.d) + 16 * root.d
            readonly property real thick: dockRoot.icon + 18 * root.d
            readonly property real span: dockRoot.vertical ? height : width
            readonly property real depth: dockRoot.vertical ? width : height
            readonly property real restInset: IrisFrame.band + (dockRoot.notch ? 0 : Math.round(10 * root.d))
            property bool hidden: false
            property int hover: -1
            property real slide: dockRoot.hidden ? -dockRoot.thick - 4 : dockRoot.restInset
            Behavior on slide { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            readonly property real alongStart: Math.round((dockRoot.span - dockRoot.length) / 2)
            readonly property real acrossAt: dockRoot.edge === "bottom" ? height - dockRoot.slide - dockRoot.thick
                : dockRoot.edge === "right" ? width - dockRoot.slide - dockRoot.thick : dockRoot.slide
            readonly property real plateX: dockRoot.vertical ? dockRoot.acrossAt : dockRoot.alongStart
            readonly property real plateY: dockRoot.vertical ? dockRoot.alongStart : dockRoot.acrossAt
            readonly property real plateW: dockRoot.vertical ? dockRoot.thick : dockRoot.length
            readonly property real plateH: dockRoot.vertical ? dockRoot.length : dockRoot.thick
            readonly property real reach: dockRoot.reserve ? dockRoot.restInset + dockRoot.thick + Math.round(10 * root.d) : IrisFrame.band

            property int step: 0
            readonly property int steps: dockRoot.count + 3
            readonly property bool gliding: dockRoot.step >= 2 && dockRoot.step < dockRoot.steps - 1
            function iconAlong(index: int): real {
                return dockRoot.alongStart + 8 * root.d + index * (dockRoot.icon + 10 * root.d) + dockRoot.icon / 2
            }
            function spot(along: real, inset: real): point {
                const across = dockRoot.edge === "bottom" ? height - inset : dockRoot.edge === "right" ? width - inset : inset
                return dockRoot.vertical ? Qt.point(across, along) : Qt.point(along, across)
            }
            function inset(side: string): real {
                if (side === dockRoot.edge) return dockRoot.reach
                return Math.round((side === "top" || side === "bottom" ? 28 : 40) * root.d)
            }
            Timer {
                running: root.playing && dockRoot.enabledDock
                interval: 620
                repeat: true
                triggeredOnStart: true
                onTriggered: dockRoot.step = (dockRoot.step + 1) % dockRoot.steps
                onRunningChanged: if (!running) dockRoot.step = 1
            }
            Binding { dockRoot.hidden: dockRoot.autoHide && dockRoot.enabledDock && (dockRoot.step === 0 || dockRoot.step === dockRoot.steps - 1) }
            Binding { dockRoot.hover: dockRoot.magnify && dockRoot.gliding ? dockRoot.step - 2 : -1 }
            Pointer {
                readonly property point aim: dockRoot.step === 0 ? Qt.point(dockRoot.width * 0.62, dockRoot.height * 0.36)
                    : dockRoot.step === dockRoot.steps - 1 ? Qt.point(dockRoot.width * 0.34, dockRoot.height * 0.3)
                    : dockRoot.step === 1 ? dockRoot.spot(dockRoot.span / 2, IrisFrame.band)
                    : dockRoot.spot(dockRoot.iconAlong(dockRoot.step - 2), dockRoot.restInset + dockRoot.thick * 0.65)
                visible: dockRoot.enabledDock && root.playing
                x: aim.x - width / 3
                y: aim.y - height / 3
            }

            Rectangle {
                x: dockRoot.inset("left")
                y: dockRoot.inset("top")
                // From the targets, not the animating x/y, or the size overshoots while they move.
                width: parent.width - dockRoot.inset("left") - dockRoot.inset("right")
                height: parent.height - dockRoot.inset("top") - dockRoot.inset("bottom")
                radius: IrisStyle.radiusTile
                color: IrisStyle.surfaceHigh
                border.width: 1
                border.color: IrisStyle.border
                Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on y { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on height { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Row {
                    x: Math.round(12 * root.d); y: Math.round(11 * root.d)
                    spacing: Math.round(6 * root.d)
                    Repeater { model: 3; Rectangle { required property int index; width: Math.round(10 * root.d); height: width; radius: width / 2; color: IrisStyle.fillStrong } }
                }
                Rectangle { x: Math.round(12 * root.d); y: Math.round(38 * root.d); width: parent.width * 0.4; height: Math.round(9 * root.d); radius: height / 2; color: IrisStyle.fill }
                Rectangle { x: Math.round(12 * root.d); y: Math.round(56 * root.d); width: parent.width * 0.62; height: Math.round(9 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
                Rectangle {
                    visible: dockRoot.reserve
                    x: dockRoot.edge === "right" ? parent.width - 1 : 0
                    y: dockRoot.edge === "bottom" ? parent.height - 1 : 0
                    width: dockRoot.vertical ? 1 : parent.width
                    height: dockRoot.vertical ? parent.height : 1
                    color: IrisStyle.accent
                }
            }

            ClippingRectangle {
                visible: dockRoot.blur && dockRoot.enabledDock
                x: dockRoot.plateX; y: dockRoot.plateY
                width: dockRoot.plateW; height: dockRoot.plateH
                radius: dockRoot.notch ? Math.round(16 * root.d) : dockRoot.thick / 2
                color: "transparent"
                ShaderEffectSource {
                    id: dockBlurSource
                    x: -dockRoot.plateX; y: -dockRoot.plateY
                    width: dockRoot.width; height: dockRoot.height
                    visible: false
                    sourceItem: wallpaperImage.textureItem
                    live: true
                }
                MultiEffect { anchors.fill: dockBlurSource; source: dockBlurSource; blurEnabled: true; blur: 1; blurMax: 48 }
            }

            Field.IrisField {
                anchors.fill: parent
                visible: dockRoot.enabledDock
                framed: false
                tint: dockRoot.blur ? IrisStyle.veilStrong : IrisStyle.bodySurface
                shapes: {
                    const out = []
                    const deep = Math.max(8, IrisStyle.fuseDeep * 2)
                    const f = IrisStyle.fuseDeep
                    const W = dockRoot.width, H = dockRoot.height, band = IrisFrame.band
                    out.push(dockRoot.edge === "top" ? { x: -2 * f, y: -deep, width: W + 4 * f, height: band + deep }
                        : dockRoot.edge === "left" ? { x: -deep, y: -2 * f, width: band + deep, height: H + 4 * f }
                        : dockRoot.edge === "right" ? { x: W - band, y: -2 * f, width: band + deep, height: H + 4 * f }
                        : { x: -2 * f, y: H - band, width: W + 4 * f, height: band + deep })
                    Object.assign(out[0], { radius: 0, fuse: f, id: "edge", paints: true })
                    out.push({ x: dockRoot.plateX, y: dockRoot.plateY, width: dockRoot.plateW, height: dockRoot.plateH,
                        radius: IrisStyle.dockShape !== "auto" ? IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.dockShape, dockRoot.notch), dockRoot.thick)
                            : dockRoot.notch ? Math.round(16 * root.d) : dockRoot.thick / 2,
                        fuse: dockRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "dock", joins: dockRoot.notch ? "edge" : "", paints: true })
                    return out
                }
            }

            Grid {
                visible: dockRoot.enabledDock
                columns: dockRoot.vertical ? 1 : Math.max(1, dockRoot.count)
                x: dockRoot.vertical ? dockRoot.plateX + (dockRoot.thick - dockRoot.icon) / 2 : dockRoot.plateX + 8 * root.d
                y: dockRoot.vertical ? dockRoot.plateY + 8 * root.d : dockRoot.plateY + (dockRoot.thick - dockRoot.icon) / 2
                spacing: Math.round(10 * root.d)
                Repeater {
                    model: (dockRoot.launcher ? [{ launcher: true }] : []).concat(dockRoot.apps)
                    Item {
                        id: dockIcon
                        required property var modelData
                        required property int index
                        readonly property int distance: dockRoot.hover < 0 ? 9 : Math.abs(dockRoot.hover - dockIcon.index)
                        width: dockRoot.icon
                        height: width
                        scale: dockIcon.distance === 0 ? 1.45 : dockIcon.distance === 1 ? 1.18 : 1
                        transformOrigin: ({ top: Item.Top, left: Item.Left, right: Item.Right })[dockRoot.edge] ?? Item.Bottom
                        z: 3 - Math.min(3, dockIcon.distance)
                        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                        Rectangle {
                            anchors.fill: parent
                            visible: dockIcon.modelData.launcher === true
                            radius: IrisStyle.iconRadius(width)
                            color: IrisStyle.fill
                            MaterialSymbol { anchors.centerIn: parent; text: "apps"; iconSize: Math.round(dockRoot.icon * 0.5); color: IrisStyle.text }
                        }
                        SmartAppIcon {
                            anchors.fill: parent
                            visible: dockIcon.modelData.launcher !== true
                            implicitSize: parent.width
                            icon: IrisPieces.appIcon(dockIcon.modelData.appId ?? "")
                            fallback: "application-x-executable"
                        }
                        Rectangle {
                            visible: dockRoot.badges && dockIcon.modelData.launcher !== true && dockIcon.index % 3 === 1
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: -Math.round(3 * root.d)
                            width: Math.round(17 * root.d); height: width; radius: width / 2
                            color: IrisStyle.badge
                            IrisText { anchors.centerIn: parent; text: dockIcon.index; color: IrisStyle.inkOnBadge; font.pixelSize: IrisStyle.typeCaption; font.weight: IrisStyle.weight(Font.Bold) }
                        }
                    }
                }
            }

            OffState { visible: !dockRoot.enabledDock; text: Translation.tr("Dock off") }
            Caption {
                anchors.leftMargin: dockRoot.edge === "left" ? dockRoot.restInset + dockRoot.thick + Math.round(14 * root.d) : Math.round(14 * root.d)
                glyph: dockRoot.autoHide ? "unfold_less" : !dockRoot.reserve ? "layers"
                    : ({ top: "vertical_align_top", left: "align_horizontal_left", right: "align_horizontal_right" })[dockRoot.edge] ?? "vertical_align_bottom"
                text: !dockRoot.enabledDock ? ""
                    : dockRoot.autoHide ? (dockRoot.revealOnEmpty ? Translation.tr("Hides over windows · stays on empty workspaces") : Translation.tr("Hides until the pointer reaches the edge"))
                    : !dockRoot.reserve ? Translation.tr("Windows run under the Dock")
                    : dockRoot.vertical ? Translation.tr("Windows stop beside the Dock")
                    : dockRoot.edge === "top" ? Translation.tr("Windows start below the Dock") : Translation.tr("Windows stop above the Dock")
            }
        }
    }

    component Loop: SequentialAnimation {
        id: loop
        property real rest: 1400
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: IrisStyle.duration(IrisStyle.settleDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve }
        PauseAnimation { duration: loop.rest }
        NumberAnimation { to: 0; duration: IrisStyle.duration(IrisStyle.recedeDuration * 2); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.recedeCurve }
        PauseAnimation { duration: loop.rest / 3 }
    }

    component LitPlate: Rectangle {
        id: lit
        property color light: IrisStyle.wallpaperLight
        color: IrisStyle.bodySurface
        border.width: IrisStyle.rim.a > 0 ? 1 : 0
        border.color: IrisStyle.rim
        IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
        IrisLightWash {
            anchors.fill: parent
            radius: lit.radius
            light: lit.light
        }
    }

    component LitBody: Item {
        id: body
        property color light
        property real restWidth: 0
        property real restHeight: 0
        property real progress: 1
        default property alias content: bodyContent.data
        RectangularShadow {
            anchors.fill: bodyPlate
            radius: bodyPlate.radius
            offset.y: 3 * IrisStyle.density
            blur: 16 * IrisStyle.density
            color: IrisStyle.shadow
        }
        LitPlate {
            id: bodyPlate
            anchors.fill: parent
            radius: Math.min(IrisStyle.radiusSheet, height / 2)
            light: body.light
        }
        Item {
            id: bodyContent
            readonly property real pad: IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * root.d)
            x: bodyContent.pad
            y: bodyContent.pad
            width: body.restWidth - 2 * bodyContent.pad
            height: body.restHeight - 2 * bodyContent.pad
            opacity: IrisStyle.ramp(body.progress, 0.55, 0.45)
            visible: opacity > 0
        }
    }

    Component {
        id: edgeScene
        Item {
            id: edgeRoot
            readonly property real naturalWidth: Math.round(640 * root.d)
            readonly property real naturalHeight: Math.round(320 * root.d)
            readonly property string edge: IrisFrame.islandEdge
            readonly property bool vertical: edgeRoot.edge === "left" || edgeRoot.edge === "right"
            readonly property bool notch: root.opt("iris.bar.notch", false)
            readonly property string layout: String(root.opt("iris.bar.layout", "island"))
            readonly property bool spans: edgeRoot.layout === "full" || (edgeRoot.layout === "menubar" && !edgeRoot.vertical)
            readonly property real thick: IrisFrame.islandBand
            readonly property real span: edgeRoot.vertical ? height : width
            // A spanning bar that floats keeps its gap on every side (IrisFrame.islandMargin is 0 with the notch).
            readonly property real length: edgeRoot.spans ? edgeRoot.span - 2 * (IrisFrame.band + IrisFrame.islandMargin)
                : Math.round(edgeRoot.thick * (edgeRoot.vertical ? 3.2 : 3.6))
            readonly property real along: edgeRoot.spans ? IrisFrame.band + IrisFrame.islandMargin
                : edgeRoot.layout === "left" ? IrisFrame.band + Math.round(20 * root.d)
                : edgeRoot.layout === "right" ? edgeRoot.span - edgeRoot.length - IrisFrame.band - Math.round(20 * root.d)
                : Math.round((edgeRoot.span - edgeRoot.length) / 2)
            readonly property real inset: IrisFrame.band + IrisFrame.islandMargin
            property real t: 0
            Loop on t { running: root.playing }
            readonly property real depth: -edgeRoot.thick - 4 + (edgeRoot.inset + edgeRoot.thick + 4) * edgeRoot.t
            function place(along: real, length: real, depth: real, thick: real): var {
                const across = edgeRoot.edge === "bottom" ? height - depth - thick : edgeRoot.edge === "right" ? width - depth - thick : depth
                return edgeRoot.vertical ? { x: across, y: along, width: thick, height: length } : { x: along, y: across, width: length, height: thick }
            }
            readonly property var island: edgeRoot.place(edgeRoot.along, edgeRoot.length, edgeRoot.depth, edgeRoot.thick)
            readonly property real bubble: Math.round(edgeRoot.thick * 0.86)
            readonly property var satellites: edgeRoot.spans ? [] : [
                edgeRoot.place(edgeRoot.along - Math.round(6 * root.d) - edgeRoot.bubble, edgeRoot.bubble, edgeRoot.depth + (edgeRoot.thick - edgeRoot.bubble) / 2, edgeRoot.bubble),
                edgeRoot.place(edgeRoot.along + edgeRoot.length + Math.round(6 * root.d), edgeRoot.bubble, edgeRoot.depth + (edgeRoot.thick - edgeRoot.bubble) / 2, edgeRoot.bubble)
            ]
            function edgeBody(): var {
                const deep = Math.max(8, IrisStyle.fuseDeep * 2), f = IrisStyle.fuseDeep
                switch (edgeRoot.edge) {
                case "bottom": return { x: -2 * f, y: height, width: width + 4 * f, height: deep }
                case "left": return { x: -deep, y: -2 * f, width: deep, height: height + 4 * f }
                case "right": return { x: width, y: -2 * f, width: deep, height: height + 4 * f }
                default: return { x: -2 * f, y: -deep, width: width + 4 * f, height: deep }
                }
            }
            Field.IrisField {
                anchors.fill: parent
                framed: false
                shapes: {
                    const out = []
                    const clear = edgeRoot.layout === "menubar" && !edgeRoot.vertical && String(root.opt("iris.bar.strip", "clear")) === "clear"
                    if (edgeRoot.notch || clear) out.push(Object.assign({ radius: 0, fuse: IrisStyle.fuseDeep, id: "edge", paints: true }, edgeRoot.edgeBody()))
                    if (!clear) out.push(Object.assign({ radius: edgeRoot.spans ? (edgeRoot.notch ? 0 : IrisStyle.pieceRadius(edgeRoot.thick))
                        : IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, edgeRoot.notch), edgeRoot.thick),
                        fuse: edgeRoot.spans && !edgeRoot.vertical ? Math.round(16 * root.d) : edgeRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse,
                        id: "island", joins: edgeRoot.notch ? "edge" : "", paints: true }, edgeRoot.island))
                    if (edgeRoot.layout === "menubar" && !edgeRoot.vertical) {
                        const height = IrisFrame.islandFullBand
                        const width = Math.round(height * 4.2)
                        out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, true), height), fuse: clear ? IrisStyle.fuseEdge : Math.round(32 * root.d),
                            id: "islandnotch", joins: clear ? "edge" : "island", paints: true },
                            edgeRoot.place((edgeRoot.span - width) / 2, width, edgeRoot.depth, height)))
                    }
                    edgeRoot.satellites.forEach((sat, i) => out.push(Object.assign({ radius: IrisStyle.pieceRadius(edgeRoot.bubble), fuse: IrisStyle.fuse,
                        id: "satellite" + i, joins: "island", paints: true }, sat)))
                    return out
                }
            }
            IrisClock {
                visible: !edgeRoot.vertical
                opacity: edgeRoot.t
                x: edgeRoot.island.x + (edgeRoot.island.width - width) / 2
                y: edgeRoot.island.y + (edgeRoot.island.height - height) / 2
                pixelSize: IrisStyle.typeHeadline
                separatorColor: IrisStyle.secondaryAccent
            }
            IslandParts.IslandStackedClock {
                visible: edgeRoot.vertical
                opacity: edgeRoot.t
                x: edgeRoot.island.x + (edgeRoot.island.width - width) / 2
                y: edgeRoot.island.y + (edgeRoot.island.height - height) / 2
                pixelSize: IrisStyle.typeHeadline
                accent: IrisStyle.secondaryAccent
            }
            Caption {
                anchors.leftMargin: edgeRoot.edge === "left" ? edgeRoot.inset + edgeRoot.thick + Math.round(14 * root.d) : Math.round(14 * root.d)
                glyph: ({ top: "vertical_align_top", bottom: "vertical_align_bottom", left: "align_horizontal_left", right: "align_horizontal_right" })[edgeRoot.edge] ?? "pill"
                text: Translation.tr(({ top: "Top edge", bottom: "Bottom edge", left: "Left edge", right: "Right edge" })[edgeRoot.edge] ?? "")
                    + " · " + (edgeRoot.layout === "menubar" ? Translation.tr("a menu bar with a notch") : edgeRoot.spans ? Translation.tr("a bar across it") : edgeRoot.notch ? Translation.tr("melts into it") : Translation.tr("floats off it"))
            }
        }
    }

    Component {
        id: zonesScene
        Item {
            id: zonesRoot
            readonly property real naturalWidth: Math.round(680 * root.d)
            readonly property real naturalHeight: Math.round(220 * root.d)
            readonly property var names: ({ island: "Island", workspaces: "Workspaces", window: "Window", time: "Time", tray: "Tray",
                notifications: "Notifications", sound: "Sound", controls: "Controls", mic: "Mic", weather: "Weather", tools: "Tools", media: "Media", equalizer: "Equalizer" })
            function listOf(path: string, fallback: var): var { return Array.from(root.opt(path, fallback) ?? []).map(kind => String(kind)) }
            readonly property var zones: [
                zonesRoot.listOf("iris.bar.fullStart", ["workspaces", "window"]),
                zonesRoot.listOf("iris.bar.fullCenter", ["island"]),
                zonesRoot.listOf("iris.bar.fullEnd", ["tray", "notifications", "sound", "controls"])
            ]
            readonly property real thick: IrisFrame.islandBand
            property real t: 0
            NumberAnimation on t { running: root.playing; from: 0; to: 3; duration: IrisStyle.duration(5400); loops: Animation.Infinite }
            readonly property int lit: Math.min(2, Math.floor(zonesRoot.t))
            Rectangle {
                id: bar
                x: Math.round(16 * root.d)
                y: Math.round(28 * root.d)
                width: parent.width - 2 * x
                height: zonesRoot.thick
                radius: IrisStyle.radiusChip
                color: IrisStyle.bodySurface
                border.width: IrisStyle.rim.a > 0 ? 1 : 0
                border.color: IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
                Repeater {
                    model: 3
                    Row {
                        id: zone
                        required property int index
                        readonly property var kinds: zonesRoot.zones[zone.index]
                        spacing: Math.round(6 * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        x: zone.index === 0 ? Math.round(8 * root.d) : zone.index === 1 ? Math.round((bar.width - width) / 2) : bar.width - width - Math.round(8 * root.d)
                        Repeater {
                            model: zone.kinds
                            Rectangle {
                                required property string modelData
                                readonly property bool current: zonesRoot.lit === zone.index
                                implicitWidth: chipLabel.implicitWidth + Math.round(16 * root.d)
                                implicitHeight: zonesRoot.thick - Math.round(10 * root.d)
                                radius: height / 2
                                color: current ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fill
                                Behavior on color { ColorAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                                IrisText {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData === "time" ? Qt.formatTime(new Date(), "hh:mm") : Translation.tr(zonesRoot.names[modelData] ?? modelData)
                                    font.pixelSize: IrisStyle.typeMeta
                                    color: parent.current ? IrisStyle.text : IrisStyle.subtext
                                }
                            }
                        }
                    }
                }
            }
            Caption {
                glyph: ["align_horizontal_left", "align_horizontal_center", "align_horizontal_right"][zonesRoot.lit]
                text: [Translation.tr("Start"), Translation.tr("Centre"), Translation.tr("End")][zonesRoot.lit] + ": "
                    + (zonesRoot.zones[zonesRoot.lit].length > 0 ? zonesRoot.zones[zonesRoot.lit].map(kind => Translation.tr(zonesRoot.names[kind] ?? kind)).join(", ") : Translation.tr("empty"))
            }
        }
    }

    Component {
        id: lightScene
        Item {
            id: lightRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(290 * root.d)
            readonly property string aura: String(root.opt("iris.appearance.aura", "subtle"))
            readonly property real reach: Number(root.opt("iris.appearance.theme.lightReach", 100))
            readonly property real glow: Number(root.opt("iris.appearance.theme.glow", 0))
            readonly property real bodyWidth: Math.round(236 * root.d)
            readonly property real bodyHeight: Math.round(176 * root.d)
            readonly property real gutter: Math.round((lightRoot.width - 2 * lightRoot.bodyWidth) / 3)
            property real t: 0
            Loop on t { running: root.playing }
            readonly property real grown: IrisFrame.islandBand + (lightRoot.bodyHeight - IrisFrame.islandBand) * lightRoot.t
            readonly property real wide: IrisFrame.islandBand * 2 + (lightRoot.bodyWidth - IrisFrame.islandBand * 2) * lightRoot.t

            LitBody {
                x: lightRoot.gutter + (lightRoot.bodyWidth - width) / 2
                y: Math.round(26 * root.d)
                width: lightRoot.wide
                height: lightRoot.grown
                restWidth: lightRoot.bodyWidth
                restHeight: lightRoot.bodyHeight
                progress: lightRoot.t
                light: IrisStyle.identity.sky
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Math.round(2 * root.d)
                    RowLayout {
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol { text: "partly_cloudy_day"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.identity.sky }
                        IrisText { text: Translation.tr("Weather"); font.weight: IrisStyle.weight(Font.DemiBold) }
                    }
                    IrisText {
                        text: "18°"
                        font.family: IrisStyle.fontNumbers
                        font.weight: IrisStyle.figureWeight
                        font.pixelSize: 40 * IrisStyle.typeScale
                    }
                    IrisText { text: Translation.tr("Partly cloudy"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
                    Item { Layout.fillHeight: true }
                }
            }
            LitBody {
                x: 2 * lightRoot.gutter + lightRoot.bodyWidth + (lightRoot.bodyWidth - width) / 2
                y: Math.round(26 * root.d)
                width: lightRoot.wide
                height: lightRoot.grown
                restWidth: lightRoot.bodyWidth
                restHeight: lightRoot.bodyHeight
                progress: lightRoot.t
                light: IrisStyle.wallpaperLight
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Math.round(10 * root.d)
                    RowLayout {
                        spacing: Math.round(6 * root.d)
                        MaterialSymbol { text: "tune"; iconSize: Math.round(18 * root.d); color: IrisStyle.text }
                        IrisText { text: Translation.tr("Control Center"); font.weight: IrisStyle.weight(Font.DemiBold) }
                    }
                    RowLayout {
                        spacing: Math.round(8 * root.d)
                        Repeater {
                            model: ["wifi", "bluetooth", "dark_mode"]
                            Rectangle {
                                required property string modelData
                                required property int index
                                implicitWidth: Math.round(38 * root.d)
                                implicitHeight: implicitWidth
                                radius: IrisStyle.pieceRadius(implicitWidth)
                                color: index === 0 ? IrisStyle.accent : IrisStyle.fill
                                MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(18 * root.d); color: parent.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(26 * root.d)
                        radius: height / 2
                        color: IrisStyle.fill
                        Rectangle { width: parent.width * 0.62; height: parent.height; radius: height / 2; color: IrisStyle.fillActive }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
            Caption {
                glyph: lightRoot.aura === "off" ? "light_off" : "light_mode"
                text: (lightRoot.aura === "off" ? Translation.tr("Light off")
                    : (lightRoot.aura === "vivid" ? Translation.tr("Vivid") : Translation.tr("Subtle")) + " · " + Translation.tr("reach %1%").arg(Math.round(lightRoot.reach)))
                    + " · " + (lightRoot.glow > 0 ? Translation.tr("shadows glow %1%").arg(Math.round(lightRoot.glow)) : Translation.tr("dark shadows"))
            }
        }
    }

    Component {
        id: fusionScene
        Item {
            id: fuseRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            readonly property real melt: Number(root.opt("iris.appearance.theme.melt", 0))
            readonly property real corners: Number(root.opt("iris.appearance.theme.shape", 100))
            readonly property real bubble: IrisFrame.islandBand
            property real t: 0
            Loop on t { running: root.playing; rest: 900 }
            readonly property var island: ({ x: Math.round(width / 2 - 90 * root.d), y: Math.round(24 * root.d), width: Math.round(180 * root.d), height: fuseRoot.bubble })
            readonly property var satellite: ({ x: fuseRoot.island.x + fuseRoot.island.width + Math.round(6 * root.d), y: fuseRoot.island.y, width: fuseRoot.bubble, height: fuseRoot.bubble })
            readonly property real cardTop: fuseRoot.island.y + fuseRoot.island.height + Math.round(40 * root.d) * (1 - fuseRoot.t) - IrisStyle.weld * fuseRoot.t
            readonly property var card: ({ x: Math.round(width / 2 - 130 * root.d), y: fuseRoot.cardTop, width: Math.round(260 * root.d), height: Math.round(150 * root.d) })
            Field.IrisField {
                anchors.fill: parent
                framed: false
                shapes: [
                    Object.assign({ radius: fuseRoot.bubble / 2, fuse: IrisStyle.fuse, id: "island", paints: true }, fuseRoot.island),
                    Object.assign({ radius: IrisStyle.pieceRadius(fuseRoot.bubble), fuse: IrisStyle.fuse, id: "satellite", joins: "island", paints: true }, fuseRoot.satellite),
                    Object.assign({ radius: IrisStyle.radiusSheet, fuse: IrisStyle.fuseDeep, id: "card", joins: "island", paints: true }, fuseRoot.card)
                ]
            }
            IrisClock {
                x: fuseRoot.island.x + (fuseRoot.island.width - width) / 2
                y: fuseRoot.island.y + (fuseRoot.island.height - height) / 2
                pixelSize: IrisStyle.typeHeadline
                separatorColor: IrisStyle.secondaryAccent
            }
            Column {
                x: fuseRoot.card.x + IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * root.d)
                y: fuseRoot.card.y + IrisStyle.concentricPad(IrisStyle.radiusSheet, 14 * root.d)
                spacing: Math.round(8 * root.d)
                Rectangle { width: Math.round(120 * root.d); height: Math.round(10 * root.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fillHover }
                Rectangle { width: Math.round(170 * root.d); height: Math.round(10 * root.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fill }
                Row {
                    spacing: Math.round(8 * root.d)
                    Repeater { model: 3; Rectangle { required property int index; width: Math.round(46 * root.d); height: Math.round(34 * root.d); radius: IrisStyle.radiusTile; color: IrisStyle.fillQuiet } }
                }
            }
            Caption {
                glyph: "join_inner"
                text: (fuseRoot.melt > 0 ? Translation.tr("Fusion %1%").arg(Math.round(fuseRoot.melt)) : Translation.tr("Crisp joins"))
                    + " · " + Translation.tr("corners %1%").arg(Math.round(fuseRoot.corners))
            }
        }
    }

    Component {
        id: shapesScene
        Item {
            id: shapeRoot
            readonly property real naturalWidth: Math.round(440 * root.d)
            readonly property real naturalHeight: Math.round(260 * root.d)
            readonly property bool notch: root.opt("iris.bar.notch", false)
            readonly property bool dockNotch: root.opt("iris.dock.notch", false)
            readonly property real rest: IrisFrame.islandBand
            readonly property real gap: shapeRoot.notch ? 0 : Math.round(14 * root.d)
            readonly property real dockThick: IrisFrame.dockBand
            readonly property real dockGap: shapeRoot.dockNotch ? 0 : Math.round(14 * root.d)
            readonly property real bubble: Math.round(shapeRoot.rest * 0.86)
            readonly property var resting: ({ x: Math.round(34 * root.d), y: shapeRoot.gap, width: Math.round(150 * root.d), height: shapeRoot.rest })
            readonly property var bubbleAt: ({ x: shapeRoot.resting.x + shapeRoot.resting.width + Math.round(6 * root.d),
                y: shapeRoot.gap + (shapeRoot.rest - shapeRoot.bubble) / 2, width: shapeRoot.bubble, height: shapeRoot.bubble })
            readonly property var opened: ({ x: Math.round(width - 34 * root.d - 190 * root.d), y: shapeRoot.gap, width: Math.round(190 * root.d), height: Math.round(104 * root.d) })
            readonly property var docked: ({ x: Math.round(width / 2 - 120 * root.d), y: height - shapeRoot.dockThick - shapeRoot.dockGap,
                width: Math.round(240 * root.d), height: shapeRoot.dockThick })
            readonly property real openCorner: Math.min(shapeRoot.opened.height / 2,
                IrisStyle.openedRadius(IrisStyle.barShape, Math.max(IrisStyle.radius, 30 * root.d)))
            function shapeName(shape: string): string {
                return Translation.tr(({ round: "Round", squircle: "Squircle", square: "Square" })[shape] ?? "Auto")
            }
            Field.IrisField {
                anchors.fill: parent
                framed: false
                shapes: {
                    const deep = Math.max(8, IrisStyle.fuseDeep * 2), f = IrisStyle.fuseDeep
                    const out = []
                    if (shapeRoot.notch) out.push({ x: -2 * f, y: -deep, width: width + 4 * f, height: deep, radius: 0, fuse: f, id: "edge", paints: true })
                    const join = shapeRoot.notch ? "edge" : ""
                    const fuse = shapeRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse
                    out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.barShape, shapeRoot.notch), shapeRoot.rest),
                        fuse: fuse, id: "island", joins: join, paints: true }, shapeRoot.resting))
                    out.push(Object.assign({ radius: IrisStyle.pieceRadius(shapeRoot.bubble), fuse: IrisStyle.fuse, id: "satellite", joins: "island", paints: true }, shapeRoot.bubbleAt))
                    out.push(Object.assign({ radius: shapeRoot.openCorner, fuse: fuse, id: "open", joins: join, paints: true }, shapeRoot.opened))
                    if (shapeRoot.dockNotch) out.push({ x: -2 * f, y: height, width: width + 4 * f, height: deep, radius: 0, fuse: f, id: "dockEdge", paints: true })
                    out.push(Object.assign({ radius: IrisStyle.profileRadius(IrisStyle.bodyProfile(IrisStyle.dockShape, shapeRoot.dockNotch), shapeRoot.dockThick),
                        fuse: shapeRoot.dockNotch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "dock", joins: shapeRoot.dockNotch ? "dockEdge" : "", paints: true }, shapeRoot.docked))
                    return out
                }
            }
            IrisClock {
                x: shapeRoot.resting.x + (shapeRoot.resting.width - width) / 2
                y: shapeRoot.resting.y + (shapeRoot.resting.height - height) / 2
                pixelSize: IrisStyle.typeHeadline
                separatorColor: IrisStyle.secondaryAccent
            }
            Column {
                x: shapeRoot.opened.x + IrisStyle.concentricPad(shapeRoot.openCorner, 16 * root.d)
                y: shapeRoot.opened.y + IrisStyle.concentricPad(shapeRoot.openCorner, 16 * root.d)
                spacing: Math.round(8 * root.d)
                Rectangle { width: Math.round(96 * root.d); height: Math.round(10 * root.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fillHover }
                Rectangle { width: Math.round(140 * root.d); height: Math.round(10 * root.d); radius: IrisStyle.radiusMicro; color: IrisStyle.fill }
                Row {
                    spacing: Math.round(8 * root.d)
                    Repeater { model: 3; Rectangle { required property int index; width: Math.round(40 * root.d); height: Math.round(30 * root.d); radius: IrisStyle.radiusTile; color: IrisStyle.fillQuiet } }
                }
            }
            Row {
                x: shapeRoot.docked.x + Math.round((shapeRoot.docked.width - width) / 2)
                y: shapeRoot.docked.y + Math.round((shapeRoot.docked.height - height) / 2)
                spacing: Math.round(10 * root.d)
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        width: IrisFrame.dockIcon * 0.8; height: width
                        radius: IrisStyle.iconRadius(width)
                        color: index === 2 ? IrisStyle.fillActive : IrisStyle.fillHover
                    }
                }
            }
            Caption {
                glyph: "rounded_corner"
                text: Translation.tr("Island shape") + " · " + shapeRoot.shapeName(IrisStyle.barShape) + "   " + Translation.tr("Dock shape") + " · " + shapeRoot.shapeName(IrisStyle.dockShape)
            }
        }
    }

    Component {
        id: glassScene
        Item {
            id: glassRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            readonly property string mode: String(root.opt("iris.appearance.glass.mode", "off"))
            property real t: 0
            Loop on t { running: root.playing; rest: 600 }
            ClippingRectangle {
                id: pane
                width: Math.round(300 * root.d)
                height: Math.round(170 * root.d)
                x: Math.round(24 * root.d + (glassRoot.width - width - 48 * root.d) * glassRoot.t)
                y: Math.round(28 * root.d)
                radius: IrisStyle.radiusSheet
                color: IrisStyle.glassy ? "transparent" : IrisStyle.bodySurface
                ShaderEffectSource {
                    id: paneSource
                    x: -pane.x; y: -pane.y
                    width: glassRoot.width; height: glassRoot.height
                    visible: false
                    sourceItem: IrisStyle.glassy ? wallpaperImage.textureItem : null
                    live: true
                }
                MultiEffect {
                    anchors.fill: paneSource
                    visible: IrisStyle.glassy
                    source: paneSource
                    blurEnabled: true
                    blur: IrisStyle.glassBlurAmount
                    blurMax: IrisStyle.glassBlurMax
                    saturation: IrisStyle.glassSaturation
                }
                Rectangle { anchors.fill: parent; visible: IrisStyle.glassy; color: IrisStyle.bodyTint }
                Column {
                    x: IrisStyle.concentricPad(pane.radius, 14 * root.d)
                    y: x
                    width: pane.width - 2 * x
                    spacing: Math.round(4 * root.d)
                    IrisText { text: Translation.tr("Now playing"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeBody }
                    IrisText { width: parent.width; text: Translation.tr("Secondary text stays readable over the wallpaper"); color: IrisStyle.muted; wrapMode: Text.WordWrap; font.pixelSize: IrisStyle.typeMeta }
                    IrisText { text: Translation.tr("Tertiary detail"); color: IrisStyle.textTertiary; font.pixelSize: IrisStyle.typeMeta }
                }
                // Appearance › Button rows on this material.
                IrisControlPlate {
                    id: glassControls
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: IrisStyle.concentricPad(pane.radius, 12 * root.d)
                    controlHeight: Math.round(30 * root.d)
                    Row {
                        spacing: glassControls.framed ? Math.round(4 * root.d) : Math.round(18 * root.d)
                        Repeater {
                            model: ["skip_previous", "pause", "skip_next"]
                            Item {
                                required property string modelData
                                width: Math.round(30 * root.d); height: width
                                MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(20 * root.d); color: IrisStyle.text }
                            }
                        }
                    }
                }
                // The glass edge the field draws on bodies (Appearance › Glass › Edge light, line, width, colour).
                IrisGlassEdge { anchors.fill: parent; visible: (IrisStyle.glassy || IrisStyle.edgeLit) && shown; radius: pane.radius }
            }
            Caption {
                glyph: IrisStyle.glassy ? "blur_on" : "crop_square"
                text: !IrisStyle.glassy ? Translation.tr("Off: solid material")
                    : (glassRoot.mode === "off" ? Translation.tr("Lume frost") + " · " : "")
                        + Translation.tr("Tint %1% · frost %2%").arg(Math.round(IrisStyle.glassTint * 100)).arg(Math.round(IrisStyle.glassBlurAmount * 100))
                        + (glassRoot.mode === "compositor" ? " · " + Translation.tr("Blur previews as Glass") : "")
            }
        }
    }

    Component {
        id: widgetsScene
        Item {
            id: widgetsRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(260 * root.d)
            readonly property bool on: root.opt("iris.modules.desktopWidgets", true)
            readonly property string design: DesktopWidgetDesign.current
            readonly property bool iris: widgetsRoot.design === "iris"
            readonly property bool instrument: widgetsRoot.design === "instrument"
            readonly property bool bare: widgetsRoot.instrument || widgetsRoot.design === "readout"
            readonly property string material: String(root.opt("iris.widgets.material", "glass"))
            readonly property bool glass: widgetsRoot.iris && widgetsRoot.material === "glass"
            readonly property bool clear: widgetsRoot.bare || (widgetsRoot.iris && widgetsRoot.material === "clear")
            readonly property color ink: String(root.opt("iris.widgets.tint", "wallpaper")) === "wallpaper" ? IrisStyle.wallpaperLight : IrisStyle.accent
            readonly property int weight: ({ light: Font.Light, regular: Font.Medium, bold: Font.Bold })[String(root.opt("iris.widgets.weight", "regular"))] ?? Font.Medium
            readonly property real strength: Math.max(0.2, Math.min(1, Number(root.opt("iris.widgets.opacity", 100)) / 100))
            // Outline as IrisWidgetFace draws it: Auto on Glass, Solid and Tinted (glass wears the glass edge), none on
            // Transparent unless the legacy hairline asks; Always everywhere; None nowhere.
            readonly property string outline: String(root.opt("iris.widgets.outline", "auto"))
            readonly property bool rimShown: !widgetsRoot.bare && widgetsRoot.iris && (widgetsRoot.outline === "always"
                || (widgetsRoot.outline === "auto" && (!widgetsRoot.clear || Boolean(root.opt("iris.widgets.rim", false)))))
            readonly property bool edgeLit: widgetsRoot.rimShown && (widgetsRoot.glass || IrisStyle.edgeLit) && (IrisStyle.glassEdgeLight > 0 || IrisStyle.glassEdgeLine > 0)
            readonly property real plateRadius: Math.round(Math.max(0, Math.min(40, Number(root.opt("iris.widgets.radius", 22)))) * root.d)
            readonly property real unit: Math.round(170 * root.d)
            readonly property real wide: Math.round(250 * root.d)
            readonly property real gap: Math.round(16 * root.d)
            readonly property real plateX: Math.round((widgetsRoot.width - widgetsRoot.wide - widgetsRoot.gap - widgetsRoot.unit) / 2)
            readonly property real plateY: Math.round((widgetsRoot.height - widgetsRoot.unit) / 2)
            readonly property color plateColor: widgetsRoot.bare ? "transparent" : !widgetsRoot.iris ? Appearance.colors.colLayer2 : widgetsRoot.glass || widgetsRoot.clear
                ? ColorUtils.applyAlpha(IrisStyle.surface, widgetsRoot.clear && !Boolean(root.opt("iris.widgets.legibleAlways", false)) ? 0
                    : IrisStyle.legibleVeil(widgetsRoot.material, 0, 0, 1)
                        * (Boolean(root.opt("iris.widgets.legibleAlways", false)) ? 1 : widgetsRoot.strength))
                : ColorUtils.applyAlpha(widgetsRoot.material === "tinted"
                    ? ColorUtils.mix(IrisStyle.surface, Appearance.colors.colPrimary, 0.82) : IrisStyle.surface, widgetsRoot.strength)

            ShaderEffectSource {
                id: widgetsWall
                anchors.fill: parent
                visible: false
                sourceItem: widgetsRoot.glass ? wallpaperImage.textureItem : null
                live: true
            }
            Repeater {
                model: widgetsRoot.on && widgetsRoot.glass ? [
                    Qt.rect(widgetsRoot.plateX, widgetsRoot.plateY, widgetsRoot.wide, widgetsRoot.unit),
                    Qt.rect(widgetsRoot.plateX + widgetsRoot.wide + widgetsRoot.gap, widgetsRoot.plateY, widgetsRoot.unit, widgetsRoot.unit)
                ] : []
                ClippingRectangle {
                    id: frost
                    required property rect modelData
                    x: frost.modelData.x
                    y: frost.modelData.y
                    width: frost.modelData.width
                    height: frost.modelData.height
                    radius: widgetsRoot.plateRadius
                    color: "transparent"
                    MultiEffect {
                        x: -frost.x
                        y: -frost.y
                        width: widgetsRoot.width
                        height: widgetsRoot.height
                        source: widgetsWall
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: IrisStyle.glassBlurAmount
                        blurMax: IrisStyle.glassBlurMax
                        saturation: IrisStyle.glassSaturation
                    }
                }
            }

            Rectangle {
                visible: widgetsRoot.on
                x: widgetsRoot.plateX
                y: widgetsRoot.plateY
                width: widgetsRoot.wide
                height: widgetsRoot.unit
                radius: widgetsRoot.plateRadius
                color: widgetsRoot.plateColor
                border.width: widgetsRoot.rimShown && !widgetsRoot.edgeLit ? 1 : 0
                border.color: widgetsRoot.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; visible: widgetsRoot.edgeLit; radius: parent.radius }
                InstrumentRing {
                    anchors.fill: parent
                    anchors.margins: Math.round(4 * root.d)
                    visible: widgetsRoot.instrument
                    fraction: DateTime.clock.date.getMinutes() / 60
                    ink: IrisStyle.onMedia
                    accent: widgetsRoot.ink
                    accentSoft: IrisStyle.secondaryAccent
                    showArc: false
                    showComet: false
                    animated: false
                }
                ColumnLayout {
                    anchors.left: parent.left; anchors.bottom: parent.bottom
                    anchors.margins: Math.round(18 * root.d)
                    anchors.bottomMargin: widgetsRoot.instrument ? Math.round(44 * root.d) : Math.round(18 * root.d)
                    anchors.leftMargin: widgetsRoot.instrument ? Math.round(60 * root.d) : Math.round(18 * root.d)
                    spacing: 0
                    IrisText { text: Qt.locale().toString(DateTime.clock.date, "dddd"); color: widgetsRoot.ink; font.weight: widgetsRoot.weight; font.pixelSize: IrisStyle.typeHeadline }
                    IrisText {
                        text: Qt.locale().toString(DateTime.clock.date, "hh:mm")
                        font.family: IrisStyle.fontNumbers
                        font.weight: widgetsRoot.weight
                        font.pixelSize: (widgetsRoot.instrument ? 36 : 52) * IrisStyle.typeScale
                        style: widgetsRoot.clear ? Text.Raised : Text.Normal
                        styleColor: IrisStyle.plateShadow
                    }
                }
            }
            Rectangle {
                visible: widgetsRoot.on
                x: widgetsRoot.plateX + widgetsRoot.wide + widgetsRoot.gap
                y: widgetsRoot.plateY
                width: widgetsRoot.unit
                height: widgetsRoot.unit
                radius: widgetsRoot.plateRadius
                color: widgetsRoot.plateColor
                border.width: widgetsRoot.rimShown && !widgetsRoot.edgeLit ? 1 : 0
                border.color: widgetsRoot.clear || IrisStyle.rim.a === 0 ? IrisStyle.clearRim : IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; visible: widgetsRoot.edgeLit; radius: parent.radius }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(18 * root.d)
                    spacing: Math.round(2 * root.d)
                    MaterialSymbol { text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"; fill: 1; iconSize: Math.round(30 * root.d); color: widgetsRoot.ink }
                    Item { Layout.fillHeight: true }
                    IrisText { text: String(Weather.data?.temp ?? "18°"); font.family: IrisStyle.fontNumbers; font.weight: widgetsRoot.weight; font.pixelSize: 34 * IrisStyle.typeScale }
                    IrisText { text: Weather.data?.city ?? Translation.tr("Weather"); color: IrisStyle.subtext; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            OffState { visible: !widgetsRoot.on; text: Translation.tr("Desktop widgets off") }
            Caption {
                glyph: widgetsRoot.bare ? "avg_pace" : widgetsRoot.glass ? "blur_on" : widgetsRoot.clear ? "select" : "square"
                text: !widgetsRoot.on ? ""
                    : widgetsRoot.instrument ? Translation.tr("Dials, scales and ruled lists")
                    : widgetsRoot.design === "readout" ? Translation.tr("Quiet figures and open lists")
                    : !widgetsRoot.iris ? Translation.tr("Each widget keeps its Material design")
                    : widgetsRoot.glass && Boolean(root.opt("iris.widgets.brightWallpapers", false)) ? Translation.tr("Frosted wallpaper · turns to frost over a bright wallpaper")
                    : widgetsRoot.glass ? Translation.tr("Frosted wallpaper · darker only where the wallpaper is bright")
                    : widgetsRoot.clear ? Translation.tr("Bare wallpaper · a veil only where text needs it")
                    : widgetsRoot.material === "tinted" ? Translation.tr("Black material with a trace of the wallpaper hue")
                    : Translation.tr("The Island's black material")
            }
        }
    }

    Component {
        id: backdropScene
        Item {
            id: backdropRoot
            readonly property real naturalWidth: Math.round(640 * root.d)
            readonly property real naturalHeight: Math.round(260 * root.d)
            readonly property bool on: root.opt("background.backdrop.enable", true)
            readonly property real blurAmount: Math.max(0, Math.min(100, Number(root.opt("background.backdrop.blurRadius", 40))))
            readonly property real dim: Math.max(0, Math.min(100, Number(root.opt("background.backdrop.dim", 40)))) / 100
            readonly property bool vignette: root.opt("background.backdrop.vignetteEnabled", false)
            Rectangle { anchors.fill: parent; color: IrisStyle.surface }
            Item {
                anchors.fill: parent
                visible: backdropRoot.on
                clip: true
                ShaderEffectSource {
                    id: backdropImage
                    anchors.fill: parent
                    anchors.margins: -48
                    visible: false
                    sourceItem: wallpaperImage.textureItem
                    live: true
                }
                MultiEffect {
                    anchors.fill: backdropImage
                    source: backdropImage
                    blurEnabled: backdropRoot.blurAmount > 0
                    blur: backdropRoot.blurAmount / 100
                    blurMax: 48
                }
                Rectangle { anchors.fill: parent; color: "black"; opacity: backdropRoot.dim }
                Rectangle {
                    anchors.fill: parent
                    visible: backdropRoot.vignette
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) } // iris-literal: vignette falloff
                        GradientStop { position: 0.3; color: "transparent" }
                        GradientStop { position: 0.7; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) } // iris-literal: vignette falloff
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: Math.round(18 * root.d)
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: Math.round((index === 1 ? 200 : 150) * root.d)
                        height: Math.round((index === 1 ? 130 : 100) * root.d)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: IrisStyle.radiusTile
                        color: IrisStyle.surfaceHigh
                        border.width: index === 1 ? 2 : 1
                        border.color: index === 1 ? IrisStyle.accent : IrisStyle.border
                        Rectangle { x: 10; y: 10; width: parent.width * 0.5; height: 7; radius: 3.5; color: IrisStyle.fill }
                        Rectangle { x: 10; y: 24; width: parent.width * 0.7; height: 7; radius: 3.5; color: IrisStyle.fillQuiet }
                    }
                }
            }
            Caption {
                glyph: "grid_view"
                text: backdropRoot.on ? Translation.tr("Overview over your wallpaper") : Translation.tr("Overview over Niri's plain background")
            }
        }
    }

    Component {
        id: galleryScene
        Item {
            id: galleryRoot
            readonly property real galleryWidth: Math.max(640, Math.min(1400, Number(root.opt("iris.wallpaper.width", 960)))) * root.d
            readonly property real thumb: Math.max(160, Math.min(320, Number(root.opt("iris.wallpaper.thumbnailSize", 228)))) * root.d
            readonly property bool live: root.opt("iris.wallpaper.livePreview", true)
            readonly property int perRow: Math.max(1, Math.floor((galleryRoot.galleryWidth - 30 * root.d) / (galleryRoot.thumb + 10 * root.d)))
            readonly property var sources: {
                const list = Array.from(Wallpapers.wallpapers ?? []).map(path => Wallpapers.stillUrlFor(path)).filter(url => url.length > 0)
                const pool = list.length > 0 ? list : [root.wallpaper]
                return Array.from({ length: galleryRoot.perRow * 2 }, (_, i) => pool[i % pool.length])
            }
            readonly property real naturalWidth: galleryRoot.galleryWidth + Math.round(80 * root.d)
            readonly property real naturalHeight: galleryRoot.thumb * 0.62 * 2 + Math.round(170 * root.d)
            property int focusIndex: 1
            Timer {
                running: root.playing
                interval: 1600
                repeat: true
                onTriggered: galleryRoot.focusIndex = (galleryRoot.focusIndex + 1) % Math.max(1, galleryRoot.sources.length)
            }
            IrisImage {
                anchors.fill: parent
                visible: galleryRoot.live
                source: galleryRoot.sources[galleryRoot.focusIndex] ?? ""
            }
            Plate {
                id: galleryPlate
                surface: "gallery"
                own: IrisStyle.wallpaperLight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(26 * root.d)
                width: galleryRoot.galleryWidth
                height: galleryFlow.implicitHeight + Math.round(64 * root.d)
                IrisText {
                    x: Math.round(20 * root.d); y: Math.round(16 * root.d)
                    text: Translation.tr("Wallpapers")
                    font.family: IrisStyle.fontTitle; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: IrisStyle.typeTitle
                }
                Flow {
                    id: galleryFlow
                    x: Math.round(20 * root.d); y: Math.round(48 * root.d)
                    width: parent.width - 2 * x
                    spacing: Math.round(10 * root.d)
                    Repeater {
                        model: galleryRoot.sources
                        ClippingRectangle {
                            id: shot
                            required property string modelData
                            required property int index
                            width: galleryRoot.thumb
                            height: Math.round(galleryRoot.thumb * 0.62)
                            radius: IrisStyle.radiusTile
                            border.width: shot.index === galleryRoot.focusIndex ? 2 : 0
                            border.color: IrisStyle.accent
                            IrisImage { anchors.fill: parent; source: shot.modelData }
                        }
                    }
                }
            }
            Caption {
                anchors.bottom: undefined
                anchors.top: parent.top
                glyph: galleryRoot.live ? "preview" : "preview_off"
                text: galleryRoot.live ? Translation.tr("The desktop previews the chosen wallpaper") : Translation.tr("Wallpapers apply only when chosen")
            }
        }
    }

    Component {
        id: spotlightScene
        Item {
            id: spotRoot
            readonly property bool on: root.opt("iris.modules.palette", true)
            readonly property bool fromIsland: String(root.opt("iris.palette.opens", "floating")) === "island"
            readonly property bool hints: root.opt("iris.palette.showHints", true)
            readonly property int results: Math.max(3, Math.min(14, Number(root.opt("iris.palette.maxResults", 8))))
            readonly property real plateWidth: Math.max(420, Math.min(900, Number(root.opt("iris.palette.width", 640)))) * root.d
            readonly property var apps: (TaskbarApps.apps ?? []).filter(app => app && !app.separator && String(app.appId ?? "").length > 0 && app.appId !== "SEPARATOR")
            readonly property real naturalWidth: spotRoot.plateWidth + Math.round(80 * root.d)
            readonly property real naturalHeight: spotPlate.y + spotPlate.height + Math.round(24 * root.d)
            readonly property bool cropBottom: true
            IslandPill {
                id: spotIsland
                visible: spotRoot.fromIsland
                anchors.horizontalCenter: parent.horizontalCenter
                y: IrisFrame.band
            }
            Plate {
                id: spotPlate
                surface: "spotlight"
                opacity: spotRoot.on ? 1 : 0.35
                anchors.horizontalCenter: parent.horizontalCenter
                y: spotRoot.fromIsland ? spotIsland.y + spotIsland.height + IrisStyle.weld : Math.round(40 * root.d)
                width: spotRoot.plateWidth
                height: spotColumn.implicitHeight + Math.round(28 * root.d)
                ColumnLayout {
                    id: spotColumn
                    x: Math.round(14 * root.d); y: Math.round(14 * root.d)
                    width: parent.width - 2 * x
                    spacing: Math.round(6 * root.d)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(40 * root.d)
                        radius: height / 2
                        color: IrisStyle.fillQuiet
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(14 * root.d)
                            spacing: Math.round(8 * root.d)
                            MaterialSymbol { text: "search"; iconSize: Math.round(18 * root.d); color: IrisStyle.muted }
                            IrisText { text: Translation.tr("Search apps, files and actions"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeLabel }
                        }
                    }
                    Row {
                        visible: spotRoot.hints
                        spacing: Math.round(6 * root.d)
                        Repeater {
                            model: [";  " + Translation.tr("Clipboard"), "=  " + Translation.tr("Calculator"), "/  " + Translation.tr("Actions"), ":  " + Translation.tr("Emoji")]
                            Rectangle {
                                required property string modelData
                                width: hintLabel.implicitWidth + Math.round(18 * root.d)
                                height: Math.round(24 * root.d)
                                radius: height / 2
                                color: IrisStyle.fillQuiet
                                IrisText { id: hintLabel; anchors.centerIn: parent; text: parent.modelData; color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeFootnote }
                            }
                        }
                    }
                    IrisText { text: Translation.tr("Top hit"); role: IrisText.Meta; Layout.topMargin: Math.round(4 * root.d) }
                    Repeater {
                        model: spotRoot.results
                        RowLayout {
                            id: hit
                            required property int index
                            readonly property var app: spotRoot.apps[hit.index % Math.max(1, spotRoot.apps.length)] ?? null
                            Layout.fillWidth: true
                            spacing: Math.round(10 * root.d)
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: Math.round(36 * root.d)
                                radius: IrisStyle.radiusRow
                                color: hit.index === 0 ? IrisStyle.tintFill(IrisStyle.accent) : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(8 * root.d)
                                    anchors.rightMargin: Math.round(10 * root.d)
                                    spacing: Math.round(10 * root.d)
                                    SmartAppIcon { implicitSize: Math.round(24 * root.d); icon: IrisPieces.appIcon(hit.app?.appId ?? ""); fallback: "application-x-executable" }
                                    IrisText {
                                        Layout.fillWidth: true
                                        text: DesktopEntries.heuristicLookup(hit.app?.appId ?? "")?.name ?? String(hit.app?.appId ?? Translation.tr("Result"))
                                        elide: Text.ElideRight
                                    }
                                    IrisText { text: hit.index === 0 ? Translation.tr("Open") : Translation.tr("App"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
                                }
                            }
                        }
                    }
                }
            }
            OffState { visible: !spotRoot.on; text: Translation.tr("Spotlight off") }
            Caption {
                glyph: spotRoot.fromIsland ? "pill" : "web_asset"
                text: Translation.tr("%1 results").arg(spotRoot.results) + " · " + (spotRoot.fromIsland ? Translation.tr("grows out of the Island") : Translation.tr("floats over the screen"))
            }
        }
    }

    Component {
        id: controlScene
        Item {
            id: ccRoot
            readonly property bool on: root.opt("iris.modules.controlCenter", true)
            readonly property bool fromIsland: String(root.opt("iris.controlCenter.opens", "island")) === "island"
            readonly property bool round: String(root.opt("iris.controlCenter.controls", "tiles")) === "round"
            readonly property real plateWidth: Math.max(320, Math.min(540, Number(root.opt("iris.controlCenter.width", 360)))) * root.d
            readonly property int columns: { root.rev; return IrisControlOptions.columns }
            readonly property var ids: { root.rev; return IrisControlOptions.gridModules }
            readonly property bool listed: { root.rev; return IrisControlOptions.modules.includes("notifications") }
            readonly property var packed: {
                root.rev
                const shapes = ({})
                for (const id of ccRoot.ids) shapes[id] = IrisControlOptions.shapeOf(id)
                return IrisControlOptions.pack(ccRoot.ids, shapes, ccRoot.columns)
            }
            readonly property real naturalWidth: ccRoot.plateWidth + Math.round(120 * root.d)
            readonly property real naturalHeight: ccPlate.y + ccPlate.height + Math.round(24 * root.d)
            readonly property bool cropBottom: true
            IslandPill {
                id: ccIsland
                anchors.horizontalCenter: parent.horizontalCenter
                y: IrisFrame.band
                opacity: ccRoot.fromIsland ? 0 : 1
            }
            Plate {
                id: ccPlate
                surface: "controlCenter"
                fallbackRadius: IrisStyle.radiusPanel
                opacity: ccRoot.on ? 1 : 0.35
                anchors.horizontalCenter: parent.horizontalCenter
                y: ccRoot.fromIsland ? IrisFrame.band : ccIsland.y + ccIsland.height + IrisFrame.bodyAir
                width: ccRoot.plateWidth
                height: ccColumn.implicitHeight + Math.round(28 * root.d)
                ColumnLayout {
                    id: ccColumn
                    x: Math.round(14 * root.d); y: Math.round(14 * root.d)
                    width: parent.width - 2 * x
                    spacing: Math.round(10 * root.d)
                    IrisText { text: Translation.tr("Control Center"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline }
                    Item {
                        id: ccGrid
                        readonly property real gap: Math.round(8 * root.d)
                        readonly property real cell: (width - (ccRoot.columns - 1) * gap) / ccRoot.columns
                        readonly property real unit: Math.round((root.opt("iris.controlCenter.labels", false) ? 70 : 64) * root.d)
                        Layout.fillWidth: true
                        implicitHeight: ccRoot.packed.rows * unit + Math.max(0, ccRoot.packed.rows - 1) * gap
                        Repeater {
                            model: ccRoot.ids
                            Rectangle {
                                id: block
                                required property string modelData
                                required property int index
                                readonly property var spot: ccRoot.packed.placed[block.modelData]
                                readonly property string kind: IrisControlOptions.kindOf(block.modelData)
                                readonly property bool wide: !["media", "level", "levels", "platter"].includes(block.kind) && block.spot.w > 1
                                readonly property bool grouped: block.kind === "levels" || block.kind === "platter"
                                readonly property bool upright: block.spot.h > block.spot.w
                                x: Math.round(block.spot.col * (ccGrid.cell + ccGrid.gap))
                                y: Math.round(block.spot.row * (ccGrid.unit + ccGrid.gap))
                                width: Math.round(block.spot.w * ccGrid.cell + (block.spot.w - 1) * ccGrid.gap)
                                height: Math.round(block.spot.h * ccGrid.unit + (block.spot.h - 1) * ccGrid.gap)
                                radius: block.kind === "platter" || block.kind === "media" ? IrisStyle.radiusPlate
                                    : !ccRoot.round ? IrisStyle.radiusTile : Math.min(width, height) / 2
                                color: block.kind === "levels" ? "transparent"
                                    : block.index === 0 && block.kind === "toggle" && !block.wide ? IrisStyle.accent : IrisStyle.fillQuiet
                                clip: true
                                Grid {
                                    visible: block.kind === "platter"
                                    anchors.centerIn: parent
                                    columns: block.spot.w > 2 ? 4 : 2
                                    spacing: Math.round(10 * root.d)
                                    Repeater {
                                        model: IrisControlOptions.platterIds
                                        Rectangle {
                                            required property string modelData
                                            required property int index
                                            width: Math.round(38 * root.d)
                                            height: width
                                            radius: width / 2
                                            color: index === 0 ? IrisStyle.accent : IrisStyle.fill
                                            MaterialSymbol { anchors.centerIn: parent; text: IrisControlOptions.glyphOf(parent.modelData); iconSize: Math.round(17 * root.d); color: parent.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text }
                                        }
                                    }
                                }
                                Row {
                                    visible: block.kind === "levels"
                                    anchors.centerIn: parent
                                    spacing: Math.round(10 * root.d)
                                    Repeater {
                                        model: IrisControlOptions.levelIds
                                        Rectangle {
                                            required property string modelData
                                            width: Math.round(Math.min(46 * root.d, (block.width - 20 * root.d) / 3))
                                            height: block.height
                                            radius: width / 2
                                            color: IrisStyle.fill
                                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * 0.6; radius: parent.radius; color: IrisStyle.fillStrong }
                                            MaterialSymbol { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(10 * root.d); text: IrisControlOptions.glyphOf(parent.modelData); iconSize: Math.round(15 * root.d); color: IrisStyle.surface }
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: block.kind === "level"
                                    y: block.upright ? parent.height * 0.4 : 0
                                    width: block.upright ? parent.width : parent.width * 0.6
                                    height: block.upright ? parent.height * 0.6 : parent.height
                                    radius: parent.radius
                                    color: IrisStyle.fillStrong
                                }
                                MaterialSymbol {
                                    visible: !block.wide && !block.grouped && block.kind !== "media"
                                    x: block.kind === "level" && !block.upright ? Math.round(14 * root.d) : Math.round((parent.width - width) / 2)
                                    y: block.kind === "level" && block.upright ? parent.height - height - Math.round(14 * root.d) : Math.round((parent.height - height) / 2)
                                    text: IrisControlOptions.glyphOf(block.modelData)
                                    iconSize: Math.round(18 * root.d)
                                    color: block.kind === "level" ? IrisStyle.surface : block.index === 0 ? IrisStyle.inkOnAccent : IrisStyle.text
                                }
                                RowLayout {
                                    visible: block.wide || block.kind === "media"
                                    anchors.fill: parent
                                    anchors.margins: Math.round(10 * root.d)
                                    spacing: Math.round(8 * root.d)
                                    Rectangle {
                                        Layout.alignment: block.kind === "media" && block.spot.h > 1 && !(block.spot.w > 2) ? Qt.AlignTop : Qt.AlignVCenter
                                        implicitWidth: Math.round(30 * root.d)
                                        implicitHeight: implicitWidth
                                        radius: width / 2
                                        color: block.kind === "media" ? IrisStyle.fillActive : IrisStyle.accent
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: block.kind === "media" ? "music_note" : IrisControlOptions.glyphOf(block.modelData)
                                            iconSize: Math.round(16 * root.d)
                                            color: block.kind === "media" ? IrisStyle.subtext : IrisStyle.inkOnAccent
                                        }
                                    }
                                    IrisText {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        text: block.kind === "media" ? (MprisController.titleOf(MprisController.activePlayer) || Translation.tr("Not playing"))
                                            : Translation.tr(IrisControlOptions.labelOf(block.modelData))
                                        font.weight: IrisStyle.weight(Font.DemiBold)
                                        font.pixelSize: IrisStyle.typeMeta
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        visible: ccRoot.listed
                        implicitHeight: Math.round(52 * root.d)
                        radius: IrisStyle.radiusPlate
                        color: IrisStyle.fillQuiet
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Math.round(12 * root.d)
                            MaterialSymbol { text: "notifications"; iconSize: Math.round(17 * root.d); color: IrisStyle.subtext }
                            IrisText { Layout.fillWidth: true; text: Translation.tr("You're all caught up"); color: IrisStyle.subtext }
                        }
                    }
                }
            }
            OffState { visible: !ccRoot.on; text: Translation.tr("Control Center off") }
            Caption {
                glyph: ccRoot.fromIsland ? "pill" : "web_asset"
                text: (ccRoot.fromIsland ? Translation.tr("Becomes the Island's controls page") : Translation.tr("Hangs from the Island as a panel")) + " · " + (ccRoot.round ? Translation.tr("round") : Translation.tr("tiles"))
            }
        }
    }

    Component {
        id: cardsScene
        Item {
            id: cardRoot
            readonly property real cardWidth: Number(root.opt("iris.appearance.surfaces.cards.width", 0)) > 0
                ? Number(root.opt("iris.appearance.surfaces.cards.width", 0)) * root.d : Math.round(340 * root.d)
            readonly property bool header: root.opt("iris.appearance.surfaces.cards.header", true)
            readonly property bool devices: root.opt("iris.appearance.surfaces.cards.devices", true)
            readonly property bool mixer: root.opt("iris.appearance.surfaces.cards.mixer", true)
            readonly property real naturalWidth: cardRoot.cardWidth + Math.round(120 * root.d)
            readonly property real naturalHeight: cardPlate.y + cardPlate.height + Math.round(24 * root.d)
            Rectangle {
                id: origin
                anchors.horizontalCenter: parent.horizontalCenter
                y: IrisFrame.band
                width: IrisFrame.islandBand; height: width
                radius: IrisStyle.pieceRadius(width)
                color: IrisStyle.bodySurface
                MaterialSymbol { anchors.centerIn: parent; text: "volume_up"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.text }
            }
            Plate {
                id: cardPlate
                surface: "cards"
                own: IrisStyle.identity.sky
                anchors.horizontalCenter: parent.horizontalCenter
                y: origin.y + origin.height + IrisStyle.weld
                width: cardRoot.cardWidth
                height: cardColumn.implicitHeight + Math.round(32 * root.d)
                ColumnLayout {
                    id: cardColumn
                    x: Math.round(16 * root.d); y: Math.round(16 * root.d)
                    width: parent.width - 2 * x
                    spacing: Math.round(12 * root.d)
                    RowLayout {
                        visible: cardRoot.header
                        spacing: Math.round(10 * root.d)
                        Rectangle {
                            implicitWidth: Math.round(30 * root.d); implicitHeight: implicitWidth
                            radius: IrisStyle.iconRadius(width); color: IrisStyle.identity.sky
                            MaterialSymbol { anchors.centerIn: parent; text: "volume_up"; fill: 1; iconSize: Math.round(16 * root.d); color: IrisStyle.onTint }
                        }
                        ColumnLayout {
                            spacing: 0
                            IrisText { text: Translation.tr("Sound"); font.weight: IrisStyle.weight(Font.DemiBold) }
                            IrisText { text: Audio.sink?.description ?? Translation.tr("Speakers"); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(10 * root.d)
                        MaterialSymbol { text: "volume_up"; iconSize: Math.round(18 * root.d); color: IrisStyle.text }
                        Level { value: Math.min(1, Audio.value ?? 0.6); tint: IrisStyle.text }
                        IrisText { text: Math.round(Math.min(1, Audio.value ?? 0.6) * 100); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.DemiBold) }
                    }
                    Row {
                        visible: cardRoot.devices
                        spacing: Math.round(6 * root.d)
                        Repeater {
                            model: [Translation.tr("Speakers"), Translation.tr("Headphones")]
                            Rectangle {
                                required property string modelData
                                required property int index
                                width: devLabel.implicitWidth + Math.round(20 * root.d); height: Math.round(26 * root.d)
                                radius: height / 2
                                color: index === 0 ? IrisStyle.tintFill(IrisStyle.accent) : IrisStyle.fillQuiet
                                IrisText { id: devLabel; anchors.centerIn: parent; text: parent.modelData; color: parent.index === 0 ? IrisStyle.accent : IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                            }
                        }
                    }
                    Repeater {
                        model: cardRoot.mixer ? (TaskbarApps.apps ?? []).filter(app => app && !app.separator && String(app.appId ?? "").length > 0 && app.appId !== "SEPARATOR").slice(0, 2) : []
                        RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: Math.round(10 * root.d)
                            SmartAppIcon { implicitSize: Math.round(20 * root.d); icon: IrisPieces.appIcon(parent.modelData.appId); fallback: "application-x-executable" }
                            Level { value: parent.index === 0 ? 0.8 : 0.45 }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: menusScene
        Item {
            id: menuRoot
            readonly property real naturalWidth: Math.round(480 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            readonly property int pad: Math.round(6 * root.d)
            Plate {
                id: menuPlate
                surface: "menus"
                fallbackRadius: IrisStyle.radiusTile
                anchors.centerIn: parent
                width: Math.round(236 * root.d)
                height: menuColumn.implicitHeight + 2 * menuRoot.pad
                ColumnLayout {
                    id: menuColumn
                    x: menuRoot.pad; y: menuRoot.pad
                    width: parent.width - 2 * x
                    spacing: 0
                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round(width * 9 / 16)
                        radius: Math.max(IrisStyle.radiusMicro, menuPlate.radius - menuRoot.pad)
                        color: IrisStyle.fillQuiet
                        ShaderEffectSource {
                            anchors.fill: parent
                            sourceItem: wallpaperImage
                            sourceRect: {
                                const w = wallpaperImage.width, h = Math.min(wallpaperImage.height, w * 9 / 16)
                                return Qt.rect(0, (wallpaperImage.height - h) / 2, w, h)
                            }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.round(parent.height * 0.55)
                            gradient: Gradient {
                                GradientStop { position: 0; color: ColorUtils.applyAlpha(IrisStyle.mediaScrim, 0) }
                                GradientStop { position: 1; color: IrisStyle.veilStrong }
                            }
                        }
                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: Math.round(10 * root.d)
                            IrisText { Layout.fillWidth: true; text: Translation.tr("Wallpaper"); color: IrisStyle.onMedia; font.pixelSize: IrisStyle.typeLabel; font.weight: IrisStyle.weight(Font.DemiBold) }
                            MaterialSymbol { text: "chevron_right"; iconSize: Math.round(16 * root.d); color: IrisStyle.onMedia }
                        }
                    }
                    Repeater {
                        model: [
                            { sep: true },
                            { glyph: "widgets", text: Translation.tr("Edit widgets"), tint: "teal", lit: true },
                            { glyph: "palette", text: Translation.tr("Customize iRiS"), tint: "purple" },
                            { sep: true },
                            { glyph: "settings", text: Translation.tr("Settings"), tint: "gray" },
                            { glyph: "restart_alt", text: Translation.tr("Restart shell"), tint: "gray" }
                        ]
                        Item {
                            id: menuRow
                            required property var modelData
                            readonly property color tint: IrisStyle.identityColor(String(menuRow.modelData.tint ?? "gray"))
                            Layout.fillWidth: true
                            implicitHeight: menuRow.modelData.sep ? Math.round(9 * root.d) : Math.round(28 * root.d)
                            Rectangle {
                                visible: menuRow.modelData.sep === true
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round(8 * root.d); width: parent.width - 2 * x; height: 1
                                color: IrisStyle.hairline
                            }
                            Rectangle {
                                visible: menuRow.modelData.sep !== true
                                anchors.fill: parent
                                radius: Math.max(IrisStyle.radiusMicro, menuPlate.radius - menuRoot.pad)
                                color: menuRow.modelData.lit ? IrisStyle.fillHover : "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(8 * root.d)
                                    spacing: Math.round(8 * root.d)
                                    Rectangle {
                                        Layout.preferredWidth: Math.round(18 * root.d)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        radius: IrisStyle.iconRadius(width)
                                        gradient: Gradient {
                                            GradientStop { position: 0; color: Qt.lighter(menuRow.tint, 1.2) }
                                            GradientStop { position: 1; color: menuRow.tint }
                                        }
                                        MaterialSymbol { anchors.centerIn: parent; text: String(menuRow.modelData.glyph ?? ""); fill: 1; iconSize: Math.round(13 * root.d); color: IrisStyle.onTint }
                                    }
                                    IrisText { Layout.fillWidth: true; text: String(menuRow.modelData.text ?? ""); font.pixelSize: IrisStyle.typeLabel }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: settingsScene
        Item {
            id: settingsRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            Plate {
                id: settingsPlate
                surface: "settings"
                fallbackRadius: IrisStyle.radiusPanel
                anchors.centerIn: parent
                width: Math.round(540 * root.d)
                height: Math.round(250 * root.d)
                clip: true
                Rectangle {
                    id: settingsSide
                    x: 1; y: 1
                    width: Math.round(150 * root.d); height: parent.height - 2
                    radius: parent.radius
                    color: IrisStyle.surfaceHigh
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: IrisStyle.hairline }
                    Column {
                        x: Math.round(10 * root.d); y: Math.round(18 * root.d)
                        width: parent.width - 2 * x
                        spacing: Math.round(4 * root.d)
                        Rectangle { width: parent.width; height: Math.round(18 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
                        Item { width: 1; height: Math.round(4 * root.d) }
                        Repeater {
                            model: [IrisStyle.identity.gray, IrisStyle.identity.purple, IrisStyle.identity.indigo, IrisStyle.identity.blue, IrisStyle.identity.sky, IrisStyle.identity.pink]
                            Rectangle {
                                required property color modelData
                                required property int index
                                width: parent.width; height: Math.round(20 * root.d)
                                radius: IrisStyle.radiusRow
                                color: index === 4 ? IrisStyle.fillActive : "transparent"
                                Row {
                                    x: Math.round(4 * root.d); anchors.verticalCenter: parent.verticalCenter
                                    spacing: Math.round(6 * root.d)
                                    Rectangle { width: Math.round(13 * root.d); height: width; radius: IrisStyle.iconRadius(width); color: parent.parent.modelData }
                                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.round(56 * root.d); height: Math.round(6 * root.d); radius: height / 2; color: IrisStyle.fillStrong }
                                }
                            }
                        }
                    }
                }
                Column {
                    x: settingsSide.width + Math.round(22 * root.d); y: Math.round(20 * root.d)
                    width: parent.width - x - Math.round(22 * root.d)
                    spacing: Math.round(12 * root.d)
                    Rectangle { width: Math.round(120 * root.d); height: Math.round(10 * root.d); radius: height / 2; color: IrisStyle.text }
                    Rectangle {
                        width: parent.width
                        height: groupRows.implicitHeight
                        radius: IrisStyle.radiusTile
                        color: IrisStyle.fillQuiet
                        Column {
                            id: groupRows
                            width: parent.width
                            Repeater {
                                model: [IrisStyle.identity.yellow, IrisStyle.identity.red, IrisStyle.identity.green, IrisStyle.identity.blue, IrisStyle.identity.teal]
                                Item {
                                    required property color modelData
                                    required property int index
                                    width: parent.width; height: Math.round(32 * root.d)
                                    Rectangle { id: rowMark; x: Math.round(10 * root.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round(16 * root.d); height: width; radius: IrisStyle.iconRadius(width); color: parent.modelData }
                                    Rectangle { x: rowMark.x + rowMark.width + Math.round(10 * root.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round((80 + 24 * (parent.index % 3)) * root.d); height: Math.round(7 * root.d); radius: height / 2; color: IrisStyle.fillStrong }
                                    Rectangle { anchors.right: parent.right; anchors.rightMargin: Math.round(26 * root.d); anchors.verticalCenter: parent.verticalCenter; width: Math.round(46 * root.d); height: Math.round(6 * root.d); radius: height / 2; color: IrisStyle.fill }
                                    MaterialSymbol { anchors.right: parent.right; anchors.rightMargin: Math.round(8 * root.d); anchors.verticalCenter: parent.verticalCenter; text: "chevron_right"; iconSize: Math.round(14 * root.d); color: IrisStyle.muted }
                                    Rectangle { visible: parent.index > 0; x: rowMark.x + rowMark.width + Math.round(10 * root.d); width: parent.width - x; height: 1; color: IrisStyle.hairline }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: panelsScene
        Item {
            id: panelRoot
            readonly property real panelWidth: Math.max(300, Math.min(560, Number(root.opt("iris.sidebars.right.width", 380)))) * root.d
            readonly property real naturalWidth: panelRoot.panelWidth * 2.2
            readonly property real naturalHeight: Math.round(420 * root.d)
            Plate {
                surface: "panels"
                fallbackRadius: IrisStyle.radiusPanel
                anchors.right: parent.right
                anchors.rightMargin: IrisFrame.band + IrisFrame.bodyAir
                y: IrisFrame.band + IrisFrame.bodyAir
                width: panelRoot.panelWidth
                height: parent.height - 2 * y
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(16 * root.d)
                    spacing: Math.round(10 * root.d)
                    RowLayout {
                        spacing: Math.round(10 * root.d)
                        IrisText { text: Qt.locale().toString(DateTime.clock.date, "d"); color: IrisStyle.identity.red; font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: 30 * IrisStyle.typeScale }
                        ColumnLayout {
                            spacing: 0
                            IrisText { text: Translation.tr("Today"); font.family: IrisStyle.fontTitle; font.weight: IrisStyle.weight(Font.Bold); font.pixelSize: IrisStyle.typeTitle }
                            IrisText { text: Qt.locale().toString(DateTime.clock.date, "dddd, MMMM"); color: IrisStyle.subtext; font.pixelSize: IrisStyle.typeMeta }
                        }
                        Item { Layout.fillWidth: true }
                        // The header's tools, on Appearance › Button rows as IrisSidebar draws them.
                        IrisControlPlate {
                            id: previewPanelTools
                            Layout.alignment: Qt.AlignVCenter
                            controlHeight: Math.round(28 * root.d)
                            Row {
                                spacing: Math.round(2 * root.d)
                                Repeater {
                                    model: ["keep", "tune", "close"]
                                    Item {
                                        required property string modelData
                                        width: Math.round(28 * root.d); height: width
                                        MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; iconSize: Math.round(16 * root.d); color: IrisStyle.textSecondary }
                                    }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: [["calendar_month", Translation.tr("Calendar"), IrisStyle.identity.red], ["partly_cloudy_day", Translation.tr("Weather"), IrisStyle.identity.sky], ["notifications", Translation.tr("Notifications"), IrisStyle.identity.orange]]
                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: IrisStyle.radiusCard
                            color: IrisStyle.surfaceHigh
                            RowLayout {
                                x: Math.round(12 * root.d); y: Math.round(12 * root.d)
                                spacing: Math.round(8 * root.d)
                                Rectangle {
                                    implicitWidth: Math.round(24 * root.d); implicitHeight: implicitWidth
                                    radius: IrisStyle.iconRadius(width); color: parent.parent.modelData[2]
                                    MaterialSymbol { anchors.centerIn: parent; text: parent.parent.parent.modelData[0]; fill: 1; iconSize: Math.round(14 * root.d); color: IrisStyle.onTint }
                                }
                                IrisText { text: parent.parent.modelData[1]; font.weight: IrisStyle.weight(Font.DemiBold) }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: joiningScene
        Item {
            id: joinRoot
            readonly property real naturalWidth: Math.round(640 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            readonly property bool along: String(root.opt("iris.appearance.theme.placement", "auto")) === "along"
            readonly property real air: IrisFrame.bodyAir
            readonly property real bubble: IrisFrame.islandBand
            readonly property var island: ({ x: Math.round(width / 2 - 170 * root.d), y: IrisFrame.band, width: Math.round(150 * root.d), height: joinRoot.bubble })
            readonly property var origin: ({ x: joinRoot.island.x + joinRoot.island.width + Math.round(6 * root.d), y: IrisFrame.band, width: joinRoot.bubble, height: joinRoot.bubble })
            readonly property var card: joinRoot.along
                ? ({ x: joinRoot.origin.x + joinRoot.origin.width + IrisStyle.weld, y: IrisFrame.band, width: Math.round(200 * root.d), height: Math.round(130 * root.d) })
                : ({ x: joinRoot.origin.x + joinRoot.origin.width / 2 - Math.round(100 * root.d), y: joinRoot.origin.y + joinRoot.origin.height + IrisStyle.weld, width: Math.round(200 * root.d), height: Math.round(130 * root.d) })
            readonly property var neighbour: ({ x: joinRoot.card.x + joinRoot.card.width + joinRoot.air, y: joinRoot.card.y + (joinRoot.along ? 0 : Math.round(20 * root.d)), width: Math.round(120 * root.d), height: Math.round(100 * root.d) })
            Field.IrisField {
                anchors.fill: parent
                framed: false
                shapes: {
                    const deep = Math.max(8, IrisStyle.fuseDeep * 2)
                    const sheet = IrisStyle.radiusSheet
                    return [
                        { x: -2 * IrisStyle.fuseDeep, y: -deep - 1 + IrisFrame.band, width: joinRoot.width + 4 * IrisStyle.fuseDeep, height: deep, radius: 0, fuse: IrisStyle.fuseDeep, id: "edge", paints: true },
                        Object.assign({ radius: joinRoot.bubble / 2, fuse: IrisStyle.fuseEdge, id: "island", joins: "edge", paints: true }, joinRoot.island),
                        Object.assign({ radius: IrisStyle.pieceRadius(joinRoot.bubble), fuse: IrisStyle.fuse, id: "origin", joins: "island", paints: true }, joinRoot.origin),
                        Object.assign({ radius: sheet, fuse: IrisStyle.fuse, id: "card", joins: "origin", paints: true }, joinRoot.card),
                        Object.assign({ radius: sheet, fuse: IrisStyle.fuse, id: "neighbour", paints: true }, joinRoot.neighbour)
                    ]
                }
            }
            MaterialSymbol { x: joinRoot.origin.x + (joinRoot.origin.width - width) / 2; y: joinRoot.origin.y + (joinRoot.origin.height - height) / 2; text: "partly_cloudy_day"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.identity.sky }
            IrisClock { x: joinRoot.island.x + (joinRoot.island.width - width) / 2; y: joinRoot.island.y + (joinRoot.island.height - height) / 2; pixelSize: IrisStyle.typeHeadline; separatorColor: IrisStyle.secondaryAccent }
            Rectangle {
                visible: joinRoot.air > 0
                x: joinRoot.card.x + joinRoot.card.width
                y: joinRoot.neighbour.y + joinRoot.neighbour.height / 2
                width: joinRoot.air; height: 2
                color: IrisStyle.accent
            }
            Caption {
                glyph: joinRoot.along ? "swap_horiz" : "south"
                text: (joinRoot.along ? Translation.tr("Opens along the edge") : Translation.tr("Opens away from the edge"))
                    + " · " + Translation.tr("air %1 px").arg(Math.round(joinRoot.air / root.d))
            }
        }
    }

    Component {
        id: feedbackScene
        Item {
            id: feedRoot
            readonly property bool banners: root.opt("iris.modules.notificationPopup", true)
            readonly property bool osd: root.opt("iris.modules.osd", true)
            readonly property real bannerWidth: Math.max(340, Math.min(560, Number(root.opt("iris.notifications.width", 380)))) * root.d
            readonly property real osdWidth: Math.max(260, Math.min(520, Number(root.opt("iris.osd.width", 320)))) * root.d
            readonly property int duration: Math.max(2000, Math.min(12000, Number(root.opt("iris.notifications.duration", 4000))))
            readonly property real naturalWidth: Math.max(feedRoot.bannerWidth, feedRoot.osdWidth) + Math.round(120 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            IslandPill { id: feedIsland; anchors.horizontalCenter: parent.horizontalCenter; y: IrisFrame.band }
            Plate {
                id: bannerPlate
                surface: "cards"
                own: IrisStyle.identity.orange
                opacity: feedRoot.banners ? 1 : 0.3
                anchors.horizontalCenter: parent.horizontalCenter
                y: feedIsland.y + feedIsland.height + IrisStyle.weld
                width: feedRoot.bannerWidth
                height: Math.round(76 * root.d)
                radius: IrisStyle.radiusPlate
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(14 * root.d)
                    spacing: Math.round(12 * root.d)
                    IrisMark { implicitSize: Math.round(38 * root.d) }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(2 * root.d)
                        IrisText { text: Translation.tr("A notification"); font.weight: IrisStyle.weight(Font.DemiBold) }
                        IrisText { Layout.fillWidth: true; text: Translation.tr("Stays %1 s, then folds back into the Island.").arg((feedRoot.duration / 1000).toFixed(1)); color: IrisStyle.textSecondary; elide: Text.ElideRight }
                    }
                }
                Rectangle {
                    id: drain
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(6 * root.d)
                    x: Math.round(18 * root.d)
                    height: 2
                    radius: 1
                    color: IrisStyle.secondaryAccent
                    readonly property real full: parent.width - 2 * x
                    width: drain.full
                    NumberAnimation on width {
                        running: root.playing && feedRoot.banners
                        loops: Animation.Infinite
                        from: drain.full; to: 0
                        duration: feedRoot.duration
                    }
                }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: bannerPlate.y + bannerPlate.height + Math.round(40 * root.d)
                opacity: feedRoot.osd ? 1 : 0.3
                width: feedRoot.osdWidth
                height: Math.round(44 * root.d)
                radius: height / 2
                color: IrisStyle.bodySurface
                border.width: IrisStyle.rim.a > 0 ? 1 : 0
                border.color: IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(14 * root.d)
                    anchors.rightMargin: Math.round(16 * root.d)
                    spacing: Math.round(10 * root.d)
                    MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.text }
                    Level { value: Math.min(1, Audio.value ?? 0.7); tint: IrisStyle.text }
                    IrisText { text: Math.round(Math.min(1, Audio.value ?? 0.7) * 100); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.weight(Font.DemiBold) }
                }
            }
            Caption {
                glyph: "campaign"
                text: [feedRoot.banners ? Translation.tr("Banners on") : Translation.tr("Banners off"), feedRoot.osd ? Translation.tr("level feedback on") : Translation.tr("level feedback off")].join(" · ")
            }
        }
    }

    Component {
        id: trayScene
        Item {
            id: trayRoot
            readonly property int columns: Math.max(2, Math.min(6, Number(root.opt("iris.tray.columns", 4))))
            readonly property bool labels: root.opt("iris.tray.labels", true)
            readonly property bool hidePassive: root.opt("iris.tray.hidePassive", false)
            readonly property var items: (SystemTray.items.values ?? []).filter(item => !trayRoot.hidePassive || item.status !== Status.Passive)
            readonly property real naturalWidth: trayPlate.width + Math.round(80 * root.d)
            readonly property real naturalHeight: trayPlate.height + Math.round(80 * root.d)
            Plate {
                id: trayPlate
                surface: "cards"
                anchors.centerIn: parent
                width: trayGrid.implicitWidth + Math.round(32 * root.d)
                height: trayGrid.implicitHeight + Math.round(64 * root.d)
                IrisText {
                    x: Math.round(16 * root.d); y: Math.round(14 * root.d)
                    text: Translation.tr("Tray") + "  " + trayRoot.items.length
                    font.weight: IrisStyle.weight(Font.DemiBold)
                }
                Grid {
                    id: trayGrid
                    x: Math.round(16 * root.d); y: Math.round(46 * root.d)
                    columns: trayRoot.columns
                    spacing: Math.round(6 * root.d)
                    Repeater {
                        model: trayRoot.items.length > 0 ? trayRoot.items : [null, null, null]
                        Column {
                            id: trayEntry
                            required property var modelData
                            width: Math.round(72 * root.d)
                            spacing: Math.round(5 * root.d)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(48 * root.d); height: width
                                radius: IrisStyle.iconRadius(width)
                                color: IrisStyle.fillQuiet
                                IconImage { anchors.centerIn: parent; implicitSize: Math.round(26 * root.d); source: trayEntry.modelData ? TrayService.getSafeIcon(trayEntry.modelData) : "" }
                            }
                            IrisText {
                                visible: trayRoot.labels
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: trayEntry.modelData?.tooltipTitle || trayEntry.modelData?.title || trayEntry.modelData?.id || Translation.tr("App")
                                elide: Text.ElideRight
                                font.pixelSize: IrisStyle.typeFootnote
                                color: IrisStyle.subtext
                            }
                        }
                    }
                }
            }
            Caption {
                glyph: "inventory_2"
                text: Translation.tr("%1 columns").arg(trayRoot.columns) + (trayRoot.hidePassive ? " · " + Translation.tr("passive apps hidden") : "")
            }
        }
    }

    Component {
        id: playerScene
        Item {
            id: playerRoot
            readonly property var player: MprisController.activePlayer
            readonly property string art: String(MprisController.artUrlOf(playerRoot.player) ?? "")
            readonly property string cover: playerRoot.art.length > 0 ? playerRoot.art : root.wallpaper
            readonly property bool roundCover: root.opt("iris.player.roundCover", false)
            readonly property bool artBackground: root.opt("iris.player.artworkBackground", true)
            readonly property bool opensIsland: String(root.opt("iris.player.bubbleOpens", "card")) === "island"
            readonly property bool pinned: root.opt("iris.player.cardPinned", false)
            readonly property real naturalWidth: Math.round(560 * root.d)
            readonly property real naturalHeight: Math.round(290 * root.d)
            ClippingRectangle {
                id: playerCard
                anchors.centerIn: parent
                width: Math.round(380 * root.d)
                height: Math.round(210 * root.d)
                radius: playerRoot.opensIsland ? IrisStyle.radius : IrisStyle.radiusSheet
                color: IrisStyle.bodySurface
                border.width: IrisStyle.rim.a > 0 ? 1 : 0
                border.color: IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
                Image {
                    id: artSource
                    anchors.fill: parent
                    anchors.margins: -40
                    source: playerRoot.cover
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 240
                    visible: false
                }
                MultiEffect {
                    anchors.fill: artSource
                    source: artSource
                    visible: playerRoot.artBackground
                    blurEnabled: true; blur: 1; blurMax: 48
                    brightness: -0.25
                }
                Rectangle { anchors.fill: parent; visible: playerRoot.artBackground; color: IrisStyle.mediaScrim }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(18 * root.d)
                    spacing: Math.round(10 * root.d)
                    RowLayout {
                        spacing: Math.round(14 * root.d)
                        ClippingRectangle {
                            implicitWidth: Math.round(84 * root.d); implicitHeight: implicitWidth
                            radius: playerRoot.roundCover ? width / 2 : IrisStyle.radiusTile
                            Behavior on radius { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                            IrisImage { anchors.fill: parent; source: playerRoot.cover }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(2 * root.d)
                            IrisText { Layout.fillWidth: true; text: MprisController.titleOf(playerRoot.player) || Translation.tr("Song title"); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text; font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline; elide: Text.ElideRight }
                            IrisText { Layout.fillWidth: true; text: MprisController.artistOf(playerRoot.player) || Translation.tr("Artist"); color: playerRoot.artBackground ? IrisStyle.onMediaSecondary : IrisStyle.subtext; elide: Text.ElideRight }
                        }
                        MaterialSymbol { visible: playerRoot.pinned; Layout.alignment: Qt.AlignTop; text: "keep"; fill: 1; iconSize: Math.round(18 * root.d); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.accent }
                    }
                    Item { Layout.fillHeight: true }
                    Level { value: 0.38; tint: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text; color: playerRoot.artBackground ? IrisStyle.onMediaFill : IrisStyle.fill }
                    // Appearance › Button rows, as IrisMediaCard draws it.
                    IrisControlPlate {
                        id: previewTransport
                        Layout.alignment: Qt.AlignHCenter
                        controlHeight: Math.round(32 * root.d)
                        Row {
                            spacing: previewTransport.framed ? Math.round(4 * root.d) : Math.round(26 * root.d)
                            Repeater {
                                model: ["skip_previous", "pause", "skip_next"]
                                Item {
                                    required property string modelData
                                    width: Math.round(32 * root.d); height: width
                                    MaterialSymbol { anchors.centerIn: parent; text: parent.modelData; fill: 1; iconSize: Math.round(24 * root.d); color: playerRoot.artBackground ? IrisStyle.onMedia : IrisStyle.text }
                                }
                            }
                        }
                    }
                }
            }
            Caption {
                glyph: playerRoot.opensIsland ? "pill" : "web_asset"
                text: (playerRoot.opensIsland ? Translation.tr("The media bubble opens the Island") : Translation.tr("The media bubble opens a card"))
                    + (playerRoot.pinned ? " · " + Translation.tr("kept open") : "")
            }
        }
    }

    Component {
        id: islandPageScene
        Item {
            id: pageRoot
            readonly property string mode: root.group === "Player page" ? "media" : root.group === "Pages" ? "pages" : "desktop"
            readonly property real pageW: Math.max(360, Math.min(600, Number(root.opt("iris.bar.pageWidth", 440)))) * root.d
            readonly property bool banner: String(root.opt("iris.bar.desktopBanner", "wallpaper")) === "wallpaper"
            // Same resolution as IrisIsland.pagePlate and the header's options as IslandDesktopPage reads them.
            readonly property string plate: {
                const value = String(root.opt("iris.bar.navFrame", "auto"))
                const global = String(root.opt("iris.appearance.controlPlate", "none"))
                return ["none", "veil", "glass", "solid"].includes(value) ? value : ["veil", "glass", "solid"].includes(global) ? global : "none"
            }
            function part(key: string, fallback: int): real { return Math.max(0, Math.min(100, Number(root.opt("iris.bar." + key, fallback)))) / 100 }
            readonly property real bannerTop: pageRoot.part("desktopBannerTop", 100)
            readonly property real bannerFade: pageRoot.part("desktopBannerFade", 100)
            readonly property real bannerVeil: pageRoot.part("desktopBannerVeil", 100)
            readonly property real bannerBlur: pageRoot.part("desktopBannerBlur", 0)
            readonly property bool grouped: String(root.opt("iris.bar.blockStyle", "plain")) === "grouped"
            readonly property var desktopBlocks: Array.from(root.opt("iris.bar.desktopBlocks", ["profile", "context", "forecast", "agenda", "modules"]))
            readonly property var mediaBlocks: Array.from(root.opt("iris.bar.mediaBlocks", ["player", "timeline", "transport", "players", "levels"]))
            readonly property var navKinds: ["media", "activity", "desktop", "tray", "tools", "focus", "today", "controls", "settings"]
            readonly property var navEntries: {
                const chosen = Array.from(root.opt("iris.bar.navItems", pageRoot.navKinds)).filter(kind => pageRoot.navKinds.includes(kind))
                const glyphs = { media: "music_note", activity: "bolt", desktop: "space_dashboard", tray: "apps", tools: "timer",
                    focus: "left_panel_open", today: "right_panel_open", controls: "tune", settings: "settings" }
                const pageKinds = ["media", "activity", "desktop", "tray", "tools"]
                const out = []
                let pages = true
                for (const kind of (chosen.length > 0 ? chosen : pageRoot.navKinds)) {
                    const page = pageKinds.includes(kind)
                    if (pages && !page && out.length > 0) out.push({ kind: "|" })
                    if (!page) pages = false
                    out.push({ kind: kind, page: page, glyph: glyphs[kind] })
                }
                return out
            }
            readonly property int pageCount: pageRoot.navEntries.filter(entry => entry.page).length
            readonly property int actionCount: pageRoot.navEntries.filter(entry => entry.kind !== "|" && !entry.page).length
            readonly property string current: pageRoot.mode === "media" ? "media" : "desktop"
            readonly property var player: MprisController.activePlayer
            readonly property var hours: Array.from(Weather.data?.hourly ?? []).slice(0, 6)
            readonly property bool weatherReady: Weather.enabled && !String(Weather.data?.temp ?? "--").startsWith("--")
            readonly property var lastWindow: {
                const stamp = w => (w.focus_timestamp?.secs ?? 0) * 1e9 + (w.focus_timestamp?.nanos ?? 0)
                return (NiriService.windows ?? []).slice().sort((a, b) => stamp(b) - stamp(a))[0] ?? null
            }
            readonly property real naturalWidth: pageRoot.pageW + Math.round(160 * root.d)
            readonly property real naturalHeight: pageRoot.bodyY + pageRoot.bodyHeight + Math.round(56 * root.d)
            readonly property bool cropBottom: true
            // The Island's own geometry (IrisIsland): notched it hangs from the frame and its content starts one corner
            // down (edgeInset); floating it sits the Island margin below the band.
            readonly property bool notch: Boolean(root.opt("iris.bar.notch", true))
            readonly property real corner: IrisStyle.openedRadius(IrisStyle.barShape, Math.max(IrisStyle.radius, 30 * root.d))
            readonly property real topInset: pageRoot.notch ? Math.ceil(pageRoot.corner) : 0
            readonly property real padding: Math.round(20 * root.d)
            readonly property real navBand: previewNav.height + Math.round(14 * root.d)
            readonly property real bodyX: Math.round((width - pageRoot.pageW) / 2)
            readonly property real bodyY: pageRoot.notch ? 0 : IrisFrame.band + Math.round(Number(root.opt("iris.bar.margin", 8)) * root.d)
            readonly property real bodyHeight: pageColumn.y + pageColumn.implicitHeight + pageRoot.padding

            // The Island as it opens on the desktop: the field draws its body and, notched, its join to the frame;
            // the page sits in a clip that follows it. Hanging from the edge, the clip's top corners sit above
            // the view so the join stays the field's.
            Field.IrisField {
                anchors.fill: parent
                framed: false
                shapes: {
                    const f = IrisStyle.fuseDeep, deep = Math.max(8, f * 2)
                    const out = []
                    if (pageRoot.notch || IrisFrame.framed)
                        out.push({ x: -2 * f, y: -deep, width: width + 4 * f, height: deep + (IrisFrame.framed ? IrisFrame.band : 0), radius: 0, fuse: f, id: "edge", paints: true })
                    out.push({ x: pageRoot.bodyX, y: pageRoot.bodyY, width: pageRoot.pageW, height: pageRoot.bodyHeight, radius: pageRoot.corner,
                        fuse: pageRoot.notch ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "island", joins: pageRoot.notch ? "edge" : "", paints: true })
                    return out
                }
            }

            ClippingRectangle {
                id: islandBody
                x: pageRoot.bodyX
                y: pageRoot.bodyY - pageRoot.topInset
                width: pageRoot.pageW
                height: pageRoot.bodyHeight + pageRoot.topInset
                radius: pageRoot.corner
                color: "transparent"

                Item {
                    id: bodyContent
                    y: pageRoot.topInset
                    width: parent.width
                    height: pageRoot.bodyHeight

                    // The header, from the shared IrisHeaderScrim and IrisHeaderFade with the Island's own geometry.
                    Item {
                        id: previewHeader
                        visible: pageRoot.mode !== "media" && pageRoot.banner
                        width: parent.width
                        height: pageColumn.y + previewHero.height + Math.round(12 * root.d)
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: previewFade
                            maskThresholdMin: 0.5
                            maskSpreadAtMin: 1
                            blurEnabled: pageRoot.bannerBlur > 0
                            blur: pageRoot.bannerBlur
                            blurMax: 48
                        }
                        IrisImage {
                            anchors.fill: parent
                            source: root.wallpaper
                        }
                        IrisHeaderScrim {
                            id: previewScrim
                            anchors.fill: parent
                            hangs: true
                            solidTop: pageRoot.topInset + pageRoot.padding + pageRoot.navBand * 0.5
                            navBand: pageRoot.navBand
                            topJoin: pageRoot.notch
                            joinDepth: pageRoot.topInset + Math.round(pageRoot.corner * 0.62) + 4 * root.d
                            unit: root.d
                            meltTop: pageRoot.bannerTop
                            meltFade: pageRoot.bannerFade
                            meltVeil: pageRoot.bannerVeil
                        }
                    }
                    IrisHeaderFade {
                        id: previewFade
                        scrim: previewScrim
                        width: previewHeader.width
                        height: previewHeader.height
                    }

                    // The navigation row as the Island draws it (IrisIsland's navFrame): 36 × 30 buttons, 4 px apart.
                    IrisControlPlate {
                        id: previewNav
                        x: Math.round((bodyContent.width - width) / 2)
                        y: pageRoot.topInset + pageRoot.padding
                        material: pageRoot.plate
                        Row {
                            spacing: Math.round(4 * root.d)
                            Repeater {
                                model: pageRoot.navEntries
                                Item {
                                    id: navEntry
                                    required property var modelData
                                    readonly property bool divider: navEntry.modelData.kind === "|"
                                    readonly property bool selected: navEntry.modelData.kind === pageRoot.current
                                    width: navEntry.divider ? Math.round(9 * root.d) : Math.round(36 * root.d)
                                    height: Math.round(30 * root.d)
                                    Rectangle {
                                        visible: navEntry.divider
                                        anchors.centerIn: parent
                                        width: 1; height: Math.round(14 * root.d)
                                        color: IrisStyle.fill
                                    }
                                    Rectangle {
                                        visible: !navEntry.divider
                                        anchors.fill: parent
                                        radius: previewNav.controlRadius
                                        color: navEntry.selected ? IrisStyle.tintFill(IrisStyle.accent) : pageRoot.mode === "pages" && navEntry.modelData.page ? IrisStyle.fillQuiet : "transparent"
                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: navEntry.modelData.glyph ?? ""
                                            fill: navEntry.selected ? 1 : 0
                                            iconSize: Math.round(18 * root.d)
                                            color: navEntry.selected ? IrisStyle.accent : IrisStyle.textSecondary
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: pageColumn
                        x: pageRoot.padding
                        y: previewNav.y + pageRoot.navBand
                        width: parent.width - 2 * x
                        spacing: Math.round(14 * root.d)

                        // The hero as IslandDesktopPage draws it: date and time on the left, the weather on the right,
                        // the header's tools on its top corner.
                        Item {
                            id: previewHero
                            visible: pageRoot.mode !== "media"
                            Layout.fillWidth: true
                            implicitHeight: pageRoot.banner
                                ? Math.max(Math.round(112 * root.d), heroRow.implicitHeight + Math.round(26 * root.d))
                                : heroRow.implicitHeight

                            // The header's tools share the Island's plate; bare, each keeps its own veil.
                            IrisControlPlate {
                                id: previewTools
                                visible: pageRoot.mode === "desktop"
                                anchors.right: parent.right
                                anchors.rightMargin: -previewTools.inset
                                anchors.top: parent.top
                                anchors.topMargin: -Math.round(6 * root.d) - previewTools.inset
                                material: pageRoot.plate
                                controlHeight: Math.round(32 * root.d)
                                Row {
                                    spacing: previewTools.framed ? Math.round(2 * root.d) : Math.round(6 * root.d)
                                    Repeater {
                                        model: pageRoot.banner ? ["edit", "wallpaper"] : ["edit"]
                                        Rectangle {
                                            required property string modelData
                                            width: Math.round(32 * root.d)
                                            height: width
                                            radius: previewTools.framed ? previewTools.controlRadius : height / 2
                                            color: previewTools.framed ? "transparent" : pageRoot.banner ? IrisStyle.veil : IrisStyle.fillQuiet
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                iconSize: Math.round(17 * root.d)
                                                color: pageRoot.banner ? IrisStyle.onMedia : IrisStyle.text
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                id: heroRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                spacing: Math.round(12 * root.d)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignBottom
                                    spacing: -Math.round(2 * root.d)
                                    IrisText {
                                        textFormat: Text.StyledText
                                        text: "<font color='" + (pageRoot.banner ? IrisStyle.textStrong : IrisStyle.secondaryAccent) + "'><b>"
                                            + Qt.locale().toString(DateTime.clock.date, "dddd") + "</b></font> "
                                            + Qt.locale().toString(DateTime.clock.date, "d MMMM")
                                        color: pageRoot.banner ? IrisStyle.textStrong : IrisStyle.textSecondary
                                        font.pixelSize: IrisStyle.typeLabel
                                        font.weight: IrisStyle.weight(Font.Medium)
                                    }
                                    IrisClock { pixelSize: 46 * IrisStyle.typeScale }
                                }
                                ColumnLayout {
                                    visible: pageRoot.weatherReady
                                    Layout.alignment: Qt.AlignBottom
                                    spacing: 0
                                    RowLayout {
                                        Layout.alignment: Qt.AlignRight
                                        spacing: Math.round(6 * root.d)
                                        MaterialSymbol { text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"; fill: 1; iconSize: Math.round(22 * root.d); color: IrisStyle.text }
                                        IslandParts.Metric {
                                            readonly property string raw: String(Weather.data?.temp ?? "")
                                            value: raw.replace(/°?[CF]$/, "")
                                            unit: raw.length > value.length ? raw.slice(value.length) : ""
                                            pixelSize: 26 * IrisStyle.typeScale
                                            weight: Font.DemiBold
                                        }
                                    }
                                    IrisText {
                                        Layout.alignment: Qt.AlignRight
                                        Layout.maximumWidth: Math.round(150 * root.d)
                                        text: String(Weather.data?.description ?? "")
                                        color: pageRoot.banner ? IrisStyle.textStrong : IrisStyle.textSecondary
                                        font.pixelSize: IrisStyle.typeMeta
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: pageRoot.mode === "desktop" ? pageRoot.desktopBlocks : []
                            Loader {
                                id: desktopBlock
                                required property string modelData
                                Layout.fillWidth: true
                                sourceComponent: desktopBlock.modelData === "forecast" || desktopBlock.modelData === "vitals" ? stripBlock : rowBlock
                                Component {
                                    id: rowBlock
                                    BlockRow {
                                        glyph: ({ profile: "account_circle", context: "select_window", agenda: "event_upcoming", modules: "widgets" })[desktopBlock.modelData] ?? "circle"
                                        title: ({ profile: SystemInfo.displayName || SystemInfo.username || Translation.tr("You"),
                                            context: pageRoot.lastWindow?.title || Translation.tr("Current app"),
                                            agenda: Translation.tr("Up next"), modules: Translation.tr("Modules") })[desktopBlock.modelData] ?? ""
                                        detail: ({ profile: Translation.tr("Up %1").arg(DateTime.uptime), context: AppSearch.lookupDesktopEntry(pageRoot.lastWindow?.app_id ?? "")?.name || Translation.tr("Workspace"),
                                            agenda: Translation.tr("This week is clear"), modules: Translation.tr("Your desktop widgets") })[desktopBlock.modelData] ?? ""
                                    }
                                }
                                Component {
                                    id: stripBlock
                                    Rectangle {
                                        implicitHeight: stripRow.implicitHeight + (pageRoot.grouped ? Math.round(20 * root.d) : 0)
                                        radius: IrisStyle.radiusTile
                                        color: pageRoot.grouped ? IrisStyle.fillQuiet : "transparent"
                                        RowLayout {
                                            id: stripRow
                                            anchors.centerIn: parent
                                            width: parent.width - (pageRoot.grouped ? Math.round(20 * root.d) : 0)
                                            spacing: 0
                                            Repeater {
                                                model: desktopBlock.modelData === "forecast"
                                                    ? (pageRoot.hours.length > 0 ? pageRoot.hours : [{}, {}, {}, {}, {}, {}])
                                                    : [{ glyph: "memory", value: Math.round(ResourceUsage.cpuUsage * 100) + "%" },
                                                        { glyph: "memory_alt", value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%" },
                                                        { glyph: "device_thermostat", value: ResourceUsage.maxTemp + "°" },
                                                        { glyph: "hard_drive", value: Math.round(ResourceUsage.diskUsedPercentage * 100) + "%" }]
                                                ColumnLayout {
                                                    id: stripCell
                                                    required property var modelData
                                                    required property int index
                                                    Layout.fillWidth: true
                                                    Layout.preferredWidth: 1
                                                    spacing: Math.round(4 * root.d)
                                                    IrisText {
                                                        visible: desktopBlock.modelData === "forecast"
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: stripCell.index === 0 ? Translation.tr("Now") : String(stripCell.modelData.label ?? "").slice(0, 2)
                                                        color: IrisStyle.muted
                                                        font.pixelSize: IrisStyle.typeMeta
                                                    }
                                                    MaterialSymbol {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: desktopBlock.modelData === "forecast" ? (Icons.getWeatherIcon(stripCell.modelData.code, stripCell.modelData.isNight) ?? "cloud") : stripCell.modelData.glyph
                                                        fill: 1
                                                        iconSize: Math.round(17 * root.d)
                                                        color: desktopBlock.modelData === "forecast" ? IrisStyle.skyLight(text) : IrisStyle.subtext
                                                    }
                                                    IrisText {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: desktopBlock.modelData === "forecast" ? String(stripCell.modelData.temp ?? "—") : stripCell.modelData.value
                                                        font.family: IrisStyle.fontNumbers
                                                        font.pixelSize: IrisStyle.typeLabel
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: pageRoot.mode === "media" ? pageRoot.mediaBlocks : []
                            Loader {
                                id: mediaBlock
                                required property string modelData
                                Layout.fillWidth: true
                                sourceComponent: ({ player: playerBlock, timeline: timelineBlock, transport: transportBlock, players: playersBlock, levels: levelsBlock })[mediaBlock.modelData] ?? null
                                Component {
                                    id: playerBlock
                                    RowLayout {
                                        spacing: Math.round(14 * root.d)
                                        ClippingRectangle {
                                            implicitWidth: Math.round(56 * root.d); implicitHeight: implicitWidth
                                            radius: IrisStyle.radiusTile
                                            color: IrisStyle.fill
                                            IrisImage { anchors.fill: parent; source: String(MprisController.artUrlOf(pageRoot.player) ?? "") }
                                            MaterialSymbol { anchors.centerIn: parent; visible: String(MprisController.artUrlOf(pageRoot.player) ?? "").length === 0; text: "music_note"; fill: 1; iconSize: Math.round(26 * root.d); color: IrisStyle.subtext }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Math.round(2 * root.d)
                                            IrisText { Layout.fillWidth: true; text: MprisController.titleOf(pageRoot.player) || Translation.tr("Song title"); font.weight: IrisStyle.weight(Font.DemiBold); font.pixelSize: IrisStyle.typeHeadline; elide: Text.ElideRight }
                                            IrisText { Layout.fillWidth: true; text: MprisController.artistOf(pageRoot.player) || Translation.tr("Artist"); color: IrisStyle.subtext; elide: Text.ElideRight }
                                        }
                                    }
                                }
                                Component { id: timelineBlock; Level { value: 0.34; tint: IrisStyle.text } }
                                Component {
                                    id: transportBlock
                                    Item {
                                        implicitHeight: Math.round(30 * root.d)
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: Math.round(34 * root.d)
                                            Repeater {
                                                model: ["fast_rewind", pageRoot.player?.isPlaying ? "pause" : "play_arrow", "fast_forward"]
                                                MaterialSymbol { required property string modelData; text: modelData; fill: 1; iconSize: Math.round(26 * root.d); color: IrisStyle.text }
                                            }
                                        }
                                    }
                                }
                                Component {
                                    id: playersBlock
                                    BlockRow { glyph: "queue_music"; title: Translation.tr("Other players"); detail: Translation.tr("%1 playing").arg(Math.max(1, (MprisController.players ?? []).length)) }
                                }
                                Component {
                                    id: levelsBlock
                                    ColumnLayout {
                                        spacing: Math.round(10 * root.d)
                                        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: IrisStyle.hairline }
                                        Repeater {
                                            model: [0.66, 0.9]
                                            RowLayout {
                                                id: levelRow
                                                required property real modelData
                                                required property int index
                                                spacing: Math.round(12 * root.d)
                                                MaterialSymbol { text: levelRow.index === 0 ? "music_note" : "public"; fill: 1; iconSize: Math.round(17 * root.d); color: IrisStyle.subtext }
                                                IrisText { Layout.preferredWidth: Math.round(110 * root.d); text: levelRow.index === 0 ? Translation.tr("Player") : Translation.tr("Browser"); elide: Text.ElideRight }
                                                Level { value: levelRow.modelData; tint: IrisStyle.text }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Caption {
                glyph: pageRoot.mode === "media" ? "music_note" : pageRoot.mode === "pages" ? "view_carousel" : "space_dashboard"
                text: pageRoot.mode === "pages"
                    ? Translation.tr("%1 px · %2 pages, %3 shortcuts").arg(Math.round(pageRoot.pageW / root.d)).arg(pageRoot.pageCount).arg(pageRoot.actionCount)
                    : pageRoot.mode === "media"
                        ? (pageRoot.mediaBlocks.length > 0 ? Translation.tr("%1 blocks, in your order").arg(pageRoot.mediaBlocks.length) : Translation.tr("No blocks: the page is empty"))
                        : (pageRoot.banner ? Translation.tr("Wallpaper header") : Translation.tr("Plain header")) + " · "
                            + (pageRoot.grouped ? Translation.tr("grouped strips") : Translation.tr("plain rows")) + " · "
                            + Translation.tr("%1 blocks").arg(pageRoot.desktopBlocks.length)
            }
        }
    }

    Component {
        id: bubblesScene
        Item {
            id: bubRoot
            readonly property real naturalWidth: Math.round(760 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            readonly property bool snap: root.opt("iris.bubbles.snap", true)
            readonly property bool attach: root.opt("iris.bubbles.attach", true)
            readonly property bool cluster: root.opt("iris.bubbles.cluster", true)
            readonly property bool opensIsland: String(root.opt("iris.bubbles.opens", "card")) === "island"
            readonly property bool joined: root.opt("iris.appearance.surfaces.cards.joinOrigin", false)
            readonly property real size: IrisFrame.pieceBand
            readonly property real gap: bubRoot.attach ? 0 : Math.round(Math.max(0, Math.min(64, Number(root.opt("iris.bubbles.edgeGap", 20)))) * root.d)
            readonly property real split: bubRoot.cluster ? 0 : Math.round(6 * root.d)
            readonly property real pad: bubRoot.cluster ? Math.round(4 * root.d) : 0
            readonly property point home: Qt.point(width - IrisFrame.band - bubRoot.gap - bubRoot.pad - bubRoot.size, IrisFrame.band + bubRoot.gap + bubRoot.pad)
            readonly property point slot: Qt.point(bubRoot.home.x - bubRoot.size - bubRoot.split, bubRoot.home.y)
            readonly property point start: Qt.point(Math.round(width * 0.3), Math.round(height * 0.5))
            readonly property point drop: Qt.point(bubRoot.slot.x - Math.round(34 * root.d), bubRoot.slot.y + Math.round(46 * root.d))
            property int step: 0
            readonly property bool grabbed: bubRoot.step === 1
            readonly property bool settled: bubRoot.step >= 2 && bubRoot.step <= 5
            readonly property bool open: bubRoot.step === 4 || bubRoot.step === 5
            readonly property point rest: bubRoot.settled ? (bubRoot.snap ? bubRoot.slot : bubRoot.drop) : bubRoot.start
            property real bx: bubRoot.rest.x
            property real by: bubRoot.rest.y
            Behavior on bx { enabled: !bubRoot.grabbed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on by { enabled: !bubRoot.grabbed; NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Binding { when: bubRoot.grabbed; bubRoot.bx: bubPointer.x - bubRoot.size / 2 + bubPointer.width / 2 }
            Binding { when: bubRoot.grabbed; bubRoot.by: bubPointer.y - bubRoot.size / 2 + bubPointer.height / 2 }
            readonly property bool together: bubRoot.cluster && bubRoot.settled && bubRoot.snap
            readonly property bool framed: bubRoot.attach && bubRoot.settled && bubRoot.snap
            property real openness: bubRoot.open ? 1 : 0
            Behavior on openness { NumberAnimation { duration: bubRoot.open ? IrisStyle.emergeDuration : IrisStyle.recedeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: bubRoot.open ? IrisStyle.emergeCurve : IrisStyle.recedeCurve } }
            readonly property real islandW: Math.round(150 * root.d + (340 - 150) * root.d * (bubRoot.opensIsland ? bubRoot.openness : 0))
            readonly property real islandH: Math.round(IrisFrame.islandBand + (130 * root.d - IrisFrame.islandBand) * (bubRoot.opensIsland ? bubRoot.openness : 0))
            readonly property var card: ({
                x: Math.round(Math.max(IrisFrame.band + 8 * root.d, Math.min(bubRoot.width - IrisFrame.band - 230 * root.d, bubRoot.bx + bubRoot.size / 2 - 115 * root.d))),
                y: Math.round(bubRoot.by + bubRoot.size + (bubRoot.joined ? IrisStyle.weld : IrisFrame.bodyAir)),
                width: Math.round(230 * root.d),
                height: Math.max(1, Math.round(120 * root.d * bubRoot.openness))
            })

            Timer {
                running: root.playing
                interval: 900
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    bubRoot.step = (bubRoot.step + 1) % 7
                    if (bubRoot.step === 1 || bubRoot.step === 3) bubPointer.click()
                }
                onRunningChanged: if (!running) bubRoot.step = 2
            }

            Field.IrisField {
                anchors.fill: parent
                shapes: {
                    const out = []
                    const s = bubRoot.size
                    out.push({ x: (bubRoot.width - bubRoot.islandW) / 2, y: IrisFrame.band, width: bubRoot.islandW, height: bubRoot.islandH,
                        radius: Math.min(bubRoot.islandH / 2, IrisStyle.radius), fuse: IrisStyle.fuseEdge, id: "island", joins: "frame", paints: true })
                    if (bubRoot.together) {
                        const w = bubRoot.home.x + s - bubRoot.bx + 2 * bubRoot.pad
                        out.push({ x: bubRoot.bx - bubRoot.pad, y: bubRoot.home.y - bubRoot.pad, width: w, height: s + 2 * bubRoot.pad,
                            radius: IrisStyle.pieceRadius(s + 2 * bubRoot.pad), fuse: bubRoot.framed ? IrisStyle.fuseEdge : IrisStyle.fuse,
                            id: "plate", joins: bubRoot.framed ? "frame" : "", paints: true })
                    } else {
                        out.push({ x: bubRoot.home.x, y: bubRoot.home.y, width: s, height: s, radius: IrisStyle.pieceRadius(s),
                            fuse: bubRoot.attach ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "resident", joins: bubRoot.attach ? "frame" : "", paints: true })
                        out.push({ x: bubRoot.bx, y: bubRoot.by, width: s, height: s, radius: IrisStyle.pieceRadius(s),
                            fuse: bubRoot.framed ? IrisStyle.fuseEdge : IrisStyle.fuse, id: "carried", joins: bubRoot.framed ? "frame" : "", paints: true })
                    }
                    if (!bubRoot.opensIsland && bubRoot.openness > 0.01)
                        out.push(Object.assign({ radius: Math.min(IrisStyle.radiusSheet, bubRoot.card.height / 2), fuse: IrisStyle.fuseDeep,
                            id: "card", joins: bubRoot.joined ? (bubRoot.together ? "plate" : "carried") : "", paints: true }, bubRoot.card))
                    return out
                }
            }

            IrisClock {
                x: (bubRoot.width - width) / 2
                y: IrisFrame.band + (IrisFrame.islandBand - height) / 2
                opacity: 1 - (bubRoot.opensIsland ? bubRoot.openness : 0)
                pixelSize: IrisStyle.typeHeadline
                separatorColor: IrisStyle.secondaryAccent
            }
            MaterialSymbol {
                x: bubRoot.home.x + (bubRoot.size - width) / 2
                y: bubRoot.home.y + (bubRoot.size - height) / 2
                text: "partly_cloudy_day"; fill: 1
                iconSize: Math.round(bubRoot.size * 0.46)
                color: IrisStyle.identity.sky
            }
            MaterialSymbol {
                x: bubRoot.bx + (bubRoot.size - width) / 2
                y: bubRoot.by + (bubRoot.size - height) / 2
                scale: bubRoot.grabbed ? 1.08 : 1
                Behavior on scale { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
                text: "volume_up"; fill: 1
                iconSize: Math.round(bubRoot.size * 0.46)
                color: IrisStyle.identity.indigo
            }

            ColumnLayout {
                visible: bubRoot.openness > 0.02
                opacity: IrisStyle.ramp(bubRoot.openness, IrisStyle.dropRise, IrisStyle.dropSpan)
                x: bubRoot.opensIsland ? (bubRoot.width - bubRoot.islandW) / 2 + Math.round(18 * root.d) : bubRoot.card.x + Math.round(16 * root.d)
                y: bubRoot.opensIsland ? IrisFrame.band + Math.round(16 * root.d) : bubRoot.card.y + Math.round(14 * root.d)
                width: (bubRoot.opensIsland ? bubRoot.islandW : bubRoot.card.width) - Math.round(32 * root.d)
                spacing: Math.round(10 * root.d)
                RowLayout {
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol { text: "volume_up"; fill: 1; iconSize: Math.round(18 * root.d); color: IrisStyle.identity.indigo }
                    IrisText { text: Translation.tr("Sound"); font.weight: IrisStyle.weight(Font.DemiBold) }
                }
                Level { value: 0.62; tint: IrisStyle.identity.indigo }
                IrisText { text: Translation.tr("Speakers"); color: IrisStyle.muted; font.pixelSize: IrisStyle.typeMeta }
            }

            Pointer {
                id: bubPointer
                grabbing: bubRoot.grabbed
                travel: bubRoot.step === 1 ? 820 : 560
                x: bubRoot.step === 0 ? bubRoot.start.x + bubRoot.size * 0.55
                    : bubRoot.step === 1 ? bubRoot.drop.x + bubRoot.size / 2 - width / 2
                    : bubRoot.step === 2 ? bubRoot.drop.x + bubRoot.size * 0.9
                    : bubRoot.step === 6 ? bubRoot.width * 0.45
                    : bubRoot.rest.x + bubRoot.size * 0.55
                y: bubRoot.step === 0 ? bubRoot.start.y + bubRoot.size * 0.55
                    : bubRoot.step === 1 ? bubRoot.drop.y + bubRoot.size / 2 - height / 2
                    : bubRoot.step === 2 ? bubRoot.drop.y + bubRoot.size * 1.4
                    : bubRoot.step === 6 ? bubRoot.height * 0.72
                    : bubRoot.rest.y + bubRoot.size * 0.55
            }

            Caption {
                glyph: ["near_me", "back_hand", bubRoot.snap ? "select" : "pan_tool", "touch_app", bubRoot.opensIsland ? "pill" : "web_asset", bubRoot.opensIsland ? "pill" : "web_asset", "undo"][bubRoot.step]
                text: [Translation.tr("A bubble floats over the desktop"),
                    Translation.tr("Drag it towards a corner"),
                    !bubRoot.snap ? Translation.tr("Snap off: it stays where you let go")
                        : (bubRoot.attach ? Translation.tr("Snaps onto the frame") : Translation.tr("Snaps %1 px from the edges").arg(Math.round(bubRoot.gap / root.d)))
                            + (bubRoot.cluster ? " · " + Translation.tr("grouped into a bar") : ""),
                    Translation.tr("Tap it"),
                    bubRoot.opensIsland ? Translation.tr("Opens the Island") : bubRoot.joined ? Translation.tr("Grows its card, joined to it") : Translation.tr("Grows its card"),
                    bubRoot.opensIsland ? Translation.tr("Opens the Island") : bubRoot.joined ? Translation.tr("Grows its card, joined to it") : Translation.tr("Grows its card"),
                    Translation.tr("And back")][bubRoot.step]
            }
        }
    }

    Component {
        id: reserveScene
        Item {
            id: reserveRoot
            readonly property real naturalWidth: Math.round(640 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            readonly property bool reserve: root.opt("iris.bar.reserveSpace", true)
            readonly property string edge: IrisFrame.islandEdge
            readonly property bool bottomEdge: reserveRoot.edge === "bottom"
            readonly property bool vertical: reserveRoot.edge === "left" || reserveRoot.edge === "right"
            readonly property real islandSpan: IrisFrame.band + IrisFrame.islandMargin + IrisFrame.islandBand
            function inset(side: string): real {
                if (side === reserveRoot.edge) return reserveRoot.reserve ? reserveRoot.islandSpan + Math.round(8 * root.d) : IrisFrame.band
                return Math.round((side === "top" || side === "bottom" ? 24 : 40) * root.d)
            }
            Rectangle {
                x: reserveRoot.inset("left")
                // From the targets, not the animating x/y, or the size overshoots while they move.
                width: parent.width - reserveRoot.inset("left") - reserveRoot.inset("right")
                y: reserveRoot.inset("top")
                height: parent.height - reserveRoot.inset("top") - reserveRoot.inset("bottom")
                Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                radius: IrisStyle.radiusTile
                color: IrisStyle.surfaceHigh
                border.width: 1
                border.color: IrisStyle.border
                Behavior on y { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Behavior on height { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                Row {
                    x: Math.round(12 * root.d); y: Math.round(11 * root.d)
                    spacing: Math.round(6 * root.d)
                    Repeater { model: 3; Rectangle { required property int index; width: Math.round(10 * root.d); height: width; radius: width / 2; color: IrisStyle.fillStrong } }
                }
                Rectangle { x: Math.round(12 * root.d); y: Math.round(38 * root.d); width: parent.width * 0.42; height: Math.round(9 * root.d); radius: height / 2; color: IrisStyle.fill }
                Rectangle { x: Math.round(12 * root.d); y: Math.round(56 * root.d); width: parent.width * 0.6; height: Math.round(9 * root.d); radius: height / 2; color: IrisStyle.fillQuiet }
            }
            IslandPill {
                readonly property real inset: IrisFrame.band + IrisFrame.islandMargin
                vertical: reserveRoot.vertical
                x: reserveRoot.edge === "left" ? inset : reserveRoot.edge === "right" ? parent.width - inset - width : Math.round((parent.width - width) / 2)
                y: reserveRoot.edge === "top" ? inset : reserveRoot.bottomEdge ? parent.height - inset - height : Math.round((parent.height - height) / 2)
            }
            Caption {
                anchors.bottom: reserveRoot.bottomEdge ? undefined : parent.bottom
                anchors.top: reserveRoot.bottomEdge ? parent.top : undefined
                glyph: !reserveRoot.reserve ? "layers" : reserveRoot.edge === "left" ? "align_horizontal_left"
                    : reserveRoot.edge === "right" ? "align_horizontal_right" : reserveRoot.bottomEdge ? "vertical_align_bottom" : "vertical_align_top"
                text: !reserveRoot.reserve ? Translation.tr("Windows run under the Island")
                    : reserveRoot.vertical ? Translation.tr("Windows start beside the Island")
                    : reserveRoot.bottomEdge ? Translation.tr("Windows end above the Island") : Translation.tr("Windows start below the Island")
            }
        }
    }

    Component {
        id: interactionScene
        Item {
            id: actRoot
            readonly property real naturalWidth: Math.round(620 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            readonly property bool hover: root.opt("iris.bar.hoverExpand", true)
            readonly property int delay: Math.max(120, Math.min(800, Number(root.opt("iris.bar.hoverDelay", 300))))
            readonly property string scroll: String(root.opt("iris.bar.scrollAction", "volume"))
            readonly property bool events: root.opt("iris.bar.events", true)
            readonly property bool caps: actRoot.events && root.opt("keyboardIndicators.popup.caps", true)
            property int step: 0
            property bool expanded: false
            property bool clicked: false
            property real level: 0.35
            readonly property real restW: Math.round(150 * root.d)
            readonly property real restH: IrisFrame.islandBand
            readonly property real pillW: actRoot.expanded ? Math.round(360 * root.d) : actRoot.step === 3 && actRoot.events ? Math.round(260 * root.d) : actRoot.restW
            readonly property real pillH: actRoot.expanded ? Math.round(150 * root.d) : actRoot.restH
            Timer {
                running: root.playing
                interval: 1700
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    actRoot.step = (actRoot.step + 1) % 4
                    actRoot.expanded = false
                    actRoot.clicked = false
                    if (actRoot.step === 1) expandTimer.restart()
                    if (actRoot.step === 2) actRoot.level = 0.35
                }
            }
            Timer {
                id: expandTimer
                interval: actRoot.hover ? actRoot.delay : 420
                onTriggered: { actRoot.clicked = !actRoot.hover; actRoot.expanded = true }
            }
            Timer {
                running: root.playing && actRoot.step === 2 && actRoot.scroll !== "none"
                interval: 120
                repeat: true
                onTriggered: actRoot.level = Math.min(0.85, actRoot.level + 0.05)
            }
            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                y: IrisFrame.band + IrisFrame.islandMargin
                width: actRoot.pillW
                height: actRoot.pillH
                radius: actRoot.expanded ? IrisStyle.radius : height / 2
                color: IrisStyle.bodySurface
                border.width: IrisStyle.rim.a > 0 ? 1 : 0
                border.color: IrisStyle.rim
                IrisGlassEdge { anchors.fill: parent; z: 10; visible: IrisStyle.edgeLit && shown; radius: parent.radius }
                Behavior on width { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on height { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                Behavior on radius { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                IrisClock {
                    anchors.centerIn: parent
                    visible: !actRoot.expanded && !(actRoot.step === 2 && actRoot.scroll !== "none") && !(actRoot.step === 3 && actRoot.events)
                    pixelSize: IrisStyle.typeHeadline
                    separatorColor: IrisStyle.secondaryAccent
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(14 * root.d)
                    anchors.rightMargin: Math.round(16 * root.d)
                    visible: actRoot.step === 2 && actRoot.scroll !== "none" && !actRoot.expanded
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol { text: actRoot.scroll === "brightness" ? "light_mode" : "volume_up"; fill: 1; iconSize: Math.round(16 * root.d); color: IrisStyle.text }
                    Level { value: actRoot.level; tint: IrisStyle.text }
                }
                RowLayout {
                    anchors.centerIn: parent
                    visible: actRoot.step === 3 && actRoot.events && !actRoot.expanded
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol { text: "battery_charging_full"; fill: 1; iconSize: Math.round(17 * root.d); color: IrisStyle.identity.green }
                    IrisText { text: Translation.tr("Charger connected"); font.weight: IrisStyle.weight(Font.DemiBold) }
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(18 * root.d)
                    visible: actRoot.expanded
                    opacity: actRoot.expanded ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(200); easing.type: IrisStyle.feedbackEasing } }
                    IrisText { text: Qt.locale().toString(DateTime.clock.date, "dddd d MMMM"); color: IrisStyle.secondaryAccent; font.weight: IrisStyle.weight(Font.DemiBold) }
                    IrisText { text: Qt.locale().toString(DateTime.clock.date, "hh:mm"); font.family: IrisStyle.fontNumbers; font.weight: IrisStyle.figureWeight; font.pixelSize: 40 * IrisStyle.typeScale }
                    Item { Layout.fillHeight: true }
                    Level { value: 0.6 }
                }
            }
            Rectangle {
                anchors.horizontalCenter: pill.horizontalCenter
                anchors.top: pill.bottom
                anchors.topMargin: Math.round(8 * root.d)
                visible: actRoot.step === 3 && actRoot.caps
                width: capsLabel.implicitWidth + Math.round(24 * root.d)
                height: Math.round(26 * root.d)
                radius: height / 2
                color: IrisStyle.bodySurface
                IrisText { id: capsLabel; anchors.centerIn: parent; text: Translation.tr("Caps Lock on"); font.pixelSize: IrisStyle.typeMeta; font.weight: IrisStyle.weight(Font.DemiBold) }
            }
            MaterialSymbol {
                id: pointer
                text: actRoot.step === 2 ? "mouse" : "arrow_selector_tool"
                fill: 1
                iconSize: Math.round(22 * root.d)
                color: "white"
                x: actRoot.step === 0 ? parent.width * 0.72 : pill.x + pill.width * 0.55
                y: actRoot.step === 0 ? parent.height * 0.7 : pill.y + Math.min(pill.height - 8, IrisFrame.islandBand * 0.6)
                visible: actRoot.step < 3
                Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                Rectangle {
                    anchors.centerIn: parent
                    width: actRoot.clicked ? parent.width * 1.6 : 0
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: IrisStyle.accent
                    opacity: actRoot.clicked ? 0 : 1
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                    Behavior on opacity { NumberAnimation { duration: 420; easing.type: IrisStyle.feedbackEasing } }
                }
            }
            Caption {
                glyph: ["near_me", actRoot.hover ? "timer" : "ads_click", "swipe_vertical", "campaign"][actRoot.step]
                text: [Translation.tr("Resting"),
                    actRoot.hover ? Translation.tr("Opens after resting %1 ms").arg(actRoot.delay) : Translation.tr("Opens on a click"),
                    actRoot.scroll === "none" ? Translation.tr("Scroll does nothing") : actRoot.scroll === "brightness" ? Translation.tr("Scroll sets brightness") : Translation.tr("Scroll sets volume"),
                    actRoot.events ? (actRoot.caps ? Translation.tr("System events and the Caps Lock badge") : Translation.tr("System events")) : Translation.tr("System events off")][actRoot.step]
            }
        }
    }

    Component {
        id: typographyScene
        Item {
            readonly property real naturalWidth: Math.round(560 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            Plate {
                anchors.centerIn: parent
                width: Math.round(480 * root.d)
                height: Math.round(216 * root.d)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Math.round(24 * root.d)
                    spacing: Math.round(6 * root.d)
                    IrisText { text: Translation.tr("A little room to breathe"); font.family: IrisStyle.fontTitle; font.pixelSize: IrisStyle.typeTitleLarge; font.weight: IrisStyle.weight(Font.Medium) }
                    IrisClock { pixelSize: 56 * IrisStyle.typeScale; separatorColor: IrisStyle.secondaryAccent }
                    Rectangle { Layout.fillWidth: true; height: 1; color: IrisStyle.hairline }
                    RowLayout {
                        Layout.fillWidth: true
                        IrisText { text: Translation.tr("Words, figures, one family"); color: IrisStyle.subtext }
                        Item { Layout.fillWidth: true }
                        IrisText { text: "Aa 0123"; color: IrisStyle.accent; font.pixelSize: IrisStyle.typeTitle }
                    }
                }
            }
            Caption { glyph: "text_fields"; text: Translation.tr("Your typefaces, weight and text size") }
        }
    }

    Component {
        id: motionScene
        Item {
            readonly property real naturalWidth: Math.round(540 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            IrisMotionLab {
                anchors.fill: parent
                anchors.margins: Math.round(12 * root.d)
                playing: root.playing && root.visible && IrisStyle.motionEnabled
            }
            Caption { glyph: "animation"; text: IrisStyle.motionEnabled ? Translation.tr("The same motion when opening and closing") : Translation.tr("Motion is off") }
        }
    }

    Component {
        id: frameScene
        Item {
            id: framePreview
            readonly property real naturalWidth: Math.round(540 * root.d)
            readonly property real naturalHeight: Math.round(280 * root.d)
            readonly property bool wave: root.section === "frameMusic" && root.opt("background.edgeWidgets.organic.enable", false) && String(root.opt("iris.surround.music", "widget")) === "widget"
            readonly property bool music: root.section === "frameMusic"
                && root.opt("background.edgeWidgets.organic.enable", false)
                && String(root.opt("iris.surround.music", "widget")) === "frame"
            property real phase: 0
            readonly property real strength: Number(root.opt("iris.surround.musicStrength", 160)) / 100
            readonly property real sensitivity: Number(root.opt("iris.surround.musicSensitivity", 140)) / 100
            readonly property string edges: String(root.opt("iris.surround.musicEdges", "sides"))
            Timer {
                interval: 50
                repeat: true
                running: root.playing && root.visible && (framePreview.wave || (framePreview.music && IrisFrame.framed)) && IrisStyle.motionEnabled
                onTriggered: framePreview.phase += 0.05 * Number(root.opt("iris.surround.musicSpeed", 100)) / 100
            }
            Field.IrisField {
                anchors.fill: parent
                anchors.margins: Math.round(16 * root.d)
                framed: IrisFrame.framed
                band: IrisFrame.band
                cornerRadius: IrisFrame.cornerRadius
                // Miniatures always sample wallpaper; they never blur Settings itself.
                compositorAllowed: false
                edgeWave: {
                    const level = framePreview.music ? Math.min(20, (5 + 3 * Math.sin(framePreview.phase * 3)) * framePreview.strength * framePreview.sensitivity) : 0
                    const sides = framePreview.edges !== "horizontal", horizontal = framePreview.edges !== "sides"
                    return Qt.vector4d(horizontal ? level : 0, sides ? level : 0, horizontal ? level : 0, sides ? level : 0)
                }
                waveClock: framePreview.phase
                frameMusicLevel: framePreview.music ? 0.5 : 0
                shapes: [{ x: width / 2 - 66 * root.d, y: 0, width: 132 * root.d, height: 30 * root.d,
                    radius: IrisStyle.radiusTile, id: "island", joins: "frame", fuse: IrisStyle.fuse }]
            }
            IrisClock { anchors.centerIn: parent; pixelSize: 48 * IrisStyle.typeScale; separatorColor: IrisStyle.secondaryAccent }
            Shape {
                anchors.fill: parent
                visible: framePreview.wave
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: IrisStyle.accent
                    strokeWidth: Math.round(3 * root.d)
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathMultiline {
                        paths: [Array.from({length: 49}, (_, i) => Qt.point(i / 48 * framePreview.width,
                            framePreview.height - 24 * root.d - (10 + 7 * Math.sin(i * 0.2 + framePreview.phase * 3)) * root.d))]
                    }
                }
            }
            OffState { visible: !IrisFrame.framed && !framePreview.wave; text: Translation.tr("Frame off") }
            Caption { glyph: "crop_free"; text: framePreview.wave ? Translation.tr("Music follows the screen edges") : framePreview.music ? Translation.tr("A sample of your frame's music response") : Translation.tr("The frame's width, corners and material") }
        }
    }

    Component {
        id: lockScene
        Item {
            id: lockPreview
            readonly property real naturalWidth: Math.round(540 * root.d)
            readonly property real naturalHeight: Math.round(300 * root.d)
            readonly property string source: String(root.opt("iris.lock.scene.source", "desktop"))
            readonly property real blur: Number(root.opt("iris.lock.scene.blur", 100)) / 100
            readonly property real dim: Number(root.opt("iris.lock.scene.dim", 0)) / 100
            readonly property string clockFormat: String(root.opt("iris.lock.type.clockFormat", "auto"))
            readonly property string format: lockPreview.clockFormat === "24h" ? "HH:mm" : lockPreview.clockFormat === "12h" ? "h:mm AP" : String(Config.options?.time?.format ?? "hh:mm")
            Rectangle { anchors.fill: parent; color: IrisStyle.surface }
            IrisWallpaperView {
                id: lockWall
                anchors.fill: parent
                active: root.visible && lockPreview.source !== "colour"
                live: false
                screen: GlobalStates.focusedScreen
                path: lockPreview.source === "custom" ? String(root.opt("iris.lock.scene.path", "")) : configuredPath
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
                saturation: Number(root.opt("iris.lock.scene.saturation", 100)) / 100 - 1
                autoPaddingEnabled: false
            }
            Rectangle { anchors.fill: parent; color: IrisStyle.surface; opacity: lockPreview.dim }
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Math.round(64 * root.d)
                spacing: Math.round(10 * root.d)
                IrisText {
                    visible: root.opt("iris.lock.blocks.clock.enable", true)
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().toString(DateTime.clock.date, lockPreview.format + (root.opt("iris.lock.type.seconds", false) ? ":ss" : ""))
                    font.family: IrisLockOptions.clockFamily
                    font.pixelSize: Number(root.opt("iris.lock.type.clockSize", 112)) * 0.6 * IrisLockOptions.typeScale
                    font.weight: Number(root.opt("iris.lock.type.clockWeight", 700))
                    font.letterSpacing: Number(root.opt("iris.lock.type.clockTracking", -4))
                    color: IrisLockOptions.accentColour
                }
                IrisText {
                    visible: root.opt("iris.lock.blocks.clock.enable", true) && String(root.opt("iris.lock.type.dateFormat", "long")) !== "none"
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.locale().toString(DateTime.clock.date, String(root.opt("iris.lock.type.dateFormat", "long")) === "short" ? "ddd d MMM" : "dddd d MMMM")
                    color: IrisStyle.onMediaSecondary
                }
                RowLayout {
                    visible: root.opt("iris.lock.blocks.glance.enable", true)
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Math.round(16 * root.d)
                    MaterialSymbol { visible: root.opt("iris.lock.blocks.glance.weather", true); text: "partly_cloudy_day"; color: IrisStyle.onMedia; iconSize: Math.round(22 * root.d) }
                    MaterialSymbol { visible: root.opt("iris.lock.blocks.glance.events", true); text: "event"; color: IrisStyle.onMedia; iconSize: Math.round(22 * root.d) }
                    MaterialSymbol { visible: root.opt("iris.lock.blocks.glance.battery", true); text: "battery_full"; color: IrisStyle.onMedia; iconSize: Math.round(22 * root.d) }
                }
                Rectangle {
                    visible: root.opt("iris.lock.blocks.session.enable", true)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Number(root.opt("iris.lock.blocks.session.width", 248)) * 0.65
                    Layout.preferredHeight: Math.round(32 * root.d)
                    radius: height / 2
                    color: IrisStyle.onMediaFill
                    MaterialSymbol { anchors.centerIn: parent; text: "lock"; color: IrisStyle.onMedia; iconSize: Math.round(18 * root.d) }
                }
                IrisText {
                    visible: root.opt("iris.lock.blocks.media.enable", true)
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: parent.width
                    text: MprisController.titleOf(MprisController.activePlayer) || Translation.tr("Now playing")
                    color: IrisStyle.onMediaSecondary
                    elide: Text.ElideRight
                }
            }
            Caption { glyph: "lock"; text: Translation.tr("Your lock screen, without locking") }
        }
    }
}
