pragma Singleton
import Quickshell

Singleton {
    id: root

    /**
     * Returns a color with the hue of color2 and the saturation, value, and alpha of color1.
     *
     * @param {string} color1 - The base color (any Qt.color-compatible string).
     * @param {string} color2 - The color to take hue from.
     * @returns {Qt.rgba} The resulting color.
     */
    function colorWithHueOf(color1, color2) {
        var c1 = Qt.color(color1);
        var c2 = Qt.color(color2);

        // Qt.color hsvHue/hsvSaturation/hsvValue/alpha return 0-1
        var hue = c2.hsvHue;
        var sat = c1.hsvSaturation;
        var val = c1.hsvValue;
        var alpha = c1.a;

        return Qt.hsva(hue, sat, val, alpha);
    }

    /**
     * Returns a color with the saturation of color2 and the hue/value/alpha of color1.
     *
     * @param {string} color1 - The base color (any Qt.color-compatible string).
     * @param {string} color2 - The color to take saturation from.
     * @returns {Qt.rgba} The resulting color.
     */
    function colorWithSaturationOf(color1, color2) {
        var c1 = Qt.color(color1);
        var c2 = Qt.color(color2);

        var hue = c1.hsvHue;
        var sat = c2.hsvSaturation;
        var val = c1.hsvValue;
        var alpha = c1.a;

        return Qt.hsva(hue, sat, val, alpha);
    }

    /**
     * Returns a color with the given lightness and the hue, saturation, and alpha of the input color (using HSL).
     *
     * @param {string} color - The base color (any Qt.color-compatible string).
     * @param {number} lightness - The lightness value to use (0-1).
     * @returns {Qt.rgba} The resulting color.
     */
    function colorWithLightness(color, lightness) {
        var c = Qt.color(color);
        return Qt.hsla(c.hslHue, c.hslSaturation, lightness, c.a);
    }

    /**
     * Returns a color with the lightness of color2 and the hue, saturation, and alpha of color1 (using HSL).
     *
     * @param {string} color1 - The base color (any Qt.color-compatible string).
     * @param {string} color2 - The color to take lightness from.
     * @returns {Qt.rgba} The resulting color.
     */
    function colorWithLightnessOf(color1, color2) {
        var c2 = Qt.color(color2);
        return colorWithLightness(color1, c2.hslLightness);
    }

    /**
     * Adapts color1 to the accent (hue and saturation) of color2 using HSL, keeping lightness and alpha from color1.
     *
     * @param {string} color1 - The base color (any Qt.color-compatible string).
     * @param {string} color2 - The accent color.
     * @returns {Qt.rgba} The resulting color.
     */
    function adaptToAccent(color1, color2) {
        var c1 = Qt.color(color1);
        var c2 = Qt.color(color2);

        var hue = c2.hslHue;
        var sat = c2.hslSaturation;
        var light = c1.hslLightness;
        var alpha = c1.a;

        return Qt.hsla(hue, sat, light, alpha);
    }

    /**
     * Mixes two colors by a given percentage.
     *
     * @param {string} color1 - The first color (any Qt.color-compatible string).
     * @param {string} color2 - The second color.
     * @param {number} percentage - The mix ratio (0-1). 1 = all color1, 0 = all color2.
     * @returns {Qt.rgba} The resulting mixed color.
     */
    function mix(color1, color2, percentage = 0.5) {
        var c1 = Qt.color(color1);
        var c2 = Qt.color(color2);
        return Qt.rgba(percentage * c1.r + (1 - percentage) * c2.r, percentage * c1.g + (1 - percentage) * c2.g, percentage * c1.b + (1 - percentage) * c2.b, percentage * c1.a + (1 - percentage) * c2.a);
    }

    /**
     * Transparentizes a color by a given percentage.
     *
     * @param {string} color - The color (any Qt.color-compatible string).
     * @param {number} percentage - The amount to transparentize (0-1).
     * @returns {Qt.rgba} The resulting color.
     */
    function transparentize(color, percentage = 1) {
        if (!color || color === "") return Qt.rgba(0, 0, 0, 0);
        var c = Qt.color(color);
        if (!c.valid) return Qt.rgba(0, 0, 0, 0);
        return Qt.rgba(c.r, c.g, c.b, c.a * (1 - percentage));
    }

    /**
     * Sets the alpha channel of a color.
     *
     * @param {string} color - The base color (any Qt.color-compatible string).
     * @param {number} alpha - The desired alpha (0-1).
     * @returns {Qt.rgba} The resulting color with applied alpha.
     */
    function applyAlpha(color, alpha) {
        var c = Qt.color(color);
        var a = Math.max(0, Math.min(1, alpha));
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    /**
     * Returns black or white depending on which provides better contrast with the input color.
     * Uses relative luminance calculation per WCAG guidelines.
     *
     * @param {string} color - The background color (any Qt.color-compatible string).
     * @returns {Qt.rgba} Either white or black for optimal contrast.
     */
    function contrastColor(color) {
        var c = Qt.color(color);
        // Calculate relative luminance using sRGB formula
        var r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4);
        var g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4);
        var b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4);
        var luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        return luminance > 0.179 ? Qt.rgba(0, 0, 0, 1) : Qt.rgba(1, 1, 1, 1);
    }

    /**
     * Lightens a color by a given amount.
     *
     * @param {string} color - The color (any Qt.color-compatible string).
     * @param {number} amount - The amount to lighten (0-1).
     * @returns {Qt.rgba} The resulting lighter color.
     */
    function lighten(color, amount = 0.1) {
        var c = Qt.color(color);
        var newL = Math.min(1, c.hslLightness + amount);
        return Qt.hsla(c.hslHue, c.hslSaturation, newL, c.a);
    }

    /**
     * Darkens a color by a given amount.
     *
     * @param {string} color - The color (any Qt.color-compatible string).
     * @param {number} amount - The amount to darken (0-1).
     * @returns {Qt.rgba} The resulting darker color.
     */
    function darken(color, amount = 0.1) {
        var c = Qt.color(color);
        var newL = Math.max(0, c.hslLightness - amount);
        return Qt.hsla(c.hslHue, c.hslSaturation, newL, c.a);
    }

    function isDark(color) {
        var c = Qt.color(color);
        return c.hslLightness < 0.5;
    }

    function clamp01(x) {
        return Math.min(1, Math.max(0, x));
    }

    /**
     * Solves for the solid overlay color that, when composited over a base color
     * with a given opacity, yields the target color.
     */
    function solveOverlayColor(baseColor, targetColor, overlayOpacity) {
        let invA = 1.0 - overlayOpacity;
        let r = (targetColor.r - baseColor.r * invA) / overlayOpacity;
        let g = (targetColor.g - baseColor.g * invA) / overlayOpacity;
        let b = (targetColor.b - baseColor.b * invA) / overlayOpacity;
        return Qt.rgba(clamp01(r), clamp01(g), clamp01(b), overlayOpacity);
    }

    /**
     * Calculates relative luminance per WCAG 2.1 guidelines.
     * @param {color} color - Qt color object
     * @returns {number} Luminance value 0-1
     */
    function relativeLuminance(color) {
        var c = Qt.color(color);
        var r = c.r <= 0.03928 ? c.r / 12.92 : Math.pow((c.r + 0.055) / 1.055, 2.4);
        var g = c.g <= 0.03928 ? c.g / 12.92 : Math.pow((c.g + 0.055) / 1.055, 2.4);
        var b = c.b <= 0.03928 ? c.b / 12.92 : Math.pow((c.b + 0.055) / 1.055, 2.4);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    /**
     * Calculates WCAG contrast ratio between two colors.
     * @param {color} fg - Foreground color
     * @param {color} bg - Background color
     * @returns {number} Contrast ratio (1-21)
     */
    function contrastRatio(fg, bg) {
        var l1 = relativeLuminance(fg);
        var l2 = relativeLuminance(bg);
        var lighter = Math.max(l1, l2);
        var darker = Math.min(l1, l2);
        return (lighter + 0.05) / (darker + 0.05);
    }

    /**
     * Checks if contrast ratio meets WCAG AA standard (4.5:1 for normal text).
     * @param {color} fg - Foreground color
     * @param {color} bg - Background color
     * @returns {bool} True if meets AA standard
     */
    function meetsWcagAA(fg, bg) {
        return contrastRatio(fg, bg) >= 4.5;
    }

    /**
     * Adjusts color saturation by a factor.
     * @param {color} color - Input color
     * @param {number} factor - Multiplier (0.5 = half saturation, 2 = double)
     * @returns {color} Adjusted color
     */
    function adjustSaturation(color, factor) {
        var c = Qt.color(color);
        var newSat = clamp01(c.hslSaturation * factor);
        return Qt.hsla(c.hslHue, newSat, c.hslLightness, c.a);
    }

    /**
     * Shifts hue by degrees (for color temperature adjustment).
     * @param {color} color - Input color
     * @param {number} degrees - Hue shift (-180 to 180)
     * @returns {color} Adjusted color
     */
    function shiftHue(color, degrees) {
        var c = Qt.color(color);
        var newHue = (c.hslHue + degrees / 360 + 1) % 1;
        return Qt.hsla(newHue, c.hslSaturation, c.hslLightness, c.a);
    }

    /**
     * Generates complementary color (opposite on color wheel).
     * @param {color} color - Input color
     * @returns {color} Complementary color
     */
    function complementary(color) {
        return shiftHue(color, 180);
    }

    /**
     * Generates analogous colors (adjacent on color wheel).
     * @param {color} color - Input color
     * @param {number} angle - Angle offset (default 30)
     * @returns {array} [color, analogous1, analogous2]
     */
    function analogous(color, angle = 30) {
        return [color, shiftHue(color, angle), shiftHue(color, -angle)];
    }

    /**
     * Generates triadic colors (120° apart on color wheel).
     * @param {color} color - Input color
     * @returns {array} [color, triadic1, triadic2]
     */
    function triadic(color) {
        return [color, shiftHue(color, 120), shiftHue(color, 240)];
    }

    /**
     * Generates split-complementary colors.
     * @param {color} color - Input color
     * @returns {array} [color, split1, split2]
     */
    function splitComplementary(color) {
        return [color, shiftHue(color, 150), shiftHue(color, 210)];
    }

    /**
     * Ensures text color has sufficient contrast against background.
     * Adjusts lightness while preserving hue/saturation.
     * @param {color} textColor - Original text color
     * @param {color} bgColor - Background color
     * @param {number} minRatio - Minimum contrast ratio (default 4.5 for WCAG AA)
     * @returns {color} Adjusted text color with sufficient contrast
     */
    function ensureReadable(textColor, bgColor, minRatio = 4.5) {
        if (textColor === undefined || textColor === null || String(textColor).length === 0)
            textColor = Qt.rgba(1, 1, 1, 1);
        if (bgColor === undefined || bgColor === null || String(bgColor).length === 0)
            bgColor = Qt.rgba(0, 0, 0, 1);
        var fg = Qt.color(textColor);
        var bg = Qt.color(bgColor);
        var ratio = contrastRatio(fg, bg);
        
        if (ratio >= minRatio) return fg;

        // Choose the direction that can actually provide the strongest
        // contrast. A luminance threshold is insufficient here: mid-tone
        // wallpaper palettes can make white fail while black passes (or the
        // inverse), which previously returned an unreadable extreme.
        var white = Qt.rgba(1, 1, 1, fg.a);
        var black = Qt.rgba(0, 0, 0, fg.a);
        var whiteRatio = contrastRatio(white, bg);
        var blackRatio = contrastRatio(black, bg);
        var targetLightness = whiteRatio >= blackRatio ? 1.0 : 0.0;
        var target = targetLightness > 0.5 ? white : black;

        if (Math.max(whiteRatio, blackRatio) < minRatio)
            return target;

        // Binary-search the smallest lightness adjustment that reaches the
        // requested ratio while preserving the original hue and saturation.
        var failingLightness = fg.hslLightness;
        var passingLightness = targetLightness;
        for (var i = 0; i < 18; i++) {
            var candidateLightness = (failingLightness + passingLightness) / 2;
            var candidate = Qt.hsla(fg.hslHue, fg.hslSaturation,
                candidateLightness, fg.a);
            if (contrastRatio(candidate, bg) >= minRatio)
                passingLightness = candidateLightness;
            else
                failingLightness = candidateLightness;
        }
        return Qt.hsla(fg.hslHue, fg.hslSaturation, passingLightness, fg.a);
    }

    /**
     * Region-adaptive ACCENT colour. Unlike ensureReadable (which is for body text and
     * collapses to white/black), this keeps the accent a COLOUR: it preserves the
     * wallpaper-generated hue and a minimum saturation, and drives lightness within a
     * coloured band to whichever value maximises contrast against the region behind it.
     * This is why a light Material-You accent (tuned for the shell's dark surfaces)
     * becomes a darker version of the SAME hue over a bright wallpaper region instead of
     * washing out — exactly how the shell keeps accents legible, applied to the desktop.
     *
     * @param {color} accentColor - Wallpaper-generated accent (colPrimary/Secondary/...)
     * @param {color} bgColor - The wallpaper region colour behind the widget
     * @param {number} target - Desired contrast ratio (default 4.0; accents, not text)
     * @param {number} minSat - Saturation floor so the accent never greys out (0.35)
     * @param {number} bandMin - Lowest lightness allowed (0.20 — still a colour, not black)
     * @param {number} bandMax - Highest lightness allowed (0.82 — still a colour, not white)
     * @returns {color} Region-legible accent that keeps the wallpaper hue
     */
    function adaptAccent(accentColor, bgColor, target = 4.0, minSat = 0.45, bandMin = 0.18, bandMax = 0.84) {
        if (accentColor === undefined || accentColor === null || String(accentColor).length === 0)
            return accentColor;
        if (bgColor === undefined || bgColor === null || String(bgColor).length === 0)
            return accentColor;
        var fg = Qt.color(accentColor);
        var bg = Qt.color(bgColor);
        // Clamp, not normalizer: an accent that already reads keeps its exact
        // palette identity, so themes whose accents oppose their surfaces (the
        // common dark-theme case) render byte-identical with or without this.
        if (contrastRatio(fg, bg) >= target)
            return fg;
        var hue = fg.hslHue;
        var sat = Math.max(minSat, fg.hslSaturation);
        var bgLum = relativeLuminance(bg);
        // Same move the shell's ZZZ style makes for its signal accents: take the
        // wallpaper-generated accent hue and PIN its lightness into a fixed readable
        // band on the opposite side of the surface — here the surface is the wallpaper
        // region. Bright region → deep accent; dark region → bright accent. Then walk
        // toward the band edge only as far as needed to clear `target`, boosting chroma
        // as it deepens so the colour stays vivid (never a washed-out near-white/!black).
        var regionLight = bgLum >= 0.18;
        // Anchor lightness: deep band on bright regions, light band on dark regions.
        var anchorL = regionLight ? 0.42 : 0.70;
        var edgeL = regionLight ? bandMin : bandMax;
        var best = Qt.hsla(hue, sat, anchorL, fg.a);
        var bestRatio = contrastRatio(best, bg);
        var steps = 18;
        for (var i = 0; i <= steps; i++) {
            var L = anchorL + (edgeL - anchorL) * (i / steps);
            // Deepening accents gain chroma so they read as a saturated colour, not mud.
            var satHere = regionLight ? Math.min(1.0, sat + (anchorL - L) * 0.8) : sat;
            var cand = Qt.hsla(hue, clamp01(satHere), clamp01(L), fg.a);
            var r = contrastRatio(cand, bg);
            if (r >= target) return cand;
            if (r > bestRatio) {
                best = cand;
                bestRatio = r;
            }
        }
        return best;
    }

    /**
     * Raises a neutral on-surface ink's saturation to a fixed floor while keeping its
     * hue and lightness untouched — the ink already carries the wallpaper's hue (Material
     * You ties on-surface tones to the seed color) but at near-zero chroma for legibility.
     * This makes that hue actually visible without touching the lightness that legibility
     * depends on. Falls back to the ink unchanged for genuinely achromatic wallpapers
     * (checked via seedColor, typically m3primary) so grayscale wallpapers don't get a
     * fake hue injected.
     *
     * @param {color} ink - Neutral on-surface text color (e.g. colOnLayer0)
     * @param {color} seedColor - Wallpaper-generated color used only to detect "is this
     *   wallpaper chromatic at all" (typically m3primary)
     * @param {number} targetSat - Saturation floor to raise ink to (default 0.5)
     * @returns {color} ink with boosted saturation, or unchanged if already vivid enough
     */
    function boostInkSaturation(ink, seedColor, targetSat = 0.5) {
        if (ink === undefined || ink === null || String(ink).length === 0)
            return ink;
        var seed = Qt.color(seedColor);
        if (seed.hslSaturation <= 0.02)
            return ink;
        var c = Qt.color(ink);
        if (c.hslSaturation >= targetSat)
            return c;
        return Qt.hsla(c.hslHue, targetSat, c.hslLightness, c.a);
    }

    /**
     * Creates a readable subtext color (slightly less prominent than main text).
     * @param {color} mainTextColor - Main text color
     * @param {color} bgColor - Background color
     * @param {number} dimFactor - How much to dim (0.7 = 70% opacity effect)
     * @returns {color} Readable subtext color
     */
    function readableSubtext(mainTextColor, bgColor, dimFactor = 0.7) {
        var main = Qt.color(mainTextColor);
        var bg = Qt.color(bgColor);
        
        // Mix towards background to create dimmed effect
        var dimmed = mix(main, bg, dimFactor);
        
        // Ensure it's still readable (WCAG AA for large text is 3:1)
        return ensureReadable(dimmed, bg, 3.0);
    }
}
