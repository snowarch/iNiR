#version 440
// The built-in subjects of GlyphArt: eight objects that turn and an iris, drawn here so no picture file ships.
// Each is a distance field marched from a still camera; what is not the object stays transparent, which is the
// cut GlyphArt needs. Drawn small (it is read at a few samples a glyph cell) and only when its phase moves.
// After winchxyz/afterglyph (MIT): its demo objects, their colours and its three-term shading.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    // x: which (0 planet, 1 jellyfish, 2 helix, 3 knot, 4 heart, 5 crystal, 6 amphora, 7 mushroom, 8 iris);
    // y: turn in radians; z: breath, -1..1 times how soft it is; w: width over height.
    vec4 view;
} u;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec2 spin(vec2 p, float a) { return vec2(p.x * cos(a) - p.y * sin(a), p.x * sin(a) + p.y * cos(a)); }
vec2 nearer(vec2 a, vec2 b) { return a.x < b.x ? a : b; }

// The planet keeps its lean toward the eye while it turns: seen from above its ring, never from under it.
vec3 leaned(vec3 p) {
    p.xz = spin(p.xz, -u.view.y);
    p.xy = spin(p.xy, 0.26);
    p.yz = spin(p.yz, -0.3);
    return p;
}

// x: distance to the object, y: which part of it.
vec2 map(vec3 p) {
    float form = u.view.x;
    if (form < 0.5) {
        p = leaned(p);
        float ball = length(p) - 0.56;
        float ring = max(abs(p.y) - 0.03, abs(length(p.xz) - 0.98) - 0.2);
        return nearer(vec2(ball, 0.0), vec2(ring, 1.0));
    }
    if (form < 1.5) {
        float swell = 1.0 + u.view.z;
        vec3 b = p - vec3(0.0, 0.3, 0.0);
        b.xz /= swell;
        float bell = max(abs(length(b * vec3(1.0, 1.25, 1.0)) - 0.5) - 0.035, -b.y - 0.02) * 0.75;
        float around = atan(p.z, p.x);
        float sector = 6.2831853 / 14.0;
        float which = floor(around / sector + 0.5);
        vec2 s = spin(p.xz, -which * sector);
        float wave = sin(p.y * 9.0 + which * 1.7 + u.view.y * 3.0) * 0.035;
        float string = max(length(vec2(s.x - 0.44 * swell - wave, s.y - wave * 0.6)) - 0.016, max(p.y - 0.3, -p.y - 0.85));
        sector = 6.2831853 / 4.0;
        which = floor(around / sector + 0.5);
        s = spin(p.xz, -which * sector);
        wave = sin(p.y * 6.0 + which * 2.1 + u.view.y * 2.0) * 0.05;
        float arm = max(length(vec2(s.x - 0.14 - wave, s.y - wave)) - 0.05 * (1.0 + p.y * 0.6), max(p.y - 0.35, -p.y - 0.65));
        return nearer(vec2(bell, 0.0), nearer(vec2(string * 0.7, 1.0), vec2(arm * 0.7, 2.0)));
    }
    if (form < 2.5) {
        vec3 q = p;
        q.xz = spin(q.xz, p.y * 3.2);
        float strand = length(vec2(abs(q.x) - 0.34, q.z)) - 0.075;
        float rung = max(length(vec2(mod(q.y + 0.1, 0.2) - 0.1, q.z)) - 0.026, abs(q.x) - 0.34);
        float cap = abs(p.y) - 0.92;
        return nearer(vec2(max(strand, cap) * 0.55, q.x > 0.0 ? 0.0 : 1.0), vec2(max(rung, cap) * 0.55, 2.0));
    }
    if (form < 3.5) {
        p.yz = spin(p.yz, 1.2);
        float around = atan(p.z, p.x);
        vec2 c = spin(vec2(length(p.xz) - 0.56, p.y), around * 1.5);
        c.y = abs(c.y) - 0.24;
        return vec2((length(c) - 0.105) * 0.6, around);
    }
    if (form < 4.5) {
        vec3 q = p / (1.0 + u.view.z);
        float x = abs(q.x);
        q.y = 0.08 + q.y * 1.1 - x * sqrt(max((1.2 - x) / 2.2, 0.0)) * 0.9;
        q.z *= 1.7;
        return vec2((length(q) - 0.66) * 0.45, 0.0);
    }
    if (form < 5.5) {
        p.xy = spin(p.xy, 0.16);
        vec3 q = abs(p);
        float side = max(q.x * 0.866 + q.z * 0.5, q.z);
        return vec2(max(side - 0.3, q.y * 0.5 + side * 0.866 - 0.5), floor(atan(p.z, p.x) / 1.0471976 + 0.5));
    }
    if (form < 6.5) {
        float y = p.y, r;
        if (y < 0.38) r = 0.09 + 0.43 * pow(max(sin(3.14159 * clamp((y + 0.9) / 1.36, 0.0, 1.0)), 0.0), 0.8);
        else r = 0.13 + 0.09 * smoothstep(0.55, 0.9, y);
        float body = max((length(p.xz) - r) * 0.5, abs(y) - 0.9);
        float foot = max(length(p.xz) - 0.2, abs(y + 0.88) - 0.03);
        float handle = length(vec2(length(vec2(abs(p.x) - 0.24, y - 0.5)) - 0.2, p.z)) - 0.035;
        handle = max(handle, 0.2 - abs(p.x));
        return nearer(vec2(min(body, foot), 0.0), vec2(handle, 1.0));
    }
    if (form < 7.5) {
        vec3 c = p - vec3(0.0, 0.22, 0.0);
        float cap = max((length(c / vec3(0.62, 0.4, 0.62)) - 1.0) * 0.4, -c.y);
        float gills = max(length(c.xz) - 0.58 + (0.22 - p.y) * 2.2, max(p.y - 0.22, 0.1 - p.y));
        float stem = max(length(p.xz) - 0.1 - 0.06 * smoothstep(-0.2, -0.85, p.y), max(p.y - 0.25, -p.y - 0.85));
        float skirt = max(abs(length(p.xz) - 0.1 - (-0.02 - p.y) * 0.9) - 0.012, max(p.y + 0.02, -p.y - 0.2));
        return nearer(nearer(vec2(cap, 0.0), vec2(gills, 1.0)), nearer(vec2(stem, 2.0), vec2(skirt * 0.7, 2.0)));
    }
    return vec2(1.0, 0.0);
}

