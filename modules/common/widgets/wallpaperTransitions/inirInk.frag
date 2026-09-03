#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float time;
    vec2 aspectRatio;
    vec2 origin;
} ubuf;

layout(binding = 1) uniform sampler2D source1;
layout(binding = 2) uniform sampler2D source2;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + 1.0), f.x), f.y);
}

float inkNoise(vec2 p) {
    float n = 0.0;
    n += noise2(p * 3.0) * 0.56;
    n += noise2(p * 7.0 + 11.7) * 0.29;
    n += noise2(p * 15.0 - 4.2) * 0.15;
    return n;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = max(1.0, ubuf.aspectRatio.x);
    vec2 p = uv - ubuf.origin;
    p.x *= aspect;

    float travel = uv.x * 0.78 + uv.y * 0.22;
    float organic = (inkNoise(vec2(p.x / aspect, p.y) + vec2(ubuf.time * 0.018, 0.0)) - 0.5) * 0.34;
    float threshold = mix(-0.24, 1.24, ubuf.progress);
    float field = travel + organic;
    float reveal = 1.0 - smoothstep(threshold - 0.075, threshold + 0.075, field);

    float edge = 1.0 - smoothstep(0.015, 0.105, abs(field - threshold));
    edge *= sin(ubuf.progress * 3.14159265);

    vec3 oldColor = texture(source1, uv).rgb;
    vec3 newColor = texture(source2, uv).rgb;
    vec3 color = mix(oldColor, newColor, reveal);

    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 inkTint = mix(color, vec3(luminance) * vec3(0.72, 0.76, 0.84), 0.58);
    color = mix(color, inkTint, edge * 0.38);
    color *= 1.0 - edge * 0.16;

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
