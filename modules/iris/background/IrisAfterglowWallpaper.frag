#version 440
// Runs when the wallpaper under it changes (IrisAfterglowWallpaper caches it): never bind it to anything that changes per frame.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // x: on, y: unused, z: bloom, w: signal (0..1).
    vec4 glowMix;
    // rgb: shadow hue; a: 1 on a paper scheme.
    vec4 glowShadow;
    // rgb: key light; a: atmosphere.
    vec4 glowLight;
    vec4 glowBloom;
    // xy: the drawn size in pixels; z: a texel of the bloom's mip level in uv; w: that level.
    vec4 frame;
} u;
layout(binding = 1) uniform sampler2D source;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = max(u.frame.xy, vec2(1.0));
    vec2 px = uv * size;
    float signal = u.glowMix.w;
    float bloom = u.glowMix.z;
    float atmosphere = u.glowLight.a;

    vec3 c = texture(source, uv).rgb;
    if (signal > 0.0) {
        vec2 step = vec2(1.0 / size.x, 0.0) * (1.0 + 2.5 * signal);
        vec3 smear = (texture(source, uv - 2.0 * step).rgb + texture(source, uv - step).rgb * 2.0 + c * 2.0
            + texture(source, uv + step).rgb * 2.0 + texture(source, uv + 2.0 * step).rgb) / 8.0;
        float y = mix(luma(c), luma(smear), 0.3 * signal);
        vec2 chroma = vec2(smear.b - luma(smear), smear.r - luma(smear));
        vec2 own = vec2(c.b - luma(c), c.r - luma(c));
        chroma = mix(own, chroma, signal) * (1.0 + 0.18 * signal);
        float r = y + chroma.y;
        float b = y + chroma.x;
        c = vec3(r, (y - 0.299 * r - 0.114 * b) / 0.587, b);
    }

    vec2 t = vec2(u.frame.z, u.frame.z * size.x / size.y);
    float lod = u.frame.w;
    vec3 soft = textureLod(source, uv, lod).rgb * 4.0
        + (textureLod(source, uv + vec2(t.x, 0.0), lod).rgb + textureLod(source, uv - vec2(t.x, 0.0), lod).rgb
         + textureLod(source, uv + vec2(0.0, t.y), lod).rgb + textureLod(source, uv - vec2(0.0, t.y), lod).rgb) * 2.0
        + textureLod(source, uv + t, lod).rgb + textureLod(source, uv - t, lod).rgb
        + textureLod(source, uv + vec2(t.x, -t.y), lod).rgb + textureLod(source, uv + vec2(-t.x, t.y), lod).rgb;
    soft /= 16.0;
    float bright = smoothstep(0.42, 0.95, luma(soft));
    vec3 spill = mix(soft, soft * u.glowBloom.rgb * 1.6, 0.35);
    c += spill * bright * bloom * 0.85 + soft * bloom * 0.1;

    float l = clamp(luma(c), 0.0, 1.0);
    vec3 key = u.glowLight.rgb / max(max(u.glowLight.r, max(u.glowLight.g, u.glowLight.b)), 1e-3);
    c += u.glowShadow.rgb * atmosphere * 0.32 * (1.0 - l) * (1.0 - l);
    c *= mix(vec3(1.0), mix(vec3(1.0), key, atmosphere * 0.5), smoothstep(0.15, 0.9, l));
    l = luma(c);
    c = mix(vec3(l), c, 1.0 + 0.22 * atmosphere);
    vec3 s = clamp(c, 0.0, 1.0);
    c = mix(c, s * s * (3.0 - 2.0 * s), 0.22 * atmosphere);

    float line = 0.5 + 0.5 * cos(6.2831853 * (px.y + 0.5) / 3.0);
    c *= 1.0 - signal * 0.3 * (1.0 - line) * (1.0 - 0.55 * clamp(l, 0.0, 1.0));
    vec2 q = uv - 0.5;
    c *= 1.0 - signal * 0.35 * smoothstep(0.25, 0.75, dot(q, q) * 2.0);

    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * u.qt_Opacity;
}
