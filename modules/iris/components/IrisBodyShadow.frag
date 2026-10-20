#version 440
// A cut body's soft shadow (IrisBodyShadow): RectangularShadow's falloff (Qt's rectangularshadow.frag, the CSS
// box-shadow ramp) laid on the distance to the body's own outline (IrisField.frag cutBox). Qt's shrinks the box by most
// of the blur and measures from there, so every corner comes out round: under a body cut at 45° with two square
// corners, its shade went missing at the square ones. Measured from the outline, straight edges ramp the same and each
// corner keeps its shape.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Premultiplied, as Qt hands a QML color to a shader.
    vec4 shade;
    // xy: the effect's size in pixels, z: how far it reaches past the body on each side, w: spread.
    vec4 box;
    // x: the cut's leg, y: the blur (RectangularShadow.blur), z: which corners the blade takes (IrisField.frag cutsCorner).
    vec4 cut;
} u;

bool cutsCorner(vec2 d, float mask) {
    if (mask > -0.5) return d.x * d.y < 0.0;
    if (mask > -1.5) return d.y < 0.0;
    if (mask > -2.5) return d.y > 0.0;
    if (mask > -3.5) return d.x < 0.0;
    return d.x > 0.0;
}

float cutBox(vec2 p, vec2 centre, vec2 halfSize, float cut, float mask) {
    vec2 d = p - centre;
    vec2 q = abs(d) - halfSize;
    float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
    cut = min(cut, min(halfSize.x, halfSize.y));
    if (cut > 0.5 && cutsCorner(d, mask))
        box = max(box, (abs(d.x) + abs(d.y) - (halfSize.x + halfSize.y - cut)) * 0.70710678);
    return box;
}

void main() {
    vec2 p = qt_TexCoord0 * u.box.xy;
    vec2 centre = u.box.xy * 0.5;
    vec2 halfSize = max(centre - vec2(u.box.z), vec2(0.5));
    // Qt's ramp: full until 0.8 blur inside the edge, gone 1.3 blur outside it, squared.
    float d = cutBox(p, centre, halfSize, u.cut.x, u.cut.z) - u.box.w + 0.8 * u.cut.y;
    float a = 1.0 - smoothstep(0.0, max(1.0, 2.1 * u.cut.y), d);
    fragColor = u.shade * (a * a) * u.qt_Opacity;
}
