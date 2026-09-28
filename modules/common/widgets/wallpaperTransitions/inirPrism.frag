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
    const float slices = 13.0;
    float diagonalX = uv.x + (uv.y - 0.5) * 0.16;
    float sliceId = floor(diagonalX * slices);
    float local = fract(diagonalX * slices);
    float randomPhase = hash11(sliceId + 3.7);

    float delay = (sliceId / slices) * 0.34 + randomPhase * 0.13;
    float localProgress = smoothstep(delay, min(1.0, delay + 0.55), ubuf.progress);
    float energy = sin(localProgress * 3.14159265);

    float direction = mod(sliceId, 2.0) < 1.0 ? -1.0 : 1.0;
    vec2 offset = vec2(direction * (1.0 - localProgress) * 0.055, 0.0);
    offset.y += (randomPhase - 0.5) * (1.0 - localProgress) * 0.025;

    float edgeDistance = min(local, 1.0 - local);
    float edgeGlow = 1.0 - smoothstep(0.0, 0.12, edgeDistance);
    edgeGlow *= energy;

    vec2 newUv = clamp(uv + offset, 0.0, 1.0);
    float chromaShift = 0.0025 + edgeGlow * 0.0075;
    vec3 newBase = texture(source2, newUv).rgb;
    vec3 prism = vec3(
        texture(source2, clamp(newUv + vec2(chromaShift, 0.0), 0.0, 1.0)).r,
        newBase.g,
        texture(source2, clamp(newUv - vec2(chromaShift, 0.0), 0.0, 1.0)).b
    );

    vec3 oldColor = texture(source1, uv).rgb;
    vec3 newColor = mix(newBase, prism, edgeGlow * 0.72);
    vec3 color = mix(oldColor, newColor, localProgress);
    color += vec3(0.020, 0.030, 0.055) * edgeGlow;

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
