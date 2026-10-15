pragma Singleton

import QtQuick

QtObject {
    function _readPath(source, path: string): var {
        let cursor = source
        const parts = path.split(".")
        for (const part of parts) {
            if (cursor === null || cursor === undefined)
                return undefined
            cursor = cursor[part]
        }
        return cursor
    }

    function captureUserPreset(options): string {
        const defaults = defaultConfigUpdates()
        const snapshot = {}
        for (const fullPath in defaults) {
            const relative = fullPath.startsWith("orbit.") ? fullPath.slice(6) : fullPath
            const value = _readPath(options, relative)
            snapshot[fullPath] = value === undefined ? defaults[fullPath] : value
        }
        return JSON.stringify(snapshot)
    }

    function userPresetUpdates(serialized: string): var {
        if (!serialized || serialized.length === 0)
            return ({})
        try {
            const parsed = JSON.parse(serialized)
            const result = {}
            for (const key in parsed) {
                if (key.startsWith("orbit.") && key !== "orbit.userPresetJson")
                    result[key] = parsed[key]
            }
            return result
        } catch (error) {
            return ({})
        }
    }

    function profileUpdates(profile: string): var {
        const p = String(profile)
        const base = {
            "orbit.maxPanelWidthPercent": 92,
            "orbit.windowGap": 4,
            "orbit.canvasScrubNavigation": true,
            "orbit.canvasScrubThreshold": 96,
            "orbit.backdropBlurMode": "shell",
            "orbit.backdropBlurSaturation": 18,
            "orbit.backdropBlurTint": 28,
            "orbit.presentation.advanced": false,
            "orbit.navigationMotion.advanced": false,
            "orbit.orbital.geometry.advanced": false,
            "orbit.orbital.surface.outlineOpacityPercent": 72,
            "orbit.orbital.surface.frameInset": 5,
            "orbit.orbital.surface.shadowMode": "core",
            "orbit.orbital.surface.shadowOpacityPercent": 72,
            "orbit.orbital.surface.coreElevation": 2,
            "orbit.orbital.surface.satelliteElevation": 1,
            "orbit.orbital.geometry.edgePadding": 10,
            "orbit.orbital.geometry.horizonGap": 12,
            "orbit.orbital.geometry.horizonInset": 24,
            "orbit.orbital.geometry.horizonVerticalBase": 8,
            "orbit.orbital.geometry.horizonVerticalRange": 26,
            "orbit.orbital.geometry.galleryBaseGap": 34,
            "orbit.orbital.geometry.galleryRowGap": 14,
            "orbit.orbital.geometry.deckBaseGap": 26,
            "orbit.orbital.geometry.deckStep": 44,
            "orbit.orbital.geometry.deckLiftStep": 24,
            "orbit.orbital.geometry.atlasGap": 14,
            "orbit.orbital.geometry.atlasColumns": 3,
            "orbit.orbital.geometry.atlasCoreBoostPercent": 10,
            "orbit.orbital.geometry.coreContentMargin": 9,
            "orbit.orbital.geometry.satelliteContentMargin": 6,
            "orbit.orbital.showWorkspaceWallpaper": true,
            "orbit.orbital.satelliteClickAction": "select",
            "orbit.shelf.enable": true,
            "orbit.shelf.moduleSpacing": 7,
            "orbit.shelf.islandPadding": 8
        }
        if (p === "classic") {
            return Object.assign(base, {
                "orbit.stageMode": "stage",
                "orbit.workspaceCount": 3,
                "orbit.workspaceScalePercent": 28,
                "orbit.workspaceSpacing": 16,
                "orbit.windowGap": 4,
                "orbit.balancedGrid": true,
                "orbit.presentation.preset": "adaptive",
                "orbit.navigationMotion.preset": "fluid",
                "orbit.scrimDim": 32,
                "orbit.backdropBlurStrength": 68,
                "orbit.shelf.layout": "bar",
                "orbit.shelf.density": "compact",
                "orbit.shelf.labels": "auto"
            })
        }
        if (p === "spatial") {
            return Object.assign(base, {
                "orbit.stageMode": "orbital",
                "orbit.orbital.layout": "orbit",
                "orbit.orbital.visibleWorkspaces": 5,
                "orbit.orbital.coreSizePercent": 44,
                "orbit.orbital.satelliteSizePercent": 50,
                "orbit.orbital.horizontalSpreadPercent": 92,
                "orbit.orbital.verticalSpreadPercent": 70,
                "orbit.orbital.depthPercent": 30,
                "orbit.orbital.surface.style": "ricelin",
                "orbit.orbital.surface.outline": true,
                "orbit.orbital.surface.outlineWidth": 1,
                "orbit.orbital.surface.radiusPercent": 110,
                "orbit.orbital.workspaceLabelMode": "index",
                "orbit.presentation.preset": "float",
                "orbit.navigationMotion.preset": "cinematic",
                "orbit.scrimDim": 38,
                "orbit.backdropBlurStrength": 82,
                "orbit.orbital.workspaceWallpaperOpacity": 80,
                "orbit.shelf.layout": "islands",
                "orbit.shelf.islandStyle": "ricelin",
                "orbit.shelf.density": "compact",
                "orbit.shelf.labels": "auto"
            })
        }
        if (p === "minimal") {
            return Object.assign(base, {
                "orbit.stageMode": "orbital",
                "orbit.orbital.layout": "horizon",
                "orbit.orbital.visibleWorkspaces": 3,
                "orbit.orbital.coreSizePercent": 54,
                "orbit.orbital.satelliteSizePercent": 34,
                "orbit.orbital.horizontalSpreadPercent": 76,
                "orbit.orbital.verticalSpreadPercent": 48,
                "orbit.orbital.depthPercent": 10,
                "orbit.orbital.surface.style": "current",
                "orbit.orbital.surface.outline": false,
                "orbit.orbital.workspaceLabelMode": "off",
                "orbit.orbital.satellitePreviews": false,
                "orbit.presentation.preset": "soft",
                "orbit.navigationMotion.preset": "snappy",
                "orbit.scrimDim": 26,
                "orbit.backdropBlurStrength": 56,
                "orbit.shelf.layout": "minimal",
                "orbit.shelf.density": "compact",
                "orbit.shelf.labels": "icons"
            })
        }
        if (p === "cinematic") {
            return Object.assign(base, {
                "orbit.stageMode": "orbital",
                "orbit.orbital.layout": "gallery",
                "orbit.orbital.visibleWorkspaces": 5,
                "orbit.orbital.coreSizePercent": 46,
                "orbit.orbital.satelliteSizePercent": 52,
                "orbit.orbital.horizontalSpreadPercent": 90,
                "orbit.orbital.verticalSpreadPercent": 72,
                "orbit.orbital.depthPercent": 32,
                "orbit.orbital.surface.style": "ricelin",
                "orbit.orbital.surface.outline": true,
                "orbit.orbital.surface.outlineWidth": 2,
                "orbit.orbital.surface.outlineOpacityPercent": 78,
                "orbit.orbital.surface.radiusPercent": 120,
                "orbit.orbital.workspaceLabelMode": "full",
                "orbit.presentation.preset": "sweep",
                "orbit.navigationMotion.preset": "cinematic",
                "orbit.scrimDim": 46,
                "orbit.backdropBlurStrength": 90,
                "orbit.orbital.workspaceWallpaperOpacity": 86,
                "orbit.shelf.layout": "islands",
                "orbit.shelf.islandStyle": "ricelin",
                "orbit.shelf.density": "comfortable",
                "orbit.shelf.labels": "always"
            })
        }
        return Object.assign(base, {
            "orbit.stageMode": "orbital",
            "orbit.orbital.layout": "orbit",
            "orbit.orbital.visibleWorkspaces": 5,
            "orbit.orbital.coreSizePercent": 48,
            "orbit.orbital.satelliteSizePercent": 42,
            "orbit.orbital.horizontalSpreadPercent": 82,
            "orbit.orbital.verticalSpreadPercent": 58,
            "orbit.orbital.depthPercent": 18,
            "orbit.orbital.surface.style": "current",
            "orbit.orbital.surface.outline": true,
            "orbit.orbital.surface.outlineWidth": 1,
            "orbit.orbital.surface.radiusPercent": 100,
            "orbit.orbital.workspaceLabelMode": "index",
            "orbit.orbital.satellitePreviews": true,
            "orbit.presentation.preset": "adaptive",
            "orbit.navigationMotion.preset": "fluid",
            "orbit.scrimDim": 35,
            "orbit.backdropBlurStrength": 72,
            "orbit.orbital.workspaceWallpaperOpacity": 70,
            "orbit.shelf.layout": "islands",
            "orbit.shelf.islandStyle": "material",
            "orbit.shelf.density": "comfortable",
            "orbit.shelf.labels": "auto"
        })
    }

    function defaultConfigUpdates(): var {
        return {
            "orbit.enable": true,
            "orbit.stageMode": "stage",
            "orbit.backdropBlurMode": "shell",
            "orbit.backdropBlurStrength": 72,
            "orbit.backdropBlurSaturation": 18,
            "orbit.backdropBlurTint": 28,
            "orbit.hotCornerEnable": true,
            "orbit.hotCorner": "topRight",
            "orbit.hotCornerSize": 12,
            "orbit.hotCornerActivationDistance": 2,
            "orbit.hotCornerDwellMs": 0,
            "orbit.workspaceCount": 3,
            "orbit.workspaceScalePercent": 27,
            "orbit.maxPanelWidthPercent": 92,
            "orbit.workspaceSpacing": 18,
            "orbit.windowGap": 4,
            "orbit.windowLabels": "hover",
            "orbit.windowLabelIcons": true,
            "orbit.scrimDim": 35,
            "orbit.showWorkspaceNumbers": true,
            "orbit.balancedGrid": true,
            "orbit.closeOnSelect": true,
            "orbit.keyboardNavigation": true,
            "orbit.scrollNavigation": true,
            "orbit.scrollSteps": 1,
            "orbit.scrollSwitchWorkspace": true,
            "orbit.scrollWrapAround": false,
            "orbit.canvasScrubNavigation": true,
            "orbit.canvasScrubThreshold": 96,
            "orbit.studio.surfaceStyle": "ricelin",
            "orbit.studio.widthPercent": 26,
            "orbit.studio.density": "compact",
            "orbit.studio.showDescriptions": true,
            "orbit.presentation.preset": "adaptive",
            "orbit.presentation.advanced": false,
            "orbit.presentation.entryStyle": "cascade",
            "orbit.presentation.direction": "top",
            "orbit.presentation.distance": 92,
            "orbit.presentation.enterDurationMs": 300,
            "orbit.presentation.exitDurationMs": 220,
            "orbit.presentation.entryDelayMs": 64,
            "orbit.presentation.entryStaggerMs": 42,
            "orbit.presentation.shelfDelayMs": 72,
            "orbit.presentation.entryOpacityPercent": 0,
            "orbit.navigationMotion.preset": "fluid",
            "orbit.navigationMotion.advanced": false,
            "orbit.navigationMotion.durationMs": 320,
            "orbit.navigationMotion.easing": "smooth",
            "orbit.showTrail": true,
            "orbit.trailItems": 5,
            "orbit.showStash": true,
            "orbit.showNewWorkspaceDrop": true,
            "orbit.stashRestoreMode": "original",
            "orbit.orbital.layout": "orbit",
            "orbit.orbital.visibleWorkspaces": 5,
            "orbit.orbital.coreSizePercent": 48,
            "orbit.orbital.satelliteSizePercent": 42,
            "orbit.orbital.horizontalSpreadPercent": 82,
            "orbit.orbital.verticalSpreadPercent": 58,
            "orbit.orbital.depthPercent": 18,
            "orbit.orbital.surface.style": "current",
            "orbit.orbital.surface.outline": true,
            "orbit.orbital.surface.outlineWidth": 1,
            "orbit.orbital.surface.outlineOpacityPercent": 72,
            "orbit.orbital.surface.frameInset": 5,
            "orbit.orbital.surface.shadowMode": "core",
            "orbit.orbital.surface.shadowOpacityPercent": 72,
            "orbit.orbital.surface.coreElevation": 2,
            "orbit.orbital.surface.satelliteElevation": 1,
            "orbit.orbital.surface.radiusPercent": 100,
            "orbit.orbital.geometry.advanced": false,
            "orbit.orbital.geometry.edgePadding": 10,
            "orbit.orbital.geometry.horizonGap": 12,
            "orbit.orbital.geometry.horizonInset": 24,
            "orbit.orbital.geometry.horizonVerticalBase": 8,
            "orbit.orbital.geometry.horizonVerticalRange": 26,
            "orbit.orbital.geometry.galleryBaseGap": 34,
            "orbit.orbital.geometry.galleryRowGap": 14,
            "orbit.orbital.geometry.deckBaseGap": 26,
            "orbit.orbital.geometry.deckStep": 44,
            "orbit.orbital.geometry.deckLiftStep": 24,
            "orbit.orbital.geometry.atlasGap": 14,
            "orbit.orbital.geometry.atlasColumns": 3,
            "orbit.orbital.geometry.atlasCoreBoostPercent": 10,
            "orbit.orbital.geometry.coreContentMargin": 9,
            "orbit.orbital.geometry.satelliteContentMargin": 6,
            "orbit.orbital.satellitePreviews": true,
            "orbit.orbital.satelliteClickAction": "select",
            "orbit.orbital.showWorkspaceLabels": true,
            "orbit.orbital.workspaceLabelMode": "",
            "orbit.orbital.showWorkspaceWallpaper": true,
            "orbit.orbital.workspaceWallpaperOpacity": 70,
            "orbit.pocket.layout": "cards",
            "orbit.pocket.showPreviews": true,
            "orbit.shelf.enable": true,
            "orbit.shelf.showStudioButton": true,
            "orbit.shelf.layout": "islands",
            "orbit.shelf.density": "comfortable",
            "orbit.shelf.labels": "auto",
            "orbit.shelf.islandStyle": "material",
            "orbit.shelf.moduleSpacing": 7,
            "orbit.shelf.islandPadding": 8,
            "orbit.shelf.trailScope": "output",
            "orbit.shelf.locatorLabel": "auto",
            "orbit.shelf.modules": ["locator", "trail", "niri", "actions", "stash"],
            "orbit.shelf.niriActions": ["maximize", "consume", "expel"],
            "orbit.shelf.pinnedActions": ["open-clipboard", "toggle-tiling", "toggle-dashboard"],
            "orbit.shelf.closeOnAction": true
        }
    }

    function presentationPreset(options): string {
        const preset = String(options?.preset ?? "adaptive")
        return ["adaptive", "soft", "float", "sweep", "instant"].includes(preset)
            ? preset : "adaptive"
    }

    function presentationAdvanced(options): bool {
        return options?.advanced ?? false
    }

    function presentationDirection(options, stageMode: string, layout: string): string {
        const preset = presentationPreset(options)
        const configured = ["center", "top", "bottom", "left", "right"].includes(options?.direction)
            ? options.direction : "top"
        if (presentationAdvanced(options))
            return configured
        if (preset === "adaptive") {
            if (stageMode === "stage") return "bottom"
            if (layout === "horizon") return "left"
            if (layout === "gallery") return "right"
            if (layout === "deck") return "bottom"
            if (layout === "atlas") return "center"
            return "top"
        }
        if (preset === "soft") return "center"
        if (preset === "float") return "bottom"
        if (preset === "sweep") return "right"
        return "center"
    }

    function presentationDistance(options): int {
        const preset = presentationPreset(options)
        if (presentationAdvanced(options))
            return Math.max(0, Math.min(160, options?.distance ?? 92))
        if (preset === "soft") return 24
        if (preset === "float") return 46
        if (preset === "sweep") return 72
        return 54
    }

    function presentationEnterDuration(options): int {
        const preset = presentationPreset(options)
        if (preset === "instant") return 0
        if (presentationAdvanced(options))
            return Math.max(80, Math.min(600, options?.enterDurationMs ?? 300))
        if (preset === "soft") return 360
        if (preset === "float") return 310
        if (preset === "sweep") return 330
        return 340
    }

    function presentationExitDuration(options): int {
        const preset = presentationPreset(options)
        if (preset === "instant") return 0
        if (presentationAdvanced(options))
            return Math.max(60, Math.min(500, options?.exitDurationMs ?? 220))
        if (preset === "soft") return 240
        if (preset === "float") return 210
        if (preset === "sweep") return 190
        return 220
    }

    function presentationEntryStyle(options): string {
        const preset = presentationPreset(options)
        const configured = String(options?.entryStyle ?? "cascade")
        if (presentationAdvanced(options)
                && ["fade", "drift", "cascade", "instant"].includes(configured))
            return configured
        if (preset === "soft") return "fade"
        if (preset === "float") return "drift"
        return "cascade"
    }

    function presentationEntryDelay(options): int {
        const preset = presentationPreset(options)
        if (presentationAdvanced(options))
            return Math.max(0, Math.min(240, options?.entryDelayMs ?? 64))
        if (preset === "soft") return 92
        if (preset === "float") return 68
        if (preset === "sweep") return 44
        return 72
    }

    function presentationStagger(options): int {
        const preset = presentationPreset(options)
        if (presentationAdvanced(options))
            return Math.max(0, Math.min(120, options?.entryStaggerMs ?? 42))
        if (preset === "sweep") return 54
        if (preset === "adaptive") return 46
        return 34
    }

    function presentationShelfDelay(options): int {
        const preset = presentationPreset(options)
        if (presentationAdvanced(options))
            return Math.max(0, Math.min(240, options?.shelfDelayMs ?? 72))
        if (preset === "soft") return 52
        if (preset === "sweep") return 92
        return 72
    }

    function presentationEntryOpacity(options): real {
        const preset = presentationPreset(options)
        if (presentationAdvanced(options))
            return Math.max(0, Math.min(0.9, (options?.entryOpacityPercent ?? 0) / 100))
        if (preset === "soft") return 0.08
        if (preset === "float") return 0.04
        return 0
    }

    function navigationPreset(options): string {
        const preset = String(options?.preset ?? "fluid")
        return ["snappy", "fluid", "cinematic", "instant", "custom"].includes(preset)
            ? preset : "fluid"
    }

    function navigationAdvanced(options): bool {
        return (options?.advanced ?? false) || navigationPreset(options) === "custom"
    }

    function navigationDuration(options, layout = ""): int {
        const preset = navigationPreset(options)
        if (preset === "instant") return 0
        if (navigationAdvanced(options))
            return Math.max(80, Math.min(600, options?.durationMs ?? 320))
        const normalizedLayout = ["orbit", "horizon", "gallery", "deck", "atlas"].includes(layout)
            ? layout : "stage"
        if (preset === "snappy") {
            if (normalizedLayout === "atlas") return 125
            if (normalizedLayout === "horizon") return 145
            if (normalizedLayout === "gallery") return 155
            if (normalizedLayout === "deck") return 170
            if (normalizedLayout === "orbit") return 165
            return 150
        }
        if (preset === "cinematic") {
            if (normalizedLayout === "atlas") return 250
            if (normalizedLayout === "horizon") return 285
            if (normalizedLayout === "gallery") return 305
            if (normalizedLayout === "deck") return 330
            if (normalizedLayout === "orbit") return 320
            return 290
        }
        if (normalizedLayout === "atlas") return 165
        if (normalizedLayout === "horizon") return 185
        if (normalizedLayout === "gallery") return 200
        if (normalizedLayout === "deck") return 220
        if (normalizedLayout === "orbit") return 210
        return 195
    }

    function navigationEasing(options): string {
        const preset = navigationPreset(options)
        if (navigationAdvanced(options)) {
            const configured = String(options?.easing ?? "smooth")
            return ["direct", "smooth", "linear"].includes(configured) ? configured : "smooth"
        }
        if (preset === "snappy") return "direct"
        if (preset === "instant") return "linear"
        return "smooth"
    }

    function navigationEasingType(options): int {
        const easing = navigationEasing(options)
        if (easing === "linear") return Easing.Linear
        if (easing === "direct") return Easing.OutQuart
        if (navigationPreset(options) === "cinematic") return Easing.InOutCubic
        // Workspace navigation must react immediately to repeated input. An
        // ease-out keeps the fast initial response while still settling softly;
        // InOutCubic restarted from zero velocity on every key/scroll event.
        return Easing.OutCubic
    }
}
