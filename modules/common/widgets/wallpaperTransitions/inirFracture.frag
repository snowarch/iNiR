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
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

vec2 rotate2d(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c) * p;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 grid = vec2(10.0, 6.0);
    vec2 cellId = floor(uv * grid);
    vec2 cellUv = fract(uv * grid) - 0.5;
    float rnd = hash21(cellId + 3.7);
    float rnd2 = hash21(cellId.yx + 19.1);

    vec2 center = (cellId + 0.5) / grid;
    vec2 fromOrigin = center - ubuf.origin;
    fromOrigin.x *= max(1.0, ubuf.aspectRatio.x);
    float radial = length(fromOrigin);
    float threshold = clamp(ubuf.progress * 1.35 - radial * 0.36 - rnd * 0.18, 0.0, 1.0);
    float globalBlend = smoothstep(0.0, 1.0, ubuf.progress);
    float energy = sin(threshold * 3.14159265);

    float angle = (rnd - 0.5) * 0.22 * energy;
    vec2 rotated = rotate2d(cellUv, angle);
    vec2 shardUv = (cellId + rotated + 0.5) / grid;

    vec2 direction = normalize(fromOrigin + vec2(0.0001));
    direction.x /= max(1.0, ubuf.aspectRatio.x);
    float drift = (0.018 + rnd2 * 0.030) * energy;
    vec2 oldUv = clamp(shardUv + direction * drift, 0.0, 1.0);

    vec4 oldColor = texture(source1, oldUv);
    vec4 newColor = texture(source2, uv);

    float seamX = smoothstep(0.47, 0.50, abs(cellUv.x));
    float seamY = smoothstep(0.47, 0.50, abs(cellUv.y));
    float seam = max(seamX, seamY) * energy;
    vec3 shard = oldColor.rgb * (1.0 - seam * 0.24);
    float reveal = max(smoothstep(0.18, 0.88, threshold), globalBlend * 0.18);
    vec3 color = mix(shard, newColor.rgb, reveal);

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
