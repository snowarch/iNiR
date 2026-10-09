#version 440
// A plate of Light leak film for a surface IrisField does not draw (desktop widgets, IrisSurface): the light, grain and
// burn of the field's bodies, sampled where the plate sits on its output, so it reads as the same film. Static: it
// draws again only when its window does.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Same encoding as IrisField.frag.
    vec4 leakMix;
    vec4 leakGrain;
    vec4 leakStop0; vec4 leakStop1; vec4 leakStop2; vec4 leakStop3; vec4 leakStop4;
    vec4 leakCore;
    vec4 leakAt0; vec4 leakAt1; vec4 leakAt2;
    vec4 leakForm0; vec4 leakForm1; vec4 leakForm2;
    vec4 leakHue0; vec4 leakHue1; vec4 leakHue2;
    // xy: the plate's top-left on its output, zw: the output's size, in pixels.
    vec4 plate;
    // x, y: the plate's size; w: how deep the edge that faces the light burns, in pixels (IrisStyle.leakBody.x).
    vec4 body;
    // Corner radii: top-left, top-right, bottom-right, bottom-left.
    vec4 corners;
    // The plate's own colour, not premultiplied: a light one is photo paper, a dark one film.
    vec4 tone;
} u;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Copies of IrisField.frag's (IrisLeakWallpaper.frag keeps a third): change all three.
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

vec3 leakLight(vec2 at, vec2 size, float scatter, out vec3 wash, out vec2 toward) {
    float aspect = size.x / max(size.y, 1.0);
    vec2 q = at / max(size.y, 1.0);
    float prism = u.leakMix.w;
    vec3 sum = vec3(0.0);
    float tone = 0.0;
    float weights = 0.0;
    vec2 from = vec2(0.0);
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
        vec2 slope = d / max(place.zw, vec2(1e-3));
        slope = vec2(c * slope.x - s * slope.y, s * slope.x + c * slope.y);
        from -= slope / max(length(slope), 1e-4) * weight;
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
    toward = from / max(length(from), 1e-4);
    // Its core runs to the grade's own white: the colour lives where the light fades, as on film.
    return mix(hue * exposed, u.leakCore.rgb * exposed, 0.6 * smoothstep(0.5, 1.0, exposed));
}

void main() {
    vec2 local = qt_TexCoord0 * u.body.xy;
    vec2 halfSize = u.body.xy * 0.5;
    vec4 r = u.corners;
    float radius = min(local.x < halfSize.x ? (local.y < halfSize.y ? r.x : r.w) : (local.y < halfSize.y ? r.y : r.z),
                       min(halfSize.x, halfSize.y));
    vec2 corner = abs(local - halfSize) - halfSize + radius;
    float sd = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - radius;
    // Derivatives before any early return: the edge's outward normal in item space (y down on every backend).
    vec2 dp = vec2(dFdx(local.x), dFdy(local.y));
    vec2 slope = vec2(dFdx(sd), dFdy(sd)) / vec2(abs(dp.x) > 1e-6 ? dp.x : 1.0, abs(dp.y) > 1e-6 ? dp.y : 1.0);
    float coverage = 1.0 - smoothstep(-0.7, 0.7, sd);
    if (coverage <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    vec2 frameP = u.plate.xy + local;
    vec2 size = max(u.plate.zw, vec2(1.0));
    float light = u.leakMix.y;
    float grain = u.leakGrain.x;
    float prism = u.leakMix.w;
    vec2 cell = floor(frameP);
    float g = 0.6 * leakHash(cell) + 0.4 * leakNoise(frameP / max(1.0, u.leakGrain.z)) - 0.5;
    vec3 chroma = vec3(leakHash(cell + 31.0), leakHash(cell + 57.0), leakHash(cell + 83.0)) - 0.5;
    vec3 wash;
    vec2 toward;
    vec3 leak = leakLight(frameP, size, g * grain, wash, toward);
    // The same film as IrisField.frag's solid bodies: change both.
    float facing = smoothstep(-0.1, 0.8, dot(slope / max(length(slope), 1e-4), toward));
    float depth = max(0.0, -sd);
    float lip = max(1.0, u.body.w);
    vec3 base = u.tone.rgb;
    bool paper = luma(base) > 0.5;
    float lv = max(leak.r, max(leak.g, leak.b));
    float grained = clamp(lv + g * grain * 0.12, 0.0, 1.0);
    float burn = light * lv * facing * exp(-depth / lip);
    // A lit edge splits the light as a cut prism does: the grade's spectrum across the first pixels in, its warm end
    // outermost. Only where the light is strong and the edge faces it.
    float band = clamp(depth / (1.5 + 4.0 * prism), 0.0, 1.0);
    float split = smoothstep(0.3, 0.8, lv) * facing * light * prism * (1.0 - band) * (1.0 - band) * 1.6;
    vec3 spectrum = leakRamp(band);
    const vec3 lumaW = vec3(0.2126, 0.7152, 0.0722);
    vec3 material;
    if (paper) {
        // Photo paper toned by the light: the grade's pastel everywhere, the light's own colour where it lands, lifted
        // toward white there, warmer at the edge it enters by. Never darker than dark ink reads on (4.5:1).
        vec3 pastel = mix(vec3(1.0), wash, 0.6);
        material = mix(base, base * pastel * 1.05, min(1.0, light * (0.6 + 0.5 * grained)));
        material *= mix(vec3(1.0), leak / max(lv, 1e-3), 0.35 * lv * light);
        material += (vec3(1.0) - material) * leak * light * 0.45;
        material *= mix(vec3(1.0), wash, 0.5 * burn);
        material *= mix(vec3(1.0), spectrum * 1.15, min(1.0, split * 0.6));
        material *= 1.0 + g * grain * 0.2;
        material += chroma * grain * 0.035;
        float lum = dot(material * material, lumaW);
        material = mix(material, vec3(1.0), max(0.0, 0.24 - lum) / max(1.0 - lum, 1e-3));
    } else {
        // Smoked film over the light: the light's own hue comes through at full saturation (never its white core), rolled
        // off toward the luminance light text reads on slowly enough that the light keeps its shape.
        material = base * 0.7 + u.leakStop4.rgb * 0.035 + vec3(0.014, 0.010, 0.008);
        material += wash * (0.75 * lv + 0.3 + 0.4 * grained) * light;
        float lum = dot(material * material, lumaW);
        float held = 0.16 * lum / (lum + 0.16);
        material *= sqrt(held / max(lum, 1e-5));
        material += (g * (0.06 + 0.9 * sqrt(held)) + 0.012) * grain + chroma * grain * 0.04;
        material += leak * burn + spectrum * split * 0.8;
    }
    material += (ign(cell) - 0.5) / 255.0;
    float alpha = u.tone.a * coverage * u.qt_Opacity;
    fragColor = vec4(clamp(material, 0.0, 1.0) * alpha, alpha);
}
