#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float time;
} ubuf;

layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

void main() {
    vec2 uv = qt_TexCoord0;
    float collapse = clamp(ubuf.progress * 2.0, 0.0, 1.0);
    float expand = clamp(ubuf.progress * 2.0 - 1.0, 0.0, 1.0);
    bool outgoing = ubuf.progress < 0.5;
    float energy = outgoing ? collapse : (1.0 - expand);
    float band = outgoing
        ? mix(0.5, 0.004, collapse)
        : mix(0.004, 0.5, expand);
    float distFromCenter = abs(uv.y - 0.5);

    vec3 base = outgoing ? texture(source1, uv).rgb : texture(source2, uv).rgb;

    // A CRT collapse should feel like phosphor persistence, not a compositor
    // blackout. Keep a dim ghost of the active frame outside the scan band so
    // there is always visual continuity through the midpoint.
    float ghostStrength = mix(1.0, 0.72, energy);
    float scanline = 0.985 + 0.015 * sin(uv.y * 1080.0 * 3.14159265);
    vec3 color = base * ghostStrength * scanline;

    if (distFromCenter < band) {
        vec2 sampleUv = vec2(
            uv.x,
            0.5 + ((uv.y - 0.5) / max(band / 0.5, 0.001))
        );
        vec3 compressed = outgoing
            ? texture(source1, sampleUv).rgb
            : texture(source2, sampleUv).rgb;
        float edgeGlow = smoothstep(band, band * 0.70, distFromCenter);
        vec3 glow = vec3(0.72, 0.84, 1.0) * edgeGlow * energy * 0.32;
        color = compressed + glow;
    }

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
