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

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float columns = 42.0;
    float column = floor(uv.x * columns);
    float jitter = hash11(column + 17.0);
    float wave = 0.035 * sin(column * 0.73 + ubuf.time * 2.2);
    float localProgress = clamp(ubuf.progress * 1.28 - jitter * 0.28, 0.0, 1.0);
    float edge = localProgress + wave * sin(ubuf.progress * 3.14159265);
    float feather = 0.018 + 0.010 * jitter;
    float reveal = smoothstep(edge - feather, edge + feather, uv.y);

    float drag = (1.0 - localProgress) * (0.016 + jitter * 0.028);
    vec2 oldUv = clamp(vec2(uv.x, uv.y - drag), 0.0, 1.0);
    vec2 newUv = clamp(vec2(uv.x, uv.y + drag * 0.35), 0.0, 1.0);

    vec4 oldColor = texture(source1, oldUv);
    vec4 newColor = texture(source2, newUv);

    float ember = exp(-abs(uv.y - edge) * 90.0) * sin(ubuf.progress * 3.14159265);
    vec3 edgeTint = vec3(0.12, 0.05, 0.18) * ember * (0.35 + jitter * 0.35);
    vec3 color = mix(newColor.rgb, oldColor.rgb, reveal) + edgeTint;
    fragColor = vec4(color, mix(newColor.a, oldColor.a, reveal)) * ubuf.qt_Opacity;
}
