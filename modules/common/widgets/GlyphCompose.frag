#version 440
// One texel per glyph cell: which glyph it shows (alpha, as a slot of the atlas over 255) and the light it gives
// (rgb). Everything that decides a cell happens here, so GlyphArt.frag only draws: the cut from the background,
// the levels, the edge lines from a structure tensor, the character set, shimmer, digit rain, colour and the intro.
// After winchxyz/afterglyph (MIT): its compose rules, moved from a CPU loop over cells to this fragment.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // xy: columns and rows; z: set mode (0 mixed, 1 lines, 2 ramp, 3 random); w: mirror (0 off, 1 two, 2 four).
    vec4 grid;
    // x: the set's first slot, y: its slots, z: edge lines, w: shimmer.
    vec4 chars;
    // x: 1 the picture's colours, 0 the palette; y: contrast; z: vividness; w: 1 swaps light and dark.
    vec4 tone;
    // x: hue shift in turns, y: rainbow, z: drift, w: digit rain.
    vec4 hue;
    // xy: where the cut starts and ends; z: 1 draws the outline; w: intro (1 grow, 2 scan, 3 type, 4 centre, 5 dissolve).
    vec4 cut;
    // x: seconds; y: intro 0..1 (2 = no intro); z: zoom; w: columns over rows as seen.
    vec4 clock;
    vec4 low;
    vec4 mid;
    vec4 high;
    vec4 accent;
} u;
layout(binding = 1) uniform sampler2D picture;
layout(binding = 2) uniform sampler2D stats;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Where a cell reads the picture: mirrored, then through the camera.
vec2 look(vec2 cell) {
    vec2 uv = (cell + 0.5) / u.grid.xy;
    if (u.grid.w > 0.5 && uv.x > 0.5) uv.x = 1.0 - uv.x;
    if (u.grid.w > 1.5 && uv.y > 0.5) uv.y = 1.0 - uv.y;
    return clamp((uv - 0.5) / u.clock.z + 0.5, 0.0, 1.0);
}
// rgb: the cell's own colour; a: how much of it is subject.
vec4 subject(vec2 cell, vec4 key) {
    vec4 s = textureLod(picture, look(cell), 0.0);
    vec3 c = s.rgb / max(s.a, 0.001);
    float m = s.a;
    if (key.a > 0.5) m *= smoothstep(u.cut.x, u.cut.y, distance(c, key.rgb));
    return vec4(c, m);
}
float level(vec3 c, vec2 levels) {
    float l = luma(c);
    if (u.tone.w > 0.5) l = 1.0 - l;
    l = clamp((l - levels.x) / max(levels.y - levels.x, 0.05), 0.0, 1.0);
    return pow(clamp((l - 0.5) * u.tone.y + 0.5, 0.0, 1.0), 0.85);
}
float lit(vec2 cell, vec4 key, vec2 levels) {
    vec4 s = subject(cell, key);
    return level(s.rgb, levels) * s.a;
}

