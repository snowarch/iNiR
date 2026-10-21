pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.iris.style
import qs.modules.iris.components
import qs.modules.iris.preview.scenes

// The live preview a Settings group shows above its rows: picks the group's scene (preview/scenes, built from the parts
// in preview/parts), decodes the wallpaper once for it and scales it to the frame.
ClippingRectangle {
    id: root

    property string section: ""
    property string group: ""
    property bool playing: true
    // Awake for a few seconds after it appears, after any change and while the pointer is on it; then every scene rests on
    // what it shows. Settings left open stops drawing (measured 2026-10-11: a scene looping in an idle Settings cost the
    // shell 16-18 % CPU, closed 1.4 %).
    readonly property bool awake: wakeTimer.running || sceneHover.hovered
    function wake(): void { wakeTimer.restart() }
    Timer { id: wakeTimer; interval: 9000; running: true }
    HoverHandler { id: sceneHover }
    Connections {
        target: Config
        function onRevisionChanged(): void { root.wake() }
    }
    onSceneChanged: root.wake()
    onPlayingChanged: if (root.playing) root.wake()
    property bool compact: false
    property string caption: ""
    // Niri's values for the scenes that draw them (windows, keyboard, the screen); Settings passes its reader in.
    property var niriValue: null
    property int niriRevision: 0
    readonly property real d: IrisStyle.density
    readonly property string scene: root.sceneFor(root.section, root.group)
    readonly property bool available: (Config.options?.iris?.appearance?.previews ?? true) && root.scene.length > 0
    readonly property real wantedHeight: Math.round(Math.min(420 * root.d, Math.max(260 * root.d, Number(sceneLoader.item?.naturalHeight ?? 0))))
    readonly property string wallpaper: WallpaperListener.wallpaperUrlForScreen(GlobalStates.focusedScreen)
    readonly property Item wallpaperView: wallpaperImage

    function sceneFor(section: string, group: string): string {
        if (group.length === 0)
            return ({ dock: "dock", player: "player", desktop: "widgets", widgets: "widgets", sidebars: "panels", controlCenter: "controlCenter", spotlight: "spotlight", bubbles: "bubbles",
                bar: "islandEdge", appearance: "fusion", colour: "palette", wallpaper: "gallery", login: "login", motion: "motion", lock: "lock", notifications: "feedback", sound: "feedback",
                windows: "windows", display: "display", keyboard: "keyboard", orbit: "orbit", capture: "capture", anime: "anime",
                sources: "sources", battery: "battery" })[section] ?? ""
        const key = section + "/" + group
        return ({
            "bar/Visibility": "islandReserve", "bar/Interaction": "islandInteraction",
            "bar/Shape": "shapes", "bar/Layout": "islandEdge", "bar/Bar": "barZones",
            "appearance/Light": "light", "appearance/Shape": "shapes", "appearance/Corners per surface": "surfaces", "appearance/Glass": "glass", "appearance/Edges": "glass",
            "appearance/Menus": "menus", "appearance/Settings": "settings",
            "appearance/Texture": "texture", "appearance/Material": "material", "appearance/Material per surface": "surfaces", "appearance/Look": "fusion",
            "appearance/Adaptive": "fusion",
            "appearance/Faces": "typography", "appearance/Text": "typography", "appearance/Frame": "frame",
            "colour/Colour theme": "palette", "colour/Scheme": "palette", "colour/Accent": "palette", "colour/Highlight": "highlight",
            "colour/App colours": "palette", "colour/Dark look": "palette", "colour/Ink look": "palette", "colour/Light look": "palette",
            "colour/Wallpaper tint": "palette",
            "login/Login Screen": "login",
            "desktop/Desktop menu": "menus",
            "motion/Motion": "motion", "motion/Curve": "motion", "motion/Timing": "motion",
            "motion/Per surface": "motion", "motion/Style per surface": "motion", "motion/Touch": "motion",
            "player/Frame music": "frame", "player/Frame response": "frame", "player/Frame finish": "frame",
            "lock/Scene": "lock", "lock/Type": "lock", "lock/Clock": "lock", "lock/At a glance": "lock",
            "lock/Now playing": "lock", "lock/Activity": "lock", "lock/Sign in": "lock", "lock/Status": "lock",
            "bar/Desktop page": "islandPage", "bar/Pages": "islandPage", "bar/Player page": "islandPage",
            "bubbles/Behaviour": "bubbles", "bubbles/Floating": "bubbles", "bubbles/On the contour": "bubbles", "bubbles/Size": "bubbles",
            "bubbles/Cards": "cards", "bubbles/Card contents": "cards", "bubbles/Joining": "joining", "bubbles/Tray": "tray",
            "dock/Visibility": "dock", "dock/Icons": "dock", "dock/Look": "dock",
            "desktop/Widgets": "widgets", "wallpaper/Overview backdrop": "backdrop", "wallpaper/Wallpaper gallery": "gallery",
            "spotlight/Spotlight": "spotlight", "controlCenter/Control Center": "controlCenter",
            "sidebars/Panel look": "panels",
            "notifications/Banners": "feedback", "sound/Feedback": "feedback",
            "player/Player": "player", "player/Bubble": "player"
        })[key] ?? ""
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
        // A scene that reflows (`narrowest`, `lowest`) is laid out at the size it is drawn at, down to those: shrunk whole
        // from its natural size, AIRISU's 308 px column scaled the Dock to 0.41 and its 40 px icons came out 16 px and soft.
        readonly property real wide: (sceneLoader.item?.narrowest ?? 0) > 0 ? sceneLoader.item.narrowest : sceneLoader.item?.naturalWidth ?? 1
        readonly property real tall: (sceneLoader.item?.lowest ?? 0) > 0 ? sceneLoader.item.lowest : sceneLoader.item?.naturalHeight ?? 1
        readonly property real fit: Math.min(1, root.width / Math.max(1, world.wide),
            sceneLoader.item?.cropBottom ? 1 : root.height / Math.max(1, world.tall))
        // Any shortfall shrinks it: kept at 1 down to 0.85, a scene a few percent too wide cut its words at the edge.
        readonly property real k: world.fit
        width: root.width / world.k
        height: root.height / world.k
        scale: world.k
        transformOrigin: Item.TopLeft
        // Drawn at twice the frame and read back with one linear step: a mipmapped layer sampled a level under the frame
        // and every line of the scene's type came out soft.
        layer.enabled: world.k < 0.999
        layer.smooth: true
        layer.textureSize: Qt.size(Math.max(1, Math.ceil(root.width * 2)), Math.max(1, Math.ceil(root.height * 2)))

        Loader {
            id: sceneLoader
            anchors.fill: parent
            active: root.available && root.visible
            sourceComponent: ({
                typography: typographyScene, frame: frameScene, lock: lockScene, motion: motionScene,
                texture: textureScene, dock: dockScene, widgets: widgetsScene, backdrop: backdropScene, gallery: galleryScene,
                spotlight: spotlightScene, controlCenter: controlCenterScene, cards: cardsScene, menus: menusScene,
                settings: settingsScene, panels: panelsScene, joining: joiningScene, feedback: feedbackScene,
                tray: trayScene, player: playerScene, islandReserve: islandReserveScene, islandEdge: islandEdgeScene, barZones: barZonesScene,
                light: lightScene, palette: paletteScene, fusion: fusionScene, shapes: shapesScene, glass: glassScene,
                islandInteraction: islandInteractionScene, islandPage: islandPageScene, bubbles: bubblesScene,
                highlight: highlightScene, login: loginScene, material: materialScene, surfaces: surfacesScene,
                windows: windowsScene, display: displayScene, keyboard: keyboardScene, orbit: orbitScene, capture: captureScene,
                anime: animeScene, sources: sourcesScene, battery: batteryScene
            })[root.scene] ?? null
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        // A chamfered Design cuts the frame with its own die; this rule would run on through the cut corners.
        border.width: IrisStyle.fieldChamfer ? 0 : 1
        border.color: IrisStyle.border
    }

    Component { id: backdropScene; BackdropScene { preview: root } }
    Component { id: windowsScene; WindowsScene { preview: root } }
    Component { id: displayScene; DisplayScene { preview: root } }
    Component { id: keyboardScene; KeyboardScene { preview: root } }
    Component { id: orbitScene; OrbitScene { preview: root } }
    Component { id: captureScene; CaptureScene { preview: root } }
    Component { id: animeScene; AnimeScene { preview: root } }
    Component { id: sourcesScene; SourcesScene { preview: root } }
    Component { id: batteryScene; BatteryScene { preview: root } }
    Component { id: barZonesScene; BarZonesScene { preview: root } }
    Component { id: bubblesScene; BubblesScene { preview: root } }
    Component { id: cardsScene; CardsScene { preview: root } }
    Component { id: controlCenterScene; ControlCenterScene { preview: root } }
    Component { id: dockScene; DockScene { preview: root } }
    Component { id: feedbackScene; FeedbackScene { preview: root } }
    Component { id: frameScene; FrameScene { preview: root } }
    Component { id: fusionScene; FusionScene { preview: root } }
    Component { id: galleryScene; GalleryScene { preview: root } }
    Component { id: glassScene; GlassScene { preview: root } }
    Component { id: highlightScene; HighlightScene { preview: root } }
    Component { id: islandEdgeScene; IslandEdgeScene { preview: root } }
    Component { id: islandInteractionScene; IslandInteractionScene { preview: root } }
    Component { id: islandPageScene; IslandPageScene { preview: root } }
    Component { id: islandReserveScene; IslandReserveScene { preview: root } }
    Component { id: joiningScene; JoiningScene { preview: root } }
    Component { id: lightScene; LightScene { preview: root } }
    Component { id: lockScene; LockScene { preview: root } }
    Component { id: loginScene; LoginScene { preview: root } }
    Component { id: materialScene; MaterialScene { preview: root } }
    Component { id: menusScene; MenusScene { preview: root } }
    Component { id: motionScene; MotionScene { preview: root } }
    Component { id: paletteScene; PaletteScene { preview: root } }
    Component { id: panelsScene; PanelsScene { preview: root } }
    Component { id: playerScene; PlayerScene { preview: root } }
    Component { id: settingsScene; SettingsScene { preview: root } }
    Component { id: shapesScene; ShapesScene { preview: root } }
    Component { id: spotlightScene; SpotlightScene { preview: root } }
    Component { id: surfacesScene; SurfacesScene { preview: root } }
    Component { id: textureScene; TextureScene { preview: root } }
    Component { id: trayScene; TrayScene { preview: root } }
    Component { id: typographyScene; TypographyScene { preview: root } }
    Component { id: widgetsScene; WidgetsScene { preview: root } }
}
