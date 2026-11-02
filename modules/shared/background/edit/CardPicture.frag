#version 440
// The desktop as a card: the full-size picture brought down to the card's pixels through a tent of nine taps (a mipmap
// blends in the half-size level and blurs text; a picture drawn at the card's size aliases its glyphs), cut by the
// card's shape, worked out here (a rounded rect) with one card pixel
// of edge, so no mask picture has to be drawn and kept.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // The desktop's size, the corner in desktop px, and one card pixel in desktop px.
    vec2 size;
    float corner;
    float edge;
    // 0.2 of a card pixel in the picture's uv, at the card's scale of the moment: sharp from the first frame.
    vec2 reach;
};
layout(binding = 1) uniform sampler2D source;

float roundedCoverage(vec2 p) {
    vec2 half_ = size * 0.5;
    vec2 q = abs(p - half_) - (half_ - vec2(corner));
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
    return clamp(0.5 - d / edge, 0.0, 1.0);
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float cut = corner <= 0.0 ? 1.0 : roundedCoverage(p);
    vec2 uv = qt_TexCoord0;
    vec2 dx = vec2(reach.x, 0.0);
    vec2 dy = vec2(0.0, reach.y);
    vec4 c = 4.0 * texture(source, uv)
        + 2.0 * (texture(source, uv + dx) + texture(source, uv - dx) + texture(source, uv + dy) + texture(source, uv - dy))
        + texture(source, uv + dx + dy) + texture(source, uv - dx - dy) + texture(source, uv + dx - dy) + texture(source, uv - dx + dy);
    fragColor = c * (cut * qt_Opacity / 16.0);
}
