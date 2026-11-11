#version 440
// A picture as glowing glyphs, whole in one pass. Every pixel finds its 7x9 cell, reads the picture there (one texel
// per cell, plus its eight neighbours for the edge), picks the cell's glyph and inks it from the atlas. The glow is
// the same small picture read smooth, so there is no blur pass. Nothing here moves unless `make.x` (grow) does.
// After winchxyz/afterglyph (MIT): its glyph rules, tone curve and palettes, moved from the CPU to the fragment.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // xy: size in px, z: corner radius, w: px per glyph pixel.
    vec4 box;
    // xy: columns and rows, z: glyphs in the atlas, w: 1 ink on paper.
    vec4 grid;
    // x: grow 0..1, y: glow, z: fringe, w: scanlines.
    vec4 make;
    // x: how much colour comes from the picture (0 = the palette), y: contrast, z: edge strokes, w: plate alpha.
    vec4 tone;
    vec4 low;
    vec4 mid;
    vec4 high;
    vec4 plate;
} u;
layout(binding = 1) uniform sampler2D picture;
layout(binding = 2) uniform sampler2D atlas;

const float RAMP = 1.0, BOLD = 10.0, THIN = 14.0, DIGIT = 18.0, DOT = 28.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 cellColour(vec2 cell) { return textureLod(picture, (cell + 0.5) / u.grid.xy, 0.0).rgb; }
// Exposure: the picture's mean (its smallest mip) is brought to mid grey, so a dark cover still lights up.
float gain() { return clamp(0.3 / max(luma(textureLod(picture, vec2(0.5), 16.0).rgb), 0.04), 1.0, 2.2); }
float level(vec3 c) {
    float l = clamp((min(luma(c) * gain(), 1.0) - 0.5) * u.tone.y + 0.5, 0.0, 1.0);
    return pow(l, 0.85);
}
// One glyph pixel of the atlas; outside the cell there is no ink.
float ink(float glyph, vec2 gp) {
    if (gp.x < 0.0 || gp.x >= 7.0 || gp.y < 0.0 || gp.y >= 9.0) return 0.0;
    return texture(atlas, vec2((glyph * 7.0 + floor(gp.x) + 0.5) / (u.grid.z * 7.0), (floor(gp.y) + 0.5) / 9.0)).a;
}
vec3 paletteAt(float l) {
    return l < 0.5 ? mix(u.low.rgb, u.mid.rgb, l * 2.0) : mix(u.mid.rgb, u.high.rgb, l * 2.0 - 2.0 + 1.0);
}

