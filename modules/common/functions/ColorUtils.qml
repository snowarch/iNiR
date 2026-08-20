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
     * Makes an accent usable as foreground ink without converting warm Material
     * palettes into rust/brown/olive. HSL lightness clamping cannot preserve the
     * visual identity of a pastel accent on a bright background: orange and yellow
     * necessarily become brown when pushed to text-level contrast at fixed chroma.
     * Instead, retain as much of the source color as possible and blend only the
     * minimum amount toward a contrast endpoint. The result becomes a tinted ink,
     * not an artificially saturated dark version of the source hue.
     *
     * @param {color} accentColor - Source accent.
     * @param {color} bgColor - Backdrop the foreground lands on.
     * @param {number} target - Desired contrast ratio.
     * @param {color} towardColor - Optional preferred readable ink polarity.
     * @returns {color} The least-modified foreground color that reaches target.
     */
    function readableAccentInk(accentColor, bgColor, target = 4.0, towardColor = null) {
        if (accentColor === undefined || accentColor === null || String(accentColor).length === 0)
            return accentColor;
        if (bgColor === undefined || bgColor === null || String(bgColor).length === 0)
            return accentColor;

        var fg = Qt.color(accentColor);
        var bg = Qt.color(bgColor);
        if (!fg.valid || !bg.valid || contrastRatio(fg, bg) >= target)
            return fg;

        var endpoint = Qt.rgba(0, 0, 0, fg.a);
        if (towardColor !== undefined && towardColor !== null && String(towardColor).length > 0) {
            var hinted = Qt.color(towardColor);
            if (hinted.valid)
                endpoint = Qt.rgba(hinted.r, hinted.g, hinted.b, fg.a);
        }

        // A style hint is useful only when it can actually satisfy the requested
        // contrast. Otherwise choose the stronger neutral endpoint deterministically.
        if (contrastRatio(endpoint, bg) < target) {
            var white = Qt.rgba(1, 1, 1, fg.a);
            var black = Qt.rgba(0, 0, 0, fg.a);
            endpoint = contrastRatio(white, bg) >= contrastRatio(black, bg) ? white : black;
        }
        if (contrastRatio(endpoint, bg) < target)
            return endpoint;

        // retention=1 is the untouched accent (known to fail); retention=0 is
        // the readable endpoint. Find the highest source retention that passes.
        var passingRetention = 0.0;
        var failingRetention = 1.0;
        for (var i = 0; i < 20; i++) {
            var retention = (passingRetention + failingRetention) / 2;
            var candidate = mix(fg, endpoint, retention);
            if (contrastRatio(candidate, bg) >= target)
                passingRetention = retention;
            else
                failingRetention = retention;
        }
        return mix(fg, endpoint, passingRetention);
    }

    /**
     * Region-adaptive accent used by existing components that already render on
     * a controlled surface (Battery/Cookie Clock). Keep this contract stable;
     * desktop telemetry graphics use style-owned colors instead of routing raw
     * shapes through this text-like contrast transform.
     */
    function adaptAccent(accentColor, bgColor, target = 4.0, minSat = 0.45, bandMin = 0.18, bandMax = 0.84) {
        if (accentColor === undefined || accentColor === null || String(accentColor).length === 0)
            return accentColor;
        if (bgColor === undefined || bgColor === null || String(bgColor).length === 0)
            return accentColor;
        var fg = Qt.color(accentColor);
        var bg = Qt.color(bgColor);
        if (contrastRatio(fg, bg) >= target)
            return fg;
        var hue = fg.hslHue;
        var sat = Math.max(minSat, fg.hslSaturation);
        var bgLum = relativeLuminance(bg);
        var regionLight = bgLum >= 0.18;
        var anchorL = regionLight ? 0.42 : 0.70;
        var edgeL = regionLight ? bandMin : bandMax;
        var best = Qt.hsla(hue, sat, anchorL, fg.a);
        var bestRatio = contrastRatio(best, bg);
        var steps = 18;
        for (var i = 0; i <= steps; i++) {
            var L = anchorL + (edgeL - anchorL) * (i / steps);
            var satHere = regionLight ? Math.min(1.0, sat + (anchorL - L) * 0.8) : sat;
            var cand = Qt.hsla(hue, clamp01(satHere), clamp01(L), fg.a);
            var ratio = contrastRatio(cand, bg);
            if (ratio >= target)
                return cand;
            if (ratio > bestRatio) {
                best = cand;
                bestRatio = ratio;
            }
        }
        return best;
    }

    /**
     * Gives neutral on-surface ink a restrained theme tint without turning gray
     * tokens into arbitrary red. Qt reports hue=0 for achromatic colors, so using
     * the ink hue while force-raising saturation injected a red cast whenever a
     * generated on-surface token was truly gray. Neutral ink now borrows the seed
     * hue and receives only a subtle amount of chroma; already-colored ink is left
     * untouched.
     *
     * @param {color} ink - Neutral or lightly tinted on-surface text color.
     * @param {color} seedColor - Theme accent used as the hue source for neutral ink.
     * @param {number} targetSat - Maximum tint saturation for neutral ink.
     * @returns {color} Restrained theme-tinted ink.
     */
    function boostInkSaturation(ink, seedColor, targetSat = 0.5) {
        if (ink === undefined || ink === null || String(ink).length === 0)
            return ink;
        var seed = Qt.color(seedColor);
        var c = Qt.color(ink);
        if (!seed.valid || !c.valid || seed.hslSaturation <= 0.02)
            return c;

        // Preserve the established behavior for ink that already has a real hue.
        // The bug is specifically Qt's hue=0 sentinel on achromatic colors: raising
        // that gray to 50% saturation manufactures red. Neutral ink instead borrows
        // the seed hue and only receives a restrained tint.
        if (c.hslSaturation > 0.025) {
            if (c.hslSaturation >= targetSat)
                return c;
            return Qt.hsla(c.hslHue, targetSat, c.hslLightness, c.a);
        }

        var neutralSat = Math.min(0.12, targetSat, seed.hslSaturation * 0.14);
        return neutralSat > 0
            ? Qt.hsla(seed.hslHue, neutralSat, c.hslLightness, c.a)
            : c;
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
