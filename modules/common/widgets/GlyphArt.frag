#version 440
// A picture as glowing glyphs: the last stage. GlyphCompose has decided every cell (its glyph and its light); this
// draws them from the atlas and puts the screen over them: lens fringe, glow, curve, glitch, scanlines, grain, or
// ink on paper. The glow is the cell texture's own mips, so there is no blur pass.
// After winchxyz/afterglyph (MIT): its final composite, value for value.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // xy: size in px, z: corner radius, w: a cell's width in px.
    vec4 box;
    // xy: columns and rows, z: 1 ink on paper, w: 1 opaque over what is under it.
    vec4 grid;
    // x: glow, y: scanlines, z: grain, w: lens fringe.
    vec4 screen;
    // x: screen curve, y: glitch, z: seconds, w: sway (radians).
    vec4 warp;
    vec4 back;
} u;
layout(binding = 1) uniform sampler2D cells;
layout(binding = 2) uniform sampler2D atlas;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float peak(vec3 c) { return max(c.r, max(c.g, c.b)); }

// The light of the glyph under a point of the screen.
vec3 ink(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) return vec3(0.0);
    vec2 g = uv * u.grid.xy;
    vec2 cell = floor(g);
    vec4 t = textureLod(cells, (cell + 0.5) / u.grid.xy, 0.0);
    float glyph = floor(t.a * 255.0 + 0.5);
    if (glyph < 0.5) return vec3(0.0);
    // Most of a level sharper than the size it is drawn at: a full level softened a 10 px glyph into a smudge.
    float lod = max(0.0, log2(28.0 / max(u.box.w, 1.0)) - 0.7);
    float pad = 0.5 * exp2(lod) / 28.0;
    vec2 f = clamp(g - cell, vec2(pad), vec2(1.0 - pad));
    vec2 tile = vec2(mod(glyph, 8.0), floor(glyph / 8.0));
    return t.rgb * textureLod(atlas, (tile + f) / vec2(8.0, 28.0), lod).a;
}
vec3 bloom(vec2 uv) {
    if (uv.x < 0.0 || uv.x >= 1.0 || uv.y < 0.0 || uv.y >= 1.0) return vec3(0.0);
    return (textureLod(cells, uv, 1.0).rgb * 0.34 + textureLod(cells, uv, 2.0).rgb * 0.3
        + textureLod(cells, uv, 3.0).rgb * 0.24 + textureLod(cells, uv, 4.5).rgb * 0.18) * 0.24;
}

void main() {
    vec2 c = qt_TexCoord0 * 2.0 - 1.0;
    float r2 = dot(c, c) * 0.5;
    float k = u.warp.x * 0.42;
    vec2 uv = c * (1.0 + k * r2) / (1.0 + k * 0.5) * 0.5 + 0.5;
    bool inside = uv.x >= 0.0 && uv.x < 1.0 && uv.y >= 0.0 && uv.y < 1.0;

    if (u.warp.w != 0.0) {
        // The whole sheet leans a little about a point just above its middle, drawn slightly closer so no edge shows.
        vec2 p = (uv - vec2(0.5, 0.48)) * u.box.xy;
        float sn = sin(u.warp.w), cs = cos(u.warp.w);
        p = vec2(cs * p.x - sn * p.y, sn * p.x + cs * p.y) / (1.026 + 0.006 * sin(u.warp.z * 0.5));
        uv = p / u.box.xy + vec2(0.5, 0.48);
    }

    if (u.warp.y > 0.0) {
        float band = floor(uv.y * 26.0), tick = floor(u.warp.z * 9.0);
        if (hash(vec2(band, tick)) < u.warp.y * 0.25) uv.x += (hash(vec2(tick, band)) - 0.5) * 0.12 * u.warp.y;
    }

    vec3 col;
    if (u.screen.w > 0.0) {
        vec2 off = c * (0.0005 + 0.0018 * r2) * u.screen.w;
        col = vec3(ink(uv + off).r, ink(uv).g, ink(uv - off).b);
    } else {
        col = ink(uv);
    }
    if (u.screen.x > 0.0) col += bloom(uv) * u.screen.x;
    col = 1.0 - exp(-col * 1.25);
    col *= 1.0 - u.screen.y * 0.45 * (0.5 - 0.5 * cos(6.2831853 * uv.y * u.grid.y));
    float grain = (hash(floor(qt_TexCoord0 * u.box.xy) + floor(u.warp.z * 12.0)) - 0.5) * 0.03 * u.screen.z;

    vec4 result;
    if (u.grid.z > 0.5) {
        float amount = peak(col);
        vec3 sheet = vec3(0.93, 0.90, 0.84) * (1.0 - r2 * 0.12);
        result = vec4(mix(sheet, col / max(amount, 0.001) * 0.2, clamp(amount * 1.15, 0.0, 1.0)) + grain, 1.0);
    } else {
        col = col * (1.0 - r2 * 0.275) + grain * (0.4 + peak(col));
        if (u.grid.w > 0.5) result = vec4(u.back.rgb * 0.9 * clamp(1.0 - r2 * 0.8, 0.0, 1.0) + max(col, 0.0), 1.0);
        else result = vec4(max(col, 0.0), clamp(peak(col) * 1.4, 0.0, 1.0));
    }
    if (!inside) result = u.grid.w > 0.5 || u.grid.z > 0.5 ? vec4(0.0, 0.0, 0.0, 1.0) : vec4(0.0);

    vec2 half_ = u.box.xy * 0.5;
    vec2 d = abs((qt_TexCoord0 - 0.5) * u.box.xy) - half_ + u.box.z;
    float edge = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - u.box.z;
    fragColor = result * clamp(0.5 - edge, 0.0, 1.0) * u.qt_Opacity;
}
