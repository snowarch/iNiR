#version 440
// What GlyphCompose needs to know of the whole picture, in two texels. Left: the background colour to cut away
// (alpha 1 when there is one). Right: the darkest and lightest levels of what is left, and its mean.
// After winchxyz/afterglyph (MIT): its border key and its 4 %/97 % levels, read here from a 16x16 grid of samples.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // x: background 0 by itself, 1 keep all, 2 remove dark, 3 remove light; y: 1 swaps light and dark, and a
    // quarter more says the subject is flat (a word): its darkest letter keeps a third of the ink;
    // zw: where the cut starts and ends, as a colour distance.
    vec4 mode;
} u;
layout(binding = 1) uniform sampler2D picture;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec3 sum = vec3(0.0), squares = vec3(0.0);
    float solid = 0.0;
    for (int j = 0; j < 16; j++) for (int i = 0; i < 16; i++) {
        if (i == 0 || i == 15 || j == 0 || j == 15) {
            vec4 s = textureLod(picture, (vec2(float(i), float(j)) + 0.5) / 16.0, 0.0);
            vec3 c = s.rgb / max(s.a, 0.001);
            sum += c * s.a;
            squares += c * c * s.a;
            solid += s.a;
        }
    }
    vec3 edge = sum / max(solid, 0.001);
    float spread = dot(max(squares / max(solid, 0.001) - edge * edge, 0.0), vec3(1.0));
    // A picture with its own transparency is already cut; a border of one flat colour is a background.
    bool opaque = solid > 57.0;
    vec4 key = vec4(edge, opaque && spread < 0.006 ? 1.0 : 0.0);
    if (u.mode.x > 2.5) key = vec4(key.a > 0.5 && luma(edge) > 0.6 ? edge : vec3(1.0), 1.0);
    else if (u.mode.x > 1.5) key = vec4(key.a > 0.5 && luma(edge) < 0.4 ? edge : vec3(0.0), 1.0);
    else if (u.mode.x > 0.5) key.a = 0.0;

    float weight = 0.0, mean = 0.0, square = 0.0;
    for (int j = 0; j < 16; j++) for (int i = 0; i < 16; i++) {
        vec4 s = textureLod(picture, (vec2(float(i), float(j)) + 0.5) / 16.0, 0.0);
        vec3 c = s.rgb / max(s.a, 0.001);
        float m = s.a;
        if (key.a > 0.5) m *= smoothstep(u.mode.z, u.mode.w, distance(c, key.rgb));
        float l = luma(c);
        if (u.mode.y > 0.5) l = 1.0 - l;
        weight += m;
        mean += l * m;
        square += l * l * m;
    }
    mean /= max(weight, 0.001);
    float sigma = sqrt(max(square / max(weight, 0.001) - mean * mean, 0.0));
    float low = clamp(mean - 1.8 * sigma, 0.0, 0.6);
    float high = clamp(mean + 2.0 * sigma, low + 0.15, 1.0);
    if (fract(u.mode.y) > 0.1) low = max(low - 0.5 * (high - low), 0.0);
    fragColor = qt_TexCoord0.x < 0.5 ? key : vec4(low, high, mean, 1.0);
}
