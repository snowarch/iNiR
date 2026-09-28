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

float softBand(float x, float center, float halfWidth) {
    return 1.0 - smoothstep(halfWidth * 0.45, halfWidth, abs(x - center));
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 p = uv - 0.5;
    p.x *= max(1.0, ubuf.aspectRatio.x);

    float diagonal = (p.x * 0.72 + p.y * 0.58) / max(1.0, ubuf.aspectRatio.x);
    float sweep = mix(-0.85, 0.85, ubuf.progress);
    float edge = diagonal - sweep;
    float reveal = smoothstep(0.075, -0.075, edge);
    float globalBlend = smoothstep(0.0, 1.0, ubuf.progress);

    float energy = sin(ubuf.progress * 3.14159265);
    float fringe = softBand(diagonal, sweep, 0.16) * energy;
    vec2 tangent = normalize(vec2(0.58, -0.72));
    vec2 shift = tangent * (0.004 + 0.008 * fringe);

    vec3 oldColor = texture(source1, uv).rgb;
    vec3 nr = texture(source2, clamp(uv + shift, 0.0, 1.0)).rgb;
    vec3 ng = texture(source2, uv).rgb;
    vec3 nb = texture(source2, clamp(uv - shift, 0.0, 1.0)).rgb;
    vec3 chroma = vec3(nr.r, ng.g, nb.b);

    vec3 newColor = mix(ng, chroma, fringe * 0.72);
    float blend = max(reveal, globalBlend * 0.22);
    vec3 color = mix(oldColor, newColor, blend);
    color += vec3(0.035, 0.020, 0.060) * fringe;

    fragColor = vec4(color, 1.0) * ubuf.qt_Opacity;
}