// A line along an edge whose gradient points to quarter q: upright, slash, level, backslash.
float thin(float q) { return q < 0.5 ? 4.0 : q < 1.5 ? 6.0 : q < 2.5 ? 2.0 : 7.0; }
float bold(float q) { return q < 0.5 ? 5.0 : q < 1.5 ? 8.0 : q < 2.5 ? 3.0 : 9.0; }
float quarter(float angle) { return mod(floor(angle / 0.7853982 + 0.5) + 8.0, 4.0); }
float pick(float r, float a, float b, float c, float d) {
    float i = floor(r * 4.0);
    return i < 1.0 ? a : i < 2.0 ? b : i < 3.0 ? c : d;
}
// The mixed set: eight steps of light, each with a few glyphs of that weight.
float mixed(float l, float r) {
    if (l < 0.08) return r < 0.25 ? 1.0 : 0.0;
    if (l < 0.20) return pick(r, 1.0, 2.0, 23.0, 2.0);
    if (l < 0.32) { float i = floor(r * 5.0); return i < 1.0 ? 2.0 : i < 2.0 ? 10.0 : i < 3.0 ? 3.0 : i < 4.0 ? 11.0 : 12.0; }
    if (l < 0.44) { float i = floor(r * 6.0); return i < 1.0 ? 3.0 : i < 2.0 ? 13.0 : i < 3.0 ? 14.0 : i < 4.0 ? 15.0 : i < 5.0 ? 16.0 : 11.0; }
    if (l < 0.58) { float i = floor(r * 5.0); return i < 2.0 ? 16.0 : i < 3.0 ? 17.0 : i < 4.0 ? 40.0 : 16.0; }
    if (l < 0.74) return pick(r, 17.0, 18.0, 16.0, 18.0);
    if (l < 0.90) return pick(r, 18.0, 19.0, 18.0, 19.0);
    return r < 0.667 ? 20.0 : 19.0;
}
vec3 turn(vec3 c, float angle) {
    vec3 k = vec3(0.57735);
    return c * cos(angle) + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - cos(angle));
}

