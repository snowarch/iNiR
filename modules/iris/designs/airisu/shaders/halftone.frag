#version 440
// AIRISU's halftone (網点): a picture printed in one ink as a screen of dots on a grid turned to `angle`. Each cell
// reads the picture at its centre and grows a dot whose area is that tone; a dot under `floorPx` across is not
// printed (it would read as dither). `fadeFrom`..`fadeTo` is a screen ramp along x: the dots themselves shrink to
// nothing, as a printer fades a picture, never an alpha gradient. `lightInk` prints the lights (light ink on a dark
// stock); otherwise the darks (dark ink on paper).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float cell;
    float angle;
    vec4 ink;
    float fadeFrom;
    float fadeTo;
    float lightInk;
    float floorPx;
    float gain;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    float c = cos(angle);
    float s = sin(angle);
    vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
    vec2 centreQ = (floor(q / cell) + 0.5) * cell;
    vec2 centreP = vec2(c * centreQ.x - s * centreQ.y, s * centreQ.x + c * centreQ.y);
    vec2 uv = clamp(centreP / max(size, vec2(1.0)), 0.0, 1.0);
    vec3 rgb = texture(source, uv).rgb;
    float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    float tone = lightInk > 0.5 ? lum : 1.0 - lum;
    tone = clamp(tone * gain, 0.0, 1.0) * smoothstep(fadeFrom, fadeTo, uv.x);
    float r = cell * sqrt(tone / 3.14159265);
    float a = (1.0 - smoothstep(r - 0.7, r + 0.7, length(q - centreQ))) * step(floorPx * 0.5, r);
    fragColor = vec4(ink.rgb, 1.0) * ink.a * a * qt_Opacity;
}
