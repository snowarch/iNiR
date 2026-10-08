#version 440
// A body's light (IrisLightWash): its identity colour at full on the joined side, a third of it at 45 % of the fall,
// gone at the fall. A long, faint ramp over a dark body bands in eight bits; a dither under one level breaks it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The stops' colours, premultiplied (Qt hands a QML color to a shader premultiplied).
    vec4 strong;
    vec4 fading;
    // x: where the fading stop sits, y: where the light is gone (0..1 along the axis), z: 1 across (from the left or
    // right), w: 1 reversed (from the bottom or right).
    vec4 ramp;
    // xy: size in pixels, z: corner radius (0 inside a clip, which rounds it), w: unused.
    vec4 box;
} u;

float ign(vec2 p) {
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
    float t = u.ramp.z > 0.5 ? qt_TexCoord0.x : qt_TexCoord0.y;
    if (u.ramp.w > 0.5)
        t = 1.0 - t;
    float fadeAt = max(u.ramp.x, 1e-4);
    float goneAt = max(u.ramp.y, fadeAt + 1e-4);
    vec4 c = t < fadeAt ? mix(u.strong, u.fading, t / fadeAt)
        : mix(u.fading, vec4(0.0), clamp((t - fadeAt) / (goneAt - fadeAt), 0.0, 1.0));
    vec2 px = qt_TexCoord0 * u.box.xy;
    float coverage = 1.0;
    if (u.box.z > 0.0) {
        vec2 half_ = 0.5 * u.box.xy;
        float r = min(u.box.z, min(half_.x, half_.y));
        vec2 q = abs(px - half_) - (half_ - r);
        float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
        coverage = 1.0 - smoothstep(-0.7, 0.7, d);
    }
    c *= coverage * u.qt_Opacity;
    float n = c.a > 0.0 ? (ign(floor(px)) - 0.5) / 255.0 : 0.0;
    fragColor = max(c + vec4(n), vec4(0.0));
}
