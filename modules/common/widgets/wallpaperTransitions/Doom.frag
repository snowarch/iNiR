#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float time;
} ubuf;

layout(binding = 1) uniform sampler2D fromImage;
layout(binding = 2) uniform sampler2D toImage;

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float columns = 72.0;
    float column = floor(uv.x * columns);
    float rnd = hash11(column + 11.0);
    float rnd2 = hash11(column + 47.0);

    // Stagger each column while still guaranteeing exact old/new endpoints.
    float localProgress = clamp(ubuf.progress * 1.30 - rnd * 0.30, 0.0, 1.0);
    float wobble = sin(column * 0.61 + ubuf.time * 2.0)
        * 0.018 * sin(ubuf.progress * 3.14159265);
    float front = clamp(localProgress + wobble, 0.0, 1.0);
    float feather = 0.010 + rnd2 * 0.010;
    float reveal = 1.0 - smoothstep(front - feather, front + feather, uv.y);

    // Stretch the outgoing frame only near the melt front. Sampling is clamped,
    // so the effect can never expose the sampler's black border.
    float edgeEnergy = exp(-abs(uv.y - front) * 48.0)
        * sin(ubuf.progress * 3.14159265);
    float drag = edgeEnergy * (0.018 + rnd * 0.040);
    vec2 oldUv = clamp(vec2(uv.x, uv.y + drag), 0.0, 1.0);

    vec3 oldColor = texture(fromImage, oldUv).rgb;
    vec3 newColor = texture(toImage, uv).rgb;
    vec3 color = mix(oldColor, newColor, reveal);

    // Restrained hot edge keeps the classic melt character without turning the
    // transition into a full-screen brightness pulse.
    vec3 edgeTint = vec3(0.16, 0.045, 0.015) * edgeEnergy * 0.45;
    color += edgeTint;

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
