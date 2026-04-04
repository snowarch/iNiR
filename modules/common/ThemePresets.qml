pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

Singleton {
    id: root

    // Available tags for filtering
    readonly property var availableTags: [
        { id: "dark", name: Translation.tr("Dark"), icon: "dark_mode" },
        { id: "light", name: Translation.tr("Light"), icon: "light_mode" },
        { id: "pastel", name: Translation.tr("Pastel"), icon: "palette" },
        { id: "vibrant", name: Translation.tr("Vibrant"), icon: "colorize" },
        { id: "minimal", name: Translation.tr("Minimal"), icon: "remove" },
        { id: "retro", name: Translation.tr("Retro"), icon: "history" },
        { id: "nature", name: Translation.tr("Nature"), icon: "eco" },
        { id: "neon", name: Translation.tr("Neon"), icon: "bolt" }
    ]

    readonly property var presets: [
        {
            id: "auto",
            name: "Auto (Wallpaper)",
            description: "Colors generated from your wallpaper",
            icon: "wallpaper",
            colors: null,
            tags: []
        },
        {
            id: "custom",
            name: "Custom",
            description: "Your personalized color palette",
            icon: "edit",
            colors: "custom",
            tags: []
        },
        {
            id: "angel",
            name: "Angel",
            description: "Celestial twilight with warm golden halos",
            icon: "brightness_7",
            colors: angelColors,
            tags: ["dark", "pastel"],
            meta: {
                roundingScale: 1.2,
                fontStyle: "serif"
            }
        },
        {
            id: "angel-light",
            name: "Angel Light",
            description: "Ethereal dawn with warm cream tones",
            icon: "wb_twilight",
            colors: angelLightColors,
            tags: ["light", "pastel"],
            meta: {
                roundingScale: 1.2
            }
        },
        {
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            description: "Pastel colors on dark backgrounds",
            icon: "palette",
            colors: catppuccinMochaColors,
            tags: ["dark", "pastel"],
            meta: {
                roundingScale: 1.15
            }
        },
        {
            id: "catppuccin-latte",
            name: "Catppuccin Latte",
            description: "Pastel colors on light backgrounds",
            icon: "palette",
            colors: catppuccinLatteColors,
            tags: ["light", "pastel"],
            meta: {
                roundingScale: 1.15
            }
        },
        {
            id: "material-black",
            name: "Material Black",
            description: "Pure black with elegant muted accents",
            icon: "palette",
            colors: materialBlackColors,
            tags: ["dark", "minimal"]
        },
        {
            id: "gruvbox-material",
            name: "Gruvbox Material",
            description: "Gruvbox with Material Design refinements",
            icon: "palette",
            colors: gruvboxMaterialColors,
            tags: ["dark", "retro"],
            meta: {
                roundingScale: 0.8,
                fontStyle: "mono"
            }
        },
        {
            id: "nord",
            name: "Nord",
            description: "Arctic blue-gray tones",
            icon: "palette",
            colors: nordColors,
            tags: ["dark", "minimal"],
            meta: {
                roundingScale: 0.9
            }
        },

        {
            id: "kanagawa",
            name: "Kanagawa",
            description: "Inspired by Katsushika Hokusai's Great Wave",
            icon: "tsunami",
            colors: kanagawaColors,
            tags: ["dark", "nature"],
            meta: {
                roundingScale: 1.0
            }
        },
        {
            id: "kanagawa-dragon",
            name: "Kanagawa Dragon",
            description: "Darker variant with dragon ink tones",
            icon: "whatshot",
            colors: kanagawaDragonColors,
            tags: ["dark", "vibrant"],
            meta: {
                roundingScale: 1.0
            }
        },
        {
            id: "samurai",
            name: "Samurai",
            description: "Deep crimson and steel inspired by bushido",
            icon: "swords",
            colors: samuraiColors,
            tags: ["dark", "vibrant"],
            meta: {
                roundingScale: 0.4,
                borderWidthScale: 1.2
            }
        },
        {
            id: "tokyo-night",
            name: "Tokyo Night",
            description: "Neon city lights on midnight blue",
            icon: "location_city",
            colors: tokyoNightColors,
            tags: ["dark", "neon"],
            meta: {
                roundingScale: 1.0,
                borderWidthScale: 1.1
            }
        },
        {
            id: "sakura",
            name: "Sakura",
            description: "Cherry blossom pink on soft cream",
            icon: "local_florist",
            colors: sakuraColors,
            tags: ["light", "pastel", "nature"],
            meta: {
                roundingScale: 1.3
            }
        },
        {
            id: "zen-garden",
            name: "Zen Garden",
            description: "Tranquil moss greens and stone grays",
            icon: "spa",
            colors: zenGardenColors,
            tags: ["light", "nature", "minimal"],
            meta: {
                roundingScale: 1.5,
                fontStyle: "sans"
            }
        },
        {
            id: "everforest",
            name: "Everforest",
            description: "Natural, warm, and organic",
            icon: "forest",
            colors: everforestColors,
            tags: ["dark", "nature"]
        },
        {
            id: "ayu",
            name: "Ayu",
            description: "Bright and elegant",
            icon: "wb_sunny",
            colors: ayuColors,
            tags: ["dark", "minimal"],
            meta: {
                roundingScale: 1.0
            }
        },
        {
            id: "catppuccin-macchiato",
            name: "Catppuccin Macchiato",
            description: "Soft, warm high-contrast dark",
            icon: "coffee",
            colors: catppuccinMacchiatoColors,
            tags: ["dark", "pastel"],
            meta: {
                roundingScale: 1.15
            }
        },
        {
            id: "matrix",
            name: "Matrix",
            description: "Follow the white rabbit",
            icon: "terminal",
            colors: matrixColors,
            tags: ["dark", "neon", "retro"],
            meta: {
                roundingScale: 0,
                fontStyle: "mono",
                borderWidthScale: 2.0
            }
        },
        {
            id: "one-dark",
            name: "One Dark",
            description: "Atom-inspired dark theme",
            icon: "code",
            colors: oneDarkColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.9
            }
        },
        {
            id: "gruvbox-dark",
            name: "Gruvbox Dark",
            description: "Retro groove color scheme (Hard)",
            icon: "dataset",
            colors: gruvboxDarkColors,
            tags: ["dark", "retro"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.7,
                borderWidthScale: 1.1
            }
        },
        {
            id: "catppuccin-frappe",
            name: "Catppuccin Frappe",
            description: "Soft, warm pastel palette",
            icon: "icecream",
            colors: catppuccinFrappeColors,
            tags: ["dark", "pastel"],
            meta: {
                roundingScale: 1.15
            }
        },
        {
            id: "dracula",
            name: "Dracula",
            description: "Dark theme for vampires",
            icon: "nightlight",
            colors: draculaColors,
            tags: ["dark", "vibrant"],
            meta: {
                fontStyle: "mono",
                roundingScale: 1.0
            }
        },
        {
            id: "solarized-dark",
            name: "Solarized Dark",
            description: "Precision colors for machines and people",
            icon: "wb_sunny",
            colors: solarizedDarkColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.8
            }
        },
        {
            id: "monokai-pro",
            name: "Monokai Pro",
            description: "Focus and code",
            icon: "filter_vintage",
            colors: monokaiProColors,
            tags: ["dark", "vibrant"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.9
            }
        },
        {
            id: "rose-pine",
            name: "Rosé Pine",
            description: "All natural pine, faux fur and bits of gold",
            icon: "local_florist",
            colors: rosePineColors,
            tags: ["dark", "pastel", "nature"],
            meta: {
                roundingScale: 1.25
            }
        },
        {
            id: "synthwave84",
            name: "Synthwave '84",
            description: "Retro neon aesthetics",
            icon: "music_note",
            colors: synthwave84Colors,
            tags: ["dark", "neon", "retro"],
            meta: {
                roundingScale: 0.2,
                borderWidthScale: 1.5
            }
        },
        {
            id: "nightowl",
            name: "Night Owl",
            description: "For the night owls",
            icon: "nights_stay",
            colors: nightOwlColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 1.0
            }
        },
        {
            id: "cobalt2",
            name: "Cobalt2",
            description: "Blue perfection",
            icon: "water_drop",
            colors: cobalt2Colors,
            tags: ["dark", "vibrant"],
            meta: {
                fontStyle: "mono",
                roundingScale: 1.0
            }
        },
        {
            id: "github-dark",
            name: "GitHub Dark",
            description: "The developer standard",
            icon: "code",
            colors: githubDarkColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.8
            }
        },
        {
            id: "vercel",
            name: "Vercel",
            description: "Minimalist and high contrast",
            icon: "change_history",
            colors: vercelColors,
            tags: ["dark", "minimal"],
            meta: {
                roundingScale: 0.6,
                fontStyle: "sans"
            }
        },
        {
            id: "zenburn",
            name: "Zenburn",
            description: "Low contrast earth tones",
            icon: "contrast",
            colors: zenburnColors,
            tags: ["dark", "nature"]
        },
        {
            id: "mercury",
            name: "Mercury",
            description: "Cold and metallic",
            icon: "science",
            colors: mercuryColors,
            tags: ["dark", "minimal"],
            meta: {
                roundingScale: 0.8,
                borderWidthScale: 1.1
            }
        },
        {
            id: "flexoki",
            name: "Flexoki",
            description: "Inky blacks and warm paper",
            icon: "history_edu",
            colors: flexokiColors,
            tags: ["dark", "nature"],
            meta: {
                roundingScale: 1.1,
                fontStyle: "serif"
            }
        },
        {
            id: "cursor",
            name: "Cursor",
            description: "Modern IDE aesthetic",
            icon: "smart_toy",
            colors: cursorColors,
            tags: ["dark", "minimal"],
            meta: {
                roundingScale: 0.9,
                fontStyle: "sans"
            }
        },
        {
            id: "material-ocean",
            name: "Material Ocean",
            description: "Deep oceanic blue",
            icon: "sailing",
            colors: materialOceanColors,
            tags: ["dark", "vibrant"],
            meta: {
                roundingScale: 1.0
            }
        },
        {
            id: "palenight",
            name: "Palenight",
            description: "Elegant and mild",
            icon: "night_shelter",
            colors: palenightColors,
            tags: ["dark", "pastel"],
            meta: {
                roundingScale: 1.0
            }
        },
        {
            id: "osaka-jade",
            name: "Osaka Jade",
            description: "Fresh jade green",
            icon: "park",
            colors: osakaJadeColors,
            tags: ["dark", "nature"],
            meta: {
                roundingScale: 1.1
            }
        },
        {
            id: "monokai",
            name: "Monokai",
            description: "The classic",
            icon: "cookie",
            colors: monokaiColors,
            tags: ["dark", "vibrant", "retro"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.8
            }
        },
        {
            id: "vesper",
            name: "Vesper",
            description: "Dark and sophisticated",
            icon: "church",
            colors: vesperColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono"
            }
        },
        {
            id: "orng",
            name: "Orng",
            description: "Vibrant orange focus",
            icon: "local_fire_department",
            colors: orngColors,
            tags: ["dark", "vibrant", "neon"],
            meta: {
                roundingScale: 0.8
            }
        },
        {
            id: "lucent-orng",
            name: "Lucent Orng",
            description: "Transparent orange focus",
            icon: "blur_on",
            colors: lucentOrngColors,
            tags: ["dark", "vibrant", "neon"],
            meta: {
                roundingScale: 0.5,
                borderWidthScale: 0.5
            }
        },
        {
            id: "fields-of-the-shire",
            name: "Fields of the Shire",
            description: "Warm earthy tones of the pastoral countryside",
            icon: "grass",
            colors: fieldsOfTheShireDarkColors,
            tags: ["dark", "nature"],
            meta: {
                roundingScale: 1.2,
                fontStyle: "serif"
            }
        },
        {
            id: "fields-of-the-shire-light",
            name: "Fields of the Shire Light",
            description: "Morning sun over parchment meadows",
            icon: "wb_sunny",
            colors: fieldsOfTheShireLightColors,
            tags: ["light", "nature"],
            meta: {
                roundingScale: 1.2,
                fontStyle: "serif"
            }
        },
        {
            id: "vitesse-dark",
            name: "Vitesse Dark",
            description: "Refined and minimal, by Anthony Fu",
            icon: "code",
            colors: vitesseDarkColors,
            tags: ["dark", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.9
            }
        },
        {
            id: "vitesse-light",
            name: "Vitesse Light",
            description: "Clean and warm, by Anthony Fu",
            icon: "code",
            colors: vitesseLightColors,
            tags: ["light", "minimal"],
            meta: {
                fontStyle: "mono",
                roundingScale: 0.9
            }
        }
    ]

    // Angel - Signature theme for iNiR
    // Celestial twilight aesthetic: warm golden halos against deep cosmic void
    // Inspired by the image: amber eyes, ethereal glow, dark silhouette
    readonly property var angelColors: ({
        darkmode: true,
        m3background: "#08070a",
        m3onBackground: "#e6dfd6",
        m3surface: "#08070a",
        m3surfaceDim: "#050406",
        m3surfaceBright: "#16141a",
        m3surfaceContainerLowest: "#050406",
        m3surfaceContainerLow: "#0c0b0f",
        m3surfaceContainer: "#121016",
        m3surfaceContainerHigh: "#1a171f",
        m3surfaceContainerHighest: "#221f28",
        m3onSurface: "#e6dfd6",
        m3surfaceVariant: "#2a2630",
        m3onSurfaceVariant: "#c8c0b4",
        m3inverseSurface: "#e6dfd6",
        m3inverseOnSurface: "#08070a",
        m3outline: "#5c5466",
        m3outlineVariant: "#3a3440",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#e8b882",
        m3primary: "#e8b882",
        m3onPrimary: "#2a1c0e",
        m3primaryContainer: "#3a2816",
        m3onPrimaryContainer: "#f8dcc0",
        m3inversePrimary: "#c49458",
        m3secondary: "#d4c4aa",
        m3onSecondary: "#1e1a14",
        m3secondaryContainer: "#322c22",
        m3onSecondaryContainer: "#ece0cc",
        m3tertiary: "#b8c4d8",
        m3onTertiary: "#141820",
        m3tertiaryContainer: "#262e3a",
        m3onTertiaryContainer: "#d8e4f0",
        m3error: "#f0a090",
        m3onError: "#2a1410",
        m3errorContainer: "#3a1c14",
        m3onErrorContainer: "#fcd0c0",
        m3primaryFixed: "#e8b882",
        m3primaryFixedDim: "#c89860",
        m3onPrimaryFixed: "#2a1c0e",
        m3onPrimaryFixedVariant: "#1a171f",
        m3secondaryFixed: "#d4c4aa",
        m3secondaryFixedDim: "#b4a48a",
        m3onSecondaryFixed: "#1e1a14",
        m3onSecondaryFixedVariant: "#1a171f",
        m3tertiaryFixed: "#b8c4d8",
        m3tertiaryFixedDim: "#98a4b8",
        m3onTertiaryFixed: "#141820",
        m3onTertiaryFixedVariant: "#1a171f",
        m3success: "#98c890",
        m3onSuccess: "#142014",
        m3successContainer: "#1c3018",
        m3onSuccessContainer: "#c0e8b8"
    })

    // Angel Light - Ethereal dawn variant
    readonly property var angelLightColors: ({
        darkmode: false,
        m3background: "#fdfaf6",
        m3onBackground: "#1c1a18",
        m3surface: "#fdfaf6",
        m3surfaceDim: "#f0ebe4",
        m3surfaceBright: "#ffffff",
        m3surfaceContainerLowest: "#ffffff",
        m3surfaceContainerLow: "#f8f4ee",
        m3surfaceContainer: "#f0ebe4",
        m3surfaceContainerHigh: "#e8e2da",
        m3surfaceContainerHighest: "#e0d8ce",
        m3onSurface: "#1c1a18",
        m3surfaceVariant: "#e0d8ce",
        m3onSurfaceVariant: "#4a4640",
        m3inverseSurface: "#1c1a18",
        m3inverseOnSurface: "#fdfaf6",
        m3outline: "#8a8078",
        m3outlineVariant: "#c8c0b4",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#9a6830",
        m3primary: "#9a6830",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#f8dcc0",
        m3onPrimaryContainer: "#5a3c18",
        m3inversePrimary: "#e8b882",
        m3secondary: "#7a6a50",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#ece0cc",
        m3onSecondaryContainer: "#4a3c28",
        m3tertiary: "#506478",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#d8e4f0",
        m3onTertiaryContainer: "#2a3a4a",
        m3error: "#b04030",
        m3onError: "#ffffff",
        m3errorContainer: "#fcd0c0",
        m3onErrorContainer: "#5a1c10",
        m3primaryFixed: "#9a6830",
        m3primaryFixedDim: "#7a5020",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#f0ebe4",
        m3secondaryFixed: "#7a6a50",
        m3secondaryFixedDim: "#5a4a30",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#f0ebe4",
        m3tertiaryFixed: "#506478",
        m3tertiaryFixedDim: "#3a4a5a",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#f0ebe4",
        m3success: "#3a7a38",
        m3onSuccess: "#ffffff",
        m3successContainer: "#c0e8b8",
        m3onSuccessContainer: "#1a3a18"
    })

    readonly property var catppuccinMochaColors: ({
        darkmode: true,
        m3background: "#1e1e2e",
        m3onBackground: "#cdd6f4",
        m3surface: "#1e1e2e",
        m3surfaceDim: "#11111b",
        m3surfaceBright: "#313244",
        m3surfaceContainerLowest: "#11111b",
        m3surfaceContainerLow: "#181825",
        m3surfaceContainer: "#1e1e2e",
        m3surfaceContainerHigh: "#313244",
        m3surfaceContainerHighest: "#45475a",
        m3onSurface: "#cdd6f4",
        m3surfaceVariant: "#45475a",
        m3onSurfaceVariant: "#bac2de",
        m3inverseSurface: "#cdd6f4",
        m3inverseOnSurface: "#1e1e2e",
        m3outline: "#6c7086",
        m3outlineVariant: "#45475a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#cba6f7",
        m3primary: "#cba6f7",
        m3onPrimary: "#1e1e2e",
        m3primaryContainer: "#45475a",
        m3onPrimaryContainer: "#f5c2e7",
        m3inversePrimary: "#8839ef",
        m3secondary: "#f5c2e7",
        m3onSecondary: "#1e1e2e",
        m3secondaryContainer: "#45475a",
        m3onSecondaryContainer: "#f5c2e7",
        m3tertiary: "#94e2d5",
        m3onTertiary: "#1e1e2e",
        m3tertiaryContainer: "#45475a",
        m3onTertiaryContainer: "#94e2d5",
        m3error: "#f38ba8",
        m3onError: "#1e1e2e",
        m3errorContainer: "#45475a",
        m3onErrorContainer: "#f38ba8",
        m3primaryFixed: "#cba6f7",
        m3primaryFixedDim: "#b4befe",
        m3onPrimaryFixed: "#1e1e2e",
        m3onPrimaryFixedVariant: "#313244",
        m3secondaryFixed: "#f5c2e7",
        m3secondaryFixedDim: "#f2cdcd",
        m3onSecondaryFixed: "#1e1e2e",
        m3onSecondaryFixedVariant: "#313244",
        m3tertiaryFixed: "#94e2d5",
        m3tertiaryFixedDim: "#89dceb",
        m3onTertiaryFixed: "#1e1e2e",
        m3onTertiaryFixedVariant: "#313244",
        m3success: "#a6e3a1",
        m3onSuccess: "#1e1e2e",
        m3successContainer: "#45475a",
        m3onSuccessContainer: "#a6e3a1"
    })

    readonly property var catppuccinLatteColors: ({
        darkmode: false,
        m3background: "#eff1f5",
        m3onBackground: "#4c4f69",
        m3surface: "#eff1f5",
        m3surfaceDim: "#e6e9ef",
        m3surfaceBright: "#ffffff",
        m3surfaceContainerLowest: "#ffffff",
        m3surfaceContainerLow: "#f2f4f8",
        m3surfaceContainer: "#e6e9ef",
        m3surfaceContainerHigh: "#dce0e8",
        m3surfaceContainerHighest: "#ccd0da",
        m3onSurface: "#4c4f69",
        m3surfaceVariant: "#ccd0da",
        m3onSurfaceVariant: "#5c5f77",
        m3inverseSurface: "#4c4f69",
        m3inverseOnSurface: "#eff1f5",
        m3outline: "#8c8fa1",
        m3outlineVariant: "#bcc0cc",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8839ef",
        m3primary: "#8839ef",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#dce0e8",
        m3onPrimaryContainer: "#7287fd",
        m3inversePrimary: "#cba6f7",
        m3secondary: "#ea76cb",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#dce0e8",
        m3onSecondaryContainer: "#ea76cb",
        m3tertiary: "#179299",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#dce0e8",
        m3onTertiaryContainer: "#179299",
        m3error: "#d20f39",
        m3onError: "#ffffff",
        m3errorContainer: "#dce0e8",
        m3onErrorContainer: "#d20f39",
        m3primaryFixed: "#8839ef",
        m3primaryFixedDim: "#7287fd",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#e6e9ef",
        m3secondaryFixed: "#ea76cb",
        m3secondaryFixedDim: "#dd7878",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#e6e9ef",
        m3tertiaryFixed: "#179299",
        m3tertiaryFixedDim: "#04a5e5",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#e6e9ef",
        m3success: "#40a02b",
        m3onSuccess: "#ffffff",
        m3successContainer: "#dce0e8",
        m3onSuccessContainer: "#40a02b"
    })

    readonly property var materialBlackColors: ({
        darkmode: true,
        m3background: "#000000",
        m3onBackground: "#e0e0e0",
        m3surface: "#000000",
        m3surfaceDim: "#000000",
        m3surfaceBright: "#1a1a1a",
        m3surfaceContainerLowest: "#000000",
        m3surfaceContainerLow: "#0d0d0d",
        m3surfaceContainer: "#141414",
        m3surfaceContainerHigh: "#1a1a1a",
        m3surfaceContainerHighest: "#242424",
        m3onSurface: "#e0e0e0",
        m3surfaceVariant: "#2a2a2a",
        m3onSurfaceVariant: "#b0b0b0",
        m3inverseSurface: "#e0e0e0",
        m3inverseOnSurface: "#000000",
        m3outline: "#5a5a5a",
        m3outlineVariant: "#3a3a3a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#a0a0a0",
        m3primary: "#a0a0a0",
        m3onPrimary: "#000000",
        m3primaryContainer: "#2a2a2a",
        m3onPrimaryContainer: "#d0d0d0",
        m3inversePrimary: "#707070",
        m3secondary: "#8a8a8a",
        m3onSecondary: "#000000",
        m3secondaryContainer: "#252525",
        m3onSecondaryContainer: "#c0c0c0",
        m3tertiary: "#909090",
        m3onTertiary: "#000000",
        m3tertiaryContainer: "#282828",
        m3onTertiaryContainer: "#c8c8c8",
        m3error: "#cf6679",
        m3onError: "#000000",
        m3errorContainer: "#3d1a1e",
        m3onErrorContainer: "#f2b8c0",
        m3primaryFixed: "#b0b0b0",
        m3primaryFixedDim: "#909090",
        m3onPrimaryFixed: "#000000",
        m3onPrimaryFixedVariant: "#1a1a1a",
        m3secondaryFixed: "#9a9a9a",
        m3secondaryFixedDim: "#7a7a7a",
        m3onSecondaryFixed: "#000000",
        m3onSecondaryFixedVariant: "#1a1a1a",
        m3tertiaryFixed: "#a0a0a0",
        m3tertiaryFixedDim: "#808080",
        m3onTertiaryFixed: "#000000",
        m3onTertiaryFixedVariant: "#1a1a1a",
        m3success: "#6b9b6b",
        m3onSuccess: "#000000",
        m3successContainer: "#1e2e1e",
        m3onSuccessContainer: "#a8c8a8"
    })

    readonly property var gruvboxMaterialColors: ({
        darkmode: true,
        m3background: "#1d2021",
        m3onBackground: "#d4be98",
        m3surface: "#1d2021",
        m3surfaceDim: "#141617",
        m3surfaceBright: "#32302f",
        m3surfaceContainerLowest: "#141617",
        m3surfaceContainerLow: "#1d2021",
        m3surfaceContainer: "#282828",
        m3surfaceContainerHigh: "#32302f",
        m3surfaceContainerHighest: "#3c3836",
        m3onSurface: "#d4be98",
        m3surfaceVariant: "#3c3836",
        m3onSurfaceVariant: "#bdae93",
        m3inverseSurface: "#d4be98",
        m3inverseOnSurface: "#1d2021",
        m3outline: "#7c6f64",
        m3outlineVariant: "#504945",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#e78a4e",
        m3primary: "#e78a4e",
        m3onPrimary: "#1d2021",
        m3primaryContainer: "#5a3d2b",
        m3onPrimaryContainer: "#e9b99a",
        m3inversePrimary: "#c57339",
        m3secondary: "#a9b665",
        m3onSecondary: "#1d2021",
        m3secondaryContainer: "#4a5332",
        m3onSecondaryContainer: "#c9d6a5",
        m3tertiary: "#7daea3",
        m3onTertiary: "#1d2021",
        m3tertiaryContainer: "#3a5550",
        m3onTertiaryContainer: "#a9cec5",
        m3error: "#ea6962",
        m3onError: "#1d2021",
        m3errorContainer: "#5c2d2d",
        m3onErrorContainer: "#f2a9a5",
        m3primaryFixed: "#e78a4e",
        m3primaryFixedDim: "#d47d44",
        m3onPrimaryFixed: "#1d2021",
        m3onPrimaryFixedVariant: "#32302f",
        m3secondaryFixed: "#a9b665",
        m3secondaryFixedDim: "#8fa352",
        m3onSecondaryFixed: "#1d2021",
        m3onSecondaryFixedVariant: "#32302f",
        m3tertiaryFixed: "#7daea3",
        m3tertiaryFixedDim: "#6a9a90",
        m3onTertiaryFixed: "#1d2021",
        m3onTertiaryFixedVariant: "#32302f",
        m3success: "#a9b665",
        m3onSuccess: "#1d2021",
        m3successContainer: "#4a5332",
        m3onSuccessContainer: "#c9d6a5"
    })

    readonly property var nordColors: ({
        darkmode: true,
        m3background: "#2e3440",
        m3onBackground: "#eceff4",
        m3surface: "#2e3440",
        m3surfaceDim: "#242933",
        m3surfaceBright: "#3b4252",
        m3surfaceContainerLowest: "#242933",
        m3surfaceContainerLow: "#2e3440",
        m3surfaceContainer: "#3b4252",
        m3surfaceContainerHigh: "#434c5e",
        m3surfaceContainerHighest: "#4c566a",
        m3onSurface: "#eceff4",
        m3surfaceVariant: "#4c566a",
        m3onSurfaceVariant: "#d8dee9",
        m3inverseSurface: "#eceff4",
        m3inverseOnSurface: "#2e3440",
        m3outline: "#7b88a1",
        m3outlineVariant: "#4c566a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#88c0d0",
        m3primary: "#88c0d0",
        m3onPrimary: "#2e3440",
        m3primaryContainer: "#5e81ac",
        m3onPrimaryContainer: "#e5e9f0",
        m3inversePrimary: "#5e81ac",
        m3secondary: "#81a1c1",
        m3onSecondary: "#2e3440",
        m3secondaryContainer: "#5e81ac",
        m3onSecondaryContainer: "#e5e9f0",
        m3tertiary: "#b48ead",
        m3onTertiary: "#2e3440",
        m3tertiaryContainer: "#5e81ac",
        m3onTertiaryContainer: "#e5e9f0",
        m3error: "#bf616a",
        m3onError: "#2e3440",
        m3errorContainer: "#a3545c",
        m3onErrorContainer: "#eceff4",
        m3primaryFixed: "#8fbcbb",
        m3primaryFixedDim: "#88c0d0",
        m3onPrimaryFixed: "#2e3440",
        m3onPrimaryFixedVariant: "#3b4252",
        m3secondaryFixed: "#81a1c1",
        m3secondaryFixedDim: "#5e81ac",
        m3onSecondaryFixed: "#2e3440",
        m3onSecondaryFixedVariant: "#3b4252",
        m3tertiaryFixed: "#b48ead",
        m3tertiaryFixedDim: "#a3be8c",
        m3onTertiaryFixed: "#2e3440",
        m3onTertiaryFixedVariant: "#3b4252",
        m3success: "#a3be8c",
        m3onSuccess: "#2e3440",
        m3successContainer: "#8aa87a",
        m3onSuccessContainer: "#eceff4"
    })



    // Kanagawa - Inspired by The Great Wave off Kanagawa
    readonly property var kanagawaColors: ({
        darkmode: true,
        m3background: "#1f1f28",
        m3onBackground: "#dcd7ba",
        m3surface: "#1f1f28",
        m3surfaceDim: "#16161d",
        m3surfaceBright: "#2a2a37",
        m3surfaceContainerLowest: "#16161d",
        m3surfaceContainerLow: "#1f1f28",
        m3surfaceContainer: "#2a2a37",
        m3surfaceContainerHigh: "#363646",
        m3surfaceContainerHighest: "#54546d",
        m3onSurface: "#dcd7ba",
        m3surfaceVariant: "#54546d",
        m3onSurfaceVariant: "#c8c093",
        m3inverseSurface: "#dcd7ba",
        m3inverseOnSurface: "#1f1f28",
        m3outline: "#727169",
        m3outlineVariant: "#54546d",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#7e9cd8",
        m3primary: "#7e9cd8",
        m3onPrimary: "#1f1f28",
        m3primaryContainer: "#223249",
        m3onPrimaryContainer: "#a3d4d5",
        m3inversePrimary: "#658594",
        m3secondary: "#7fb4ca",
        m3onSecondary: "#1f1f28",
        m3secondaryContainer: "#2d4f67",
        m3onSecondaryContainer: "#a3d4d5",
        m3tertiary: "#957fb8",
        m3onTertiary: "#1f1f28",
        m3tertiaryContainer: "#3d3d5c",
        m3onTertiaryContainer: "#d3b8e0",
        m3error: "#e82424",
        m3onError: "#1f1f28",
        m3errorContainer: "#43242b",
        m3onErrorContainer: "#ff5d62",
        m3primaryFixed: "#7e9cd8",
        m3primaryFixedDim: "#658594",
        m3onPrimaryFixed: "#1f1f28",
        m3onPrimaryFixedVariant: "#2a2a37",
        m3secondaryFixed: "#7fb4ca",
        m3secondaryFixedDim: "#6a9589",
        m3onSecondaryFixed: "#1f1f28",
        m3onSecondaryFixedVariant: "#2a2a37",
        m3tertiaryFixed: "#957fb8",
        m3tertiaryFixedDim: "#7e6a9f",
        m3onTertiaryFixed: "#1f1f28",
        m3onTertiaryFixedVariant: "#2a2a37",
        m3success: "#98bb6c",
        m3onSuccess: "#1f1f28",
        m3successContainer: "#2e4a3a",
        m3onSuccessContainer: "#c4d99e"
    })

    // Kanagawa Dragon - Darker variant
    readonly property var kanagawaDragonColors: ({
        darkmode: true,
        m3background: "#181616",
        m3onBackground: "#c5c9c5",
        m3surface: "#181616",
        m3surfaceDim: "#0d0c0c",
        m3surfaceBright: "#282727",
        m3surfaceContainerLowest: "#0d0c0c",
        m3surfaceContainerLow: "#181616",
        m3surfaceContainer: "#282727",
        m3surfaceContainerHigh: "#393836",
        m3surfaceContainerHighest: "#625e5a",
        m3onSurface: "#c5c9c5",
        m3surfaceVariant: "#625e5a",
        m3onSurfaceVariant: "#a6a69c",
        m3inverseSurface: "#c5c9c5",
        m3inverseOnSurface: "#181616",
        m3outline: "#737c73",
        m3outlineVariant: "#625e5a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8ba4b0",
        m3primary: "#8ba4b0",
        m3onPrimary: "#181616",
        m3primaryContainer: "#2d4f67",
        m3onPrimaryContainer: "#b6d7e3",
        m3inversePrimary: "#658594",
        m3secondary: "#8ea4a2",
        m3onSecondary: "#181616",
        m3secondaryContainer: "#3a5550",
        m3onSecondaryContainer: "#b8d4d0",
        m3tertiary: "#a292a3",
        m3onTertiary: "#181616",
        m3tertiaryContainer: "#4a3d4a",
        m3onTertiaryContainer: "#d0c4d1",
        m3error: "#c4746e",
        m3onError: "#181616",
        m3errorContainer: "#43242b",
        m3onErrorContainer: "#e6a0a0",
        m3primaryFixed: "#8ba4b0",
        m3primaryFixedDim: "#6d8a94",
        m3onPrimaryFixed: "#181616",
        m3onPrimaryFixedVariant: "#282727",
        m3secondaryFixed: "#8ea4a2",
        m3secondaryFixedDim: "#6a8785",
        m3onSecondaryFixed: "#181616",
        m3onSecondaryFixedVariant: "#282727",
        m3tertiaryFixed: "#a292a3",
        m3tertiaryFixedDim: "#857585",
        m3onTertiaryFixed: "#181616",
        m3onTertiaryFixedVariant: "#282727",
        m3success: "#87a987",
        m3onSuccess: "#181616",
        m3successContainer: "#2e4a3a",
        m3onSuccessContainer: "#b5d5b5"
    })

    // Samurai - Deep crimson and steel
    readonly property var samuraiColors: ({
        darkmode: true,
        m3background: "#0f0f0f",
        m3onBackground: "#e8e4e0",
        m3surface: "#0f0f0f",
        m3surfaceDim: "#080808",
        m3surfaceBright: "#1a1a1a",
        m3surfaceContainerLowest: "#080808",
        m3surfaceContainerLow: "#0f0f0f",
        m3surfaceContainer: "#1a1a1a",
        m3surfaceContainerHigh: "#252525",
        m3surfaceContainerHighest: "#333333",
        m3onSurface: "#e8e4e0",
        m3surfaceVariant: "#333333",
        m3onSurfaceVariant: "#c0b8b0",
        m3inverseSurface: "#e8e4e0",
        m3inverseOnSurface: "#0f0f0f",
        m3outline: "#6b6560",
        m3outlineVariant: "#4a4540",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#c41e3a",
        m3primary: "#c41e3a",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#4a0d18",
        m3onPrimaryContainer: "#ffb3be",
        m3inversePrimary: "#ff6b7a",
        m3secondary: "#8b8589",
        m3onSecondary: "#0f0f0f",
        m3secondaryContainer: "#3a3538",
        m3onSecondaryContainer: "#c8c0c4",
        m3tertiary: "#d4af37",
        m3onTertiary: "#0f0f0f",
        m3tertiaryContainer: "#4a3d15",
        m3onTertiaryContainer: "#f0d890",
        m3error: "#ff4444",
        m3onError: "#0f0f0f",
        m3errorContainer: "#4a1515",
        m3onErrorContainer: "#ffaaaa",
        m3primaryFixed: "#c41e3a",
        m3primaryFixedDim: "#a01830",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#1a1a1a",
        m3secondaryFixed: "#8b8589",
        m3secondaryFixedDim: "#6b6569",
        m3onSecondaryFixed: "#0f0f0f",
        m3onSecondaryFixedVariant: "#1a1a1a",
        m3tertiaryFixed: "#d4af37",
        m3tertiaryFixedDim: "#b8962e",
        m3onTertiaryFixed: "#0f0f0f",
        m3onTertiaryFixedVariant: "#1a1a1a",
        m3success: "#4a7c4a",
        m3onSuccess: "#ffffff",
        m3successContainer: "#1e3a1e",
        m3onSuccessContainer: "#a8d4a8"
    })

    // Tokyo Night - Neon city aesthetic
    readonly property var tokyoNightColors: ({
        darkmode: true,
        m3background: "#1a1b26",
        m3onBackground: "#c0caf5",
        m3surface: "#1a1b26",
        m3surfaceDim: "#13141c",
        m3surfaceBright: "#24283b",
        m3surfaceContainerLowest: "#13141c",
        m3surfaceContainerLow: "#1a1b26",
        m3surfaceContainer: "#24283b",
        m3surfaceContainerHigh: "#2f3549",
        m3surfaceContainerHighest: "#414868",
        m3onSurface: "#c0caf5",
        m3surfaceVariant: "#414868",
        m3onSurfaceVariant: "#a9b1d6",
        m3inverseSurface: "#c0caf5",
        m3inverseOnSurface: "#1a1b26",
        m3outline: "#565f89",
        m3outlineVariant: "#414868",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#7aa2f7",
        m3primary: "#7aa2f7",
        m3onPrimary: "#1a1b26",
        m3primaryContainer: "#3d59a1",
        m3onPrimaryContainer: "#c0caf5",
        m3inversePrimary: "#5a7ecc",
        m3secondary: "#bb9af7",
        m3onSecondary: "#1a1b26",
        m3secondaryContainer: "#5a4a78",
        m3onSecondaryContainer: "#dcc8ff",
        m3tertiary: "#7dcfff",
        m3onTertiary: "#1a1b26",
        m3tertiaryContainer: "#3a6a8a",
        m3onTertiaryContainer: "#b4e8ff",
        m3error: "#f7768e",
        m3onError: "#1a1b26",
        m3errorContainer: "#5a2a35",
        m3onErrorContainer: "#ffb4c4",
        m3primaryFixed: "#7aa2f7",
        m3primaryFixedDim: "#5a7ecc",
        m3onPrimaryFixed: "#1a1b26",
        m3onPrimaryFixedVariant: "#24283b",
        m3secondaryFixed: "#bb9af7",
        m3secondaryFixedDim: "#9a7acc",
        m3onSecondaryFixed: "#1a1b26",
        m3onSecondaryFixedVariant: "#24283b",
        m3tertiaryFixed: "#7dcfff",
        m3tertiaryFixedDim: "#5aaccc",
        m3onTertiaryFixed: "#1a1b26",
        m3onTertiaryFixedVariant: "#24283b",
        m3success: "#9ece6a",
        m3onSuccess: "#1a1b26",
        m3successContainer: "#4a6a35",
        m3onSuccessContainer: "#c8f0a0"
    })

    // Sakura - Cherry blossom theme (light)
    readonly property var sakuraColors: ({
        darkmode: false,
        m3background: "#fef9f3",
        m3onBackground: "#4a3f3f",
        m3surface: "#fef9f3",
        m3surfaceDim: "#f5ede5",
        m3surfaceBright: "#ffffff",
        m3surfaceContainerLowest: "#ffffff",
        m3surfaceContainerLow: "#faf5ef",
        m3surfaceContainer: "#f5ede5",
        m3surfaceContainerHigh: "#efe5db",
        m3surfaceContainerHighest: "#e8dcd0",
        m3onSurface: "#4a3f3f",
        m3surfaceVariant: "#e8dcd0",
        m3onSurfaceVariant: "#5c5050",
        m3inverseSurface: "#4a3f3f",
        m3inverseOnSurface: "#fef9f3",
        m3outline: "#9a8a8a",
        m3outlineVariant: "#d0c0b8",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#d4869c",
        m3primary: "#d4869c",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#ffd9e3",
        m3onPrimaryContainer: "#8a4a5a",
        m3inversePrimary: "#ffb4c8",
        m3secondary: "#c9a0a0",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#f5dada",
        m3onSecondaryContainer: "#6a5050",
        m3tertiary: "#8faa8f",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#d5ecd5",
        m3onTertiaryContainer: "#4a5a4a",
        m3error: "#c44040",
        m3onError: "#ffffff",
        m3errorContainer: "#ffd5d5",
        m3onErrorContainer: "#6a2020",
        m3primaryFixed: "#d4869c",
        m3primaryFixedDim: "#b86a80",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#f5ede5",
        m3secondaryFixed: "#c9a0a0",
        m3secondaryFixedDim: "#a88080",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#f5ede5",
        m3tertiaryFixed: "#8faa8f",
        m3tertiaryFixedDim: "#708a70",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#f5ede5",
        m3success: "#6a9a6a",
        m3onSuccess: "#ffffff",
        m3successContainer: "#d5f0d5",
        m3onSuccessContainer: "#3a5a3a"
    })

    // Zen Garden - Tranquil moss and stone
    readonly property var zenGardenColors: ({
        darkmode: true,
        m3background: "#1a1e1a",
        m3onBackground: "#d5dcd5",
        m3surface: "#1a1e1a",
        m3surfaceDim: "#121512",
        m3surfaceBright: "#252a25",
        m3surfaceContainerLowest: "#121512",
        m3surfaceContainerLow: "#1a1e1a",
        m3surfaceContainer: "#252a25",
        m3surfaceContainerHigh: "#303530",
        m3surfaceContainerHighest: "#404540",
        m3onSurface: "#d5dcd5",
        m3surfaceVariant: "#404540",
        m3onSurfaceVariant: "#b0b8b0",
        m3inverseSurface: "#d5dcd5",
        m3inverseOnSurface: "#1a1e1a",
        m3outline: "#6a756a",
        m3outlineVariant: "#4a524a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#7a9a7a",
        m3primary: "#7a9a7a",
        m3onPrimary: "#1a1e1a",
        m3primaryContainer: "#2a3a2a",
        m3onPrimaryContainer: "#a8c8a8",
        m3inversePrimary: "#5a7a5a",
        m3secondary: "#9a9080",
        m3onSecondary: "#1a1e1a",
        m3secondaryContainer: "#3a3530",
        m3onSecondaryContainer: "#c8c0b0",
        m3tertiary: "#8a9aa0",
        m3onTertiary: "#1a1e1a",
        m3tertiaryContainer: "#303a40",
        m3onTertiaryContainer: "#b8c8d0",
        m3error: "#c07070",
        m3onError: "#1a1e1a",
        m3errorContainer: "#402828",
        m3onErrorContainer: "#e0a8a8",
        m3primaryFixed: "#7a9a7a",
        m3primaryFixedDim: "#5a7a5a",
        m3onPrimaryFixed: "#1a1e1a",
        m3onPrimaryFixedVariant: "#252a25",
        m3secondaryFixed: "#9a9080",
        m3secondaryFixedDim: "#7a7060",
        m3onSecondaryFixed: "#1a1e1a",
        m3onSecondaryFixedVariant: "#252a25",
        m3tertiaryFixed: "#8a9aa0",
        m3tertiaryFixedDim: "#6a7a80",
        m3onTertiaryFixed: "#1a1e1a",
        m3onTertiaryFixedVariant: "#252a25",
        m3success: "#6a9a6a",
        m3onSuccess: "#1a1e1a",
        m3successContainer: "#2a4a2a",
        m3onSuccessContainer: "#a8d8a8"
    })

    // Everforest - Natural, warm, and organic
    readonly property var everforestColors: ({
        darkmode: true,
        m3background: "#2d353b",
        m3onBackground: "#d3c6aa",
        m3surface: "#2d353b",
        m3surfaceDim: "#232a2e",
        m3surfaceBright: "#343f44",
        m3surfaceContainerLowest: "#232a2e",
        m3surfaceContainerLow: "#2d353b",
        m3surfaceContainer: "#343f44",
        m3surfaceContainerHigh: "#3d484d",
        m3surfaceContainerHighest: "#475258",
        m3onSurface: "#d3c6aa",
        m3surfaceVariant: "#475258",
        m3onSurfaceVariant: "#9da9a0",
        m3inverseSurface: "#d3c6aa",
        m3inverseOnSurface: "#2d353b",
        m3outline: "#859289",
        m3outlineVariant: "#475258",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#a7c080",
        m3primary: "#a7c080",
        m3onPrimary: "#2d353b",
        m3primaryContainer: "#4a553b",
        m3onPrimaryContainer: "#d3e8b0",
        m3inversePrimary: "#7fbbb3",
        m3secondary: "#dbbc7f",
        m3onSecondary: "#2d353b",
        m3secondaryContainer: "#5e523e",
        m3onSecondaryContainer: "#f0dfb8",
        m3tertiary: "#d699b6",
        m3onTertiary: "#2d353b",
        m3tertiaryContainer: "#5c424f",
        m3onTertiaryContainer: "#e8c2d6",
        m3error: "#e67e80",
        m3onError: "#2d353b",
        m3errorContainer: "#5c3234",
        m3onErrorContainer: "#f2b3b4",
        m3primaryFixed: "#a7c080",
        m3primaryFixedDim: "#8ba36a",
        m3onPrimaryFixed: "#2d353b",
        m3onPrimaryFixedVariant: "#343f44",
        m3secondaryFixed: "#dbbc7f",
        m3secondaryFixedDim: "#b89e6b",
        m3onSecondaryFixed: "#2d353b",
        m3onSecondaryFixedVariant: "#343f44",
        m3tertiaryFixed: "#d699b6",
        m3tertiaryFixedDim: "#b38098",
        m3onTertiaryFixed: "#2d353b",
        m3onTertiaryFixedVariant: "#343f44",
        m3success: "#a7c080",
        m3onSuccess: "#2d353b",
        m3successContainer: "#4a553b",
        m3onSuccessContainer: "#d3e8b0"
    })

    // Ayu - Bright and elegant
    readonly property var ayuColors: ({
        darkmode: true,
        m3background: "#0f1419",
        m3onBackground: "#e6e1cf",
        m3surface: "#0f1419",
        m3surfaceDim: "#0a0e12",
        m3surfaceBright: "#192027",
        m3surfaceContainerLowest: "#0a0e12",
        m3surfaceContainerLow: "#0f1419",
        m3surfaceContainer: "#192027",
        m3surfaceContainerHigh: "#242d36",
        m3surfaceContainerHighest: "#303a45",
        m3onSurface: "#e6e1cf",
        m3surfaceVariant: "#303a45",
        m3onSurfaceVariant: "#b3b1ad",
        m3inverseSurface: "#e6e1cf",
        m3inverseOnSurface: "#0f1419",
        m3outline: "#5c6773",
        m3outlineVariant: "#303a45",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#ffb454",
        m3primary: "#ffb454",
        m3onPrimary: "#0f1419",
        m3primaryContainer: "#5c411e",
        m3onPrimaryContainer: "#ffdba1",
        m3inversePrimary: "#ff8f40",
        m3secondary: "#39bae6",
        m3onSecondary: "#0f1419",
        m3secondaryContainer: "#144252",
        m3onSecondaryContainer: "#99e3fc",
        m3tertiary: "#f07178",
        m3onTertiary: "#0f1419",
        m3tertiaryContainer: "#57292c",
        m3onTertiaryContainer: "#ffc2c5",
        m3error: "#ff3333",
        m3onError: "#0f1419",
        m3errorContainer: "#5c1212",
        m3onErrorContainer: "#ff9999",
        m3primaryFixed: "#ffb454",
        m3primaryFixedDim: "#d99947",
        m3onPrimaryFixed: "#0f1419",
        m3onPrimaryFixedVariant: "#192027",
        m3secondaryFixed: "#39bae6",
        m3secondaryFixedDim: "#319dc2",
        m3onSecondaryFixed: "#0f1419",
        m3onSecondaryFixedVariant: "#192027",
        m3tertiaryFixed: "#f07178",
        m3tertiaryFixedDim: "#cc6066",
        m3onTertiaryFixed: "#0f1419",
        m3onTertiaryFixedVariant: "#192027",
        m3success: "#aad94c",
        m3onSuccess: "#0f1419",
        m3successContainer: "#3d4d1b",
        m3onSuccessContainer: "#d4edb4"
    })

    // Catppuccin Macchiato - Soft, warm high-contrast dark
    readonly property var catppuccinMacchiatoColors: ({
        darkmode: true,
        m3background: "#24273a",
        m3onBackground: "#cad3f5",
        m3surface: "#24273a",
        m3surfaceDim: "#1e2030",
        m3surfaceBright: "#363a4f",
        m3surfaceContainerLowest: "#1e2030",
        m3surfaceContainerLow: "#24273a",
        m3surfaceContainer: "#363a4f",
        m3surfaceContainerHigh: "#494d64",
        m3surfaceContainerHighest: "#5b6078",
        m3onSurface: "#cad3f5",
        m3surfaceVariant: "#5b6078",
        m3onSurfaceVariant: "#939ab7",
        m3inverseSurface: "#cad3f5",
        m3inverseOnSurface: "#24273a",
        m3outline: "#6e738d",
        m3outlineVariant: "#494d64",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8aadf4",
        m3primary: "#8aadf4",
        m3onPrimary: "#24273a",
        m3primaryContainer: "#363a4f",
        m3onPrimaryContainer: "#bad1f7",
        m3inversePrimary: "#b7bdf8",
        m3secondary: "#f5bde6",
        m3onSecondary: "#24273a",
        m3secondaryContainer: "#363a4f",
        m3onSecondaryContainer: "#fcdcf5",
        m3tertiary: "#8bd5ca",
        m3onTertiary: "#24273a",
        m3tertiaryContainer: "#363a4f",
        m3onTertiaryContainer: "#c2ede8",
        m3error: "#ed8796",
        m3onError: "#24273a",
        m3errorContainer: "#363a4f",
        m3onErrorContainer: "#f6c3ca",
        m3primaryFixed: "#8aadf4",
        m3primaryFixedDim: "#7593d1",
        m3onPrimaryFixed: "#24273a",
        m3onPrimaryFixedVariant: "#363a4f",
        m3secondaryFixed: "#f5bde6",
        m3secondaryFixedDim: "#d1a1c4",
        m3onSecondaryFixed: "#24273a",
        m3onSecondaryFixedVariant: "#363a4f",
        m3tertiaryFixed: "#8bd5ca",
        m3tertiaryFixedDim: "#76b5ac",
        m3onTertiaryFixed: "#24273a",
        m3onTertiaryFixedVariant: "#363a4f",
        m3success: "#a6da95",
        m3onSuccess: "#24273a",
        m3successContainer: "#363a4f",
        m3onSuccessContainer: "#d2ecd0"
    })

    // Matrix - Follow the white rabbit
    readonly property var matrixColors: ({
        darkmode: true,
        m3background: "#000000",
        m3onBackground: "#00ff41",
        m3surface: "#000000",
        m3surfaceDim: "#000000",
        m3surfaceBright: "#0d0d0d",
        m3surfaceContainerLowest: "#000000",
        m3surfaceContainerLow: "#050505",
        m3surfaceContainer: "#0a0a0a",
        m3surfaceContainerHigh: "#141414",
        m3surfaceContainerHighest: "#1f1f1f",
        m3onSurface: "#00ff41",
        m3surfaceVariant: "#1f1f1f",
        m3onSurfaceVariant: "#008f11",
        m3inverseSurface: "#00ff41",
        m3inverseOnSurface: "#000000",
        m3outline: "#003b00",
        m3outlineVariant: "#002200",
        m3shadow: "#00ff41",
        m3scrim: "#000000",
        m3surfaceTint: "#00ff41",
        m3primary: "#00ff41",
        m3onPrimary: "#000000",
        m3primaryContainer: "#003b00",
        m3onPrimaryContainer: "#ccffcc",
        m3inversePrimary: "#008f11",
        m3secondary: "#008f11",
        m3onSecondary: "#000000",
        m3secondaryContainer: "#002200",
        m3onSecondaryContainer: "#8fcc8f",
        m3tertiary: "#ffffff",
        m3onTertiary: "#000000",
        m3tertiaryContainer: "#333333",
        m3onTertiaryContainer: "#ffffff",
        m3error: "#ff0000",
        m3onError: "#000000",
        m3errorContainer: "#330000",
        m3onErrorContainer: "#ffcccc",
        m3primaryFixed: "#00ff41",
        m3primaryFixedDim: "#00cc33",
        m3onPrimaryFixed: "#000000",
        m3onPrimaryFixedVariant: "#003300",
        m3secondaryFixed: "#008f11",
        m3secondaryFixedDim: "#00700d",
        m3onSecondaryFixed: "#000000",
        m3onSecondaryFixedVariant: "#002200",
        m3tertiaryFixed: "#ffffff",
        m3tertiaryFixedDim: "#cccccc",
        m3onTertiaryFixed: "#000000",
        m3onTertiaryFixedVariant: "#333333",
        m3success: "#00ff41",
        m3onSuccess: "#000000",
        m3successContainer: "#003b00",
        m3onSuccessContainer: "#ccffcc"
    })

    // One Dark - Atom-inspired dark theme
    readonly property var oneDarkColors: ({
        darkmode: true,
        m3background: "#282c34",
        m3onBackground: "#abb2bf",
        m3surface: "#282c34",
        m3surfaceDim: "#21252b",
        m3surfaceBright: "#32363e",
        m3surfaceContainerLowest: "#21252b",
        m3surfaceContainerLow: "#282c34",
        m3surfaceContainer: "#32363e",
        m3surfaceContainerHigh: "#3d414a",
        m3surfaceContainerHighest: "#4b5059",
        m3onSurface: "#abb2bf",
        m3surfaceVariant: "#4b5059",
        m3onSurfaceVariant: "#818691",
        m3inverseSurface: "#abb2bf",
        m3inverseOnSurface: "#282c34",
        m3outline: "#5c6370",
        m3outlineVariant: "#4b5059",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#61afef",
        m3primary: "#61afef",
        m3onPrimary: "#282c34",
        m3primaryContainer: "#253a52",
        m3onPrimaryContainer: "#bad5f5",
        m3inversePrimary: "#56b6c2",
        m3secondary: "#c678dd",
        m3onSecondary: "#282c34",
        m3secondaryContainer: "#472c52",
        m3onSecondaryContainer: "#e6c3f0",
        m3tertiary: "#56b6c2",
        m3onTertiary: "#282c34",
        m3tertiaryContainer: "#1e3a3f",
        m3onTertiaryContainer: "#bce5e8",
        m3error: "#e06c75",
        m3onError: "#282c34",
        m3errorContainer: "#52272a",
        m3onErrorContainer: "#f2c2c6",
        m3primaryFixed: "#61afef",
        m3primaryFixedDim: "#4d8cc0",
        m3onPrimaryFixed: "#282c34",
        m3onPrimaryFixedVariant: "#32363e",
        m3secondaryFixed: "#c678dd",
        m3secondaryFixedDim: "#9e60b1",
        m3onSecondaryFixed: "#282c34",
        m3onSecondaryFixedVariant: "#32363e",
        m3tertiaryFixed: "#56b6c2",
        m3tertiaryFixedDim: "#45919b",
        m3onTertiaryFixed: "#282c34",
        m3onTertiaryFixedVariant: "#32363e",
        m3success: "#98c379",
        m3onSuccess: "#282c34",
        m3successContainer: "#35452a",
        m3onSuccessContainer: "#d3e5c6"
    })

    // Gruvbox Dark (Hard) - Retro groove
    readonly property var gruvboxDarkColors: ({
        darkmode: true,
        m3background: "#1d2021",
        m3onBackground: "#ebdbb2",
        m3surface: "#1d2021",
        m3surfaceDim: "#1d2021",
        m3surfaceBright: "#32302f",
        m3surfaceContainerLowest: "#1d2021",
        m3surfaceContainerLow: "#282828",
        m3surfaceContainer: "#282828",
        m3surfaceContainerHigh: "#32302f",
        m3surfaceContainerHighest: "#3c3836",
        m3onSurface: "#ebdbb2",
        m3surfaceVariant: "#3c3836",
        m3onSurfaceVariant: "#a89984", // Gruvbox Gray 245
        m3inverseSurface: "#ebdbb2",
        m3inverseOnSurface: "#1d2021",
        m3outline: "#7c6f64",
        m3outlineVariant: "#504945",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#fabd2f",
        m3primary: "#fabd2f",
        m3onPrimary: "#1d2021", // Dark on Yellow
        m3primaryContainer: "#b57614",
        m3onPrimaryContainer: "#fbf1c7",
        m3inversePrimary: "#d79921",
        m3secondary: "#83a598",
        m3onSecondary: "#1d2021", // Dark on Blue
        m3secondaryContainer: "#458588",
        m3onSecondaryContainer: "#d3e8e1",
        m3tertiary: "#d3869b",
        m3onTertiary: "#1d2021", // Dark on Purple
        m3tertiaryContainer: "#b16286",
        m3onTertiaryContainer: "#f6dce8",
        m3error: "#fb4934",
        m3onError: "#1d2021",
        m3errorContainer: "#cc241d",
        m3onErrorContainer: "#f9ceca",
        m3primaryFixed: "#fabd2f",
        m3primaryFixedDim: "#d79921",
        m3onPrimaryFixed: "#1d2021",
        m3onPrimaryFixedVariant: "#282828",
        m3secondaryFixed: "#83a598",
        m3secondaryFixedDim: "#458588",
        m3onSecondaryFixed: "#1d2021",
        m3onSecondaryFixedVariant: "#282828",
        m3tertiaryFixed: "#d3869b",
        m3tertiaryFixedDim: "#b16286",
        m3onTertiaryFixed: "#1d2021",
        m3onTertiaryFixedVariant: "#282828",
        m3success: "#b8bb26",
        m3onSuccess: "#1d2021",
        m3successContainer: "#79740e",
        m3onSuccessContainer: "#d9dcb8"
    })

    // Catppuccin Frappe - Soft warm pastel
    readonly property var catppuccinFrappeColors: ({
        darkmode: true,
        m3background: "#303446",
        m3onBackground: "#c6d0f5",
        m3surface: "#303446",
        m3surfaceDim: "#292c3c",
        m3surfaceBright: "#414559",
        m3surfaceContainerLowest: "#292c3c",
        m3surfaceContainerLow: "#303446",
        m3surfaceContainer: "#414559",
        m3surfaceContainerHigh: "#51576d",
        m3surfaceContainerHighest: "#626880",
        m3onSurface: "#c6d0f5",
        m3surfaceVariant: "#626880",
        m3onSurfaceVariant: "#a5adce",
        m3inverseSurface: "#c6d0f5",
        m3inverseOnSurface: "#303446",
        m3outline: "#737994",
        m3outlineVariant: "#51576d",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8aadf4",
        m3primary: "#8aadf4",
        m3onPrimary: "#303446",
        m3primaryContainer: "#414559",
        m3onPrimaryContainer: "#bbd1f7",
        m3inversePrimary: "#719df0",
        m3secondary: "#f4b8e4",
        m3onSecondary: "#303446",
        m3secondaryContainer: "#414559",
        m3onSecondaryContainer: "#f9d7f0",
        m3tertiary: "#81c8be",
        m3onTertiary: "#303446",
        m3tertiaryContainer: "#414559",
        m3onTertiaryContainer: "#c5e6e1",
        m3error: "#e78284",
        m3onError: "#303446",
        m3errorContainer: "#414559",
        m3onErrorContainer: "#f2c1c2",
        m3primaryFixed: "#8aadf4",
        m3primaryFixedDim: "#6a94e0",
        m3onPrimaryFixed: "#303446",
        m3onPrimaryFixedVariant: "#414559",
        m3secondaryFixed: "#f4b8e4",
        m3secondaryFixedDim: "#e0a0d0",
        m3onSecondaryFixed: "#303446",
        m3onSecondaryFixedVariant: "#414559",
        m3tertiaryFixed: "#81c8be",
        m3tertiaryFixedDim: "#6cb0a8",
        m3onTertiaryFixed: "#303446",
        m3onTertiaryFixedVariant: "#414559",
        m3success: "#a6d189",
        m3onSuccess: "#303446",
        m3successContainer: "#414559",
        m3onSuccessContainer: "#d2e8c4"
    })

    // Dracula - Dark theme for vampires
    readonly property var draculaColors: ({
        darkmode: true,
        m3background: "#282a36",
        m3onBackground: "#f8f8f2",
        m3surface: "#282a36",
        m3surfaceDim: "#21222c",
        m3surfaceBright: "#44475a",
        m3surfaceContainerLowest: "#21222c",
        m3surfaceContainerLow: "#282a36",
        m3surfaceContainer: "#44475a",
        m3surfaceContainerHigh: "#6272a4",
        m3surfaceContainerHighest: "#6272a4",
        m3onSurface: "#f8f8f2",
        m3surfaceVariant: "#6272a4",
        m3onSurfaceVariant: "#bd93f9",
        m3inverseSurface: "#f8f8f2",
        m3inverseOnSurface: "#282a36",
        m3outline: "#6272a4",
        m3outlineVariant: "#44475a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#bd93f9",
        m3primary: "#bd93f9",
        m3onPrimary: "#282a36", // Dark background color for high contrast on purple
        m3primaryContainer: "#4a3c61",
        m3onPrimaryContainer: "#e6d6fc",
        m3inversePrimary: "#9580ff",
        m3secondary: "#ff79c6",
        m3onSecondary: "#282a36", // Dark on Pink
        m3secondaryContainer: "#613c51",
        m3onSecondaryContainer: "#ffccec",
        m3tertiary: "#8be9fd",
        m3onTertiary: "#282a36", // Dark on Cyan
        m3tertiaryContainer: "#3c5e61",
        m3onTertiaryContainer: "#d4f7fd",
        m3error: "#ff5555",
        m3onError: "#282a36",
        m3errorContainer: "#612222",
        m3onErrorContainer: "#ffbfbf",
        m3primaryFixed: "#bd93f9",
        m3primaryFixedDim: "#9580ff",
        m3onPrimaryFixed: "#282a36",
        m3onPrimaryFixedVariant: "#44475a",
        m3secondaryFixed: "#ff79c6",
        m3secondaryFixedDim: "#d66ba6",
        m3onSecondaryFixed: "#282a36",
        m3onSecondaryFixedVariant: "#44475a",
        m3tertiaryFixed: "#8be9fd",
        m3tertiaryFixedDim: "#76c4d6",
        m3onTertiaryFixed: "#282a36",
        m3onTertiaryFixedVariant: "#44475a",
        m3success: "#50fa7b",
        m3onSuccess: "#282a36",
        m3successContainer: "#1e5e2e",
        m3onSuccessContainer: "#bdfdcd"
    })

    // Solarized Dark
    readonly property var solarizedDarkColors: ({
        darkmode: true,
        m3background: "#002b36",
        m3onBackground: "#93a1a1", // Base1 (better contrast than #839496)
        m3surface: "#002b36",
        m3surfaceDim: "#00212b",
        m3surfaceBright: "#073642",
        m3surfaceContainerLowest: "#00212b",
        m3surfaceContainerLow: "#002b36",
        m3surfaceContainer: "#073642",
        m3surfaceContainerHigh: "#586e75",
        m3surfaceContainerHighest: "#657b83",
        m3onSurface: "#93a1a1", // Base1
        m3surfaceVariant: "#586e75",
        m3onSurfaceVariant: "#839496", // Base0 (slightly muted)
        m3inverseSurface: "#fdf6e3", // Base3
        m3inverseOnSurface: "#002b36",
        m3outline: "#586e75",
        m3outlineVariant: "#073642",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#268bd2",
        m3primary: "#268bd2",
        m3onPrimary: "#002b36",
        m3primaryContainer: "#004c63",
        m3onPrimaryContainer: "#b0d8f0",
        m3inversePrimary: "#2075b0",
        m3secondary: "#2aa198",
        m3onSecondary: "#002b36",
        m3secondaryContainer: "#00524e",
        m3onSecondaryContainer: "#aee2de",
        m3tertiary: "#d33682",
        m3onTertiary: "#002b36",
        m3tertiaryContainer: "#661a3f",
        m3onTertiaryContainer: "#eeb4d0",
        m3error: "#dc322f",
        m3onError: "#002b36",
        m3errorContainer: "#6e1917",
        m3onErrorContainer: "#f1b1b0",
        m3primaryFixed: "#268bd2",
        m3primaryFixedDim: "#2075b0",
        m3onPrimaryFixed: "#002b36",
        m3onPrimaryFixedVariant: "#073642",
        m3secondaryFixed: "#2aa198",
        m3secondaryFixedDim: "#238880",
        m3onSecondaryFixed: "#002b36",
        m3onSecondaryFixedVariant: "#073642",
        m3tertiaryFixed: "#d33682",
        m3tertiaryFixedDim: "#b02d6d",
        m3onTertiaryFixed: "#002b36",
        m3onTertiaryFixedVariant: "#073642",
        m3success: "#859900",
        m3onSuccess: "#002b36",
        m3successContainer: "#424c00",
        m3onSuccessContainer: "#d1d9a0"
    })

    // Monokai Pro
    readonly property var monokaiProColors: ({
        darkmode: true,
        m3background: "#2d2a2e",
        m3onBackground: "#fcfcfa",
        m3surface: "#2d2a2e",
        m3surfaceDim: "#221f22",
        m3surfaceBright: "#403e41",
        m3surfaceContainerLowest: "#221f22",
        m3surfaceContainerLow: "#2d2a2e",
        m3surfaceContainer: "#403e41",
        m3surfaceContainerHigh: "#5b595c",
        m3surfaceContainerHighest: "#727072",
        m3onSurface: "#fcfcfa",
        m3surfaceVariant: "#727072",
        m3onSurfaceVariant: "#c1c0c0",
        m3inverseSurface: "#fcfcfa",
        m3inverseOnSurface: "#2d2a2e",
        m3outline: "#939293",
        m3outlineVariant: "#5b595c",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#ffd866",
        m3primary: "#ffd866",
        m3onPrimary: "#2d2a2e",
        m3primaryContainer: "#665629",
        m3onPrimaryContainer: "#fff0c2",
        m3inversePrimary: "#e6c35c",
        m3secondary: "#ff6188",
        m3onSecondary: "#2d2a2e",
        m3secondaryContainer: "#662736",
        m3onSecondaryContainer: "#ffc0d0",
        m3tertiary: "#78dce8",
        m3onTertiary: "#2d2a2e",
        m3tertiaryContainer: "#30585d",
        m3onTertiaryContainer: "#c9f1f6",
        m3error: "#ff6188",
        m3onError: "#2d2a2e",
        m3errorContainer: "#662736",
        m3onErrorContainer: "#ffc0d0",
        m3primaryFixed: "#ffd866",
        m3primaryFixedDim: "#e6c35c",
        m3onPrimaryFixed: "#2d2a2e",
        m3onPrimaryFixedVariant: "#403e41",
        m3secondaryFixed: "#ff6188",
        m3secondaryFixedDim: "#e6577a",
        m3onSecondaryFixed: "#2d2a2e",
        m3onSecondaryFixedVariant: "#403e41",
        m3tertiaryFixed: "#78dce8",
        m3tertiaryFixedDim: "#6cc6d1",
        m3onTertiaryFixed: "#2d2a2e",
        m3onTertiaryFixedVariant: "#403e41",
        m3success: "#a9dc76",
        m3onSuccess: "#2d2a2e",
        m3successContainer: "#44582f",
        m3onSuccessContainer: "#dcf1c8"
    })

    // Rosé Pine
    readonly property var rosePineColors: ({
        darkmode: true,
        m3background: "#191724",
        m3onBackground: "#e0def4",
        m3surface: "#191724",
        m3surfaceDim: "#1f1d2e",
        m3surfaceBright: "#26233a",
        m3surfaceContainerLowest: "#191724",
        m3surfaceContainerLow: "#1f1d2e",
        m3surfaceContainer: "#26233a",
        m3surfaceContainerHigh: "#403d52",
        m3surfaceContainerHighest: "#524f67",
        m3onSurface: "#e0def4",
        m3surfaceVariant: "#524f67",
        m3onSurfaceVariant: "#908caa",
        m3inverseSurface: "#e0def4",
        m3inverseOnSurface: "#191724",
        m3outline: "#6e6a86",
        m3outlineVariant: "#524f67",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#c4a7e7",
        m3primary: "#c4a7e7",
        m3onPrimary: "#191724",
        m3primaryContainer: "#3a2f45",
        m3onPrimaryContainer: "#eadff8",
        m3inversePrimary: "#a88ac2",
        m3secondary: "#eb6f92",
        m3onSecondary: "#191724",
        m3secondaryContainer: "#45202b",
        m3onSecondaryContainer: "#f8c5d3",
        m3tertiary: "#31748f",
        m3onTertiary: "#191724",
        m3tertiaryContainer: "#183a48",
        m3onTertiaryContainer: "#add2e0",
        m3error: "#eb6f92",
        m3onError: "#191724",
        m3errorContainer: "#45202b",
        m3onErrorContainer: "#f8c5d3",
        m3primaryFixed: "#c4a7e7",
        m3primaryFixedDim: "#a88ac2",
        m3onPrimaryFixed: "#191724",
        m3onPrimaryFixedVariant: "#26233a",
        m3secondaryFixed: "#eb6f92",
        m3secondaryFixedDim: "#c95e7d",
        m3onSecondaryFixed: "#191724",
        m3onSecondaryFixedVariant: "#26233a",
        m3tertiaryFixed: "#31748f",
        m3tertiaryFixedDim: "#2a6279",
        m3onTertiaryFixed: "#191724",
        m3onTertiaryFixedVariant: "#26233a",
        m3success: "#9ccfd8",
        m3onSuccess: "#191724",
        m3successContainer: "#2e3e40",
        m3onSuccessContainer: "#d8ecef"
    })

    // Synthwave '84 - Retro Neon
    readonly property var synthwave84Colors: ({
        darkmode: true,
        m3background: "#262335",
        m3onBackground: "#ffffff",
        m3surface: "#262335",
        m3surfaceDim: "#1e1a29",
        m3surfaceBright: "#2a2139",
        m3surfaceContainerLowest: "#1e1a29",
        m3surfaceContainerLow: "#241b2f",
        m3surfaceContainer: "#2a2139",
        m3surfaceContainerHigh: "#34294a",
        m3surfaceContainerHighest: "#495495",
        m3onSurface: "#ffffff",
        m3surfaceVariant: "#495495",
        m3onSurfaceVariant: "#b0b8e6", // Boosted from #848bbd for legibility
        m3inverseSurface: "#ffffff",
        m3inverseOnSurface: "#262335",
        m3outline: "#616eb3", // Boosted form #495495 for Inir borders
        m3outlineVariant: "#34294a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#36f9f6",
        m3primary: "#36f9f6",
        m3onPrimary: "#262335", // High Contrast: Dark text on Cyan Neon
        m3primaryContainer: "#2a2139",
        m3onPrimaryContainer: "#72f1f8",
        m3inversePrimary: "#ff7edb",
        m3secondary: "#ff7edb",
        m3onSecondary: "#262335", // High Contrast: Dark text on Pink Neon
        m3secondaryContainer: "#492d50",
        m3onSecondaryContainer: "#ff92df",
        m3tertiary: "#b084eb",
        m3onTertiary: "#262335", // High Contrast: Dark text on Purple Neon
        m3tertiaryContainer: "#3a2d5a",
        m3onTertiaryContainer: "#c792ea",
        m3error: "#fe4450",
        m3onError: "#262335",
        m3errorContainer: "#501b2a",
        m3onErrorContainer: "#ff5e5b",
        m3primaryFixed: "#36f9f6",
        m3primaryFixedDim: "#2bcac7",
        m3onPrimaryFixed: "#262335",
        m3onPrimaryFixedVariant: "#2a2139",
        m3secondaryFixed: "#ff7edb",
        m3secondaryFixedDim: "#d466b5",
        m3onSecondaryFixed: "#262335",
        m3onSecondaryFixedVariant: "#2a2139",
        m3tertiaryFixed: "#b084eb",
        m3tertiaryFixedDim: "#906cc0",
        m3onTertiaryFixed: "#262335",
        m3onTertiaryFixedVariant: "#2a2139",
        m3success: "#72f1b8",
        m3onSuccess: "#262335",
        m3successContainer: "#1e3a2f",
        m3onSuccessContainer: "#97f1d8"
    })

    // Night Owl
    readonly property var nightOwlColors: ({
        darkmode: true,
        m3background: "#011627",
        m3onBackground: "#d6deeb",
        m3surface: "#011627",
        m3surfaceDim: "#000e1a",
        m3surfaceBright: "#0b253a",
        m3surfaceContainerLowest: "#000e1a",
        m3surfaceContainerLow: "#011627",
        m3surfaceContainer: "#0b253a",
        m3surfaceContainerHigh: "#1d3b53",
        m3surfaceContainerHighest: "#5f7e97",
        m3onSurface: "#d6deeb",
        m3surfaceVariant: "#5f7e97",
        m3onSurfaceVariant: "#89a4bb",
        m3inverseSurface: "#d6deeb",
        m3inverseOnSurface: "#011627",
        m3outline: "#5f7e97",
        m3outlineVariant: "#0b253a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#82AAFF",
        m3primary: "#82AAFF",
        m3onPrimary: "#011627",
        m3primaryContainer: "#0b253a",
        m3onPrimaryContainer: "#c5e478",
        m3inversePrimary: "#7fdbca",
        m3secondary: "#7fdbca",
        m3onSecondary: "#011627",
        m3secondaryContainer: "#0b253a",
        m3onSecondaryContainer: "#7fdbca",
        m3tertiary: "#c792ea",
        m3onTertiary: "#011627",
        m3tertiaryContainer: "#251d3a",
        m3onTertiaryContainer: "#e2b8ff",
        m3error: "#EF5350",
        m3onError: "#011627",
        m3errorContainer: "#3a1515",
        m3onErrorContainer: "#ff8684",
        m3primaryFixed: "#82AAFF",
        m3primaryFixedDim: "#6b8bc9",
        m3onPrimaryFixed: "#011627",
        m3onPrimaryFixedVariant: "#0b253a",
        m3secondaryFixed: "#7fdbca",
        m3secondaryFixedDim: "#65b0a2",
        m3onSecondaryFixed: "#011627",
        m3onSecondaryFixedVariant: "#0b253a",
        m3tertiaryFixed: "#c792ea",
        m3tertiaryFixedDim: "#a075bb",
        m3onTertiaryFixed: "#011627",
        m3onTertiaryFixedVariant: "#0b253a",
        m3success: "#c5e478",
        m3onSuccess: "#011627",
        m3successContainer: "#2f3a1d",
        m3onSuccessContainer: "#e4f7a0"
    })

    // Cobalt2
    readonly property var cobalt2Colors: ({
        darkmode: true,
        m3background: "#193549",
        m3onBackground: "#ffffff",
        m3surface: "#193549",
        m3surfaceDim: "#122738",
        m3surfaceBright: "#1f4662",
        m3surfaceContainerLowest: "#122738",
        m3surfaceContainerLow: "#193549",
        m3surfaceContainer: "#1f4662",
        m3surfaceContainerHigh: "#2a5a7d",
        m3surfaceContainerHighest: "#5c6b7d",
        m3onSurface: "#ffffff",
        m3surfaceVariant: "#1f4662",
        m3onSurfaceVariant: "#adb7c9",
        m3inverseSurface: "#ffffff",
        m3inverseOnSurface: "#193549",
        m3outline: "#1f4662",
        m3outlineVariant: "#0e1e2e",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#0088ff",
        m3primary: "#0088ff",
        m3onPrimary: "#193549",
        m3primaryContainer: "#122738",
        m3onPrimaryContainer: "#5cb7ff",
        m3inversePrimary: "#9a5feb",
        m3secondary: "#9a5feb",
        m3onSecondary: "#193549",
        m3secondaryContainer: "#2a1a45",
        m3onSecondaryContainer: "#b88cfd",
        m3tertiary: "#2affdf",
        m3onTertiary: "#193549",
        m3tertiaryContainer: "#0e3a35",
        m3onTertiaryContainer: "#7efff5",
        m3error: "#ff0088",
        m3onError: "#ffffff",
        m3errorContainer: "#450025",
        m3onErrorContainer: "#ff5fb3",
        m3primaryFixed: "#0088ff",
        m3primaryFixedDim: "#006ecc",
        m3onPrimaryFixed: "#193549",
        m3onPrimaryFixedVariant: "#1f4662",
        m3secondaryFixed: "#9a5feb",
        m3secondaryFixedDim: "#7c4dbe",
        m3onSecondaryFixed: "#193549",
        m3onSecondaryFixedVariant: "#1f4662",
        m3tertiaryFixed: "#2affdf",
        m3tertiaryFixedDim: "#22ccb2",
        m3onTertiaryFixed: "#193549",
        m3onTertiaryFixedVariant: "#1f4662",
        m3success: "#9eff80",
        m3onSuccess: "#193549",
        m3successContainer: "#25451d",
        m3onSuccessContainer: "#b9ff9f"
    })

    // GitHub Dark
    readonly property var githubDarkColors: ({
        darkmode: true,
        m3background: "#0d1117",
        m3onBackground: "#c9d1d9",
        m3surface: "#0d1117",
        m3surfaceDim: "#010409",
        m3surfaceBright: "#161b22",
        m3surfaceContainerLowest: "#010409",
        m3surfaceContainerLow: "#0d1117",
        m3surfaceContainer: "#161b22",
        m3surfaceContainerHigh: "#21262d",
        m3surfaceContainerHighest: "#30363d",
        m3onSurface: "#c9d1d9",
        m3surfaceVariant: "#30363d",
        m3onSurfaceVariant: "#8b949e",
        m3inverseSurface: "#c9d1d9",
        m3inverseOnSurface: "#0d1117",
        m3outline: "#30363d",
        m3outlineVariant: "#21262d",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#58a6ff",
        m3primary: "#58a6ff",
        m3onPrimary: "#0d1117",
        m3primaryContainer: "#1f6feb",
        m3onPrimaryContainer: "#ffffff",
        m3inversePrimary: "#bc8cff",
        m3secondary: "#bc8cff",
        m3onSecondary: "#0d1117",
        m3secondaryContainer: "#3a1d6e",
        m3onSecondaryContainer: "#d2a8ff",
        m3tertiary: "#39c5cf",
        m3onTertiary: "#0d1117",
        m3tertiaryContainer: "#103a3e",
        m3onTertiaryContainer: "#56d4dd",
        m3error: "#f85149",
        m3onError: "#0d1117",
        m3errorContainer: "#da3633",
        m3onErrorContainer: "#ff8182",
        m3primaryFixed: "#58a6ff",
        m3primaryFixedDim: "#4482c9",
        m3onPrimaryFixed: "#0d1117",
        m3onPrimaryFixedVariant: "#161b22",
        m3secondaryFixed: "#bc8cff",
        m3secondaryFixedDim: "#966fcc",
        m3onSecondaryFixed: "#0d1117",
        m3onSecondaryFixedVariant: "#161b22",
        m3tertiaryFixed: "#39c5cf",
        m3tertiaryFixedDim: "#2da0a8",
        m3onTertiaryFixed: "#0d1117",
        m3onTertiaryFixedVariant: "#161b22",
        m3success: "#3fb950",
        m3onSuccess: "#0d1117",
        m3successContainer: "#2ea043",
        m3onSuccessContainer: "#56d364"
    })

    // Vercel
    readonly property var vercelColors: ({
        darkmode: true,
        m3background: "#000000",
        m3onBackground: "#ededed",
        m3surface: "#000000",
        m3surfaceDim: "#000000",
        m3surfaceBright: "#1a1a1a",
        m3surfaceContainerLowest: "#000000",
        m3surfaceContainerLow: "#0a0a0a",
        m3surfaceContainer: "#141414",
        m3surfaceContainerHigh: "#1a1a1a",
        m3surfaceContainerHighest: "#292929",
        m3onSurface: "#ededed",
        m3surfaceVariant: "#292929",
        m3onSurfaceVariant: "#a1a1a1",
        m3inverseSurface: "#ededed",
        m3inverseOnSurface: "#000000",
        m3outline: "#454545",
        m3outlineVariant: "#2e2e2e",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#0070F3",
        m3primary: "#0070F3",
        m3onPrimary: "#000000",
        m3primaryContainer: "#003e87",
        m3onPrimaryContainer: "#52A8FF",
        m3inversePrimary: "#52A8FF",
        m3secondary: "#52A8FF",
        m3onSecondary: "#000000",
        m3secondaryContainer: "#002a5c",
        m3onSecondaryContainer: "#EBF8FF",
        m3tertiary: "#8E4EC6",
        m3onTertiary: "#000000",
        m3tertiaryContainer: "#401861",
        m3onTertiaryContainer: "#BF7AF0",
        m3error: "#E5484D",
        m3onError: "#000000",
        m3errorContainer: "#5c1d1f",
        m3onErrorContainer: "#FF6166",
        m3primaryFixed: "#0070F3",
        m3primaryFixedDim: "#0056b3",
        m3onPrimaryFixed: "#000000",
        m3onPrimaryFixedVariant: "#1a1a1a",
        m3secondaryFixed: "#52A8FF",
        m3secondaryFixedDim: "#2e8dec",
        m3onSecondaryFixed: "#000000",
        m3onSecondaryFixedVariant: "#1a1a1a",
        m3tertiaryFixed: "#8E4EC6",
        m3tertiaryFixedDim: "#703ca1",
        m3onTertiaryFixed: "#000000",
        m3onTertiaryFixedVariant: "#1a1a1a",
        m3success: "#46A758",
        m3onSuccess: "#000000",
        m3successContainer: "#1e4726",
        m3onSuccessContainer: "#63C46D"
    })

    // Zenburn - Low Contrast
    readonly property var zenburnColors: ({
        darkmode: true,
        m3background: "#3f3f3f",
        m3onBackground: "#dcdccc",
        m3surface: "#3f3f3f",
        m3surfaceDim: "#383838",
        m3surfaceBright: "#4f4f4f",
        m3surfaceContainerLowest: "#383838",
        m3surfaceContainerLow: "#3f3f3f",
        m3surfaceContainer: "#4f4f4f",
        m3surfaceContainerHigh: "#5f5f5f",
        m3surfaceContainerHighest: "#6f6f6f",
        m3onSurface: "#dcdccc",
        m3surfaceVariant: "#5f5f5f",
        m3onSurfaceVariant: "#bfbfbf", // Increased contrast from #9f9f9f
        m3inverseSurface: "#dcdccc",
        m3inverseOnSurface: "#3f3f3f",
        m3outline: "#7f7f7f", // Increased from #5f5f5f for better border visibility
        m3outlineVariant: "#5f5f5f",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8cd0d3",
        m3primary: "#8cd0d3",
        m3onPrimary: "#3f3f3f",
        m3primaryContainer: "#3a5759",
        m3onPrimaryContainer: "#93e0e3",
        m3inversePrimary: "#7cb8bb",
        m3secondary: "#dc8cc3",
        m3onSecondary: "#3f3f3f",
        m3secondaryContainer: "#5e3c53",
        m3onSecondaryContainer: "#e8b8d8",
        m3tertiary: "#93e0e3",
        m3onTertiary: "#3f3f3f",
        m3tertiaryContainer: "#3d5e60",
        m3onTertiaryContainer: "#b0f0f3",
        m3error: "#cc9393",
        m3onError: "#3f3f3f",
        m3errorContainer: "#573d3d",
        m3onErrorContainer: "#dca3a3",
        m3primaryFixed: "#8cd0d3",
        m3primaryFixedDim: "#70a6a9",
        m3onPrimaryFixed: "#3f3f3f",
        m3onPrimaryFixedVariant: "#4f4f4f",
        m3secondaryFixed: "#dc8cc3",
        m3secondaryFixedDim: "#b0709c",
        m3onSecondaryFixed: "#3f3f3f",
        m3onSecondaryFixedVariant: "#4f4f4f",
        m3tertiaryFixed: "#93e0e3",
        m3tertiaryFixedDim: "#76b3b5",
        m3onTertiaryFixed: "#3f3f3f",
        m3onTertiaryFixedVariant: "#4f4f4f",
        m3success: "#7f9f7f",
        m3onSuccess: "#3f3f3f",
        m3successContainer: "#354235",
        m3onSuccessContainer: "#8fb28f"
    })

    // Mercury
    readonly property var mercuryColors: ({
        darkmode: true,
        m3background: "#171721",
        m3onBackground: "#dddde5",
        m3surface: "#171721",
        m3surfaceDim: "#10101a",
        m3surfaceBright: "#1e1e2a",
        m3surfaceContainerLowest: "#10101a",
        m3surfaceContainerLow: "#171721",
        m3surfaceContainer: "#1e1e2a",
        m3surfaceContainerHigh: "#272735",
        m3surfaceContainerHighest: "#363644",
        m3onSurface: "#dddde5",
        m3surfaceVariant: "#363644",
        m3onSurfaceVariant: "#9d9da8",
        m3inverseSurface: "#dddde5",
        m3inverseOnSurface: "#171721",
        m3outline: "#636375", // Boosted from #535461
        m3outlineVariant: "#464655", // Boosted from #363644
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#8da4f5",
        m3primary: "#8da4f5",
        m3onPrimary: "#171721",
        m3primaryContainer: "#3442a6",
        m3onPrimaryContainer: "#a7b6f8",
        m3inversePrimary: "#5266eb",
        m3secondary: "#a7b6f8",
        m3onSecondary: "#171721",
        m3secondaryContainer: "#465bd1",
        m3onSecondaryContainer: "#cdd6fc",
        m3tertiary: "#77becf",
        m3onTertiary: "#171721",
        m3tertiaryContainer: "#007f95",
        m3onTertiaryContainer: "#b0dfe8",
        m3error: "#fc92b4",
        m3onError: "#171721",
        m3errorContainer: "#b0175f",
        m3onErrorContainer: "#fdc2d5",
        m3primaryFixed: "#8da4f5",
        m3primaryFixedDim: "#7083c4",
        m3onPrimaryFixed: "#171721",
        m3onPrimaryFixedVariant: "#1e1e2a",
        m3secondaryFixed: "#a7b6f8",
        m3secondaryFixedDim: "#8591c6",
        m3onSecondaryFixed: "#171721",
        m3onSecondaryFixedVariant: "#1e1e2a",
        m3tertiaryFixed: "#77becf",
        m3tertiaryFixedDim: "#5fa8b9",
        m3onTertiaryFixed: "#171721",
        m3onTertiaryFixedVariant: "#1e1e2a",
        m3success: "#77c599",
        m3onSuccess: "#171721",
        m3successContainer: "#036e43",
        m3onSuccessContainer: "#bcedce"
    })

    // Flexoki
    readonly property var flexokiColors: ({
        darkmode: true,
        m3background: "#100F0F",
        m3onBackground: "#CECDC3",
        m3surface: "#100F0F",
        m3surfaceDim: "#1C1B1A",
        m3surfaceBright: "#282726",
        m3surfaceContainerLowest: "#1C1B1A",
        m3surfaceContainerLow: "#100F0F",
        m3surfaceContainer: "#282726",
        m3surfaceContainerHigh: "#343331",
        m3surfaceContainerHighest: "#403E3C",
        m3onSurface: "#CECDC3",
        m3surfaceVariant: "#403E3C",
        m3onSurfaceVariant: "#b7b5ac", // Boosted from #878580
        m3inverseSurface: "#CECDC3",
        m3inverseOnSurface: "#100F0F",
        m3outline: "#6F6E69", // Boosted from #575653
        m3outlineVariant: "#403E3C",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#DA702C",
        m3primary: "#DA702C",
        m3onPrimary: "#100F0F", // Ink color on Orange
        m3primaryContainer: "#5c3315",
        m3onPrimaryContainer: "#f0b894",
        m3inversePrimary: "#BC5215",
        m3secondary: "#4385BE",
        m3onSecondary: "#100F0F", // Ink color on Blue
        m3secondaryContainer: "#1b3852",
        m3onSecondaryContainer: "#b0d1f0",
        m3tertiary: "#8B7EC8",
        m3onTertiary: "#100F0F", // Ink color on Purple
        m3tertiaryContainer: "#3a3554",
        m3onTertiaryContainer: "#c9c2e8",
        m3error: "#D14D41",
        m3onError: "#100F0F",
        m3errorContainer: "#59211c",
        m3onErrorContainer: "#eb9d96",
        m3primaryFixed: "#DA702C",
        m3primaryFixedDim: "#ae5a23",
        m3onPrimaryFixed: "#100F0F",
        m3onPrimaryFixedVariant: "#282726",
        m3secondaryFixed: "#4385BE",
        m3secondaryFixedDim: "#356a98",
        m3onSecondaryFixed: "#100F0F",
        m3onSecondaryFixedVariant: "#282726",
        m3tertiaryFixed: "#8B7EC8",
        m3tertiaryFixedDim: "#6f65a0",
        m3onTertiaryFixed: "#100F0F",
        m3onTertiaryFixedVariant: "#282726",
        m3success: "#879A39",
        m3onSuccess: "#100F0F",
        m3successContainer: "#384018",
        m3onSuccessContainer: "#c3cc9b"
    })

    // Cursor
    readonly property var cursorColors: ({
        darkmode: true,
        m3background: "#181818",
        m3onBackground: "#e4e4e4",
        m3surface: "#181818",
        m3surfaceDim: "#141414",
        m3surfaceBright: "#262626",
        m3surfaceContainerLowest: "#141414",
        m3surfaceContainerLow: "#181818",
        m3surfaceContainer: "#262626",
        m3surfaceContainerHigh: "#303030",
        m3surfaceContainerHighest: "#3a3a3a",
        m3onSurface: "#e4e4e4",
        m3surfaceVariant: "#3a3a3a",
        m3onSurfaceVariant: "#a0a0a0",
        m3inverseSurface: "#e4e4e4",
        m3inverseOnSurface: "#181818",
        m3outline: "#505050",
        m3outlineVariant: "#3a3a3a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#88c0d0",
        m3primary: "#88c0d0",
        m3onPrimary: "#181818",
        m3primaryContainer: "#304850",
        m3onPrimaryContainer: "#c4e0e8",
        m3inversePrimary: "#6f9ba6",
        m3secondary: "#81a1c1",
        m3onSecondary: "#181818",
        m3secondaryContainer: "#303c48",
        m3onSecondaryContainer: "#bfcfe0",
        m3tertiary: "#82D2CE",
        m3onTertiary: "#181818",
        m3tertiaryContainer: "#304e4c",
        m3onTertiaryContainer: "#c1e9e7",
        m3error: "#e34671",
        m3onError: "#181818",
        m3errorContainer: "#501828",
        m3onErrorContainer: "#f1a3b8",
        m3primaryFixed: "#88c0d0",
        m3primaryFixedDim: "#6daab8",
        m3onPrimaryFixed: "#181818",
        m3onPrimaryFixedVariant: "#262626",
        m3secondaryFixed: "#81a1c1",
        m3secondaryFixedDim: "#67809a",
        m3onSecondaryFixed: "#181818",
        m3onSecondaryFixedVariant: "#262626",
        m3tertiaryFixed: "#82D2CE",
        m3tertiaryFixedDim: "#68a8a5",
        m3onTertiaryFixed: "#181818",
        m3onTertiaryFixedVariant: "#262626",
        m3success: "#3fa266",
        m3onSuccess: "#181818",
        m3successContainer: "#184028",
        m3onSuccessContainer: "#9fd1b3"
    })

    // Material Ocean
    readonly property var materialOceanColors: ({
        darkmode: true,
        m3background: "#263238",
        m3onBackground: "#eeffff",
        m3surface: "#263238",
        m3surfaceDim: "#1e272c",
        m3surfaceBright: "#37474f",
        m3surfaceContainerLowest: "#1e272c",
        m3surfaceContainerLow: "#263238",
        m3surfaceContainer: "#37474f",
        m3surfaceContainerHigh: "#455a64",
        m3surfaceContainerHighest: "#546e7a",
        m3onSurface: "#eeffff",
        m3surfaceVariant: "#546e7a",
        m3onSurfaceVariant: "#90a4ae",
        m3inverseSurface: "#eeffff",
        m3inverseOnSurface: "#263238",
        m3outline: "#546e7a",
        m3outlineVariant: "#37474f",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#82aaff",
        m3primary: "#82aaff",
        m3onPrimary: "#263238",
        m3primaryContainer: "#37474f",
        m3onPrimaryContainer: "#c1d5ff",
        m3inversePrimary: "#6182b8",
        m3secondary: "#c792ea",
        m3onSecondary: "#263238",
        m3secondaryContainer: "#4a3c57",
        m3onSecondaryContainer: "#e3c8f5",
        m3tertiary: "#89ddff",
        m3onTertiary: "#263238",
        m3tertiaryContainer: "#32515e",
        m3onTertiaryContainer: "#c4eeff",
        m3error: "#f07178",
        m3onError: "#263238",
        m3errorContainer: "#572d30",
        m3onErrorContainer: "#f8b8bc",
        m3primaryFixed: "#82aaff",
        m3primaryFixedDim: "#6888cc",
        m3onPrimaryFixed: "#263238",
        m3onPrimaryFixedVariant: "#37474f",
        m3secondaryFixed: "#c792ea",
        m3secondaryFixedDim: "#9f75bb",
        m3onSecondaryFixed: "#263238",
        m3onSecondaryFixedVariant: "#37474f",
        m3tertiaryFixed: "#89ddff",
        m3tertiaryFixedDim: "#6eb0cc",
        m3onTertiaryFixed: "#263238",
        m3onTertiaryFixedVariant: "#37474f",
        m3success: "#c3e88d",
        m3onSuccess: "#263238",
        m3successContainer: "#475435",
        m3onSuccessContainer: "#e1f4c6"
    })

    // Palenight
    readonly property var palenightColors: ({
        darkmode: true,
        m3background: "#292d3e",
        m3onBackground: "#a6accd",
        m3surface: "#292d3e",
        m3surfaceDim: "#1e2132",
        m3surfaceBright: "#32364a",
        m3surfaceContainerLowest: "#1e2132",
        m3surfaceContainerLow: "#292d3e",
        m3surfaceContainer: "#32364a",
        m3surfaceContainerHigh: "#444267",
        m3surfaceContainerHighest: "#676e95",
        m3onSurface: "#a6accd",
        m3surfaceVariant: "#676e95",
        m3onSurfaceVariant: "#8796b0",
        m3inverseSurface: "#a6accd",
        m3inverseOnSurface: "#292d3e",
        m3outline: "#676e95",
        m3outlineVariant: "#32364a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#82aaff",
        m3primary: "#82aaff",
        m3onPrimary: "#292d3e",
        m3primaryContainer: "#32364a",
        m3onPrimaryContainer: "#c1d5ff",
        m3inversePrimary: "#4976eb",
        m3secondary: "#c792ea",
        m3onSecondary: "#292d3e",
        m3secondaryContainer: "#4a3c57",
        m3onSecondaryContainer: "#e3c8f5",
        m3tertiary: "#89ddff",
        m3onTertiary: "#292d3e",
        m3tertiaryContainer: "#32515e",
        m3onTertiaryContainer: "#c4eeff",
        m3error: "#f07178",
        m3onError: "#292d3e",
        m3errorContainer: "#572d30",
        m3onErrorContainer: "#f8b8bc",
        m3primaryFixed: "#82aaff",
        m3primaryFixedDim: "#6888cc",
        m3onPrimaryFixed: "#292d3e",
        m3onPrimaryFixedVariant: "#32364a",
        m3secondaryFixed: "#c792ea",
        m3secondaryFixedDim: "#9f75bb",
        m3onSecondaryFixed: "#292d3e",
        m3onSecondaryFixedVariant: "#32364a",
        m3tertiaryFixed: "#89ddff",
        m3tertiaryFixedDim: "#6eb0cc",
        m3onTertiaryFixed: "#292d3e",
        m3onTertiaryFixedVariant: "#32364a",
        m3success: "#c3e88d",
        m3onSuccess: "#292d3e",
        m3successContainer: "#475435",
        m3onSuccessContainer: "#e1f4c6"
    })

    // Osaka Jade
    readonly property var osakaJadeColors: ({
        darkmode: true,
        m3background: "#111c18",
        m3onBackground: "#C1C497",
        m3surface: "#111c18",
        m3surfaceDim: "#0d1411",
        m3surfaceBright: "#1a2520",
        m3surfaceContainerLowest: "#0d1411",
        m3surfaceContainerLow: "#111c18",
        m3surfaceContainer: "#1a2520",
        m3surfaceContainerHigh: "#23372B",
        m3surfaceContainerHighest: "#3d4a44",
        m3onSurface: "#C1C497",
        m3surfaceVariant: "#3d4a44",
        m3onSurfaceVariant: "#9aa88a",
        m3inverseSurface: "#C1C497",
        m3inverseOnSurface: "#111c18",
        m3outline: "#53685B",
        m3outlineVariant: "#3d4a44",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#2DD5B7",
        m3primary: "#2DD5B7",
        m3onPrimary: "#111c18",
        m3primaryContainer: "#16453b",
        m3onPrimaryContainer: "#8CD3CB",
        m3inversePrimary: "#1faa90",
        m3secondary: "#D2689C",
        m3onSecondary: "#111c18",
        m3secondaryContainer: "#4a2537",
        m3onSecondaryContainer: "#75bbb3",
        m3tertiary: "#549e6a",
        m3onTertiary: "#111c18",
        m3tertiaryContainer: "#1e3826",
        m3onTertiaryContainer: "#63b07a",
        m3error: "#FF5345",
        m3onError: "#111c18",
        m3errorContainer: "#5c201b",
        m3onErrorContainer: "#db9f9c",
        m3primaryFixed: "#2DD5B7",
        m3primaryFixedDim: "#24aa92",
        m3onPrimaryFixed: "#111c18",
        m3onPrimaryFixedVariant: "#1a2520",
        m3secondaryFixed: "#D2689C",
        m3secondaryFixedDim: "#a8537d",
        m3onSecondaryFixed: "#111c18",
        m3onSecondaryFixedVariant: "#1a2520",
        m3tertiaryFixed: "#549e6a",
        m3tertiaryFixedDim: "#437e55",
        m3onTertiaryFixed: "#111c18",
        m3onTertiaryFixedVariant: "#1a2520",
        m3success: "#549e6a",
        m3onSuccess: "#111c18",
        m3successContainer: "#1e3826",
        m3onSuccessContainer: "#63b07a"
    })

    // Monokai (Classic)
    readonly property var monokaiColors: ({
        darkmode: true,
        m3background: "#272822",
        m3onBackground: "#f8f8f2",
        m3surface: "#272822",
        m3surfaceDim: "#1e1f1c",
        m3surfaceBright: "#3e3d32",
        m3surfaceContainerLowest: "#1e1f1c",
        m3surfaceContainerLow: "#272822",
        m3surfaceContainer: "#3e3d32",
        m3surfaceContainerHigh: "#5c5b4b",
        m3surfaceContainerHighest: "#75715e",
        m3onSurface: "#f8f8f2",
        m3surfaceVariant: "#75715e",
        m3onSurfaceVariant: "#cfcfc2",
        m3inverseSurface: "#f8f8f2",
        m3inverseOnSurface: "#272822",
        m3outline: "#75715e",
        m3outlineVariant: "#3e3d32",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#66d9ef",
        m3primary: "#66d9ef",
        m3onPrimary: "#272822",
        m3primaryContainer: "#254f57",
        m3onPrimaryContainer: "#b3ecf7",
        m3inversePrimary: "#66d9ef",
        m3secondary: "#ae81ff",
        m3onSecondary: "#272822",
        m3secondaryContainer: "#40305e",
        m3onSecondaryContainer: "#d7c0ff",
        m3tertiary: "#a6e22e",
        m3onTertiary: "#272822",
        m3tertiaryContainer: "#3d5211",
        m3onTertiaryContainer: "#d2f096",
        m3error: "#f92672",
        m3onError: "#272822",
        m3errorContainer: "#5b0e2a",
        m3onErrorContainer: "#fc93b9",
        m3primaryFixed: "#66d9ef",
        m3primaryFixedDim: "#52adc0",
        m3onPrimaryFixed: "#272822",
        m3onPrimaryFixedVariant: "#3e3d32",
        m3secondaryFixed: "#ae81ff",
        m3secondaryFixedDim: "#8b67cc",
        m3onSecondaryFixed: "#272822",
        m3onSecondaryFixedVariant: "#3e3d32",
        m3tertiaryFixed: "#a6e22e",
        m3tertiaryFixedDim: "#85b525",
        m3onTertiaryFixed: "#272822",
        m3onTertiaryFixedVariant: "#3e3d32",
        m3success: "#a6e22e",
        m3onSuccess: "#272822",
        m3successContainer: "#3d5211",
        m3onSuccessContainer: "#d2f096"
    })

    // Vesper
    readonly property var vesperColors: ({
        darkmode: true,
        m3background: "#101010",
        m3onBackground: "#FFFFFF",
        m3surface: "#101010",
        m3surfaceDim: "#0a0a0a",
        m3surfaceBright: "#1C1C1C",
        m3surfaceContainerLowest: "#0a0a0a",
        m3surfaceContainerLow: "#101010",
        m3surfaceContainer: "#1C1C1C",
        m3surfaceContainerHigh: "#282828",
        m3surfaceContainerHighest: "#333333",
        m3onSurface: "#FFFFFF",
        m3surfaceVariant: "#333333",
        m3onSurfaceVariant: "#A0A0A0",
        m3inverseSurface: "#FFFFFF",
        m3inverseOnSurface: "#101010",
        m3outline: "#404040", // Boosted from #282828 for visibility
        m3outlineVariant: "#282828", // Boosted from #1C1C1C
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#FFC799",
        m3primary: "#FFC799",
        m3onPrimary: "#101010",
        m3primaryContainer: "#5c4837",
        m3onPrimaryContainer: "#ffe3cc",
        m3inversePrimary: "#b38b6b",
        m3secondary: "#99FFE4",
        m3onSecondary: "#101010",
        m3secondaryContainer: "#375c52",
        m3onSecondaryContainer: "#ccfff1",
        m3tertiary: "#A0A0A0",
        m3onTertiary: "#101010",
        m3tertiaryContainer: "#3a3a3a",
        m3onTertiaryContainer: "#d0d0d0",
        m3error: "#FF8080",
        m3onError: "#101010",
        m3errorContainer: "#5c2e2e",
        m3onErrorContainer: "#ffbfbf",
        m3primaryFixed: "#FFC799",
        m3primaryFixedDim: "#b38b6b",
        m3onPrimaryFixed: "#101010",
        m3onPrimaryFixedVariant: "#1C1C1C",
        m3secondaryFixed: "#99FFE4",
        m3secondaryFixedDim: "#6bb3a0",
        m3onSecondaryFixed: "#101010",
        m3onSecondaryFixedVariant: "#1C1C1C",
        m3tertiaryFixed: "#A0A0A0",
        m3tertiaryFixedDim: "#707070",
        m3onTertiaryFixed: "#101010",
        m3onTertiaryFixedVariant: "#1C1C1C",
        m3success: "#99FFE4",
        m3onSuccess: "#101010",
        m3successContainer: "#375c52",
        m3onSuccessContainer: "#ccfff1"
    })

    // Orng
    readonly property var orngColors: ({
        darkmode: true,
        m3background: "#0a0a0a",
        m3onBackground: "#eeeeee",
        m3surface: "#0a0a0a",
        m3surfaceDim: "#000000",
        m3surfaceBright: "#1e1e1e",
        m3surfaceContainerLowest: "#000000",
        m3surfaceContainerLow: "#0a0a0a",
        m3surfaceContainer: "#141414",
        m3surfaceContainerHigh: "#1e1e1e",
        m3surfaceContainerHighest: "#282828",
        m3onSurface: "#eeeeee",
        m3surfaceVariant: "#282828",
        m3onSurfaceVariant: "#808080",
        m3inverseSurface: "#eeeeee",
        m3inverseOnSurface: "#0a0a0a",
        m3outline: "#484848",
        m3outlineVariant: "#3c3c3c",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#EC5B2B",
        m3primary: "#EC5B2B",
        m3onPrimary: "#0a0a0a",
        m3primaryContainer: "#552110",
        m3onPrimaryContainer: "#EE7948",
        m3inversePrimary: "#c94d24",
        m3secondary: "#EE7948",
        m3onSecondary: "#0a0a0a",
        m3secondaryContainer: "#562b1a",
        m3onSecondaryContainer: "#ffbfa6",
        m3tertiary: "#FFF7F1",
        m3onTertiary: "#0a0a0a",
        m3tertiaryContainer: "#282828",
        m3onTertiaryContainer: "#ffffff",
        m3error: "#e06c75",
        m3onError: "#0a0a0a",
        m3errorContainer: "#51272a",
        m3onErrorContainer: "#f0b6bb",
        m3primaryFixed: "#EC5B2B",
        m3primaryFixedDim: "#a5401e",
        m3onPrimaryFixed: "#0a0a0a",
        m3onPrimaryFixedVariant: "#1e1e1e",
        m3secondaryFixed: "#EE7948",
        m3secondaryFixedDim: "#a75532",
        m3onSecondaryFixed: "#0a0a0a",
        m3onSecondaryFixedVariant: "#1e1e1e",
        m3tertiaryFixed: "#FFF7F1",
        m3tertiaryFixedDim: "#b3ada9",
        m3onTertiaryFixed: "#0a0a0a",
        m3onTertiaryFixedVariant: "#1e1e1e",
        m3success: "#6ba1e6",
        m3onSuccess: "#0a0a0a",
        m3successContainer: "#263a53",
        m3onSuccessContainer: "#aaccf2"
    })

    // Lucent Orng (Transparent variant)
    readonly property var lucentOrngColors: ({
        darkmode: true,
        transparent: true,
        m3background: "#0a0a0a",
        m3onBackground: "#eeeeee",
        m3surface: "#0a0a0a",
        m3surfaceDim: "#000000",
        m3surfaceBright: "#1e1e1e",
        m3surfaceContainerLowest: "#000000",
        m3surfaceContainerLow: "#0a0a0a",
        m3surfaceContainer: "#141414",
        m3surfaceContainerHigh: "#1e1e1e",
        m3surfaceContainerHighest: "#282828",
        m3onSurface: "#eeeeee",
        m3surfaceVariant: "#282828",
        m3onSurfaceVariant: "#808080",
        m3inverseSurface: "#eeeeee",
        m3inverseOnSurface: "#0a0a0a",
        m3outline: "#EC5B2B",
        m3outlineVariant: "#3c3c3c",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#EC5B2B",
        m3primary: "#EC5B2B",
        m3onPrimary: "#0a0a0a",
        m3primaryContainer: "#552110",
        m3onPrimaryContainer: "#EE7948",
        m3inversePrimary: "#c94d24",
        m3secondary: "#EE7948",
        m3onSecondary: "#0a0a0a",
        m3secondaryContainer: "#562b1a",
        m3onSecondaryContainer: "#ffbfa6",
        m3tertiary: "#FFF7F1",
        m3onTertiary: "#0a0a0a",
        m3tertiaryContainer: "#282828",
        m3onTertiaryContainer: "#ffffff",
        m3error: "#e06c75",
        m3onError: "#0a0a0a",
        m3errorContainer: "#51272a",
        m3onErrorContainer: "#f0b6bb",
        m3primaryFixed: "#EC5B2B",
        m3primaryFixedDim: "#a5401e",
        m3onPrimaryFixed: "#0a0a0a",
        m3onPrimaryFixedVariant: "#1e1e1e",
        m3secondaryFixed: "#EE7948",
        m3secondaryFixedDim: "#a75532",
        m3onSecondaryFixed: "#0a0a0a",
        m3onSecondaryFixedVariant: "#1e1e1e",
        m3tertiaryFixed: "#FFF7F1",
        m3tertiaryFixedDim: "#b3ada9",
        m3onTertiaryFixed: "#0a0a0a",
        m3onTertiaryFixedVariant: "#1e1e1e",
        m3success: "#6ba1e6",
        m3onSuccess: "#0a0a0a",
        m3successContainer: "#263a53",
        m3onSuccessContainer: "#aaccf2"
    })

    // Fields of the Shire (Dark) — Inspired by OpenChamber's "Fields of the Shire"
    // Warm earthy tones: muted olive greens, parchment creams, amber and clay
    readonly property var fieldsOfTheShireDarkColors: ({
        darkmode: true,
        m3background: "#1b1815",
        m3onBackground: "#ebe0d1",
        m3surface: "#1b1815",
        m3surfaceDim: "#141210",
        m3surfaceBright: "#2b2622",
        m3surfaceContainerLowest: "#141210",
        m3surfaceContainerLow: "#1b1815",
        m3surfaceContainer: "#231f1b",
        m3surfaceContainerHigh: "#2b2622",
        m3surfaceContainerHighest: "#332d28",
        m3onSurface: "#ebe0d1",
        m3surfaceVariant: "#332d28",
        m3onSurfaceVariant: "#a89888",
        m3inverseSurface: "#ebe0d1",
        m3inverseOnSurface: "#1b1815",
        m3outline: "#6a5e52",
        m3outlineVariant: "#413e3a",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#7a8a5a",
        m3primary: "#7a8a5a",
        m3onPrimary: "#1b1815",
        m3primaryContainer: "#3d4530",
        m3onPrimaryContainer: "#a4b67d",
        m3inversePrimary: "#93a56b",
        m3secondary: "#c47a3a",
        m3onSecondary: "#1b1815",
        m3secondaryContainer: "#5c3a1e",
        m3onSecondaryContainer: "#e8a870",
        m3tertiary: "#5a6d7a",
        m3onTertiary: "#ebe0d1",
        m3tertiaryContainer: "#2e3840",
        m3onTertiaryContainer: "#8fa8b8",
        m3error: "#b34d3b",
        m3onError: "#ebe0d1",
        m3errorContainer: "#4a2520",
        m3onErrorContainer: "#d98878",
        m3primaryFixed: "#7a8a5a",
        m3primaryFixedDim: "#5e6b45",
        m3onPrimaryFixed: "#1b1815",
        m3onPrimaryFixedVariant: "#2b2622",
        m3secondaryFixed: "#c47a3a",
        m3secondaryFixedDim: "#9a6030",
        m3onSecondaryFixed: "#1b1815",
        m3onSecondaryFixedVariant: "#2b2622",
        m3tertiaryFixed: "#5a6d7a",
        m3tertiaryFixedDim: "#485860",
        m3onTertiaryFixed: "#ebe0d1",
        m3onTertiaryFixedVariant: "#2b2622",
        m3success: "#93a56b",
        m3onSuccess: "#1b1815",
        m3successContainer: "#3d4530",
        m3onSuccessContainer: "#a4b67d"
    })

    // Fields of the Shire (Light) — Parchment and morning meadow
    readonly property var fieldsOfTheShireLightColors: ({
        darkmode: false,
        m3background: "#f9f5eb",
        m3onBackground: "#2c2820",
        m3surface: "#f9f5eb",
        m3surfaceDim: "#ece8de",
        m3surfaceBright: "#f9f5eb",
        m3surfaceContainerLowest: "#ffffff",
        m3surfaceContainerLow: "#f5f1e7",
        m3surfaceContainer: "#efebe1",
        m3surfaceContainerHigh: "#e9e5db",
        m3surfaceContainerHighest: "#e3dfd5",
        m3onSurface: "#2c2820",
        m3surfaceVariant: "#e3dfd5",
        m3onSurfaceVariant: "#5a5348",
        m3inverseSurface: "#2c2820",
        m3inverseOnSurface: "#f9f5eb",
        m3outline: "#8a7e70",
        m3outlineVariant: "#c8c0b4",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#5a6b3a",
        m3primary: "#5a6b3a",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#d8e8b8",
        m3onPrimaryContainer: "#3d4a28",
        m3inversePrimary: "#93a56b",
        m3secondary: "#8a5a2a",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#f0d0a8",
        m3onSecondaryContainer: "#5c3a1a",
        m3tertiary: "#3a5a6a",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#b8d8e8",
        m3onTertiaryContainer: "#1a3a4a",
        m3error: "#9a3528",
        m3onError: "#ffffff",
        m3errorContainer: "#f0c8c0",
        m3onErrorContainer: "#5a2018",
        m3primaryFixed: "#5a6b3a",
        m3primaryFixedDim: "#485830",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#e9e5db",
        m3secondaryFixed: "#8a5a2a",
        m3secondaryFixedDim: "#704820",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#e9e5db",
        m3tertiaryFixed: "#3a5a6a",
        m3tertiaryFixedDim: "#2a4858",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#e9e5db",
        m3success: "#5a6b3a",
        m3onSuccess: "#ffffff",
        m3successContainer: "#d8e8b8",
        m3onSuccessContainer: "#3d4a28"
    })

    // Vitesse Dark — by Anthony Fu (antfu/vscode-theme-vitesse)
    // Refined minimal aesthetic with green accent on near-black
    readonly property var vitesseDarkColors: ({
        darkmode: true,
        m3background: "#121212",
        m3onBackground: "#dbd7ca",
        m3surface: "#121212",
        m3surfaceDim: "#0e0e0e",
        m3surfaceBright: "#222222",
        m3surfaceContainerLowest: "#0e0e0e",
        m3surfaceContainerLow: "#161616",
        m3surfaceContainer: "#1e1e1e",
        m3surfaceContainerHigh: "#252525",
        m3surfaceContainerHighest: "#2c2c2c",
        m3onSurface: "#dbd7ca",
        m3surfaceVariant: "#2c2c2c",
        m3onSurfaceVariant: "#a0a0a0",
        m3inverseSurface: "#dbd7ca",
        m3inverseOnSurface: "#121212",
        m3outline: "#494b43",
        m3outlineVariant: "#333333",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#4d9375",
        m3primary: "#4d9375",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#264a3b",
        m3onPrimaryContainer: "#80c4a4",
        m3inversePrimary: "#1c6b48",
        m3secondary: "#6394bf",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#2e4860",
        m3onSecondaryContainer: "#99c4e5",
        m3tertiary: "#d9739f",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#6b3a50",
        m3onTertiaryContainer: "#f0a8c8",
        m3error: "#cb7676",
        m3onError: "#ffffff",
        m3errorContainer: "#5c3030",
        m3onErrorContainer: "#e8a8a8",
        m3primaryFixed: "#4d9375",
        m3primaryFixedDim: "#3a7058",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#1e1e1e",
        m3secondaryFixed: "#6394bf",
        m3secondaryFixedDim: "#4a7198",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#1e1e1e",
        m3tertiaryFixed: "#d9739f",
        m3tertiaryFixedDim: "#a85878",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#1e1e1e",
        m3success: "#4d9375",
        m3onSuccess: "#ffffff",
        m3successContainer: "#264a3b",
        m3onSuccessContainer: "#80c4a4",
        // Exact Vitesse terminal palette (bypasses harmonized generation)
        term0:  "#121212",
        term1:  "#cb7676",
        term2:  "#4d9375",
        term3:  "#e6cc77",
        term4:  "#6394bf",
        term5:  "#d9739f",
        term6:  "#5eaab5",
        term7:  "#dbd7ca",
        term8:  "#393a34",
        term9:  "#cb7676",
        term10: "#4d9375",
        term11: "#e6cc77",
        term12: "#6394bf",
        term13: "#d9739f",
        term14: "#5eaab5",
        term15: "#ffffff"
    })

    // Vitesse Light — by Anthony Fu (antfu/vscode-theme-vitesse)
    // Clean warm minimal with deep green accent on white
    readonly property var vitesseLightColors: ({
        darkmode: false,
        m3background: "#ffffff",
        m3onBackground: "#393a34",
        m3surface: "#ffffff",
        m3surfaceDim: "#f0f0f0",
        m3surfaceBright: "#ffffff",
        m3surfaceContainerLowest: "#ffffff",
        m3surfaceContainerLow: "#f7f7f7",
        m3surfaceContainer: "#f0f0f0",
        m3surfaceContainerHigh: "#e8e8e8",
        m3surfaceContainerHighest: "#e0e0e0",
        m3onSurface: "#393a34",
        m3surfaceVariant: "#e0e0e0",
        m3onSurfaceVariant: "#6e6e6e",
        m3inverseSurface: "#393a34",
        m3inverseOnSurface: "#ffffff",
        m3outline: "#999999",
        m3outlineVariant: "#c8c8c8",
        m3shadow: "#000000",
        m3scrim: "#000000",
        m3surfaceTint: "#1c6b48",
        m3primary: "#1c6b48",
        m3onPrimary: "#ffffff",
        m3primaryContainer: "#b8e8d0",
        m3onPrimaryContainer: "#0d3520",
        m3inversePrimary: "#4d9375",
        m3secondary: "#296aa3",
        m3onSecondary: "#ffffff",
        m3secondaryContainer: "#b0d4f0",
        m3onSecondaryContainer: "#143550",
        m3tertiary: "#a13865",
        m3onTertiary: "#ffffff",
        m3tertiaryContainer: "#f0c0d8",
        m3onTertiaryContainer: "#501c33",
        m3error: "#ab5959",
        m3onError: "#ffffff",
        m3errorContainer: "#f0c8c8",
        m3onErrorContainer: "#552c2c",
        m3primaryFixed: "#1c6b48",
        m3primaryFixedDim: "#155438",
        m3onPrimaryFixed: "#ffffff",
        m3onPrimaryFixedVariant: "#e8e8e8",
        m3secondaryFixed: "#296aa3",
        m3secondaryFixedDim: "#1f5480",
        m3onSecondaryFixed: "#ffffff",
        m3onSecondaryFixedVariant: "#e8e8e8",
        m3tertiaryFixed: "#a13865",
        m3tertiaryFixedDim: "#802d50",
        m3onTertiaryFixed: "#ffffff",
        m3onTertiaryFixedVariant: "#e8e8e8",
        m3success: "#1c6b48",
        m3onSuccess: "#ffffff",
        m3successContainer: "#b8e8d0",
        m3onSuccessContainer: "#0d3520",
        // Exact Vitesse Light terminal palette (bypasses harmonized generation)
        term0:  "#ffffff",
        term1:  "#ab5959",
        term2:  "#1e754f",
        term3:  "#bda437",
        term4:  "#296aa3",
        term5:  "#a13865",
        term6:  "#2993a3",
        term7:  "#dbd7ca",
        term8:  "#aaaaaa",
        term9:  "#ab5959",
        term10: "#1e754f",
        term11: "#bda437",
        term12: "#296aa3",
        term13: "#a13865",
        term14: "#2993a3",
        term15: "#393a34"
    })

    function getPreset(id) {
        for (let i = 0; i < presets.length; i++) {
            if (presets[i].id === id) return presets[i];
        }
        return presets[0];
    }

    function softenColors(colorsObj) {
        if (!colorsObj) return colorsObj;
        var newColors = {};
        var keys = Object.keys(colorsObj);
        for (var i = 0; i < keys.length; i++) {
            var key = keys[i];
            var val = colorsObj[key];
            // Check if property is a color string
            if (typeof val === "string" && val.startsWith("#")) {
                var c = Qt.color(val);
                // Only soften if it has significant saturation (>5%)
                if (c.hslSaturation > 0.05) {
                    var newSat = c.hslSaturation * 0.60;
                    val = Qt.hsla(c.hslHue, newSat, c.hslLightness, c.a).toString();
                }
            }
            newColors[key] = val;
        }
        return newColors;
    }

    function applyPreset(id, applyExternal = true, skipColorsJson = false) {
        console.log("[ThemePresets] Applying preset:", id);
        const preset = getPreset(id);
        if (!preset.colors) {
            console.log("[ThemePresets] Preset has no colors (auto theme)");
            return false;
        }
        console.log("[ThemePresets] Applying colors to Appearance.m3colors");
        
        var cSource = preset.colors === "custom" ? (Config.options?.appearance?.customTheme ?? {}) : preset.colors;
        
        // Soften colors for built-in presets (not custom) if enabled in config
        var shouldSoften = (Config.options?.appearance?.softenColors ?? true) && (id !== "custom");
        var c = shouldSoften ? softenColors(cSource) : cSource;

        const m3 = Appearance.m3colors;
        
        m3.darkmode = c.darkmode;
        m3.transparent = c.transparent ?? false;
        m3.m3background = c.m3background;
        m3.m3onBackground = c.m3onBackground;
        m3.m3surface = c.m3surface;
        m3.m3surfaceDim = c.m3surfaceDim;
        m3.m3surfaceBright = c.m3surfaceBright;
        m3.m3surfaceContainerLowest = c.m3surfaceContainerLowest;
        m3.m3surfaceContainerLow = c.m3surfaceContainerLow;
        m3.m3surfaceContainer = c.m3surfaceContainer;
        m3.m3surfaceContainerHigh = c.m3surfaceContainerHigh;
        m3.m3surfaceContainerHighest = c.m3surfaceContainerHighest;
        m3.m3onSurface = c.m3onSurface;
        m3.m3surfaceVariant = c.m3surfaceVariant;
        m3.m3onSurfaceVariant = c.m3onSurfaceVariant;
        m3.m3inverseSurface = c.m3inverseSurface;
        m3.m3inverseOnSurface = c.m3inverseOnSurface;
        m3.m3outline = c.m3outline;
        m3.m3outlineVariant = c.m3outlineVariant;
        m3.m3shadow = c.m3shadow;
        m3.m3scrim = c.m3scrim;
        m3.m3surfaceTint = c.m3surfaceTint;
        m3.m3primary = c.m3primary;
        m3.m3onPrimary = c.m3onPrimary;
        m3.m3primaryContainer = c.m3primaryContainer;
        m3.m3onPrimaryContainer = c.m3onPrimaryContainer;
        m3.m3inversePrimary = c.m3inversePrimary;
        m3.m3secondary = c.m3secondary;
        m3.m3onSecondary = c.m3onSecondary;
        m3.m3secondaryContainer = c.m3secondaryContainer;
        m3.m3onSecondaryContainer = c.m3onSecondaryContainer;
        m3.m3tertiary = c.m3tertiary;
        m3.m3onTertiary = c.m3onTertiary;
        m3.m3tertiaryContainer = c.m3tertiaryContainer;
        m3.m3onTertiaryContainer = c.m3onTertiaryContainer;
        m3.m3error = c.m3error;
        m3.m3onError = c.m3onError;
        m3.m3errorContainer = c.m3errorContainer;
        m3.m3onErrorContainer = c.m3onErrorContainer;
        m3.m3primaryFixed = c.m3primaryFixed;
        m3.m3primaryFixedDim = c.m3primaryFixedDim;
        m3.m3onPrimaryFixed = c.m3onPrimaryFixed;
        m3.m3onPrimaryFixedVariant = c.m3onPrimaryFixedVariant;
        m3.m3secondaryFixed = c.m3secondaryFixed;
        m3.m3secondaryFixedDim = c.m3secondaryFixedDim;
        m3.m3onSecondaryFixed = c.m3onSecondaryFixed;
        m3.m3onSecondaryFixedVariant = c.m3onSecondaryFixedVariant;
        m3.m3tertiaryFixed = c.m3tertiaryFixed;
        m3.m3tertiaryFixedDim = c.m3tertiaryFixedDim;
        m3.m3onTertiaryFixed = c.m3onTertiaryFixed;
        m3.m3onTertiaryFixedVariant = c.m3onTertiaryFixedVariant;
        m3.m3success = c.m3success;
        m3.m3onSuccess = c.m3onSuccess;
        m3.m3successContainer = c.m3successContainer;
        m3.m3onSuccessContainer = c.m3onSuccessContainer;

        if (!skipColorsJson) {
            generateColorsJson(c);
        }
        
        if (applyExternal) {
            applyExternalThemes(c);
        }
        
        return true;
    }
    
    function applyExternalThemes(c) {
        const enableAppsAndShell = Config.options?.appearance?.wallpaperTheming?.enableAppsAndShell ?? true;
        const enableVesktop = Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true;
        const enableTerminal = Config.options?.appearance?.wallpaperTheming?.enableTerminal ?? true;
        
        // Apply GTK theme (if enabled)
        if (enableAppsAndShell) {
            Qt.callLater(() => {
                const script = Directories.scriptsPath + "/colors/apply-gtk-theme.sh";
                Quickshell.execDetached([
                    script,
                    c.m3background,
                    c.m3onBackground,
                    c.m3primary,
                    c.m3onPrimary,
                    c.m3surface,
                    c.m3surfaceDim
                ]);
            });
        }
        
        // Apply terminal colors (if enabled)
        if (enableTerminal) {
            applyTerminalColors(c);
        }
    }
    
    function applyTerminalColors(c) {
        // Generate material_colors.scss from preset colors for terminal theming
        const scssContent = generateScssFromColors(c);
        const scssPath = Directories.generatedMaterialScssPath;
        
        // Write scss file
        presetScssFileView.path = Qt.resolvedUrl(scssPath);
        presetScssFileView.setText(scssContent);
        
        // Run applycolor.sh to apply terminal colors
        Qt.callLater(() => {
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptsPath + "/colors/applycolor.sh"
            ]);
        });
    }
    
    function generateScssFromColors(c) {
        // Generate SCSS format matching generate_colors_material.py output
        let scss = `$darkmode: ${c.darkmode};\n`;
        scss += `$transparent: ${c.transparent ?? false};\n`;
        
        // Map m3* properties to scss variables
        const colorMap = {
            "background": c.m3background,
            "onBackground": c.m3onBackground,
            "surface": c.m3surface,
            "surfaceDim": c.m3surfaceDim,
            "surfaceBright": c.m3surfaceBright,
            "surfaceContainerLowest": c.m3surfaceContainerLowest,
            "surfaceContainerLow": c.m3surfaceContainerLow,
            "surfaceContainer": c.m3surfaceContainer,
            "surfaceContainerHigh": c.m3surfaceContainerHigh,
            "surfaceContainerHighest": c.m3surfaceContainerHighest,
            "onSurface": c.m3onSurface,
            "surfaceVariant": c.m3surfaceVariant,
            "onSurfaceVariant": c.m3onSurfaceVariant,
            "inverseSurface": c.m3inverseSurface,
            "inverseOnSurface": c.m3inverseOnSurface,
            "outline": c.m3outline,
            "outlineVariant": c.m3outlineVariant,
            "shadow": c.m3shadow,
            "scrim": c.m3scrim,
            "surfaceTint": c.m3surfaceTint,
            "primary": c.m3primary,
            "onPrimary": c.m3onPrimary,
            "primaryContainer": c.m3primaryContainer,
            "onPrimaryContainer": c.m3onPrimaryContainer,
            "primaryFixed": c.m3primaryFixed,
            "primaryFixedDim": c.m3primaryFixedDim,
            "onPrimaryFixed": c.m3onPrimaryFixed,
            "onPrimaryFixedVariant": c.m3onPrimaryFixedVariant,
            "inversePrimary": c.m3inversePrimary,
            "secondary": c.m3secondary,
            "onSecondary": c.m3onSecondary,
            "secondaryContainer": c.m3secondaryContainer,
            "onSecondaryContainer": c.m3onSecondaryContainer,
            "secondaryFixed": c.m3secondaryFixed,
            "secondaryFixedDim": c.m3secondaryFixedDim,
            "onSecondaryFixed": c.m3onSecondaryFixed,
            "onSecondaryFixedVariant": c.m3onSecondaryFixedVariant,
            "tertiary": c.m3tertiary,
            "onTertiary": c.m3onTertiary,
            "tertiaryContainer": c.m3tertiaryContainer,
            "onTertiaryContainer": c.m3onTertiaryContainer,
            "tertiaryFixed": c.m3tertiaryFixed,
            "tertiaryFixedDim": c.m3tertiaryFixedDim,
            "onTertiaryFixed": c.m3onTertiaryFixed,
            "onTertiaryFixedVariant": c.m3onTertiaryFixedVariant,
            "error": c.m3error,
            "onError": c.m3onError,
            "errorContainer": c.m3errorContainer,
            "onErrorContainer": c.m3onErrorContainer,
            "success": c.m3success,
            "onSuccess": c.m3onSuccess,
            "successContainer": c.m3successContainer,
            "onSuccessContainer": c.m3onSuccessContainer,
        };
        
        for (const [key, value] of Object.entries(colorMap)) {
            if (value) scss += `$${key}: ${value};\n`;
        }
        
        // Generate terminal colors
        // If the color object provides explicit terminal colors (term1-term14),
        // use them directly — this allows preset themes to ship their exact
        // terminal palette instead of relying on harmonized generation.
        const hasExplicitTermColors = c.term1 !== undefined;
        const isDark = c.darkmode;

        // Helper to convert Qt color to hex
        function colorToHex(col) {
            const r = Math.round(col.r * 255);
            const g = Math.round(col.g * 255);
            const b = Math.round(col.b * 255);
            return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase();
        }

        // Background colors - directly from theme (use surfaceContainerLow for slightly lighter bg)
        const bgColor = Qt.color(c.m3surfaceContainerLow ?? c.m3background);
        const term0 = c.term0 ?? colorToHex(bgColor);
        
        // Foreground colors - from theme
        const fgColor = Qt.color(c.m3onBackground);
        const term15 = c.term15 ?? colorToHex(fgColor);
        
        // Gray tones - from theme's surface variant and outline
        const term7 = c.term7 ?? colorToHex(Qt.color(c.m3onSurfaceVariant));
        const term8 = c.term8 ?? colorToHex(Qt.color(c.m3outline));

        let term1, term2, term3, term4, term5, term6;
        let term9, term10, term11, term12, term13, term14;

        if (hasExplicitTermColors) {
            // Preset provides exact terminal colors — use as-is
            term1 = c.term1;   term9  = c.term9;
            term2 = c.term2;   term10 = c.term10;
            term3 = c.term3;   term11 = c.term11;
            term4 = c.term4;   term12 = c.term12;
            term5 = c.term5;   term13 = c.term13;
            term6 = c.term6;   term14 = c.term14;
        } else {
            // Harmonized generation from fixed semantic hues + theme primary
            const termAdj = Config.options?.appearance?.wallpaperTheming?.terminalColorAdjustments ?? {};
            const userSaturation = termAdj.saturation ?? 0.65;
            const userBrightness = termAdj.brightness ?? 0.60;
            const userHarmony = termAdj.harmony ?? 0.40;

            const primaryColor = Qt.color(c.m3primary);
            const primaryHue = primaryColor.hslHue;
            const primarySat = primaryColor.hslSaturation;

            // Helper to create harmonized color with fixed semantic hue
            // Harmony is intentionally gentle (~12° max shift) to preserve
            // semantic color identity while adding subtle theme warmth.
            function harmonizedColor(targetHue, saturation, lightness, harmony) {
                let finalHue = targetHue;
                if (primarySat > 0.08 && harmony > 0) {
                    let hueDiff = primaryHue - targetHue;
                    if (hueDiff > 0.5) hueDiff -= 1;
                    if (hueDiff < -0.5) hueDiff += 1;
                    const maxShift = 0.033;
                    const rawShift = hueDiff * harmony * 0.3;
                    const clampedShift = Math.max(-maxShift, Math.min(maxShift, rawShift));
                    finalHue = (targetHue + clampedShift + 1) % 1;
                }
                const clampedSat = Math.max(0.25, Math.min(0.85, saturation));
                const clampedLight = Math.max(0.25, Math.min(0.75, lightness));
                const col = Qt.hsla(finalHue, clampedSat, clampedLight, 1.0);
                return colorToHex(col);
            }

            // Calculate lightness values based on user brightness setting
            const normalLight = isDark ? (0.42 + userBrightness * 0.35) : (0.58 - userBrightness * 0.30);
            const brightLight = isDark ? (0.55 + userBrightness * 0.30) : (0.48 - userBrightness * 0.30);

            // Saturation values - boost for vivid terminal colors
            const normalSat = Math.min(0.85, userSaturation * 1.3);
            const brightSat = Math.min(0.90, userSaturation * 1.3 + 0.05);

            // Red
            term1 = harmonizedColor(0.98, normalSat, normalLight, userHarmony);
            term9 = harmonizedColor(0.98, brightSat, brightLight, userHarmony);
            // Green
            term2 = harmonizedColor(0.36, normalSat, normalLight, userHarmony);
            term10 = harmonizedColor(0.36, brightSat, brightLight, userHarmony);
            // Yellow
            term3 = harmonizedColor(0.12, normalSat + 0.10, normalLight, userHarmony);
            term11 = harmonizedColor(0.12, brightSat + 0.10, brightLight, userHarmony);
            // Blue
            term4 = harmonizedColor(0.58, normalSat, normalLight, userHarmony);
            term12 = harmonizedColor(0.58, brightSat, brightLight, userHarmony);
            // Magenta
            term5 = harmonizedColor(0.85, normalSat, normalLight, userHarmony);
            term13 = harmonizedColor(0.85, brightSat, brightLight, userHarmony);
            // Cyan
            term6 = harmonizedColor(0.48, normalSat, normalLight, userHarmony);
            term14 = harmonizedColor(0.48, brightSat, brightLight, userHarmony);
        }
        
        scss += `$term0: ${term0};\n`;
        scss += `$term1: ${term1};\n`;
        scss += `$term2: ${term2};\n`;
        scss += `$term3: ${term3};\n`;
        scss += `$term4: ${term4};\n`;
        scss += `$term5: ${term5};\n`;
        scss += `$term6: ${term6};\n`;
        scss += `$term7: ${term7};\n`;
        scss += `$term8: ${term8};\n`;
        scss += `$term9: ${term9};\n`;
        scss += `$term10: ${term10};\n`;
        scss += `$term11: ${term11};\n`;
        scss += `$term12: ${term12};\n`;
        scss += `$term13: ${term13};\n`;
        scss += `$term14: ${term14};\n`;
        scss += `$term15: ${term15};\n`;
        
        return scss;
    }
    
    FileView {
        id: presetScssFileView
    }
    
    function applyGtkTheme(c) {
        // DEPRECATED: Use applyExternalThemes instead
        applyExternalThemes(c);
    }

    function generateColorsJsonObject(c) {
        return {
            primary: c.m3primary,
            on_primary: c.m3onPrimary,
            primary_container: c.m3primaryContainer,
            on_primary_container: c.m3onPrimaryContainer,
            primary_fixed: c.m3primaryFixed,
            primary_fixed_dim: c.m3primaryFixedDim,
            on_primary_fixed: c.m3onPrimaryFixed,
            on_primary_fixed_variant: c.m3onPrimaryFixedVariant,
            secondary: c.m3secondary,
            on_secondary: c.m3onSecondary,
            secondary_container: c.m3secondaryContainer,
            on_secondary_container: c.m3onSecondaryContainer,
            secondary_fixed: c.m3secondaryFixed,
            secondary_fixed_dim: c.m3secondaryFixedDim,
            on_secondary_fixed: c.m3onSecondaryFixed,
            on_secondary_fixed_variant: c.m3onSecondaryFixedVariant,
            tertiary: c.m3tertiary,
            on_tertiary: c.m3onTertiary,
            tertiary_container: c.m3tertiaryContainer,
            on_tertiary_container: c.m3onTertiaryContainer,
            tertiary_fixed: c.m3tertiaryFixed,
            tertiary_fixed_dim: c.m3tertiaryFixedDim,
            on_tertiary_fixed: c.m3onTertiaryFixed,
            on_tertiary_fixed_variant: c.m3onTertiaryFixedVariant,
            error: c.m3error,
            on_error: c.m3onError,
            error_container: c.m3errorContainer,
            on_error_container: c.m3onErrorContainer,
            background: c.m3background,
            on_background: c.m3onBackground,
            surface: c.m3surface,
            on_surface: c.m3onSurface,
            surface_dim: c.m3surfaceDim,
            surface_bright: c.m3surfaceBright,
            surface_variant: c.m3surfaceVariant,
            on_surface_variant: c.m3onSurfaceVariant,
            surface_container_lowest: c.m3surfaceContainerLowest,
            surface_container_low: c.m3surfaceContainerLow,
            surface_container: c.m3surfaceContainer,
            surface_container_high: c.m3surfaceContainerHigh,
            surface_container_highest: c.m3surfaceContainerHighest,
            outline: c.m3outline,
            outline_variant: c.m3outlineVariant,
            inverse_surface: c.m3inverseSurface,
            inverse_on_surface: c.m3inverseOnSurface,
            inverse_primary: c.m3inversePrimary,
            shadow: c.m3shadow,
            scrim: c.m3scrim,
            surface_tint: c.m3surfaceTint,
            success: c.m3success,
            on_success: c.m3onSuccess,
            success_container: c.m3successContainer,
            on_success_container: c.m3onSuccessContainer
        };
    }
    
    function generateColorsJson(c) {
        console.log("[ThemePresets] Generating colors.json for preset theme");
        const colorsJson = generateColorsJsonObject(c);
        const terminalJson = buildTerminalJson(c);
        Object.assign(colorsJson, terminalJson)

        const outputPath = Directories.generatedMaterialThemePath;
        const jsonStr = JSON.stringify(colorsJson, null, 2);

        colorsJsonFileView.path = Qt.resolvedUrl(outputPath)
        colorsJsonFileView.setText(jsonStr)
        writeGeneratedThemeContracts(c)
        if ((Config.options?.appearance?.wallpaperTheming?.enableVesktop ?? true) !== false) {
            console.log("[ThemePresets] Triggering Vesktop theme generation wrapper")
            Quickshell.execDetached([
                "/usr/bin/bash",
                Directories.scriptsPath + "/colors/system24_palette.sh"
            ])
        }
        console.log("[ThemePresets] colors.json written to:", outputPath);
    }

    FileView {
        id: colorsJsonFileView
    }

    FileView {
        id: paletteJsonFileView
    }

    FileView {
        id: terminalJsonFileView
    }

    FileView {
        id: themeMetaFileView
    }

    function buildTerminalJson(c) {
        const scss = generateScssFromColors(c);
        const terminalJson = {};
        const regex = /^\$(term\d+):\s*(#[0-9A-Fa-f]{6});$/gm;
        let match;
        while ((match = regex.exec(scss)) !== null) {
            terminalJson[match[1]] = match[2];
        }
        return terminalJson;
    }

    function buildThemeMeta(c) {
        return {
            source: "preset",
            preset: Config.options?.appearance?.theme ?? null,
            mode: c.darkmode ? "dark" : "light",
            scheme: "preset",
            transparent: c.transparent ?? false,
            term_source: c.term1 !== undefined ? "preset-explicit" : "harmonized",
            generated_by: "ThemePresets.qml"
        };
    }

    function writeGeneratedThemeContracts(c) {
        paletteJsonFileView.path = Qt.resolvedUrl(Directories.generatedPalettePath)
        paletteJsonFileView.setText(JSON.stringify(generateColorsJsonObject(c), null, 2))

        terminalJsonFileView.path = Qt.resolvedUrl(Directories.generatedTerminalPalettePath)
        terminalJsonFileView.setText(JSON.stringify(buildTerminalJson(c), null, 2))

        themeMetaFileView.path = Qt.resolvedUrl(Directories.generatedThemeMetaPath)
        themeMetaFileView.setText(JSON.stringify(buildThemeMeta(c), null, 2))
    }

    // ========== Hover Preview System ==========
    property var _previewBackup: null
    property bool _isPreviewing: false

    function captureCurrentColors() {
        const m3 = Appearance.m3colors;
        return {
            darkmode: m3.darkmode,
            transparent: m3.transparent,
            m3background: m3.m3background,
            m3onBackground: m3.m3onBackground,
            m3surface: m3.m3surface,
            m3surfaceDim: m3.m3surfaceDim,
            m3surfaceBright: m3.m3surfaceBright,
            m3surfaceContainerLowest: m3.m3surfaceContainerLowest,
            m3surfaceContainerLow: m3.m3surfaceContainerLow,
            m3surfaceContainer: m3.m3surfaceContainer,
            m3surfaceContainerHigh: m3.m3surfaceContainerHigh,
            m3surfaceContainerHighest: m3.m3surfaceContainerHighest,
            m3onSurface: m3.m3onSurface,
            m3surfaceVariant: m3.m3surfaceVariant,
            m3onSurfaceVariant: m3.m3onSurfaceVariant,
            m3inverseSurface: m3.m3inverseSurface,
            m3inverseOnSurface: m3.m3inverseOnSurface,
            m3outline: m3.m3outline,
            m3outlineVariant: m3.m3outlineVariant,
            m3shadow: m3.m3shadow,
            m3scrim: m3.m3scrim,
            m3surfaceTint: m3.m3surfaceTint,
            m3primary: m3.m3primary,
            m3onPrimary: m3.m3onPrimary,
            m3primaryContainer: m3.m3primaryContainer,
            m3onPrimaryContainer: m3.m3onPrimaryContainer,
            m3inversePrimary: m3.m3inversePrimary,
            m3secondary: m3.m3secondary,
            m3onSecondary: m3.m3onSecondary,
            m3secondaryContainer: m3.m3secondaryContainer,
            m3onSecondaryContainer: m3.m3onSecondaryContainer,
            m3tertiary: m3.m3tertiary,
            m3onTertiary: m3.m3onTertiary,
            m3tertiaryContainer: m3.m3tertiaryContainer,
            m3onTertiaryContainer: m3.m3onTertiaryContainer,
            m3error: m3.m3error,
            m3onError: m3.m3onError,
            m3errorContainer: m3.m3errorContainer,
            m3onErrorContainer: m3.m3onErrorContainer,
            m3primaryFixed: m3.m3primaryFixed,
            m3primaryFixedDim: m3.m3primaryFixedDim,
            m3onPrimaryFixed: m3.m3onPrimaryFixed,
            m3onPrimaryFixedVariant: m3.m3onPrimaryFixedVariant,
            m3secondaryFixed: m3.m3secondaryFixed,
            m3secondaryFixedDim: m3.m3secondaryFixedDim,
            m3onSecondaryFixed: m3.m3onSecondaryFixed,
            m3onSecondaryFixedVariant: m3.m3onSecondaryFixedVariant,
            m3tertiaryFixed: m3.m3tertiaryFixed,
            m3tertiaryFixedDim: m3.m3tertiaryFixedDim,
            m3onTertiaryFixed: m3.m3onTertiaryFixed,
            m3onTertiaryFixedVariant: m3.m3onTertiaryFixedVariant,
            m3success: m3.m3success,
            m3onSuccess: m3.m3onSuccess,
            m3successContainer: m3.m3successContainer,
            m3onSuccessContainer: m3.m3onSuccessContainer
        };
    }

    function previewPreset(id) {
        if (!id || id === "auto") return;
        
        const preset = getPreset(id);
        if (!preset?.colors) return;
        
        // Capture current colors if not already previewing
        if (!_isPreviewing) {
            _previewBackup = captureCurrentColors();
            _isPreviewing = true;
        }
        
        // Apply preview (no external apps)
        var cSource = preset.colors === "custom" ? Config.options?.appearance?.customTheme : preset.colors;
        var shouldSoften = (Config.options?.appearance?.softenColors ?? true) && (id !== "custom");
        var c = shouldSoften ? softenColors(cSource) : cSource;
        
        applyColorsToAppearance(c);
    }

    function restoreFromPreview() {
        if (!_isPreviewing || !_previewBackup) return;
        
        applyColorsToAppearance(_previewBackup);
        _previewBackup = null;
        _isPreviewing = false;
    }

    function applyColorsToAppearance(c) {
        const m3 = Appearance.m3colors;
        m3.darkmode = c.darkmode;
        m3.transparent = c.transparent ?? false;
        m3.m3background = c.m3background;
        m3.m3onBackground = c.m3onBackground;
        m3.m3surface = c.m3surface;
        m3.m3surfaceDim = c.m3surfaceDim;
        m3.m3surfaceBright = c.m3surfaceBright;
        m3.m3surfaceContainerLowest = c.m3surfaceContainerLowest;
        m3.m3surfaceContainerLow = c.m3surfaceContainerLow;
        m3.m3surfaceContainer = c.m3surfaceContainer;
        m3.m3surfaceContainerHigh = c.m3surfaceContainerHigh;
        m3.m3surfaceContainerHighest = c.m3surfaceContainerHighest;
        m3.m3onSurface = c.m3onSurface;
        m3.m3surfaceVariant = c.m3surfaceVariant;
        m3.m3onSurfaceVariant = c.m3onSurfaceVariant;
        m3.m3inverseSurface = c.m3inverseSurface;
        m3.m3inverseOnSurface = c.m3inverseOnSurface;
        m3.m3outline = c.m3outline;
        m3.m3outlineVariant = c.m3outlineVariant;
        m3.m3shadow = c.m3shadow;
        m3.m3scrim = c.m3scrim;
        m3.m3surfaceTint = c.m3surfaceTint;
        m3.m3primary = c.m3primary;
        m3.m3onPrimary = c.m3onPrimary;
        m3.m3primaryContainer = c.m3primaryContainer;
        m3.m3onPrimaryContainer = c.m3onPrimaryContainer;
        m3.m3inversePrimary = c.m3inversePrimary;
        m3.m3secondary = c.m3secondary;
        m3.m3onSecondary = c.m3onSecondary;
        m3.m3secondaryContainer = c.m3secondaryContainer;
        m3.m3onSecondaryContainer = c.m3onSecondaryContainer;
        m3.m3tertiary = c.m3tertiary;
        m3.m3onTertiary = c.m3onTertiary;
        m3.m3tertiaryContainer = c.m3tertiaryContainer;
        m3.m3onTertiaryContainer = c.m3onTertiaryContainer;
        m3.m3error = c.m3error;
        m3.m3onError = c.m3onError;
        m3.m3errorContainer = c.m3errorContainer;
        m3.m3onErrorContainer = c.m3onErrorContainer;
        m3.m3primaryFixed = c.m3primaryFixed;
        m3.m3primaryFixedDim = c.m3primaryFixedDim;
        m3.m3onPrimaryFixed = c.m3onPrimaryFixed;
        m3.m3onPrimaryFixedVariant = c.m3onPrimaryFixedVariant;
        m3.m3secondaryFixed = c.m3secondaryFixed;
        m3.m3secondaryFixedDim = c.m3secondaryFixedDim;
        m3.m3onSecondaryFixed = c.m3onSecondaryFixed;
        m3.m3onSecondaryFixedVariant = c.m3onSecondaryFixedVariant;
        m3.m3tertiaryFixed = c.m3tertiaryFixed;
        m3.m3tertiaryFixedDim = c.m3tertiaryFixedDim;
        m3.m3onTertiaryFixed = c.m3onTertiaryFixed;
        m3.m3onTertiaryFixedVariant = c.m3onTertiaryFixedVariant;
        m3.m3success = c.m3success;
        m3.m3onSuccess = c.m3onSuccess;
        m3.m3successContainer = c.m3successContainer;
        m3.m3onSuccessContainer = c.m3onSuccessContainer;
    }
}
