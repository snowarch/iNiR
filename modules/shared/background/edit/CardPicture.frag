#version 440
// The desktop as a card: the full-size picture brought down to the card's pixels through a tent of nine taps (a
// mipmap blends in the half-size level and blurs text; a plain fetch aliases it), cut by the card's shape.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Half a card pixel, in the picture's uv. Zero while the card travels: the mipmapped fetch alone.
    vec2 reach;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskSource;

void main() {
    vec2 uv = qt_TexCoord0;
    float cut = texture(maskSource, uv).a;
    if (reach.x <= 0.0) {
        fragColor = texture(source, uv) * cut * qt_Opacity;
        return;
    }
    vec2 dx = vec2(reach.x, 0.0);
    vec2 dy = vec2(0.0, reach.y);
    vec4 c = 4.0 * texture(source, uv)
        + 2.0 * (texture(source, uv + dx) + texture(source, uv - dx) + texture(source, uv + dy) + texture(source, uv - dy))
        + texture(source, uv + dx + dy) + texture(source, uv - dx - dy) + texture(source, uv + dx - dy) + texture(source, uv - dx + dy);
    fragColor = c * (cut * qt_Opacity / 16.0);
}