void main() {
    vec2 size = u.box.xy;
    vec2 px = qt_TexCoord0 * size;
    vec2 cellPx = vec2(7.0, 9.0) * u.box.w;
    vec2 origin = floor((size - u.grid.xy * cellPx) * 0.5);
    vec2 at = (px - origin) / cellPx;
    vec2 cell = floor(at);
    bool inside = cell.x >= 0.0 && cell.y >= 0.0 && cell.x < u.grid.x && cell.y < u.grid.y;

    vec3 c = cellColour(cell);
    float L = level(c);

    // The edge through this cell, from its eight neighbours.
    float tl = luma(cellColour(cell + vec2(-1, -1))), tc = luma(cellColour(cell + vec2(0, -1))), tr = luma(cellColour(cell + vec2(1, -1)));
    float ml = luma(cellColour(cell + vec2(-1, 0))), mr = luma(cellColour(cell + vec2(1, 0)));
    float bl = luma(cellColour(cell + vec2(-1, 1))), bc = luma(cellColour(cell + vec2(0, 1))), br = luma(cellColour(cell + vec2(1, 1)));
    vec2 g = vec2((tr + 2.0 * mr + br) - (tl + 2.0 * ml + bl), (bl + 2.0 * bc + br) - (tl + 2.0 * tc + tr)) * 0.25;
    float edge = min(1.0, length(g) * 2.6) * u.tone.z;
    vec2 ag = abs(g);
    // 0 ‖  1 =  2 /  3 \ : the stroke runs along the edge, across the gradient.
    float q = ag.x > 2.414 * ag.y ? 0.0 : ag.y > 2.414 * ag.x ? 1.0 : g.x * g.y > 0.0 ? 2.0 : 3.0;

    // Growing in from the foot, a little ragged; the front is digits that re-roll as it climbs.
    float order = (1.0 - (cell.y + 0.5) / u.grid.y) * 0.86 + hash(cell) * 0.14;
    float front = u.make.x * 1.14 - order;
    float seen = u.make.x >= 1.0 ? 1.0 : clamp(front / 0.025, 0.0, 1.0);
    bool digit = u.make.x < 1.0 && front > 0.0 && front < 0.11;

    float lit = L;
    float glyph;
    float hv = hash(cell + 11.0);
    float around = max(max(max(tl, tc), max(tr, ml)), max(max(mr, bl), max(bc, br))) * gain();
    if (digit) {
        glyph = DIGIT + floor(hash(cell + floor(u.make.x * 22.0)) * 10.0);
        lit = 0.32 + 0.68 * L;
    } else if (L < 0.07) {
        // Empty; one cell outside something bright, the contour's dot.
        glyph = around > 0.3 ? DOT : 0.0;
        lit = 0.24;
    } else if (edge > 0.5) {
        glyph = BOLD + q;
        lit = 0.38 + 0.62 * L;
    } else if (edge > 0.2 && L < 0.8) {
        glyph = THIN + q;
        lit = 0.13 + 0.7 * L;
    } else {
        float step9 = floor(clamp(L * 0.94 + (hv - 0.5) * 0.14, 0.0, 0.9999) * 9.0);
        // The brightest cells are discs with blocks among them, never a wall of blocks.
        glyph = RAMP + (step9 > 7.5 && hv < 0.6 ? 7.0 : step9);
        lit = 0.1 + 0.9 * pow(L, 1.35);
    }

    // The cell's colour: the picture's own, pushed to full and vivid, or the palette by brightness.
    float top = max(c.r, max(c.g, c.b));
    vec3 own = c / max(top, 0.001);
    own = clamp(vec3(luma(own)) + (own - vec3(luma(own))) * 1.5, 0.0, 1.0);
    own = mix(own, vec3(1.0), clamp((L - 0.78) / 0.22, 0.0, 1.0) * 0.55);
    vec3 colour = mix(paletteAt(L), own, u.tone.x);

    // Ink, with the lens fringe as red and blue read one glyph pixel apart.
    vec2 gp = fract(at) * vec2(7.0, 9.0);
    float fr = u.make.z * length(qt_TexCoord0 - 0.5) * 0.7;
    vec3 cover = vec3(ink(glyph, gp + vec2(fr, 0.0)), ink(glyph, gp), ink(glyph, gp - vec2(fr, 0.0)));
    cover = mix(vec3(cover.g), cover, step(0.001, u.make.z));

    // Glow: the picture itself, read smooth between cells, under the glyphs.
    vec2 guv = (px - origin) / (u.grid.xy * cellPx);
    vec3 soft = textureLod(picture, guv, 0.0).rgb;
    float softL = level(soft);
    float softSeen = u.make.x >= 1.0 ? 1.0 : smoothstep(0.0, 0.12, u.make.x * 1.14 - (1.0 - guv.y) * 0.86 - 0.07);
    vec3 softC = mix(paletteAt(softL), soft / max(max(soft.r, max(soft.g, soft.b)), 0.001), u.tone.x);
    vec3 glow = softC * pow(softL, 1.6) * 0.42 * u.make.y * softSeen;

    vec3 light = (colour * lit * 1.5 * cover * seen + glow) * (inside ? 1.0 : 0.0);
    light = 1.0 - exp(-light * 1.25);
    // One darker row per glyph line.
    light *= (1.0 + u.make.w * 0.3) * (1.0 - u.make.w * 0.45 * (0.5 + 0.5 * cos(fract(at.y) * 6.2832)));

    vec2 d = qt_TexCoord0 - 0.5;
    float r2 = dot(d, d);
    float grain = hash(floor(px)) - 0.5;
    vec3 rgb;
    float alpha;
    if (u.grid.w > 0.5) {
        // Ink on paper: the light becomes how much ink lies on the sheet.
        float a = clamp(lit * 1.3 * cover.g * seen, 0.0, 1.0) * (inside ? 1.0 : 0.0);
        vec3 sheet = u.plate.rgb * (1.0 - r2 * 0.22) + grain * 0.03;
        rgb = mix(sheet, u.low.rgb, a);
        alpha = 1.0;
    } else {
        light *= 1.0 - r2 * 0.55;
        float a = clamp(max(light.r, max(light.g, light.b)) * 1.6, 0.0, 1.0);
        alpha = max(u.tone.w, a);
        rgb = u.plate.rgb * u.tone.w * (1.0 - r2 * 0.5) + light + grain * 0.012 * u.tone.w;
        rgb = min(rgb, vec3(1.0));
    }

    // The plate's rounded corners.
    vec2 h = size * 0.5;
    vec2 k = abs(px - h) - h + u.box.z;
    float mask = clamp(0.5 - (length(max(k, 0.0)) + min(max(k.x, k.y), 0.0) - u.box.z), 0.0, 1.0);
    fragColor = vec4(max(rgb, 0.0), alpha) * mask * u.qt_Opacity;
}
