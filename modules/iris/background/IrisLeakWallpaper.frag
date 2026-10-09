#version 440
// Light leak over the wallpaper: the light IrisField.frag exposes the bodies with, laid over the picture the way a
// leak lands on a print. Runs when the wallpaper under it changes (IrisLeakWallpaper caches it): never bind it to
// anything that changes per frame.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Same encoding as IrisField.frag, but leakMix.x is how much of the picture shows (0: the light alone, on the
    // darkroom's black) and leakMix.y how strongly it is exposed.
    vec4 leakMix;
    vec4 leakGrain;
    vec4 leakStop0; vec4 leakStop1; vec4 leakStop2; vec4 leakStop3; vec4 leakStop4;
    vec4 leakCore;
    vec4 leakAt0; vec4 leakAt1; vec4 leakAt2;
    vec4 leakForm0; vec4 leakForm1; vec4 leakForm2;
    vec4 leakHue0; vec4 leakHue1; vec4 leakHue2;
    // xy: the drawn size in pixels; z: a texel of the halation's mip level in uv; w: that level.
    vec4 frame;
    // x: how far the exposure has developed, 0 to 1 (a Polaroid rising out of its milky ground); y: how much dust and
    // bokeh, 0 to 2 (1 the default); z: how strongly the lens's corners and the film gate show, 0 to 1.
    vec4 film;
} u;
layout(binding = 1) uniform sampler2D source;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