vec3 paint(vec3 p, float part) {
    float form = u.view.x;
    if (form < 0.5) {
        vec3 q = leaned(p);
        if (part > 0.5) {
            float r = length(q.xz);
            return mix(vec3(0.83, 0.74, 0.58), vec3(0.42, 0.36, 0.3), step(0.55, fract(r * 13.0))) * smoothstep(0.78, 0.84, r);
        }
        return mix(vec3(0.93, 0.74, 0.45), vec3(0.68, 0.4, 0.2), 0.5 + 0.5 * sin(q.y * 24.0 + sin(q.y * 7.0) * 2.0 + 0.7 * sin(atan(q.z, q.x) * 3.0 + u.view.y * 3.0)));
    }
    if (form < 1.5) {
        if (part < 0.5) return mix(vec3(1.0, 0.36, 0.72), vec3(0.62, 0.3, 1.0), clamp(p.y * 1.6 + 0.2, 0.0, 1.0));
        if (part < 1.5) return mix(vec3(0.55, 0.85, 1.0), vec3(1.0, 0.5, 0.85), clamp(-p.y, 0.0, 1.0));
        return vec3(1.0, 0.72, 0.9);
    }
    if (form < 2.5) return part < 0.5 ? vec3(0.3, 0.62, 1.0) : part < 1.5 ? vec3(1.0, 0.36, 0.62) : vec3(0.9, 0.95, 1.0);
    if (form < 3.5) return 0.55 + 0.45 * cos(part + vec3(0.0, 2.1, 4.2));
    if (form < 4.5) return mix(vec3(0.78, 0.05, 0.16), vec3(1.0, 0.25, 0.36), clamp(p.y + 0.5, 0.0, 1.0));
    if (form < 5.5) return mix(vec3(0.62, 0.5, 1.0), vec3(0.8, 0.95, 1.0), fract(part * 0.37 + p.y * 0.4 + 0.5));
    if (form < 6.5) {
        vec3 clay = vec3(0.78, 0.4, 0.22);
        if (part > 0.5) return clay * 0.85;
        float band = step(abs(p.y - 0.1), 0.09) * step(0.5, fract(atan(p.z, p.x) * 3.8197 + step(0.1, p.y) * 0.5));
        band = max(band, step(abs(abs(p.y - 0.1) - 0.13), 0.012));
        return mix(clay, vec3(0.12, 0.07, 0.05), band);
    }
    if (part < 0.5) {
        vec2 spot = vec2(atan(p.z, p.x) * 2.2, p.y * 9.0);
        float dot_ = step(length(fract(spot) - 0.5), 0.2 + 0.18 * hash(floor(spot)));
        return mix(vec3(0.86, 0.1, 0.08), vec3(1.0, 0.96, 0.9), dot_);
    }
    return part < 1.5 ? vec3(0.8, 0.72, 0.6) : vec3(0.96, 0.92, 0.82);
}