void main() {
    vec2 cell = floor(qt_TexCoord0 * u.grid.xy);
    vec2 uv = (cell + 0.5) / u.grid.xy;
    vec4 key = textureLod(stats, vec2(0.25, 0.5), 0.0);
    vec2 levels = textureLod(stats, vec2(0.75, 0.5), 0.0).rg;
    vec4 me = subject(cell, key);
    float l = level(me.rgb, levels);

    // The structure tensor of the light around the cell, smoothed over its eight neighbours: how strong an edge
    // is here, how much it keeps one direction, and which.
    float a = 0.0, b = 0.0, e = 0.0;
    for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
        vec2 n = cell + vec2(float(i), float(j));
        float gx = (lit(n + vec2(1.0, 0.0), key, levels) - lit(n - vec2(1.0, 0.0), key, levels)) * 0.5;
        float gy = (lit(n + vec2(0.0, 1.0), key, levels) - lit(n - vec2(0.0, 1.0), key, levels)) * 0.5;
        float w = (i == 0 && j == 0) ? 1.0 : 0.5;
        a += w * gx * gx;
        b += w * gy * gy;
        e += w * gx * gy;
    }
    a /= 5.0; b /= 5.0; e /= 5.0;
    float energy = min(1.0, sqrt(a + b) * 3.0) * u.chars.z;
    float coherence = sqrt((a - b) * (a - b) + 4.0 * e * e) / (a + b + 0.00001);
    float q = quarter(0.5 * atan(2.0 * e, a - b + 0.0000001));

    float r = hash(cell);
    if (u.chars.w > 0.0) {
        float tick = floor(u.clock.x * 7.0 * max(1.0, u.chars.w));
        if (hash(cell + tick * 0.37) < 0.2 * u.chars.w) r = hash(cell * 1.7 + tick);
    }

    float glyph = 0.0, light = 0.0;
    bool stroke = false;
    vec3 colour = u.accent.rgb;
    if (me.a > 0.5) {
        if (energy > 0.5 && coherence > 0.42) {
            glyph = l > 0.72 && q < 0.5 ? 21.0 : l > 0.72 && q > 1.5 && q < 2.5 ? 22.0 : bold(q);
            stroke = true;
        } else if (energy > 0.2 && coherence > 0.45 && l < 0.8) {
            glyph = thin(q);
            stroke = true;
        } else if (u.grid.z < 0.5) {
            glyph = mixed(l, r);
        } else if (u.grid.z < 1.5) {
            glyph = l < 0.1 ? 0.0 : l > 0.62 ? bold(q) : thin(q);
        } else if (u.grid.z < 2.5) {
            float i = floor(l * (u.chars.y + 1.0)) - 1.0;
            glyph = i < 0.0 ? 0.0 : u.chars.x + min(i, u.chars.y - 1.0);
        } else {
            glyph = l < 0.06 ? 0.0 : u.chars.x + floor(r * u.chars.y);
        }
        light = glyph < 0.5 ? 0.0 : mix(0.42, 1.0, l);
        if (stroke) light = max(light, 0.6);

        if (u.tone.x > 0.5) {
            vec3 n = me.rgb / max(max(me.r, max(me.g, me.b)), 0.02);
            colour = clamp(mix(vec3(luma(n)), n, u.tone.z), 0.0, 1.0);
            colour = mix(colour, vec3(1.0), smoothstep(0.78, 1.0, l) * 0.55);
        } else {
            colour = l < 0.5 ? mix(u.low.rgb, u.mid.rgb, l * 2.0) : mix(u.mid.rgb, u.high.rgb, l * 2.0 - 1.0);
            if (stroke && l < 0.6) colour = mix(colour, u.accent.rgb, 0.7);
        }
    } else if (u.cut.z > 0.5) {
        // Just outside the subject: a faint line that follows its contour.
        float left = subject(cell - vec2(1.0, 0.0), key).a, right = subject(cell + vec2(1.0, 0.0), key).a;
        float up = subject(cell - vec2(0.0, 1.0), key).a, down = subject(cell + vec2(0.0, 1.0), key).a;
        if (max(max(left, right), max(up, down)) > 0.5) {
            glyph = thin(quarter(atan(down - up, right - left + 0.0000001)));
            light = 0.24;
        }
    }

    float angle = u.hue.x + u.hue.y * (uv.x + uv.y * 0.5) + u.clock.x * u.hue.z * 0.1111;
    if (angle != 0.0) colour = clamp(turn(colour, angle * 6.2831853), 0.0, 1.0);

    if (u.hue.w > 0.0) {
        // Digit rain: each column drops a head with a fading tail of digits.
        float speed = 0.5 + hash(vec2(cell.x, 3.0));
        float tail = 6.0 + 10.0 * hash(vec2(cell.x, 9.0));
        float head = fract(u.clock.x * speed * 0.11 + hash(vec2(cell.x, 5.0))) * (u.grid.y + tail);
        float behind = head - cell.y;
        if (behind >= 0.0 && behind < tail) {
            float k = (1.0 - behind / tail) * u.hue.w;
            float tick = floor(u.clock.x * 11.0);
            if (hash(cell + tick * 0.13) < k) glyph = 32.0 + floor(hash(cell * 2.3 + tick) * 10.0);
            light = max(light, k * (me.a > 0.5 ? 1.0 : 0.35));
            colour = mix(colour, behind < 1.0 ? vec3(1.0) : u.accent.rgb, k * 0.6);
        }
    }

    if (u.clock.y < 1.5) {
        // The intro: a front crosses the picture, digits flickering on it.
        float d = hash(cell * 0.71);
        if (u.cut.w < 1.5) d = ((1.0 - uv.y) + abs(uv.x - 0.5) * 0.5) / 1.25;
        else if (u.cut.w < 2.5) d = uv.y;
        else if (u.cut.w < 3.5) d = (cell.y + uv.x) / u.grid.y;
        else if (u.cut.w < 4.5) d = length((uv - 0.5) * vec2(u.clock.w, 1.0)) / length(vec2(u.clock.w, 1.0) * 0.5);
        float front = u.clock.y * 1.14 - d;
        if (front < 0.0) {
            glyph = 0.0;
            light = 0.0;
        } else {
            if (front < 0.11 && glyph > 0.5) {
                glyph = 32.0 + floor(hash(cell + floor(u.clock.y * 90.0)) * 10.0);
                light = max(light, 0.8);
            }
            light *= clamp(front / 0.025, 0.0, 1.0);
        }
    }
    fragColor = vec4(colour * light, glyph / 255.0);
}
