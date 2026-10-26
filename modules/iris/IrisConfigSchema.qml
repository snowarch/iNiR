import QtQuick
import Quickshell.Io

// iRiS's part of the shell config (`iris.*` in config.json): Config holds it in its `iris` slot once this plugin is
// installed (plugin.json `configKey`). Defaults also live in defaults/config.json and settings/IrisOptions.qml.
JsonObject {
    property JsonObject sidebars: JsonObject {
        property JsonObject left: JsonObject {
            property bool enable: true
            property int width: 380
            property int height: 88
            property string alignment: "center"
            property bool pinned: false
            property bool reserveSpace: true
            property bool notch: false // attach to the screen edge
            property bool hoverReveal: false // open by resting at the screen edge
            property list<string> sections: ["media", "tasks", "notes"]
            property list<string> expanded: [] // Sections shown open; the rest rest compact
        }
        property JsonObject right: JsonObject {
            property bool enable: true
            property int width: 380
            property int height: 88
            property string alignment: "center"
            property bool pinned: false
            property bool reserveSpace: true
            property bool notch: false // attach to the screen edge
            property bool hoverReveal: false // open by resting at the screen edge
            property list<string> sections: ["calendar", "weather", "notifications"]
            property list<string> expanded: [] // Sections shown open; the rest rest compact
        }
    }
    property JsonObject widgets: JsonObject {
        property int radius: 22
        property int opacity: 100
        property string tint: "wallpaper" // accents: "wallpaper", "system" (iRiS), "spectrum" or "mono"
        property int vibrance: 85 // how strong widget accents are (0-100)
        property bool legibleAlways: false // Lume backs every widget as if the wallpaper under it were bright and busy
        property string design: "iris" // "iris" faces, "material" (each widget's own style), "instrument" or "readout"
        property string material: "glass" // "glass", "clear", "solid" or "tinted"
        property string weight: "regular" // "light", "regular" or "bold"
        property bool rim: false
        property string outline: "auto" // "auto" (the shell's outline; Transparent bare), "always" or "none"
        property bool brightWallpapers: false
    }
    property JsonObject desktopMenu: JsonObject {
        property bool wallpaper: true // The wallpaper at the head of the right-click menu
        property list<string> items: ["widgets", "customize", "screenshot", "terminal", "settings", "restart"]
    }
    property JsonObject dock: JsonObject {
        property bool enable: true
        property bool autoHide: true
        property bool reserveSpace: true
        property bool blur: false // legacy: read as material "blur" while material is "inherit"
        property string material: "inherit" // "inherit" (iRiS glass), "solid", "glass" or "blur" (Niri blurs what is below)
        property int iconSize: 40
        property bool notch: true
        property string shape: "auto" // "auto" (capsule when notched, else the bubbles' shape), "round", "squircle" or "square"
        property bool magnification: false
        property int magnifySize: 150 // hovered icon at its largest, % of its size
        property bool badges: true // Unread notification counts on app icons
        property bool launcher: true // Applications button at the start of the Dock
        property bool reorder: true
        property string arrange: "pinned" // "pinned" (pinned apps keep their place while open) or "opened" (open apps together, in the order opened)
        property bool revealOnEmpty: true // Auto-hide keeps the dock shown on an empty workspace
        property string position: "auto" // "auto" (opposite the Island), "top", "bottom", "left" or "right"
    }
    property JsonObject appearance: JsonObject {
        property string preset: "iris" // IrisStyle.presets: iris, soft, round, crisp, angular, contrast
        property string morph: "direct" // IrisStyle.morphStyles: direct, liquid, glide, snap, elastic, instant
        property string accent: "blue" // "blue", "mint", "rose", "lilac" or "wallpaper"
        property string scheme: "auto" // "auto" (follows the system), "dark", "ink" or "light"
        property string language: "iris" // the palette's style: "iris" (iRiS's own), "washi" (paper and pigment) or "material" (Material You)
        property string variant: "tonalSpot" // Material You's scheme: "tonalSpot", "vibrant", "expressive", "fidelity" or "monochrome"
        property string inkStyle: "washi" // Ink's own style: "washi" (paper and sumi, whatever the style) or "style" (follows language)
        property string darkStyle: "style" // Dark's: "style" (the style's own night) or "ink" (washi, a sumi night paper)
        property bool followTheme: true // with a colour theme chosen, the shell wears its accent, highlight and material
        property bool materialForApps: true // with the wallpaper colour theme, terminals and apps sit on the shell's material
        property bool accentForApps: true // with the wallpaper colour theme, apps take the shell's own accent when it has one
        property string controlPlate: "none" // rows of round controls: "none", "veil", "glass" or "solid" (IrisControlPlate)
        property string texture: "solid" // what the material is drawn as: "solid", "afterglow" or "leak" (IrisField.frag)
        // Afterglow: grade "dusk", "cyber", "fog" or "wallpaper"; the rest 0..100 %; wallpaper grades the desktop too.
        property JsonObject afterglow: JsonObject {
            property string grade: "dusk"
            property int atmosphere: 60
            property int chrome: 65
            property int bloom: 50
            property int signal: 35
            property bool wallpaper: true
        }
        // Light leak: grade "prism", "ember", "orchid", "polaroid", "accent" or "wallpaper"; shape "lens", "burn",
        // "orbs" or "beam"; x/y move the light (-50..50 % of the output); the rest 0..100 %; wallpaper is how
        // strongly the desktop is exposed (0 off), frame the screen edge's band, widgets the desktop widgets;
        // grainSize in px (1..4), dust 0..200 %, gate the lens's corners and film edge, develop the Polaroid rise.
        property JsonObject leak: JsonObject {
            property string grade: "prism"
            property string shape: "lens"
            property int x: 0
            property int y: 0
            property int light: 60
            property int frame: 100
            property int widgets: 100
            property int spill: 55
            property int prism: 50
            property int grain: 55
            property real grainSize: 1.6
            property int streaks: 15
            property int dust: 100
            property bool gate: true
            property int wallpaper: 50
            property string backdrop: "picture"
            property bool develop: true
        }
        // Per scheme: tone lifts or dims the material (-30..30), colour is how strong accents read (0..100 %),
        // widgets is how colourful the desktop widgets read (40..160 %), lume makes bodies frost the wallpaper
        // shows through instead of solid; warmth (0..100) is how much washi fibre the paper (or Dark's ink night) carries.
        property JsonObject tune: JsonObject {
            property JsonObject dark: JsonObject { property int tone: 0; property int warmth: 20; property int colour: 100; property int widgets: 100; property bool lume: false }
            property JsonObject ink: JsonObject { property int tone: 0; property int warmth: 50; property int colour: 100; property int widgets: 100; property bool lume: true }
            property JsonObject light: JsonObject { property int tone: -8; property int warmth: 38; property int colour: 85; property int widgets: 110; property bool lume: true }
        }
        property string highlight: "orange" // "orange", "yellow", "red", "pink", "green", "accent" or "wallpaper"
        property JsonObject anime: JsonObject {
            property bool enabled: false
            property string palette: "sakura" // IrisStyle.animePalettes
            property int strength: 60 // 0 = the configured accent, 100 = the palette
            property bool highlight: false
        }
        // How much of the wallpaper's hue the black surfaces carry.
        // 0 keeps iRiS pure black; 1 is a few percent of the wallpaper
        // in the raised surfaces and the neutral fills, never in the
        // primary surface.
        property int tint: 0
        // The light a body carries from what it is — its content's
        // colour, or the wallpaper's when it has none: "off",
        // "subtle" or "vivid" (IrisStyle.aura).
        property string aura: "subtle"
        property int adaptive: 0 // how much the wallpaper's brightness, contrast and colour shape iRiS (0-100)
        property string figureWeight: "bold" // "light", "regular" or "bold"
        // The pack every iRiS plate wears: "iris" (the family's tinted squircle)
        // or "tile" (the app-icon look: a plate with the glyph in a gradient of
        // its own colour). `plate` picks that plate's colour.
        property JsonObject icons: JsonObject {
            property string style: "iris"
            property string plate: "black" // "black", "white", "tint" or "surface"
        }
        property int expandedRadius: 28
        property int motionDuration: 220
        property string fontFamily: "" // Empty = Geist (bundled)
        property string titleFontFamily: "" // Empty = Geist (bundled)
        property string numbersFontFamily: "" // Empty = Archivo SemiExpanded (bundled; the figure voice)
        // The one colour of Signal (live, needs you, errors): "nothing" (#D71921), "wallpaper" or a #rrggbb.
        property string signal: "nothing"
        // apple: the accent marks what is chosen; nothing: ink body, one signal colour; synth: keys and faders; gel: glossy accent
        property string look: "apple"
        // Where a look other than Apple is worn; a place turned off keeps Apple's controls and type.
        property JsonObject nothingOn: JsonObject {
            property bool island: true
            property bool dock: true
            property bool settings: true
            property bool spotlight: true
            property bool orbit: true
            property bool lock: true
            property bool widgets: true
            property bool notifications: true
            property bool osd: true
        }
        property real density: 1.0
        property bool motion: true
        // iRiS Studio: the user's own tweaks on top of the preset. Every
        // number is a percentage of what the preset gives (100 = as the
        // preset has it), so switching presets keeps the character of
        // the tweaks.
        property JsonObject theme: JsonObject {
            // The material itself: "black", "graphite", "midnight" or "wallpaper".
            property string surface: "black"
            property int fill: 100      // neutral fills: groups, hover, pressed
            property int lines: 100     // hairlines and borders
            property int contrast: 100  // secondary and tertiary text
            property int shadow: 100    // shadows under floating bodies
            property int shape: 100     // every corner radius
            property int melt: 0        // how deeply bodies fuse where they meet (100 = the style's own depth)
            property int bounce: 100    // how much arrivals and moves bounce (100 = the motion style's own)
            property int text: 100      // iRiS type size
            property string weight: "regular" // iRiS type weight: "light", "regular" or "bold"
            property bool rim: true     // the hairline around the field's silhouette
            property string edges: "line" // the edge every body wears: "line" (the hairline) or "light" (lit from above like glass); rim false turns it off
            property string rimTint: "neutral" // that hairline's ink: "neutral", "accent" or "highlight"
            property int rimWidth: 1    // the width of every body's edge, line or lit glass: 1-3 device pixels
            property int glow: 0        // how much shadows take the accent colour, 0-100
            property int accentHue: 212    // accent "custom": its hue, 0-359
            property int highlightHue: 32  // highlight "custom": its hue, 0-359
            property int lightReach: 100   // how far into a body its light reaches
            property string badge: "alert" // unread counts: "alert", "accent", "highlight" or "neutral"
            property int air: 8            // gap between an opened body and the bar or piece it came from
            property string placement: "auto" // where bodies open from a piece: "auto" (away from its edge) or "along" (along its edge)
            property string curve: "expressive" // direct motion curve: "expressive", "standard", "gentle", "swift" or "custom"
            property list<real> curvePoints: [0.16, 1, 0.3, 1] // the custom curve's two control points
            property int openTime: 100     // how long shapes take to open and close, % of the style
            property int moveTime: 100     // how long open shapes take to adjust, % of the style
            property int contentTiming: 100 // when content shows up inside a growing shape, % of the style
            property int press: 100        // how deep controls dip when pressed
            property string pieceShape: "circle" // bubbles, bars and satellites: "circle", "squircle" or "square"
            property bool linkShapes: false // the Island and the Dock take the bubbles' shape
        }
        // Animated previews in iRiS Settings and Studio; off builds none of them.
        property bool previews: true
        // How Customize opens: "shell" (on the shell itself) or "studio" (a panel beside it).
        property string customize: "shell"
        // Choosing a theme takes only its colours; its shapes, layout and motion stay as they are.
        property bool themeColoursOnly: false
        property string settingsHost: "overlay"
        // How iRiS Settings lays its page: "folio", "deck" or "console" (a Design with its own page keeps it).
        property string settingsLayout: "classic"
        // What iRiS Settings' Home holds, in order: rows by path, nightLight and gameMode for the live switches.
        property list<string> settingsHome: ["iris.appearance.scheme", "iris.appearance.accent", "iris.appearance.look", "iris.appearance.glass.mode", "notifications.silent", "nightLight", "gameMode"]
        // Looks saved from iRiS Studio: [{ name, values: { "iris.…": value } }].
        property list<var> saved: []
        property string themeId: "iris" // the iRiS theme last applied (curated id or a file in ~/.config/inir/iris/themes)
        // The iRiS Design: the anatomy every part is drawn with (modules/iris/designs/<id>, DESIGNS.md).
        // "iris" draws the primitives as they are; a Theme may choose another when it is applied.
        property string design: "iris"
        property JsonObject glass: JsonObject {
            property string mode: "off" // "off", "wallpaper" (the output's wallpaper, blurred) or "compositor" (Niri blurs what is below)
            property int tint: 58       // how much of the material stays over the glass, 0-100
            property int blur: 100      // wallpaper glass blur, % of the maximum
            // The cut edge of Blur glass: light where it faces up, a line elsewhere (%) and colour ("scene" = the wallpaper's light, "white", "accent", "highlight").
            property int edgeLight: 34
            property int edgeLine: 10
            property string edgeColour: "scene"
        }
        // Per surface: its own corners (0 = the family's) and its light
        // ("inherit" = its identity, "wallpaper", or "off").
        property JsonObject surfaces: JsonObject {
            property JsonObject island: JsonObject { property int radius: 0; property int speed: 100; property string morph: "" }
            property JsonObject controlCenter: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject cards: JsonObject { property string design: "welded"; property int radius: 0; property string light: "inherit"; property int width: 0; property int speed: 100; property string morph: ""; property string material: ""; property bool joinOrigin: false; property int gap: 0; property int pad: 0; property string grabber: "auto"; property bool header: true; property bool devices: true; property bool mixer: true }
            property JsonObject panels: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject spotlight: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject orbit: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject settings: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject gallery: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
            property JsonObject menus: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: ""; property string density: "compact" }
            property JsonObject osd: JsonObject { property int radius: 0; property string light: "inherit"; property int speed: 100; property string morph: ""; property string material: "" }
        }
    }
    property JsonObject bar: JsonObject {
        property string position: "top" // "top", "bottom", "left" or "right"
        property string composition: "cluster" // "unified" or "cluster"
        property bool notch: true
        // Notch shoulders: how far the Island melts into its edge (%).
        property int notchCurve: 100
        property string shape: "auto" // "auto" (capsule when notched, else the bubbles' shape), "round", "squircle" or "square"
        property int satelliteGap: 6
        property int clockScale: 100 // resting clock and date size, %
        property string clockAccent: "highlight" // time separator and day number: "highlight", "accent" or "plain"
        property int padding: 100 // room around the resting Island's content, %
        property int satelliteScale: 100 // bubbles beside the Island, % of its height
        // How the resting Island sits on its edge: "island" hugs its
        // content in the middle, "left"/"right" hug an end, "full"
        // spans the whole edge as a bar.
        property string layout: "island"
        property string strip: "clear" // menu bar: "clear" (items on the wallpaper) or "band"
        // A full-width Island is a bar: what rests at its start, centre and end, in order.
        // "island" (the live Island), "workspaces", "window", "time" and piece kinds.
        property list<string> fullStart: ["workspaces", "window"]
        property list<string> fullCenter: ["island"]
        property list<string> fullEnd: ["tray", "notifications", "sound", "controls"]
        // Extra pieces the Island carries itself, in the order they are
        // switched on: registry kinds (weather, sound, tray, ...).
        property list<string> pieces: []
        property bool hoverExpand: true
        property int hoverDelay: 300
        // Expanded Island: page width (px) and its navigation, in order (media, activity, desktop,
        // tray, tools, focus, today, controls, settings).
        property int pageWidth: 440
        property list<string> navItems: ["media", "activity", "desktop", "shelf", "weather", "calendar", "vitals", "tray", "tools", "focus", "today", "controls", "settings"]
        property string design: "halo" // the Island's design: "halo", "ledger" or "tiles"
        property string blockStyle: "plain" // desktop page blocks: "plain" on the Island's black or "grouped" on quiet plates
        property string scrollAction: "volume" // "volume", "brightness" or "none"
        property string desktopBanner: "wallpaper" // Island Desktop page header: "wallpaper" or "none"
        property int desktopBannerFade: 100
        property int desktopBannerTop: 100
        property int desktopBannerVeil: 100
        property int desktopBannerBlur: 0
        property string navFrame: "auto" // the open Island's page buttons: "auto" (Appearance › Button rows), "none", "veil", "glass" or "solid"
        // Island Desktop page blocks under the hero, in order:
        // "profile", "context", "vitals", "modules".
        property list<string> desktopBlocks: ["profile", "context", "forecast", "agenda", "modules"]
        property list<string> mediaBlocks: ["player", "timeline", "transport", "players", "levels"]
        property string clockStyle: "dateTime" // resting clock: "time", "dateTime" or "weather"
        property string auxiliary: "tray" // "tray", "tools", "sound", "mic" or "none"
        property string piecesSide: "end" // Which end of the resting Island carries its own pieces: "end" or "start"
        property bool scrollBubbles: true // The scroll action also works over the bubbles beside the Island
        property bool events: true // Charger, Bluetooth, Do Not Disturb and keyboard events in the Island
        property string trailing: "controls" // Cluster trailing bubble: "controls", "notifications", "weather", "sound", "mic" or "none"
        property int height: 42
        property int margin: 8
        property bool autoHide: false // Rest the pointer at the Island's edge to bring it back
        property bool revealOnEmpty: true // Keep the Island visible on an empty workspace while auto-hide is on
        property bool reserveSpace: true
        property list<string> screenList: []
        property list<string> leftModules: []
        property list<string> centerModules: []
        property list<string> rightModules: [] // Island Desktop page: "custom:<widget-id>" modules
    }
    property JsonObject orbit: JsonObject {
        property bool enable: false
        property string opens: "island" // "island": the Island becomes Orbit; "floating": a sheet under it
        property bool previews: true // Niri's own screenshot of each window, when there is one
        property int previewAge: 10 // seconds a picture of the workspace you are on may be old
        property int width: 1100
        property int cardHeight: 440 // the tallest the workspace you are on gets
        property int peek: 56 // how much of the neighbouring workspaces shows (0 hides them)
        property bool wallpaper: true
        property string titles: "hover" // "hover", "always" or "off"
        property string labels: "full" // "full" (number and name) or "number"
        property int dimMatches: 78 // how far the windows that do not match a search fall back
        property bool hints: true
        property bool showRecent: true
        property int recentCount: 5
        property bool showMinimised: true
        property bool showActions: true
        property int thumbSize: 88
        property bool closeOnGo: true
        property bool scroll: true
        property bool askSpotlight: true
        property string stashRestore: "original" // "original" workspace or the "current" one
        property string keys: "niri" // "niri": ↑ ↓ workspaces, ← → windows; "swapped" the other way
        property bool hotCorner: true
        property string hotCornerAt: "auto" // "auto" picks a free corner; or "topLeft", "topRight", "bottomLeft", "bottomRight"
        property int hotCornerSize: 12
        property int hotCornerDelay: 150 // ms the pointer rests in the corner before Orbit opens
    }
    property JsonObject palette: JsonObject {
        property string opens: "floating" // "floating" below the Island, or "island": the Island itself becomes Spotlight
        property int width: 640
        property int maxResults: 8
        property int clipboardResults: 8
        property bool showHints: true
    }
    property JsonObject tray: JsonObject {
        property bool hidePassive: false
        property bool labels: true
        property int columns: 4
        property string face: "apps" // "apps" or "count": what the tray bubble shows
    }
    property JsonObject wallpaper: JsonObject {
        // The highlighted wallpaper shows on the desktop while browsing.
        property bool livePreview: true
        property string layout: "reel" // reel | mosaic | browser (strip/showcase read as reel, wall as browser)
        property bool motion: true // live wallpapers play their preview while chosen
        property string liveQuality: "best" // "best": the 4K file when offered; "light": HD
        property string sort: "newest" // library order: newest | oldest | name
        property string onlineSort: "top" // online sources: top | hot | newest | views | favorites | random
        property string topRange: "1w" // what "top" covers online: 1d | 1w | 1M | 1y
        property string ratio: "screen" // shape asked of the web: screen | wide | portrait | any
        property list<string> sources: ["wallhaven", "live"] // online sources shown, in order
        property bool suggestive: false // swimsuits, lingerie, fan service in online results
        property list<string> pinned: []
    }
    property JsonObject player: JsonObject {
        property bool roundCover: false
        property bool artworkBackground: true
        // What the media bubble becomes: a card floating out of it, or the Island page.
        property string bubbleOpens: "card"
        // Keep the card floating beside the Island while something is playing.
        property bool cardPinned: false
        // The visualizer on the Island, its player page and the Visualizer bubble.
        property JsonObject visualizer: JsonObject {
            property string style: "capsules" // capsules | rise | dots | wave | ring
            property int bars: 5
            property string colour: "art" // art | accent | highlight | ink
        }
    }
    // Where each Island bubble slot rests: "island", a zone ("top-left",
    // "top-right", "left", "right", "bottom-left", "bottom-right") or "free"
    // at fx/fy (its centre as fractions of the output).
    property JsonObject bubbles: JsonObject {
        property int scale: 100 // size of pieces off the Island, % of the Island height
        property JsonObject left: JsonObject {
            property string place: "island"
            property real fx: 0.5
            property real fy: 0.5
        }
        property JsonObject right: JsonObject {
            property string place: "island"
            property real fx: 0.5
            property real fy: 0.5
        }
        property JsonObject utility: JsonObject {
            property string place: "island"
            property real fx: 0.5
            property real fy: 0.5
        }
        // Bubbles of their own, off the Island only: one per kind, placed like
        // the slots above (a zone or "free"); several in one zone line up.
        property JsonObject extras: JsonObject {
            property JsonObject weather: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject notifications: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject controls: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject sound: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject mic: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject tools: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject media: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject tray: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject calendar: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject clock: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject battery: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject focus: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject awake: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject nightLight: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject capture: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject keyboard: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject wallpaper: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject power: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject network: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject bluetooth: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject vitals: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject workspaces: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
                property string opens: "card"
            }
            property JsonObject updates: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject vpn: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject visualizer: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject shellUpdate: JsonObject {
                property bool enable: true
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject anime: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
            property JsonObject watching: JsonObject {
                property bool enable: false
                property string place: "right"
                property real fx: 0.5
                property real fy: 0.5
            }
        }
        // Distance (px) floating bubbles keep from the screen edges.
        property int edgeGap: 20
        // "card": a bubble grows into a card of its own (weather, sound,
        // microphone, notifications, timers, tray); "island": it opens the
        // Island page or panel it stands for, and level bubbles mute.
        property string opens: "card"
        property string design: "glass" // bubbles: "glass", "tint" or "outline"
        // Dropped near a zone, a bubble snaps to it; off, it stays where it is let go.
        property bool snap: true
        // Bubbles sharing a zone rest on one plate and read as a small
        // bar; off, each one floats as its own disc.
        property bool cluster: true
        // Bubbles in a zone sit on the shell's own edge, where they read
        // as a swelling of the frame; off, they float over the windows at
        // `edgeGap` from the edges.
        property bool attach: true
        // How attached bubbles meet the edge: "notch" (they melt into it with the
        // Island's shoulders), "weld" (they touch it) or "gap" (the Island's margin).
        property string join: "notch"
        property int notchCurve: 100 // depth of those shoulders, % of the Island's
        // An edge carrying bubbles takes its space from the desktop, like
        // the Island's edge does, so nothing is covered by them.
        property bool reserve: true
        // Apps carried out of the Dock, each one a quick-launch bubble:
        // { appId, place, fx, fy }, placed like any other piece.
        property list<var> apps: []
    }
    property JsonObject anime: JsonObject {
        property int shows: 5 // how many upcoming episodes the Airing card lists
        property list<var> following: [] // AniList ids you follow; the piece shows these first
        property string audio: "sub" // "sub" Japanese audio with subtitles | "dub" dubbed (ani-cli --dub)
        property string quality: "best" // ani-cli -q: "best" | "1080" | "720" | "480"
        property int subtitleScale: 100 // mpv sub-scale, percent
        property int subtitlePosition: 100 // mpv sub-pos: 100 is the bottom edge
        property bool skipIntro: false // ani-cli --skip, needs ani-skip
    }
    property JsonObject pieces: JsonObject {
        // Glyph chosen for a piece whose resting face is a glyph:
        // { kind, glyph }, glyph being a Material Symbol name.
        property list<var> icons: []
    }
    // Surround: the shell closes around the display with one band on
    // every edge, turning the screen's corners inward.
    property JsonObject surround: JsonObject {
        property bool enable: true
        property string music: "widget" // Organic Edge under iRiS: "widget" (its own wave) or "frame" (the frame breathes)
        property string musicEdges: "sides" // "sides" | "horizontal" | "all"
        property int musicStrength: 160 // 50-300 %, maximum inward swell
        property int musicSensitivity: 140 // 50-250 %, response to quiet music
        property int musicSpeed: 100 // 40-200 %, travel along the frame
        property string musicAppearance: "etched" // "sculpted" | "etched" | "satin"
        property string musicColour: "pearl" // "pearl" | "accent" | "highlight" | "wallpaper"
        property int musicLight: 35 // 0-100 %, light on the moving inner edge
        property int musicLightWidth: 5 // 1-18 px, edge treatment width
        property int thickness: 10
        property int radius: 22
    }
    property JsonObject controlCenter: JsonObject {
        property string opens: "island" // "island": the Island becomes the Control Center; "panel": a panel hangs from it
        // "tiles" (wide glyph tiles on the panel) or "round" (the
        // same round body as the connectivity toggles, in a module).
        property string controls: "tiles"
        property int width: 360
        // 2.31's composition, read only to seed `modules` for configs that changed it.
        property list<string> sections: ["connectivity", "media", "shortcuts", "levels", "notifications"]
        property string preset: "iris"
        property int columns: 4
        property bool labels: true
        property list<string> modules: ["platter", "media", "darkMode", "nightLight", "levels", "idle", "snip", "devices", "record", "notifications"]
        // Per-module shapes, as "<id>:<columns>x<rows>" ("F" = full width).
        property list<string> sizes: ["devices:2x1", "record:2x1"]
        property list<string> platter: ["network", "bluetooth", "focus", "gameMode"]
        property list<string> levels: ["brightness", "volume", "microphone"]
        property string accent: "system" // "system", "accent", "colourful" or "mono"
        property string sliders: "neutral" // "neutral" or "accent"
    }
    property JsonObject lock: JsonObject {
        property string preset: "iris"
        property string material: "glass" // "glass", "tint" or "none": what the plates are made of
        property JsonObject scene: JsonObject {
            property string source: "desktop" // "desktop", "custom" or "colour"
            property string path: ""
            property int blur: 100
            property int dim: 0
            property int saturation: 15
            property string scrim: "gradient" // "gradient", "flat" or "none"
            property int scrimStrength: 100
            property int vignette: 0
            property string motion: "none" // "none" or "drift": a slow Ken Burns over the still
            property int driftTime: 40 // seconds for one drift pass
            property string fit: "cover" // "cover" or "contain"
        }
        property JsonObject type: JsonObject {
            property int scale: 100
            property int clockSize: 112
            property string clockFont: "numbers" // "numbers", "main" or "title"
            property int clockWeight: 700
            property int clockTracking: -2
            property string accent: "plain" // "plain", "accent" or "highlight"
            property string clockFormat: "auto" // "auto", "24h" or "12h"
            property bool seconds: false
            property string dateFormat: "long" // "long", "short", "numeric" or "weekday"
        }
        property JsonObject blocks: JsonObject {
            property JsonObject clock: JsonObject {
                property bool enable: true
                property string style: "stack" // "stack", "inline" or "minimal"
                property string zone: "top"
                property real fx: 0.5
                property real fy: 0.09
                property int scale: 100
                property bool date: true
            }
            property JsonObject glance: JsonObject {
                property bool enable: true
                property string zone: "top"
                property real fx: 0.5
                property real fy: 0.26
                property int scale: 100
                property bool weather: true
                property bool events: true
                property bool battery: true
            }
            property JsonObject media: JsonObject {
                property bool enable: true
                property string style: "card" // "card" or "bare"
                property string zone: "bottom"
                property real fx: 0.5
                property real fy: 0.34
                property int scale: 100
            }
            property JsonObject activity: JsonObject {
                property bool enable: true
                property string zone: "top"
                property real fx: 0.5
                property real fy: 0.46
                property int scale: 100
            }
            property JsonObject session: JsonObject {
                property bool enable: true
                property string zone: "bottom"
                property real fx: 0.5
                property real fy: 0.89
                property int scale: 100
                property bool avatar: true
                property bool name: true
                property bool hint: true
                property int width: 248
            }
            property JsonObject status: JsonObject {
                property bool enable: false
                property string zone: "topRight"
                property real fx: 0.9
                property real fy: 0.06
                property int scale: 100
                property bool battery: true
                property bool network: true
                property bool keyboard: true
            }
        }
    }
    property JsonObject notifications: JsonObject {
        property int width: 380
        property int duration: 4000 // Banner time on screen (ms) when the app does not set one
        property bool fullscreen: true // banners over fullscreen windows; off holds them for Today
    }
    property JsonObject osd: JsonObject {
        property int width: 320
        property string position: "bottom" // "bottom" or "top"
        property int offset: 18
        property int duration: 1500
        property string levels: "yours" // "yours", "every" or "off": volume, brightness and mic
        property string media: "yours" // "yours", "every" or "off": song changes
        property bool keyboard: true
        property string fullscreen: "show" // "show", "quiet" or "hide": over fullscreen windows and in Game mode
        property string style: "capsule" // "capsule", "bar" or "minimal": how a level is drawn
        property bool figure: true
    }
    property JsonObject modules: JsonObject {
        property bool desktopWidgets: true
        property bool palette: true
        property bool controlCenter: true
        property bool notificationPopup: true
        property bool osd: true
        property bool sessionScreen: true
        property bool lock: true
        property bool polkit: true
    }
}
