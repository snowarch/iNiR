#version 440
// Every dot of an IrisDotStrip in one pass. Dots sit on the along axis at start + i * pitch (pixel-snapped like the
// Rectangles they replace); each dot's fill comes from one animated level, so the 12 ms stagger is one number.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // Premultiplied (Qt hands a QML color to a shader premultiplied).
    vec4 fill;
    vec4 empty;
    vec4 knobFill;
    // xy: size in px, z: 1 vertical, w: 1 round dots (0 = square, AIRISU).
    vec4 box;
    // x: dot count, y: start, z: pitch, w: dot size.
    vec4 grid;
    // x: fill level in dots (dot i is lit by clamp(level - i)), y: knob size (0 none), z: knob centre along,
    // w: indeterminate head in dots (< -100 when not travelling).
    vec4 phase;
} u;

float cover(vec2 p, vec2 c, float size) {
    vec2 d = abs(p - c);
    float r = size * 0.5;
    if (u.box.w > 0.5)
        return clamp(r - length(d) + 0.5, 0.0, 1.0);
    vec2 e = clamp(r - d + 0.5, 0.0, 1.0);
    return e.x * e.y;
}

void main() {
    vec2 p = qt_TexCoord0 * u.box.xy;
    bool vertical = u.box.z > 0.5;
    float span = vertical ? u.box.y : u.box.x;
    float across = vertical ? u.box.x : u.box.y;
    float along = vertical ? p.y : p.x;
    float side = vertical ? p.x : p.y;
    vec2 q = vec2(along, side);
    float n = u.grid.x;
    float start = u.grid.y;
    float pitch = u.grid.z;
    float size = u.grid.w;
    float knob = u.phase.y;
    float canon = vertical ? span - along : along;
    float nearest = pitch > 0.0 ? floor((canon - start) / pitch + 0.5) : 0.0;
    float crossC = floor((across - size) * 0.5 + 0.5) + size * 0.5;
    vec4 c = vec4(0.0);
    for (int k = -1; k <= 1; k++) {
        float i = nearest + float(k);
        if (i < 0.0 || i > n - 1.0)
            continue;
        float pos = start + i * pitch;
        pos = vertical ? span - pos : pos;
        if (knob > 0.0 && abs(pos - u.phase.z) <= (knob + size) * 0.5 + 1.0)
            continue;
        float centre = floor(pos - size * 0.5 + 0.5) + size * 0.5;
        float a = cover(q, vec2(centre, crossC), size);
        if (a <= 0.0)
            continue;
        float lit = u.phase.w > -100.0 ? max(0.0, 1.0 - abs(i - u.phase.w) / 2.5) : clamp(u.phase.x - i, 0.0, 1.0);
        c = max(c, mix(u.empty, u.fill, lit) * a);
    }
    if (knob > 0.0) {
        float kc = floor(u.phase.z - knob * 0.5 + 0.5) + knob * 0.5;
        float kx = floor((across - knob) * 0.5 + 0.5) + knob * 0.5;
        float a = cover(q, vec2(kc, kx), knob);
        c = c * (1.0 - a * u.knobFill.a) + u.knobFill * a;
    }
    fragColor = c * u.qt_Opacity;
}
