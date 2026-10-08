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
    property bool compact: false
    property string caption: ""
    readonly property real d: IrisStyle.density
    readonly property string scene: root.sceneFor(root.section, root.group)
    readonly property bool available: (Config.options?.iris?.appearance?.previews ?? true) && root.scene.length > 0
    readonly property real wantedHeight: Math.round(Math.min(420 * root.d, Math.max(260 * root.d, Number(sceneLoader.item?.naturalHeight ?? 0))))
    readonly property string wallpaper: WallpaperListener.wallpaperUrlForScreen(GlobalStates.focusedScreen)
    readonly property Item wallpaperView: wallpaperImage

    function sceneFor(section: string, group: string): string {
        if (group.length === 0)
            return ({ dock: "dock", player: "player", desktop: "widgets", sidebars: "panels", controlCenter: "controlCenter", spotlight: "spotlight", bubbles: "bubbles",
                bar: "islandEdge", appearance: "palette", motion: "motion", lock: "lock", frameMusic: "frame", notifications: "feedback", sound: "feedback" })[section] ?? ""
        const key = section + "/" + group
        return ({
            "bar/Visibility": "islandReserve", "bar/Interaction": "islandInteraction",
            "bar/Shape": "shapes", "bar/Layout": "islandEdge", "bar/Bar": "barZones",
            "appearance/Light": "light", "appearance/Shape": "shapes", "appearance/Colour theme": "palette", "appearance/Scheme": "palette", "appearance/Dark look": "palette", "appearance/Ink look": "palette", "appearance/Light look": "palette", "appearance/App colours": "palette", "appearance/Wallpaper": "palette", "appearance/Corners per surface": "fusion", "appearance/Glass": "glass", "appearance/Edges": "glass",
            "appearance/Menus": "menus", "appearance/Settings": "settings",
            "appearance/Material": "glass", "appearance/Material per surface": "glass", "appearance/Look": "fusion",
            "appearance/Adaptive": "fusion", "appearance/Accent": "palette", "appearance/Highlight": "palette",
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
                spotlight: spotlightScene, controlCenter: controlCenterScene, cards: cardsScene, menus: menusScene,
                settings: settingsScene, panels: panelsScene, joining: joiningScene, feedback: feedbackScene,
                tray: trayScene, player: playerScene, islandReserve: islandReserveScene, islandEdge: islandEdgeScene, barZones: barZonesScene,
                light: lightScene, palette: paletteScene, fusion: fusionScene, shapes: shapesScene, glass: glassScene,
                islandInteraction: islandInteractionScene, islandPage: islandPageScene, bubbles: bubblesScene
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

    Component { id: backdropScene; BackdropScene { preview: root } }
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
    Component { id: islandEdgeScene; IslandEdgeScene { preview: root } }
    Component { id: islandInteractionScene; IslandInteractionScene { preview: root } }
    Component { id: islandPageScene; IslandPageScene { preview: root } }
    Component { id: islandReserveScene; IslandReserveScene { preview: root } }
    Component { id: joiningScene; JoiningScene { preview: root } }
    Component { id: lightScene; LightScene { preview: root } }
    Component { id: lockScene; LockScene { preview: root } }
    Component { id: menusScene; MenusScene { preview: root } }
    Component { id: motionScene; MotionScene { preview: root } }
    Component { id: paletteScene; PaletteScene { preview: root } }
    Component { id: panelsScene; PanelsScene { preview: root } }
    Component { id: playerScene; PlayerScene { preview: root } }
    Component { id: settingsScene; SettingsScene { preview: root } }
    Component { id: shapesScene; ShapesScene { preview: root } }
    Component { id: spotlightScene; SpotlightScene { preview: root } }
    Component { id: trayScene; TrayScene { preview: root } }
    Component { id: typographyScene; TypographyScene { preview: root } }
    Component { id: widgetsScene; WidgetsScene { preview: root } }
}