// The iris: a flat drawing, a stem with two leaves, three falls and three standards.
float petal(vec2 p, vec2 foot, float angle, float len, float wide) {
    vec2 q = spin(p - foot, angle);
    q.y -= len;
    return length(q / vec2(wide * (0.55 + 0.45 * smoothstep(-len, len, q.y)), len)) - 1.0;
}
vec4 iris(vec2 p) {
    float sway = u.view.z * 3.0;
    vec2 heart = vec2(sway * 0.4, 0.34);
    vec4 col = vec4(0.0);
    float bend = (p.y + 0.95) * (p.y + 0.95) * 0.03 + sway * 0.4 * smoothstep(-0.95, 0.34, p.y);
    if (abs(p.x - bend) < 0.022 && p.y > -0.95 && p.y < 0.34) col = vec4(0.2, 0.62, 0.3, 1.0);
    for (int i = 0; i < 2; i++) {
        float s = i == 0 ? -1.0 : 1.0;
        float leaf = petal(p, vec2(0.0, -0.95), s * 0.3, 0.48 + float(i) * 0.1, 0.075);
        if (leaf < 0.0) col = vec4(mix(vec3(0.1, 0.45, 0.25), vec3(0.4, 0.8, 0.4), -leaf), 1.0);
    }
    for (int i = 0; i < 3; i++) {
        float a = (float(i) - 1.0) * 2.05;
        float fall = petal(p, heart, 3.14159 + a * 0.5, i == 1 ? 0.19 : 0.3, 0.2);
        if (fall < 0.0) {
            vec2 q = spin(p - heart, 3.14159 + a * 0.5);
            vec3 c = mix(vec3(0.23, 0.2, 0.84), vec3(0.5, 0.55, 1.0), clamp(-fall * 1.4, 0.0, 1.0));
            c = mix(c, vec3(1.0, 0.85, 0.3), smoothstep(0.035, 0.0, abs(q.x)) * smoothstep(0.3, 0.02, q.y));
            col = vec4(c, 1.0);
        }
    }
    for (int i = 0; i < 3; i++) {
        float a = (float(i) - 1.0) * 0.55;
        float standard = petal(p, heart, a * 1.2, 0.27, 0.16);
        if (standard < 0.0) col = vec4(mix(vec3(0.5, 0.55, 1.0), vec3(0.91, 0.92, 1.0), clamp(-standard * 1.5, 0.0, 1.0)), 1.0);
    }
    return col;
}

void main() {
    vec2 p = (qt_TexCoord0 * 2.0 - 1.0) * vec2(u.view.w, -1.0);
    if (u.view.w < 1.0) p /= u.view.w;
    if (u.view.x > 7.5) {
        vec4 flower = iris(p * 1.05);
        fragColor = vec4(flower.rgb * flower.a, flower.a);
        return;
    }
    // A camera a little above, looking at the centre; the object turns, not the camera.
    vec3 from = vec3(0.0, 0.62, 4.4);
    vec3 dir = normalize(vec3(p * 0.2493, -1.0));
    dir.yz = spin(dir.yz, -0.14);
    float c = cos(u.view.y), s = sin(u.view.y);
    from = vec3(from.x * c - from.z * s, from.y, from.x * s + from.z * c);
    dir = vec3(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c);

    float t = 2.8;
    vec2 hit = vec2(1.0, 0.0);
    bool found = false;
    for (int i = 0; i < 72; i++) {
        hit = map(from + dir * t);
        if (hit.x < 0.0025) { found = true; break; }
        t += hit.x;
        if (t > 6.2) break;
    }
    if (!found) {
        fragColor = vec4(0.0);
        return;
    }
    vec3 at = from + dir * t;
    vec2 h = vec2(0.004, -0.004);
    vec3 n = normalize(h.xyy * map(at + h.xyy).x + h.yyx * map(at + h.yyx).x + h.yxy * map(at + h.yxy).x + h.xxx * map(at + h.xxx).x);
    vec3 sun = normalize(vec3(0.45, 0.55, 0.7));
    sun = vec3(sun.x * c - sun.z * s, sun.y, sun.x * s + sun.z * c);
    float d = max(dot(n, sun), 0.0);
    float rim = pow(1.0 - max(dot(n, -dir), 0.0), 2.0);
    vec3 col = paint(at, hit.y);
    fragColor = vec4(clamp(col * (0.3 + 0.8 * d) + col * rim * 0.45 + pow(d, 28.0) * 0.22, 0.0, 1.0), 1.0);
}
