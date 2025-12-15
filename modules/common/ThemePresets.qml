pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.services

Singleton {
    id: root

    readonly property var presets: [
        {
            id: "auto",
            name: "Auto (Wallpaper)",
            description: "Colors generated from your wallpaper",
            icon: "wallpaper",
            colors: null
        },
        {
            id: "custom",
            name: "Custom",
            description: "Your personalized color palette",
            icon: "edit",
            colors: "custom"
        },
        {
            id: "angel",
            name: "Angel",
            description: "Celestial twilight with warm golden halos",
            icon: "brightness_7",
            colors: angelColors
        },
        {
            id: "angel-light",
            name: "Angel Light",
            description: "Ethereal dawn with warm cream tones",
            icon: "wb_twilight",
            colors: angelLightColors
        },
        {
            id: "catppuccin-mocha",
            name: "Catppuccin Mocha",
            description: "Pastel colors on dark backgrounds",
            icon: "palette",
            colors: catppuccinMochaColors
        },
        {
            id: "catppuccin-latte",
            name: "Catppuccin Latte",
            description: "Pastel colors on light backgrounds",
            icon: "palette",
            colors: catppuccinLatteColors
        },
        {
            id: "material-black",
            name: "Material Black",
            description: "Pure black with elegant muted accents",
            icon: "palette",
            colors: materialBlackColors
        },
        {
            id: "gruvbox-material",
            name: "Gruvbox Material",
            description: "Gruvbox with Material Design refinements",
            icon: "palette",
            colors: gruvboxMaterialColors
        },
        {
            id: "nord",
            name: "Nord",
            description: "Arctic blue-gray tones",
            icon: "palette",
            colors: nordColors
        },

        {
            id: "kanagawa",
            name: "Kanagawa",
            description: "Inspired by Katsushika Hokusai's Great Wave",
            icon: "tsunami",
            colors: kanagawaColors
        },
        {
            id: "kanagawa-dragon",
            name: "Kanagawa Dragon",
            description: "Darker variant with dragon ink tones",
            icon: "whatshot",
            colors: kanagawaDragonColors
        },
        {
            id: "samurai",
            name: "Samurai",
            description: "Deep crimson and steel inspired by bushido",
            icon: "swords",
            colors: samuraiColors
        },
        {
            id: "tokyo-night",
            name: "Tokyo Night",
            description: "Neon city lights on midnight blue",
            icon: "location_city",
            colors: tokyoNightColors
        },
        {
            id: "sakura",
            name: "Sakura",
            description: "Cherry blossom pink on soft cream",
            icon: "local_florist",
            colors: sakuraColors
        },
        {
            id: "zen-garden",
            name: "Zen Garden",
            description: "Tranquil moss greens and stone grays",
            icon: "spa",
            colors: zenGardenColors
        }
    ]

    // Angel - Signature theme for ii on Niri
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

    function getPreset(id) {
        for (let i = 0; i < presets.length; i++) {
            if (presets[i].id === id) return presets[i];
        }
        return presets[0];
    }

    function applyPreset(id, applyExternal = true) {
        console.log("[ThemePresets] Applying preset:", id);
        const preset = getPreset(id);
        if (!preset.colors) {
            console.log("[ThemePresets] Preset has no colors (auto theme)");
            return false;
        }
        console.log("[ThemePresets] Applying colors to Appearance.m3colors");
        
        const c = preset.colors === "custom" ? Config.options.appearance.customTheme : preset.colors;
        const m3 = Appearance.m3colors;
        
        m3.darkmode = c.darkmode;
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
        
        if (applyExternal) {
            // Apply to GTK apps (Nautilus, etc)
            applyGtkTheme(c);
        }
        
        return true;
    }
    
    function applyGtkTheme(c) {
        // First, generate colors.json for Vesktop theme generation
        generateColorsJson(c);
        
        // Small delay to ensure colors.json is written before apply-gtk-theme.sh reads it
        Qt.callLater(() => {
            const script = Directories.scriptPath + "/colors/apply-gtk-theme.sh";
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
    
    function generateColorsJson(c) {
        console.log("[ThemePresets] Generating colors.json for Vesktop");
        
        // Generate colors.json in the format expected by system24_palette.py
        const colorsJson = {
            primary: c.m3primary,
            on_primary: c.m3onPrimary,
            primary_container: c.m3primaryContainer,
            on_primary_container: c.m3onPrimaryContainer,
            secondary: c.m3secondary,
            on_secondary: c.m3onSecondary,
            secondary_container: c.m3secondaryContainer,
            on_secondary_container: c.m3onSecondaryContainer,
            tertiary: c.m3tertiary,
            on_tertiary: c.m3onTertiary,
            tertiary_container: c.m3tertiaryContainer,
            on_tertiary_container: c.m3onTertiaryContainer,
            error: c.m3error,
            on_error: c.m3onError,
            error_container: c.m3errorContainer,
            on_error_container: c.m3onErrorContainer,
            background: c.m3background,
            on_background: c.m3onBackground,
            surface: c.m3surface,
            on_surface: c.m3onSurface,
            surface_variant: c.m3surfaceVariant,
            on_surface_variant: c.m3onSurfaceVariant,
            surface_container: c.m3surfaceContainer,
            surface_container_low: c.m3surfaceContainerLow,
            surface_container_high: c.m3surfaceContainerHigh,
            surface_container_highest: c.m3surfaceContainerHighest,
            outline: c.m3outline,
            outline_variant: c.m3outlineVariant,
            inverse_surface: c.m3inverseSurface,
            inverse_on_surface: c.m3inverseOnSurface,
            inverse_primary: c.m3inversePrimary,
            shadow: c.m3shadow,
            scrim: c.m3scrim,
            surface_tint: c.m3surfaceTint
        };
        
        const outputPath = Directories.generatedMaterialThemePath;
        const jsonStr = JSON.stringify(colorsJson, null, 2);

        colorsJsonFileView.path = Qt.resolvedUrl(outputPath)
        colorsJsonFileView.setText(jsonStr)
        console.log("[ThemePresets] colors.json written to:", outputPath);
    }

    FileView {
        id: colorsJsonFileView
    }
}