// Copies of IrisField.frag's (IrisLeakPlate.frag keeps a third; this leakLight leaves out the direction the field
// reads its burn from): change all three.
float leakHash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float leakNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(leakHash(i), leakHash(i + vec2(1.0, 0.0)), f.x),
               mix(leakHash(i + vec2(0.0, 1.0)), leakHash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 leakRamp(float t) {
    float s = clamp(t, 0.0, 1.0) * 4.0;
    vec3 a = s < 1.0 ? u.leakStop0.rgb : s < 2.0 ? u.leakStop1.rgb : s < 3.0 ? u.leakStop2.rgb : u.leakStop3.rgb;
    vec3 b = s < 1.0 ? u.leakStop1.rgb : s < 2.0 ? u.leakStop2.rgb : s < 3.0 ? u.leakStop3.rgb : u.leakStop4.rgb;
    float f = s - min(floor(s), 3.0);
    return mix(a, b, f * f * (3.0 - 2.0 * f));
}

vec3 leakLight(vec2 at, vec2 size, float scatter, out vec3 wash) {
    float aspect = size.x / max(size.y, 1.0);
    vec2 q = at / max(size.y, 1.0);
    float prism = u.leakMix.w;
    vec3 sum = vec3(0.0);
    float tone = 0.0;
    float weights = 0.0;
    for (int i = 0; i < 3; ++i) {
        vec4 place = i == 0 ? u.leakAt0 : i == 1 ? u.leakAt1 : u.leakAt2;
        vec4 form = i == 0 ? u.leakForm0 : i == 1 ? u.leakForm1 : u.leakForm2;
        vec4 hue = i == 0 ? u.leakHue0 : i == 1 ? u.leakHue1 : u.leakHue2;
        if (form.y <= 0.0)
            continue;
        vec2 d = q - vec2(place.x * aspect, place.y);
        float c = cos(form.x);
        float s = sin(form.x);
        d = vec2(c * d.x + s * d.y, c * d.y - s * d.x) / max(place.zw, vec2(1e-3));
        float rho = length(d);
        float up = -d.y / max(rho, 1e-4);
        float t = hue.x + hue.y * rho + hue.z * up * min(1.0, rho * 2.5) + hue.w * d.x;
        float strength = form.y * max(0.0, 1.0 + form.w * up);
        float weight = strength / (1.0 + 2.0 * rho * rho);
        tone += weight * t;
        weights += weight;
        vec3 ramp = leakRamp(t) * strength;
        for (int ch = 0; ch < 3; ++ch) {
            float spread = float(ch - 1);
            float r = rho * (1.0 + prism * 0.07 * spread);
            // The grain scatters where the shape ends, so its edge dissolves into grain instead of ending.
            float x = (form.z > 0.0 ? (r - 1.0) / form.z : r) * (1.0 + scatter);
            float x2 = x * x;
            // A body of light with a soft shoulder and a faint glow past it: light that leaks has no hard edge.
            float fall = exp(-1.6 * x2 * (1.0 + x2)) + 0.1 / (1.0 + 5.0 * x2);
            sum[ch] += ramp[ch] * fall;
        }
    }
    float streak = 0.5 * leakNoise(vec2(at.x / 7.0, at.y / 260.0)) + 0.5 * leakNoise(vec2(at.x / 23.0, at.y / 140.0));
    sum *= mix(1.0, 0.5 + streak, u.leakGrain.y);
    // Exposed like film: the hue holds while the light rises.
    float peak = max(sum.r, max(sum.g, sum.b));
    float exposed = 1.0 - exp(-1.4 * peak);
    vec3 hue = sum / max(peak, 1e-4);
    // The colour every point takes, lit or not: the light's own hue where it is strong, the grade where it fades,
    // at full saturation (max channel 1). It is what turns a body into a grain gradient.
    // It drifts along the grade across the screen, so each body carries its own stretch of the gradient.
    float drift = (0.6 * at.x / max(size.x, 1.0) + 0.4 * at.y / max(size.y, 1.0) - 0.5) * 0.5;
    vec3 grade = leakRamp((weights > 1e-4 ? tone / weights : 0.0) + drift);
    wash = mix(grade, hue, smoothstep(0.05, 0.6, exposed));
    wash /= max(max(wash.r, max(wash.g, wash.b)), 1e-3);
    // Its core runs to the grade's own white: the colour lives where the light fades, as on film.
    return mix(hue * exposed, u.leakCore.rgb * exposed, 0.6 * smoothstep(0.5, 1.0, exposed));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = max(u.frame.xy, vec2(1.0));
    vec2 px = uv * size;
    vec2 cell = floor(px);
    float picture = u.leakMix.x;
    float expose = u.leakMix.y;
    float spill = u.leakMix.z;
    float grain = u.leakGrain.x;
    float g = 0.6 * leakHash(cell) + 0.4 * leakNoise(px / max(1.0, u.leakGrain.z)) - 0.5;
    vec3 wash;
    vec3 leak = leakLight(px, size, g * grain, wash);
    float lv = max(leak.r, max(leak.g, leak.b));

    // The darkroom's black: warm, a breath of the grade's deep end in it.
    vec3 deep = u.leakStop4.rgb * 0.05 + vec3(0.03, 0.022, 0.018);

    // A faded print: a little colour leaves, the blacks lift into the darkroom's, the whites roll off. Away from the
    // light it sinks into that black; where the light lands it holds, so any picture reads as exposed by the leak.
    vec3 c = texture(source, uv).rgb;
    c = mix(vec3(luma(c)), c, 0.86);
    c = deep + c * (vec3(1.0) - deep);
    c = c * 1.12 / (vec3(1.0) + 0.12 * c);
    float held = 0.3 + 0.7 * smoothstep(0.0, 0.75, lv);
    c = mix(c, deep + (c - deep) * held, expose);

    // Halation: the picture's own highlights glow warm past themselves, from a small copy of the same frame.
    vec2 t = vec2(u.frame.z, u.frame.z * size.x / size.y);
    float lod = u.frame.w;
    vec3 soft = textureLod(source, uv, lod).rgb * 4.0
        + (textureLod(source, uv + vec2(t.x, 0.0), lod).rgb + textureLod(source, uv - vec2(t.x, 0.0), lod).rgb
         + textureLod(source, uv + vec2(0.0, t.y), lod).rgb + textureLod(source, uv - vec2(0.0, t.y), lod).rgb) * 2.0
        + textureLod(source, uv + t, lod).rgb + textureLod(source, uv - t, lod).rgb
        + textureLod(source, uv + vec2(t.x, -t.y), lod).rgb + textureLod(source, uv + vec2(-t.x, t.y), lod).rgb;
    soft /= 16.0;
    float bright = smoothstep(0.5, 0.95, luma(soft));
    c += mix(u.leakStop1.rgb, vec3(1.0, 0.32, 0.12), 0.45) * bright * spill * 0.32 * expose;

    // Without the picture the darkroom alone, faintly toned by the grade: the leak is the whole image, as on the
    // textures it comes from.
    c = mix(deep + wash * 0.035, c, picture);

    // The leak, screen-blended as a light layer over a print is.
    vec3 l = clamp(leak * mix(1.0, 0.45 + 0.75 * expose, picture), 0.0, 1.0);
    c = vec3(1.0) - (vec3(1.0) - clamp(c, 0.0, 1.0)) * (vec3(1.0) - l);

    // Bokeh: a few out-of-focus discs of the grade in the dark, a lens's onion ring at their rim, a glow around them.
    vec2 bokehCell = floor(px / 300.0);
    if (leakHash(bokehCell + 3.0) > 0.8) {
        vec2 centre = (bokehCell + 0.35 + 0.3 * vec2(leakHash(bokehCell + 5.0), leakHash(bokehCell + 9.0))) * 300.0;
        float radius = 34.0 + 50.0 * leakHash(bokehCell + 13.0);
        float d = length(px - centre);
        float disc = (1.0 - smoothstep(radius - 5.0, radius + 2.0, d)) * (0.5 + 0.5 * smoothstep(0.3 * radius, radius, d));
        float halo = exp(-max(d - radius, 0.0) / (radius * 0.5)) * 0.25;
        vec3 hueOf = leakRamp(leakHash(bokehCell + 17.0));
        hueOf /= max(max(hueOf.r, max(hueOf.g, hueOf.b)), 1e-3);
        vec3 glow = hueOf * (disc + halo) * (0.07 + 0.11 * leakHash(bokehCell + 19.0))
            * min(1.0, grain * 1.6) * mix(1.0, 0.55, picture) * (1.0 - clamp(luma(c) * 1.3, 0.0, 1.0)) * u.film.y;
        c = vec3(1.0) - (vec3(1.0) - c) * (vec3(1.0) - clamp(glow, 0.0, 1.0));
    }

    // Grain, strongest in the mid-tones where film shows it, a little of it coloured.
    float lum = clamp(luma(c), 0.0, 1.0);
    vec3 chroma = vec3(leakHash(cell + 31.0), leakHash(cell + 57.0), leakHash(cell + 83.0)) - 0.5;
    c += (g * (0.45 + 2.4 * lum * (1.0 - lum)) * 0.28 + 0.01) * grain + chroma * grain * 0.06;

    // Dust: a few motes caught in the dark, as on a scanned negative.
    vec2 mote = floor(px / 3.0);
    vec2 inMote = fract(px / 3.0) - 0.5;
    float speck = step(1.0 - 0.0018 * u.film.y, leakHash(mote + 7.0)) * (0.4 + 0.6 * leakHash(mote + 11.0));
    c += speck * (1.0 - smoothstep(0.3, 0.5, length(inMote))) * grain * 0.7 * (1.0 - clamp(luma(c) * 1.6, 0.0, 1.0))
        * step(0.001, u.film.y);

    // The corners fall off as a lens's do; without the picture the film gate shows too, soft and a little uneven, as
    // a scan of a negative does.
    vec2 q = uv - 0.5;
    c *= 1.0 - mix(0.3, 0.22 * expose, picture) * smoothstep(0.2, 0.8, dot(q, q) * 2.0) * u.film.z;
    float edge = min(min(px.x, size.x - px.x), min(px.y, size.y - px.y)) + (leakNoise(px / 37.0) - 0.5) * 14.0;
    c *= mix(1.0, smoothstep(0.0, 34.0, edge), (1.0 - picture) * u.film.z);

    // A Polaroid developing: the exposure rises out of a milky ground, the shadows first, the colour last.
    float developed = u.film.x;
    if (developed < 1.0) {
        float shade = smoothstep(0.0, 0.8, developed + 0.3 * (1.0 - luma(c)) - 0.15);
        c = mix(vec3(luma(c)), c, smoothstep(0.35, 1.0, developed));
        c = mix(vec3(0.71, 0.74, 0.70), c, shade);
    }

    // Under one 8-bit level of dither: a dark gradient this soft bands into rings without it.
    c += (fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715)))) - 0.5) / 255.0;
    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * u.qt_Opacity;
}
